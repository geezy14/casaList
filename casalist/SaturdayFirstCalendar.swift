import Foundation

/// Casalist convention: week starts on Saturday. iOS / en_US default
/// is Sunday, but Geezy wants the app's date pickers + (future)
/// calendar grids to anchor the week on Saturday so the weekend reads
/// as one continuous block at the start.
///
/// Apply via `.environment(\.calendar, .casalist)` on the app root.
/// Every DatePicker / Calendar-aware UI underneath inherits it.
/// Use `Calendar.casalist` directly for non-UI date math (formatting,
/// week-of-year, etc.) so day-of-week semantics stay consistent.
extension Calendar {
    static let casalist: Calendar = {
        var cal = Calendar.current
        // 1 = Sunday … 7 = Saturday (iOS weekday convention).
        cal.firstWeekday = 7
        return cal
    }()
}
