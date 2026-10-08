import Foundation
import SwiftData

// MARK: - Shared Models

enum StatisticsAnalyticsPeriod: Equatable {
    case currentMonth
    case recentMonths(count: Int)
    case yearToDate
}

enum StatisticsTrendScope: String, CaseIterable, Identifiable {
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly:
            return "月度"
        case .yearly:
            return "年度"
        }
    }

    var analyticsPeriod: StatisticsAnalyticsPeriod {
        switch self {
        case .monthly:
            return .currentMonth
        case .yearly:
            return .yearToDate
        }
    }
}

struct StatisticsTrendInfo {
    let text: String
    let direction: FinanceTrendDirection
}

struct StatisticsSummaryData {
    let totalIncome: Decimal
    let totalExpense: Decimal
    let netIncome: Decimal
    let expenseTrend: StatisticsTrendInfo?
    let incomeTrend: StatisticsTrendInfo?
    let netTrend: StatisticsTrendInfo?
}

enum StatisticsHighlightTone {
    case neutral
    case positive
    case caution
}

struct StatisticsHighlightMetric: Identifiable {
    let id = UUID()
    let title: String
    let valueText: String
    let captionText: String
    let tone: StatisticsHighlightTone
}

struct StatisticsCategoryBreakdown: Identifiable {
    let id = UUID()
    let name: String
    let amount: Decimal
    let amountText: String
    let ratio: Decimal
    let ratioText: String
    let progress: Double
}

enum StatisticsInsightTone {
    case neutral
    case positive
    case warning
}

struct StatisticsInsightData: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let tone: StatisticsInsightTone
}

// MARK: - Aggregator Protocol

@MainActor
protocol StatisticsAnalyticsAggregator {
    func makeSummary(for period: StatisticsAnalyticsPeriod, referenceDate: Date) throws -> StatisticsSummaryData
    func makeTrend(for period: StatisticsAnalyticsPeriod, referenceDate: Date) throws -> [StatisticSnapshot]
    func makeCategoryBreakdown(
        for period: StatisticsAnalyticsPeriod,
        kind: CategoryKind,
        referenceDate: Date
    ) throws -> [StatisticsCategoryBreakdown]
    func makeSpendingTypeTotals(
        for period: StatisticsAnalyticsPeriod,
        referenceDate: Date
    ) throws -> [SpendingType: Decimal]
    func makeHighlights(for period: StatisticsAnalyticsPeriod, referenceDate: Date) throws -> [StatisticsHighlightMetric]
    func makeInsights(
        summary: StatisticsSummaryData,
        categories: [StatisticsCategoryBreakdown],
        profile: UserProfileSnapshot?
    ) -> [StatisticsInsightData]
}

// MARK: - Default Implementation

@MainActor
final class DefaultStatisticsAnalyticsAggregator: StatisticsAnalyticsAggregator {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.context = context
        self.calendar = calendar
    }

    func makeSummary(for period: StatisticsAnalyticsPeriod, referenceDate: Date) throws -> StatisticsSummaryData {
        let currentRange = period.dateInterval(referenceDate: referenceDate, using: calendar)
        let current = try fetchTransactions(in: currentRange)

        let currentTotals = totals(for: current)

        var expenseTrend: StatisticsTrendInfo?
        var incomeTrend: StatisticsTrendInfo?
        var netTrend: StatisticsTrendInfo?

        if let previousRange = period.previousInterval(referenceDate: referenceDate, using: calendar) {
            let previous = try fetchTransactions(in: previousRange)
            let previousTotals = totals(for: previous)

            expenseTrend = trendText(current: currentTotals.expense, previous: previousTotals.expense)
            incomeTrend = trendText(current: currentTotals.income, previous: previousTotals.income)
            netTrend = trendText(current: currentTotals.net, previous: previousTotals.net)
        }

        return StatisticsSummaryData(
            totalIncome: currentTotals.income,
            totalExpense: currentTotals.expense,
            netIncome: currentTotals.net,
            expenseTrend: expenseTrend,
            incomeTrend: incomeTrend,
            netTrend: netTrend
        )
    }

    func makeTrend(for period: StatisticsAnalyticsPeriod, referenceDate: Date) throws -> [StatisticSnapshot] {
        let range = period.dateInterval(referenceDate: referenceDate, using: calendar)
        let transactions = try fetchTransactions(in: range)

        let buckets = groupForTrend(transactions, period: period)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")

        switch period {
        case .currentMonth:
            formatter.dateFormat = "MM-dd"
        case .recentMonths:
            formatter.dateFormat = "yyyy-MM"
        case .yearToDate:
            formatter.dateFormat = "M月"
        }

        return buckets
            .sorted(by: { $0.key < $1.key })
            .map { date, totals in
                StatisticSnapshot(
                    label: formatter.string(from: date),
                    income: totals.income,
                    expense: totals.expense
                )
            }
    }

    func makeCategoryBreakdown(
        for period: StatisticsAnalyticsPeriod,
        kind: CategoryKind,
        referenceDate: Date
    ) throws -> [StatisticsCategoryBreakdown] {
        let range = period.dateInterval(referenceDate: referenceDate, using: calendar)
        let transactions = try fetchTransactions(in: range)

        let filtered = transactions.filter { transaction in
            switch (transaction.type, kind) {
            case (.expense, .expense), (.income, .income):
                return true
            default:
                return false
            }
        }

        let total = filtered.reduce(Decimal.zero) { partial, transaction in
            partial + transaction.amount
        }

        guard total > .zero else { return [] }

        var aggregation: [UUID?: Decimal] = [:]
        var categoriesByID: [UUID: TransactionCategory] = [:]

        for transaction in filtered {
            let categoryID = transaction.category?.id
            aggregation[categoryID, default: .zero] += transaction.amount
            if let category = transaction.category {
                categoriesByID[category.id] = category
            }
        }

        let breakdowns = aggregation
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map { entry -> StatisticsCategoryBreakdown in
                let category = entry.key.flatMap { categoriesByID[$0] }
                let name = category?.name ?? (kind == .expense ? "未分类支出" : "未分类收入")
                let amount = entry.value
                let ratio = amount / total
                return StatisticsCategoryBreakdown(
                    name: name,
                    amount: amount,
                    amountText: amount.formattedCurrency(),
                    ratio: ratio,
                    ratioText: ratio.formattedPercentage(),
                    progress: min(max(ratio.asDouble, 0), 1)
                )
            }

        return Array(breakdowns)
    }

    func makeHighlights(for period: StatisticsAnalyticsPeriod, referenceDate: Date) throws -> [StatisticsHighlightMetric] {
        let range = period.dateInterval(referenceDate: referenceDate, using: calendar)
        let transactions = try fetchTransactions(in: range)
        guard !transactions.isEmpty else { return [] }

        let totals = totals(for: transactions)
        let expenseCategories = try makeCategoryBreakdown(for: period, kind: .expense, referenceDate: referenceDate)
        let topCategory = expenseCategories.first

        let dailyExpense = groupByDay(transactions.filter { $0.type == .expense })
        let topDay = dailyExpense.max { $0.value < $1.value }

        var highlights: [StatisticsHighlightMetric] = []

        if let topCategory {
            let tone: StatisticsHighlightTone = topCategory.ratio >= Decimal(0.35) ? .caution : .neutral
            highlights.append(
                StatisticsHighlightMetric(
                    title: "最高支出分类",
                    valueText: topCategory.name,
                    captionText: "占比 \(topCategory.ratioText)",
                    tone: tone
                )
            )
        }

        let dayCount = max(dailyExpense.count, 1)
        let averageDailyExpense = totals.expense / Decimal(dayCount)
        highlights.append(
            StatisticsHighlightMetric(
                title: "平均每日支出",
                valueText: averageDailyExpense.formattedCurrency(),
                captionText: "基于 \(dayCount) 天消费记录",
                tone: .neutral
            )
        )

        if let topDay {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "MM月dd日"
            let caption = formatter.string(from: topDay.key)
            let tone: StatisticsHighlightTone = topDay.value > averageDailyExpense * Decimal(1.5) ? .caution : .neutral
            highlights.append(
                StatisticsHighlightMetric(
                    title: "单日最高支出",
                    valueText: topDay.value.formattedCurrency(),
                    captionText: caption,
                    tone: tone
                )
            )
        }

        return highlights
    }

    func makeInsights(
        summary: StatisticsSummaryData,
        categories: [StatisticsCategoryBreakdown],
        profile: UserProfileSnapshot?
    ) -> [StatisticsInsightData] {
        var insights: [StatisticsInsightData] = []

        if summary.netIncome < .zero {
            insights.append(
                StatisticsInsightData(
                    icon: "exclamationmark.triangle.fill",
                    title: "支出超过收入",
                    detail: "建议复查大额开销，并适当下调非刚需预算，确保现金流为正。",
                    tone: .warning
                )
            )
        } else if summary.netIncome > summary.totalIncome * Decimal(0.3) {
            insights.append(
                StatisticsInsightData(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "结余表现良好",
                    detail: "本期结余超过 30%，可考虑转入定投或高收益账户，提升资金利用率。",
                    tone: .positive
                )
            )
        }

        if let topCategory = categories.first, topCategory.ratio > Decimal(0.4) {
            insights.append(
                StatisticsInsightData(
                    icon: "creditcard.fill",
                    title: "单一支出占比较高",
                    detail: "\(topCategory.name) 占比达 \(topCategory.ratioText)，建议拆分预算或设置消费提醒。",
                    tone: .warning
                )
            )
        }

        if let profile, profile.goals.contains(.emergencyFund) {
            insights.append(
                StatisticsInsightData(
                    icon: "shield.lefthalf.fill",
                    title: "应急金进度提醒",
                    detail: "结合画像目标，建议将部分结余自动转入应急金账户，直到覆盖 3-6 个月开销。",
                    tone: .neutral
                )
            )
        }

        if insights.isEmpty {
            insights.append(
                StatisticsInsightData(
                    icon: "lightbulb.fill",
                    title: "保持良好习惯",
                    detail: "支出结构稳定，可继续跟踪重点类别，按月复盘消费策略。",
                    tone: .positive
                )
            )
        }

        return insights
    }

    // MARK: - Helpers

    private func fetchTransactions(in interval: DateInterval) throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.occurredAt, order: .forward)]
        )
        let all = try context.fetch(descriptor)
        let allowedStatuses: Set<TransactionStatus> = [.pending, .ok]
        return all.filter { transaction in
            allowedStatuses.contains(transaction.status) &&
            transaction.occurredAt >= interval.start &&
            transaction.occurredAt < interval.end
        }
    }

    func makeSpendingTypeTotals(
        for period: StatisticsAnalyticsPeriod,
        referenceDate: Date
    ) throws -> [SpendingType: Decimal] {
        let range = period.dateInterval(referenceDate: referenceDate, using: calendar)
        let transactions = try fetchTransactions(in: range)
        var totals: [SpendingType: Decimal] = [:]

        for transaction in transactions where transaction.type == .expense {
            let type = transaction.spendingType ?? .basic
            totals[type, default: .zero] += transaction.amount
        }

        return totals
    }

    private func totals(for transactions: [Transaction]) -> (income: Decimal, expense: Decimal, net: Decimal) {
        let income = transactions
            .filter { $0.type == .income }
            .reduce(Decimal.zero) { $0 + $1.amount }

        let expense = transactions
            .filter { $0.type == .expense }
            .reduce(Decimal.zero) { $0 + $1.amount }

        return (income, expense, income - expense)
    }

    private func trendText(current: Decimal, previous: Decimal) -> StatisticsTrendInfo? {
        guard previous != .zero else { return nil }
        let diff = current - previous
        let ratio = diff / previous
        let direction: FinanceTrendDirection
        if ratio > .zero {
            direction = .up
        } else if ratio < .zero {
            direction = .down
        } else {
            direction = .flat
        }
        let prefix = ratio > .zero ? "+" : ""
        return StatisticsTrendInfo(
            text: "\(prefix)\(ratio.formattedPercentage())",
            direction: direction
        )
    }

    private func groupForTrend(
        _ transactions: [Transaction],
        period: StatisticsAnalyticsPeriod
    ) -> [Date: (income: Decimal, expense: Decimal)] {
        var buckets: [Date: (income: Decimal, expense: Decimal)] = [:]

        for transaction in transactions {
            let bucketDate: Date
            switch period {
            case .currentMonth:
                bucketDate = calendar.startOfDay(for: transaction.occurredAt)
            case .recentMonths, .yearToDate:
                bucketDate = startOfMonth(for: transaction.occurredAt)
            }

            var totals = buckets[bucketDate] ?? (.zero, .zero)
            if transaction.type == .income {
                totals.income += transaction.amount
            } else {
                totals.expense += transaction.amount
            }
            buckets[bucketDate] = totals
        }

        return buckets
    }

    private func groupByDay(_ transactions: [Transaction]) -> [Date: Decimal] {
        var result: [Date: Decimal] = [:]
        for transaction in transactions {
            let day = calendar.startOfDay(for: transaction.occurredAt)
            result[day, default: .zero] += transaction.amount
        }
        return result
    }

    private func startOfMonth(for date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}

// MARK: - Period Utilities

private struct StatisticsDateInterval {
    let start: Date
    let end: Date
}

private extension StatisticsAnalyticsPeriod {
    func dateInterval(referenceDate: Date, using calendar: Calendar) -> DateInterval {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        switch self {
        case .currentMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: startOfToday)) ?? startOfToday
            guard let end = calendar.date(byAdding: .month, value: 1, to: start) else {
                return DateInterval(start: start, end: start)
            }
            return DateInterval(start: start, end: end)
        case .recentMonths(let count):
            let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: startOfToday)) ?? startOfToday
            let months = max(count - 1, 0)
            let start = calendar.date(byAdding: .month, value: -months, to: currentMonthStart) ?? currentMonthStart
            guard let end = calendar.date(byAdding: .month, value: 1, to: currentMonthStart) else {
                return DateInterval(start: start, end: currentMonthStart)
            }
            return DateInterval(start: start, end: end)
        case .yearToDate:
            let components = calendar.dateComponents([.year], from: startOfToday)
            let start = calendar.date(from: components) ?? startOfToday
            return DateInterval(start: start, end: startOfToday.addingTimeInterval(60 * 60 * 24))
        }
    }

    func previousInterval(referenceDate: Date, using calendar: Calendar) -> DateInterval? {
        switch self {
        case .currentMonth:
            let currentMonthRange = dateInterval(referenceDate: referenceDate, using: calendar)
            guard let previousStart = calendar.date(byAdding: .month, value: -1, to: currentMonthRange.start),
                  let previousEnd = calendar.date(byAdding: .month, value: 0, to: currentMonthRange.start) else {
                return nil
            }
            return DateInterval(start: previousStart, end: previousEnd)
        case .recentMonths(let count):
            let months = max(count, 1)
            let currentRange = dateInterval(referenceDate: referenceDate, using: calendar)
            guard let previousStart = calendar.date(byAdding: .month, value: -months, to: currentRange.start),
                  let previousEnd = calendar.date(byAdding: .month, value: -months, to: currentRange.end) else {
                return nil
            }
            return DateInterval(start: previousStart, end: previousEnd)
        case .yearToDate:
            guard let previousYearDate = calendar.date(byAdding: .year, value: -1, to: referenceDate) else {
                return nil
            }
            let previousYearRange = StatisticsAnalyticsPeriod.yearToDate.dateInterval(referenceDate: previousYearDate, using: calendar)
            return previousYearRange
        }
    }
}
