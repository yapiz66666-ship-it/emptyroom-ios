import Foundation

/// A building's whole-term class list as returned by the jwxt classroom API, stored as-is so any
/// day of the term can be computed offline (by the app and by the widget).
struct TermPayload: Codable {
    var academicTerm: String
    var firstSaturday: String
    var totalWeeks: Int
    var rows: [Row]

    struct Row: Codable {
        var jsmc: String
        var kkzc: String
        var zzdweek: String
        var jc: String
        var sjbz: String
    }
}

struct RoomDay: Hashable {
    let buildingName: String
    let roomName: String
    let freePeriods: [String]
}

/// Free rooms of one building on one day.
struct DayResult {
    let buildingName: String
    let date: Date
    let academicTerm: String
    let weekNumber: Int?
    let weekdayName: String
    let calendarStart: Date?
    let calendarEnd: Date?
    let rooms: [RoomDay]
    let queriedAt: Date
}

/// Week 1 of the term and how many weeks it has.
struct TermCalendar {
    let firstMonday: Date
    let totalWeeks: Int

    var lastSunday: Date {
        Periods.calendar.date(byAdding: .day, value: totalWeeks * 7 - 1, to: firstMonday)!
    }

    func week(of date: Date) -> Int? {
        let calendar = Periods.calendar
        let days = calendar.dateComponents([.day], from: firstMonday, to: calendar.startOfDay(for: date)).day ?? -1
        guard days >= 0 else { return nil }
        let week = days / 7 + 1
        return week <= totalWeeks ? week : nil
    }

    /// The weekly calendar only prints month/day for the first Saturday (e.g. "09月12日"); the
    /// year comes from the term code: autumn terms ("-1") start in the first year unless the
    /// month is before July, spring terms ("-2") in the second.
    static func from(term: String, firstSaturdayText: String, totalWeeks: Int) -> TermCalendar? {
        guard totalWeeks > 0,
              let termMatch = firstMatch(#"^(\d{4})-(\d{4})-([12])"#, in: term),
              let dayMatch = firstMatch(#"(\d{1,2})月(\d{1,2})日"#, in: firstSaturdayText),
              let firstYear = Int(termMatch[1]), let secondYear = Int(termMatch[2]),
              let month = Int(dayMatch[1]), let day = Int(dayMatch[2])
        else { return nil }
        let year = termMatch[3] == "2" || month < 7 ? secondYear : firstYear
        let calendar = Periods.calendar
        guard let saturday = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              let monday = calendar.date(byAdding: .day, value: -5, to: saturday)
        else { return nil }
        return TermCalendar(firstMonday: monday, totalWeeks: totalWeeks)
    }
}

enum ScheduleParser {
    /// The five two-period blocks and the single periods each covers.
    static let blocks: [(String, [Int])] = [
        ("1-2节", [1, 2]), ("3-4节", [3, 4]), ("5-6节", [5, 6]), ("7-8节", [7, 8]), ("9-10节", [9, 10]),
    ]
    static let weekdayNames = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]

    static func weekdayName(of date: Date) -> String {
        // Calendar weekday: 1 = Sunday ... 7 = Saturday.
        let weekday = Periods.calendar.component(.weekday, from: date)
        return weekdayNames[(weekday + 5) % 7]
    }

    /// Free two-period blocks per room on [date]. A room is free in a block when no class
    /// active in that week and weekday overlaps it. Rooms with no free block are left out.
    static func day(_ payload: TermPayload, buildingName: String, date: Date, queriedAt: Date) -> DayResult {
        let calendar = TermCalendar.from(
            term: payload.academicTerm,
            firstSaturdayText: payload.firstSaturday,
            totalWeeks: payload.totalWeeks
        )
        let week = calendar?.week(of: date)
        let weekday = weekdayName(of: date)

        var order: [String] = []
        var occupied: [String: Set<Int>] = [:]
        for row in payload.rows {
            let room = row.jsmc.trimmingCharacters(in: .whitespaces)
            guard !room.isEmpty else { continue }
            if occupied[room] == nil {
                occupied[room] = []
                order.append(room)
            }
            guard let week, row.zzdweek.trimmingCharacters(in: .whitespaces) == weekday else { continue }
            guard WeekExpression.isActive(row.kkzc + "周" + parity(of: row.sjbz), week: week) else { continue }
            occupied[room]!.formUnion(periods(of: row.jc))
        }

        let rooms = order.compactMap { room -> RoomDay? in
            let busy = occupied[room] ?? []
            let free = blocks.filter { block in block.1.allSatisfy { !busy.contains($0) } }.map { $0.0 }
            return free.isEmpty ? nil : RoomDay(buildingName: buildingName, roomName: room, freePeriods: free)
        }
        return DayResult(
            buildingName: buildingName,
            date: Periods.calendar.startOfDay(for: date),
            academicTerm: payload.academicTerm,
            weekNumber: week,
            weekdayName: weekday,
            calendarStart: calendar?.firstMonday,
            calendarEnd: calendar?.lastSunday,
            rooms: rooms,
            queriedAt: queriedAt
        )
    }

    static func periods(of text: String) -> Set<Int> {
        var result = Set<Int>()
        for part in text.split(whereSeparator: { $0 == "," || $0 == "，" }) {
            let bounds = part.split(separator: "-").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if bounds.count == 1 { result.insert(bounds[0]) }
            if bounds.count == 2, bounds[0] <= bounds[1] { result.formUnion(bounds[0]...bounds[1]) }
        }
        return result
    }

    private static func parity(of weekType: String) -> String {
        if weekType.contains("单") { return "(单)" }
        if weekType.contains("双") { return "(双)" }
        return ""
    }
}

/// Capture groups of the first match of [pattern] in [text] (index 0 = whole match).
func firstMatch(_ pattern: String, in text: String) -> [String]? {
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    else { return nil }
    return (0..<match.numberOfRanges).map { index in
        Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
    }
}
