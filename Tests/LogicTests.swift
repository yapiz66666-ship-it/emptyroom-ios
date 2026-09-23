import XCTest

/// Same cases as the Android unit tests (JwxtClassroomListParserTest, RoomLabelTest,
/// WidgetSnapshotTest, WeekExpressionParserTest).
final class LogicTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        Periods.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func row(_ room: String, _ weeks: String, _ weekday: String, _ periods: String, _ type: String = "全部") -> TermPayload.Row {
        TermPayload.Row(jsmc: room, kkzc: weeks, zzdweek: weekday, jc: periods, sjbz: type)
    }

    private func payload(_ rows: TermPayload.Row...) -> TermPayload {
        TermPayload(academicTerm: "2026-2027-1", firstSaturday: "09月12日", totalWeeks: 20, rows: rows)
    }

    // MARK: Schedule parser

    func testWeekFromCalendarAndOverlappingBlocksBusy() {
        // 2026-09-22 is the Tuesday of week 3 (week 1 starts Monday 2026-09-07).
        let result = ScheduleParser.day(payload(
            row("逸夫楼240", "3-6", "星期二", "5-6"),
            row("逸夫楼240", "1-2,6", "星期二", "1-2"),
            row("逸夫楼132", "1-4,10-13", "星期二", "3-10"),
            row("逸夫楼132", "3", "星期三", "1-2")
        ), buildingName: "逸夫楼", date: date(2026, 9, 22), queriedAt: Date())

        XCTAssertEqual(result.weekNumber, 3)
        XCTAssertEqual(result.weekdayName, "星期二")
        let rooms = Dictionary(uniqueKeysWithValues: result.rooms.map { ($0.roomName, $0.freePeriods) })
        XCTAssertEqual(rooms["逸夫楼240"], ["1-2节", "3-4节", "7-8节", "9-10节"])
        XCTAssertEqual(rooms["逸夫楼132"], ["1-2节"])
    }

    func testOddEvenWeekType() {
        let result = ScheduleParser.day(payload(row("逸101", "1-16", "星期二", "1-2", "双周")),
                                        buildingName: "逸夫楼", date: date(2026, 9, 22), queriedAt: Date())
        XCTAssertEqual(result.rooms.first?.freePeriods.count, 5)
    }

    func testOutsideCalendarMeansNoRegularClasses() {
        let result = ScheduleParser.day(payload(row("逸101", "1-20", "星期二", "1-10")),
                                        buildingName: "逸夫楼", date: date(2026, 8, 25), queriedAt: Date())
        XCTAssertNil(result.weekNumber)
        XCTAssertEqual(result.rooms.first?.freePeriods.count, 5)
    }

    func testSpringTermUsesSecondYear() {
        let calendar = TermCalendar.from(term: "2025-2026-2", firstSaturdayText: "03月14日", totalWeeks: 20)
        XCTAssertEqual(calendar?.firstMonday, Periods.calendar.startOfDay(for: date(2026, 3, 9)))
    }

    func testWeekExpressions() {
        XCTAssertTrue(WeekExpression.isActive("1-4,10-13周", week: 11))
        XCTAssertFalse(WeekExpression.isActive("1-4,10-13周", week: 6))
        XCTAssertTrue(WeekExpression.isActive("2-16周(双)", week: 4))
        XCTAssertFalse(WeekExpression.isActive("2-16周(双)", week: 5))
    }

    // MARK: Room labels

    func testBuildingPrefixes() {
        let full = RoomLabel.parse(building: "逸夫楼", room: "逸夫楼650材料制备实验室（二）")
        XCTAssertEqual(full.code, "650")
        XCTAssertEqual(full.description, "材料制备实验室（二）")
        XCTAssertEqual(full.floor, 6)
        XCTAssertTrue(full.isLab)
        XCTAssertEqual(RoomLabel.parse(building: "逸夫楼", room: "逸252装饰与涂料").code, "252")
        XCTAssertEqual(RoomLabel.parse(building: "逸夫楼", room: "逸夫112木材干燥与热改性实验室").code, "112")
    }

    func testLetterSuffixAndBasement() {
        let plain = RoomLabel.parse(building: "逸夫楼", room: "逸夫楼218A")
        XCTAssertEqual(plain.code, "218A")
        XCTAssertEqual(plain.description, "")
        XCTAssertFalse(plain.isLab)
        let basement = RoomLabel.parse(building: "逸夫楼", room: "逸B09材料加工成型")
        XCTAssertEqual(basement.code, "B09")
        XCTAssertEqual(basement.floorTitle, "地下层")
    }

    func testBracketedZoneAndWing() {
        let label = RoomLabel.parse(building: "博文楼", room: "博文楼(文综)北201")
        XCTAssertEqual(label.code, "北201")
        XCTAssertEqual(label.description, "文综")
        XCTAssertEqual(label.floor, 2)
        let full = RoomLabel.parse(building: "博文楼", room: "博文楼（文综）南605")
        XCTAssertEqual(full.code, "南605")
        XCTAssertEqual(full.floor, 6)
    }

    // MARK: Widget

    private let all = ["1-2节", "3-4节", "5-6节", "7-8节", "9-10节"]

    private func result(_ day: Date, _ rooms: [(String, [String])]) -> DayResult {
        DayResult(buildingName: "逸夫楼", date: day, academicTerm: "2026-2027-1", weekNumber: 3, weekdayName: "星期二",
                  calendarStart: nil, calendarEnd: nil,
                  rooms: rooms.map { RoomDay(buildingName: "逸夫楼", roomName: $0.0, freePeriods: $0.1) },
                  queriedAt: Date())
    }

    func testWidgetTopFive() {
        let snapshot = WidgetSnapshot.build(now: date(2026, 9, 22, 16, 30), savedAt: date(2026, 9, 22, 16, 30)) {
            self.result($0, [
                ("逸夫楼650材料制备实验室", self.all),
                ("逸夫楼218A", ["1-2节", "3-4节", "5-6节"]),
                ("逸夫楼345", self.all),
                ("逸夫楼240", ["1-2节"]),
                ("逸夫楼132", ["1-2节", "7-8节", "9-10节"]),
                ("逸夫楼101", ["1-2节", "3-4节", "5-6节", "9-10节"]),
                ("逸夫楼102", ["1-2节", "3-4节"]),
            ])
        }!
        XCTAssertEqual(snapshot.timeTitle, "现在 16:00–17:40")
        XCTAssertEqual(snapshot.currentPeriod, "7-8节")
        XCTAssertEqual(snapshot.pastPeriods, ["1-2节", "3-4节", "5-6节"])
        XCTAssertEqual(snapshot.rooms.map(\.code), ["345", "650", "101", "132", "218A"])
    }

    func testWidgetBetweenPeriods() {
        let snapshot = WidgetSnapshot.build(now: date(2026, 9, 22, 17, 50), savedAt: Date()) {
            self.result($0, [("逸夫楼345", self.all)])
        }!
        XCTAssertEqual(snapshot.timeTitle, "下一节 19:00–20:40")
        XCTAssertNil(snapshot.currentPeriod)
    }

    func testWidgetSwitchesToTomorrow() {
        var asked: Date?
        let snapshot = WidgetSnapshot.build(now: date(2026, 9, 22, 21, 0), savedAt: date(2026, 9, 14, 21, 0)) { day in
            asked = day
            return self.result(day, [("逸夫楼345", self.all)])
        }!
        XCTAssertTrue(Periods.calendar.isDate(asked!, inSameDayAs: date(2026, 9, 23)))
        XCTAssertEqual(snapshot.timeTitle, "明天 08:00 起")
        XCTAssertEqual(snapshot.note, "数据 8 天未更新")
    }

    // MARK: Page detection

    func testPageDetection() {
        XCTAssertEqual(PageDetector.detect(url: "https://http-jwxt-csuft-edu-cn-80.webvpn.csuft.edu.cn/jsxsd/kbcx/kbxx_classroom", title: "", bodyText: ""), .classroomQuery)
        XCTAssertEqual(PageDetector.detect(url: "https://http-jwxt-csuft-edu-cn-80.webvpn.csuft.edu.cn/jsxsd/framework/xsMainV.htmlx", title: "首页", bodyText: ""), .jwxtPage)
        XCTAssertEqual(PageDetector.detect(url: "https://webvpn.csuft.edu.cn/site-nav/home", title: "", bodyText: ""), .webVpnHome)
        XCTAssertEqual(Jwxt.classroomQuery(for: "https://http-jwgl-csuft-edu-cn-80.webvpn.csuft.edu.cn/jsxsd/x"),
                       "https://http-jwgl-csuft-edu-cn-80.webvpn.csuft.edu.cn/jsxsd/kbcx/kbxx_classroom")
    }

    func testDemoDataParses() {
        let result = DemoData.result(for: DemoData.now)
        XCTAssertEqual(result.weekNumber, 3)
        XCTAssertGreaterThan(result.rooms.count, 10)
    }
}
