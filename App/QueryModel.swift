import Foundation
import WebKit
import WidgetKit

struct QueryMetadata {
    var academicTerm: String
    var campuses: [QueryOption]
    var selectedCampus: QueryOption?
    var buildings: [QueryOption]
    var selectedBuilding: QueryOption?
}

/// Drives the school pages in a WKWebView, same flow as the Android LoginWebViewScreen:
/// WebVPN login (by the user) → CAS SSO into jwxt → jwxt home → classroom page → read campuses and
/// buildings → query one building's whole-term class list.
@MainActor
final class QueryModel: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var pageState: PageState = .unknown
    @Published var currentUrl = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var metadata: QueryMetadata?
    @Published var isLoadingOptions = false
    @Published var isQuerying = false
    @Published var queryError: String?
    @Published var showWebPage = false

    let webView: WKWebView
    let autoQuery: Bool
    var onFinished: () -> Void = {}

    private var enteredJwxt = false
    private var openedClassroom = false
    private var restoredSelection = false
    private var navigationToken = 0

    init(autoQuery: Bool) {
        self.autoQuery = autoQuery
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default() // keeps the WebVPN login between launches
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = nil
    }

    func start() {
        guard webView.url == nil else { return }
        load(Jwxt.webVpnHome)
    }

    func load(_ url: String) {
        guard let url = URL(string: url) else { return }
        webView.load(URLRequest(url: url))
    }

    var onQueryPage: Bool { pageState == .classroomQuery }

    /// Covers the automatic hops with a loading screen; login pages stay visible.
    var isConnecting: Bool {
        !onQueryPage && !showWebPage && pageState.isAutomatic && !currentUrl.localizedCaseInsensitiveContains("login")
    }

    // MARK: Navigation

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        navigationToken += 1
        isLoading = true
        currentUrl = webView.url?.absoluteString ?? currentUrl
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        if navigationResponse.isForMainFrame, let response = navigationResponse.response as? HTTPURLResponse,
           response.statusCode >= 400 {
            let url = response.url?.absoluteString ?? ""
            errorMessage = "页面返回 \(response.statusCode)"
            pageState = .error
            // A protected jwxt page answers 404 when the jwxt session is gone: go log in again.
            if response.statusCode == 404, url.contains("/jsxsd/") {
                after(0.5) { $0.load(Jwxt.login) }
            }
        }
        return .allow
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        currentUrl = webView.url?.absoluteString ?? currentUrl
        detectPage()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        failed(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        failed(error)
    }

    private func failed(_ error: Error) {
        isLoading = false
        if (error as NSError).code == NSURLErrorCancelled { return }
        errorMessage = "页面加载失败：\(error.localizedDescription)"
        pageState = .error
    }

    private func detectPage() {
        let token = navigationToken
        let url = currentUrl
        let title = webView.title ?? ""
        webView.evaluateJavaScript(JwxtScripts.detect) { [weak self] value, _ in
            guard let self, token == self.navigationToken else { return }
            let facts = (value as? String).flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] } ?? [:]
            let state = PageDetector.detect(
                url: url,
                title: title,
                bodyText: facts["bodyText"] as? String ?? "",
                tableCount: facts["tableCount"] as? Int ?? 0,
                selects: facts["selects"] as? [String] ?? [],
                buttons: facts["buttons"] as? [String] ?? []
            )
            self.handle(state)
        }
    }

    private func handle(_ state: PageState) {
        pageState = state
        errorMessage = state == .jwxtLoginRequired ? "WebVPN 已登录，但教务系统尚未登录，请在下方完成教务登录。" : nil
        switch state {
        case .webVpnHome where !enteredJwxt:
            // Once WebVPN is authenticated, go straight on to jwxt instead of waiting for a tap.
            enteredJwxt = true
            after(0.3) { $0.load(Jwxt.ssoEntry) }
        case .ssoCallback:
            after(0.5) { $0.load(Jwxt.home) }
        case .jwxtPage where !openedClassroom:
            openedClassroom = true
            after(0.35) { $0.load(Jwxt.classroomQuery(for: $0.currentUrl)) }
        case .classroomQuery where metadata == nil:
            loadMetadata()
        default:
            break
        }
    }

    private func after(_ seconds: Double, _ action: @escaping @MainActor (QueryModel) -> Void) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if let self { action(self) }
        }
    }

    /// The main action for the current page, shown on the banner above the web page.
    var primaryAction: (title: String, url: String) {
        switch pageState {
        case .jwxtPage, .classroomQuery: return ("进入查询", Jwxt.classroomQuery(for: currentUrl))
        case .error, .jwxtLoginRequired: return ("重新认证教务", Jwxt.ssoEntry)
        case .ssoCallback: return ("继续进入教务", Jwxt.home)
        default: return ("进入教务", Jwxt.ssoEntry)
        }
    }

    // MARK: Campus / building / query

    private func run(_ script: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        webView.evaluateJavaScript(script) { value, error in
            if let error { return completion(.failure(error)) }
            guard let text = value as? String,
                  let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
            else { return completion(.failure(QueryError("教务页面返回了无法识别的结果"))) }
            if let message = json["error"] as? String, !message.isEmpty { return completion(.failure(QueryError(message))) }
            completion(.success(json))
        }
    }

    private func options(_ value: Any?) -> [QueryOption] {
        (value as? [[String: Any]] ?? []).compactMap { item in
            guard let value = item["value"] as? String, let label = item["label"] as? String,
                  !value.isEmpty, !label.isEmpty else { return nil }
            return QueryOption(value: value, label: label)
        }
    }

    func loadMetadata() {
        isLoadingOptions = true
        queryError = nil
        run(JwxtScripts.metadata) { [weak self] result in
            guard let self else { return }
            self.isLoadingOptions = false
            switch result {
            case .failure(let error):
                self.queryError = "读取校区和教学楼失败：\(error.localizedDescription)"
            case .success(let json):
                let campuses = self.options(json["campuses"])
                let buildings = self.options(json["buildings"])
                let selectedValue = json["selectedCampusValue"] as? String
                self.metadata = QueryMetadata(
                    academicTerm: json["academicTerm"] as? String ?? "",
                    campuses: campuses,
                    selectedCampus: campuses.first { $0.value == selectedValue },
                    buildings: buildings,
                    selectedBuilding: buildings.first { $0.label == "逸夫楼" } ?? buildings.first
                )
                self.restoreSelection()
            }
        }
    }

    /// Restores the last campus/building; from the home screen's one-tap button, also queries.
    private func restoreSelection() {
        guard !restoredSelection, let metadata else { return }
        restoredSelection = true
        let savedBuilding = Store.shared.lastBuilding
        let savedCampus = Store.shared.lastCampus.flatMap { saved in metadata.campuses.first { $0.value == saved.value } }
        if let savedCampus, savedCampus.value != metadata.selectedCampus?.value {
            selectCampus(savedCampus, preferredBuilding: savedBuilding?.value) { [weak self] in
                guard let self, self.autoQuery, self.metadata?.selectedBuilding?.value == savedBuilding?.value else { return }
                self.query()
            }
        } else if let building = metadata.buildings.first(where: { $0.value == savedBuilding?.value }) {
            self.metadata?.selectedBuilding = building
            if autoQuery { query() }
        }
    }

    func selectCampus(_ campus: QueryOption, preferredBuilding: String? = nil, then: @escaping () -> Void = {}) {
        guard metadata != nil else { return }
        metadata?.selectedCampus = campus
        metadata?.buildings = []
        metadata?.selectedBuilding = nil
        isLoadingOptions = true
        queryError = nil
        run(JwxtScripts.buildings(campus: campus.value)) { [weak self] result in
            guard let self else { return }
            self.isLoadingOptions = false
            switch result {
            case .failure(let error):
                self.queryError = "读取教学楼失败：\(error.localizedDescription)"
            case .success(let json):
                let buildings = self.options(json["buildings"])
                self.metadata?.buildings = buildings
                self.metadata?.selectedBuilding = buildings.first { $0.value == preferredBuilding }
                    ?? buildings.first { $0.label == "逸夫楼" } ?? buildings.first
                then()
            }
        }
    }

    func query() {
        guard let campus = metadata?.selectedCampus, let building = metadata?.selectedBuilding else {
            queryError = "请先选择校区和教学楼"
            return
        }
        isQuerying = true
        queryError = nil
        webView.evaluateJavaScript(JwxtScripts.query(campus: campus.value, building: building.value)) { [weak self] value, error in
            guard let self else { return }
            self.isQuerying = false
            do {
                if let error { throw error }
                guard let text = value as? String else { throw QueryError("教务页面没有返回数据") }
                if let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
                   let message = json["error"] as? String, !message.isEmpty {
                    throw QueryError(message)
                }
                let payload = try JSONDecoder().decode(TermPayload.self, from: Data(text.utf8))
                Store.shared.saveTerm(buildingName: building.label, payload: payload)
                Store.shared.saveSelection(campus: campus, building: building)
                WidgetCenter.shared.reloadAllTimelines()
                self.onFinished()
            } catch {
                self.queryError = "查询空教室失败：\(error.localizedDescription)"
            }
        }
    }

    func retry() {
        queryError = nil
        errorMessage = nil
        pageState = .unknown
        load(Jwxt.classroomQuery(for: currentUrl))
    }

    func clearLoginState() {
        let store = WKWebsiteDataStore.default()
        store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { [weak self] in
            guard let self else { return }
            self.enteredJwxt = false
            self.openedClassroom = false
            self.restoredSelection = false
            self.metadata = nil
            self.errorMessage = "登录状态已清除，请重新登录"
            self.pageState = .unknown
            self.load(Jwxt.webVpnHome)
        }
    }
}

struct QueryError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
