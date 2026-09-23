import SwiftUI
import WidgetKit

enum Route: Hashable {
    case query(auto: Bool)
    case results
    case settings
}

/// Navigation state shared by the screens.
final class AppRouter: ObservableObject {
    @Published var path: [Route] = []
    @Published var showWidgetGuide = false

    func showResults() { path = [.results] }
}

@main
struct EmptyRoomApp: App {
    @StateObject private var router = AppRouter()

    init() {
        DemoMode.applyLaunchArguments()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                HomeView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .query(let auto): QueryView(autoQuery: auto)
                        case .results: ResultView()
                        case .settings: SettingsView()
                        }
                    }
            }
            .environmentObject(router)
            .tint(Palette.green)
            .preferredColorScheme(.light)
            // Tapping the widget opens the results.
            .onOpenURL { url in
                if url.host == "results" { router.showResults() }
            }
            .onAppear { DemoMode.applyInitialScreen(router) }
        }
    }
}

/// Launch arguments used by the CI screenshots: `-demo` loads made-up data and pins the clock,
/// `-screen results|widget` opens a screen directly.
enum DemoMode {
    static var isOn: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }

    static func applyLaunchArguments() {
        guard isOn else { return }
        AppClock.override = DemoData.now
        Store.shared.saveTerm(buildingName: DemoData.buildingName, payload: DemoData.payload, savedAt: DemoData.now)
        Store.shared.saveSelection(
            campus: QueryOption(value: "1", label: "东园"),
            building: QueryOption(value: "36", label: DemoData.buildingName)
        )
    }

    static func applyInitialScreen(_ router: AppRouter) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screen"), index + 1 < arguments.count else { return }
        switch arguments[index + 1] {
        case "results": router.path = [.results]
        case "settings": router.path = [.settings]
        case "query": router.path = [.query(auto: false)]
        case "widget": router.showWidgetGuide = true
        default: break
        }
    }
}
