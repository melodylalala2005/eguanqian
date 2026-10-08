import Foundation
import SwiftData

@MainActor
final class ReceiptRecognitionHistoryStore {
    private let context: ModelContext
    private let encoder: JSONEncoder

    init(context: ModelContext) {
        self.context = context
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = encoder
    }

    func append(from task: PendingReceiptRecognition, result: ReceiptRecognitionResult) throws -> RecognizedReceiptHistory {
        let data = try encoder.encode(result)
        guard let json = String(data: data, encoding: .utf8) else {
            throw ReceiptRecognitionHistoryStoreError.encodingFailed
        }

        let history = RecognizedReceiptHistory(
            provider: task.provider,
            billID: task.billID,
            userID: task.userID,
            recognizedAt: Date(),
            resultJSON: json,
            imageFilePath: task.imageFileURL.path,
            originalFileSize: task.originalFileSize,
            compressedFileSize: task.compressedFileSize,
            compressionQuality: task.compressionQuality
        )
        context.insert(history)
        try context.save()
        return history
    }

    func fetchRecent(limit: Int = 50) throws -> [RecognizedReceiptHistory] {
        var descriptor = FetchDescriptor<RecognizedReceiptHistory>(
            sortBy: [SortDescriptor(\.recognizedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func delete(_ history: RecognizedReceiptHistory) throws {
        context.delete(history)
        try context.save()
    }

    func markApplied(historyID: UUID, transactionID: UUID) throws {
        guard let history = try fetchHistory(id: historyID) else {
            throw ReceiptRecognitionHistoryStoreError.entryNotFound
        }
        history.appliedTransactionID = transactionID
        history.recognizedAt = history.recognizedAt
        try context.save()
    }

    private func fetchHistory(id: UUID) throws -> RecognizedReceiptHistory? {
        let descriptor = FetchDescriptor<RecognizedReceiptHistory>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    func clearAll() throws {
        let items = try context.fetch(FetchDescriptor<RecognizedReceiptHistory>())
        items.forEach(context.delete)
        if context.hasChanges {
            try context.save()
        }
    }
}

enum ReceiptRecognitionHistoryStoreError: LocalizedError {
    case encodingFailed
    case entryNotFound

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "无法保存识别结果，请稍后重试。"
        case .entryNotFound:
            return "识别历史不存在或已被删除。"
        }
    }
}
