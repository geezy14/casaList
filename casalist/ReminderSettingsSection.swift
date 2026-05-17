import SwiftUI
import EventKit

/// Settings → REMINDERS — picks the Apple Reminders list that
/// Casalist mirrors reminders to (push) and reads from (display).
/// Isolated in its own View struct for the same bounded-TupleView
/// reasons as the other Settings sub-sections.
struct ReminderSettingsSection: View {
    @StateObject private var svc = ReminderLinkService.shared
    @AppStorage("reminderLinkID") private var reminderLinkID: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REMINDERS")
                .font(.system(size: 11, weight: .heavy)).tracking(1.2)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                ReminderLinkRow(
                    status: svc.authorizationStatus,
                    available: svc.availableLists,
                    selectedID: $reminderLinkID,
                    requestAccess: { Task { await svc.requestAccess() } }
                )
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .onAppear {
            // Re-read auth status — covers the case where the user
            // flipped Privacy → Reminders in iOS Settings while the
            // app was suspended.
            svc.refreshAuthStatus()
        }
    }
}

private struct ReminderLinkPickRow: View {
    let title: String
    let color: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle().fill(color).frame(width: 10, height: 10)
                Text(title).font(.system(size: 14, weight: .semibold))
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .padding(.vertical, 6).padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.row)
    }
}

private struct ReminderLinkRow: View {
    let status: EKAuthorizationStatus
    let available: [EKCalendar]
    @Binding var selectedID: String
    let requestAccess: () -> Void

    var body: some View {
        Group {
            switch status {
            case .notDetermined:
                Button {
                    requestAccess()
                } label: {
                    Label("Connect an Apple Reminders list", systemImage: "checklist")
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            case .denied, .restricted:
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reminders access denied").font(.system(size: 14, weight: .semibold))
                    Text("Enable in iOS Settings → Privacy → Reminders to link a list.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Open iOS Settings").font(.system(size: 13, weight: .semibold))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            default:
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "checklist").font(.system(size: 13, weight: .semibold))
                        Text("Linked list").font(.system(size: 13, weight: .semibold))
                    }
                    if available.isEmpty {
                        Text("No Reminders lists found. Open Apple Reminders, create a list, then come back.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        // Inline list of all available Reminders lists.
                        // A Menu-style Picker hides this behind a tap —
                        // showing rows directly makes it obvious there
                        // are choices.
                        ReminderLinkPickRow(
                            title: "None — Casalist only",
                            color: .gray,
                            selected: selectedID.isEmpty
                        ) { selectedID = "" }
                        ForEach(available, id: \.calendarIdentifier) { cal in
                            ReminderLinkPickRow(
                                title: cal.title,
                                color: Color(cgColor: cal.cgColor),
                                selected: selectedID == cal.calendarIdentifier
                            ) { selectedID = cal.calendarIdentifier }
                        }
                    }
                    Text("Casalist reminders are mirrored here, and this list's reminders appear in Casalist.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
        }
    }
}
