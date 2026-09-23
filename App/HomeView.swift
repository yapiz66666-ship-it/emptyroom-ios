import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase
    @State private var result: DayResult?
    @State private var lastBuilding: QueryOption?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("空教室速查").font(.system(size: 30, weight: .bold)).foregroundColor(Palette.ink)
                        Text(todayLine()).font(.subheadline).foregroundColor(Palette.muted)
                    }
                    Spacer()
                    Button { router.path.append(.settings) } label: {
                        Image(systemName: "gearshape").font(.title2).foregroundColor(Palette.ink)
                    }
                    .accessibilityLabel("设置")
                }
                .padding(.top, 8)

                if let result {
                    resultCard(result)
                    widgetCard
                } else {
                    howTo
                }
            }
            .padding(.horizontal, 20)
        }
        .background(Palette.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { bottomButtons }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: reload)
        .onChange(of: scenePhase) { phase in if phase == .active { reload() } }
        .sheet(isPresented: $router.showWidgetGuide) { WidgetGuideView() }
    }

    private func reload() {
        result = Store.shared.result(for: AppClock.now())
        lastBuilding = Store.shared.lastBuilding
    }

    private func resultCard(_ result: DayResult) -> some View {
        let minute = Periods.minuteOfDay(AppClock.now())
        let current = Periods.currentPeriod(atMinute: minute)
        let freeNow = current.map { period in result.rooms.filter { $0.freePeriods.contains(period) }.count }
        return Button { router.path.append(.results) } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("今日结果").font(.subheadline.weight(.medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(freeNow ?? result.rooms.count)").font(.system(size: 48, weight: .bold))
                    Text(freeNow != nil ? "间现在空闲" : "间有空闲").font(.title3)
                }
                Text(result.weekNumber == nil ? "\(result.buildingName) · 非教学周" : result.buildingName).font(.subheadline)
            }
            .foregroundColor(.white)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20).fill(Palette.green))
        }
        .buttonStyle(.plain)
    }

    private var widgetCard: some View {
        Button { router.showWidgetGuide = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.grid.2x2").font(.title3).foregroundColor(Palette.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("添加桌面小组件").font(.subheadline.weight(.semibold)).foregroundColor(Palette.ink)
                    Text("不用打开 App，桌面上直接看今天哪些教室空着").font(.footnote).foregroundColor(Palette.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(Palette.muted)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.busy))
        }
        .buttonStyle(.plain)
    }

    private var howTo: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("怎么用").font(.subheadline).foregroundColor(Palette.muted)
            VStack(alignment: .leading, spacing: 14) {
                GuideStep(index: 1, title: "登录学校统一身份认证", detail: "登录态保存在本机，下次通常免登录")
                GuideStep(index: 2, title: "选择校区和教学楼", detail: "App 会记住，下次一键直达")
                GuideStep(index: 3, title: "看课表矩阵", detail: "绿色＝空闲，点时段筛选，点教室看全天")
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        }
    }

    private var bottomButtons: some View {
        VStack(spacing: 4) {
            Button {
                router.path.append(.query(auto: lastBuilding != nil))
            } label: {
                Label(primaryTitle, systemImage: "magnifyingglass")
            }
            .buttonStyle(PrimaryButtonStyle())
            if lastBuilding != nil {
                Button("换一栋教学楼") { router.path.append(.query(auto: false)) }
                    .font(.subheadline.weight(.medium))
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .background(Palette.background)
    }

    private var primaryTitle: String {
        guard let building = lastBuilding else { return "登录并查询空教室" }
        if result?.buildingName == building.label { return "刷新\(building.label)空教室" }
        return "查\(building.label)今天的空教室"
    }

    private func todayLine() -> String {
        let now = AppClock.now()
        let parts = Periods.calendar.dateComponents([.month, .day], from: now)
        let period = Periods.currentPeriod(atMinute: Periods.minuteOfDay(now)).map { " · 当前 \($0)" } ?? ""
        return "\(parts.month ?? 0)月\(parts.day ?? 0)日 \(ScheduleParser.weekdayName(of: now))\(period)"
    }
}

/// iOS cannot add a widget programmatically, so this explains the steps.
struct WidgetGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    WidgetMatrixView(snapshot: WidgetSnapshot.build(now: DemoData.now, savedAt: DemoData.now, resultFor: { DemoData.result(for: $0) }))
                        .padding(16)
                        .frame(height: 170)
                        .background(RoundedRectangle(cornerRadius: 22).fill(Color.white))
                        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                    Text("示意图，实际显示你查询的教学楼").font(.caption).foregroundColor(Palette.muted)
                    GuideStep(index: 1, title: "长按桌面空白处", detail: "图标开始抖动后，点左上角的“＋”（新系统点“编辑”→“添加小组件”）")
                    GuideStep(index: 2, title: "搜索“空教室速查”", detail: "选中等尺寸，也可以左右滑动选大尺寸")
                    GuideStep(index: 3, title: "点“添加小组件”", detail: "拖到想放的位置，点“完成”")
                    if !Store.shared.isSharedWithWidget {
                        Text("注意：这次安装没有开启 App Group，小组件可能读不到数据。用 Sideloadly 重新安装时保持默认签名选项即可。")
                            .font(.footnote)
                            .foregroundColor(Palette.amber)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Palette.amberSoft))
                    }
                    Text("小组件不联网，数据来自最近一次查询；学校调课后在 App 里刷新一次即可。")
                        .font(.footnote).foregroundColor(Palette.muted)
                }
                .padding(20)
            }
            .background(Palette.background)
            .navigationTitle("添加桌面小组件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("好的") { dismiss() } } }
        }
        .presentationDetents([.large])
    }
}
