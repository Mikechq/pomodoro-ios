# 番茄钟（Pomodoro iOS）

原生 iOS 番茄钟应用：SwiftUI、iOS 17+、中文界面、零第三方依赖。

## 功能

- **经典番茄节奏**：25 分钟专注 / 5 分钟短休息，每 4 个番茄后 15 分钟长休息（均可在设置中自定义）
- **进度环 + 倒计时**：环形进度随时间平滑推进，不同阶段不同配色
- **开始 / 暂停 / 重置 / 跳过**：重置需二次确认；阶段结束后自动进入下一阶段
- **后台准确计时**：基于 `endDate` 时间戳计时而非递减计数，切后台、锁屏后时间依然准确；回到前台自动校准；App 被杀掉重进也能恢复或补结算
- **本地通知**：阶段结束时发送通知，即使切到后台也能收到提醒（首次启动会请求通知权限）
- **统计**：今日完成的番茄数 + 近 7 天柱状历史，按天归零，存在 UserDefaults
- **设置**：专注时长、短休息、长休息、长休息间隔均可调，恢复默认需确认

## 在 Xcode 中运行

1. 打开 Xcode → **Create New Project** → **iOS → App**，语言选 **Swift**，界面选 **SwiftUI**，最低版本设为 **iOS 17.0**（项目名随意，如 `Pomodoro`）
2. 在项目导航栏中**删除** Xcode 自动生成的两个文件：`<项目名>App.swift` 和 `ContentView.swift`（右键 → Delete → Move to Trash）
3. 把本目录下的 5 个 `.swift` 文件**拖入** Xcode 项目导航栏，勾选 **Copy items if needed**，Target 勾选你的 App
4. 选择目标设备（真机或模拟器），按 **⌘R** 运行
5. 首次启动允许通知权限，即可在后台收到阶段结束提醒

> 说明：本地通知无需额外配置 Background Modes，系统会在 App 切后台后按时推送已调度的通知。

## 文件结构

```
pomodoro-ios/
├── PomodoroApp.swift     # @main 入口，启动时请求通知权限
├── TimerViewModel.swift   # 计时核心（ObservableObject）：endDate 计时、阶段流转、通知调度、状态持久化
├── ContentView.swift      # 主界面：进度环、倒计时、阶段标签、控制按钮、统计
├── SettingsView.swift     # 设置页 + PomodoroSettings（UserDefaults 存取）
├── StatsStore.swift       # 统计仓库：按天 key 存 UserDefaults，今日计数与历史查询
└── README.md              # 本说明
```

## 计时原理

- `start()` 时记录 `endDate = Date() + 剩余秒数`，并用 `Timer.publish(every: 1)` 每秒 tick
- 每次 tick 用 `endDate.timeIntervalSinceNow` 重算剩余秒数 → 后台/锁屏不影响准确性
- `scenePhase` 回到 `.active` 时主动 tick 一次，立即校准（若阶段已在后台结束则直接流转）
- 同时为阶段结束时刻调度一条本地通知（`UNTimeIntervalNotificationTrigger`），暂停/重置/跳过时取消
