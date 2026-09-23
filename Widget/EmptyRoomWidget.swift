import SwiftUI
import WidgetKit

struct RoomEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let sharedStorage: Bool
}

/// Offline timeline: one entry now and one at every period start/end today, plus just after
/// midnight, each computed from the term schedule the app stored in the App Group.
struct RoomProvider: TimelineProvider {
    func placeholder(in context: Context) -> RoomEntry {
        RoomEntry(date: DemoData.now, snapshot: demoSnapshot(), sharedStorage: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (RoomEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(entry(at: Date()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RoomEntry>) -> Void) {
        let now = Date()
        let calendar = Periods.calendar
        let startOfDay = calendar.startOfDay(for: now)
        let boundaries = Periods.slots
            .flatMap { [Periods.startMinute($0), Periods.endMinute($0)].compactMap { $0 } }
            .compactMap { calendar.date(byAdding: .minute, value: $0, to: startOfDay) }
            .filter { $0 > now }
        let midnight = calendar.date(byAdding: .minute, value: 24 * 60 + 1, to: startOfDay)!
        let entries = ([now] + boundaries + [midnight]).map(entry(at:))
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> RoomEntry {
        let store = Store.shared
        let snapshot = store.termSchedule().flatMap { schedule in
            WidgetSnapshot.build(now: date, savedAt: schedule.savedAt) { store.result(for: $0) }
        }
        return RoomEntry(date: date, snapshot: snapshot, sharedStorage: store.isSharedWithWidget)
    }

    private func demoSnapshot() -> WidgetSnapshot? {
        WidgetSnapshot.build(now: DemoData.now, savedAt: DemoData.now) { DemoData.result(for: $0) }
    }
}

struct EmptyRoomWidgetView: View {
    let entry: RoomEntry

    var body: some View {
        WidgetMatrixView(snapshot: entry.snapshot, sharedStorage: entry.sharedStorage)
            .widgetURL(URL(string: "emptyroom://results"))
            .widgetBackground(Color.white)
    }
}

extension View {
    /// iOS 17 requires containerBackground; older systems use a plain background.
    @ViewBuilder
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(color, for: .widget)
        } else {
            padding().background(color)
        }
    }
}

@main
struct EmptyRoomWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "EmptyRoomWidget", provider: RoomProvider()) { entry in
            EmptyRoomWidgetView(entry: entry)
        }
        .configurationDisplayName("空教室速查")
        .description("在桌面直接看到今天空闲最多的教室")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
