import SwiftUI
import UserNotifications

/// App 入口：启动时请求本地通知权限
@main
struct PomodoroApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await requestNotificationPermission()
                }
        }
    }

    /// 请求本地通知权限（弹窗 + 声音），拒绝也不影响计时功能
    private func requestNotificationPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            print("通知权限：\(granted ? "已授予" : "被拒绝")")
        } catch {
            print("请求通知权限失败：\(error)")
        }
    }
}
