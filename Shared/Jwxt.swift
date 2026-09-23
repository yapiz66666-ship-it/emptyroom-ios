import Foundation

/// School system addresses (reached through WebVPN) and page-state detection. Same logic as the
/// Android JwglEndpoints / JwglPageDetector.
enum Jwxt {
    static let webVpnHome = "https://webvpn.csuft.edu.cn/site-nav/home"
    static let ssoEntry = "https://http-jwxt-csuft-edu-cn-80.webvpn.csuft.edu.cn/sso.jsp"
    static let login = "https://http-jwxt-csuft-edu-cn-80.webvpn.csuft.edu.cn/jsxsd/"
    static let home = "https://http-jwxt-csuft-edu-cn-80.webvpn.csuft.edu.cn/jsxsd/framework/xsMainV.htmlx"
    static let classroomQuery = "https://http-jwxt-csuft-edu-cn-80.webvpn.csuft.edu.cn/jsxsd/kbcx/kbxx_classroom"

    /// Stay on whichever jwgl/jwxt host the session actually landed on.
    static func classroomQuery(for currentUrl: String) -> String {
        guard let match = firstMatch(#"^https://http-jw(gl|xt)-csuft-edu-cn-80\.webvpn\.csuft\.edu\.cn"#, in: currentUrl)
        else { return classroomQuery }
        return match[0] + "/jsxsd/kbcx/kbxx_classroom"
    }
}

enum PageState: Equatable {
    case webVpnLogin, webVpnHome, ssoCallback, jwxtLoginRequired, jwxtPage, classroomQuery, unknown, error

    var title: String {
        switch self {
        case .webVpnLogin: return "WebVPN 登录"
        case .webVpnHome: return "已进入 WebVPN"
        case .ssoCallback: return "正在进入教务系统"
        case .jwxtLoginRequired: return "教务系统未登录"
        case .jwxtPage: return "已进入教务系统"
        case .classroomQuery: return "选择教学楼"
        case .unknown: return "正在连接"
        case .error: return "页面加载错误"
        }
    }

    /// Hint shown above the web page.
    var hint: String {
        switch self {
        case .webVpnLogin: return "在下方登录学校统一身份认证，登录后会自动进入教务系统"
        case .webVpnHome: return "WebVPN 已登录，正在进入教务系统"
        case .ssoCallback: return "正在进入教务系统…"
        case .jwxtLoginRequired: return "教务系统需要再认证一次"
        case .jwxtPage: return "已进入教务，正在打开空教室查询页"
        case .classroomQuery: return "当前显示的是原始网页"
        case .error: return "页面加载出错，可重新认证教务"
        case .unknown: return "正在连接学校 WebVPN…"
        }
    }

    /// States the app moves through by itself once logged in.
    var isAutomatic: Bool { [.unknown, .webVpnHome, .ssoCallback, .jwxtPage].contains(self) }
}

enum PageDetector {
    static func detect(url: String, title: String, bodyText: String, tableCount: Int = 0, selects: [String] = [], buttons: [String] = []) -> PageState {
        let lowerUrl = url.lowercased()
        let path = String(lowerUrl.split(separator: "?", maxSplits: 1).first ?? "").split(separator: "#").first.map(String.init) ?? ""
        let joinedSelects = selects.joined(separator: " ")
        let joinedButtons = buttons.joined(separator: " ")

        let hasWebVpn = path.contains("webvpn") || title.localizedCaseInsensitiveContains("WebVPN")
        let hasJwxtUrl = path.contains("jwgl") || path.contains("jwxt")
        let hasClassroomUrl = path.contains("/jsxsd/kbcx/kbxx_classroom")
        let hasHomeUrl = path.contains("/jsxsd/framework/xsmain.jsp") || path.contains("/jsxsd/framework/xsmainv.htmlx")
        let hasSsoCallback = path.contains("/jsxsd/xk/logintoxk") || path.contains("/logon.do")
        let hasJwxtContent = bodyText.contains("教务") || title.contains("教务")
        let classroomWords = ["空教室", "教室查询", "教室", "教学楼"].filter {
            title.contains($0) || bodyText.contains($0) || joinedSelects.contains($0)
        }.count
        let hasQueryControls = joinedButtons.contains("查询") || joinedButtons.contains("检索") || joinedSelects.contains("教学楼")
        let browserError = ["Webpage not available", "网页无法打开"].contains { title.contains($0) || bodyText.contains($0) }

        if loginRequired(hasJwxtUrl: hasJwxtUrl, title: title, bodyText: bodyText) { return .jwxtLoginRequired }
        if webVpnLogin(path: path, title: title, bodyText: bodyText) { return .webVpnLogin }
        if browserError { return .error }
        if hasSsoCallback { return .ssoCallback }
        if hasClassroomUrl { return .classroomQuery }
        if classroomWords >= 2 && hasQueryControls && (tableCount > 0 || hasJwxtUrl || hasJwxtContent || hasWebVpn) { return .classroomQuery }
        if hasHomeUrl || (hasJwxtContent && !hasWebVpn) { return .jwxtPage }
        if hasWebVpn { return .webVpnHome }
        return .unknown
    }

    private static func webVpnLogin(path: String, title: String, bodyText: String) -> Bool {
        let words = ["登录", "统一身份认证", "账号", "密码", "login"]
        let hasLoginText = words.filter { title.localizedCaseInsensitiveContains($0) || bodyText.localizedCaseInsensitiveContains($0) }.count >= 2
        let hasLoginPath = path.contains("/auth/login") || path.contains("/cas/login")
        return path.contains("webvpn") && (hasLoginPath || hasLoginText)
    }

    private static func loginRequired(hasJwxtUrl: Bool, title: String, bodyText: String) -> Bool {
        guard hasJwxtUrl else { return false }
        let rejected = bodyText.contains("请先登录系统") || bodyText.contains("请登录系统后") ||
            (bodyText.contains("\"flag\":2") && bodyText.contains("登录"))
        let credentialForm = bodyText.contains("密码") && (bodyText.contains("用户名") || bodyText.contains("账号")) &&
            (title.contains("登录") || bodyText.contains("登录"))
        return rejected || credentialForm
    }
}
