import SwiftUI
import WebKit
import WidgetKit

struct SettingsView: View {
    @State private var message: String?

    var body: some View {
        List {
            Section {
                Button("清除网页登录状态") {
                    WKWebsiteDataStore.default().removeData(
                        ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                        modifiedSince: .distantPast
                    ) { message = "登录状态已清除" }
                }
                Button("清除本地查询数据", role: .destructive) {
                    Store.shared.clearTerm()
                    WidgetCenter.shared.reloadAllTimelines()
                    message = "本地查询数据已清除"
                }
            } footer: {
                if let message { Text(message) }
            }
            Section("小组件") {
                LabeledContent("与小组件共享数据", value: Store.shared.isSharedWithWidget ? "正常" : "未生效")
            }
            Section("隐私说明") {
                Text("本应用只在本机的网页里加载学校 WebVPN 和教务系统，不上传账号密码，不保存明文密码，查询结果只保存在本机。")
                    .font(.footnote)
                    .foregroundColor(Palette.muted)
            }
            Section {
                LabeledContent("版本", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
            }
        }
        .navigationTitle("设置")
    }
}
