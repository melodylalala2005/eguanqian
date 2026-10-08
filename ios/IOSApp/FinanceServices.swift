import Foundation
import Combine
import SwiftData

@MainActor
protocol TransactionRepository {
    func fetchRecentTransactions(limit: Int) throws -> [Transaction]
    func fetchSections(in range: DateInterval?) throws -> [TransactionSection]
    func fetchAllTransactions() throws -> [Transaction]
    func addTransaction(from draft: TransactionDraft) async throws -> Transaction
    func updateTransaction(_ transaction: Transaction) async throws
    func deleteTransaction(_ transaction: Transaction) throws
}

@MainActor
protocol BudgetService {
    func activePlan() throws -> BudgetPlan?
    func savePlan(_ plan: BudgetPlan) throws
    func updateSpentAmounts() throws
    func currentSummary(on date: Date) throws -> BudgetSummary?
}

@MainActor
protocol StatisticsService {
    func availableYears() throws -> [Int]
    func monthlySnapshots(for year: Int) throws -> [StatisticSnapshot]
    func yearlySnapshots(limit: Int) throws -> [StatisticSnapshot]
    func categorySummaries(
        kind: CategoryKind,
        in range: DateInterval?
    ) throws -> [CategorySummary]
    func goalComparisons() throws -> [GoalComparisonSnapshot]
}

// MARK: - Upcoming Remote Service Protocols

struct AIChatMessage: Identifiable, Equatable {
    enum Role: String, Equatable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let content: String
    let createdAt: Date

    init(id: UUID = UUID(), role: Role, content: String, createdAt: Date = .now) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

@MainActor
protocol AIChatService {
    func respond(to history: [AIChatMessage]) async throws -> AIChatMessage
}

@MainActor
protocol UserProfileService {
    var currentProfile: UserProfileSnapshot? { get }
    var profilePublisher: AnyPublisher<UserProfileSnapshot?, Never> { get }
    func loadProfile(for userID: String) throws -> UserProfileSnapshot?
    @discardableResult
    func saveProfile(for userID: String, from draft: UserProfileDraft) throws -> UserProfileSnapshot
}

struct GoalSyncPayload: Identifiable, Equatable {
    enum GoalType: String, Codable {
        case saving
        case investment
        case debt
    }

    let id: UUID
    var title: String
    var targetAmount: Decimal
    var currentAmount: Decimal
    var deadline: Date
    var category: String
    var type: GoalType
}

@MainActor
protocol GoalSyncService {
    func fetchGoals() async throws -> [GoalSyncPayload]
    func upsertGoal(_ payload: GoalSyncPayload) async throws
}

@MainActor
final class PersistentUserProfileService: UserProfileService {
    private let context: ModelContext
    private let eventBus: FinanceEventBus
    @Published private var profileCache: UserProfileSnapshot?

    init(context: ModelContext, eventBus: FinanceEventBus) {
        self.context = context
        self.eventBus = eventBus
    }

    var currentProfile: UserProfileSnapshot? {
        profileCache
    }

    var profilePublisher: AnyPublisher<UserProfileSnapshot?, Never> {
        $profileCache.eraseToAnyPublisher()
    }

    func loadProfile(for userID: String) throws -> UserProfileSnapshot? {
        if let entity = try fetchEntity(userID: userID) {
            let snapshot = entity.snapshot
            profileCache = snapshot
            return snapshot
        }
        return nil
    }

    @discardableResult
    func saveProfile(for userID: String, from draft: UserProfileDraft) throws -> UserProfileSnapshot {
        let entity = try fetchOrCreateEntity(userID: userID)
        entity.apply(from: draft)
        if context.hasChanges {
            try context.save()
        }
        let snapshot = entity.snapshot
        profileCache = snapshot
        eventBus.send(.userProfileUpdated(snapshot))
        return snapshot
    }

    private func fetchEntity(userID: String) throws -> UserProfileEntity? {
        let descriptor = FetchDescriptor<UserProfileEntity>(
            predicate: #Predicate<UserProfileEntity> { $0.userID == userID }
        )
        return try context.fetch(descriptor).first
    }

    private func fetchOrCreateEntity(userID: String) throws -> UserProfileEntity {
        if let existing = try fetchEntity(userID: userID) {
            return existing
        }
        let entity = UserProfileEntity(userID: userID)
        context.insert(entity)
        return entity
    }
}

// MARK: - Mock Implementations

@MainActor
struct MockTransactionRepository: TransactionRepository {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchRecentTransactions(limit: Int) throws -> [Transaction] {
        var descriptor = FetchDescriptor<Transaction>(
            predicate: nil,
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func fetchAllTransactions() throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: nil,
            sortBy: [SortDescriptor(\.occurredAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func fetchSections(in range: DateInterval?) throws -> [TransactionSection] {
        var predicate: Predicate<Transaction>?

        if let range {
            predicate = #Predicate<Transaction> { transaction in
                transaction.occurredAt >= range.start && transaction.occurredAt <= range.end
            }
        }

        let descriptor = FetchDescriptor<Transaction>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )

        let transactions = try context.fetch(descriptor)

        let grouped = Dictionary(grouping: transactions) {
            Calendar.current.startOfDay(for: $0.occurredAt)
        }

        return grouped
            .map { TransactionSection(date: $0.key, transactions: $0.value.sorted(by: { $0.occurredAt > $1.occurredAt })) }
            .sorted(by: { $0.date > $1.date })
    }

    func addTransaction(from draft: TransactionDraft) async throws -> Transaction {
        let transaction = Transaction(
            name: draft.name,
            type: draft.type,
            amount: draft.amount,
            occurredAt: draft.occurredAt,
            status: .pending,
            note: draft.note,
            rawJSON: nil,
            createdAt: .now,
            updatedAt: .now
        )

        if let categoryID = draft.categoryID {
            transaction.category = try context.fetch(
                FetchDescriptor<TransactionCategory>(
                    predicate: #Predicate<TransactionCategory> { category in
                        category.id == categoryID
                    }
                )
            ).first
        }

        transaction.spendingType = draft.spendingType

        context.insert(transaction)
        try context.save()
        return transaction
    }

    func updateTransaction(_ transaction: Transaction) async throws {
        transaction.updatedAt = .now
        try context.save()
    }

    func deleteTransaction(_ transaction: Transaction) throws {
        context.delete(transaction)
        try context.save()
    }
}

@MainActor
struct MockBudgetService: BudgetService {
    let context: ModelContext

    func activePlan() throws -> BudgetPlan? {
        let descriptor = FetchDescriptor<BudgetPlan>(
            predicate: nil,
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }

    func savePlan(_ plan: BudgetPlan) throws {
        context.insert(plan)
        try context.save()
    }

    func updateSpentAmounts() throws {
        let plans = try context.fetch(FetchDescriptor<BudgetPlan>())
        let transactions = try context.fetch(FetchDescriptor<Transaction>())

        for plan in plans {
            let filtered = transactions.filter { transaction in
                transaction.type == .expense &&
                    transaction.occurredAt >= plan.startDate &&
                    transaction.occurredAt <= plan.endDate
            }

            let grouped = Dictionary(grouping: filtered) { $0.category?.id }

            for segment in plan.segments {
                if let categoryID = segment.category?.id,
                   let items = grouped[categoryID] {
                    let total = items.reduce(Decimal.zero) { $0 + $1.amount }
                    segment.spent = total
                } else {
                    segment.spent = .zero
                }
            }
        }

        if context.hasChanges {
            try context.save()
        }
    }

    func currentSummary(on date: Date) throws -> BudgetSummary? {
        if let plan = try activePlan() {
            try updateSpentAmounts()

            let spent = plan.segments.reduce(Decimal.zero) { $0 + $1.spent }
            let remaining = max(plan.totalLimit - spent, 0)

            let calendar = Calendar.current
            let daysLeft: Int
            if date > plan.endDate {
                daysLeft = 0
            } else if let difference = calendar.dateComponents([.day], from: date, to: plan.endDate).day {
                daysLeft = max(difference, 0)
            } else {
                daysLeft = 0
            }

            return BudgetSummary(
                total: plan.totalLimit,
                spent: spent,
                remaining: remaining,
                daysLeft: daysLeft,
                period: plan.period,
                hasBudgetPlan: true
            )
        } else {
            let calendar = Calendar.current
            guard
                let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
                let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)
            else {
                return nil
            }

            let allTransactions = try context.fetch(FetchDescriptor<Transaction>())
            let transactions = allTransactions.filter { transaction in
                transaction.type == .expense &&
                transaction.occurredAt >= startOfMonth &&
                transaction.occurredAt <= endOfMonth
            }

            let spent = transactions.reduce(Decimal.zero) { $0 + $1.amount }
            let daysLeft = max(calendar.dateComponents([.day], from: date, to: endOfMonth).day ?? 0, 0)

            if spent == .zero {
                return nil
            }

            return BudgetSummary(
                total: spent,
                spent: spent,
                remaining: .zero,
                daysLeft: daysLeft,
                period: .monthly,
                hasBudgetPlan: false
            )
        }
    }
}

@MainActor
struct MockStatisticsService: StatisticsService {
    private let context: ModelContext
    private let calendar = Calendar.current

    init(context: ModelContext) {
        self.context = context
    }

    func availableYears() throws -> [Int] {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.occurredAt, order: .forward)]
        )
        let transactions = try context.fetch(descriptor)
        let years = Set(transactions.map { calendar.component(.year, from: $0.occurredAt) })
        if years.isEmpty {
            return [calendar.component(.year, from: .now)]
        }
        return years.sorted()
    }

    func monthlySnapshots(for year: Int) throws -> [StatisticSnapshot] {
        guard let startOfYear = calendar.date(from: DateComponents(year: year)) else { return [] }
        guard let endOfYear = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: startOfYear) else { return [] }
        let range = DateInterval(start: startOfYear, end: endOfYear)

        let transactions = try fetchTransactions(in: range)
        var buckets: [Int: (income: Decimal, expense: Decimal)] = [:]

        for transaction in transactions {
            let month = calendar.component(.month, from: transaction.occurredAt)
            var bucket = buckets[month] ?? (.zero, .zero)
            switch transaction.type {
            case .income:
                bucket.income += transaction.amount
            case .expense:
                bucket.expense += transaction.amount
            }
            buckets[month] = bucket
        }

        let orderedMonths = buckets.keys.sorted()
        return orderedMonths.map { month in
            let bucket = buckets[month] ?? (.zero, .zero)
            return StatisticSnapshot(
                label: "\(month)月",
                income: bucket.income,
                expense: bucket.expense
            )
        }
    }

    func yearlySnapshots(limit: Int) throws -> [StatisticSnapshot] {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.occurredAt, order: .forward)]
        )
        let transactions = try context.fetch(descriptor)

        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.component(.year, from: transaction.occurredAt)
        }

        let sortedYears = grouped.keys.sorted()
        let snapshots = sortedYears.map { year -> StatisticSnapshot in
            let values = grouped[year] ?? []
            let totals = values.reduce(into: (income: Decimal.zero, expense: Decimal.zero)) { partial, transaction in
                switch transaction.type {
                case .income:
                    partial.income += transaction.amount
                case .expense:
                    partial.expense += transaction.amount
                }
            }
            return StatisticSnapshot(
                label: "\(year)",
                income: totals.income,
                expense: totals.expense
            )
        }

        return Array(snapshots.suffix(limit))
    }

    func categorySummaries(kind: CategoryKind, in range: DateInterval?) throws -> [CategorySummary] {
        let transactions = try fetchTransactions(in: range).filter { transaction in
            switch (kind, transaction.type) {
            case (.expense, .expense), (.income, .income):
                return true
            default:
                return false
            }
        }

        var results: [UUID: (category: TransactionCategory, total: Decimal)] = [:]
        let uncategorized = TransactionCategory(
            name: "未分类",
            emoji: "❔",
            kind: kind,
            colorHex: "#94A3B8"
        )

        for transaction in transactions {
            let category = transaction.category ?? uncategorized
            let key = transaction.category?.id ?? uncategorized.id
            var entry = results[key] ?? (category, .zero)
            entry.total += transaction.amount
            results[key] = entry
        }

        return results.values
            .map { CategorySummary(category: $0.category, total: $0.total) }
            .sorted { $0.total > $1.total }
    }

    func goalComparisons() throws -> [GoalComparisonSnapshot] {
        var planDescriptor = FetchDescriptor<BudgetPlan>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        planDescriptor.fetchLimit = 1
        guard let plan = try context.fetch(planDescriptor).first else {
            return []
        }

        let interval = DateInterval(start: plan.startDate, end: plan.endDate)
        let expenses = try fetchTransactions(in: interval).filter { $0.type == .expense }
        let grouped = Dictionary(grouping: expenses) { $0.category?.id }

        return plan.segments.compactMap { segment in
            guard let category = segment.category else { return nil }
            let spent = grouped[category.id]?.reduce(Decimal.zero) { $0 + $1.amount } ?? .zero
            return GoalComparisonSnapshot(category: category.name, actual: spent, goal: segment.limit)
        }
    }

    private func fetchTransactions(in range: DateInterval?) throws -> [Transaction] {
        let predicate: Predicate<Transaction>?

        if let range {
            predicate = #Predicate<Transaction> { transaction in
                transaction.occurredAt >= range.start && transaction.occurredAt <= range.end
            }
        } else {
            predicate = nil
        }

        let descriptor = FetchDescriptor<Transaction>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.occurredAt, order: .forward)]
        )

        return try context.fetch(descriptor)
    }
}

// MARK: - Upcoming Remote Service Mocks

@MainActor
struct MockAIChatService: AIChatService {
    func respond(to history: [AIChatMessage]) async throws -> AIChatMessage {
        let userPrompt = history.last(where: { $0.role == .user })?.content ?? ""
        let reply = userPrompt.isEmpty
            ? "这是模拟助手，尚未连接真实 AI 服务。"
            : "收到你的消息：\(userPrompt)\n（模拟助手将来会接入真实 API）"
        try await Task.sleep(nanoseconds: 300_000_000) // Simulate latency
        return AIChatMessage(role: .assistant, content: reply)
    }
}

@MainActor
final class MockUserProfileService: UserProfileService {
    @Published private var profileCache: UserProfileSnapshot?

    var currentProfile: UserProfileSnapshot? {
        profileCache
    }

    var profilePublisher: AnyPublisher<UserProfileSnapshot?, Never> {
        $profileCache.eraseToAnyPublisher()
    }

    func loadProfile(for userID: String) throws -> UserProfileSnapshot? {
        profileCache
    }

    @discardableResult
    func saveProfile(for userID: String, from draft: UserProfileDraft) throws -> UserProfileSnapshot {
        let snapshot = UserProfileSnapshot(
            userID: userID,
            ageRange: draft.ageRange,
            occupation: draft.occupation,
            incomeBracket: draft.incomeBracket,
            goals: draft.goals,
            targetTimeline: draft.targetTimeline,
            targetAmount: draft.targetAmount,
            savedAmount: draft.savedAmount,
            updatedAt: .now
        )
        profileCache = snapshot
        return snapshot
    }
}

@MainActor
final class MockGoalSyncService: GoalSyncService {
    private var storage: [GoalSyncPayload]

    init(initialGoals: [GoalSyncPayload]? = nil) {
        storage = initialGoals ?? []
    }

    func fetchGoals() async throws -> [GoalSyncPayload] {
        try await Task.sleep(nanoseconds: 150_000_000)
        return storage
    }

    func upsertGoal(_ payload: GoalSyncPayload) async throws {
        try await Task.sleep(nanoseconds: 150_000_000)
        if let index = storage.firstIndex(where: { $0.id == payload.id }) {
            storage[index] = payload
        } else {
            storage.append(payload)
        }
    }

}


// MARK: - Receipt Recognition Services

enum ReceiptRecognitionProvider: String, CaseIterable {
    case baiduQwen

    var pathComponent: String {
        switch self {
        case .baiduQwen:
            return "/upload_baidu_qwen"
        }
    }
}

enum ReceiptNeedWantClassification: String, Codable {
    case need = "需要"
    case want = "想要"

    var mappedCategoryName: String {
        switch self {
        case .need:
            return "基本支出"
        case .want:
            return "娱乐支出"
        }
    }
}

struct ReceiptRecognitionResult: Codable {
    let category: String
    let amount: Decimal
    let date: String
    let description: String
    let needWantClassification: ReceiptNeedWantClassification?

    var spendingCategoryName: String? {
        needWantClassification?.mappedCategoryName
    }

    private enum CodingKeys: String, CodingKey {
        case category
        case amount
        case date
        case description
        case needWantClassification = "nw_type"
    }

    init(
        category: String,
        amount: Decimal,
        date: String,
        description: String,
        needWantClassification: ReceiptNeedWantClassification?
    ) {
        self.category = category
        self.amount = amount
        self.date = date
        self.description = description
        self.needWantClassification = needWantClassification
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        date = try container.decodeIfPresent(String.self, forKey: .date) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""

        if let decimalValue = try? container.decode(Decimal.self, forKey: .amount) {
            amount = decimalValue
        } else if let stringValue = try container.decodeIfPresent(String.self, forKey: .amount),
                  let parsed = Decimal(string: stringValue.filter { !$0.isWhitespace }) {
            amount = parsed
        } else if let stringValue = try container.decodeIfPresent(String.self, forKey: .amount),
                  let doubleValue = Double(stringValue.filter { !$0.isWhitespace }) {
            amount = Decimal(doubleValue)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .amount, in: container, debugDescription: "无法解析金额字段")
        }

        if let rawValue = try container.decodeIfPresent(String.self, forKey: .needWantClassification) {
            needWantClassification = ReceiptNeedWantClassification(rawValue: rawValue)
        } else {
            needWantClassification = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(category, forKey: .category)
        try container.encode(amount, forKey: .amount)
        try container.encode(date, forKey: .date)
        try container.encode(description, forKey: .description)
        if let needWantClassification {
            try container.encode(needWantClassification.rawValue, forKey: .needWantClassification)
        }
    }
}

private struct ReceiptRecognitionResponse: Decodable {
    let status: String
    let result: ReceiptRecognitionResult?
    let message: String?
}

enum ReceiptRecognitionError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized(message: String?)
    case serverError(statusCode: Int, message: String?)
    case statusNotOK(message: String?)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "识别接口地址无效。"
        case .invalidResponse:
            return "服务器返回了无效响应。"
        case let .unauthorized(message):
            return message ?? "登录已过期，请重新登录后再试。"
        case let .serverError(statusCode, message):
            if let message {
                return "识别服务返回错误 (\(statusCode))：\(message)"
            } else {
                return "识别服务返回错误 (\(statusCode))。"
            }
        case let .statusNotOK(message):
            return message ?? "识别失败，请稍后再试。"
        case let .decodingFailed(error):
            return "识别结果解析失败：\(error.localizedDescription)"
        }
    }
}

protocol ReceiptRecognitionService {
    func recognizeWithBaiduQwen(
        imageData: Data,
        token: String,
        billID: String
    ) async throws -> ReceiptRecognitionResult
}

struct NetworkReceiptRecognitionService: ReceiptRecognitionService {
    private let configuration: APIConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder

    init(configuration: APIConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    func recognizeWithBaiduQwen(
        imageData: Data,
        token: String,
        billID: String
    ) async throws -> ReceiptRecognitionResult {
        try await recognize(
            imageData: imageData,
            provider: .baiduQwen,
            token: token,
            billID: billID
        )
    }

    private func recognize(
        imageData: Data,
        provider: ReceiptRecognitionProvider,
        token: String,
        billID: String
    ) async throws -> ReceiptRecognitionResult {
        guard let url = URL(string: provider.pathComponent, relativeTo: configuration.baseURL) else {
            throw ReceiptRecognitionError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let formData = try makeMultipartBody(
            boundary: boundary,
            imageData: imageData,
            token: token,
            billID: billID
        )
        request.httpBody = formData

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReceiptRecognitionError.invalidResponse
        }

        if !(200 ..< 300).contains(httpResponse.statusCode) {
            let payload = try? decoder.decode(ReceiptRecognitionResponse.self, from: data)
            let message = payload?.message ?? String(data: data, encoding: .utf8)

            if httpResponse.statusCode == 401 {
                throw ReceiptRecognitionError.unauthorized(message: message)
            }

            throw ReceiptRecognitionError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            let payload = try decoder.decode(ReceiptRecognitionResponse.self, from: data)
            guard payload.status == "ok" else {
                throw ReceiptRecognitionError.statusNotOK(message: payload.message)
            }
            guard let result = payload.result else {
                throw ReceiptRecognitionError.invalidResponse
            }
            return result
        } catch let decodingError as ReceiptRecognitionError {
            throw decodingError
        } catch {
            throw ReceiptRecognitionError.decodingFailed(error)
        }
    }

    private func makeMultipartBody(
        boundary: String,
        imageData: Data,
        token: String,
        billID: String
    ) throws -> Data {
        var body = Data()

        func append(_ string: String) {
            if let data = string.data(using: .utf8) {
                body.append(data)
            }
        }

        let lineBreak = "\r\n"

        append("--\(boundary)\(lineBreak)")
        append("Content-Disposition: form-data; name=\"token\"\(lineBreak)\(lineBreak)")
        append("\(token)\(lineBreak)")

        append("--\(boundary)\(lineBreak)")
        append("Content-Disposition: form-data; name=\"bill_id\"\(lineBreak)\(lineBreak)")
        append("\(billID)\(lineBreak)")

        append("--\(boundary)\(lineBreak)")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"receipt.jpg\"\(lineBreak)")
        append("Content-Type: image/jpeg\(lineBreak)\(lineBreak)")
        body.append(imageData)
        append(lineBreak)
        append("--\(boundary)--\(lineBreak)")

        return body
    }
}

