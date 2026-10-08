import Foundation
import Combine
import SwiftData
import SwiftUI

enum FinancialFormMode: Equatable {
    case create
    case edit
}

enum FinancialHealthModal: Equatable {
    case budget
    case asset(FinancialFormMode)
    case liability(FinancialFormMode)
    case goal(FinancialFormMode)
}

struct FinancialPortfolioItem: Identifiable {
    let id: UUID
    let name: String
    let amount: Decimal
    let rate: Double
    let term: String?
    let detail: String?

    var formattedAmount: String {
        amount.formattedCurrency()
    }

    var formattedRate: String {
        String(format: "%.1f%%", rate)
    }

    var hasSupportingDetail: Bool {
        !(term?.isEmpty ?? true) || !(detail?.isEmpty ?? true)
    }
}

struct FinancialSummary {
    let title: String
    let amount: Decimal
    let detail: String?

    var amountText: String {
        amount.formattedCurrency()
    }
}

struct FinancialGoalItem: Identifiable {
    let id: UUID
    let name: String
    let category: String
    let current: Decimal
    let target: Decimal
    let deadline: Date?

    var progress: Double {
        guard target > .zero else { return 0 }
        let ratio = min(max((current / target).asDouble, 0), 1)
        return ratio
    }

    var progressText: String {
        String(format: "%.1f%%", progress * 100)
    }

    var progressAmount: String {
        current.formattedCurrency()
    }

    var targetText: String {
        target.formattedCurrency()
    }

    var remainingAmount: String {
        max(target - current, 0).formattedCurrency()
    }

    var remainingDaysText: String {
        guard let deadline else { return "未设置" }
        let days = Calendar.current.dateComponents([.day], from: .now, to: deadline).day ?? 0
        if days < 0 {
            return "已到期"
        }
        return "\(days) 天"
    }

    var isOverdue: Bool {
        guard let deadline else { return false }
        return deadline < .now
    }
}

struct FinancialGoalSummary {
    let activeGoals: Int
    let goalCompletion: String
}

struct FinancialHealthDisplayModel {
    let budget: Decimal
    let assets: [FinancialPortfolioItem]
    let debts: [FinancialPortfolioItem]
    let assetSummary: FinancialSummary
    let debtSummary: FinancialSummary
    let goals: [FinancialGoalItem]
    let summary: FinancialGoalSummary

    var formattedBudget: String {
        budget.formattedCurrency()
    }
}

struct FinancialAssetRecord: Identifiable {
    var id: UUID
    var name: String
    var amount: Decimal
    var rate: Double
    var term: String?
    var detail: String?
    var createdAt: Date
    var updatedAt: Date
}

struct FinancialLiabilityRecord: Identifiable {
    var id: UUID
    var name: String
    var amount: Decimal
    var rate: Double
    var createdAt: Date
    var updatedAt: Date
}

struct FinancialGoalRecord: Identifiable {
    var id: UUID
    var name: String
    var category: String
    var current: Decimal
    var target: Decimal
    var deadline: Date?
    var createdAt: Date
    var updatedAt: Date
}

struct FinancialBudgetDraft {
    var amountText: String = ""

    var isValid: Bool {
        guard let amount = parseDecimal(amountText) else { return false }
        return amount > .zero
    }

    var validationErrorMessage: String? {
        guard let amount = parseDecimal(amountText) else {
            return "请输入有效的金额"
        }
        guard amount > .zero else {
            return "金额需要大于 0"
        }
        return nil
    }
}

struct FinancialAssetDraft {
    var editingID: UUID?
    var category: String = ""
    var amountText: String = ""
    var rateText: String = ""
    var term: String = ""
    var detail: String = ""

    var isValid: Bool {
        guard !category.isEmpty, let amount = parseDecimal(amountText), amount > .zero else { return false }
        return parseRate(rateText) != nil
    }

    var validationErrorMessage: String? {
        guard !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "请输入资产类别"
        }
        guard let amount = parseDecimal(amountText) else {
            return "请输入正确的资产金额"
        }
        guard amount > .zero else {
            return "资产金额需要大于 0"
        }
        guard parseRate(rateText) != nil else {
            return "请输入正确的年化利率"
        }
        return nil
    }

    mutating func configure(with record: FinancialAssetRecord) {
        editingID = record.id
        category = record.name
        amountText = record.amount.cleanNumericString()
        rateText = String(record.rate)
        term = record.term ?? ""
        detail = record.detail ?? ""
    }
}

struct FinancialLiabilityDraft {
    var editingID: UUID?
    var category: String = ""
    var amountText: String = ""
    var rateText: String = ""

    var isValid: Bool {
        guard !category.isEmpty, let amount = parseDecimal(amountText), amount > .zero else { return false }
        return parseRate(rateText) != nil
    }

    var validationErrorMessage: String? {
        guard !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "请输入负债类别"
        }
        guard let amount = parseDecimal(amountText) else {
            return "请输入正确的负债金额"
        }
        guard amount > .zero else {
            return "负债金额需要大于 0"
        }
        guard parseRate(rateText) != nil else {
            return "请输入正确的年化利率"
        }
        return nil
    }

    mutating func configure(with record: FinancialLiabilityRecord) {
        editingID = record.id
        category = record.name
        amountText = record.amount.cleanNumericString()
        rateText = String(record.rate)
    }
}

struct FinancialGoalDraft {
    var editingID: UUID?
    var name: String = ""
    var category: String = ""
    var targetText: String = ""
    var deadline: Date = .now

    var isValid: Bool {
        guard !name.isEmpty, !category.isEmpty, let target = parseDecimal(targetText) else { return false }
        return target > .zero
    }

    var validationErrorMessage: String? {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "请输入目标名称"
        }
        guard !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "请输入目标类别"
        }
        guard let target = parseDecimal(targetText) else {
            return "请输入正确的目标金额"
        }
        guard target > .zero else {
            return "目标金额需要大于 0"
        }
        return nil
    }

    mutating func configure(with record: FinancialGoalRecord) {
        editingID = record.id
        name = record.name
        category = record.category
        targetText = record.target.cleanNumericString()
        deadline = record.deadline ?? .now
    }
}

@MainActor
final class FinancialHealthViewModel: ObservableObject {
    @Published private(set) var display: FinancialHealthDisplayModel
    @Published var activeModal: FinancialHealthModal?
    @Published var budgetDraft = FinancialBudgetDraft()
    @Published var assetDraft = FinancialAssetDraft()
    @Published var liabilityDraft = FinancialLiabilityDraft()
    @Published var goalDraft = FinancialGoalDraft()
    @Published var formErrorMessage: String?

    private var budget: Decimal
    private var assets: [FinancialAssetRecord]
    private var liabilities: [FinancialLiabilityRecord]
    private var goals: [FinancialGoalRecord]
    private var budgetPlanID: UUID?

    private let context: ModelContext
    private let eventBus: FinanceEventBus
    private let userProfileService: UserProfileService
    private let userID: String
    private let calendar: Calendar

    init(
        context: ModelContext,
        eventBus: FinanceEventBus,
        userProfileService: UserProfileService,
        userID: String,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) {
        self.context = context
        self.eventBus = eventBus
        self.userProfileService = userProfileService
        self.userID = userID
        self.calendar = calendar
        self.budget = .zero
        self.assets = []
        self.liabilities = []
        self.goals = []
        self.budgetPlanID = nil
        self.display = FinancialHealthViewModel.makeDisplay(
            budget: .zero,
            assets: [],
            liabilities: [],
            goals: [],
            calendar: calendar
        )

        loadInitialSnapshot()
    }

    func dismissModal() {
        activeModal = nil
        formErrorMessage = nil
    }

    func presentBudgetEditor() {
        budgetDraft.amountText = budget.cleanNumericString()
        formErrorMessage = nil
        activeModal = .budget
    }

    func presentAddAsset() {
        assetDraft = FinancialAssetDraft()
        formErrorMessage = nil
        activeModal = .asset(.create)
    }

    func presentEditAsset(_ item: FinancialPortfolioItem) {
        guard let record = assets.first(where: { $0.id == item.id }) else { return }
        var draft = FinancialAssetDraft()
        draft.configure(with: record)
        assetDraft = draft
        formErrorMessage = nil
        activeModal = .asset(.edit)
    }

    func deleteAsset(_ item: FinancialPortfolioItem) {
        do {
            try removeAsset(id: item.id)
            refreshFinancialData()
        } catch {
            print("⚠️ 删除资产失败：\(error.localizedDescription)")
        }
    }

    func presentAddLiability() {
        liabilityDraft = FinancialLiabilityDraft()
        formErrorMessage = nil
        activeModal = .liability(.create)
    }

    func presentEditLiability(_ item: FinancialPortfolioItem) {
        guard let record = liabilities.first(where: { $0.id == item.id }) else { return }
        var draft = FinancialLiabilityDraft()
        draft.configure(with: record)
        liabilityDraft = draft
        formErrorMessage = nil
        activeModal = .liability(.edit)
    }

    func deleteLiability(_ item: FinancialPortfolioItem) {
        do {
            try removeLiability(id: item.id)
            refreshFinancialData()
        } catch {
            print("⚠️ 删除负债失败：\(error.localizedDescription)")
        }
    }

    func presentAddGoal() {
        goalDraft = FinancialGoalDraft()
        formErrorMessage = nil
        activeModal = .goal(.create)
    }

    func presentEditGoal(_ item: FinancialGoalItem) {
        guard let record = goals.first(where: { $0.id == item.id }) else { return }
        var draft = FinancialGoalDraft()
        draft.configure(with: record)
        goalDraft = draft
        formErrorMessage = nil
        activeModal = .goal(.edit)
    }

    func deleteGoal(_ item: FinancialGoalItem) {
        do {
            try removeGoal(id: item.id)
            refreshFinancialData()
            eventBus.send(.goalsChanged(source: .goals))
        } catch {
            print("⚠️ 删除目标失败：\(error.localizedDescription)")
        }
    }

    func saveBudget() {
        guard budgetDraft.isValid, let amount = parseDecimal(budgetDraft.amountText) else {
            formErrorMessage = budgetDraft.validationErrorMessage ?? "请输入有效的金额"
            return
        }
        guard amount > .zero else {
            formErrorMessage = "金额需要大于 0"
            return
        }
        do {
            try persistBudgetChange(amount: amount)
            budget = amount
            budgetDraft = FinancialBudgetDraft()
            updateDisplay()
            activeModal = nil
            eventBus.send(.budgetSummaryUpdated(nil))
            formErrorMessage = nil
        } catch {
            print("⚠️ 保存预算失败：\(error.localizedDescription)")
        }
    }

    func saveAsset() {
        guard assetDraft.isValid else {
            formErrorMessage = assetDraft.validationErrorMessage ?? "请检查资产表单信息"
            return
        }

        guard let amount = parseDecimal(assetDraft.amountText),
              let rate = parseRate(assetDraft.rateText)
        else {
            formErrorMessage = assetDraft.validationErrorMessage ?? "请输入正确的资产信息"
            return
        }

        let now = Date()
        let existingRecord = assetDraft.editingID.flatMap { id in
            assets.first(where: { $0.id == id })
        }

        let record = FinancialAssetRecord(
            id: assetDraft.editingID ?? UUID(),
            name: assetDraft.category,
            amount: amount,
            rate: rate,
            term: assetDraft.term.isEmpty ? nil : assetDraft.term,
            detail: assetDraft.detail.isEmpty ? nil : assetDraft.detail,
            createdAt: existingRecord?.createdAt ?? now,
            updatedAt: now
        )

        do {
            try upsertAsset(record: record)
            assetDraft = FinancialAssetDraft()
            activeModal = nil
            refreshFinancialData()
            formErrorMessage = nil
        } catch {
            print("⚠️ 保存资产失败：\(error.localizedDescription)")
        }
    }

    func saveLiability() {
        guard liabilityDraft.isValid else {
            formErrorMessage = liabilityDraft.validationErrorMessage ?? "请检查负债表单信息"
            return
        }

        guard let amount = parseDecimal(liabilityDraft.amountText),
              let rate = parseRate(liabilityDraft.rateText)
        else {
            formErrorMessage = liabilityDraft.validationErrorMessage ?? "请输入正确的负债信息"
            return
        }

        let now = Date()
        let existingRecord = liabilityDraft.editingID.flatMap { id in
            liabilities.first(where: { $0.id == id })
        }

        let record = FinancialLiabilityRecord(
            id: liabilityDraft.editingID ?? UUID(),
            name: liabilityDraft.category,
            amount: amount,
            rate: rate,
            createdAt: existingRecord?.createdAt ?? now,
            updatedAt: now
        )

        do {
            try upsertLiability(record: record)
            liabilityDraft = FinancialLiabilityDraft()
            activeModal = nil
            refreshFinancialData()
            formErrorMessage = nil
        } catch {
            print("⚠️ 保存负债失败：\(error.localizedDescription)")
        }
    }

    func saveGoal() {
        guard goalDraft.isValid else {
            formErrorMessage = goalDraft.validationErrorMessage ?? "请检查目标表单信息"
            return
        }

        guard let target = parseDecimal(goalDraft.targetText)
        else {
            formErrorMessage = goalDraft.validationErrorMessage ?? "请输入正确的目标信息"
            return
        }

        let now = Date()
        let existingRecord = goalDraft.editingID.flatMap { id in
            goals.first(where: { $0.id == id })
        }

        let record = FinancialGoalRecord(
            id: goalDraft.editingID ?? UUID(),
            name: goalDraft.name,
            category: goalDraft.category,
            current: existingRecord?.current ?? .zero,
            target: target,
            deadline: goalDraft.deadline,
            createdAt: existingRecord?.createdAt ?? now,
            updatedAt: now
        )

        do {
            try upsertGoal(record: record)
            goalDraft = FinancialGoalDraft()
            activeModal = nil
            refreshFinancialData()
            formErrorMessage = nil
            eventBus.send(.goalsChanged(source: .goals))
        } catch {
            print("⚠️ 保存目标失败：\(error.localizedDescription)")
        }
    }

    private func loadInitialSnapshot() {
        do {
            var descriptor = FetchDescriptor<BudgetPlan>(
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )
            descriptor.fetchLimit = 1
            if let plan = try context.fetch(descriptor).first {
                budgetPlanID = plan.id
                budget = plan.totalLimit
            }
        } catch {
            print("⚠️ 预算加载失败：\(error.localizedDescription)")
        }

        refreshFinancialData()
    }

    private func refreshFinancialData() {
        do {
            assets = try fetchAssetRecords()
            liabilities = try fetchLiabilityRecords()
            goals = try fetchGoalRecords()
        } catch {
            assets = []
            liabilities = []
            goals = []
            print("⚠️ 财务数据加载失败：\(error.localizedDescription)")
        }
        updateDisplay()
    }

    private func updateDisplay() {
        display = FinancialHealthViewModel.makeDisplay(
            budget: budget,
            assets: assets,
            liabilities: liabilities,
            goals: goals,
            calendar: calendar
        )
    }

    private func fetchAssetRecords() throws -> [FinancialAssetRecord] {
        let descriptor = FetchDescriptor<FinancialAssetEntity>(
            predicate: #Predicate { $0.userID == userID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { entity in
            FinancialAssetRecord(
                id: entity.id,
                name: entity.name,
                amount: entity.amount,
                rate: entity.rate,
                term: entity.term,
                detail: entity.detail,
                createdAt: entity.createdAt,
                updatedAt: entity.updatedAt
            )
        }
    }

    private func fetchLiabilityRecords() throws -> [FinancialLiabilityRecord] {
        let descriptor = FetchDescriptor<FinancialLiabilityEntity>(
            predicate: #Predicate { $0.userID == userID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { entity in
            FinancialLiabilityRecord(
                id: entity.id,
                name: entity.name,
                amount: entity.amount,
                rate: entity.rate,
                createdAt: entity.createdAt,
                updatedAt: entity.updatedAt
            )
        }
    }

    private func fetchGoalRecords() throws -> [FinancialGoalRecord] {
        let descriptor = FetchDescriptor<FinancialGoalEntity>(
            predicate: #Predicate { $0.userID == userID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { entity in
            FinancialGoalRecord(
                id: entity.id,
                name: entity.name,
                category: entity.category,
                current: entity.current,
                target: entity.target,
                deadline: entity.deadline,
                createdAt: entity.createdAt,
                updatedAt: entity.updatedAt
            )
        }
    }

    private func fetchAssetEntity(id: UUID) throws -> FinancialAssetEntity? {
        var descriptor = FetchDescriptor<FinancialAssetEntity>(
            predicate: #Predicate { $0.id == id && $0.userID == userID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchLiabilityEntity(id: UUID) throws -> FinancialLiabilityEntity? {
        var descriptor = FetchDescriptor<FinancialLiabilityEntity>(
            predicate: #Predicate { $0.id == id && $0.userID == userID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchGoalEntity(id: UUID) throws -> FinancialGoalEntity? {
        var descriptor = FetchDescriptor<FinancialGoalEntity>(
            predicate: #Predicate { $0.id == id && $0.userID == userID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func upsertAsset(record: FinancialAssetRecord) throws {
        if let entity = try fetchAssetEntity(id: record.id) {
            entity.name = record.name
            entity.amount = record.amount
            entity.rate = record.rate
            entity.term = record.term
            entity.detail = record.detail
            entity.updatedAt = record.updatedAt
        } else {
            let entity = FinancialAssetEntity(
                id: record.id,
                userID: userID,
                name: record.name,
                amount: record.amount,
                rate: record.rate,
                term: record.term,
                detail: record.detail,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
            context.insert(entity)
        }
        try context.save()
    }

    private func upsertLiability(record: FinancialLiabilityRecord) throws {
        if let entity = try fetchLiabilityEntity(id: record.id) {
            entity.name = record.name
            entity.amount = record.amount
            entity.rate = record.rate
            entity.updatedAt = record.updatedAt
        } else {
            let entity = FinancialLiabilityEntity(
                id: record.id,
                userID: userID,
                name: record.name,
                amount: record.amount,
                rate: record.rate,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
            context.insert(entity)
        }
        try context.save()
    }

    private func upsertGoal(record: FinancialGoalRecord) throws {
        if let entity = try fetchGoalEntity(id: record.id) {
            entity.name = record.name
            entity.category = record.category
            entity.current = record.current
            entity.target = record.target
            entity.deadline = record.deadline
            entity.updatedAt = record.updatedAt
        } else {
            let entity = FinancialGoalEntity(
                id: record.id,
                userID: userID,
                name: record.name,
                category: record.category,
                current: record.current,
                target: record.target,
                deadline: record.deadline,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
            context.insert(entity)
        }
        try context.save()
    }

    private func removeAsset(id: UUID) throws {
        guard let entity = try fetchAssetEntity(id: id) else { return }
        context.delete(entity)
        try context.save()
    }

    private func removeLiability(id: UUID) throws {
        guard let entity = try fetchLiabilityEntity(id: id) else { return }
        context.delete(entity)
        try context.save()
    }

    private func removeGoal(id: UUID) throws {
        guard let entity = try fetchGoalEntity(id: id) else { return }
        context.delete(entity)
        try context.save()
    }

    private func persistBudgetChange(amount: Decimal) throws {
        if let planID = budgetPlanID, let plan = try fetchBudgetPlan(id: planID) {
            plan.totalLimit = amount
        } else {
            let interval = currentMonthInterval(referenceDate: Date())
            let plan = BudgetPlan(
                id: UUID(),
                title: "月度预算",
                period: .monthly,
                totalLimit: amount,
                startDate: interval.start,
                endDate: interval.end
            )
            context.insert(plan)
            budgetPlanID = plan.id
        }
        try context.save()
    }

    private func fetchBudgetPlan(id: UUID) throws -> BudgetPlan? {
        var descriptor = FetchDescriptor<BudgetPlan>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func currentMonthInterval(referenceDate: Date) -> DateInterval {
        if let interval = calendar.dateInterval(of: .month, for: referenceDate) {
            return interval
        }
        let start = calendar.startOfDay(for: referenceDate)
        let end = calendar.date(byAdding: .day, value: 30, to: start) ?? referenceDate
        return DateInterval(start: start, end: end)
    }

#if DEBUG
    func injectSampleData(
        budget: Decimal,
        assets: [FinancialAssetRecord],
        liabilities: [FinancialLiabilityRecord],
        goals: [FinancialGoalRecord]
    ) {
        budgetPlanID = nil
        self.budget = budget
        do {
            try clearPreviewFinancialData()
            try persistBudgetChange(amount: budget)
            for asset in assets {
                try upsertAsset(record: asset)
            }
            for liability in liabilities {
                try upsertLiability(record: liability)
            }
            for goal in goals {
                try upsertGoal(record: goal)
            }
        } catch {
            print("⚠️ 预览数据注入失败：\(error.localizedDescription)")
        }
        refreshFinancialData()
    }

    private func clearPreviewFinancialData() throws {
        let assetDescriptor = FetchDescriptor<FinancialAssetEntity>(
            predicate: #Predicate { $0.userID == userID }
        )
        let liabilityDescriptor = FetchDescriptor<FinancialLiabilityEntity>(
            predicate: #Predicate { $0.userID == userID }
        )
        let goalDescriptor = FetchDescriptor<FinancialGoalEntity>(
            predicate: #Predicate { $0.userID == userID }
        )
        let assetEntities = try context.fetch(assetDescriptor)
        let liabilityEntities = try context.fetch(liabilityDescriptor)
        let goalEntities = try context.fetch(goalDescriptor)
        let plans = try context.fetch(FetchDescriptor<BudgetPlan>())

        assetEntities.forEach { context.delete($0) }
        liabilityEntities.forEach { context.delete($0) }
        goalEntities.forEach { context.delete($0) }
        plans.forEach { context.delete($0) }

        try context.save()
    }
#endif

    private static func makeDisplay(
        budget: Decimal,
        assets: [FinancialAssetRecord],
        liabilities: [FinancialLiabilityRecord],
        goals: [FinancialGoalRecord],
        calendar: Calendar
    ) -> FinancialHealthDisplayModel {
        let assetItems = assets.map { record in
            FinancialPortfolioItem(
                id: record.id,
                name: record.name,
                amount: record.amount,
                rate: record.rate,
                term: record.term,
                detail: record.detail
            )
        }

        let liabilityItems = liabilities.map { record in
            FinancialPortfolioItem(
                id: record.id,
                name: record.name,
                amount: record.amount,
                rate: record.rate,
                term: nil,
                detail: nil
            )
        }

        let assetTotal = assets.reduce(Decimal.zero) { $0 + $1.amount }
        let liabilityTotal = liabilities.reduce(Decimal.zero) { $0 + $1.amount }

        let assetSummary = FinancialSummary(
            title: "资产总额",
            amount: assetTotal,
            detail: assets.isEmpty ? nil : "加权平均利率 \(formatRate(weightedAverageRate(records: assets)))"
        )

        let liabilitySummary = FinancialSummary(
            title: "负债总额",
            amount: liabilityTotal,
            detail: liabilities.isEmpty ? nil : "加权平均利率 \(formatRate(weightedAverageRate(records: liabilities)))"
        )

        let goalItems = goals.map { record in
            FinancialGoalItem(
                id: record.id,
                name: record.name,
                category: record.category,
                current: record.current,
                target: record.target,
                deadline: record.deadline
            )
        }

        let completionValue: Decimal
        if goals.isEmpty {
            completionValue = .zero
        } else {
            let sum = goals.reduce(Decimal.zero) { partial, goal in
                guard goal.target > .zero else { return partial }
                let ratio = min(max(goal.current / goal.target, 0), 1)
                return partial + ratio
            }
            completionValue = sum / Decimal(goals.count)
        }

        let summary = FinancialGoalSummary(
            activeGoals: goals.count,
            goalCompletion: completionValue.formattedPercentage()
        )

        return FinancialHealthDisplayModel(
            budget: budget,
            assets: assetItems,
            debts: liabilityItems,
            assetSummary: assetSummary,
            debtSummary: liabilitySummary,
            goals: goalItems,
            summary: summary
        )
    }
}

#if DEBUG
extension FinancialHealthViewModel {
    static func previewModel() -> FinancialHealthViewModel {
        let container = try! ModelContainer(
            for: BudgetPlan.self,
                BudgetSegment.self,
                UserProfileEntity.self,
                FinancialAssetEntity.self,
                FinancialLiabilityEntity.self,
                FinancialGoalEntity.self
        )
        let context = ModelContext(container)
        let eventBus = FinanceEventBus()
        let profileService = PersistentUserProfileService(context: context, eventBus: eventBus)
        let viewModel = FinancialHealthViewModel(
            context: context,
            eventBus: eventBus,
            userProfileService: profileService,
            userID: "preview"
        )
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        viewModel.injectSampleData(
            budget: 4000,
            assets: [
                FinancialAssetRecord(id: UUID(), name: "储蓄", amount: 30000, rate: 2.1, term: nil, detail: "活期户", createdAt: now, updatedAt: now),
                FinancialAssetRecord(id: UUID(), name: "投资理财", amount: 50000, rate: 4.5, term: "12个月", detail: "预期年化收益 4.5%", createdAt: now, updatedAt: now)
            ],
            liabilities: [
                FinancialLiabilityRecord(id: UUID(), name: "信用卡", amount: 10000, rate: 18, createdAt: now, updatedAt: now),
                FinancialLiabilityRecord(id: UUID(), name: "房贷", amount: 200000, rate: 4.2, createdAt: now, updatedAt: now)
            ],
            goals: [
                FinancialGoalRecord(id: UUID(), name: "旅行基金", category: "旅行", current: 8500, target: 15000, deadline: calendar.date(byAdding: .month, value: 6, to: now), createdAt: now, updatedAt: now),
                FinancialGoalRecord(id: UUID(), name: "紧急备用金", category: "储蓄", current: 18000, target: 30000, deadline: calendar.date(byAdding: .month, value: 9, to: now), createdAt: now, updatedAt: now)
            ]
        )
        return viewModel
    }
}
#endif

private func parseDecimal(_ text: String) -> Decimal? {
    let sanitized = text.replacingOccurrences(of: ",", with: "")
        .replacingOccurrences(of: "￥", with: "")
        .replacingOccurrences(of: "¥", with: "")
        .replacingOccurrences(of: " ", with: "")
    return Decimal(string: sanitized)
}

private func parseRate(_ text: String) -> Double? {
    let sanitized = text.replacingOccurrences(of: "%", with: "")
        .replacingOccurrences(of: " ", with: "")
    return Double(sanitized)
}

private func formatRate(_ value: Double) -> String {
    String(format: "%.2f%%", value)
}

private func weightedAverageRate(records: [FinancialAssetRecord]) -> Double {
    let total = records.reduce(Decimal.zero) { $0 + $1.amount }
    guard total > .zero else { return 0 }
    var numerator = Decimal.zero
    for record in records {
        numerator += record.amount * Decimal(record.rate)
    }
    let average = numerator / total
    return NSDecimalNumber(decimal: average).doubleValue
}

private func weightedAverageRate(records: [FinancialLiabilityRecord]) -> Double {
    let total = records.reduce(Decimal.zero) { $0 + $1.amount }
    guard total > .zero else { return 0 }
    var numerator = Decimal.zero
    for record in records {
        numerator += record.amount * Decimal(record.rate)
    }
    let average = numerator / total
    return NSDecimalNumber(decimal: average).doubleValue
}

private extension Decimal {
    func cleanNumericString() -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.numberStyle = .decimal
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? ""
    }
}
