import Foundation
import CoreGraphics
import SwiftData

@MainActor
final class ReceiptRecognitionQueueStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func enqueue(
        processedImage: ReceiptImagePreprocessor.ProcessedImage,
        provider: ReceiptRecognitionProvider,
        billID: String,
        userID: String?,
        tokenSnapshot: String?
    ) throws -> PendingReceiptRecognition {
        let fileURL = try processedImage.persist()
        let pending = PendingReceiptRecognition(
            provider: provider,
            imageFileURL: fileURL,
            billID: billID,
            userID: userID,
            tokenSnapshot: tokenSnapshot,
            originalFileSize: processedImage.originalFileSize,
            compressedFileSize: processedImage.compressedFileSize,
            outputDimensions: processedImage.outputDimensions,
            originalDimensions: processedImage.originalDimensions,
            compressionQuality: processedImage.compressionQuality.doubleValue
        )
        context.insert(pending)
        try context.save()
        return pending
    }

    func fetchQueued(maxCount: Int? = nil) throws -> [PendingReceiptRecognition] {
        let descriptor = FetchDescriptor<PendingReceiptRecognition>(
            sortBy: [
                SortDescriptor(\.nextRetryAt, order: .forward),
                SortDescriptor(\.createdAt, order: .forward)
            ]
        )

        let tasks = try context.fetch(descriptor)
        let activeStatuses: Set<String> = [
            ReceiptRecognitionTaskStatus.queued.rawValue,
            ReceiptRecognitionTaskStatus.preprocessing.rawValue,
            ReceiptRecognitionTaskStatus.uploading.rawValue,
            ReceiptRecognitionTaskStatus.awaitingRetry.rawValue
        ]
        let filtered = tasks.filter { activeStatuses.contains($0.statusIdentifier) }
        if let maxCount {
            return Array(filtered.prefix(maxCount))
        }
        return filtered
    }

    func fetchFailed() throws -> [PendingReceiptRecognition] {
        let failedStatus = ReceiptRecognitionTaskStatus.failed.rawValue
        let descriptor = FetchDescriptor<PendingReceiptRecognition>(
            predicate: #Predicate { $0.statusIdentifier == failedStatus },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchAwaitingRetry() throws -> [PendingReceiptRecognition] {
        let awaitingStatus = ReceiptRecognitionTaskStatus.awaitingRetry.rawValue
        let descriptor = FetchDescriptor<PendingReceiptRecognition>(
            predicate: #Predicate { $0.statusIdentifier == awaitingStatus },
            sortBy: [
                SortDescriptor(\.nextRetryAt, order: .forward),
                SortDescriptor(\.updatedAt, order: .forward)
            ]
        )
        return try context.fetch(descriptor)
    }

    func fetchMissingToken() throws -> [PendingReceiptRecognition] {
        let descriptor = FetchDescriptor<PendingReceiptRecognition>(
            predicate: #Predicate { $0.tokenSnapshot == nil },
            sortBy: [SortDescriptor(\.updatedAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func task(withID id: UUID) throws -> PendingReceiptRecognition? {
        var descriptor = FetchDescriptor<PendingReceiptRecognition>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func update(_ task: PendingReceiptRecognition, mutation: (PendingReceiptRecognition) -> Void) throws {
        mutation(task)
        task.markUpdated()
        try context.save()
    }

    func delete(_ task: PendingReceiptRecognition) throws {
        context.delete(task)
        try context.save()
    }

    func reset() throws {
        let all = try context.fetch(FetchDescriptor<PendingReceiptRecognition>())
        all.forEach(context.delete)
        if context.hasChanges {
            try context.save()
        }
    }
}

private extension CGFloat {
    var doubleValue: Double { Double(self) }
}
