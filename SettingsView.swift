import SwiftUI

/// 番茄钟时长设置，Codable 编码后存 UserDefaults
struct PomodoroSettings: Codable {
    var focusMinutes: Int = 25
    var shortBreakMinutes: Int = 5
    var longBreakMinutes: Int = 15
    var longBreakInterval: Int = 4

    static let `default` = PomodoroSettings()
    private static let storageKey = "pomodoro.settings"

    static func load() -> PomodoroSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let s = try? JSONDecoder().decode(PomodoroSettings.self, from: data)
        else { return .default }
        return s.clamped()
    }

    func save() {
        let s = clamped()
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    static func resetToDefault() {
        Self.default.save()
    }

    private func clamped() -> PomodoroSettings {
        PomodoroSettings(
            focusMinutes: min(120, max(1, focusMinutes)),
            shortBreakMinutes: min(60, max(1, shortBreakMinutes)),
            longBreakMinutes: min(60, max(1, longBreakMinutes)),
            longBreakInterval: min(10, max(2, longBreakInterval))
        )
    }
}

/// 设置页：自定义专注 / 短休息 / 长休息时长与长休息间隔
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var focusMinutes = 25
    @State private var shortBreakMinutes = 5
    @State private var longBreakMinutes = 15
    @State private var longBreakInterval = 4
    @State private var showingResetConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("时长（分钟）") {
                    Stepper("专注：\(focusMinutes) 分钟", value: $focusMinutes, in: 1...120)
                    Stepper("短休息：\(shortBreakMinutes) 分钟", value: $shortBreakMinutes, in: 1...60)
                    Stepper("长休息：\(longBreakMinutes) 分钟", value: $longBreakMinutes, in: 1...60)
                }

                Section("节奏") {
                    Stepper("每 \(longBreakInterval) 个番茄后长休息", value: $longBreakInterval, in: 2...10)
                }

                Section {
                    Text("修改将在下一阶段生效，当前正在进行的计时不受影响。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("恢复默认设置", role: .destructive) {
                        showingResetConfirm = true
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear(perform: loadSettings)
            .onChange(of: focusMinutes) { _, _ in saveSettings() }
            .onChange(of: shortBreakMinutes) { _, _ in saveSettings() }
            .onChange(of: longBreakMinutes) { _, _ in saveSettings() }
            .onChange(of: longBreakInterval) { _, _ in saveSettings() }
            .alert("恢复默认设置？", isPresented: $showingResetConfirm) {
                Button("恢复", role: .destructive) {
                    PomodoroSettings.resetToDefault()
                    loadSettings()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将恢复为 25 / 5 / 15 分钟、每 4 个番茄长休息。")
            }
        }
    }

    private func loadSettings() {
        let s = PomodoroSettings.load()
        focusMinutes = s.focusMinutes
        shortBreakMinutes = s.shortBreakMinutes
        longBreakMinutes = s.longBreakMinutes
        longBreakInterval = s.longBreakInterval
    }

    private func saveSettings() {
        PomodoroSettings(
            focusMinutes: focusMinutes,
            shortBreakMinutes: shortBreakMinutes,
            longBreakMinutes: longBreakMinutes,
            longBreakInterval: longBreakInterval
        ).save()
    }
}
