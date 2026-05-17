import SwiftUI
import CoreData
import PhotosUI

/// Reminder add/edit sheet — all fields visible inline, no hidden panels.
/// Layout: title → when (date + time always shown) → repeat → notify → advanced.
struct AddReminderView: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName: String = ""
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var familyMembers: FetchedResults<FamilyMember>
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: false)],
        predicate: NSPredicate(format: "deletedAt == nil AND category ==[c] %@", "reminders")
    )
    private var existingReminders: FetchedResults<TaskItem>

    private let editing: TaskItem?

    @State private var title: String
    @State private var repeatKind: String
    @State private var hasFireDate: Bool
    @State private var fireDate: Date
    @State private var assignee: String
    @State private var hasStopTime: Bool
    @State private var stopDate: Date
    @State private var locationLat: Double
    @State private var locationLng: Double
    @State private var locationRadius: Double
    @State private var locationName: String
    @State private var locationOnArrive: Bool
    @State private var confirmDelete: Bool = false
    @State private var showCustomRepeat: Bool = false
    @State private var showLocationPicker: Bool = false
    @State private var pendingPhoto: UIImage? = nil
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var showSaveTemplate: Bool = false
    @State private var templateName: String = ""
    @State private var colorTag: ReminderColorTag
    @State private var playSound: Bool
    @State private var showColorWheel: Bool = false
    @State private var showAdvanced: Bool = false

    init(editing: TaskItem? = nil, template: ReminderTemplate? = nil) {
        self.editing = editing
        if let t = editing {
            _title = State(initialValue: t.task)
            _repeatKind = State(initialValue: t.effectiveRepeatKind)
            _hasFireDate = State(initialValue: t.dueDate != nil)
            _fireDate = State(initialValue: t.dueDate ?? Date().addingTimeInterval(3600))
            let mins = Int(t.repeatEndMinutes)
            _hasStopTime = State(initialValue: mins > 0)
            let cal = Calendar.current
            let baseToday = cal.startOfDay(for: Date())
            let stopAnchor = cal.date(byAdding: .minute, value: mins > 0 ? mins : 22 * 60, to: baseToday) ?? baseToday
            _stopDate = State(initialValue: stopAnchor)
            _assignee = State(initialValue: t.assignee ?? "")
            _locationLat = State(initialValue: t.locationLat)
            _locationLng = State(initialValue: t.locationLng)
            _locationRadius = State(initialValue: t.locationRadius)
            _locationName = State(initialValue: t.locationName)
            _locationOnArrive = State(initialValue: t.locationOnArrive)
            _colorTag = State(initialValue: ReminderColorTagStore.tag(for: t.uid))
            _playSound = State(initialValue: ReminderSoundStore.playsSound(for: t.uid))
            _pendingPhoto = State(initialValue: ReminderPhotoStore.image(for: t.uid))
            // Auto-open advanced section if any advanced field is set.
            let hasAdvanced = t.locationRadius > 0
                || ReminderPhotoStore.hasImage(for: t.uid)
                || ReminderColorTagStore.tag(for: t.uid) != .none
                || !ReminderSoundStore.playsSound(for: t.uid)
            _showAdvanced = State(initialValue: hasAdvanced)
        } else if let tpl = template {
            _title = State(initialValue: tpl.title)
            _repeatKind = State(initialValue: tpl.repeatKind)
            _hasFireDate = State(initialValue: tpl.hasFireTime)
            let cal = Calendar.current
            let now = Date()
            let seeded = cal.date(bySettingHour: tpl.fireHour, minute: tpl.fireMinute, second: 0, of: now) ?? now.addingTimeInterval(3600)
            _fireDate = State(initialValue: seeded)
            _hasStopTime = State(initialValue: tpl.repeatEndMinutes > 0)
            let stopAnchor = cal.date(byAdding: .minute, value: tpl.repeatEndMinutes > 0 ? Int(tpl.repeatEndMinutes) : 22 * 60, to: cal.startOfDay(for: now)) ?? now
            _stopDate = State(initialValue: stopAnchor)
            _assignee = State(initialValue: tpl.assignee)
            _locationLat = State(initialValue: tpl.locationLat)
            _locationLng = State(initialValue: tpl.locationLng)
            _locationRadius = State(initialValue: tpl.locationRadius)
            _locationName = State(initialValue: tpl.locationName)
            _locationOnArrive = State(initialValue: tpl.locationOnArrive)
            _colorTag = State(initialValue: .none)
            _playSound = State(initialValue: true)
            _showAdvanced = State(initialValue: tpl.locationRadius > 0)
        } else {
            _title = State(initialValue: "")
            _repeatKind = State(initialValue: "")
            _hasFireDate = State(initialValue: false)
            _fireDate = State(initialValue: Date().addingTimeInterval(3600))
            _hasStopTime = State(initialValue: false)
            let cal = Calendar.current
            _stopDate = State(initialValue: cal.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date())
            _assignee = State(initialValue: "")
            _locationLat = State(initialValue: 0)
            _locationLng = State(initialValue: 0)
            _locationRadius = State(initialValue: 0)
            _locationName = State(initialValue: "")
            _locationOnArrive = State(initialValue: true)
            _colorTag = State(initialValue: .none)
            _playSound = State(initialValue: true)
            _showAdvanced = State(initialValue: false)
        }
    }

    // MARK: – Computed helpers

    private var hasLocationTrigger: Bool { locationRadius > 0 }
    private let metersPerFoot: Double = 0.3048
    private var radiusLabel: String {
        let ft = locationRadius / metersPerFoot
        if ft >= 1000 { return String(format: "%.1f mi", ft / 5280) }
        return "\(Int(ft.rounded())) ft"
    }
    private var hasRepeat: Bool { !repeatKind.isEmpty }
    private var isCadenceKind: Bool {
        ["hourly", "every2h", "every4h", "every8h", "every12h"].contains(repeatKind)
    }
    private var isPinned: Bool { !hasFireDate && repeatKind.isEmpty }
    private var repeatRowLabel: String {
        if repeatKind.isEmpty { return "Never" }
        if let rule = RepeatRule.decode(repeatKind) { return rule.label }
        if let rule = RepeatRule.fromLegacy(repeatKind) { return rule.label }
        return repeatKind.capitalized
    }
    private var stopMinutesValue: Int64 {
        guard isCadenceKind, hasStopTime else { return 0 }
        let cal = Calendar.current
        let stopMin = cal.component(.hour, from: stopDate) * 60 + cal.component(.minute, from: stopDate)
        let startMin = cal.component(.hour, from: fireDate) * 60 + cal.component(.minute, from: fireDate)
        guard stopMin > startMin else { return 0 }
        return Int64(stopMin)
    }

    // MARK: – Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    titleCard

                    // Streak heatmap in edit mode (daily/weekly/monthly/yearly only)
                    if let editing,
                       ["daily","weekly","monthly","yearly"].contains(editing.effectiveRepeatKind),
                       !ReminderStreak.completionDays(for: editing.uid).isEmpty {
                        ReminderStreakHeatmap(taskUid: editing.uid)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                    }

                    whenCard
                    if hasFireDate { repeatCard }
                    notifyCard
                    advancedCard

                    // Footer actions
                    Button {
                        templateName = title.isEmpty ? "" : title
                        showSaveTemplate = true
                    } label: {
                        Label("Save as template", systemImage: "square.stack")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)

                    if editing != nil {
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Label("Delete reminder", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Capsule().fill(Color.red.opacity(0.12)))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .animation(.easeInOut(duration: 0.2), value: hasFireDate)
                .animation(.easeInOut(duration: 0.2), value: hasRepeat)
                .animation(.easeInOut(duration: 0.2), value: showAdvanced)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(editing == nil ? "New reminder" : "Edit reminder")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCustomRepeat) {
                CustomRepeatPicker(encoded: $repeatKind)
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerSheet { picked in
                    locationLat = picked.latitude
                    locationLng = picked.longitude
                    locationName = picked.displayName
                    if locationRadius == 0 { locationRadius = 500 * metersPerFoot }
                }
            }
            .sheet(isPresented: $showColorWheel) {
                ColorWheelSheet(tag: $colorTag).presentationDetents([.large])
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Delete reminder?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleteReminder() }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Save as template", isPresented: $showSaveTemplate) {
                TextField("Template name", text: $templateName)
                Button("Save") { persistTemplate() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Templates save the cadence, assignee, location, and stop time.")
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        pendingPhoto = ui
                    }
                }
            }
        }
    }

    // MARK: – Title card

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("What do you want to remember?", text: $title, axis: .vertical)
                .font(.system(size: 18, weight: .semibold))
                .textInputAutocapitalization(.sentences)
                .lineLimit(1...4)
            if !titleSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(titleSuggestions, id: \.self) { s in
                            Button { title = s } label: {
                                Text(s)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var titleSuggestions: [String] {
        let typed = title.trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty else { return [] }
        let needle = typed.lowercased()
        var seen: Set<String> = [typed.lowercased()]
        var out: [String] = []
        for t in existingReminders {
            let name = t.task.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            let key = name.lowercased()
            if seen.contains(key) { continue }
            if key.hasPrefix(needle) { out.append(name); seen.insert(key) }
            if out.count >= 5 { break }
        }
        if out.count < 5 {
            for tpl in ReminderTemplateStore.loadAll() {
                let name = tpl.title.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { continue }
                let key = name.lowercased()
                if seen.contains(key) { continue }
                if key.hasPrefix(needle) { out.append(name); seen.insert(key) }
                if out.count >= 5 { break }
            }
        }
        return out
    }

    // MARK: – When card

    private var whenCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row: label + toggle
            HStack {
                Image(systemName: "bell")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.secondary)
                Text("Alert")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("Alert", isOn: $hasFireDate)
                    .labelsHidden()
                    .onChange(of: hasFireDate) { _, on in
                        if on && fireDate < Date() {
                            fireDate = Date().addingTimeInterval(3600)
                        }
                    }
            }

            if hasFireDate {
                // Quick-pick date chips
                quickDateChips

                Divider()

                // Date picker — compact tappable pill
                HStack {
                    Text("Date")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    Spacer()
                    DatePicker("Date", selection: $fireDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }

                // Time picker — compact tappable pill (always visible)
                HStack {
                    Text("Time")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    Spacer()
                    DatePicker("Time", selection: $fireDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
            } else {
                Text("Pinned — stays at the top, no alert")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    // Quick date chip strip
    private var quickDateChips: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today) ?? today
        let weekendDay = upcomingSaturday(from: today, cal: cal)
        let nextWeek = cal.date(byAdding: .day, value: 7, to: today) ?? today
        let selected = selectedQuickPick(cal: cal, weekendDay: weekendDay, nextWeek: nextWeek)
        let todayWeekday = cal.component(.weekday, from: today)
        let isAlreadyWeekend = (todayWeekday == 7 || todayWeekday == 1)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                quickChip("Today",    isOn: selected == .today,
                          target: defaultTimeOnTodayOrLater())
                quickChip("Tomorrow", isOn: selected == .tomorrow,
                          target: cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow)
                if !isAlreadyWeekend {
                    quickChip("Weekend", isOn: selected == .weekend,
                              target: cal.date(bySettingHour: 10, minute: 0, second: 0, of: weekendDay) ?? weekendDay)
                }
                quickChip("Next week", isOn: selected == .nextWeek,
                          target: cal.date(bySettingHour: 9, minute: 0, second: 0, of: nextWeek) ?? nextWeek)
            }
        }
    }

    private enum QuickPick { case today, tomorrow, weekend, nextWeek }

    private func selectedQuickPick(cal: Calendar, weekendDay: Date, nextWeek: Date) -> QuickPick? {
        if cal.isDateInToday(fireDate) { return .today }
        if cal.isDateInTomorrow(fireDate) { return .tomorrow }
        if cal.isDate(fireDate, inSameDayAs: weekendDay) { return .weekend }
        if cal.isDate(fireDate, inSameDayAs: nextWeek) { return .nextWeek }
        return nil
    }

    private func quickChip(_ label: String, isOn: Bool, target: Date) -> some View {
        Button { fireDate = target } label: {
            Text(label)
                .font(.system(size: 12, weight: .heavy))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .background(Capsule().fill(isOn ? Color.accentColor : Color(.tertiarySystemBackground)))
        }
        .buttonStyle(.plain)
    }

    private func defaultTimeOnTodayOrLater() -> Date {
        let cal = Calendar.current
        let now = Date()
        let plusHour = now.addingTimeInterval(3600)
        if cal.isDateInToday(plusHour) { return plusHour }
        return cal.date(bySettingHour: 23, minute: 0, second: 0, of: cal.startOfDay(for: now)) ?? now
    }

    private func upcomingSaturday(from base: Date, cal: Calendar) -> Date {
        let weekday = cal.component(.weekday, from: base)
        let daysUntilSat = (7 - weekday + 7) % 7
        return cal.date(byAdding: .day, value: daysUntilSat == 0 ? 7 : daysUntilSat, to: base) ?? base
    }

    // MARK: – Repeat card

    private var repeatCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Repeat row
            Button { showCustomRepeat = true } label: {
                HStack {
                    Image(systemName: "repeat")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.secondary)
                    Text("Repeat")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(repeatRowLabel)
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            // Stop time — only for hourly cadences
            if isCadenceKind {
                Divider()
                HStack {
                    Text("Stop at")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if hasStopTime {
                        DatePicker("", selection: $stopDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                    Toggle("", isOn: $hasStopTime)
                        .labelsHidden()
                }
            }

            // "Next fires" preview
            let nextDates = NotificationsManager.previewFireDates(
                kind: repeatKind,
                dueDate: hasFireDate ? fireDate : nil,
                endMinutes: stopMinutesValue,
                limit: 3
            )
            if hasRepeat && !nextDates.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEXT FIRES")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    ForEach(Array(nextDates.enumerated()), id: \.offset) { _, d in
                        (Text(d, style: .relative)
                            .foregroundStyle(.secondary)
                        + Text("  ·  ")
                            .foregroundStyle(.tertiary)
                        + Text(d, style: .time)
                            .foregroundStyle(.secondary))
                        .font(.system(size: 12))
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    // MARK: – Notify card

    private var notifyCard: some View {
        HStack {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.secondary)
            Text("Notify")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.secondary)
            Spacer()
            Picker("Notify", selection: $assignee) {
                Text("Everyone").tag("")
                ForEach(familyMembers, id: \.uid) { m in
                    Text(m.name).tag(m.name)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    // MARK: – Advanced card (disclosure)

    private var advancedCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Disclosure toggle header
            Button {
                withAnimation { showAdvanced.toggle() }
            } label: {
                HStack {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.secondary)
                    Text("More options")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .padding(14)

            if showAdvanced {
                Divider().padding(.horizontal, 14)

                // ── Location ──────────────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Location")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Button(locationName.isEmpty ? "Set place" : locationName) {
                            showLocationPicker = true
                        }
                        .font(.subheadline)
                        .lineLimit(1)
                        if hasLocationTrigger {
                            Button { locationRadius = 0; locationName = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if hasLocationTrigger {
                        // Arrive / Leave
                        Picker("", selection: $locationOnArrive) {
                            Text("Arriving").tag(true)
                            Text("Leaving").tag(false)
                        }
                        .pickerStyle(.segmented)

                        // Radius slider (100 ft → 1 mi in feet, stored as meters)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Radius: \(radiusLabel)")
                                .font(.caption).foregroundStyle(.secondary)
                            Slider(
                                value: $locationRadius,
                                in: 30.48...1609.34,    // 100 ft … 1 mi in meters
                                step: 30.48             // 100 ft steps
                            )
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider().padding(.horizontal, 14)

                // ── Photo ─────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Photo")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            Text(pendingPhoto == nil ? "Add photo" : "Change")
                                .font(.subheadline)
                        }
                        if pendingPhoto != nil {
                            Button { pendingPhoto = nil } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if let img = pendingPhoto {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(height: 120).frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider().padding(.horizontal, 14)

                // ── Color tag ─────────────────────────────────────────
                HStack {
                    Text("Tag")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Button { showColorWheel = true } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(colorTag == .none ? Color(.tertiarySystemFill) : colorTag.swiftUIColor)
                                .frame(width: 20, height: 20)
                                .overlay(Circle().stroke(.secondary.opacity(0.3), lineWidth: 0.5))
                            Text(colorTag == .none ? "None" : colorTag.label)
                                .font(.subheadline)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider().padding(.horizontal, 14)

                // ── Sound ─────────────────────────────────────────────
                HStack {
                    Text("Sound")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Toggle("Sound", isOn: $playSound)
                        .labelsHidden()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    // MARK: – Template persistence

    private func persistTemplate() {
        let trimmed = templateName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let cal = Calendar.current
        let template = ReminderTemplate(
            name: trimmed,
            title: title.trimmingCharacters(in: .whitespaces),
            repeatKind: repeatKind,
            repeatEndMinutes: stopMinutesValue,
            assignee: assignee.trimmingCharacters(in: .whitespaces),
            locationLat: locationLat,
            locationLng: locationLng,
            locationRadius: locationRadius,
            locationOnArrive: locationOnArrive,
            locationName: locationName,
            hasFireTime: hasFireDate && repeatKind.isEmpty,
            fireHour: cal.component(.hour, from: fireDate),
            fireMinute: cal.component(.minute, from: fireDate)
        )
        ReminderTemplateStore.add(template)
    }

    // MARK: – Save / delete

    private func save() {
        let storeDate: Date? = isPinned ? nil : fireDate
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedAssignee = assignee.trimmingCharacters(in: .whitespaces)
        let target: TaskItem
        if let editing {
            editing.task = trimmedTitle
            editing.dueDate = storeDate
            editing.repeatKind = repeatKind
            editing.repeatHours = 0
            editing.repeatEndMinutes = stopMinutesValue
            editing.assignee = trimmedAssignee.isEmpty ? nil : trimmedAssignee
            editing.locationLat = locationLat
            editing.locationLng = locationLng
            editing.locationRadius = locationRadius
            editing.locationOnArrive = locationOnArrive
            editing.locationName = locationName
            target = editing
        } else {
            let item = TaskItem(
                context: moc,
                task: trimmedTitle,
                assignee: trimmedAssignee.isEmpty ? nil : trimmedAssignee,
                dueDate: storeDate,
                category: "reminders",
                points: 0,
                createdBy: userName.trimmingCharacters(in: .whitespaces),
                repeatHours: 0,
                repeatKind: repeatKind
            )
            item.repeatEndMinutes = stopMinutesValue
            item.locationLat = locationLat
            item.locationLng = locationLng
            item.locationRadius = locationRadius
            item.locationOnArrive = locationOnArrive
            item.locationName = locationName
            if let h = households.preferredTarget {
                moc.assign(item, toStoreOf: h)
                item.household = h
            }
            target = item
        }
        try? moc.save()
        if let img = pendingPhoto {
            ReminderPhotoStore.save(img, for: target.uid)
        } else {
            ReminderPhotoStore.delete(for: target.uid)
        }
        ReminderColorTagStore.set(colorTag, for: target.uid)
        ReminderSoundStore.setPlaysSound(playSound, for: target.uid)
        Task { await NotificationsManager.scheduleNow(for: target) }
        ReminderLinkService.shared.mirror(target)
        LocationReminderService.shared.resyncMonitoredRegions(in: moc)
        dismiss()
    }

    private func deleteReminder() {
        guard let editing else { return }
        ReminderLinkService.shared.unmirror(uid: editing.uid)
        ReminderPhotoStore.delete(for: editing.uid)
        editing.softDelete()
        try? moc.save()
        let ctx = moc
        Task { await NotificationsManager.syncFromContext(ctx) }
        dismiss()
    }
}
