# 空教室速查 iOS 版

安卓版（`D:\vibeIdea\vibeidea`）的 iPhone 版本，功能对齐：WebVPN 登录后一键查询教学楼、课表矩阵（绿＝空、灰＝有课、点时段筛选）、桌面小组件（当天空闲最多的 5 间）。

## 没有 Mac 怎么编译

项目用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 的 `project.yml` 描述，`.xcodeproj` 不进仓库。每次推送到 `main`，GitHub Actions 的 macOS 机器会：

1. `xcodegen generate` 生成工程
2. 在 iPhone 模拟器上跑单元测试（`Tests/`，与安卓单测同样的用例）
3. 用假数据（`-demo`）启动 App 截图，放在构建产物 `screenshots/`
4. 打包 `EmptyRoom.ipa`（未用开发者证书签名，App 和小组件带 App Group 权限的临时签名）

构建产物在仓库的 Actions 页面 → 对应运行 → Artifacts → `EmptyRoom-iOS`。

> 目前账号的 GitHub Actions 因账单问题被锁，改用 [Codemagic](https://codemagic.io)（`codemagic.yaml`，步骤相同），推送到 `main` 自动构建，产物在 Codemagic 的构建页面下载。GitHub Actions 暂时只能手动触发。

## 装到 iPhone（Windows 上用 Sideloadly）

1. 装好 iTunes（微软商店版不行，要官网版）和 [Sideloadly](https://sideloadly.io/)
2. 数据线连上 iPhone，手机上点“信任此电脑”
3. 把 `EmptyRoom.ipa` 拖进 Sideloadly，**自己**输入 Apple ID，点 Start
4. iPhone：设置 → 通用 → VPN 与设备管理 → 信任你的 Apple ID；iOS 16+ 还要在 设置 → 隐私与安全性 → 开发者模式 里打开
5. 免费 Apple ID 装的应用 **7 天后失效**，需要用 Sideloadly 重装（登录数据会保留）

小组件依赖 App Group 读取 App 的数据。装好后在 App 的 设置 页看“与小组件共享数据”：显示“未生效”说明这次侧载丢了 App Group，App 能用但小组件没数据。

## 目录

- `Shared/`：App 和小组件共用的逻辑，逐行对应安卓 Kotlin（解析课表、节次、房号、Top 5、存储）
- `App/`：SwiftUI 界面 + WKWebView 登录与查询（脚本与安卓完全相同）
- `Widget/`：WidgetKit 小组件，按节次边界生成离线时间线
- `Tests/`：XCTest 单元测试
- `scripts/`：CI 用的选模拟器、截图、打包脚本
