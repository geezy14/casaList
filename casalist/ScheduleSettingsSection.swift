import SwiftUI
import EventKit

/// Settings → SCHEDULE — picks the Apple Calendar that Casalist mirrors
/// events to (push) and reads from (display). Isolated in its own View
/// struct for the same bounded-TupleView reasons as the other Settings
/// sub-sections.
struct ScheduleSettingsSection: View {
    @StateObject private var svc = CalendarLinkService.shared
    @AppStorage("calendarLinkID") private var calendarLinkID: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SCHEDULE")
                .font(.system(size: 11, weight: .heavy)).tracking(1.2)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                ScheduleLinkRow(
                    status: svc.authorizationStatus,
                    available: svc.availableCalendars,
                    selectedID: $calendarLinkID,
                    requestAccess: { Task { await svc.requestAccess() } }
                )
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .onAppear {
            svc.refreshCalendars()
        }
    }
}

private struct ScheduleLinkRow: View {
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
                    Label("Connect an Apple Calendar", systemImage: "calendar.badge.plus")
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            case .denied, .restricted:
                VStack(alignment: .leading, spacing: 6) {
                    Text("Calendar access denied").font(.system(size: 14, weight: .semibold))
                    Text("Enable in iOS Settings → Privacy → Calendars to link a calendar.")
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
                VStack(alignment: .leading, spacing: 6) {
                    Picker(selection: $selectedID) {
                        Text("None — Casalist only").tag("")
                        ForEach(available, id: \.calendarIdentifier) { cal in
                            HStack {
                                Circle().fill(Color(cgColor: cal.cgColor))
                                    .frame(width: 10, height: 10)
                                Text(cal.title)
                            }.tag(cal.calendarIdentifier)
                        }
                    } label: {
                        Label("Linked calendar", systemImage: "calendar")
                    }
                    Text("Casalist events are mirrored here, and this calendar's events appear in the Schedule.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
        }
    }
}
