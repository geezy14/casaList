import SwiftUI

/// Picker sheet that lists every saved ReminderTemplate. Tapping a
/// row calls `onPick` and dismisses the sheet — the caller is then
/// responsible for opening AddReminderView seeded with that
/// template's values.
///
/// Swipe-to-delete on a row removes the template from storage.
struct ReminderTemplatePicker: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (ReminderTemplate) -> Void

    @State private var templates: [ReminderTemplate] = []

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(templates) { t in
                            Button { onPick(t) } label: {
                                row(t)
                            }
                            .buttonStyle(.row)
                        }
                        .onDelete(perform: deleteRows)
                    }
                }
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { templates = ReminderTemplateStore.loadAll() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No templates yet").font(.system(size: 16, weight: .heavy))
            Text("Open any reminder, tap \"Save as template\" at the bottom, and it'll show up here.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ t: ReminderTemplate) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.on.doc")
                .foregroundStyle(.tint).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.name).font(.system(size: 15, weight: .semibold))
                Text(summary(t)).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption).foregroundStyle(.tertiary)
        }
    }

    /// One-line description so the user can tell two similar templates
    /// apart without opening either.
    private func summary(_ t: ReminderTemplate) -> String {
        var parts: [String] = [t.title]
        if !t.repeatKind.isEmpty {
            if let rule = RepeatRule.decode(t.repeatKind) {
                parts.append(rule.label)
            } else if let rule = RepeatRule.fromLegacy(t.repeatKind) {
                parts.append(rule.label)
            } else {
                parts.append(t.repeatKind.capitalized)
            }
        }
        if !t.assignee.isEmpty { parts.append("→ \(t.assignee)") }
        if t.locationRadius > 0 {
            parts.append(t.locationOnArrive ? "@\(t.locationName.isEmpty ? "location" : t.locationName)" : "leave \(t.locationName)")
        }
        return parts.joined(separator: " · ")
    }

    private func deleteRows(at offsets: IndexSet) {
        for idx in offsets {
            ReminderTemplateStore.remove(id: templates[idx].id)
        }
        templates.remove(atOffsets: offsets)
    }
}
