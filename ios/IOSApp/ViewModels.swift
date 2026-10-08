import Combine
import Foundation
import SwiftData
import SwiftUI

@MainActor
struct TransactionSyncCoordinator {
    let repository: TransactionRepository
    let service: BillSyncService
    let configuration: APIConfiguration

    func sync(transaction: Transaction) async throws -> ManualBillResponse {
        let response = try await service.sync(transaction: transaction, configuration: configuration)
        transaction.status = .ok
        transaction.cloudID = response.bill_id
        transaction.updatedAt = .now
        mergeTransactionMetadata(transaction, billID: response.bill_id)
        try await repository.updateTransaction(transaction)
        return response
    }

    func markPending(_ transaction: Transaction) async {
        transaction.status = .pending
        transaction.updatedAt = .now
        try? await repository.updateTransaction(transaction)
    }
}

fileprivate func mergeTransactionMetadata(_ transaction: Transaction, billID: String? = nil) {
    var metadata: [String: String] = [:]
    if let raw = transaction.rawJSON,
       let data = raw.data(using: .utf8),
       let object = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
        metadata = object
    }

    if let billID {
        metadata["bill_id"] = billID
    } else if metadata["bill_id"] == nil, let cloudID = transaction.cloudID {
        metadata["bill_id"] = cloudID
    }

    if let spendingType = transaction.spendingType {
        metadata["spending_type"] = spendingType.rawValue
    } else {
        metadata.removeValue(forKey: "spending_type")
    }

    if metadata.isEmpty {
        transaction.rawJSON = nil
    } else if let data = try? JSONSerialization.data(withJSONObject: metadata),
              let json = String(data: data, encoding: .utf8) {
        transaction.rawJSON = json
    }
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var greeting: String = DashboardViewModel.makeGreeting(for: .now)
    @Published private(set) var budgetSummary: BudgetSummary?
    @Published var isLoadingSummary: Bool = false
    @Published var draft: TransactionDraft = .empty()
    @Published var draftAmountText: String = ""
    @Published var draftDate: Date = .now
    @Published var draftNote: String = ""
    @Published var isAddSheetPresented: Bool = false
    @Published var isSubmitting: Bool = false
    @Published var infoMessage: String?
    @Published var errorMessage: String?
    @Published var recentlyAdded: Transaction?
    @Published private(set) var recognitionQueue: [PendingReceiptRecognition] = []
    @Published private(set) var isRecognitionProcessing: Bool = false
    @Published private(set) var recognitionLastErrorMessage: String?
    @Published var recognitionFlowSavingEnabled: Bool = false
    @Published private(set) var lastRecognitionResult: ReceiptRecognitionResult?
    @Published private(set) var recognitionHistory: [RecognizedReceiptHistory] = []

    private var greetingTimer: AnyCancellable?

    private let transactionRepository: TransactionRepository
    private let budgetService: BudgetService
    private let syncCoordinator: TransactionSyncCoordinator
    private let context: ModelContext
    private let eventBus: FinanceEventBus
    private let numberFormatter: NumberFormatter
    private let recognitionCoordinator: ReceiptRecognitionCoordinator
    private let recognitionPreferences: ReceiptRecognitionPreferences
    private let historyStore: ReceiptRecognitionHistoryStore
    private let autoBookkeeper: ReceiptAutoBookkeeper
    private let recognitionToken: String
    private var recognitionSubscriptions: Set<AnyCancellable> = []
    private let recognitionDateFormatter: DateFormatter
    private let recognitionISOFormatter: ISO8601DateFormatter
    private var currentUserID: String?
    private var lastRecognitionHistoryID: UUID?

    init(
        transactionRepository: TransactionRepository,
        budgetService: BudgetService,
        context: ModelContext,
        syncCoordinator: TransactionSyncCoordinator,
        eventBus: FinanceEventBus,
        recognitionCoordinator: ReceiptRecognitionCoordinator,
        recognitionPreferences: ReceiptRecognitionPreferences,
        historyStore: ReceiptRecognitionHistoryStore,
        currentUserID: String? = nil,
        recognitionToken: String
    ) {
        self.transactionRepository = transactionRepository
        self.budgetService = budgetService
        self.syncCoordinator = syncCoordinator
        self.context = context
        self.eventBus = eventBus
        self.recognitionCoordinator = recognitionCoordinator
        self.recognitionPreferences = recognitionPreferences
        self.historyStore = historyStore
        self.autoBookkeeper = ReceiptAutoBookkeeper(
            repository: transactionRepository,
            syncCoordinator: syncCoordinator,
            eventBus: eventBus,
            context: context
        )
        self.recognitionToken = recognitionToken
        self.recognitionDateFormatter = DashboardViewModel.makeRecognitionDateFormatter()
        self.recognitionISOFormatter = DashboardViewModel.makeRecognitionISOFormatter()
        self.currentUserID = currentUserID
        self.numberFormatter = FinanceFormatters.decimal
        self.recognitionFlowSavingEnabled = recognitionPreferences.flowSavingModeEnabled
        startGreetingTimer()
        setupRecognitionBindings()
        refreshRecognitionHistory()
        self.recognitionCoordinator.supplyToken(recognitionToken)
    }

    deinit {
        greetingTimer?.cancel()
        recognitionSubscriptions.forEach { $0.cancel() }
        recognitionSubscriptions.removeAll()
    }

    func startGreetingTimer() {
        greetingTimer?.cancel()
        greetingTimer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.greeting = DashboardViewModel.makeGreeting(for: .now)
            }
    }

    private func setupRecognitionBindings() {
        recognitionCoordinator.onSuccess = { [weak self] task, result in
            self?.handleRecognitionSuccess(task: task, result: result)
        }

        recognitionCoordinator.onFailure = { [weak self] task, error in
            self?.handleRecognitionFailure(task: task, error: error)
        }

        recognitionCoordinator.onHistoryChanged = { [weak self] in
            self?.refreshRecognitionHistory()
        }

        recognitionCoordinator.onHistoryAppended = { [weak self] history in
            self?.lastRecognitionHistoryID = history.id
        }

        recognitionCoordinator.$queue
            .receive(on: RunLoop.main)
            .sink { [weak self] queue in
                self?.recognitionQueue = queue
            }
            .store(in: &recognitionSubscriptions)

        recognitionCoordinator.$isProcessing
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.isRecognitionProcessing = value
            }
            .store(in: &recognitionSubscriptions)

        recognitionCoordinator.$lastError
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                guard let self else { return }
                if let error {
                    self.recognitionLastErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                } else {
                    self.recognitionLastErrorMessage = nil
                }
            }
            .store(in: &recognitionSubscriptions)

        recognitionPreferences.$flowSavingModeEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.recognitionFlowSavingEnabled = enabled
            }
            .store(in: &recognitionSubscriptions)
    }

    private static func makeRecognitionDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static func makeRecognitionISOFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withFullDate]
        return formatter
    }

    func loadSummary() {
        isLoadingSummary = true
        defer { isLoadingSummary = false }

        do {
            let today = Date()
            let spent = try calculateMonthlySpending(containing: today)
            let calendar = Calendar.current
            guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
                  let startOfNextMonth = calendar.date(byAdding: DateComponents(month: 1), to: startOfMonth) else {
                throw SummaryComputationError.invalidDateRange
            }

            let daysLeft = max(calendar.dateComponents([.day], from: today, to: startOfNextMonth).day ?? 0, 0)
            let activePlan = try? budgetService.activePlan()
            let totalBudget = activePlan?.totalLimit
            let total = totalBudget ?? spent
            let remaining = totalBudget.map { max($0 - spent, 0) } ?? .zero

            let summary = BudgetSummary(
                total: total,
                spent: spent,
                remaining: remaining,
                daysLeft: daysLeft,
                period: .monthly,
                hasBudgetPlan: totalBudget != nil
            )

            budgetSummary = summary
            eventBus.send(.budgetSummaryUpdated(summary))
        } catch {
            errorMessage = "预算加载失败：\(error.localizedDescription)"
            eventBus.send(.budgetSummaryUpdated(nil))
        }
    }

    private enum SummaryComputationError: Error {
        case invalidDateRange
    }

    private func calculateMonthlySpending(containing date: Date) throws -> Decimal {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
              let startOfNextMonth = calendar.date(byAdding: DateComponents(month: 1), to: startOfMonth) else {
            throw SummaryComputationError.invalidDateRange
        }

        let start = startOfMonth
        let end = startOfNextMonth
        let predicate = #Predicate<Transaction> { transaction in
            transaction.occurredAt >= start && transaction.occurredAt < end
        }

        let descriptor = FetchDescriptor<Transaction>(predicate: predicate)

        let allowedStatuses: Set<TransactionStatus> = [.pending, .ok, .default]
        let transactions = try context.fetch(descriptor)
            .filter { transaction in
                transaction.type == .expense && allowedStatuses.contains(transaction.status)
            }
        return transactions.reduce(Decimal.zero) { $0 + $1.amount }
    }

    func resetDraft() {
        draft = .empty()
        draftAmountText = ""
        draftDate = .now
        draftNote = ""
        draft.spendingType = nil
        errorMessage = nil
        infoMessage = nil
        lastRecognitionHistoryID = nil
    }

    func updateRecognitionUserID(_ userID: String?) {
        currentUserID = userID
    }

    func enqueueReceiptImage(_ imageData: Data, billID: String = UUID().uuidString) {
        do {
            let pending = try recognitionCoordinator.enqueue(
                imageData: imageData,
                billID: billID,
                userID: currentUserID,
                token: recognitionToken
            )
            errorMessage = nil
            infoMessage = "识别任务已加入队列（编号：\(pending.billID)）。"
        } catch {
            errorMessage = "加入识别队列失败：\(error.localizedDescription)"
        }
    }

    func retryRecognitionTask(_ task: PendingReceiptRecognition) {
        recognitionCoordinator.retry(task)
    }

    func cancelRecognitionTask(_ task: PendingReceiptRecognition) {
        recognitionCoordinator.cancel(task)
    }

    func refreshRecognitionQueue() {
        recognitionCoordinator.refresh()
    }

    func toggleRecognitionFlowSavingMode() {
        recognitionPreferences.toggleFlowSavingMode()
    }

    func setRecognitionFlowSavingMode(_ enabled: Bool) {
        recognitionPreferences.setFlowSavingMode(enabled)
    }

    func setSpendingType(_ type: SpendingType?) {
        draft.spendingType = type
    }

    func refreshRecognitionHistory(limit: Int = 50) {
        do {
            recognitionHistory = try historyStore.fetchRecent(limit: limit)
        } catch {
            recognitionLastErrorMessage = error.localizedDescription
        }
    }

    func deleteHistoryItem(_ item: RecognizedReceiptHistory) {
        do {
            try historyStore.delete(item)
            refreshRecognitionHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func showRecognitionPlaceholder() {
        infoMessage = "点击添加图片或拍照，即可自动识别账单信息。"
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if infoMessage?.contains("识别") == true {
                infoMessage = nil
            }
        }
    }

    func submitDraft() async {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "请输入名称"
            return
        }

        let sanitizedAmount = draftAmountText
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let amount = Decimal(string: sanitizedAmount), amount > .zero else {
            errorMessage = "请输入有效金额"
            return
        }

        guard draft.categoryID != nil else {
            errorMessage = "请选择分类"
            return
        }

        if draft.type == .expense {
            guard draft.spendingType != nil else {
                errorMessage = "请选择支出类型"
                return
            }
        } else {
            draft.spendingType = nil
        }

        let trimmedNote = draftNote.trimmingCharacters(in: .whitespacesAndNewlines)

        draft.name = trimmedName
        draft.amount = amount
        draft.occurredAt = draftDate
        draft.note = trimmedNote.isEmpty ? nil : trimmedNote

        do {
            errorMessage = nil
            infoMessage = nil
            isSubmitting = true
            let transaction = try await transactionRepository.addTransaction(from: draft)
            recentlyAdded = transaction
            do {
                if let historyID = lastRecognitionHistoryID {
                    try historyStore.markApplied(historyID: historyID, transactionID: transaction.id)
                    lastRecognitionHistoryID = nil
                    refreshRecognitionHistory()
                }
            } catch {
                // 记录但不中断提交流程
                recognitionLastErrorMessage = error.localizedDescription
            }
            loadSummary()
            resetDraft()
            isAddSheetPresented = false
            eventBus.send(.transactionsChanged(source: .dashboard))
            Task {
                await syncTransaction(transaction)
            }
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }

        isSubmitting = false
    }

    private func syncTransaction(_ transaction: Transaction) async {
        do {
            let response = try await syncCoordinator.sync(transaction: transaction)
            await MainActor.run {
                infoMessage = response.message
                eventBus.send(.transactionsChanged(source: .sync))
            }
        } catch {
            await syncCoordinator.markPending(transaction)
            await MainActor.run {
                errorMessage = error.localizedDescription
                eventBus.send(.transactionsChanged(source: .sync))
            }
        }
    }

    func categoryOptions(for type: TransactionType) -> [CategoryOption] {
        let descriptor = FetchDescriptor<TransactionCategory>()

        let categories = (try? context.fetch(descriptor)) ?? []
        let kind: CategoryKind = (type == .expense) ? .expense : .income
        return categories
            .filter { $0.kind == kind }
            .sorted { lhs, rhs in
                CategoryDefinitions.orderIndex(for: lhs.name, kind: kind) <
                CategoryDefinitions.orderIndex(for: rhs.name, kind: kind)
            }
            .map(CategoryOption.init)
    }

    func selectCategory(_ id: UUID) {
        draft.categoryID = id
    }

    func isCategorySelected(_ id: UUID) -> Bool {
        draft.categoryID == id
    }

    func updateType(_ type: TransactionType) {
        draft.type = type
        draft.categoryID = nil
        if type == .income {
            draft.spendingType = nil
        }
    }

    func decimalString(_ value: Decimal) -> String {
        numberFormatter.string(from: NSDecimalNumber(decimal: value)) ?? value.description
    }

    private static func makeGreeting(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5 ..< 12:
            return "早上好"
        case 12 ..< 14:
            return "中午好"
        case 14 ..< 18:
            return "下午好"
        default:
            return "晚上好"
        }
    }

    private func handleRecognitionSuccess(task: PendingReceiptRecognition, result: ReceiptRecognitionResult) {
        lastRecognitionResult = result
        errorMessage = nil
        infoMessage = "识别成功，正在自动记账…"

        Task { [weak self] in
            guard let self else { return }
            do {
                let transaction = try await self.autoBookkeeper.persist(result: result, billID: task.billID)
                await MainActor.run {
                    self.recentlyAdded = transaction
                    self.infoMessage = "识别成功，已自动记账。"
                    self.loadSummary()
                    self.markRecognitionHistoryApplied(with: transaction.id)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "自动记账失败：\(error.localizedDescription)"
                    self.infoMessage = "已将识别结果填入草稿，请确认后保存。"
                    self.applyRecognitionResult(result)
                    if !self.isAddSheetPresented {
                        self.isAddSheetPresented = true
                    }
                }
            }
        }
    }

    private func handleRecognitionFailure(task: PendingReceiptRecognition, error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        recognitionLastErrorMessage = message
        errorMessage = message
    }

    private func applyRecognitionResult(_ result: ReceiptRecognitionResult) {
        var updatedDraft = draft
        updatedDraft.type = .expense
        updatedDraft.name = resolvedDraftName(for: result)
        let normalizedAmount = result.amount.magnitude
        updatedDraft.amount = normalizedAmount
        updatedDraft.occurredAt = parseRecognitionDate(result.date) ?? .now
        if !result.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updatedDraft.note = result.description
        }
        updatedDraft.categoryID = categoryID(matching: result.category)
        updatedDraft.spendingType = result.spendingCategoryName.flatMap(SpendingType.init(rawValue:))
        draft = updatedDraft
        draftAmountText = decimalString(normalizedAmount)
        draftDate = updatedDraft.occurredAt
        draftNote = updatedDraft.note ?? ""
    }

    private func parseRecognitionDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let date = recognitionDateFormatter.date(from: trimmed) {
            return date
        }
        return recognitionISOFormatter.date(from: trimmed)
    }

    private func resolvedDraftName(for result: ReceiptRecognitionResult) -> String {
        let description = result.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty {
            return description
        }
        let categoryName = result.category.trimmingCharacters(in: .whitespacesAndNewlines)
        if !categoryName.isEmpty {
            return categoryName
        }
        return "识别账单"
    }

    private func categoryID(matching name: String) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let descriptor = FetchDescriptor<TransactionCategory>(
            predicate: #Predicate<TransactionCategory> { category in
                category.name == trimmed
            }
        )
        return try? context.fetch(descriptor).first?.id
    }

    func clearRecognitionResult() {
        lastRecognitionResult = nil
    }

    private func markRecognitionHistoryApplied(with transactionID: UUID) {
        guard let historyID = lastRecognitionHistoryID else { return }
        do {
            try historyStore.markApplied(historyID: historyID, transactionID: transactionID)
            lastRecognitionHistoryID = nil
            refreshRecognitionHistory()
        } catch {
            recognitionLastErrorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class TransactionsViewModel: ObservableObject {
    @Published private(set) var sections: [TransactionSection] = []
    @Published var selectedTransaction: Transaction?
    @Published var isPresentingEditor: Bool = false
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var isDeleting: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var editorState: EditorState?
    var reloadSummary: (() -> Void)?
    var syncFeedback: ((Result<String, Error>) -> Void)?

    private let repository: TransactionRepository
    private let context: ModelContext
    private let syncCoordinator: TransactionSyncCoordinator
    private let eventBus: FinanceEventBus
    private let numberFormatter = FinanceFormatters.decimal
    private var cancellables: Set<AnyCancellable> = []

    struct EditorState: Identifiable {
        let id: UUID
        let transaction: Transaction
        var name: String
        var amountText: String
        var type: TransactionType
        var categoryID: UUID?
        var date: Date
        var note: String
        var spendingType: SpendingType?

        init(transaction: Transaction, amountFormatter: NumberFormatter) {
            self.id = transaction.id
            self.transaction = transaction
            self.name = transaction.name
            self.amountText = amountFormatter.string(from: NSDecimalNumber(decimal: transaction.amount)) ?? ""
            self.type = transaction.type
            self.categoryID = transaction.category?.id
            self.date = transaction.occurredAt
            self.note = transaction.note ?? ""
            self.spendingType = transaction.spendingType
        }
    }

    init(
        repository: TransactionRepository,
        context: ModelContext,
        syncCoordinator: TransactionSyncCoordinator,
        eventBus: FinanceEventBus
    ) {
        self.repository = repository
        self.context = context
        self.syncCoordinator = syncCoordinator
        self.eventBus = eventBus
        observeEvents()
    }

    func load(range: DateInterval? = nil) {
        isLoading = true
        do {
            sections = try repository.fetchSections(in: range)
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
        isLoading = false
    }

    private func observeEvents() {
        eventBus.publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                self?.handle(event)
            }
            .store(in: &cancellables)
    }

    private func handle(_ event: FinanceEventBus.Event) {
        switch event {
        case .transactionsChanged:
            guard !isLoading else { return }
            load()
        case .budgetSummaryUpdated,
             .goalsChanged,
             .userProfileUpdated:
            break
        }
    }

    func selectTransaction(_ transaction: Transaction) {
        selectedTransaction = transaction
        isPresentingEditor = true
    }

    func beginEditing(_ transaction: Transaction) {
        editorState = EditorState(transaction: transaction, amountFormatter: numberFormatter)
        isPresentingEditor = true
        errorMessage = nil
    }

    func cancelEditing() {
        isPresentingEditor = false
        editorState = nil
        errorMessage = nil
    }

    private func updateEditor(_ update: (inout EditorState) -> Void) {
        guard var state = editorState else { return }
        update(&state)
        editorState = state
    }

    func updateEditorName(_ value: String) {
        updateEditor { $0.name = value }
    }

    func updateEditorAmount(_ value: String) {
        updateEditor { $0.amountText = value }
    }

    func updateEditorType(_ type: TransactionType) {
        updateEditor {
            $0.type = type
            $0.categoryID = nil
            if type == .income {
                $0.spendingType = nil
            }
        }
    }

    func updateEditorSpendingType(_ type: SpendingType?) {
        updateEditor { $0.spendingType = type }
    }

    func updateEditorDate(_ date: Date) {
        updateEditor { $0.date = date }
    }

    func updateEditorNote(_ value: String) {
        updateEditor { $0.note = value }
    }

    func selectEditorCategory(_ id: UUID) {
        updateEditor { $0.categoryID = id }
    }

    func isEditorCategorySelected(_ id: UUID) -> Bool {
        editorState?.categoryID == id
    }

    func categoryOptions(for type: TransactionType) -> [CategoryOption] {
        let descriptor = FetchDescriptor<TransactionCategory>()

        let categories = (try? context.fetch(descriptor)) ?? []
        let kind: CategoryKind = (type == .expense) ? .expense : .income
        return categories
            .filter { $0.kind == kind }
            .sorted { lhs, rhs in
                CategoryDefinitions.orderIndex(for: lhs.name, kind: kind) <
                CategoryDefinitions.orderIndex(for: rhs.name, kind: kind)
            }
            .map(CategoryOption.init)
    }

    func saveEditor() async {
        guard let state = editorState else { return }

        let trimmedName = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "请输入名称"
            return
        }

        let sanitizedAmount = state.amountText
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let amount = Decimal(string: sanitizedAmount), amount > .zero else {
            errorMessage = "请输入有效金额"
            return
        }

        if state.type == .expense {
            guard state.categoryID != nil else {
                errorMessage = "请选择分类"
                return
            }

            guard state.spendingType != nil else {
                errorMessage = "请选择支出类型"
                return
            }
        }

        guard let transaction = editorState?.transaction else {
            errorMessage = "未找到交易记录"
            return
        }

        let trimmedNote = state.note.trimmingCharacters(in: .whitespacesAndNewlines)

        transaction.name = trimmedName
        transaction.type = state.type
        transaction.amount = amount
        transaction.occurredAt = state.date
        transaction.note = trimmedNote.isEmpty ? nil : trimmedNote
        transaction.status = state.type == .expense ? .pending : .ok

        if let categoryID = state.categoryID {
            let descriptor = FetchDescriptor<TransactionCategory>(
                predicate: #Predicate<TransactionCategory> { category in
                    category.id == categoryID
                }
            )
            transaction.category = try? context.fetch(descriptor).first
        } else {
            transaction.category = nil
        }

        transaction.spendingType = (state.type == .expense) ? state.spendingType : nil
        mergeTransactionMetadata(transaction)

        do {
            isSaving = true
            errorMessage = nil
            try await repository.updateTransaction(transaction)
            editorState = nil
            isPresentingEditor = false
            sections = try repository.fetchSections(in: nil)
            reloadSummary?()
            eventBus.send(.transactionsChanged(source: .transactions))
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }

        isSaving = false

        Task { [weak self, weak transaction] in
            guard let self, let transaction else { return }
            await self.syncTransaction(transaction)
        }
    }

    func deleteCurrent() {
        guard let transaction = editorState?.transaction else { return }
        do {
            isDeleting = true
            errorMessage = nil
            try repository.deleteTransaction(transaction)
            editorState = nil
            isPresentingEditor = false
            sections = try repository.fetchSections(in: nil)
            reloadSummary?()
            eventBus.send(.transactionsChanged(source: .transactions))
            syncFeedback?(.success("本地已删除账单（云端接口待提供）"))
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
            syncFeedback?(.failure(error))
        }
        isDeleting = false
    }

    func deleteSelected() {
        guard let transaction = selectedTransaction else { return }
        do {
            try repository.deleteTransaction(transaction)
            selectedTransaction = nil
            sections = try repository.fetchSections(in: nil)
            eventBus.send(.transactionsChanged(source: .transactions))
            syncFeedback?(.success("本地已删除账单（云端接口待提供）"))
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
            syncFeedback?(.failure(error))
        }
    }

    func saveChanges() async {
        guard let transaction = selectedTransaction else { return }
        do {
            try await repository.updateTransaction(transaction)
            sections = try repository.fetchSections(in: nil)
            isPresentingEditor = false
            reloadSummary?()
            eventBus.send(.transactionsChanged(source: .transactions))
            await syncTransaction(transaction)
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    func categories(kind: CategoryKind? = nil) -> [TransactionCategory] {
        let descriptor = FetchDescriptor<TransactionCategory>()

        let categories = (try? context.fetch(descriptor)) ?? []
        guard let kind else { return categories }
        return categories
            .filter { $0.kind == kind }
            .sorted {
                CategoryDefinitions.orderIndex(for: $0.name, kind: kind) <
                CategoryDefinitions.orderIndex(for: $1.name, kind: kind)
            }
    }

    private func syncTransaction(_ transaction: Transaction) async {
        do {
            let response = try await syncCoordinator.sync(transaction: transaction)
            await MainActor.run {
                syncFeedback?(.success(response.message))
                eventBus.send(.transactionsChanged(source: .sync))
            }
        } catch {
            await syncCoordinator.markPending(transaction)
            await MainActor.run {
                errorMessage = "云端同步失败：\(error.localizedDescription)"
                syncFeedback?(.failure(error))
                eventBus.send(.transactionsChanged(source: .sync))
            }
        }
    }
}

enum StatisticsViewMode {
    case monthly
    case yearly
}

@MainActor
final class StatisticsViewModel: ObservableObject {
    struct TrendDatum: Identifiable, Hashable {
        enum Series: String, CaseIterable {
            case expense = "支出"
            case income = "收入"
        }

        let id = UUID()
        let label: String
        let series: Series
        let value: Double
    }

    struct Overview {
        let totalIncome: Decimal
        let totalExpense: Decimal

        var net: Decimal {
            totalIncome - totalExpense
        }
    }

    @Published private(set) var summaries: [StatisticSnapshot] = []
    @Published private(set) var categorySummaries: [CategorySummary] = []
    @Published private(set) var trendData: [TrendDatum] = []
    @Published private(set) var overview: Overview = Overview(totalIncome: .zero, totalExpense: .zero)
    @Published private(set) var goalComparisons: [GoalComparisonSnapshot] = []
    @Published private(set) var availableYears: [Int] = []
    @Published var selectedYear: Int
    @Published var yearlyLimit: Int
    @Published var categoryKind: CategoryKind = .expense
    @Published var mode: StatisticsViewMode
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let service: StatisticsService
    private let eventBus: FinanceEventBus
    private var cancellables: Set<AnyCancellable> = []
    let yearlyOptions: [Int] = [3, 5, 7]

    init(
        service: StatisticsService,
        eventBus: FinanceEventBus,
        initialMode: StatisticsViewMode? = nil
    ) {
        self.service = service
        self.eventBus = eventBus
        let currentYear = Calendar.current.component(.year, from: .now)
        let fetchedYears = (try? service.availableYears()) ?? [currentYear]
        let resolvedYears = fetchedYears.isEmpty ? [currentYear] : fetchedYears
        self.availableYears = resolvedYears
        self.selectedYear = resolvedYears.last ?? currentYear
        self.yearlyLimit = yearlyOptions.first ?? 3
        self.mode = initialMode ?? .monthly
        observeEvents()
    }

    var isMonthlyMode: Bool {
        mode == .monthly
    }

    var isYearlyMode: Bool {
        mode == .yearly
    }

    var hasContent: Bool {
        trendData.contains { $0.value > 0 }
    }

    func load() {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let years = try service.availableYears()
            if !years.isEmpty {
                availableYears = years
                if !availableYears.contains(selectedYear) {
                    selectedYear = availableYears.last ?? selectedYear
                }
            }

            let snapshots = try fetchSnapshots(for: mode)
            summaries = snapshots
            trendData = makeTrendData(from: snapshots)
            overview = makeOverview(from: snapshots)
            categorySummaries = try service.categorySummaries(
                kind: categoryKind,
                in: nil
            )
            goalComparisons = try service.goalComparisons()
        } catch {
            errorMessage = "加载统计失败：\(error.localizedDescription)"
            summaries = []
            trendData = []
            overview = Overview(totalIncome: .zero, totalExpense: .zero)
            categorySummaries = []
            goalComparisons = []
        }
    }

    func select(kind: CategoryKind) {
        categoryKind = kind
        reloadCategories()
    }

    func select(mode: StatisticsViewMode) {
        self.mode = mode
        load()
    }

    func selectMonthly() {
        mode = .monthly
        load()
    }

    func selectYearly() {
        mode = .yearly
        load()
    }

    func updateYearlyLimit(to limit: Int) {
        guard yearlyLimit != limit else { return }
        yearlyLimit = limit
        if isYearlyMode {
            load()
        }
    }

    private func reloadCategories() {
        do {
            categorySummaries = try service.categorySummaries(
                kind: categoryKind,
                in: nil
            )
        } catch {
            errorMessage = "加载分类失败：\(error.localizedDescription)"
        }
    }

    private func fetchSnapshots(for mode: StatisticsViewMode) throws -> [StatisticSnapshot] {
        switch mode {
        case .monthly:
            return try service.monthlySnapshots(for: selectedYear)
        case .yearly:
            return try service.yearlySnapshots(limit: yearlyLimit)
        }
    }

    private func makeTrendData(from snapshots: [StatisticSnapshot]) -> [TrendDatum] {
        snapshots.flatMap { snapshot in
            [
                TrendDatum(
                    label: snapshot.label,
                    series: .expense,
                    value: snapshot.expense.asDouble
                ),
                TrendDatum(
                    label: snapshot.label,
                    series: .income,
                    value: snapshot.income.asDouble
                )
            ]
        }
    }

    private func makeOverview(from snapshots: [StatisticSnapshot]) -> Overview {
        let income = snapshots.reduce(Decimal.zero) { $0 + $1.income }
        let expense = snapshots.reduce(Decimal.zero) { $0 + $1.expense }
        return Overview(totalIncome: income, totalExpense: expense)
    }

    private func observeEvents() {
        eventBus.publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                self?.handle(event)
            }
            .store(in: &cancellables)
    }

    private func handle(_ event: FinanceEventBus.Event) {
        switch event {
        case .transactionsChanged:
            guard !isLoading else { return }
            load()
        case .budgetSummaryUpdated:
            break
        case .goalsChanged:
            break
        case .userProfileUpdated:
            break
        }
    }
}

// MARK: - Goals

extension GoalSyncPayload.GoalType {
    var displayName: String {
        switch self {
        case .saving: return "攒钱"
        case .investment: return "理财"
        case .debt: return "贷款"
        }
    }
}

extension GoalSyncPayload.GoalType: CaseIterable {
    static let allCases: [GoalSyncPayload.GoalType] = [.saving, .investment, .debt]
}

struct GoalItem: Identifiable {
    let id: UUID
    let title: String
    let targetAmount: Decimal
    let currentAmount: Decimal
    let deadline: Date
    let category: String
    let type: GoalSyncPayload.GoalType

    init(payload: GoalSyncPayload) {
        id = payload.id
        title = payload.title
        targetAmount = payload.targetAmount
        currentAmount = payload.currentAmount
        deadline = payload.deadline
        category = payload.category
        type = payload.type
    }

    var progress: Double {
        guard targetAmount > .zero else { return 0 }
        let ratio = (currentAmount / targetAmount).asDouble
        return min(max(ratio, 0), 1)
    }

    var remainingAmount: Decimal {
        max(targetAmount - currentAmount, 0)
    }

    var daysLeft: Int {
        let today = Calendar.current.startOfDay(for: .now)
        let targetDay = Calendar.current.startOfDay(for: deadline)
        let components = Calendar.current.dateComponents([.day], from: today, to: targetDay)
        return max(components.day ?? 0, 0)
    }
}

struct GoalDraft {
    var title: String = ""
    var targetAmountText: String = ""
    var deadline: Date = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
    var category: String = ""
    var type: GoalSyncPayload.GoalType = .saving

    mutating func reset() {
        title = ""
        targetAmountText = ""
        deadline = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
        category = ""
        type = .saving
    }
}

@MainActor
final class GoalsViewModel: ObservableObject {
    @Published private(set) var goals: [GoalItem] = []
    @Published var monthlyBudget: Decimal = 4_000
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let service: GoalSyncService
    private let eventBus: FinanceEventBus
    private var cancellables: Set<AnyCancellable> = []

    init(service: GoalSyncService, eventBus: FinanceEventBus) {
        self.service = service
        self.eventBus = eventBus
        observeEvents()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let payloads = try await service.fetchGoals()
            goals = payloads.map(GoalItem.init)
            errorMessage = nil
            eventBus.send(.goalsChanged(source: .goals))
        } catch {
            errorMessage = "加载目标失败：\(error.localizedDescription)"
        }
    }

    func addGoal(from draft: GoalDraft) async -> Bool {
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "请填写目标名称"
            return false
        }

        let sanitizedAmount = draft.targetAmountText.replacingOccurrences(of: ",", with: "")
        guard let target = Decimal(string: sanitizedAmount), target > .zero else {
            errorMessage = "请输入有效的目标金额"
            return false
        }

        let category = draft.category.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let payload = GoalSyncPayload(
                id: UUID(),
                title: trimmedTitle,
                targetAmount: target,
                currentAmount: .zero,
                deadline: draft.deadline,
                category: category.isEmpty ? "未分类" : category,
                type: draft.type
            )
            try await service.upsertGoal(payload)
            goals.append(GoalItem(payload: payload))
            errorMessage = nil
            eventBus.send(.goalsChanged(source: .goals))
            return true
        } catch {
            errorMessage = "保存目标失败：\(error.localizedDescription)"
            return false
        }
    }

    func updateMonthlyBudget(to amount: Decimal) {
        monthlyBudget = max(amount, .zero)
        eventBus.send(.goalsChanged(source: .goals))
    }

    func goals(for type: GoalSyncPayload.GoalType) -> [GoalItem] {
        goals
            .filter { $0.type == type }
            .sorted { $0.deadline < $1.deadline }
    }

    var activeGoalCount: Int {
        goals.count
    }

    var totalTargetAmount: Decimal {
        goals.reduce(.zero) { $0 + $1.targetAmount }
    }

    var totalCurrentAmount: Decimal {
        goals.reduce(.zero) { $0 + $1.currentAmount }
    }

    private func observeEvents() {
        eventBus.publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                self?.handle(event)
            }
            .store(in: &cancellables)
    }

    private func handle(_ event: FinanceEventBus.Event) {
        switch event {
        case .transactionsChanged:
            guard !isLoading else { return }
            Task { [weak self] in
                guard let self else { return }
                await self.refresh()
            }
        case .budgetSummaryUpdated:
            break
        case .goalsChanged:
            break
        case .userProfileUpdated:
            break
        }
    }
}

// MARK: - AI Chat

struct ChatMessage: Identifiable {
    enum Role {
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

    var asAIMessage: AIChatMessage {
        AIChatMessage(
            id: id,
            role: role == .user ? .user : .assistant,
            content: content,
            createdAt: createdAt
        )
    }
}

struct QuickPrompt: Identifiable {
    let id = UUID()
    let iconName: String
    let title: String
    let tint: Color
    let prompt: String
}

enum AIPersonality: String, CaseIterable {
    case professional
    case friendly
    case motivational
    case humorous

    var displayName: String {
        switch self {
        case .professional: return "专业理财师"
        case .friendly: return "贴心朋友"
        case .motivational: return "励志教练"
        case .humorous: return "幽默顾问"
        }
    }

    var description: String {
        switch self {
        case .professional: return "严谨专业，数据驱动"
        case .friendly: return "温暖亲切，通俗易懂"
        case .motivational: return "积极鼓励，充满活力"
        case .humorous: return "轻松幽默，寓教于乐"
        }
    }

    func template(for prompt: String) -> String {
        switch self {
        case .professional:
            return "针对“\(prompt)”的情况，建议：1）优化相关支出，预计可节省 15%-20%；2）建立 3-6 个月生活费的紧急备用金；3）考虑定投优质指数基金，目标年化 8%-12%。"
        case .friendly:
            return "这个问题问得真好！围绕“\(prompt)”我们可以定个小计划，每月固定存一点备用金，一年下来就有惊喜。保持节奏，你一定行的 😊"
        case .motivational:
            return "太棒了！你已经在“\(prompt)”上迈出关键一步！💪 我们立刻制定一个 mini 目标，坚持下去，很快就能看到成果！"
        case .humorous:
            return "哈哈，关于“\(prompt)”的问题，让我这个‘钱包守护神’来支招！先把那些小漏洞补好，让钱包重新鼓起来！😄"
        }
    }
}

enum AIVoice: String, CaseIterable {
    case female1
    case female2
    case male1
    case male2

    var displayName: String {
        switch self {
        case .female1: return "女声 - 温柔"
        case .female2: return "女声 - 活力"
        case .male1: return "男声 - 沉稳"
        case .male2: return "男声 - 年轻"
        }
    }
}

struct CustomPersona: Identifiable, Codable {
    let id: UUID
    var name: String
    var toneKeywords: String
    var guidance: String

    init(id: UUID = UUID(), name: String, toneKeywords: String, guidance: String) {
        self.id = id
        self.name = name
        self.toneKeywords = toneKeywords
        self.guidance = guidance
    }

    var summary: String {
        "\(name) · \(toneKeywords)"
    }

    func response(for prompt: String) -> String {
        """
        \(name)（\(toneKeywords)）针对“\(prompt)”的建议：
        \(guidance)
        """
    }
}

struct CustomPersonaDraft {
    var name: String = ""
    var toneKeywords: String = ""
    var guidance: String = ""

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !toneKeywords.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !guidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct ClonedVoiceProfile {
    var name: String
    var createdAt: Date

    var subtitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "生成于 \(formatter.string(from: createdAt))"
    }
}

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage]
    @Published var input: String = ""
    @Published var selectedPersonality: AIPersonality = .friendly
    @Published var selectedVoice: AIVoice = .female1
    @Published var voiceEnabled: Bool = false
    @Published var isSettingsPresented: Bool = false
    @Published var isSending: Bool = false
    @Published var errorMessage: String?
    @Published var useCustomPersona: Bool = false
    @Published var customPersona: CustomPersona?
    @Published var isCustomPersonaEditorPresented: Bool = false
    @Published var personaDraft: CustomPersonaDraft = .init()
    @Published var clonedVoice: ClonedVoiceProfile?
    @Published var useClonedVoice: Bool = false
    @Published var isVoiceCloneSheetPresented: Bool = false
    @Published var isCloningVoice: Bool = false
    @Published var voiceCloneProgress: Double = 0
    @Published var voiceCloneErrorMessage: String?

    let quickPrompts: [QuickPrompt] = [
        QuickPrompt(iconName: "lightbulb.fill", title: "预算建议", tint: Color(hex: "#6366F1") ?? .indigo, prompt: "如何制定月度预算？"),
        QuickPrompt(iconName: "chart.xyaxis.line", title: "消费分析", tint: Color(hex: "#22C55E") ?? .green, prompt: "分析我的消费习惯"),
        QuickPrompt(iconName: "banknote.fill", title: "储蓄建议", tint: Color(hex: "#F59E0B") ?? .orange, prompt: "给我一些储蓄建议")
    ]

    private let service: AIChatService

    init(service: AIChatService) {
        self.service = service
        self.messages = [
            ChatMessage(
                role: .assistant,
                content: "嗨小王！看到你新买了一个耳机🎧，好漂亮呢！😍但是的确有点超出预算啦，不过你别担心，我已经给你更新了新的预算规划，接下来要努力按照我们的规划执行哦💪"
            )
        ]
    }

    var personaDisplayName: String {
        if useCustomPersona, let persona = customPersona {
            return persona.name
        }
        return selectedPersonality.displayName
    }

    var personaSubtitle: String {
        if useCustomPersona, let persona = customPersona {
            return persona.toneKeywords
        }
        return selectedPersonality.description
    }

    var clonedVoiceSummary: String {
        if let profile = clonedVoice {
            return profile.name
        }
        return "尚未克隆"
    }

    func handleQuickPrompt(_ prompt: QuickPrompt) {
        input = prompt.prompt
    }

    func send() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: trimmed)
        messages.append(userMessage)
        input = ""
        Task { await respond(to: trimmed) }
    }

    func injectAssistantBroadcast(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(role: .assistant, content: trimmed))
    }

    private func respond(to prompt: String) async {
        isSending = true
        defer { isSending = false }
        do {
            _ = try await service.respond(to: messages.map { $0.asAIMessage })
            try await Task.sleep(nanoseconds: 200_000_000)
            let reply = activeResponse(for: prompt)
            messages.append(ChatMessage(role: .assistant, content: reply))
            if voiceEnabled {
                let voiceLabel: String
                if useClonedVoice, let profile = clonedVoice {
                    voiceLabel = profile.name
                } else {
                    voiceLabel = selectedVoice.displayName
                }
                print("🔊 模拟语音播报（\(voiceLabel)）：\(reply)")
            }
            errorMessage = nil
        } catch {
            errorMessage = "助手暂时无法回复，请稍后再试。"
        }
    }

    func saveCustomPersonaDraft(_ draft: CustomPersonaDraft) -> Bool {
        guard draft.isValid else {
            return false
        }
        customPersona = CustomPersona(
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            toneKeywords: draft.toneKeywords.trimmingCharacters(in: .whitespacesAndNewlines),
            guidance: draft.guidance.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        useCustomPersona = true
        personaDraft = draft
        return true
    }

    func clearCustomPersona() {
        customPersona = nil
        useCustomPersona = false
        personaDraft = CustomPersonaDraft()
    }

    private func activeResponse(for prompt: String) -> String {
        if useCustomPersona, let persona = customPersona {
            return persona.response(for: prompt)
        }
        return selectedPersonality.template(for: prompt)
    }

    func beginVoiceCloneSimulation() {
        guard !isCloningVoice else { return }
        voiceCloneErrorMessage = nil
        isCloningVoice = true
        voiceCloneProgress = 0

        Task {
            for step in 1...5 {
                try await Task.sleep(nanoseconds: 400_000_000)
                await MainActor.run {
                    self.voiceCloneProgress = Double(step) / 5.0
                }
            }
            await MainActor.run {
                self.isCloningVoice = false
                let profile = ClonedVoiceProfile(name: "我的专属音色", createdAt: .now)
                self.clonedVoice = profile
                self.useClonedVoice = true
            }
        }
    }

    func resetClonedVoice() {
        clonedVoice = nil
        useClonedVoice = false
        voiceCloneProgress = 0
        isCloningVoice = false
        voiceCloneErrorMessage = nil
    }
}

struct AchievementDetailItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let reward: String
    let iconName: String
    let colorHex: String
    let isUnlocked: Bool
    let progress: Double
    let maxProgress: Double

    var progressPercent: Double {
        guard maxProgress > 0 else { return 0 }
        return min(max(progress / maxProgress, 0), 1)
    }

    var color: Color {
        Color(hex: colorHex) ?? .accentColor
    }
}

@MainActor
final class AchievementsViewModel: ObservableObject {
    @Published private(set) var badges: [String] = []
    @Published private(set) var streakDays: Int = 0
    @Published private(set) var achievements: [AchievementDetailItem] = []

    var unlockedAchievements: [AchievementDetailItem] {
        achievements.filter { $0.isUnlocked }
    }

    var lockedAchievements: [AchievementDetailItem] {
        achievements.filter { !$0.isUnlocked }
    }

    var unlockedCount: Int {
        unlockedAchievements.count
    }

    var totalCount: Int {
        achievements.count
    }

    var progressPercent: Double {
        guard totalCount > 0 else { return 0 }
        return Double(unlockedCount) / Double(totalCount)
    }

    private let repository: TransactionRepository
    private let goalService: GoalSyncService
    private let eventBus: FinanceEventBus
    private var cancellables: Set<AnyCancellable> = []

    private let achievementDefinitions: [AchievementDefinition] = [
        AchievementDefinition(
            id: "streak-7",
            title: "记账新手",
            description: "连续记账 7 天",
            reward: "解锁自定义主题",
            iconName: "calendar.badge.plus",
            colorHex: "#22C55E",
            maxProgress: 7,
            progressProvider: { context in Double(context.streakDays) }
        ),
        AchievementDefinition(
            id: "budget-streak",
            title: "预算达人",
            description: "连续 3 个月收支保持平衡",
            reward: "获得 AI 高级分析",
            iconName: "target",
            colorHex: "#3B82F6",
            maxProgress: 3,
            progressProvider: { context in Double(context.positiveBudgetStreak) }
        ),
        AchievementDefinition(
            id: "saving-star",
            title: "节约之星",
            description: "最近一个月支出较上月下降 20%",
            reward: "解锁专属徽章",
            iconName: "arrow.down.right",
            colorHex: "#8B5CF6",
            maxProgress: 20,
            progressProvider: { context in min(context.expenseReductionPercent * 100, 20) }
        ),
        AchievementDefinition(
            id: "savings-champion",
            title: "储蓄冠军",
            description: "累计储蓄达到 ¥10,000",
            reward: "获得理财课程",
            iconName: "trophy",
            colorHex: "#FACC15",
            maxProgress: 10_000,
            progressProvider: { context in min(context.savingsAmount, 10_000) }
        ),
        AchievementDefinition(
            id: "goal-master",
            title: "目标达成",
            description: "完成 5 个财务目标",
            reward: "解锁高级功能",
            iconName: "checkmark.circle",
            colorHex: "#F472B6",
            maxProgress: 5,
            progressProvider: { context in Double(context.completedGoals) }
        ),
        AchievementDefinition(
            id: "speed-logger",
            title: "闪电记账",
            description: "单日记账超过 10 笔",
            reward: "获得快捷模板",
            iconName: "bolt.fill",
            colorHex: "#FB923C",
            maxProgress: 10,
            progressProvider: { context in Double(context.maxDailyTransactions) }
        )
    ]

    init(repository: TransactionRepository, goalService: GoalSyncService, eventBus: FinanceEventBus) {
        self.repository = repository
        self.goalService = goalService
        self.eventBus = eventBus
        observeEvents()
        refresh()
    }

    func refresh() {
        Task { @MainActor in
            do {
                let transactions = try repository.fetchAllTransactions()
                let goals = try await goalService.fetchGoals()
                let streak = AchievementsCalculator.calculateStreak(from: transactions)
                streakDays = streak
                badges = AchievementsCalculator.calculateBadges(from: transactions)
                achievements = buildAchievements(from: transactions, goals: goals, streak: streak)
            } catch {
                streakDays = 0
                badges = []
                achievements = []
            }
        }
    }

    private func observeEvents() {
        eventBus.publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case .transactionsChanged, .goalsChanged:
                    self.refresh()
                case .budgetSummaryUpdated:
                    break
                case .userProfileUpdated:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func buildAchievements(from transactions: [Transaction], goals: [GoalSyncPayload], streak: Int) -> [AchievementDetailItem] {
        let context = makeContext(transactions: transactions, goals: goals, streak: streak)

        return achievementDefinitions.map { definition in
            let rawProgress = max(0, definition.progressProvider(context))
            let clamped = min(rawProgress, definition.maxProgress)
            return AchievementDetailItem(
                title: definition.title,
                description: definition.description,
                reward: definition.reward,
                iconName: definition.iconName,
                colorHex: definition.colorHex,
                isUnlocked: clamped >= definition.maxProgress && definition.maxProgress > 0,
                progress: clamped,
                maxProgress: definition.maxProgress
            )
        }
    }

    private func makeContext(transactions: [Transaction], goals: [GoalSyncPayload], streak: Int) -> AchievementContext {
        let calendar = Calendar.current

        let groupedByDay = Dictionary(grouping: transactions) { calendar.startOfDay(for: $0.occurredAt) }
        let maxDailyTransactions = groupedByDay.values.map { $0.count }.max() ?? 0

        let groupedByMonth = Dictionary(grouping: transactions) { transaction in
            calendar.date(from: calendar.dateComponents([.year, .month], from: transaction.occurredAt)) ?? transaction.occurredAt
        }

        let monthlyEntries = groupedByMonth.keys.sorted().map { key -> (Date, Decimal, Decimal) in
            let items = groupedByMonth[key] ?? []
            let income = items.filter { $0.type == .income }.reduce(Decimal.zero) { $0 + $1.amount }
            let expense = items.filter { $0.type == .expense }.reduce(Decimal.zero) { $0 + $1.amount }
            return (key, income, expense)
        }

        var currentStreak = 0
        var maxStreak = 0
        for entry in monthlyEntries.sorted(by: { $0.0 < $1.0 }) {
            if entry.1 >= entry.2 {
                currentStreak += 1
            } else {
                currentStreak = 0
            }
            maxStreak = max(maxStreak, currentStreak)
        }

        var expenseReductionPercent: Double = 0
        let sortedExpenses = monthlyEntries.sorted(by: { $0.0 < $1.0 })
        if sortedExpenses.count >= 2 {
            let latest = sortedExpenses[sortedExpenses.count - 1].2
            let previous = sortedExpenses[sortedExpenses.count - 2].2
            if previous > .zero {
                let reduction = (previous - latest) / previous
                if reduction > .zero {
                    expenseReductionPercent = min((reduction as NSDecimalNumber).doubleValue, 1)
                }
            }
        }

        let totalIncome = transactions
            .filter { $0.type == .income }
            .reduce(Decimal.zero) { $0 + $1.amount }
            .asDouble
        let totalExpense = transactions
            .filter { $0.type == .expense }
            .reduce(Decimal.zero) { $0 + $1.amount }
            .asDouble
        let savingsAmount = max(totalIncome - totalExpense, 0)

        let completedGoals = goals.filter { $0.currentAmount >= $0.targetAmount }.count

        return AchievementContext(
            streakDays: streak,
            maxDailyTransactions: maxDailyTransactions,
            positiveBudgetStreak: maxStreak,
            expenseReductionPercent: expenseReductionPercent,
            savingsAmount: savingsAmount,
            completedGoals: completedGoals
        )
    }

    private struct AchievementDefinition {
        let id: String
        let title: String
        let description: String
        let reward: String
        let iconName: String
        let colorHex: String
        let maxProgress: Double
        let progressProvider: (AchievementContext) -> Double
    }

    private struct AchievementContext {
        let streakDays: Int
        let maxDailyTransactions: Int
        let positiveBudgetStreak: Int
        let expenseReductionPercent: Double
        let savingsAmount: Double
        let completedGoals: Int
    }
}

enum AchievementsCalculator {
    static func calculateStreak(from transactions: [Transaction]) -> Int {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { calendar.startOfDay(for: $0.occurredAt) }
        let sortedDates = grouped.keys.sorted(by: >)
        guard let latest = sortedDates.first else { return 0 }

        var streak = 0
        var currentDate = latest
        while grouped[currentDate] != nil {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
            currentDate = previous
        }
        return streak
    }

    static func calculateBadges(from transactions: [Transaction]) -> [String] {
        var badges: [String] = []
        let total = transactions.reduce(Decimal.zero) { $0 + $1.amount }
        if total > 1000 {
            badges.append("节约达人")
        }
        if transactions.filter({ $0.type == .expense }).count >= 10 {
            badges.append("精明管家")
        }
        if transactions.contains(where: { $0.type == .income }) {
            badges.append("开源先锋")
        }
        return badges
    }
}

