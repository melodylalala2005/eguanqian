import Combine
import Charts
import SwiftUI

struct StatisticsAnalyticsView: View {
    @ObservedObject var viewModel: StatisticsAnalyticsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: FinanceSpacing.sectionSpacing) {
                pageHeader
                trendSection
                budgetSection
                categorySection
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
        .navigationTitle("统计洞察")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.refresh()
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("统计分析")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(FinanceColors.neutralText)
            Text("查看你的收支趋势和分类统计")
                .font(FinanceTypography.captionFont())
                .foregroundStyle(FinanceColors.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var periodSelector: some View {
        HStack(spacing: 12) {
            ForEach(viewModel.display.periods, id: \.self) { period in
                let isSelected = viewModel.display.selectedPeriod == period
                Button {
                    viewModel.select(period: period)
                } label: {
                    Text(period)
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .frame(minWidth: 0)
                }
                .background(isSelected ? StatisticsPalette.primary : Color.white.opacity(0.9))
                .foregroundStyle(isSelected ? Color.white : StatisticsPalette.mutedText)
                .overlay(
                    Capsule()
                        .stroke(StatisticsPalette.outline.opacity(isSelected ? 0 : 1), lineWidth: 1)
                )
                .clipShape(Capsule())
                .shadow(
                    color: StatisticsPalette.cardShadow.opacity(isSelected ? 0.25 : 0),
                    radius: 10,
                    y: 4
                )
            }
        }
    }

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("财务分配情况")
                .font(FinanceTypography.sectionTitleFont())
                .foregroundStyle(FinanceColors.neutralText)

            if viewModel.budgetSections.isEmpty {
                RoundedRectangle(cornerRadius: FinanceCorners.medium, style: .continuous)
                    .fill(FinanceColors.cardStroke.opacity(0.3))
                    .frame(height: 160)
                    .overlay {
                        Text("暂无预算分配数据")
                            .font(FinanceTypography.captionFont())
                            .foregroundStyle(FinanceColors.mutedText)
                    }
            } else {
                VStack(spacing: 24) {
                    ForEach(viewModel.budgetSections) { section in
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                Text(section.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(FinanceColors.neutralText)
                                Spacer()
                                HStack(spacing: 8) {
                                    Text("目标占比")
                                        .font(FinanceTypography.captionFont())
                                        .foregroundStyle(FinanceColors.mutedText)
                                    TextField(
                                        "0",
                                        text: viewModel.bindingForBudgetTarget(section.identifier)
                                    )
                                    .textFieldStyle(.plain)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(width: 54)
                                    .padding(.vertical, 6)
                                    .background(FinanceColors.cardStroke.opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: FinanceCorners.small, style: .continuous))
                                    Text("%")
                                        .font(FinanceTypography.captionFont())
                                        .foregroundStyle(FinanceColors.mutedText)
                                }
                            }

                            HStack {
                                Text(section.actualAmountText)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(FinanceColors.neutralText)
                                Spacer()
                                Text(section.targetAmountText)
                                    .font(FinanceTypography.captionFont())
                                    .foregroundStyle(FinanceColors.mutedText)
                            }

                            budgetProgressView(for: section)

                            HStack {
                                Text(section.differenceText)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(section.isOver ? StatisticsPalette.expense : StatisticsPalette.income)
                                Spacer()
                                Text(section.actualShareText)
                                    .font(FinanceTypography.captionFont())
                                    .foregroundStyle(FinanceColors.mutedText)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FinanceColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: FinanceCorners.large, style: .continuous))
        .shadow(color: FinanceShadows.card.opacity(0.16), radius: 12, y: 8)
    }

    @ViewBuilder
    private func budgetProgressView(for section: StatisticsBudgetSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let clamped = min(max(section.progress, 0), 1)
                let fillWidth = max(proxy.size.width * CGFloat(clamped), clamped > 0 ? 6 : 0)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: FinanceCorners.medium, style: .continuous)
                        .fill(FinanceColors.cardStroke.opacity(0.65))
                        .frame(height: 16)
                    if fillWidth > 0 {
                        RoundedRectangle(cornerRadius: FinanceCorners.medium, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: section.gradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: fillWidth, height: 16)
                    }
                }
            }
            .frame(height: 16)

            HStack {
                Text("进度 \(section.progressText)")
                Spacer()
                Text(section.targetShareText)
            }
            .font(FinanceTypography.captionFont())
            .foregroundStyle(FinanceColors.mutedText)
        }
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text("收支趋势")
                    .font(FinanceTypography.sectionTitleFont())
                    .foregroundStyle(FinanceColors.neutralText)
                Spacer()
                trendScopePicker
            }

            VStack(alignment: .leading, spacing: 16) {
                Chart {
                    ForEach(viewModel.trendSeries) { datum in
                        BarMark(
                            x: .value("周期", datum.label),
                            y: .value("支出", datum.expense.asDouble)
                        )
                        .foregroundStyle(StatisticsPalette.expense)
                        .cornerRadius(10)
                        .position(by: .value("类型", "支出"))

                        BarMark(
                            x: .value("周期", datum.label),
                            y: .value("收入", datum.income.asDouble)
                        )
                        .foregroundStyle(StatisticsPalette.income)
                        .cornerRadius(10)
                        .position(by: .value("类型", "收入"))
                    }
                }
                .frame(height: 220)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(StatisticsPalette.divider.opacity(0.25))
                        AxisValueLabel()
                            .font(.system(size: 11))
                            .foregroundStyle(StatisticsPalette.mutedText)
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(StatisticsPalette.divider.opacity(0.15))
                        AxisValueLabel()
                            .font(.system(size: 11))
                            .foregroundStyle(StatisticsPalette.mutedText)
                    }
                }
                .chartLegend(position: .bottom, spacing: 12)
                .chartForegroundStyleScale([
                    "支出": StatisticsPalette.expense,
                    "收入": StatisticsPalette.income
                ])
                .overlay {
                    if viewModel.trendSeries.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 26, weight: .medium))
                                .foregroundStyle(FinanceColors.mutedText)
                            Text("暂无趋势数据")
                                .font(FinanceTypography.captionFont())
                                .foregroundStyle(FinanceColors.mutedText)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(FinanceColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: FinanceCorners.large, style: .continuous))
            .shadow(color: FinanceShadows.card.opacity(0.16), radius: 12, y: 8)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("分类报表")
                    .font(FinanceTypography.sectionTitleFont())
                    .foregroundStyle(FinanceColors.neutralText)
                Spacer()
                HStack(spacing: 10) {
                    Button {
                        viewModel.selectCategoryKind(.expense)
                    } label: {
                        Text("支出")
                            .font(FinanceTypography.captionFont())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(viewModel.selectedCategoryKind == .expense ? StatisticsPalette.primary : FinanceColors.cardStroke.opacity(0.6))
                            .foregroundStyle(viewModel.selectedCategoryKind == .expense ? Color.white : FinanceColors.neutralText)
                            .clipShape(Capsule())
                    }
                    Button {
                        viewModel.selectCategoryKind(.income)
                    } label: {
                        Text("收入")
                            .font(FinanceTypography.captionFont())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(viewModel.selectedCategoryKind == .income ? StatisticsPalette.primary : FinanceColors.cardStroke.opacity(0.6))
                            .foregroundStyle(viewModel.selectedCategoryKind == .income ? Color.white : FinanceColors.neutralText)
                            .clipShape(Capsule())
                    }
                }
            }

            if viewModel.display.categories.isEmpty {
                RoundedRectangle(cornerRadius: FinanceCorners.medium, style: .continuous)
                    .fill(FinanceColors.cardStroke.opacity(0.3))
                    .frame(height: 180)
                    .overlay {
                        Text("暂无分类数据")
                            .font(FinanceTypography.captionFont())
                            .foregroundStyle(FinanceColors.mutedText)
                    }
            } else {
                VStack(spacing: 24) {
                    Chart(viewModel.display.categories) { category in
                        SectorMark(
                            angle: .value("金额", category.rawAmount.asDouble),
                            innerRadius: .ratio(0.58),
                            outerRadius: .ratio(0.95)
                        )
                        .cornerRadius(6)
                        .foregroundStyle(category.color)
                    }
                    .frame(height: 220)
                    .chartLegend(.hidden)
                    .padding(.top, 8)

                    VStack(spacing: 12) {
                        ForEach(viewModel.display.categories) { category in
                            HStack {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(category.color)
                                        .frame(width: 10, height: 10)
                                    Text(category.name)
                                        .font(FinanceTypography.bodyFont())
                                        .foregroundStyle(FinanceColors.neutralText)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(category.amount)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(FinanceColors.neutralText)
                                    Text(category.percentage)
                                        .font(FinanceTypography.captionFont())
                                        .foregroundStyle(FinanceColors.mutedText)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FinanceColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: FinanceCorners.large, style: .continuous))
        .shadow(color: FinanceShadows.card.opacity(0.16), radius: 12, y: 8)
    }

    private var trendScopePicker: some View {
        Picker("", selection: Binding(
            get: { viewModel.selectedTrendScope },
            set: { viewModel.selectTrendScope($0) }
        )) {
            ForEach(StatisticsTrendScope.allCases) { scope in
                Text(scope.title).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 200)
    }
}

// MARK: - Display Models

struct StatisticsDisplayModel {
    var userName: String
    var totalExpense: Decimal
    var expenseMoM: String
    var expenseTrendDirection: FinanceTrendDirection?
    var totalIncome: Decimal
    var incomeMoM: String
    var incomeTrendDirection: FinanceTrendDirection?
    var netIncome: Decimal
    var netMoM: String
    var netTrendDirection: FinanceTrendDirection?
    var periods: [String]
    var selectedPeriod: String
    var highlights: [StatisticsHighlight]
    var categories: [StatisticsCategory]
    var insights: [StatisticsInsight]

    var formattedTotalExpense: String {
        totalExpense.formatted(.currency(code: "CNY"))
    }

    var formattedIncome: String {
        totalIncome.formatted(.currency(code: "CNY"))
    }

    var formattedNet: String {
        netIncome.formatted(.currency(code: "CNY"))
    }
}

extension StatisticsDisplayModel {
    static func empty(userName: String, periods: [String], selected: String) -> StatisticsDisplayModel {
        StatisticsDisplayModel(
            userName: userName,
            totalExpense: .zero,
            expenseMoM: "--",
            expenseTrendDirection: nil,
            totalIncome: .zero,
            incomeMoM: "--",
            incomeTrendDirection: nil,
            netIncome: .zero,
            netMoM: "--",
            netTrendDirection: nil,
            periods: periods,
            selectedPeriod: selected,
            highlights: [],
            categories: [],
            insights: []
        )
    }
}

struct StatisticsHighlight: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let caption: String
    let captionColor: Color
}

struct StatisticsCategory: Identifiable {
    let id = UUID()
    let name: String
    let amount: String
    let percentage: String
    let rawAmount: Decimal
    let ratio: Decimal
    let color: Color
}

struct StatisticsInsight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let accent: Color
}

struct StatisticsBudgetSection: Identifiable {
    let id = UUID()
    let identifier: String
    let title: String
    let actualAmount: Decimal
    let targetAmount: Decimal
    let actualShare: Decimal
    let targetShare: Decimal
    let gradient: [Color]

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return (actualAmount / targetAmount).asDouble
    }

    var isOver: Bool {
        actualAmount > targetAmount
    }

    var actualAmountText: String {
        actualAmount.formattedCurrency()
    }

    var targetAmountText: String {
        "目标 " + targetAmount.formattedCurrency()
    }

    var differenceText: String {
        let diff = (actualAmount - targetAmount).magnitude
        return (isOver ? "超出 " : "剩余 ") + diff.formattedCurrency()
    }

    var progressText: String {
        guard targetAmount > 0 else { return "0%" }
        return (actualAmount / targetAmount).formattedPercentage()
    }

    var actualShareText: String {
        "当前占比 " + actualShare.formattedPercentage()
    }

    var targetShareText: String {
        "目标占比 " + targetShare.formattedPercentage()
    }
}

// MARK: - View Model

@MainActor
final class StatisticsAnalyticsViewModel: ObservableObject {
    private struct PeriodOption {
        let title: String
        let value: StatisticsAnalyticsPeriod
    }

    private enum BudgetIdentifier: String, CaseIterable {
        case basic
        case entertainment
        case savings

        var title: String {
            switch self {
            case .basic:
                return "基本支出"
            case .entertainment:
                return "娱乐支出"
            case .savings:
                return "投资储蓄"
            }
        }

        var gradient: [Color] {
            switch self {
            case .basic:
                return [StatisticsPalette.primary.opacity(0.85), StatisticsPalette.primary]
            case .entertainment:
                return [Color(hex: "#F97316") ?? StatisticsPalette.expense, Color(hex: "#FB923C") ?? StatisticsPalette.expense]
            case .savings:
                return [StatisticsPalette.income, StatisticsPalette.income.opacity(0.8)]
            }
        }

    }

    @Published private(set) var display: StatisticsDisplayModel
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var selectedCategoryKind: CategoryKind
    @Published private(set) var budgetSections: [StatisticsBudgetSection] = []
    @Published private(set) var budgetTargetInputs: [String: String] = [:]
    @Published private(set) var trendSeries: [StatisticSnapshot] = []
    @Published var selectedTrendScope: StatisticsTrendScope = .monthly {
        didSet {
            guard oldValue != selectedTrendScope else { return }
            applyTrendScope()
        }
    }

    private let aggregator: StatisticsAnalyticsAggregator
    private let userProfileService: UserProfileService?
    private let budgetService: BudgetService?
    private let calendar: Calendar
    private let periodOptions: [PeriodOption]
    private let eventBus: FinanceEventBus
    private var cancellable: AnyCancellable?
    private var currentOption: PeriodOption
    private var hasLoaded = false
    private let defaultBudgetTarget: [String: Decimal] = [
        BudgetIdentifier.basic.rawValue: Decimal(0.5),
        BudgetIdentifier.entertainment.rawValue: Decimal(0.3),
        BudgetIdentifier.savings.rawValue: Decimal(0.2)
    ]
    private var budgetTargets: [String: Decimal]
    private var latestSummary: StatisticsSummaryData?
    private var latestSpendingTypeTotals: [SpendingType: Decimal] = [:]
    private var budgetBaseAmount: Decimal?
    private var trendSeriesCache: [StatisticsTrendScope: [StatisticSnapshot]] = [:]

    init(
        aggregator: StatisticsAnalyticsAggregator,
        eventBus: FinanceEventBus,
        userProfileService: UserProfileService?,
        budgetService: BudgetService? = nil,
        calendar: Calendar = Calendar(identifier: .gregorian),
        initialDisplay: StatisticsDisplayModel? = nil,
        autoLoad: Bool = true
    ) {
        self.aggregator = aggregator
        self.eventBus = eventBus
        self.userProfileService = userProfileService
        self.budgetService = budgetService
        self.calendar = calendar
        self.periodOptions = [
            PeriodOption(title: "月度统计", value: .currentMonth),
            PeriodOption(title: "年度统计", value: .yearToDate)
        ]
        self.currentOption = periodOptions.first!
        let baseDisplay = StatisticsDisplayModel.empty(
            userName: userProfileService?.currentProfile?.userID ?? "记账助手",
            periods: periodOptions.map { $0.title },
            selected: periodOptions.first!.title
        )
        self.display = initialDisplay ?? baseDisplay
        self.selectedCategoryKind = .expense
        self.budgetTargets = defaultBudgetTarget
        self.syncBudgetInputs()
        observeEvents()

        if autoLoad {
            refresh(force: true)
        }
    }

    deinit {
        cancellable?.cancel()
    }

    private func observeEvents() {
        cancellable = eventBus.publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case .transactionsChanged(_),
                     .budgetSummaryUpdated(_),
                     .goalsChanged(_),
                     .userProfileUpdated(_):
                    self.refresh(force: true)
                }
            }
    }

    func select(period title: String) {
        guard let option = periodOptions.first(where: { $0.title == title }), option.title != display.selectedPeriod else {
            return
        }
        currentOption = option
        display.selectedPeriod = option.title
        refresh(force: true)
    }

    func refresh(force: Bool = false) {
        Task { [weak self] in
            guard let self else { return }
            await self.loadData(force: force)
        }
    }

    func selectCategoryKind(_ kind: CategoryKind) {
        guard kind != selectedCategoryKind else { return }
        selectedCategoryKind = kind
        refresh(force: true)
    }

    func selectTrendScope(_ scope: StatisticsTrendScope) {
        guard scope != selectedTrendScope else { return }
        selectedTrendScope = scope
    }

    func bindingForBudgetTarget(_ identifier: String) -> Binding<String> {
        Binding(
            get: { [weak self] in
                guard let self else { return "" }
                return budgetTargetInputs[identifier] ?? ""
            },
            set: { [weak self] newValue in
                Task { @MainActor [weak self] in
                    await self?.handleBudgetTargetInput(identifier: identifier, newValue: newValue)
                }
            }
        )
    }

    @MainActor
    private func loadData(force: Bool) async {
        if hasLoaded && !force { return }
        isLoading = true
        errorMessage = nil
        let referenceDate = Date()
        do {
            let summary = try aggregator.makeSummary(for: currentOption.value, referenceDate: referenceDate)
            let expenseCategories = try aggregator.makeCategoryBreakdown(
                for: currentOption.value,
                kind: .expense,
                referenceDate: referenceDate
            )
            let categories: [StatisticsCategoryBreakdown]
            if selectedCategoryKind == .expense {
                categories = expenseCategories
            } else {
                categories = try aggregator.makeCategoryBreakdown(
                    for: currentOption.value,
                    kind: .income,
                    referenceDate: referenceDate
                )
            }
            let spendingTypeTotals = try aggregator.makeSpendingTypeTotals(
                for: currentOption.value,
                referenceDate: referenceDate
            )
            let highlights = try aggregator.makeHighlights(for: currentOption.value, referenceDate: referenceDate)
            let profile = userProfileService?.currentProfile
            let insights = aggregator.makeInsights(summary: summary, categories: expenseCategories, profile: profile)
            latestSummary = summary
            latestSpendingTypeTotals = spendingTypeTotals
            if let budgetService {
                if let budgetSummary = try budgetService.currentSummary(on: referenceDate) {
                    budgetBaseAmount = budgetSummary.total
                } else if let plan = try budgetService.activePlan(), plan.totalLimit > .zero {
                    budgetBaseAmount = plan.totalLimit
                } else {
                    budgetBaseAmount = nil
                }
            } else {
                budgetBaseAmount = nil
            }
            trendSeriesCache[.monthly] = try aggregator.makeTrend(for: .currentMonth, referenceDate: referenceDate)
            trendSeriesCache[.yearly] = try aggregator.makeTrend(for: .yearToDate, referenceDate: referenceDate)
            applyTrendScope()
            updateBudgetSections(
                summary: summary,
                spendingTypeTotals: spendingTypeTotals
            )
            display = buildDisplay(
                summary: summary,
                categories: categories,
                highlights: highlights,
                insights: insights,
                profile: profile
            )
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
            display = StatisticsDisplayModel.empty(
                userName: userProfileService?.currentProfile?.userID ?? "记账助手",
                periods: periodOptions.map { $0.title },
                selected: currentOption.title
            )
        }
        isLoading = false
    }

    private func applyTrendScope() {
        trendSeries = trendSeriesCache[selectedTrendScope] ?? []
    }

    private func buildDisplay(
        summary: StatisticsSummaryData,
        categories: [StatisticsCategoryBreakdown],
        highlights: [StatisticsHighlightMetric],
        insights: [StatisticsInsightData],
        profile: UserProfileSnapshot?
    ) -> StatisticsDisplayModel {
        let (expenseMoM, expenseDirection) = formatTrend(summary.expenseTrend)
        let (incomeMoM, incomeDirection) = formatTrend(summary.incomeTrend)
        let (netMoM, netDirection) = formatTrend(summary.netTrend)

        return StatisticsDisplayModel(
            userName: profile?.userID ?? "记账助手",
            totalExpense: summary.totalExpense,
            expenseMoM: expenseMoM,
            expenseTrendDirection: expenseDirection,
            totalIncome: summary.totalIncome,
            incomeMoM: incomeMoM,
            incomeTrendDirection: incomeDirection,
            netIncome: summary.netIncome,
            netMoM: netMoM,
            netTrendDirection: netDirection,
            periods: periodOptions.map { $0.title },
            selectedPeriod: currentOption.title,
            highlights: highlights.map(mapHighlight),
            categories: categories.enumerated().map { index, breakdown in
                mapCategory(breakdown, index: index)
            },
            insights: insights.map(mapInsight)
        )
    }

    private func formatTrend(_ info: StatisticsTrendInfo?) -> (String, FinanceTrendDirection?) {
        guard let info else { return ("--", nil) }
        return (info.text, info.direction)
    }

    private func mapHighlight(_ metric: StatisticsHighlightMetric) -> StatisticsHighlight {
        StatisticsHighlight(
            title: metric.title,
            value: metric.valueText,
            caption: metric.captionText,
            captionColor: color(for: metric.tone)
        )
    }

    private func mapCategory(_ breakdown: StatisticsCategoryBreakdown, index: Int) -> StatisticsCategory {
        let palette = selectedCategoryKind == .expense
            ? StatisticsPalette.expenseCategoryPalette
            : StatisticsPalette.incomeCategoryPalette
        return StatisticsCategory(
            name: breakdown.name,
            amount: breakdown.amountText,
            percentage: breakdown.ratioText,
            rawAmount: breakdown.amount,
            ratio: breakdown.ratio,
            color: palette[index % palette.count]
        )
    }

    private func mapInsight(_ insight: StatisticsInsightData) -> StatisticsInsight {
        StatisticsInsight(
            icon: insight.icon,
            title: insight.title,
            detail: insight.detail,
            accent: insightColor(for: insight.tone)
        )
    }

    private func updateBudgetSections(
        summary: StatisticsSummaryData,
        spendingTypeTotals: [SpendingType: Decimal]
    ) {
        latestSummary = summary

        let baseline = budgetBaseAmount ?? summary.totalExpense
        guard baseline > .zero || summary.totalExpense > .zero else {
            budgetSections = []
            return
        }

        var actuals: [BudgetIdentifier: Decimal] = [:]
        let basic = spendingTypeTotals[.basic] ?? .zero
        let entertainment = spendingTypeTotals[.entertainment] ?? .zero
        let captured = basic + entertainment
        let savings = max(summary.totalExpense - captured, .zero)

        actuals[.basic] = basic
        actuals[.entertainment] = entertainment
        actuals[.savings] = savings

        var sections: [StatisticsBudgetSection] = []
        for identifier in BudgetIdentifier.allCases {
            let actual = actuals[identifier, default: .zero]
            let targetShare = budgetTargets[identifier.rawValue] ?? defaultBudgetTarget[identifier.rawValue] ?? .zero
            let targetAmount = (baseline > .zero ? baseline : summary.totalExpense) * targetShare
            let denominator = baseline > .zero ? baseline : summary.totalExpense
            let actualShare = denominator > .zero ? actual / denominator : .zero
            sections.append(
                StatisticsBudgetSection(
                    identifier: identifier.rawValue,
                    title: identifier.title,
                    actualAmount: actual,
                    targetAmount: targetAmount,
                    actualShare: actualShare,
                    targetShare: targetShare,
                    gradient: identifier.gradient
                )
            )
        }

        budgetSections = sections
        syncBudgetInputs()
    }

    private func syncBudgetInputs() {
        for identifier in BudgetIdentifier.allCases {
            let key = identifier.rawValue
            let value = budgetTargets[key] ?? defaultBudgetTarget[key] ?? .zero
            let percentage = (value * Decimal(100)).asDouble
            budgetTargetInputs[key] = String(format: "%.0f", percentage)
        }
    }

    private func normalizeBudgetTargets(anchor: String) {
        guard let anchorValue = budgetTargets[anchor] else { return }
        let limitedAnchor = min(max(anchorValue, .zero), 1)
        budgetTargets[anchor] = limitedAnchor

        let otherKeys = BudgetIdentifier.allCases
            .map(\.rawValue)
            .filter { $0 != anchor }

        guard !otherKeys.isEmpty else { return }

        let othersSum = otherKeys.reduce(Decimal.zero) { partial, key in
            partial + (budgetTargets[key] ?? defaultBudgetTarget[key] ?? .zero)
        }
        let remaining = max(Decimal(1) - limitedAnchor, .zero)

        if othersSum <= .zero {
            let equalShare = remaining / Decimal(otherKeys.count)
            for key in otherKeys {
                budgetTargets[key] = equalShare
            }
        } else {
            for key in otherKeys {
                let original = budgetTargets[key] ?? defaultBudgetTarget[key] ?? .zero
                budgetTargets[key] = original / othersSum * remaining
            }
        }
    }

    @MainActor
    private func handleBudgetTargetInput(identifier: String, newValue: String) async {
        budgetTargetInputs[identifier] = newValue

        let sanitized = newValue
            .replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
            .replacingOccurrences(of: ",", with: ".")

        guard let decimal = Decimal(string: sanitized.isEmpty ? "0" : sanitized) else {
            return
        }

        let clamped = max(Decimal.zero, min(decimal, 100))
        budgetTargets[identifier] = clamped / Decimal(100)
        normalizeBudgetTargets(anchor: identifier)
        syncBudgetInputs()

        if let summary = latestSummary {
            updateBudgetSections(summary: summary, spendingTypeTotals: latestSpendingTypeTotals)
        }
    }

    private func color(for tone: StatisticsHighlightTone) -> Color {
        switch tone {
        case .neutral:
            return FinanceColors.mutedText
        case .positive:
            return FinanceColors.success
        case .caution:
            return FinanceColors.danger
        }
    }

    private func insightColor(for tone: StatisticsInsightTone) -> Color {
        switch tone {
        case .neutral:
            return FinanceColors.accentSecondary
        case .positive:
            return FinanceColors.success
        case .warning:
            return FinanceColors.danger
        }
    }
}

extension StatisticsAnalyticsViewModel {
    static func preview() -> StatisticsAnalyticsViewModel {
        StatisticsAnalyticsViewModel(
            aggregator: PreviewStatisticsAggregator(),
            eventBus: FinanceEventBus(),
            userProfileService: nil,
            budgetService: nil
        )
    }
}

private struct PreviewStatisticsAggregator: StatisticsAnalyticsAggregator {
    func makeSummary(for period: StatisticsAnalyticsPeriod, referenceDate: Date) throws -> StatisticsSummaryData {
        StatisticsSummaryData(
            totalIncome: 10_800,
            totalExpense: 6_423,
            netIncome: 4_377,
            expenseTrend: StatisticsTrendInfo(text: "+12.8%", direction: .up),
            incomeTrend: StatisticsTrendInfo(text: "+3.5%", direction: .up),
            netTrend: StatisticsTrendInfo(text: "-6.3%", direction: .down)
        )
    }

    func makeTrend(for period: StatisticsAnalyticsPeriod, referenceDate: Date) throws -> [StatisticSnapshot] {
        [
            StatisticSnapshot(label: "01", income: 3500, expense: 3200),
            StatisticSnapshot(label: "02", income: 3600, expense: 3100),
            StatisticSnapshot(label: "03", income: 3700, expense: 2900)
        ]
    }

    func makeCategoryBreakdown(for period: StatisticsAnalyticsPeriod, kind: CategoryKind, referenceDate: Date) throws -> [StatisticsCategoryBreakdown] {
        [
            StatisticsCategoryBreakdown(name: "餐饮", amount: 1_850, amountText: "¥1,850", ratio: 0.28, ratioText: "28%", progress: 0.28),
            StatisticsCategoryBreakdown(name: "交通", amount: 920, amountText: "¥920", ratio: 0.14, ratioText: "14%", progress: 0.14),
            StatisticsCategoryBreakdown(name: "娱乐", amount: 780, amountText: "¥780", ratio: 0.12, ratioText: "12%", progress: 0.12)
        ]
    }

    func makeSpendingTypeTotals(for period: StatisticsAnalyticsPeriod, referenceDate: Date) throws -> [SpendingType : Decimal] {
        [
            .basic: 2_770,
            .entertainment: 780
        ]
    }

    func makeHighlights(for period: StatisticsAnalyticsPeriod, referenceDate: Date) throws -> [StatisticsHighlightMetric] {
        [
            StatisticsHighlightMetric(title: "固定支出", valueText: "¥3,200", captionText: "环比 +5.2%", tone: .caution),
            StatisticsHighlightMetric(title: "生活方式", valueText: "¥1,540", captionText: "环比 -2.1%", tone: .positive),
            StatisticsHighlightMetric(title: "投资收益", valueText: "¥980", captionText: "环比 +11.0%", tone: .positive)
        ]
    }

    func makeInsights(summary: StatisticsSummaryData, categories: [StatisticsCategoryBreakdown], profile: UserProfileSnapshot?) -> [StatisticsInsightData] {
        [
            StatisticsInsightData(icon: "lightbulb.fill", title: "建议调整娱乐预算", detail: "本月娱乐支出较上月提升 18%，可考虑设定更明确的周限额。", tone: .warning),
            StatisticsInsightData(icon: "chart.pie.fill", title: "固定支出偏高", detail: "固定支出占总支出 50% 以上，可结合预算页重新规划房租及订阅类支出。", tone: .neutral)
        ]
    }
}

#Preview {
    NavigationStack {
        StatisticsAnalyticsView(viewModel: StatisticsAnalyticsViewModel.preview())
    }
}
