import Foundation
import SwiftData

enum SharedModelContainerProvider {
    private static let defaultStoreFilename = "default.store"
    private static let legacyFolderName = "SharedFinanceData"
    private static let legacyStoreFilename = "FinanceStore.sqlite"

    private static var storeURL: URL = {
        let fileManager = FileManager.default
        guard let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("无法定位 Application Support 目录")
        }

        if !fileManager.fileExists(atPath: baseURL.path) {
            try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        }

        let destination = baseURL.appendingPathComponent(defaultStoreFilename, isDirectory: false)
        migrateLegacyStoreIfNeeded(destination: destination, baseURL: baseURL)
        return destination
    }()

    private static func migrateLegacyStoreIfNeeded(destination: URL, baseURL: URL) {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: destination.path) else { return }

        let legacyDirectory = baseURL.appendingPathComponent(legacyFolderName, isDirectory: true)
        let legacyStore = legacyDirectory.appendingPathComponent(legacyStoreFilename)
        guard fileManager.fileExists(atPath: legacyStore.path) else { return }

        do {
            try fileManager.copyItem(at: legacyStore, to: destination)
            try copySidecarIfNeeded(fileExtension: "shm", from: legacyStore, to: destination)
            try copySidecarIfNeeded(fileExtension: "wal", from: legacyStore, to: destination)
        } catch {
            print("⚠️ 迁移历史数据失败：\(error.localizedDescription)")
        }
    }

    private static func copySidecarIfNeeded(fileExtension ext: String, from source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        let sourceURL = source.appendingPathExtension(ext)
        guard fileManager.fileExists(atPath: sourceURL.path) else { return }
        let destinationURL = destination.appendingPathExtension(ext)
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    private static var configuration: ModelConfiguration {
        ModelConfiguration(url: storeURL)
    }

    static func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: LedgerEntry.self,
                 Transaction.self,
                 TransactionCategory.self,
                 BudgetPlan.self,
                 BudgetSegment.self,
                 PendingReceiptRecognition.self,
                 RecognizedReceiptHistory.self,
                 UserProfileEntity.self,
                 FinancialAssetEntity.self,
                 FinancialLiabilityEntity.self,
                 FinancialGoalEntity.self,
            configurations: configuration
        )
    }
}

