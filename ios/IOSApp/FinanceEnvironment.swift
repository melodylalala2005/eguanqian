import Foundation
import Combine
import SwiftData
import SwiftUI

@MainActor
final class FinanceEventBus {
    enum Source {
        case dashboard
        case transactions
        case statistics
        case goals
        case achievements
        case sync
    }

    enum Event {
        case transactionsChanged(source: Source)
        case budgetSummaryUpdated(BudgetSummary?)
        case goalsChanged(source: Source)
        case userProfileUpdated(UserProfileSnapshot?)
    }

    private let subject = PassthroughSubject<Event, Never>()

    var publisher: AnyPublisher<Event, Never> {
        subject.eraseToAnyPublisher()
    }

    func send(_ event: Event) {
        subject.send(event)
    }
}

struct FinanceEnvironment {
    let context: ModelContext
    let transactionRepository: TransactionRepository
    let budgetService: BudgetService
    let statisticsService: StatisticsService
    let statisticsAggregator: StatisticsAnalyticsAggregator
    let aiChatService: AIChatService
    let userProfileService: UserProfileService
    let goalSyncService: GoalSyncService
    let receiptRecognitionService: any ReceiptRecognitionService
    let apiClient: FinanceAPIClient
    let billSyncService: BillSyncService
    let apiConfiguration: APIConfiguration
    let syncCoordinator: TransactionSyncCoordinator
    let eventBus: FinanceEventBus
    let networkStatusService: NetworkStatusService
    let receiptRecognitionPreferences: ReceiptRecognitionPreferences
    let receiptImagePreprocessor: ReceiptImagePreprocessor
    let receiptRecognitionQueueStore: ReceiptRecognitionQueueStore
    let receiptRecognitionHistoryStore: ReceiptRecognitionHistoryStore
    let receiptRecognitionCoordinator: ReceiptRecognitionCoordinator

    init(context: ModelContext) {
        self.context = context
        do {
            try FinanceSeeder.seedIfNeeded(in: context)
        } catch {
            print("⚠️ 数据初始化失败：\(error)")
        }
        self.eventBus = FinanceEventBus()
        let networkStatusService = NetworkStatusService()
        self.networkStatusService = networkStatusService
        let recognitionPreferences = ReceiptRecognitionPreferences()
        self.receiptRecognitionPreferences = recognitionPreferences
        self.transactionRepository = MockTransactionRepository(context: context)
        self.budgetService = MockBudgetService(context: context)
        self.statisticsService = MockStatisticsService(context: context)
        self.statisticsAggregator = DefaultStatisticsAnalyticsAggregator(context: context)
        self.apiConfiguration = .default
        var client = FinanceAPIClient(baseURL: apiConfiguration.baseURL)
        client.authMethod = .none
        self.aiChatService = MockAIChatService()
        let userProfileService = PersistentUserProfileService(context: context, eventBus: eventBus)
        self.userProfileService = userProfileService
        self.goalSyncService = MockGoalSyncService()
        self.receiptRecognitionService = NetworkReceiptRecognitionService(configuration: apiConfiguration)
        self.receiptImagePreprocessor = ReceiptImagePreprocessor(
            uuidProvider: { UUID() }
        )
        self.receiptRecognitionQueueStore = ReceiptRecognitionQueueStore(context: context)
        self.receiptRecognitionHistoryStore = ReceiptRecognitionHistoryStore(context: context)
        self.apiClient = client
        self.billSyncService = NetworkBillSyncService(client: client)
        self.syncCoordinator = TransactionSyncCoordinator(
            repository: transactionRepository,
            service: billSyncService,
            configuration: apiConfiguration
        )
        self.receiptRecognitionCoordinator = ReceiptRecognitionCoordinator(
            queueStore: receiptRecognitionQueueStore,
            historyStore: receiptRecognitionHistoryStore,
            preprocessor: receiptImagePreprocessor,
            recognitionService: receiptRecognitionService,
            networkStatusService: networkStatusService,
            configuration: ReceiptRecognitionCoordinatorConfiguration()
        )
        do {
            _ = try userProfileService.loadProfile(for: apiConfiguration.userID)
        } catch {
            print("⚠️ 用户画像加载失败：\(error.localizedDescription)")
        }
    }

    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(
            transactionRepository: transactionRepository,
            budgetService: budgetService,
            context: context,
            syncCoordinator: syncCoordinator,
            eventBus: eventBus,
            recognitionCoordinator: receiptRecognitionCoordinator,
            recognitionPreferences: receiptRecognitionPreferences,
            historyStore: receiptRecognitionHistoryStore,
            currentUserID: apiConfiguration.userID,
            recognitionToken: apiConfiguration.recognitionToken
        )
    }

    func makeTransactionsViewModel(
        reloadSummary: @escaping () -> Void,
        syncFeedback: @escaping (Result<String, Error>) -> Void
    ) -> TransactionsViewModel {
        let viewModel = TransactionsViewModel(
            repository: transactionRepository,
            context: context,
            syncCoordinator: syncCoordinator,
            eventBus: eventBus
        )
        viewModel.reloadSummary = reloadSummary
        viewModel.syncFeedback = syncFeedback
        return viewModel
    }

    func makeStatisticsViewModel() -> StatisticsViewModel {
        StatisticsViewModel(service: statisticsService, eventBus: eventBus)
    }

    func makeStatisticsAnalyticsViewModel() -> StatisticsAnalyticsViewModel {
        StatisticsAnalyticsViewModel(
            aggregator: statisticsAggregator,
            eventBus: eventBus,
            userProfileService: userProfileService,
            budgetService: budgetService
        )
    }

    func makeFinancialHealthViewModel() -> FinancialHealthViewModel {
        FinancialHealthViewModel(
            context: context,
            eventBus: eventBus,
            userProfileService: userProfileService,
            userID: apiConfiguration.userID
        )
    }

    func makeAchievementsViewModel() -> AchievementsViewModel {
        AchievementsViewModel(
            repository: transactionRepository,
            goalService: goalSyncService,
            eventBus: eventBus
        )
    }

    func makeGoalsViewModel() -> GoalsViewModel {
        GoalsViewModel(service: goalSyncService, eventBus: eventBus)
    }

    func makeAIChatViewModel() -> AIChatViewModel {
        AIChatViewModel(service: aiChatService)
    }
}

private struct FinanceEnvironmentKey: EnvironmentKey {
    static var defaultValue: FinanceEnvironment?
}

extension EnvironmentValues {
    var financeEnvironment: FinanceEnvironment? {
        get { self[FinanceEnvironmentKey.self] }
        set { self[FinanceEnvironmentKey.self] = newValue }
    }
}

