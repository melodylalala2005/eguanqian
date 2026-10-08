import SwiftUI

struct GoalsRootView: View {
    @StateObject private var viewModel: GoalsViewModel
    @State private var selectedType: GoalSyncPayload.GoalType = .saving
    @State private var isPresentingBudgetSheet = false
    @State private var isPresentingNewGoalSheet = false
    @State private var draft = GoalDraft()
    @State private var budgetInput: String = "4000"

    init(environment: FinanceEnvironment) {
        _viewModel = StateObject(wrappedValue: environment.makeGoalsViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                budgetCard
                goalTabs
                summarySection
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
        .navigationTitle("财务健康管理")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.refresh()
            budgetInput = viewModel.monthlyBudget.formattedCurrency()
        }
        .sheet(isPresented: $isPresentingBudgetSheet) {
            budgetSheet
        }
        .sheet(isPresented: $isPresentingNewGoalSheet) {
            newGoalSheet
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("财务健康管理")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("管理预算，设定目标，追踪进度")
                    .font(.footnote)
                    .foregroundStyle(StatisticsPalette.mutedText)
            }
            Spacer()
            Button {
                draft = GoalDraft()
                isPresentingNewGoalSheet = true
            } label: {
                Label("新建目标", systemImage: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(StatisticsPalette.primary)
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
            }
        }
    }

    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                Circle()
                    .fill(StatisticsPalette.primary.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(StatisticsPalette.primary)
                    }
                VStack(alignment: .leading, spacing: 6) {
                    Text("月度预算设置")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("当前月度预算：\(viewModel.monthlyBudget.formattedCurrency())")
                        .font(.subheadline)
                        .foregroundStyle(StatisticsPalette.mutedText)
                    Text("此预算将在首页预算条显示")
                        .font(.caption2)
                        .foregroundStyle(StatisticsPalette.mutedText.opacity(0.9))
                }
                Spacer()
            }

            Button {
                budgetInput = viewModel.monthlyBudget.formattedNumber()
                isPresentingBudgetSheet = true
            } label: {
                Text("调整预算")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.white.opacity(0.75))
                    .clipShape(Capsule())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    StatisticsPalette.primary.opacity(0.18),
                    StatisticsPalette.primary.opacity(0.08),
                    StatisticsPalette.primarySoft.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(StatisticsPalette.primary.opacity(0.15), lineWidth: 1)
        }
        .shadow(color: StatisticsPalette.cardShadow.opacity(0.4), radius: 10, y: 6)
    }

    private var goalTabs: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("", selection: $selectedType) {
                ForEach(GoalSyncPayload.GoalType.allCases, id: \.self) { type in
                    Text(tabLabel(for: type))
                        .tag(type)
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 16) {
                let goals = viewModel.goals(for: selectedType)
                if goals.isEmpty {
                    GoalEmptyState(type: selectedType)
                } else {
                    ForEach(goals) { goal in
                        GoalCard(goal: goal)
                    }
                }
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("目标概览")
                .font(.headline)
                .foregroundStyle(.primary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                SummaryChip(
                    iconName: "figure.strengthtraining.traditional",
                    title: "活跃目标",
                    value: "\(viewModel.activeGoalCount)"
                )
                SummaryChip(
                    iconName: "target",
                    title: "总目标金额",
                    value: viewModel.totalTargetAmount.formattedCurrency()
                )
                SummaryChip(
                    iconName: "checkmark.seal.fill",
                    title: "已完成金额",
                    value: viewModel.totalCurrentAmount.formattedCurrency()
                )
            }
        }
    }

    private func tabLabel(for type: GoalSyncPayload.GoalType) -> String {
        switch type {
        case .saving:
            return "攒钱 (\(viewModel.goals(for: .saving).count))"
        case .investment:
            return "理财 (\(viewModel.goals(for: .investment).count))"
        case .debt:
            return "贷款 (\(viewModel.goals(for: .debt).count))"
        }
    }

    private var budgetSheet: some View {
        NavigationStack {
            Form {
                Section("月度预算金额") {
                    TextField("4000", text: $budgetInput)
                        .keyboardType(.decimalPad)
                }
                Section {
                    Button("保存预算") {
                        let sanitized = budgetInput.replacingOccurrences(of: ",", with: "")
                        if let amount = Decimal(string: sanitized) {
                            viewModel.updateMonthlyBudget(to: amount)
                            isPresentingBudgetSheet = false
                        }
                    }
                }
            }
            .navigationTitle("设置月度预算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresentingBudgetSheet = false
                    }
                }
            }
        }
    }

    private var newGoalSheet: some View {
        NavigationStack {
            Form {
                Section("目标类型") {
                    Picker("类型", selection: $draft.type) {
                        Text("攒钱").tag(GoalSyncPayload.GoalType.saving)
                        Text("理财").tag(GoalSyncPayload.GoalType.investment)
                        Text("贷款").tag(GoalSyncPayload.GoalType.debt)
                    }
                    .pickerStyle(.segmented)
                }

                Section("目标信息") {
                    TextField("目标名称", text: $draft.title)
                    TextField("目标金额", text: $draft.targetAmountText)
                        .keyboardType(.decimalPad)
                    DatePicker("截止日期", selection: $draft.deadline, displayedComponents: .date)
                    TextField("类别（选填）", text: $draft.category)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button("创建目标") {
                        Task {
                            let success = await viewModel.addGoal(from: draft)
                            if success {
                                draft.reset()
                                isPresentingNewGoalSheet = false
                            }
                        }
                    }
                }
            }
            .navigationTitle("新建目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresentingNewGoalSheet = false
                    }
                }
            }
        }
    }
}

private struct GoalCard: View {
    let goal: GoalItem

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "scope")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(StatisticsPalette.primary)
                        Text(goal.title)
                            .font(.headline)
                    }
                    Text(goal.category)
                        .font(.caption)
                        .foregroundStyle(StatisticsPalette.mutedText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(goal.currentAmount.formattedCurrency())
                        .font(.title3.weight(.bold))
                    Text("/ \(goal.targetAmount.formattedCurrency())")
                        .font(.caption)
                        .foregroundStyle(StatisticsPalette.mutedText)
                }
            }

            ProgressView(value: goal.progress)
                .tint(StatisticsPalette.primary)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("进度")
                        .font(.caption)
                        .foregroundStyle(StatisticsPalette.mutedText)
                    Text("\(Int(goal.progress * 100))%")
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 6) {
                    Text(goal.type == .debt ? "还需还款" : "还需")
                        .font(.caption)
                        .foregroundStyle(StatisticsPalette.mutedText)
                    Text(goal.remainingAmount.formattedCurrency())
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("剩余天数")
                        .font(.caption)
                        .foregroundStyle(StatisticsPalette.mutedText)
                    Text("\(goal.daysLeft) 天")
                        .font(.headline)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: StatisticsPalette.cardShadow, radius: 14, y: 8)
    }
}

private struct GoalEmptyState: View {
    let type: GoalSyncPayload.GoalType

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 40))
                .foregroundStyle(StatisticsPalette.mutedText.opacity(0.6))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(StatisticsPalette.mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: StatisticsPalette.cardShadow.opacity(0.5), radius: 12, y: 6)
    }

    private var message: String {
        switch type {
        case .saving: return "暂无攒钱目标"
        case .investment: return "暂无理财目标"
        case .debt: return "暂无贷款目标"
        }
    }

    private var iconName: String {
        switch type {
        case .saving: return "banknote"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .debt: return "creditcard"
        }
    }
}

private struct SummaryChip: View {
    let iconName: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(StatisticsPalette.primarySoft)
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(StatisticsPalette.primary)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(StatisticsPalette.mutedText)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: StatisticsPalette.cardShadow.opacity(0.7), radius: 12, y: 6)
    }
}

