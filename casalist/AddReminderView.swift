import SwiftUI
import CoreData
import PhotosUI

/// Reminder add/edit sheet — Apple Reminders "Details" style.
/// Grouped cards, section headers, all options visible — no icon strip or hidden panels.
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
    /// "" = default (notify assignee, or broadcast if empty)
    /// "everyone" = broadcast push regardless of assignee
    /// "admins" = push only to owners + admins
    /// Keeps assignee independent so the My To-Do owner stays correct.
    @State private var notifyMode: String
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
    @State private var nextFireDates: [Date] = []
    @State private var hasFireTime: Bool
    @State private var priority: Int64

    /// Initialize the reminder editor. `initialTitle` lets a caller
    /// (e.g. MyToDo's quick-add bell) prefill just the title and leave
    /// everything else at sane defaults; `editing` and `template` keep
    /// their existing meanings. Only one of editing/template/initialTitle
    /// should be set per call.
    init(
        editing: TaskItem? = nil,
        template: ReminderTemplate? = nil,
        initialTitle: String = ""
    ) {
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
            _notifyMode = State(initialValue: t.notifyMode)
            _locationLat = State(initialValue: t.locationLat)
            _locationLng = State(initialValue: t.locationLng)
            _locationRadius = State(initialValue: t.locationRadius)
            _locationName = State(initialValue: t.locationName)
            _locationOnArrive = State(initialValue: t.locationOnArrive)
            _colorTag = State(initialValue: ReminderColorTagStore.tag(for: t.uid))
            _playSound = State(initialValue: ReminderSoundStore.playsSound(for: t.uid))
            _pendingPhoto = State(initialValue: ReminderPhotoStore.image(for: t.uid))
            _hasFireTime = State(initialValue: t.dueDate != nil)
            _priority = State(initialValue: t.reminderPriority)
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
            _notifyMode = State(initialValue: "")
            _locationLat = State(initialValue: tpl.locationLat)
            _locationLng = State(initialValue: tpl.locationLng)
            _locationRadius = State(initialValue: tpl.locationRadius)
            _locationName = State(initialValue: tpl.locationName)
            _locationOnArrive = State(initialValue: tpl.locationOnArrive)
            _colorTag = State(initialValue: .none)
            _playSound = State(initialValue: true)
            _hasFireTime = State(initialValue: tpl.hasFireTime)
            _priority = State(initialValue: 0)
        } else {
            _title = State(initialValue: initialTitle)
            _repeatKind = State(initialValue: "")
            _hasFireDate = State(initialValue: false)
            _fireDate = State(initialValue: Date().addingTimeInterval(3600))
            _hasStopTime = State(initialValue: false)
            let cal = Calendar.current
            _stopDate = State(initialValue: cal.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date())
            _assignee = State(initialValue: "")
            _notifyMode = State(initialValue: "")
            _locationLat = State(initialValue: 0)
            _locationLng = State(initialValue: 0)
            _locationRadius = State(initialValue: 0)
            _locationName = State(initialValue: "")
            _locationOnArrive = State(initialValue: true)
            _colorTag = State(initialValue: .none)
            _playSound = State(initialValue: true)
            _hasFireTime = State(initialValue: false)
            _priority = State(initialValue: 0)
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
    private var priorityTint: Color {
        switch priority {
        case 1: return .blue
        case 2: return .orange
        case 3: return .red
        default: return .secondary
        }
    }

    /// Single-string view of the Notify picker selection that maps to
    /// the two underlying fields (assignee + notifyMode). Tag values:
    ///   ""           = Everyone   (assignee="", mode="")
    ///   "__admins__" = Admins only (assignee="", mode="admins")
    ///   "<name>"     = Individual (assignee="<name>", mode="")
    /// The empty/Everyone case relies on the existing scheduleNow
    /// fallback that broadcasts when assignee is empty -- keeping
    /// notifyMode empty avoids a behavior change for old reminders.
    private var notifyTargetBinding: Binding<String> {
        Binding(
            get: {
                if notifyMode == "admins" { return "__admins__" }
                return assignee
            },
            set: { newValue in
                if newValue == "__admins__" {
                    assignee = ""
                    notifyMode = "admins"
                } else {
                    assignee = newValue
                    notifyMode = ""
                }
            }
        )
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
                VStack(alignment: .leading, spacing: 0) {
                    titleSection

                    sectionLabel("Date & Time")
                    dateTimeCard

                    sectionLabel("Repeat")
                    repeatCard

                    if !nextFireDates.isEmpty && hasFireDate {
                        nextFiresBlock
                            .padding(.horizontal, 36)
                            .padding(.top, 8)
                    }

                    sectionLabel("Details")
                    detailsCard

                    sectionLabel("Location")
                    locationCard

                    footerSection
                }
                .padding(.bottom, 36)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(editing == nil ? "New Reminder" : "Edit Reminder")
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
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.accentColor)
                    }
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
            .task(id: "\(repeatKind)|\(hasFireDate)|\(fireDate.timeIntervalSince1970.rounded())") {
                await refreshNextFires()
            }
        }
    }

    // MARK: – Layout helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 36)
            .padding(.top, 22)
            .padding(.bottom, 6)
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 20)
    }

    // MARK: – Title section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Title", text: $title, axis: .vertical)
                .font(.title2.weight(.semibold))
                .textInputAutocapitalization(.sentences)
                .lineLimit(1...5)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 8)

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
                            }
                            .buttonStyle(.row)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 8)
            }

            if let editing,
               ["daily","weekly","monthly","yearly"].contains(editing.effectiveRepeatKind),
               !ReminderStreak.completionDays(for: editing.uid).isEmpty {
                ReminderStreakHeatmap(taskUid: editing.uid)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
        }
    }

    // MARK: – Date & Time card

    private var dateTimeCard: some View {
        card {
            // ── Date row ────────────────────────────────────────────
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Text("Date")
                Spacer()
                if hasFireDate {
                    DatePicker("", selection: $fireDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
                Toggle("", isOn: $hasFireDate)
                    .labelsHidden()
                    .onChange(of: hasFireDate) { _, on in
                        if on && fireDate < Date() { fireDate = Date().addingTimeInterval(3600) }
                        if !on { repeatKind = ""; hasFireTime = false }
                    }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)

            // Quick chips (when date is on)
            if hasFireDate {
                Divider().padding(.leading, 50)
                quickDateChips
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }

            Divider().padding(.leading, 50)

            // ── Time row ────────────────────────────────────────────
            HStack(spacing: 12) {
                Image(systemName: "clock")
                    .font(.system(size: 17))
                    .foregroundStyle(hasFireDate ? .secondary : .tertiary)
                    .frame(width: 22)
                Text("Time")
                    .foregroundStyle(hasFireDate ? .primary : Color(.tertiaryLabel))
                Spacer()
                if hasFireDate && hasFireTime {
                    DatePicker("", selection: $fireDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
                Toggle("", isOn: $hasFireTime)
                    .labelsHidden()
                    .disabled(!hasFireDate)
                    .onChange(of: hasFireTime) { _, on in
                        if on {
                            if fireDate < Date() { fireDate = Date().addingTimeInterval(3600) }
                        } else {
                            let cal = Calendar.current
                            fireDate = cal.date(bySettingHour: 9, minute: 0, second: 0,
                                                of: fireDate) ?? fireDate
                        }
                    }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
        }
    }

    // MARK: – Repeat card

    private var repeatCard: some View {
        card {
            HStack(spacing: 12) {
                Image(systemName: "repeat")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Button { showCustomRepeat = true } label: {
                    HStack {
                        Text("Repeat").foregroundStyle(.primary)
                        Spacer()
                        Text(repeatRowLabel)
                            .foregroundStyle(hasRepeat ? .primary : .secondary)
                        if !hasRepeat {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.row)
                if hasRepeat {
                    Button { repeatKind = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    .buttonStyle(.row)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)

            if isCadenceKind {
                Divider().padding(.leading, 50)
                HStack(spacing: 12) {
                    Image(systemName: "stop.circle")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                        .frame(width: 22)
                    Text("Stop at")
                    Spacer()
                    if hasStopTime {
                        DatePicker("", selection: $stopDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                    Toggle("", isOn: $hasStopTime).labelsHidden()
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 50)
            }
        }
    }

    // MARK: – Next fires block

    private var nextFiresBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NEXT FIRES")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.5)
            ForEach(Array(nextFireDates.enumerated()), id: \.offset) { _, d in
                (Text(d, style: .relative).foregroundStyle(.secondary)
                + Text("  ·  ").foregroundStyle(.tertiary)
                + Text(d, style: .time).foregroundStyle(.secondary))
                .font(.system(size: 12))
            }
        }
    }

    // MARK: – Details card (notify, tag, sound, photo)

    private var detailsCard: some View {
        card {
            // Notify
            HStack(spacing: 12) {
                Image(systemName: "person")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Text("Notify")
                Spacer()
                Picker("Notify", selection: notifyTargetBinding) {
                    Text("Everyone").tag("")
                    Text("Admins only").tag("__admins__")
                    ForEach(familyMembers, id: \.uid) { m in
                        Text(m.name).tag(m.name)
                    }
                }
                .pickerStyle(.menu)
                .tint(.secondary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)

            Divider().padding(.leading, 50)

            // Priority
            HStack(spacing: 12) {
                Image(systemName: "flag")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Text("Priority")
                Spacer()
                Picker("Priority", selection: $priority) {
                    Text("None").tag(Int64(0))
                    Text("Low").tag(Int64(1))
                    Text("Medium").tag(Int64(2))
                    Text("High").tag(Int64(3))
                }
                .pickerStyle(.menu)
                .tint(priorityTint)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)

            Divider().padding(.leading, 50)

            // Sound
            HStack(spacing: 12) {
                Image(systemName: playSound ? "speaker.wave.2" : "speaker.slash")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Text("Sound")
                Spacer()
                Toggle("", isOn: $playSound).labelsHidden()
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)

            Divider().padding(.leading, 50)

            // Photo
            photoRow
        }
    }

    private var photoRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: pendingPhoto == nil ? "camera" : "camera.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Text("Photo")
                Spacer()
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Text(pendingPhoto == nil ? "Add" : "Change")
                        .foregroundStyle(Color.accentColor)
                }
                if pendingPhoto != nil {
                    Button { pendingPhoto = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    .buttonStyle(.row)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)

            if let img = pendingPhoto {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
    }

    // MARK: – Location card

    private var locationCard: some View {
        card {
            HStack(spacing: 12) {
                Image(systemName: "location")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Button { showLocationPicker = true } label: {
                    HStack {
                        Text("Location").foregroundStyle(.primary)
                        Spacer()
                        Text(locationName.isEmpty ? "None" : locationName)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if !hasLocationTrigger {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.row)
                if hasLocationTrigger {
                    Button { locationRadius = 0; locationName = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    .buttonStyle(.row)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)

            if hasLocationTrigger {
                Divider().padding(.leading, 50)
                VStack(spacing: 12) {
                    Picker("", selection: $locationOnArrive) {
                        Text("Arriving").tag(true)
                        Text("Leaving").tag(false)
                    }
                    .pickerStyle(.segmented)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Radius: \(radiusLabel)")
                            .font(.caption).foregroundStyle(.secondary)
                        Slider(value: $locationRadius, in: 30.48...1609.34, step: 30.48)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: – Footer

    private var footerSection: some View {
        VStack(spacing: 0) {
            Button {
                templateName = title.isEmpty ? "" : title
                showSaveTemplate = true
            } label: {
                Label("Save as template", systemImage: "square.stack")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.row)
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 20)
            .padding(.top, 24)

            if editing != nil {
                Divider().padding(.horizontal, 20)
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Delete reminder", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.row)
                .foregroundStyle(.red)
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: – Next fire refresh

    private func refreshNextFires() async {
        if let t = editing {
            let baseId = "task-\(Int(t.createdAt.timeIntervalSince1970 * 1000))"
            nextFireDates = await NotificationsManager.upcomingFireDates(
                baseId: baseId, taskUid: t.uid, limit: 3
            )
        } else {
            nextFireDates = NotificationsManager.previewFireDates(
                kind: repeatKind,
                dueDate: hasFireDate ? fireDate : nil,
                endMinutes: stopMinutesValue,
                limit: 3
            )
        }
    }

    // MARK: – Title suggestions

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

    // MARK: – Quick date chips

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
        .buttonStyle(.row)
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
            editing.notifyMode = notifyMode
            editing.locationLat = locationLat
            editing.locationLng = locationLng
            editing.locationRadius = locationRadius
            editing.locationOnArrive = locationOnArrive
            editing.locationName = locationName
            editing.reminderPriority = priority
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
            item.notifyMode = notifyMode
            item.locationLat = locationLat
            item.locationLng = locationLng
            item.locationRadius = locationRadius
            item.locationOnArrive = locationOnArrive
            item.locationName = locationName
            item.reminderPriority = priority
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
