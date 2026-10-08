import SwiftUI

/// 主界面：进度环 + 倒计时 + 阶段标签 + 控制按钮 + 今日统计
struct ContentView: View {
    @StateObject private var stats: StatsStore
    @StateObject private var viewModel: TimerViewModel
    @Environment(\.scenePhase) private var scenePhase

    @State private var showingSettings = false
    @State private var showingResetConfirm = false

    init() {
        let stats = StatsStore()
        _stats = StateObject(wrappedValue: stats)
        _viewModel = StateObject(wrappedValue: TimerViewModel(stats: stats))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 阶段标签
                    Text(phaseTitle)
                        .font(.title2)
                        .bold()
                        .foregroundStyle(phaseColor)

                    // 进度环 + 倒计时
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 18)
                        Circle()
                            .trim(from: 0, to: viewModel.progress)
                            .stroke(phaseColor,
                                    style: StrokeStyle(lineWidth: 18, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: viewModel.progress)
                        VStack(spacing: 6) {
                            Text(viewModel.timeString)
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text(viewModel.isRunning ? "进行中" : "已暂停")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 260, height: 260)
                    .padding(.top, 8)

                    // 周期圆点：本轮已完成专注数
                    HStack(spacing: 10) {
                        ForEach(0..<viewModel.dotsTotal, id: \.self) { i in
                            Circle()
                                .fill(i < viewModel.dotsFilled
                                      ? phaseColor
                                      : Color.secondary.opacity(0.2))
                                .frame(width: 12, height: 12)
                        }
                    }

                    // 控制按钮
                    HStack(spacing: 16) {
                        Button(role: .destructive) {
                            showingResetConfirm = true
                        } label: {
                            Label("重置", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            viewModel.toggle()
                        } label: {
                            Label(viewModel.isRunning ? "暂停" : "开始",
                                  systemImage: viewModel.isRunning ? "pause.fill" : "play.fill")
                            .frame(minWidth: 110)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(phaseColor)

                        Button {
                            viewModel.skip()
                        } label: {
                            Label("跳过", systemImage: "forward.fill")
                        }
                        .buttonStyle(.bordered)
                    }

                    // 今日统计 + 近 7 天
                    VStack(spacing: 12) {
                        Text("今日已完成 \(stats.todayCount) 个番茄 🍅")
                            .font(.headline)
                        HStack(alignment: .bottom, spacing: 10) {
                            ForEach(stats.recentDays(7)) { day in
                                VStack(spacing: 4) {
                                    Text("\(day.count)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(day.isToday
                                              ? phaseColor
                                              : Color.accentColor.opacity(0.6))
                                        .frame(width: 28, height: barHeight(for: day.count))
                                    Text(day.label)
                                        .font(.caption2)
                                        .foregroundStyle(day.isToday ? .primary : .secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
            .navigationTitle("番茄钟")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .alert("确定要重置吗？", isPresented: $showingResetConfirm) {
                Button("重置", role: .destructive) {
                    viewModel.reset()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("当前计时进度和本轮计数将被清空。")
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    viewModel.handleDidBecomeActive()
                    stats.refreshToday()
                }
            }
        }
    }

    // MARK: - Helpers

    private var phaseTitle: String {
        switch viewModel.phase {
        case .focus:
            return viewModel.isRunning ? "专注中 🍅" : "专注（已暂停）"
        case .shortBreak:
            return "短休息 ☕"
        case .longBreak:
            return "长休息 🌿"
        }
    }

    private var phaseColor: Color {
        switch viewModel.phase {
        case .focus: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }

    private func barHeight(for count: Int) -> CGFloat {
        CGFloat(min(count, 8)) * 10 + 6
    }
}
