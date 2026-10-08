enum SpendingType: String, Codable, CaseIterable, Identifiable {
    case basic = "基本支出"
    case entertainment = "娱乐支出"

    var id: String { rawValue }
}
import Foundation
import SwiftData
import CoreGraphics

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case expense
    case income

    var id: String { rawValue }
}

enum TransactionStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case ok
    case `default`

    var id: String { rawValue }
}

enum CategoryKind: String, Codable, CaseIterable, Identifiable {
    case expense
    case income

    var id: String { rawValue }
}

struct CategoryOption: Identifiable {
    let id: UUID
    let name: String
    let emoji: String
    let colorHex: String
    let kind: CategoryKind

    init(category: TransactionCategory) {
        self.id = category.id
        self.name = category.name
        self.emoji = category.emoji
        self.colorHex = category.colorHex
        self.kind = category.kind
    }
}

enum BudgetPeriod: String, Codable, CaseIterable, Identifiable {
    case monthly
    case yearly

    var id: String { rawValue }
}

@Model
final class TransactionCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    var emoji: String
    var kind: CategoryKind
    var colorHex: String

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String,
        kind: CategoryKind,
        colorHex: String = "#FFFFFF"
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.kind = kind
        self.colorHex = colorHex
        self.transactions = []
    }
}

@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var name: String
    var type: TransactionType
    var amount: Decimal
    var occurredAt: Date
    var status: TransactionStatus
    var note: String?
    var rawJSON: String?
    var spendingTypeRaw: String?
    var createdAt: Date
    var updatedAt: Date
    var cloudID: String?

    @Relationship(deleteRule: .nullify)
    var category: TransactionCategory?

    init(
        id: UUID = UUID(),
        name: String,
        type: TransactionType,
        amount: Decimal,
        occurredAt: Date,
        status: TransactionStatus = .pending,
        note: String? = nil,
        rawJSON: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        category: TransactionCategory? = nil,
        cloudID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.amount = amount
        self.occurredAt = occurredAt
        self.status = status
        self.note = note
        self.rawJSON = rawJSON
        self.spendingTypeRaw = nil
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.category = category
        self.cloudID = cloudID
    }

    var spendingType: SpendingType? {
        get { spendingTypeRaw.flatMap(SpendingType.init(rawValue:)) }
        set { spendingTypeRaw = newValue?.rawValue }
    }
}

@Model
final class BudgetPlan {
    @Attribute(.unique) var id: UUID
    var title: String
    var period: BudgetPeriod
    var totalLimit: Decimal
    var startDate: Date
    var endDate: Date

    @Relationship(deleteRule: .cascade, inverse: \BudgetSegment.plan)
    var segments: [BudgetSegment]

    init(
        id: UUID = UUID(),
        title: String,
        period: BudgetPeriod,
        totalLimit: Decimal,
        startDate: Date,
        endDate: Date,
        segments: [BudgetSegment] = []
    ) {
        self.id = id
        self.title = title
        self.period = period
        self.totalLimit = totalLimit
        self.startDate = startDate
        self.endDate = endDate
        self.segments = segments
    }
}

@Model
final class BudgetSegment {
    @Attribute(.unique) var id: UUID
    var limit: Decimal
    var spent: Decimal

    @Relationship(deleteRule: .nullify)
    var category: TransactionCategory?

    @Relationship(deleteRule: .nullify)
    var plan: BudgetPlan?

    init(
        id: UUID = UUID(),
        limit: Decimal,
        spent: Decimal = .zero,
        category: TransactionCategory? = nil,
        plan: BudgetPlan? = nil
    ) {
        self.id = id
        self.limit = limit
        self.spent = spent
        self.category = category
        self.plan = plan
    }
}

@Model
final class FinancialAssetEntity {
    @Attribute(.unique) var id: UUID
    var userID: String
    var name: String
    var amount: Decimal
    var rate: Double
    var term: String?
    var detail: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userID: String,
        name: String,
        amount: Decimal,
        rate: Double,
        term: String? = nil,
        detail: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userID = userID
        self.name = name
        self.amount = amount
        self.rate = rate
        self.term = term
        self.detail = detail
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class FinancialLiabilityEntity {
    @Attribute(.unique) var id: UUID
    var userID: String
    var name: String
    var amount: Decimal
    var rate: Double
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userID: String,
        name: String,
        amount: Decimal,
        rate: Double,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userID = userID
        self.name = name
        self.amount = amount
        self.rate = rate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class FinancialGoalEntity {
    @Attribute(.unique) var id: UUID
    var userID: String
    var name: String
    var category: String
    var current: Decimal
    var target: Decimal
    var deadline: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userID: String,
        name: String,
        category: String,
        current: Decimal,
        target: Decimal,
        deadline: Date?,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userID = userID
        self.name = name
        self.category = category
        self.current = current
        self.target = target
        self.deadline = deadline
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct TransactionDraft: Identifiable {
    var id: UUID = UUID()
    var name: String
    var type: TransactionType
    var amount: Decimal
    var categoryID: UUID?
    var occurredAt: Date
    var note: String?
    var spendingType: SpendingType?

    static func empty() -> TransactionDraft {
        TransactionDraft(
            name: "",
            type: .expense,
            amount: .zero,
            categoryID: nil,
            occurredAt: .now,
            note: nil,
            spendingType: nil
        )
    }
}

struct TransactionSection: Identifiable {
    let id: UUID = UUID()
    let date: Date
    let transactions: [Transaction]
}

struct CategorySummary: Identifiable {
    let id = UUID()
    let category: TransactionCategory
    let total: Decimal
}

struct StatisticsCategoryEntry: Identifiable {
    let id = UUID()
    let name: String
    let amount: Decimal
    let colorHex: String

    var amountDouble: Double {
        amount.asDouble
    }
}

struct StatisticSnapshot: Identifiable {
    let id = UUID()
    let label: String
    let income: Decimal
    let expense: Decimal
}

struct GoalComparisonSnapshot: Identifiable {
    let id = UUID()
    let category: String
    let actual: Decimal
    let goal: Decimal

    var isOverBudget: Bool {
        actual > goal
    }

    var progress: Double {
        guard goal > .zero else { return 1 }
        return min((actual as NSDecimalNumber).doubleValue / (goal as NSDecimalNumber).doubleValue, 1)
    }
}

struct BudgetSummary {
    let total: Decimal
    let spent: Decimal
    let remaining: Decimal
    let daysLeft: Int
    let period: BudgetPeriod
    let hasBudgetPlan: Bool

    init(
        total: Decimal,
        spent: Decimal,
        remaining: Decimal,
        daysLeft: Int,
        period: BudgetPeriod,
        hasBudgetPlan: Bool = true
    ) {
        self.total = total
        self.spent = spent
        self.remaining = remaining
        self.daysLeft = daysLeft
        self.period = period
        self.hasBudgetPlan = hasBudgetPlan
    }

    var progress: Double {
        guard total > 0 else { return 0 }
        return min(max((spent as NSDecimalNumber).doubleValue / (total as NSDecimalNumber).doubleValue, 0), 1)
    }
}

enum ReceiptRecognitionTaskStatus: String, Codable, CaseIterable, Identifiable {
    case queued
    case preprocessing
    case uploading
    case awaitingRetry
    case completed
    case failed
    case cancelled

    var id: String { rawValue }

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled:
            return true
        default:
            return false
        }
    }
}

@Model
final class PendingReceiptRecognition {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var providerIdentifier: String
    var imageFileURL: URL
    var statusIdentifier: String
    var billID: String
    var userID: String?
    var tokenSnapshot: String?
    var retryCount: Int
    var lastErrorMessage: String?
    var lastAttemptAt: Date?
    var nextRetryAt: Date?
    var resultJSON: String?
    var recognizedAt: Date?
    var originalFileSize: Int
    var compressedFileSize: Int
    var outputWidth: Double
    var outputHeight: Double
    var originalWidth: Double
    var originalHeight: Double
    var compressionQuality: Double

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        provider: ReceiptRecognitionProvider,
        imageFileURL: URL,
        status: ReceiptRecognitionTaskStatus = .queued,
        billID: String,
        userID: String?,
        tokenSnapshot: String?,
        originalFileSize: Int,
        compressedFileSize: Int,
        outputDimensions: CGSize,
        originalDimensions: CGSize,
        compressionQuality: Double
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.providerIdentifier = provider.rawValue
        self.imageFileURL = imageFileURL
        self.statusIdentifier = status.rawValue
        self.billID = billID
        self.userID = userID
        self.tokenSnapshot = tokenSnapshot
        self.retryCount = 0
        self.originalFileSize = originalFileSize
        self.compressedFileSize = compressedFileSize
        self.outputWidth = outputDimensions.width
        self.outputHeight = outputDimensions.height
        self.originalWidth = originalDimensions.width
        self.originalHeight = originalDimensions.height
        self.compressionQuality = compressionQuality
        self.nextRetryAt = nil
        self.recognizedAt = nil
    }

    var provider: ReceiptRecognitionProvider {
        get { ReceiptRecognitionProvider(rawValue: providerIdentifier) ?? .baiduQwen }
        set { providerIdentifier = newValue.rawValue }
    }

    var status: ReceiptRecognitionTaskStatus {
        get { ReceiptRecognitionTaskStatus(rawValue: statusIdentifier) ?? .queued }
        set { statusIdentifier = newValue.rawValue }
    }

    var outputDimensions: CGSize {
        get { CGSize(width: outputWidth, height: outputHeight) }
        set {
            outputWidth = newValue.width
            outputHeight = newValue.height
        }
    }

    var originalDimensions: CGSize {
        get { CGSize(width: originalWidth, height: originalHeight) }
        set {
            originalWidth = newValue.width
            originalHeight = newValue.height
        }
    }

    var compressionQualityCapped: CGFloat {
        CGFloat(min(max(compressionQuality, 0), 1))
    }

    func markUpdated() {
        updatedAt = .now
    }
}

@Model
final class RecognizedReceiptHistory {
    @Attribute(.unique) var id: UUID
    var providerIdentifier: String
    var billID: String
    var userID: String?
    var recognizedAt: Date
    var resultJSON: String
    var imageFilePath: String?
    var appliedTransactionID: UUID?
    var originalFileSize: Int
    var compressedFileSize: Int
    var compressionQuality: Double

    init(
        id: UUID = UUID(),
        provider: ReceiptRecognitionProvider,
        billID: String,
        userID: String?,
        recognizedAt: Date,
        resultJSON: String,
        imageFilePath: String?,
        originalFileSize: Int,
        compressedFileSize: Int,
        compressionQuality: Double,
        appliedTransactionID: UUID? = nil
    ) {
        self.id = id
        self.providerIdentifier = provider.rawValue
        self.billID = billID
        self.userID = userID
        self.recognizedAt = recognizedAt
        self.resultJSON = resultJSON
        self.imageFilePath = imageFilePath
        self.originalFileSize = originalFileSize
        self.compressedFileSize = compressedFileSize
        self.compressionQuality = compressionQuality
        self.appliedTransactionID = appliedTransactionID
    }

    var provider: ReceiptRecognitionProvider {
        get { ReceiptRecognitionProvider(rawValue: providerIdentifier) ?? .baiduQwen }
        set { providerIdentifier = newValue.rawValue }
    }

    var result: ReceiptRecognitionResult? {
        guard let data = resultJSON.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(ReceiptRecognitionResult.self, from: data)
    }

    var imageFileURL: URL? {
        guard let imageFilePath else { return nil }
        return URL(fileURLWithPath: imageFilePath)
    }
}

