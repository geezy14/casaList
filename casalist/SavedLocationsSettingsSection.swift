import SwiftUI

/// Settings → Saved Locations. Manages the device-local list of
/// labeled places (Home / Work / School) surfaced as quick-pick chips
/// in AddReminderView's Location panel. Each device keeps its own
/// list — different family members have different homes.
struct SavedLocationsSettingsSection: View {
    @State private var entries: [SavedLocation] = []
    @State private var showAddPicker: Bool = false
    @State private var showLabelAlert: Bool = false
    @State private var pendingPick: PickedLocation? = nil
    @State private var pendingLabel: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SAVED LOCATIONS")
                .font(.system(size: 11, weight: .heavy)).tracking(1.2)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                ForEach(entries) { e in
                    row(e)
                    if e.id != entries.last?.id { Divider().padding(.leading, 16) }
                }
                if !entries.isEmpty { Divider() }
                Button { showAddPicker = true } label: {
                    Label("Add a saved location", systemImage: "plus.circle.fill")
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            Text("Used by location-based reminders so you don't have to search every time.")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
        .onAppear { entries = SavedLocationsStore.loadAll() }
        .sheet(isPresented: $showAddPicker) {
            LocationPickerSheet { picked in
                pendingPick = picked
                pendingLabel = picked.name
                showLabelAlert = true
            }
        }
        .alert("Label this place", isPresented: $showLabelAlert) {
            TextField("Home", text: $pendingLabel)
            Button("Save") { commitAdd() }
            Button("Cancel", role: .cancel) { pendingPick = nil }
        } message: {
            Text("Give it a short label like Home, Work, or School.")
        }
    }

    private func row(_ e: SavedLocation) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.tint).font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text(e.label).font(.system(size: 15, weight: .semibold))
                Text(e.address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button(role: .destructive) {
                SavedLocationsStore.remove(id: e.id)
                entries = SavedLocationsStore.loadAll()
            } label: {
                Image(systemName: "trash").foregroundStyle(.red)
            }
            .buttonStyle(.row)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func commitAdd() {
        guard let picked = pendingPick else { return }
        let trimmed = pendingLabel.trimmingCharacters(in: .whitespaces)
        let label = trimmed.isEmpty ? picked.name : trimmed
        SavedLocationsStore.add(SavedLocation(
            label: label,
            address: picked.subtitle.isEmpty ? picked.name : picked.subtitle,
            latitude: picked.latitude,
            longitude: picked.longitude
        ))
        entries = SavedLocationsStore.loadAll()
        pendingPick = nil
        pendingLabel = ""
    }
}
