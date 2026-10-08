import SwiftUI
import Charts

private let chartCurrencyFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencySymbol = "¥"
    formatter.maximumFractionDigits = 0
    formatter.minimumFractionDigits = 0
    formatter.usesGroupingSeparator = true
    return formatter
}()

struct StatisticsRootView: View {
    @StateObject private var viewModel: StatisticsViewModel

    init(environment: FinanceEnvironment) {
        _viewModel = StateObject(wrappedValue: environment.makeStatisticsViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection

                if let error = viewModel.errorMessage, !error.isEmpty {
                    errorBanner(error)
                }

                modeToggle

                if viewModel.isMonthlyMode, viewModel.availableYears.count > 1 {
                    yearSelector
                }

                if viewModel.isYearlyMode {
                    yearlyRangeSelector
                }

                overviewCard
                trendChartSection
                categoryBreakdownSection
                goalComparisonSection
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
        .navigationTitle("统计分析")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: viewModel.load) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("统计分析")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
            Text("查看你的收支趋势和分类统计")
                .font(.footnote)
                .foregroundStyle(StatisticsPalette.mutedText)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            Text(message)
                .font(.caption)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.red.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var modeToggle: some View {
        HStack(spacing: 12) {
            capsuleButton(
                title: "月度统计",
                isActive: viewModel.isMonthlyMode,
                action: { viewModel.selectMonthly() }
            )
            capsuleButton(
                title: "年度统计",
                isActive: viewModel.isYearlyMode,
                action: { viewModel.selectYearly() }
            )
        }
    }

    private var yearSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.availableYears, id: \.self) { year in
                    capsuleButton(
                        title: "\(year) 年",
                        isActive: viewModel.selectedYear == year,
                        compact: true,
                        action: {
                            viewModel.selectedYear = year
                            viewModel.load()
                        }
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var yearlyRangeSelector: some View {
        HStack(spacing: 10) {
            ForEach(viewModel.yearlyOptions, id: \.self) { option in
                capsuleButton(
                    title: "近 \(option) 年",
                    isActive: viewModel.yearlyLimit == option,
                    compact: true,
                    action: { viewModel.updateYearlyLimit(to: option) }
                )
            }
        }
    }

    private var overviewCard: some View {
        statisticsCard {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("收支总览")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("当前维度下的收入、支出与结余情况")
                        .font(.caption)
                        .foregroundStyle(StatisticsPalette.mutedText)
                }
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .tint(StatisticsPalette.primary)
                }
            }

            Divider()
                .background(StatisticsPalette.divider)

            HStack(spacing: 16) {
                overviewItem(
                    title: "收入",
                    value: viewModel.overview.totalIncome,
                    accent: StatisticsPalette.income,
                    subtitle: "累计收入"
                )
                overviewItem(
                    title: "支出",
                    value: viewModel.overview.totalExpense,
                    accent: StatisticsPalette.expense,
                    subtitle: "累计支出"
                )
                overviewItem(
                    title: "结余",
                    value: viewModel.overview.net,
                    accent: viewModel.overview.net >= 0 ? StatisticsPalette.income : StatisticsPalette.expense,
                    subtitle: viewModel.overview.net >= 0 ? "剩余金额" : "超出预算"
                )
            }
        }
    }

    private func overviewItem(title: String, value: Decimal, accent: Color, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(accent)
            Text(value.formattedCurrency())
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(StatisticsPalette.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(StatisticsPalette.primarySoft.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var trendChartSection: some View {
        statisticsCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("收支对比")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(viewModel.isMonthlyMode ? "\(viewModel.selectedYear) 年收支趋势" : "近 \(viewModel.yearlyLimit) 年收支趋势")
                    .font(.caption)
                    .foregroundStyle(StatisticsPalette.mutedText)

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else if viewModel.trendData.isEmpty || !viewModel.hasContent {
                    Text("暂无记录")
                        .font(.footnote)
                        .foregroundStyle(StatisticsPalette.mutedText)
                        .frame(height: 220, alignment: .center)
                        .frame(maxWidth: .infinity)
                } else {
                    Chart {
                        ForEach(viewModel.trendData) { datum in
                            BarMark(
                                x: .value("周期", datum.label),
                                y: .value("金额", datum.value),
                                width: .ratio(0.45)
                            )
                            .foregroundStyle(by: .value("类型", datum.series.rawValue))
                            .position(by: .value("系列", datum.series.rawValue))
                            .cornerRadius(10, style: .continuous)
                            .annotation(position: .top, alignment: .center) {
                                if datum.value > 0 {
                                    Text(formattedCurrency(datum.value))
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(StatisticsPalette.mutedText)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.white.opacity(0.6))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .frame(height: 240)
                    .chartPlotStyle { plotArea in
                        plotArea
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .chartLegend(.hidden)
                    .chartForegroundStyleScale([
                        StatisticsViewModel.TrendDatum.Series.expense.rawValue: StatisticsPalette.expense,
                        StatisticsViewModel.TrendDatum.Series.income.rawValue: StatisticsPalette.income
                    ])
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisGridLine()
                                .foregroundStyle(StatisticsPalette.divider.opacity(0.3))
                            AxisValueLabel {
                                if let label = value.as(String.self) {
                                    Text(label)
                                        .font(.caption)
                                        .foregroundStyle(StatisticsPalette.mutedText)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                                .foregroundStyle(StatisticsPalette.divider.opacity(0.35))
                            AxisValueLabel {
                                if let amount = value.as(Double.self) {
                                    Text(formattedCurrency(amount))
                                        .font(.caption)
                                        .foregroundStyle(StatisticsPalette.mutedText)
                                }
                            }
                        }
                    }

                    HStack(spacing: 16) {
                        legendItem(color: StatisticsPalette.expense, title: "支出")
                        legendItem(color: StatisticsPalette.income, title: "收入")
                    }
                    .padding(.top, 6)
                }
            }
        }
    }

    private var categoryBreakdownSection: some View {
        statisticsCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("分类占比")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    HStack(spacing: 10) {
                        capsuleButton(
                            title: "支出",
                            isActive: viewModel.categoryKind == .expense,
                            compact: true,
                            action: { withAnimation(.easeInOut) { viewModel.select(kind: .expense) } }
                        )
                        capsuleButton(
                            title: "收入",
                            isActive: viewModel.categoryKind == .income,
                            compact: true,
                            action: { withAnimation(.easeInOut) { viewModel.select(kind: .income) } }
                        )
                    }
                }

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else if viewModel.categorySummaries.isEmpty {
                    Text("暂无分类数据")
                        .font(.footnote)
                        .foregroundStyle(StatisticsPalette.mutedText)
                        .frame(height: 200, alignment: .center)
                        .frame(maxWidth: .infinity)
                } else {
                    let palette = categoryPalette(for: viewModel.categoryKind)
                    let enumeratedSummaries = Array(viewModel.categorySummaries.enumerated())

                    HStack(alignment: .center, spacing: 20) {
                        Chart(enumeratedSummaries, id: \.element.id) { entry in
                            let summary = entry.element
                            SectorMark(
                                angle: .value("金额", summary.total.asDouble),
                                innerRadius: .ratio(0.48),
                                outerRadius: .ratio(0.98)
                            )
                            .foregroundStyle(palette[entry.offset % palette.count])
                            .cornerRadius(6)
                        }
                        .chartLegend(.hidden)
                        .frame(width: 180, height: 200)

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(enumeratedSummaries, id: \.element.id) { entry in
                                let summary = entry.element
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(palette[entry.offset % palette.count])
                                        .frame(width: 12, height: 12)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(summary.category.name)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text("\(summary.total.formattedCurrency()) · \(percentage(for: summary))")
                                            .font(.caption2)
                                            .foregroundStyle(StatisticsPalette.mutedText)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var goalComparisonSection: some View {
        statisticsCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("目标对比")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("实际支出与财务目标的对比")
                    .font(.caption)
                    .foregroundStyle(StatisticsPalette.mutedText)

                if viewModel.goalComparisons.isEmpty {
                    Text("暂无目标数据")
                        .font(.footnote)
                        .foregroundStyle(StatisticsPalette.mutedText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                } else {
                    VStack(spacing: 20) {
                        ForEach(viewModel.goalComparisons) { item in
                            goalRow(item)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func goalRow(_ item: GoalComparisonSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Text(emoji(for: item.category))
                        .font(.title3)
                    Text(item.category)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }
                Spacer()
                Text("目标 ¥\(item.goal.formattedNumber())")
                    .font(.caption)
                    .foregroundStyle(StatisticsPalette.mutedText)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(StatisticsPalette.outline.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(StatisticsPalette.progressBackground.opacity(0.6))
                        )

                    let width = max(0, geo.size.width * item.progress)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(progressGradient(for: item))
                        .frame(width: width)
                        .overlay(
                            Text("\(Int(round(item.progress * 100)))% 已用")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(width > 40 ? 1 : 0))
                                .padding(.horizontal, 12),
                            alignment: .leading
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .frame(height: 44)

            HStack {
                Text("实际: ¥\(item.actual.formattedNumber())")
                    .font(.caption)
                    .foregroundStyle(StatisticsPalette.mutedText)
                Spacer()
                Text(item.isOverBudget ? "超支 ¥\((item.actual - item.goal).formattedNumber())" : "剩余 ¥\((item.goal - item.actual).formattedNumber())")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.isOverBudget ? StatisticsPalette.expense : StatisticsPalette.income)
            }
        }
        .padding(.horizontal, 4)
    }

    private func statisticsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16, content: content)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StatisticsPalette.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: StatisticsPalette.cardShadow, radius: 18, y: 10)
    }

    private func capsuleButton(title: String, isActive: Bool, compact: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(compact ? .caption.weight(.semibold) : .footnote.weight(.semibold))
                .foregroundStyle(isActive ? Color.white : StatisticsPalette.primary)
                .padding(.vertical, compact ? 6 : 10)
                .padding(.horizontal, compact ? 14 : 18)
                .background(isActive ? StatisticsPalette.primary : StatisticsPalette.primarySoft)
                .clipShape(Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(StatisticsPalette.outline, lineWidth: isActive ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func formattedCurrency(_ value: Double) -> String {
        chartCurrencyFormatter.string(from: NSNumber(value: value)) ?? "¥\(Int(round(value)))"
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
                .font(.caption)
                .foregroundStyle(StatisticsPalette.mutedText)
        }
    }

    private func categoryPalette(for kind: CategoryKind) -> [Color] {
        switch kind {
        case .expense:
            return StatisticsPalette.expenseCategoryPalette
        case .income:
            return StatisticsPalette.incomeCategoryPalette
        }
    }

    private func percentage(for summary: CategorySummary) -> String {
        let total = viewModel.categorySummaries.reduce(Decimal.zero) { $0 + $1.total }
        guard total > .zero else { return "0%" }
        let percent = (summary.total / total) * 100
        return percent.formatted(.number.precision(.fractionLength(0))) + "%"
    }

    private func progressGradient(for item: GoalComparisonSnapshot) -> LinearGradient {
        if item.isOverBudget {
            return LinearGradient(colors: [StatisticsPalette.warningStart, StatisticsPalette.warningEnd], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [StatisticsPalette.primary.opacity(0.85), StatisticsPalette.primary], startPoint: .leading, endPoint: .trailing)
        }
    }

    private func emoji(for category: String) -> String {
        switch category {
        case "餐饮": return "☕"
        case "交通": return "🚗"
        case "购物": return "🛒"
        case "娱乐": return "🎮"
        default: return "📦"
        }
    }
}

