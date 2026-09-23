import SwiftUI

enum Palette {
    static let green = Color(red: 0x0F / 255, green: 0x76 / 255, blue: 0x6E / 255)
    static let greenSoft = Color(red: 0xE6 / 255, green: 0xF4 / 255, blue: 0xF1 / 255)
    static let freePast = Color(red: 0xA7 / 255, green: 0xD3 / 255, blue: 0xCC / 255)
    static let busy = Color(red: 0xDD / 255, green: 0xE3 / 255, blue: 0xE0 / 255)
    static let busyPast = Color(red: 0xF0 / 255, green: 0xF3 / 255, blue: 0xF2 / 255)
    static let ink = Color(red: 0x17 / 255, green: 0x20 / 255, blue: 0x1D / 255)
    static let muted = Color(red: 0x60 / 255, green: 0x70 / 255, blue: 0x6A / 255)
    static let amber = Color(red: 0xB4 / 255, green: 0x53 / 255, blue: 0x09 / 255)
    static let amberSoft = Color(red: 0xFF / 255, green: 0xF0 / 255, blue: 0xD5 / 255)
    static let background = Color(red: 0xF7 / 255, green: 0xFA / 255, blue: 0xF9 / 255)

    static func cell(free: Bool, past: Bool) -> Color {
        switch (free, past) {
        case (true, true): return freePast
        case (true, false): return green
        case (false, true): return busyPast
        case (false, false): return busy
        }
    }
}

/// The widget's content: the top rooms of the day as a small timetable (green = free, grey =
/// class, past periods faded). Rows split the available height evenly.
struct WidgetMatrixView: View {
    let snapshot: WidgetSnapshot?
    var sharedStorage = true

    var body: some View {
        if let snapshot {
            content(snapshot)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("空教室速查").font(.system(size: 15, weight: .bold)).foregroundColor(Palette.ink)
                Text(sharedStorage ? "打开 App 查询一次教学楼，之后这里每天自动显示空教室" : "小组件读不到 App 的数据（安装时 App Group 未生效）")
                    .font(.system(size: 12)).foregroundColor(Palette.muted)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func content(_ snapshot: WidgetSnapshot) -> some View {
        let roomColumn: CGFloat = snapshot.rooms.contains { $0.code.count >= 4 } ? 50 : 40
        return VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.timeTitle).font(.system(size: 15, weight: .bold)).foregroundColor(Palette.green)
                Spacer(minLength: 4)
                Text("\(snapshot.buildingName) · \(snapshot.dayTitle)")
                    .font(.system(size: 11)).foregroundColor(Palette.muted).lineLimit(1)
            }
            Text(snapshot.note.map { "空闲最多的 \(snapshot.rooms.count) 间 · \($0)" } ?? "空闲最多的 \(snapshot.rooms.count) 间")
                .font(.system(size: 11))
                .foregroundColor(snapshot.note == nil ? Palette.muted : Palette.amber)
                .padding(.bottom, 2)
            HStack(spacing: 3) {
                Color.clear.frame(width: roomColumn, height: 1)
                ForEach(snapshot.slots, id: \.self) { slot in
                    let isNow = slot == snapshot.currentPeriod
                    Text(isNow ? "现在" : slot.replacingOccurrences(of: "节", with: ""))
                        .font(.system(size: 10, weight: isNow ? .bold : .regular))
                        .foregroundColor(isNow ? Palette.amber : Palette.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(snapshot.rooms, id: \.self) { room in
                HStack(spacing: 3) {
                    Text(room.code)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(room.isLab ? Palette.muted : Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: roomColumn, alignment: .leading)
                    ForEach(snapshot.slots, id: \.self) { slot in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Palette.cell(free: room.freePeriods.contains(slot), past: snapshot.pastPeriods.contains(slot)))
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}
