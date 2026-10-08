import SwiftUI

struct FinancialHealthView: View {
    @ObservedObject var viewModel: FinancialHealthViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: FinanceSpacing.sectionSpacing) {
                pageHeader
                budgetCard
                assetsSection
                goalsSection
                summarySection
            }
            .padding(.horizontal, FinanceSpacing.pageHorizontal)
            .padding(.top, 24)
            .padding(.bottom, 40)
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
        .overlay(modalOverlay)
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("财务健康管理")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(FinanceColors.neutralText)
            Text("管理预算，设定目标，追踪进度")
                .font(FinanceTypography.captionFont())
                .foregroundStyle(FinanceColors.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var budgetCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: FinanceCorners.large, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#EEF3FF") ?? StatisticsPalette.primary.opacity(0.12),
                            Color(hex: "#FBFCFF") ?? Color.white
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: FinanceCorners.large, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    StatisticsPalette.primary.opacity(0.28),
                                    StatisticsPalette.primary.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: StatisticsPalette.primary.opacity(0.14), radius: 16, y: 10)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    PiggybankBadge(size: 40)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("月度预算设置")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(FinanceColors.neutralText)
                        Text("管理预算，设定目标，追踪进度")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(FinanceColors.mutedText.opacity(0.9))
                    }

                    Spacer(minLength: 8)

                    Button {
                        viewModel.presentBudgetEditor()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(StatisticsPalette.primary)
                            .padding(9)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.96),
                                        Color.white.opacity(0.78)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        StatisticsPalette.primary.opacity(0.22),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .accessibilityLabel("调整预算")
                    .shadow(color: StatisticsPalette.primary.opacity(0.1), radius: 6, y: 3)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("当前月度预算")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FinanceColors.neutralText)
                    Text(viewModel.display.formattedBudget)
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(Color(hex: "#0F172A") ?? .primary)
                    Text("此预算将同步显示在首页预算条形图中")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(FinanceColors.mutedText.opacity(0.85))
                        .lineSpacing(2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity)
    }

    private var assetsSection: some View {
        VStack(alignment: .leading, spacing: FinanceSpacing.cardSpacing) {
            Text("资产负债表")
                .font(FinanceTypography.sectionTitleFont())
                .foregroundStyle(FinanceColors.neutralText)

            VStack(spacing: 18) {
                assetList(
                    title: "资产",
                    items: viewModel.display.assets,
                    accent: FinanceColors.accentPrimary,
                    total: viewModel.display.assetSummary,
                    onAdd: viewModel.presentAddAsset,
                    onEdit: viewModel.presentEditAsset,
                    onDelete: viewModel.deleteAsset
                )
                assetList(
                    title: "负债",
                    items: viewModel.display.debts,
                    accent: FinanceColors.danger,
                    total: viewModel.display.debtSummary,
                    onAdd: viewModel.presentAddLiability,
                    onEdit: viewModel.presentEditLiability,
                    onDelete: viewModel.deleteLiability
                )
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FinanceGradients.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: FinanceCorners.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FinanceCorners.large)
                    .stroke(FinanceColors.cardStroke)
            )
        }
    }

    private func assetList(
        title: String,
        items: [FinancialPortfolioItem],
        accent: Color,
        total: FinancialSummary,
        onAdd: @escaping () -> Void,
        onEdit: @escaping (FinancialPortfolioItem) -> Void,
        onDelete: @escaping (FinancialPortfolioItem) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(FinanceColors.neutralText)
                Spacer()
                Button(action: onAdd) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("添加")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(StatisticsPalette.primary.opacity(0.15))
                    .foregroundStyle(StatisticsPalette.primary)
                    .clipShape(Capsule())
                }
            }

            if items.isEmpty {
                RoundedRectangle(cornerRadius: FinanceCorners.medium, style: .continuous)
                    .fill(FinanceColors.cardStroke.opacity(0.3))
                    .frame(height: 80)
                    .overlay {
                        Text("暂无数据")
                            .font(FinanceTypography.captionFont())
                            .foregroundStyle(FinanceColors.mutedText)
                    }
            } else {
                VStack(spacing: 12) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(FinanceColors.neutralText)
                                    Text(item.formattedAmount)
                                        .font(FinanceTypography.captionFont())
                                        .foregroundStyle(FinanceColors.mutedText)
                                }
                                Spacer()
                                Text(item.formattedRate)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(accent)
                                HStack(spacing: 12) {
                                    Button { onEdit(item) } label: {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(FinanceColors.mutedText)
                                    }
                                    Button { onDelete(item) } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(FinanceColors.danger)
                                    }
                                }
                            }

                            if let term = item.term, !term.isEmpty {
                                Text(term)
                                    .font(FinanceTypography.captionFont())
                                    .foregroundStyle(FinanceColors.mutedText)
                            }
                            if let detail = item.detail, !detail.isEmpty {
                                Text(detail)
                                    .font(FinanceTypography.captionFont())
                                    .foregroundStyle(FinanceColors.mutedText)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity)
                        .background(FinanceColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FinanceCorners.medium)
                                .stroke(FinanceColors.cardStroke.opacity(0.6))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FinanceCorners.medium, style: .continuous))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(total.title)
                        .font(FinanceTypography.captionFont())
                        .foregroundStyle(FinanceColors.mutedText)
                    Spacer()
                    Text(total.amountText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accent)
                }
                if let detail = total.detail, !detail.isEmpty {
                    Text(detail)
                        .font(FinanceTypography.captionFont())
                        .foregroundStyle(accent)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(FinanceColors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: FinanceCorners.medium)
                    .stroke(FinanceColors.cardStroke.opacity(0.6))
            )
            .clipShape(RoundedRectangle(cornerRadius: FinanceCorners.medium, style: .continuous))
        }
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                HStack(spacing: 10) {
                    iconBadge(systemName: "target")
                        .frame(width: 36, height: 36)
                    Text("攒钱目标 (\(viewModel.display.goals.count))")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(FinanceColors.neutralText)
                }
                Spacer()
                Button(action: viewModel.presentAddGoal) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("添加")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(StatisticsPalette.primary)
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
                }
            }

            if viewModel.display.goals.isEmpty {
                RoundedRectangle(cornerRadius: FinanceCorners.large, style: .continuous)
                    .fill(FinanceColors.cardBackground)
                    .frame(height: 120)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "piggybank")
                                .font(.system(size: 28))
                                .foregroundStyle(FinanceColors.mutedText.opacity(0.6))
                            Text("暂无攒钱目标")
                                .font(FinanceTypography.captionFont())
                                .foregroundStyle(FinanceColors.mutedText)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: FinanceCorners.large)
                            .stroke(FinanceColors.cardStroke.opacity(0.6))
                    )
            } else {
                VStack(spacing: 16) {
                    ForEach(viewModel.display.goals) { goal in
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(goal.name)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(FinanceColors.neutralText)
                                    Text(goal.category)
                                        .font(FinanceTypography.captionFont())
                                        .foregroundStyle(FinanceColors.mutedText)
                                }
                                Spacer()
                                HStack(spacing: 12) {
                                    Button { viewModel.presentEditGoal(goal) } label: {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(FinanceColors.mutedText)
                                    }
                                    Button { viewModel.deleteGoal(goal) } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(FinanceColors.danger)
                                    }
                                }
                            }

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(goal.progressAmount)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(FinanceColors.neutralText)
                                Text("/ \(goal.targetText)")
                                    .font(FinanceTypography.captionFont())
                                    .foregroundStyle(FinanceColors.mutedText)
                            }

                            GeometryReader { proxy in
                                let width = proxy.size.width * goal.progress
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: FinanceCorners.medium, style: .continuous)
                                        .fill(FinanceColors.cardStroke.opacity(0.6))
                                        .frame(height: 10)
                                    RoundedRectangle(cornerRadius: FinanceCorners.medium, style: .continuous)
                                        .fill(StatisticsPalette.primary)
                                        .frame(width: max(12, width), height: 10)
                                }
                            }
                            .frame(height: 10)

                            HStack {
                                goalStat(label: "进度", value: goal.progressText)
                                Spacer()
                                goalStat(label: "还需", value: goal.remainingAmount)
                                Spacer()
                                goalStat(
                                    label: "剩余天数",
                                    value: goal.remainingDaysText,
                                    accent: goal.isOverdue ? FinanceColors.danger : StatisticsPalette.primary
                                )
                            }
                        }
                        .padding(20)
                        .background(FinanceColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: FinanceCorners.large, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: FinanceCorners.large)
                                .stroke(FinanceColors.cardStroke.opacity(0.6))
                        )
                        .shadow(color: FinanceShadows.card.opacity(0.1), radius: 12, y: 6)
                    }
                }
            }
        }
    }

    private func goalStat(label: String, value: String, accent: Color = FinanceColors.mutedText) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(FinanceTypography.captionFont())
                .foregroundStyle(FinanceColors.mutedText)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
        }
    }

    private var summarySection: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            summaryCard(
                title: "活跃目标",
                value: "\(viewModel.display.summary.activeGoals)",
                icon: "chart.bar.fill",
                accent: StatisticsPalette.primary
            )
            summaryCard(
                title: "目标进度",
                value: viewModel.display.summary.goalCompletion,
                icon: "target",
                accent: StatisticsPalette.primary
            )
        }
    }

    private func summaryCard(title: String, value: String, icon: String, accent: Color) -> some View {
        HStack(alignment: .center, spacing: 16) {
            iconBadge(systemName: icon)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(FinanceTypography.captionFont())
                    .foregroundStyle(FinanceColors.mutedText)
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(FinanceColors.neutralText)
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FinanceColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: FinanceCorners.large, style: .continuous))
        .shadow(color: FinanceShadows.card.opacity(0.12), radius: 10, y: 6)
    }

    @ViewBuilder
    private var modalOverlay: some View {
        if let modal = viewModel.activeModal {
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { viewModel.dismissModal() }
                switch modal {
                case .budget:
                    budgetModal()
                case .asset(let mode):
                    assetModal(mode: mode)
                case .liability(let mode):
                    liabilityModal(mode: mode)
                case .goal(let mode):
                    goalModal(mode: mode)
                }
            }
            .transition(.opacity.combined(with: .scale))
            .animation(.easeInOut(duration: 0.2), value: viewModel.activeModal)
        }
    }

    private func budgetModal() -> some View {
        modalContainer(
            title: "调整预算",
            subtitle: "此预算将同步显示在首页预算条形图中",
            primaryTitle: "保存预算",
            primaryDisabled: false,
            primaryAction: viewModel.saveBudget,
            errorMessage: viewModel.formErrorMessage
        ) {
            FinancialFormTextField(
                title: "预算金额 (¥)",
                placeholder: "例如：4000",
                text: $viewModel.budgetDraft.amountText,
                keyboardType: .numberPad
            )
        }
    }

    private func assetModal(mode: FinancialFormMode) -> some View {
        modalContainer(
            title: mode == .create ? "添加资产" : "编辑资产",
            primaryTitle: mode == .create ? "添加资产" : "更新资产",
            primaryDisabled: false,
            primaryAction: viewModel.saveAsset,
            errorMessage: viewModel.formErrorMessage
        ) {
            FinancialFormTextField(
                title: "类别",
                placeholder: "例如：储蓄、投资理财",
                text: $viewModel.assetDraft.category
            )
            FinancialFormTextField(
                title: "金额 (¥)",
                placeholder: "例如：30000",
                text: $viewModel.assetDraft.amountText,
                keyboardType: .decimalPad
            )
            FinancialFormTextField(
                title: "利率 (%)",
                placeholder: "例如：2.1",
                text: $viewModel.assetDraft.rateText,
                keyboardType: .decimalPad
            )
            FinancialFormTextField(
                title: "期限 (可选)",
                placeholder: "例如：12个月",
                text: $viewModel.assetDraft.term
            )
            FinancialFormTextField(
                title: "详情 (可选)",
                placeholder: "例如：预期年化收益 4.5%",
                text: $viewModel.assetDraft.detail
            )
        }
    }

    private func liabilityModal(mode: FinancialFormMode) -> some View {
        modalContainer(
            title: mode == .create ? "添加负债" : "编辑负债",
            primaryTitle: mode == .create ? "添加负债" : "更新负债",
            primaryDisabled: false,
            primaryAction: viewModel.saveLiability,
            errorMessage: viewModel.formErrorMessage
        ) {
            FinancialFormTextField(
                title: "类别",
                placeholder: "例如：信用卡、房贷",
                text: $viewModel.liabilityDraft.category
            )
            FinancialFormTextField(
                title: "金额 (¥)",
                placeholder: "例如：10000",
                text: $viewModel.liabilityDraft.amountText,
                keyboardType: .decimalPad
            )
            FinancialFormTextField(
                title: "利率 (%)",
                placeholder: "例如：18.0",
                text: $viewModel.liabilityDraft.rateText,
                keyboardType: .decimalPad
            )
        }
    }

    private func goalModal(mode: FinancialFormMode) -> some View {
        modalContainer(
            title: mode == .create ? "创建新目标" : "编辑目标",
            primaryTitle: mode == .create ? "创建目标" : "更新目标",
            primaryDisabled: false,
            primaryAction: viewModel.saveGoal,
            errorMessage: viewModel.formErrorMessage
        ) {
            FinancialFormTextField(
                title: "目标名称",
                placeholder: "例如：旅行基金",
                text: $viewModel.goalDraft.name
            )
            FinancialFormTextField(
                title: "目标金额 (¥)",
                placeholder: "例如：15000",
                text: $viewModel.goalDraft.targetText,
                keyboardType: .decimalPad
            )
            FinancialDateField(
                title: "截止日期",
                selection: $viewModel.goalDraft.deadline
            )
            FinancialFormTextField(
                title: "类别",
                placeholder: "例如：储蓄、教育",
                text: $viewModel.goalDraft.category
            )
        }
    }

    private func modalContainer<Content: View>(
        title: String,
        subtitle: String? = nil,
        primaryTitle: String,
        primaryDisabled: Bool,
        primaryAction: @escaping () -> Void,
        errorMessage: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(FinanceColors.neutralText)
                    if let subtitle {
                        Text(subtitle)
                            .font(FinanceTypography.captionFont())
                            .foregroundStyle(FinanceColors.mutedText)
                    }
                }
                Spacer()
                Button(action: viewModel.dismissModal) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FinanceColors.mutedText)
                        .padding(8)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FinanceColors.danger)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(FinanceColors.danger.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(spacing: 16) {
                content()
            }

            FinancialPrimaryButton(title: primaryTitle, action: primaryAction, disabled: primaryDisabled)
        }
        .padding(24)
        .frame(maxWidth: 380)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: StatisticsPalette.cardShadow.opacity(0.28), radius: 28, y: 18)
    }

    private func iconBadge(systemName: String) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [StatisticsPalette.primary.opacity(0.26), StatisticsPalette.primary.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(StatisticsPalette.primary)
        }
    }
}

private struct PiggybankBadge: View {
    var size: CGFloat = 82

    var body: some View {
        let circleSize = size
        let highlightSize = circleSize * 0.78
        let innerCircleSize = circleSize * 0.8
        let blurStrokeWidth = max(circleSize * 0.12, 5.5)
        let blurRadius = circleSize * 0.22
        let iconSize = circleSize * 0.36

        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#D7DBFF") ?? StatisticsPalette.primary.opacity(0.45),
                            Color(hex: "#BFC5FF") ?? StatisticsPalette.primary.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.7),
                                    Color.white.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.2
                        )
                )
                .shadow(color: StatisticsPalette.primary.opacity(0.18), radius: circleSize * 0.2, y: circleSize * 0.1)
                .frame(width: circleSize, height: circleSize)

            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: blurStrokeWidth)
                .blur(radius: blurRadius)
                .opacity(0.9)
                .frame(width: circleSize, height: circleSize)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.7),
                            Color.white.opacity(0.05)
                        ],
                        center: .center,
                        startRadius: circleSize * 0.08,
                        endRadius: innerCircleSize
                    )
                )
                .frame(width: highlightSize, height: highlightSize)
                .opacity(0.8)

            Image(systemName: "piggybank.fill")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(Color(hex: "#E9EAFF") ?? .white)
                .overlay(
                    Image(systemName: "piggybank")
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(Color(hex: "#2F2F8F") ?? StatisticsPalette.primary)
                )
                .shadow(color: StatisticsPalette.primary.opacity(0.28), radius: circleSize * 0.18, y: circleSize * 0.08)
        }
        .frame(width: circleSize, height: circleSize)
    }
}

private struct FinancialFormTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FinanceColors.mutedText)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(StatisticsPalette.outline.opacity(0.8), lineWidth: 1)
                    )
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(FinanceColors.mutedText.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                TextField("", text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .foregroundStyle(FinanceColors.neutralText)
            }
        }
    }
}

private struct FinancialDateField: View {
    let title: String
    @Binding var selection: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FinanceColors.mutedText)
            HStack {
                DatePicker("", selection: $selection, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(StatisticsPalette.primary)
                Spacer()
                Image(systemName: "calendar")
                    .foregroundStyle(StatisticsPalette.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(StatisticsPalette.outline.opacity(0.8), lineWidth: 1)
                    .background(Color.white.cornerRadius(18))
            )
        }
    }
}

private struct FinancialPrimaryButton: View {
    let title: String
    let action: () -> Void
    var disabled: Bool

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [StatisticsPalette.primary, Color(hex: "#4338CA") ?? StatisticsPalette.primary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(Color.white)
                .clipShape(Capsule())
        }
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }
}

#Preview {
    NavigationStack {
        FinancialHealthView(viewModel: FinancialHealthViewModel.previewModel())
    }
}
