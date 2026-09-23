import SwiftUI

/// Option B from the Android app: one row per room, one column per period, green = free,
/// grey = class, past periods faded. Tapping a column header filters to rooms free then.
struct ResultView: View {
    @State private var result: DayResult?
    @State private var selected: Set<String> = []
    @State private var searchText = ""
    @State private var hideLabs = false
    @State private var detail: RoomRow?
    @State private var now = AppClock.now()

    private let slots = Periods.slots
    private let roomColumn: CGFloat = 76
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    struct RoomRow: Identifiable, Hashable {
        let room: RoomDay
        let label: RoomLabel
        var id: String { room.roomName }
    }

    var body: some View {
        Group {
            if let result {
                content(result)
            } else {
                Text("还没有查询结果。\n回到首页查询一栋教学楼即可。")
                    .multilineTextAlignment(.center)
                    .foregroundColor(Palette.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Palette.background)
        .navigationTitle(result?.buildingName ?? "查询结果")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索教室，如 218")
        .onAppear { result = Store.shared.result(for: AppClock.now()) }
        .onReceive(ticker) { _ in now = AppClock.now() }
        .sheet(item: $detail) { row in detailSheet(row) }
    }

    private var isToday: Bool {
        guard let result else { return false }
        return Periods.calendar.isDate(result.date, inSameDayAs: now)
    }

    private var minute: Int { Periods.minuteOfDay(now) }
    private var currentPeriod: String? { isToday ? Periods.currentPeriod(atMinute: minute) : nil }
    private var pastPeriods: Set<String> { isToday ? Set(slots).subtracting(Periods.future(slots, atMinute: minute)) : [] }

    private func rows(_ result: DayResult) -> [RoomRow] {
        result.rooms
            .map { RoomRow(room: $0, label: RoomLabel.parse(building: $0.buildingName, room: $0.roomName)) }
            .filter { row in selected.allSatisfy { row.room.freePeriods.contains($0) } }
            .filter { !hideLabs || !$0.label.isLab }
            .filter { searchText.isEmpty || $0.room.roomName.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.label.sortKey < $1.label.sortKey }
    }

    private func content(_ result: DayResult) -> some View {
        let visible = rows(result)
        var floorOrder: [String] = []
        var floors: [String: [RoomRow]] = [:]
        for row in visible {
            if floors[row.label.floorTitle] == nil { floorOrder.append(row.label.floorTitle) }
            floors[row.label.floorTitle, default: []].append(row)
        }
        // A zone every room shares (e.g. "文综" in 博文楼) says nothing per row, so it is hidden.
        let descriptions = Set(result.rooms.map { RoomLabel.parse(building: $0.buildingName, room: $0.roomName).description })
        let showDescription = descriptions.count > 1

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                summary(result, count: visible.count)
                Section {
                    if visible.isEmpty {
                        Text(selected.count > 1 ? "没有在所选时段都空闲的教室\n试试少选一个时段" : "没有符合条件的教室")
                            .multilineTextAlignment(.center)
                            .foregroundColor(Palette.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    }
                    ForEach(floorOrder, id: \.self) { floor in
                        Text("\(floor) · \(floors[floor]?.count ?? 0) 间")
                            .font(.caption.weight(.medium))
                            .foregroundColor(Palette.muted)
                            .padding(.leading, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                        ForEach(floors[floor] ?? []) { row in
                            roomRow(row, showDescription: showDescription)
                        }
                    }
                    Text("绿色＝空闲　灰色＝有课\n教务数据更新于 \(formatted(result.queriedAt))，整学期无课的教室不在列表中")
                        .font(.caption)
                        .foregroundColor(Palette.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(20)
                } header: {
                    header
                }
            }
        }
    }

    private func summary(_ result: DayResult, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selected.isEmpty ? "今天有空闲的教室 \(count) 间" : "\(slots.filter { selected.contains($0) }.map { $0.replacingOccurrences(of: "节", with: "") }.joined(separator: "、")) 节都空的 \(count) 间")
                        .font(.subheadline.weight(.semibold))
                    Text("\(isToday ? "今天" : "") \(result.weekdayName)\(result.weekNumber.map { " · 第\($0)周" } ?? " · 非教学周")")
                        .font(.caption).foregroundColor(Palette.muted)
                }
                Spacer()
                ChipButton(title: "隐藏实验室", selected: hideLabs) { hideLabs.toggle() }
            }
            if result.weekNumber == nil {
                Label("非教学周：没有常规课程，但不保证教室开放", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(Palette.amber)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Palette.amberSoft))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text(selected.isEmpty ? "点时段筛选" : "已筛选")
                    .font(.caption2).foregroundColor(Palette.muted)
                    .frame(width: roomColumn - 4, alignment: .leading)
                ForEach(slots, id: \.self) { slot in
                    let isSelected = selected.contains(slot)
                    let isNow = slot == currentPeriod
                    Button {
                        if isSelected { selected.remove(slot) } else { selected.insert(slot) }
                    } label: {
                        VStack(spacing: 1) {
                            Text(slot.replacingOccurrences(of: "节", with: ""))
                                .font(.system(size: 14, weight: .semibold))
                            Text(isNow ? "现在" : Periods.startMinute(slot).map(Periods.clock) ?? "")
                                .font(.system(size: 10, weight: isNow ? .bold : .regular))
                                .foregroundColor(isNow && !isSelected ? Palette.amber : nil)
                        }
                        .foregroundColor(isSelected ? .white : pastPeriods.contains(slot) ? Palette.muted : Palette.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Palette.green : Color.clear))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isNow ? Palette.amber : isSelected ? Palette.green : Palette.busy, lineWidth: isNow ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
        }
        .background(Palette.background)
    }

    private func roomRow(_ row: RoomRow, showDescription: Bool) -> some View {
        Button { detail = row } label: {
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(row.label.code)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(row.label.isLab ? Palette.muted : Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if showDescription && !row.label.description.isEmpty {
                        Text(row.label.description).font(.caption2).foregroundColor(Palette.muted).lineLimit(1)
                    }
                }
                .frame(width: roomColumn - 4, alignment: .leading)
                ForEach(slots, id: \.self) { slot in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Palette.cell(free: row.room.freePeriods.contains(slot), past: pastPeriods.contains(slot)))
                }
            }
            .frame(height: 42)
            .padding(.horizontal, 12)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func detailSheet(_ row: RoomRow) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.room.roomName).font(.title3.weight(.semibold))
                Text("\(row.room.buildingName) · \(row.label.floorTitle)").font(.subheadline).foregroundColor(Palette.muted)
            }
            ForEach(slots, id: \.self) { slot in
                let free = row.room.freePeriods.contains(slot)
                HStack {
                    Circle().fill(free ? Palette.green : Palette.busy).frame(width: 10, height: 10)
                    Text("\(slot)  \(Periods.timeLabel(slot) ?? "")\(slot == currentPeriod ? "  现在" : "")")
                    Spacer()
                    Text(free ? "空闲" : "有课")
                        .fontWeight(free ? .semibold : .regular)
                        .foregroundColor(free ? Palette.green : Palette.muted)
                }
            }
            Spacer()
        }
        .padding(24)
        .presentationDetents([.medium])
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = Periods.chinaTimeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
