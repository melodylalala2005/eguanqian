import AppIntents
import Photos
import SwiftData
import SwiftUI
import UserNotifications

/// 用户双击背部快捷指令的输出结构，捷径可直接引用这些字段。
@available(iOS 17, *)
struct ProcessReceiptSummary: TransientAppEntity, Codable, Sendable {
    let id: UUID
    let amount: Decimal?
    let merchant: String?
    let category: String?
    let spendingType: String?
    let message: String

    init(
        id: UUID = UUID(),
        amount: Decimal?,
        merchant: String?,
        category: String?,
        spendingType: String?,
        message: String
    ) {
        self.id = id
        self.amount = amount
        self.merchant = merchant
        self.category = category
        self.spendingType = spendingType
        self.message = message
    }

    init() {
        self.init(id: UUID(), amount: nil, merchant: nil, category: nil, spendingType: nil, message: "")
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        .init(name: "识别摘要")
    }

    var displayRepresentation: DisplayRepresentation {
        let amountText = amount?.formattedCurrency() ?? "金额未知"
        let title = "\(category ?? "记账") · \(amountText)"
        let subtitleCandidate = merchant ?? spendingType
        let titleResource = LocalizedStringResource(stringLiteral: title)
        let subtitleResource = subtitleCandidate.flatMap { value -> LocalizedStringResource? in
            guard !value.isEmpty else { return nil }
            return LocalizedStringResource(stringLiteral: value)
        }
        return DisplayRepresentation(
            title: titleResource,
            subtitle: subtitleResource,
            image: .init(systemName: "bolt.fill")
        )
    }
}

@available(iOS 17, *)
struct ProcessReceiptIntent: AppIntent {
    static var title: LocalizedStringResource = "自动识别账单"
    static var description = IntentDescription("上传截屏并自动识别账单，生成记账记录。")

    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static var openAppWhenRun = false

    @Parameter(title: "截屏文件", requestValueDialog: "请选择刚刚的截屏")
    var screenshot: IntentFile

    private var pipeline: ReceiptProcessingPipeline { ReceiptProcessingPipeline.shared }

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<ProcessReceiptSummary> {
        let summary = try await pipeline.processScreenshot(file: screenshot)
        return .result(
            value: summary,
            dialog: .init(stringLiteral: summary.message)
        )
    }
}

// MARK: - 识别流水线

@available(iOS 17, *)
final class ReceiptProcessingPipeline {
    let modelContainer: ModelContainer
    let recognitionService: any ReceiptRecognitionService
    let tokenProvider: ReceiptRecognitionTokenProvider
    let bookkeeper: ReceiptAutoBookkeeper
    let notificationCenter: UNUserNotificationCenter

    init(
        modelContainer: ModelContainer,
        recognitionService: any ReceiptRecognitionService,
        tokenProvider: ReceiptRecognitionTokenProvider,
        bookkeeper: ReceiptAutoBookkeeper,
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.modelContainer = modelContainer
        self.recognitionService = recognitionService
        self.tokenProvider = tokenProvider
        self.bookkeeper = bookkeeper
        self.notificationCenter = notificationCenter
    }

    func processScreenshot(file: IntentFile) async throws -> ProcessReceiptSummary {
        let (data, cleanupHandle) = try await loadScreenshotData(from: file)
        defer { cleanupHandle.scheduleCleanup() }

        let token = try tokenProvider.fetchActiveToken()
        let billID = UUID().uuidString

        let recognition = try await recognitionService.recognizeWithBaiduQwen(
            imageData: data,
            token: token,
            billID: billID
        )

        let transaction = try await bookkeeper.persist(result: recognition, billID: billID)
        try await cleanupHandle.executeDeletionIfNeeded()
        await notifyUser(with: recognition, transaction: transaction)

        let typeSuffix = recognition.spendingCategoryName.map { " · \($0)" } ?? ""
        let normalizedAmount = recognition.amount.magnitude
        let amountText = normalizedAmount.formattedCurrency()

        return ProcessReceiptSummary(
            amount: normalizedAmount,
            merchant: transaction.name,
            category: recognition.category,
            spendingType: recognition.spendingCategoryName,
            message: "记账成功：\(recognition.category)\(typeSuffix) · \(amountText)"
        )
    }

    private func loadScreenshotData(from file: IntentFile) async throws -> (Data, ScreenshotCleanupHandle) {
        let data = file.data
        let cleanupHandle = ScreenshotCleanupHandle()
        cleanupHandle.captureLatestScreenshotReference()
        return (data, cleanupHandle)
    }

    private func notifyUser(with result: ReceiptRecognitionResult, transaction: Transaction) async {
        let settings = await notificationCenter.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        }

        let content = UNMutableNotificationContent()
        let typeLabel = result.spendingCategoryName.map { " · \($0)" } ?? ""
        let normalizedAmount = result.amount.magnitude
        let amountText = normalizedAmount.formattedCurrency()
        content.title = "鹅管钱 AI 助手"
        content.subtitle = "\(transaction.name)\(typeLabel) · \(amountText)"
        content.body = AIAssistantNotificationText
        content.sound = .default
        content.userInfo = [
            AppNotificationUserInfoKey.deeplink: AppDeepLinkIdentifier.aiAssistantMessage.rawValue,
            AppNotificationUserInfoKey.aiMessage: AIAssistantNotificationText
        ]

        let request = UNNotificationRequest(
            identifier: "auto-bookkeeping-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await notificationCenter.add(request)
    }

    // MARK: Shared Instance
    static let shared: ReceiptProcessingPipeline = ReceiptProcessingDependencies.make()
}

// MARK: - 截图清理

private final class ScreenshotCleanupHandle {
    private var candidateAssetIdentifier: String?

    func captureLatestScreenshotReference() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 1
        let assets = PHAsset.fetchAssets(with: .image, options: options)
        candidateAssetIdentifier = assets.firstObject?.localIdentifier
    }

    func scheduleCleanup() {
        // 占位函数，保留兼容性，删除逻辑在 executeDeletionIfNeeded 调用。
    }

    func executeDeletionIfNeeded() async throws {
        guard let identifier = candidateAssetIdentifier else { return }

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard assets.count > 0 else { return }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }
}

// MARK: - Token Provider

protocol ReceiptRecognitionTokenProvider {
    func fetchActiveToken() throws -> String
}

struct EnvironmentTokenProvider: ReceiptRecognitionTokenProvider {
    let configuration: APIConfiguration

    func fetchActiveToken() throws -> String {
        configuration.recognitionToken
    }
}

// MARK: - 记账入库

@MainActor
struct ReceiptAutoBookkeeper {
    let repository: TransactionRepository
    let syncCoordinator: TransactionSyncCoordinator
    let eventBus: FinanceEventBus
    let context: ModelContext

    func persist(result: ReceiptRecognitionResult, billID: String) async throws -> Transaction {
        var draft = TransactionDraft.empty()
        let normalizedAmount = result.amount.magnitude
        draft.name = resolvedName(from: result)
        draft.type = .expense
        draft.amount = normalizedAmount
        draft.occurredAt = parsedDate(from: result.date) ?? .now
        draft.note = sanitizedNote(from: result.description)
        draft.categoryID = fetchCategoryID(for: result.category)
        draft.spendingType = result.spendingCategoryName.flatMap(SpendingType.init(rawValue:))

        let transaction = try await repository.addTransaction(from: draft)

        if let classification = result.spendingCategoryName {
            let metadata: [String: String] = [
                "bill_id": billID,
                "spending_type": classification
            ]
            if let data = try? JSONSerialization.data(withJSONObject: metadata, options: []),
               let json = String(data: data, encoding: .utf8) {
                transaction.rawJSON = json
                try? await repository.updateTransaction(transaction)
            }
        }

        eventBus.send(.transactionsChanged(source: .dashboard))
        SharedAppNotifications.postTransactionsChanged()
        Task {
            await syncTransaction(transaction)
        }

        return transaction
    }

    private func fetchCategoryID(for name: String) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let descriptor = FetchDescriptor<TransactionCategory>(
            predicate: #Predicate<TransactionCategory> { category in
                category.name == trimmed
            }
        )
        return try? context.fetch(descriptor).first?.id
    }

    private func parsedDate(from value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let date = ReceiptAutoBookkeeper.dateFormatter.date(from: trimmed) {
            return date
        }
        return ReceiptAutoBookkeeper.isoFormatter.date(from: trimmed)
    }

    private func sanitizedNote(from description: String) -> String? {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func resolvedName(from result: ReceiptRecognitionResult) -> String {
        if let note = sanitizedNote(from: result.description) {
            return note
        }
        let trimmedCategory = result.category.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCategory.isEmpty ? "自动识别账单" : trimmedCategory
    }

    private func syncTransaction(_ transaction: Transaction) async {
        do {
            _ = try await syncCoordinator.sync(transaction: transaction)
            eventBus.send(.transactionsChanged(source: .sync))
            SharedAppNotifications.postTransactionsChanged()
        } catch {
            await syncCoordinator.markPending(transaction)
            eventBus.send(.transactionsChanged(source: .sync))
            SharedAppNotifications.postTransactionsChanged()
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()
}

// MARK: - Dependency Factory

@available(iOS 17, *)
private enum ReceiptProcessingDependencies {
    static func make() -> ReceiptProcessingPipeline {
        do {
            let container = try SharedModelContainerProvider.makeContainer()

            let environment = FinanceEnvironment(context: container.mainContext)

            return ReceiptProcessingPipeline(
                modelContainer: container,
                recognitionService: environment.receiptRecognitionService,
                tokenProvider: EnvironmentTokenProvider(configuration: environment.apiConfiguration),
                bookkeeper: ReceiptAutoBookkeeper(
                    repository: environment.transactionRepository,
                    syncCoordinator: environment.syncCoordinator,
                    eventBus: environment.eventBus,
                    context: environment.context
                ),
                notificationCenter: .current()
            )
        } catch {
            fatalError("初始化自动记账管线失败：\(error.localizedDescription)")
        }
    }
}


