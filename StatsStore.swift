import Foundation

/// 番茄完成统计：UserDefaults 持久化，key 为 `pomodoro.stats.yyyy-MM-dd`，
/// 天然按天归零；跨天后调用 `refreshToday()` 刷新今日计数。
final class StatsStore: ObservableObject {

    @Published private(set) var todayCount: Int = 0

    private let defaults = UserDefaults.standard
    private static let prefix = "pomodoro.stats."

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let labelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M/d"
        return f
    }()

    init() {
        refreshToday()
    }

    private func key(for date: Date) -> String {
        Self.prefix + Self.dayFormatter.string(from: date)
    }

    /// 记录一次专注完成
    func recordFocusCompleted(on date: Date = Date()) {
        let k = key(for: date)
        let n = defaults.integer(forKey: k) + 1
        defaults.set(n, forKey: k)
        if Calendar.current.isDateInToday(date) {
            todayCount = n
        }
    }

    /// 某天的完成数
    func count(for date: Date) -> Int {
        defaults.integer(forKey: key(for: date))
    }

    /// 刷新今日计数（跨天回到前台时调用）
    func refreshToday() {
        let n = count(for: Date())
        if n != todayCount {
            todayCount = n
        }
    }

    /// 最近 n 天（含今天），从旧到新排列，供历史展示
    func recentDays(_ n: Int) -> [DayStat] {
        let cal = Calendar.current
        return (0..<max(1, n)).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            return DayStat(
                label: Self.labelFormatter.string(from: date),
                count: count(for: date),
                isToday: cal.isDateInToday(date)
            )
        }
    }

    struct DayStat: Identifiable {
        let id = UUID()
        let label: String
        let count: Int
        let isToday: Bool
    }
}
