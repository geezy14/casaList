import SwiftUI
import CoreData
import PhotosUI

/// Compact reminder sheet modeled after Apple Reminders' inline-picker
/// pattern: title at top, a small row of icon chips for the optional
/// attributes (when, repeat, who, where, stop-time), and tapping a
/// chip expands its picker inline below the strip. No more scrolling
/// through five Form sections.
struct AddReminderView: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName: String = ""
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var familyMembers: FetchedResults<FamilyMember>
    /// All live reminders — used to mine title suggestions when the
    /// user starts typing a new reminder title.
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
    /// Which inline pickers are currently open. In add mode this is
    /// empty until the user taps a chip. In edit mode every chip that
    /// already has data is expanded so you can see everything without
    /// hunting.
    @State private var expandedChips: Set<Chip>
    /// Photo attachment buffer. Held in @State until save() because
    /// the disk path is keyed by the reminder's UID, which only
    /// exists after the TaskItem is inserted.
    @State private var pendingPhoto: UIImage? = nil
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var showSaveTemplate: Bool = false
    @State private var templateName: String = ""
    @State private var colorTag: ReminderColorTag
    @State private var playSound: Bool
    @State private var showColorWheel: Bool = false

    enum Chip: Hashable, CaseIterable { case when, repeats, notify, location, photo, tag, sound, stopTime }

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
            // Pre-expand any chip that already has data so the user
            // can see everything they previously set at a glance.
            var pre: Set<Chip> = []
            if t.dueDate != nil { pre.insert(.when) }
            if !t.effectiveRepeatKind.isEmpty { pre.insert(.repeats) }
            if let a = t.assignee, !a.isEmpty { pre.insert(.notify) }
            if t.locationRadius > 0 { pre.insert(.location) }
            if t.repeatEndMinutes > 0 { pre.insert(.stopTime) }
            if ReminderPhotoStore.hasImage(for: t.uid) {
                pre.insert(.photo)
            }
            let existingTag = ReminderColorTagStore.tag(for: t.uid)
            if existingTag != .none { pre.insert(.tag) }
            _colorTag = State(initialValue: existingTag)
            _playSound = State(initialValue: ReminderSoundStore.playsSound(for: t.uid))
            _expandedChips = State(initialValue: pre)
            _pendingPhoto = State(initialValue: ReminderPhotoStore.image(for: t.uid))
        } else if let tpl = template {
            // New-from-template path. Seed every state from the
            // template, with sensible defaults where the template
            // doesn't speak (e.g. one-shot date moves to "today at
            // template time" if hasFireTime was set).
            _title = State(initialValue: tpl.title)
            _repeatKind = State(initialValue: tpl.repeatKind)
            _hasFireDate = State(initialValue: tpl.hasFireTime)
            let cal = Calendar.current
            let now = Date()
            let seeded = cal.date(bySettingHour: tpl.fireHour,
                                  minute: tpl.fireMinute,
                                  second: 0,
                                  of: now) ?? now.addingTimeInterval(3600)
            _fireDate = State(initialValue: seeded)
            _hasStopTime = State(initialValue: tpl.repeatEndMinutes > 0)
            let stopAnchor = cal.date(byAdding: .minute,
                                      value: tpl.repeatEndMinutes > 0 ? Int(tpl.repeatEndMinutes) : 22 * 60,
                                      to: cal.startOfDay(for: now)) ?? now
            _stopDate = State(initialValue: stopAnchor)
            _assignee = State(initialValue: tpl.assignee)
            _locationLat = State(initialValue: tpl.locationLat)
            _locationLng = State(initialValue: tpl.locationLng)
            _locationRadius = State(initialValue: tpl.locationRadius)
            _locationName = State(initialValue: tpl.locationName)
            _locationOnArrive = State(initialValue: tpl.locationOnArrive)
            // Pre-expand every chip the template seeded so the user
            // sees everything carried over.
            var pre: Set<Chip> = []
            if tpl.hasFireTime { pre.insert(.when) }
            if !tpl.repeatKind.isEmpty { pre.insert(.repeats) }
            if !tpl.assignee.isEmpty { pre.insert(.notify) }
            if tpl.locationRadius > 0 { pre.insert(.location) }
            if tpl.repeatEndMinutes > 0 { pre.insert(.stopTime) }
            _expandedChips = State(initialValue: pre)
            _colorTag = State(initialValue: .none)
            _playSound = State(initialValue: true)
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
            _expandedChips = State(initialValue: [])
            _colorTag = State(initialValue: .none)
            _playSound = State(initialValue: true)
        }
    }

    // MARK: – Computed

    private var hasLocationTrigger: Bool { locationRadius > 0 }

    /// One foot in meters. `locationRadius` is stored in meters
    /// because CoreLocation's `CLCircularRegion` API speaks meters.
    private let metersPerFoot: Double = 0.3048

    /// Human display for the radius — feet under 1000 ft, miles above.
    private var radiusLabel: String {
        let ft = locationRadius / metersPerFoot
        if ft >= 1000 {
            let mi = ft / 5280
            return String(format: "%.1f mi", mi)
        }
        return "\(Int(ft.rounded())) ft"
    }
    private var hasRepeat: Bool { !repeatKind.isEmpty }
    private var hasAssignee: Bool { !assignee.trimmingCharacters(in: .whitespaces).isEmpty }
    private var isCadenceKind: Bool {
        ["hourly", "every2h", "every4h", "every8h", "every12h"].contains(repeatKind)
    }
    private var isPinned: Bool { repeatKind.isEmpty && !hasFireDate }
    private var dailyOnlyTime: Bool { repeatKind == "daily" }

    private var repeatRowLabel: String {
        if repeatKind.isEmpty { return "Doesn't repeat" }
        if let rule = RepeatRule.decode(repeatKind) { return rule.label }
        if let rule = RepeatRule.fromLegacy(repeatKind) { return rule.label }
        return repeatKind.capitalized
    }

    private var whenSummary: String {
        if isPinned { return "No alert" }
        let f = DateFormatter()
        if Calendar.current.isDateInToday(fireDate) {
            f.dateFormat = "'Today' h:mm a"
        } else if Calendar.current.isDateInTomorrow(fireDate) {
            f.dateFormat = "'Tmrw' h:mm a"
        } else {
            f.dateFormat = "MMM d · h:mm a"
        }
        return f.string(from: fireDate)
    }

    // MARK: – Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    titleCard
                    // Edit-mode-only: show the 30-day completion
                    // heatmap if this reminder has a cadence that
                    // tracks streaks AND any completion data.
                    if let editing,
                       ["daily", "weekly", "monthly", "yearly"].contains(editing.effectiveRepeatKind),
                       !ReminderStreak.completionDays(for: editing.uid).isEmpty {
                        ReminderStreakHeatmap(taskUid: editing.uid)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                    }
                    chipStrip
                    // Render each expanded chip's panel in a stable
                    // order — picking a different chip never reshuffles
                    // an already-open panel.
                    ForEach(Chip.allCases, id: \.self) { chip in
                        if expandedChips.contains(chip) {
                            panel(for: chip)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    footerLine
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
                    .padding(.top, 4)
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
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .animation(.easeInOut(duration: 0.2), value: expandedChips)
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
                ColorWheelSheet(tag: $colorTag)
                    .presentationDetents([.height(360)])
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog(
                "Delete reminder?",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteReminder() }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Save as template", isPresented: $showSaveTemplate) {
                TextField("Template name", text: $templateName)
                Button("Save") { persistTemplate() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Templates save the cadence, assignee, location, and stop time — but not photos or a fixed one-shot date.")
            }
        }
    }

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

    // MARK: – Top sub-views

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("What do you want to remember?", text: $title, axis: .vertical)
                .font(.system(size: 18, weight: .semibold))
                .textInputAutocapitalization(.sentences)
                .lineLimit(1...4)
            if !titleSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(titleSuggestions, id: \.self) { suggestion in
                            Button {
                                title = suggestion
                            } label: {
                                Text(suggestion)
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

    /// Recent reminder titles that start with the user's current input
    /// (case-insensitive). Pulls from in-app history + the existing
    /// reminders list + saved templates. Suppressed when the input is
    /// empty or already matches an existing title exactly.
    private var titleSuggestions: [String] {
        let typed = title.trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty else { return [] }
        let needle = typed.lowercased()
        var seen: Set<String> = [typed.lowercased()]
        var out: [String] = []
        // Source 1: existing reminders' task names.
        for t in existingReminders {
            let name = t.task.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            let key = name.lowercased()
            if seen.contains(key) { continue }
            if key.hasPrefix(needle) {
                out.append(name)
                seen.insert(key)
            }
            if out.count >= 5 { break }
        }
        // Source 2: saved templates' reminder titles.
        if out.count < 5 {
            for tpl in ReminderTemplateStore.loadAll() {
                let name = tpl.title.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { continue }
                let key = name.lowercased()
                if seen.contains(key) { continue }
                if key.hasPrefix(needle) {
                    out.append(name)
                    seen.insert(key)
                }
                if out.count >= 5 { break }
            }
        }
        return out
    }

    private var chipStrip: some View {
        // 4 always-visible chips plus a 5th when the cadence supports
        // a stop time. Apple Reminders uses a horizontal scroller; we
        // do the same so future additions don't squeeze the row.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chipButton(.when,    icon: "calendar.badge.clock", filled: !isPinned)
                chipButton(.repeats, icon: "repeat",               filled: hasRepeat)
                chipButton(.notify,  icon: "person.crop.circle",   filled: hasAssignee)
                chipButton(.location,icon: "mappin.and.ellipse",   filled: hasLocationTrigger)
                chipButton(.photo,   icon: "camera",               filled: pendingPhoto != nil)
                chipButton(.tag,     icon: "tag.fill",             filled: colorTag != .none)
                chipButton(.sound,   icon: playSound ? "speaker.wave.2.fill" : "speaker.slash.fill",
                           filled: !playSound)
                if isCadenceKind {
                    chipButton(.stopTime, icon: "moon.zzz",        filled: hasStopTime)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func chipButton(_ chip: Chip, icon: String, filled: Bool) -> some View {
        let isActive = expandedChips.contains(chip)
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isActive {
                    expandedChips.remove(chip)
                } else {
                    expandedChips.insert(chip)
                }
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(filled ? Color.accentColor : Color.secondary)
                .frame(width: 50, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isActive ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
                )
                .overlay(alignment: .topTrailing) {
                    if filled {
                        Circle().fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                            .padding(6)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func panel(for chip: Chip) -> some View {
        switch chip {
        case .when:     whenPanel
        case .repeats:  repeatsPanel
        case .notify:   notifyPanel
        case .location: locationPanel
        case .photo:    photoPanel
        case .tag:      tagPanel
        case .sound:    soundPanel
        case .stopTime: stopTimePanel
        }
    }

    private var tagPanel: some View {
        panelCard {
            VStack(alignment: .leading, spacing: 12) {
                panelHeader("Color tag", icon: "tag.fill")
                HStack(spacing: 12) {
                    colorWheelSwatch
                    VStack(alignment: .leading, spacing: 2) {
                        Text(colorTag.isCustom ? colorTag.swiftUIColor.hexString : "No tag set")
                            .font(.system(size: 14, weight: .semibold, design: colorTag.isCustom ? .monospaced : .default))
                        Text("Tap the wheel to pick a color")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                if colorTag.isCustom {
                    Button {
                        colorTag = .none
                    } label: {
                        Label("Remove tag", systemImage: "xmark.circle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Text("Adds a colored stripe to the reminder card so the family categorize at a glance.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// Color-wheel swatch. Tapping opens a sheet with a real
    /// ColorPicker + hex input field for direct typing. Inline
    /// ColorPicker overlays were unreliable — the SwiftUI label-less
    /// ColorPicker doesn't always intercept taps when stacked under
    /// another shape. Real sheet sidesteps the issue and gives us
    /// room for the hex field.
    private var colorWheelSwatch: some View {
        let isCustom = colorTag.isCustom
        return Button { showColorWheel = true } label: {
            ZStack {
                if isCustom {
                    Circle().fill(colorTag.swiftUIColor).frame(width: 32, height: 32)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                } else {
                    Circle()
                        .fill(AngularGradient(
                            gradient: Gradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .pink, .red]),
                            center: .center
                        ))
                        .frame(width: 32, height: 32)
                }
            }
            .overlay(
                Circle().stroke(Color.primary.opacity(isCustom ? 0.4 : 0), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var soundPanel: some View {
        panelCard {
            VStack(alignment: .leading, spacing: 10) {
                panelHeader("Sound", icon: "speaker.wave.2.fill")
                Toggle("Play sound when fired", isOn: $playSound)
                Text(playSound
                     ? "Uses the system notification sound."
                     : "Silent — the reminder banner shows without audio.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var photoPanel: some View {
        panelCard {
            VStack(alignment: .leading, spacing: 10) {
                panelHeader("Photo", icon: "camera")
                if let img = pendingPhoto {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                HStack(spacing: 10) {
                    PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                        Label(pendingPhoto == nil ? "Choose photo" : "Replace photo",
                              systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    }
                    if pendingPhoto != nil {
                        Button(role: .destructive) {
                            pendingPhoto = nil
                            pickerItem = nil
                        } label: {
                            Image(systemName: "trash")
                                .frame(width: 48, height: 48)
                                .background(Circle().fill(Color.red.opacity(0.12)))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Stays on this device — photos aren't synced to the household.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    await MainActor.run { pendingPhoto = img }
                }
            }
        }
    }

    // MARK: – Panels

    private var whenPanel: some View {
        panelCard {
            VStack(alignment: .leading, spacing: 10) {
                panelHeader("When", icon: "calendar.badge.clock")
                // Opening this panel implies "I want to set a time."
                // Auto-promote pinned → scheduled with a sensible
                // default so the user immediately sees the picker
                // controls. Tapping "Make pinned" at the bottom is
                // the explicit opt-out.
                if !dailyOnlyTime {
                    whenQuickPicks
                }
                if dailyOnlyTime {
                    DatePicker("Time", selection: $fireDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                } else {
                    DatePicker("Date", selection: $fireDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    DatePicker("Time", selection: $fireDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                }
                if repeatKind.isEmpty {
                    Button {
                        hasFireDate = false
                        expandedChips.remove(.when)
                    } label: {
                        Label("Make pinned (no alert)", systemImage: "pin")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
        }
        .onAppear {
            // Auto-flip to scheduled on first sight of the panel —
            // ensures pinned reminders aren't stuck in a chicken-and-
            // egg state where the picker is shown but hasFireDate is
            // still false.
            if !hasFireDate && repeatKind.isEmpty {
                hasFireDate = true
                fireDate = defaultTimeOnTodayOrLater()
            }
        }
    }

    /// Horizontal scroller of quick-set date chips for the When panel.
    /// Each one snaps `fireDate` to a sensible default; the highlight
    /// is mutually exclusive (priority: Today → Tomorrow → This
    /// weekend → Next week → none).
    private var whenQuickPicks: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today) ?? today
        let weekendDay = upcomingSaturday(from: today, cal: cal)
        let nextWeek = cal.date(byAdding: .day, value: 7, to: today) ?? today

        // Compute which chip "wins" so highlights never collide
        // (e.g. when today already IS Saturday, "Today" wins over
        // "This weekend"; without this, both lit up).
        let selected = selectedQuickPick(
            cal: cal,
            weekendDay: weekendDay,
            nextWeek: nextWeek
        )

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                whenChip(
                    label: "Today",
                    isOn: selected == .today,
                    target: defaultTimeOnTodayOrLater()
                )
                whenChip(
                    label: "Tomorrow",
                    isOn: selected == .tomorrow,
                    target: cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
                )
                // Hide "This weekend" when today is Saturday or Sunday
                // — the Today chip already covers the same date, so a
                // separate chip is just redundant.
                let todayWeekday = cal.component(.weekday, from: today)
                let isAlreadyWeekend = (todayWeekday == 7 || todayWeekday == 1)
                if !isAlreadyWeekend {
                    whenChip(
                        label: "This weekend",
                        isOn: selected == .weekend,
                        target: cal.date(bySettingHour: 10, minute: 0, second: 0, of: weekendDay) ?? weekendDay
                    )
                }
                whenChip(
                    label: "Next week",
                    isOn: selected == .nextWeek,
                    target: cal.date(bySettingHour: 9, minute: 0, second: 0, of: nextWeek) ?? nextWeek
                )
            }
        }
    }

    private enum QuickPick { case today, tomorrow, weekend, nextWeek }

    /// Pick the best-matching quick-pick for the current fireDate.
    /// Priority is Today → Tomorrow → This weekend → Next week so
    /// chips never light up simultaneously.
    private func selectedQuickPick(cal: Calendar, weekendDay: Date, nextWeek: Date) -> QuickPick? {
        if cal.isDateInToday(fireDate) { return .today }
        if cal.isDateInTomorrow(fireDate) { return .tomorrow }
        if cal.isDate(fireDate, inSameDayAs: weekendDay) { return .weekend }
        if cal.isDate(fireDate, inSameDayAs: nextWeek) { return .nextWeek }
        return nil
    }

    /// Returns an "Today" target time: the current time + 1 hour,
    /// rounded to the nearest hour. If +1h overflows into tomorrow
    /// (e.g. you're tapping at 11:30 PM), clamp to today's last hour
    /// so the chip stays meaningful.
    private func defaultTimeOnTodayOrLater() -> Date {
        let cal = Calendar.current
        let now = Date()
        let plusHour = now.addingTimeInterval(3600)
        if cal.isDateInToday(plusHour) { return plusHour }
        // Tapped late — anchor to 11 PM today.
        let today = cal.startOfDay(for: now)
        return cal.date(bySettingHour: 23, minute: 0, second: 0, of: today) ?? now
    }

    /// First Saturday >= today. If today IS Saturday, returns today.
    /// (The chip is hidden in that case anyway via the
    /// `isAlreadyWeekend` check in whenQuickPicks.)
    private func upcomingSaturday(from base: Date, cal: Calendar) -> Date {
        let weekday = cal.component(.weekday, from: base)   // 1 = Sun … 7 = Sat
        let daysUntilSat = (7 - weekday + 7) % 7
        return cal.date(byAdding: .day, value: daysUntilSat, to: base) ?? base
    }

    private func whenChip(label: String, isOn: Bool, target: Date) -> some View {
        Button {
            hasFireDate = true
            fireDate = target
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .heavy))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .background(
                    Capsule().fill(isOn ? Color.accentColor : Color(.tertiarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }

    private var repeatsPanel: some View {
        panelCard {
            VStack(alignment: .leading, spacing: 10) {
                panelHeader("Repeats", icon: "repeat")
                Button { showCustomRepeat = true } label: {
                    HStack {
                        Text(repeatRowLabel).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private var notifyPanel: some View {
        panelCard {
            VStack(alignment: .leading, spacing: 10) {
                panelHeader("Notify", icon: "person.crop.circle")
                Picker(selection: $assignee) {
                    Text("Everyone in household").tag("")
                    ForEach(familyMembers, id: \.uid) { m in
                        Text(m.name).tag(m.name)
                    }
                } label: { Text("Who gets the alert") }
                .pickerStyle(.menu)
                Text(assignee.isEmpty
                     ? "Every device in your household will fire this reminder."
                     : "Only \(assignee)'s phone will fire this reminder.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var locationPanel: some View {
        panelCard {
            VStack(alignment: .leading, spacing: 10) {
                panelHeader("Location", icon: "mappin.and.ellipse")
                // Saved locations — quick-tap chips for places
                // defined in Settings.
                let saved = SavedLocationsStore.loadAll()
                if !saved.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(saved) { s in
                                Button {
                                    locationLat = s.latitude
                                    locationLng = s.longitude
                                    locationName = s.label
                                } label: {
                                    Label(s.label, systemImage: "mappin.circle.fill")
                                        .font(.system(size: 12, weight: .heavy))
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                Button { showLocationPicker = true } label: {
                    HStack {
                        Text(locationName.isEmpty ? "Pick a place" : locationName)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                if locationLat != 0 || locationLng != 0 {
                    LocationMiniMap(
                        latitude: locationLat,
                        longitude: locationLng,
                        title: locationName.isEmpty ? "Reminder" : locationName,
                        radiusMeters: locationRadius
                    )
                }
                Picker("Fire when", selection: $locationOnArrive) {
                    Text("Arriving").tag(true)
                    Text("Leaving").tag(false)
                }
                .pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Radius")
                        Spacer()
                        Text(radiusLabel).foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { locationRadius / metersPerFoot },
                            set: { locationRadius = $0 * metersPerFoot }
                        ),
                        in: 100...5280,
                        step: 50
                    )
                }
                Text("Needs Always location permission to fire while Casalist is in the background.")
                    .font(.caption).foregroundStyle(.secondary)
                Button {
                    locationLat = 0
                    locationLng = 0
                    locationRadius = 0
                    locationName = ""
                    expandedChips.remove(.location)
                } label: {
                    Label("Remove location trigger", systemImage: "xmark.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .onAppear {
            // Opening the chip = wants location trigger. Auto-arm
            // the defaults so all controls are immediately usable.
            if locationRadius == 0 {
                LocationReminderService.shared.requestAuthorization()
                locationRadius = 500 * metersPerFoot
                if locationLat == 0 && locationLng == 0 {
                    // Prompt for a place since the user clearly
                    // wants to set one — no separate "pick a place"
                    // step.
                    showLocationPicker = true
                }
            }
        }
    }

    private var stopTimePanel: some View {
        panelCard {
            VStack(alignment: .leading, spacing: 10) {
                panelHeader("Stop time", icon: "moon.zzz")
                DatePicker("Stop at", selection: $stopDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                Text("Notifications fire between the start time and the stop time each day. Set stop > start.")
                    .font(.caption).foregroundStyle(.secondary)
                Button {
                    hasStopTime = false
                    expandedChips.remove(.stopTime)
                } label: {
                    Label("Remove stop time", systemImage: "xmark.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .onAppear {
            if !hasStopTime { hasStopTime = true }
        }
    }

    // MARK: – Helpers

    private func panelCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private func panelHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(.tint)
            Text(title).font(.system(size: 13, weight: .heavy)).tracking(0.6)
            Spacer()
        }
    }

    private var footerLine: some View {
        Text(footerText)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private var footerText: String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d 'at' h:mm a"
        let dateStr = f.string(from: fireDate)
        if hasLocationTrigger {
            let where_ = locationName.isEmpty ? "the saved location" : locationName
            let dir = locationOnArrive ? "arriving at" : "leaving"
            return "Fires when \(dir) \(where_)."
        }
        switch repeatKind {
        case "":
            if hasFireDate { return "Fires once on \(dateStr)." }
            return "Pinned reminder — no notifications, just visible on Home."
        case "hourly":
            return "Fires every hour at minute \(Calendar.current.component(.minute, from: fireDate))."
        case "every2h":  return "Fires every 2 hours, anchored to the chosen time of day."
        case "every4h":  return "Fires every 4 hours, anchored to the chosen time of day."
        case "every8h":  return "Fires every 8 hours, anchored to the chosen time of day."
        case "every12h": return "Fires every 12 hours, anchored to the chosen time of day."
        case "daily":
            f.dateFormat = "h:mm a"
            return "Fires every day at \(f.string(from: fireDate))."
        case "weekly":
            f.dateFormat = "EEEE 'at' h:mm a"
            return "Fires every \(f.string(from: fireDate))."
        case "monthly":
            f.dateFormat = "h:mm a"
            let day = Calendar.current.component(.day, from: fireDate)
            return "Fires every month on day \(day) at \(f.string(from: fireDate))."
        case "yearly":
            f.dateFormat = "MMM d 'at' h:mm a"
            return "Fires every year on \(f.string(from: fireDate))."
        default:
            if let rule = RepeatRule.decode(repeatKind) {
                return "Fires \(rule.label.lowercased())."
            }
            return ""
        }
    }

    private var stopMinutesValue: Int64 {
        guard isCadenceKind, hasStopTime else { return 0 }
        let cal = Calendar.current
        let stopMin = cal.component(.hour, from: stopDate) * 60 + cal.component(.minute, from: stopDate)
        let startMin = cal.component(.hour, from: fireDate) * 60 + cal.component(.minute, from: fireDate)
        guard stopMin > startMin else { return 0 }
        return Int64(stopMin)
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
        // Photo lives on disk keyed by target.uid (now that the task
        // is saved, the uid exists). Write or delete based on the
        // current buffer state.
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
        if let editing {
            ReminderLinkService.shared.unmirror(uid: editing.uid)
            ReminderPhotoStore.delete(for: editing.uid)
            editing.softDelete()
            try? moc.save()
            let ctx = moc
            Task { await NotificationsManager.syncFromContext(ctx) }
            dismiss()
        }
    }
}
