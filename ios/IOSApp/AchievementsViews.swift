import SwiftUI

struct AchievementsRootView: View {
    @ObservedObject private var viewModel: AchievementsViewModel

    init(viewModel: AchievementsViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                progressOverview
                unlockedSection
                lockedSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(
            LinearGradient(
                colors: [StatisticsPalette.pageBackgroundTop, StatisticsPalette.pageBackgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("成就徽章")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("成就徽章")
                .font(.title2.weight(.semibold))
            Text("已解锁 \(viewModel.unlockedCount) / \(viewModel.totalCount) 个成就")
                .font(.footnote)
                .foregroundStyle(StatisticsPalette.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("总体进度")
                    .font(.headline)
                Spacer()
                Text("\(Int(round(viewModel.progressPercent * 100)))%")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(StatisticsPalette.primary)
            }
            ProgressView(value: viewModel.progressPercent)
                .tint(StatisticsPalette.primary)
            Text("继续努力，解锁更多成就获得奖励！")
                .font(.caption)
                .foregroundStyle(StatisticsPalette.mutedText)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: StatisticsPalette.cardShadow, radius: 14, y: 8)
    }

    private var unlockedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("已解锁")
                .font(.headline)
            if viewModel.unlockedAchievements.isEmpty {
                Text("暂未解锁成就，继续保持记账习惯吧！")
                    .font(.footnote)
                    .foregroundStyle(StatisticsPalette.mutedText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                    .background(Color.white.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(viewModel.unlockedAchievements) { achievement in
                        AchievementCard(item: achievement, state: .unlocked)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lockedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("未解锁")
                .font(.headline)
            if viewModel.lockedAchievements.isEmpty {
                Text("暂无待解锁的成就")
                    .font(.footnote)
                    .foregroundStyle(StatisticsPalette.mutedText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                    .background(Color.white.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(viewModel.lockedAchievements) { achievement in
                        AchievementCard(item: achievement, state: .locked)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AchievementCard: View {
    enum State {
        case unlocked
        case locked
    }

    let item: AchievementDetailItem
    let state: State

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(state == .unlocked ? item.color : StatisticsPalette.progressBackground)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: iconName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(state == .unlocked ? Color.white : StatisticsPalette.mutedText)
                    }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.title)
                            .font(.headline)
                        Spacer()
                        Image(systemName: state == .unlocked ? "checkmark.circle.fill" : "lock.fill")
                            .foregroundStyle(state == .unlocked ? Color.green : StatisticsPalette.mutedText.opacity(0.7))
                    }
                    Text(item.description)
                        .font(.subheadline)
                        .foregroundStyle(StatisticsPalette.mutedText)
                }
            }

            if state == .locked {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("进度")
                            .font(.caption)
                            .foregroundStyle(StatisticsPalette.mutedText)
                        Spacer()
                        Text("\(formatNumber(item.progress)) / \(formatNumber(item.maxProgress))")
                            .font(.caption.weight(.medium))
                    }
                    ProgressView(value: item.progressPercent)
                        .tint(StatisticsPalette.primary)
                }
            }

            HStack {
                Text("奖励：\(item.reward)")
                    .font(.caption.weight(.semibold))
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(state == .unlocked ? item.color.opacity(0.15) : StatisticsPalette.progressBackground.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(state == .unlocked ? 1 : 0.85))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: StatisticsPalette.cardShadow.opacity(state == .unlocked ? 1 : 0.6), radius: 12, y: 6)
    }

    private var iconName: String {
        if state == .unlocked {
            return item.iconName
        }
        return "lock.fill"
    }

    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

