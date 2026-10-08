import Foundation
import Combine
import UserNotifications

/// 番茄钟阶段
enum PomodoroPhase: String, CaseIterable {
    case focus
    case shortBreak
    case longBreak

    var title: String {
        switch self {
        case .focus: return "专注"
        case .shortBreak: return "短休息"
        case .longBreak: return "长休息"
        }
    }
}

/// 计时器 ViewModel
///
/// 计时原理：运行开始时记录 `endDate = 现在 + 剩余秒数`，
/// 每次 tick 都用 `endDate` 重新算剩余时间，而不是递减计数。
/// 因此切后台、锁屏期间计时依然准确；回到前台时一次 tick 即可校准。
final class TimerViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var phase: PomodoroPhase = .focus
    @Published private(set) var remainingSeconds: Int = 25 * 60
    @Published private(set) var isRunning = false
    /// 本轮已完成的专注数（用于判断何时进入长休息）
    @Published private(set) var cycleCompletedCount = 0

    /// 统计仓库（今日番茄数、历史每日统计）
    let stats: StatsStore

    // MARK: - Private

    private var endDate: Date?
    private var timerCancellable: AnyCancellable?
    private static let notificationID = "pomodoro.phaseEnd"

    private enum Keys {
        static let phase = "pomodoro.timer.phase"
        static let remaining = "pomodoro.timer.remaining"
        static let isRunning = "pomodoro.timer.isRunning"
        static let endDate = "pomodoro.timer.endDate"
        static let cycleCount = "pomodoro.timer.cycleCount"
    }

    // MARK: - Init / Restore

    init(stats: StatsStore) {
        self.stats = stats
        restoreState()
        stats.refreshToday()
    }

    // MARK: - Derived

    private var settings: PomodoroSettings { PomodoroSettings.load() }

    func totalSeconds(for phase: PomodoroPhase) -> Int {
        let s = settings
        switch phase {
        case .focus: return s.focusMinutes * 60
        case .shortBreak: return s.shortBreakMinutes * 60
        case .longBreak: return s.longBreakMinutes * 60
        }
    }

    /// 进度环进度 0...1
    var progress: Double {
        let total = totalSeconds(for: phase)
        guard total > 0 else { return 0 }
        return min(1, max(0, 1 - Double(remainingSeconds) / Double(total)))
    }

    var timeString: String {
        String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    /// 当前周期内已填充的圆点数
    var dotsFilled: Int {
        cycleCompletedCount % max(1, settings.longBreakInterval)
    }

    /// 周期总圆点数
    var dotsTotal: Int {
        max(1, settings.longBreakInterval)
    }

    // MARK: - Controls

    func start() {
        let total = totalSeconds(for: phase)
        if remainingSeconds <= 0 || remainingSeconds > total {
            remainingSeconds = total
        }
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        isRunning = true
        startTicker()
        schedulePhaseEndNotification(after: TimeInterval(remainingSeconds))
        persistState()
    }

    func pause() {
        guard isRunning else { return }
        if let end = endDate {
            remainingSeconds = max(0, Int(ceil(end.timeIntervalSinceNow)))
        }
        endDate = nil
        isRunning = false
        stopTicker()
        cancelScheduledNotification()
        persistState()
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    /// 重置：回到专注阶段起点，清空本轮计数（调用前请二次确认）
    func reset() {
        stopTicker()
        cancelScheduledNotification()
        endDate = nil
        isRunning = false
        phase = .focus
        cycleCompletedCount = 0
        remainingSeconds = totalSeconds(for: .focus)
        persistState()
    }

    /// 跳过当前阶段：不计入统计，直接进入下一阶段
    func skip() {
        let wasRunning = isRunning
        stopTicker()
        cancelScheduledNotification()
        moveToNextPhase()
        if wasRunning {
            start()
        } else {
            persistState()
        }
    }

    /// 回到前台时校准（由 ContentView 监听 scenePhase 调用）
    func handleDidBecomeActive() {
        guard isRunning else { return }
        tick()
    }

    // MARK: - Ticker

    private func startTicker() {
        stopTicker()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func stopTicker() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func tick() {
        guard let end = endDate else { return }
        let remaining = Int(ceil(end.timeIntervalSinceNow))
        if remaining <= 0 {
            completePhase()
        } else if remaining != remainingSeconds {
            remainingSeconds = remaining
        }
    }

    // MARK: - Phase transitions

    /// 当前阶段自然结束：结算统计 → 进入下一阶段 → 自动开始
    private func completePhase() {
        stopTicker()
        cancelScheduledNotification()
        if phase == .focus {
            cycleCompletedCount += 1
            stats.recordFocusCompleted()
        }
        moveToNextPhase()
        start() // 自动进入下一阶段，保持番茄流
    }

    private func moveToNextPhase() {
        let interval = max(2, settings.longBreakInterval)
        switch phase {
        case .focus:
            phase = (cycleCompletedCount % interval == 0) ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            phase = .focus
        }
        remainingSeconds = totalSeconds(for: phase)
        endDate = nil
        isRunning = false
    }

    // MARK: - Notifications

    private func schedulePhaseEndNotification(after seconds: TimeInterval) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])

        let content = UNMutableNotificationContent()
        if phase == .focus {
            content.title = "专注结束 🎉"
            content.body = "干得漂亮！起来活动一下吧。"
        } else {
            content.title = "休息结束 💪"
            content.body = "回来吧，下一个番茄等你开始。"
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, seconds),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.notificationID,
            content: content,
            trigger: trigger
        )
        Task {
            do {
                try await Self.addNotificationRequest(request)
            } catch {
                print("调度通知失败：\(error)")
            }
        }
    }

    /// 用 continuation 包装回调式 API，保证各版本编译通过，同时保持 async/await 调用风格
    private static func addNotificationRequest(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { continuation in
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func cancelScheduledNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    // MARK: - Persistence

    private func persistState() {
        let d = UserDefaults.standard
        d.set(phase.rawValue, forKey: Keys.phase)
        d.set(remainingSeconds, forKey: Keys.remaining)
        d.set(isRunning, forKey: Keys.isRunning)
        d.set(cycleCompletedCount, forKey: Keys.cycleCount)
        if let end = endDate {
            d.set(end, forKey: Keys.endDate)
        } else {
            d.removeObject(forKey: Keys.endDate)
        }
    }

    /// 启动时恢复：暂停态直接恢复；运行态按 endDate 续跑；
    /// 若 App 被杀期间阶段已结束，则补一次结算并停在下一阶段起点
    private func restoreState() {
        let d = UserDefaults.standard
        if let raw = d.string(forKey: Keys.phase),
           let savedPhase = PomodoroPhase(rawValue: raw) {
            phase = savedPhase
        }
        remainingSeconds = d.integer(forKey: Keys.remaining)
        cycleCompletedCount = d.integer(forKey: Keys.cycleCount)

        if d.bool(forKey: Keys.isRunning),
           let end = d.object(forKey: Keys.endDate) as? Date {
            let remaining = Int(ceil(end.timeIntervalSinceNow))
            if remaining > 0 {
                endDate = end
                remainingSeconds = remaining
                isRunning = true
                startTicker()
                schedulePhaseEndNotification(after: TimeInterval(remaining))
                return
            } else {
                endDate = nil
                if phase == .focus {
                    cycleCompletedCount += 1
                    stats.recordFocusCompleted()
                }
                moveToNextPhase()
                persistState()
                return
            }
        }

        isRunning = false
        endDate = nil
        let total = totalSeconds(for: phase)
        if remainingSeconds <= 0 || remainingSeconds > total {
            remainingSeconds = total
        }
    }
}
