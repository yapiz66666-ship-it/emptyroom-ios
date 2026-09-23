import Foundation

/// Class periods of the day, in China time. Mirrors PeriodUtils on Android.
enum Periods {
    /// The five two-period blocks the app works with.
    static let slots = ["1-2节", "3-4节", "5-6节", "7-8节", "9-10节"]

    /// Start/end as minutes since midnight.
    private static let schedule: [String: (start: Int, end: Int)] = [
        "1-2节": (8 * 60, 9 * 60 + 40),
        "3-4节": (10 * 60, 11 * 60 + 40),
        "5-6节": (14 * 60, 15 * 60 + 40),
        "7-8节": (16 * 60, 17 * 60 + 40),
        "9-10节": (19 * 60, 20 * 60 + 40),
        "11-12节": (20 * 60 + 50, 22 * 60 + 30),
    ]

    static let chinaTimeZone = TimeZone(identifier: "Asia/Shanghai")!

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = chinaTimeZone
        calendar.locale = Locale(identifier: "zh_CN")
        return calendar
    }

    static func minuteOfDay(_ date: Date) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    static func startMinute(_ period: String) -> Int? { schedule[period]?.start }

    static func endMinute(_ period: String) -> Int? { schedule[period]?.end }

    static func clock(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }

    static func timeLabel(_ period: String) -> String? {
        guard let span = schedule[period] else { return nil }
        return "\(clock(span.start))-\(clock(span.end))"
    }

    static func currentPeriod(atMinute minute: Int) -> String? {
        slots.first { period in
            guard let span = schedule[period] else { return false }
            return minute >= span.start && minute < span.end
        }
    }

    /// The period in progress, else the next one to start, else nil once the day is over.
    static func currentOrNext(_ periods: [String], atMinute minute: Int) -> String? {
        periods.first { (endMinute($0) ?? 0) > minute }
    }

    /// Periods that have not ended yet at [minute].
    static func future(_ periods: [String], atMinute minute: Int) -> [String] {
        periods.filter { endMinute($0).map { minute < $0 } ?? true }
    }

    /// Periods in timetable order; unknown labels go last.
    static func ordered(_ periods: [String]) -> [String] {
        let known = slots + ["11-12节"]
        var seen = Set<String>()
        return periods.filter { seen.insert($0).inserted }
            .sorted { (known.firstIndex(of: $0) ?? Int.max) < (known.firstIndex(of: $1) ?? Int.max) }
    }
}

/// "Now", overridable for screenshots and tests.
enum AppClock {
    static var override: Date?
    static func now() -> Date { override ?? Date() }
}
