import SwiftUI
import WebKit

struct QueryView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var model: QueryModel

    init(autoQuery: Bool) {
        _model = StateObject(wrappedValue: QueryModel(autoQuery: autoQuery))
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.isLoading {
                ProgressView().progressViewStyle(.linear).tint(Palette.green)
            }
            if (!model.onQueryPage && !model.isConnecting) || model.showWebPage {
                banner
            }
            ZStack {
                // The web view stays in the hierarchy under the native panels: the query runs in it.
                WebViewContainer(webView: model.webView)
                if model.isConnecting {
                    LoadingPanel(
                        title: model.pageState.hint,
                        detail: "已登录时会自动进入，无需操作",
                        actionTitle: "卡住了？显示网页"
                    ) { model.showWebPage = true }
                }
                if model.onQueryPage && !model.showWebPage {
                    if model.isQuerying {
                        LoadingPanel(
                            title: "正在读取\(model.metadata?.selectedBuilding?.label ?? "")今日课表",
                            detail: "教务系统响应较慢，大约需要 5～10 秒"
                        )
                    } else {
                        picker
                    }
                }
            }
        }
        .background(Palette.background)
        .safeAreaInset(edge: .bottom) {
            if model.onQueryPage && !model.showWebPage && !model.isQuerying { queryButton }
        }
        .navigationTitle(model.onQueryPage ? "选择教学楼" : model.isConnecting ? "正在连接教务系统" : model.pageState.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(model.showWebPage ? "隐藏网页" : "显示网页") { model.showWebPage.toggle() }
                    Button("刷新") { model.webView.reload() }
                    Button("网页后退") { model.webView.goBack() }.disabled(!model.webView.canGoBack)
                    Button("清除登录状态", role: .destructive) { model.clearLoginState() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            model.onFinished = { router.showResults() }
            model.start()
        }
    }

    private var banner: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.pageState.hint).font(.footnote).foregroundColor(Palette.ink)
                if let error = model.errorMessage {
                    Text(error).font(.footnote).foregroundColor(.red)
                }
            }
            Spacer(minLength: 0)
            Button(model.primaryAction.title) { model.load(model.primaryAction.url) }
                .font(.footnote.weight(.semibold))
                .disabled(model.isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Palette.greenSoft)
    }

    private var picker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("今日 \(todayText())" + (model.metadata.map { " · \($0.academicTerm) 学期" } ?? ""))
                    .font(.subheadline).foregroundColor(Palette.muted)
                if let metadata = model.metadata {
                    section("校区") {
                        ForEach(metadata.campuses) { campus in
                            ChipButton(title: campus.label, selected: campus == metadata.selectedCampus, enabled: !model.isLoadingOptions) {
                                if campus != metadata.selectedCampus { model.selectCampus(campus) }
                            }
                        }
                    }
                    if model.isLoadingOptions && metadata.buildings.isEmpty {
                        HStack(spacing: 8) { ProgressView(); Text("正在读取教学楼…").font(.subheadline) }
                    } else {
                        section("教学楼") {
                            ForEach(metadata.buildings) { building in
                                ChipButton(title: building.label, selected: building == metadata.selectedBuilding, enabled: !model.isLoadingOptions) {
                                    model.metadata?.selectedBuilding = building
                                }
                            }
                        }
                    }
                } else if model.queryError != nil {
                    Button { model.retry() } label: { Label("重新读取", systemImage: "arrow.clockwise") }
                        .buttonStyle(.bordered)
                } else {
                    HStack(spacing: 10) { ProgressView(); Text("正在读取校区和教学楼…") }.padding(.vertical, 24)
                }
                if let error = model.queryError {
                    Text(error).font(.footnote).foregroundColor(.red)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.background)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundColor(Palette.ink)
            FlowLayout(spacing: 8) { content() }
        }
    }

    private var queryButton: some View {
        Button { model.query() } label: {
            Label("查询\(model.metadata?.selectedBuilding?.label ?? "")今日空教室", systemImage: "magnifyingglass")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(model.metadata?.selectedBuilding == nil || model.isLoadingOptions)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.shadow(.drop(radius: 4)))
    }

    private func todayText() -> String {
        let parts = Periods.calendar.dateComponents([.year, .month, .day], from: AppClock.now())
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
