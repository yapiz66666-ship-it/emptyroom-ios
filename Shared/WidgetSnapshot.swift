import Foundation

/// What the home-screen widget shows: a small timetable of the rooms with the most free periods
/// that day. Same rules as the Android widget.
struct WidgetSnapshot {
    static let topRooms = 5

    struct Room: Hashable {
        let code: String
        let freePeriods: Set<String>
        let isLab: Bool
    }

    let buildingName: String
    /// e.g. "今天 星期二" or "明天 星期三".
    let dayTitle: String
    /// e.g. "现在 16:00–17:40", "下一节 19:00–20:40", "明天 08:00 起".
    let timeTitle: String
    let slots: [String]
    /// Period in progress; nil when showing tomorrow or between periods.
    let currentPeriod: String?
    let pastPeriods: Set<String>
    let rooms: [Room]
    let note: String?

    /// Shows today until its last period ends, then tomorrow. [resultFor] computes a day from
    /// the cached term schedule.
    static func build(now: Date, savedAt: Date, resultFor: (Date) -> DayResult?) -> WidgetSnapshot? {
        let slots = Periods.slots
        let minute = Periods.minuteOfDay(now)
        let next = Periods.currentOrNext(slots, atMinute: minute)
        let isTomorrow = next == nil
        let date = isTomorrow ? Periods.calendar.date(byAdding: .day, value: 1, to: now)! : now
        guard let result = resultFor(date) else { return nil }

        let period = next ?? slots[0]
        let start = Periods.startMinute(period).map(Periods.clock) ?? ""
        let end = Periods.endMinute(period).map(Periods.clock) ?? ""
        let started = !isTomorrow && (Periods.startMinute(period).map { minute >= $0 } ?? false)
        let timeTitle = isTomorrow ? "明天 \(start) 起" : started ? "现在 \(start)–\(end)" : "下一节 \(start)–\(end)"
        let past: Set<String> = isTomorrow ? [] : Set(slots).subtracting(Periods.future(slots, atMinute: minute))
        let upcoming = slots.filter { !past.contains($0) }

        // Most free periods in the day; ties go to ordinary classrooms, then to the ones with more
        // free time still ahead, then by floor and code.
        let ranked = result.rooms
            .map { room in (room, RoomLabel.parse(building: room.buildingName, room: room.roomName)) }
            .sorted { lhs, rhs in
                let a = lhs.0, la = lhs.1, b = rhs.0, lb = rhs.1
                if a.freePeriods.count != b.freePeriods.count { return a.freePeriods.count > b.freePeriods.count }
                if la.isLab != lb.isLab { return !la.isLab }
                let aheadA = upcoming.filter { a.freePeriods.contains($0) }.count
                let aheadB = upcoming.filter { b.freePeriods.contains($0) }.count
                if aheadA != aheadB { return aheadA > aheadB }
                return la.sortKey < lb.sortKey
            }
            .prefix(topRooms)
            .map { pair in Room(code: pair.1.code, freePeriods: Set(pair.0.freePeriods), isLab: pair.1.isLab) }

        let ageDays = Int(now.timeIntervalSince(savedAt) / 86_400)
        let note: String? = result.weekNumber == nil ? "非教学周" : ageDays >= 7 ? "数据 \(ageDays) 天未更新" : nil
        return WidgetSnapshot(
            buildingName: result.buildingName,
            dayTitle: "\(isTomorrow ? "明天" : "今天") \(result.weekdayName)",
            timeTitle: timeTitle,
            slots: slots,
            currentPeriod: started ? period : nil,
            pastPeriods: past,
            rooms: Array(ranked),
            note: note
        )
    }
}
