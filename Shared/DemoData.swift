import Foundation

/// A made-up building for screenshots, the widget gallery preview and tests. Not real data.
enum DemoData {
    static let buildingName = "逸夫楼"

    static let payload: TermPayload = {
        let rooms = [
            "逸夫楼132", "逸夫楼137流体力学II", "逸夫楼138流体力学I", "逸夫楼218A", "逸夫楼218B", "逸夫楼240",
            "逸夫楼242精密仪器", "逸夫楼244功能材料", "逸夫楼248高分子化学", "逸夫楼343", "逸夫楼345",
            "逸夫楼537", "逸夫楼542", "逸夫楼639", "逸夫楼649", "逸B08家具智能制造实验室", "逸夫楼217液压气动实验室",
        ]
        let weekdays = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]
        let blocks = ["1-2", "3-4", "5-6", "7-8", "9-10"]
        var rows: [TermPayload.Row] = []
        for (index, room) in rooms.enumerated() {
            // Real data only lists rooms that have classes; an out-of-term row keeps every room listed.
            rows.append(TermPayload.Row(jsmc: room, kkzc: "20", zzdweek: "星期日", jc: "11-12", sjbz: "全部"))
            for (day, weekday) in weekdays.enumerated() {
                // A deterministic mix: some rooms busy twice a day, some never.
                for (slot, block) in blocks.enumerated() where (index * 3 + day * 5 + slot * 7) % 11 < index % 4 {
                    rows.append(TermPayload.Row(jsmc: room, kkzc: "1-16", zzdweek: weekday, jc: block, sjbz: "全部"))
                }
            }
        }
        return TermPayload(academicTerm: "2026-2027-1", firstSaturday: "09月12日", totalWeeks: 20, rows: rows)
    }()

    /// Tuesday of week 3, 16:30 China time.
    static let now: Date = {
        Periods.calendar.date(from: DateComponents(year: 2026, month: 9, day: 22, hour: 16, minute: 30))!
    }()

    static func result(for date: Date) -> DayResult {
        ScheduleParser.day(payload, buildingName: buildingName, date: date, queriedAt: now)
    }
}
