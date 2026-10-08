import Charts
import SwiftData
import SwiftUI

struct DashboardRootView: View {
    private let service: ConnectivityService
    private let financeEnvironment: FinanceEnvironment
    private let showsEmbeddedNavigation: Bool

    @StateObject private var dashboardViewModel: DashboardViewModel
    @StateObject private var transactionsViewModel: TransactionsViewModel
    @ObservedObject private var achievementsViewModel: AchievementsViewModel

    init(
        service: ConnectivityService,
        financeEnvironment: FinanceEnvironment,
        achievementsViewModel: AchievementsViewModel,
        showsEmbeddedNavigation: Bool = true
    ) {
        self.service = service
        self.financeEnvironment = financeEnvironment
        self.showsEmbeddedNavigation = showsEmbeddedNavigation
        let dashboardVM = financeEnvironment.makeDashboardViewModel()
        let transactionsVM = financeEnvironment.makeTransactionsViewModel(
            reloadSummary: {
                Task { @MainActor in
                    dashboardVM.loadSummary()
                }
            },
            syncFeedback: { result in
                Task { @MainActor in
                    switch result {
                    case .success(let message):
                        dashboardVM.errorMessage = nil
                        dashboardVM.infoMessage = message
                    case .failure(let error):
                        dashboardVM.infoMessage = nil
                        dashboardVM.errorMessage = error.localizedDescription
                    }
                }
            }
        )
        _dashboardViewModel = StateObject(wrappedValue: dashboardVM)
        _transactionsViewModel = StateObject(wrappedValue: transactionsVM)
        _achievementsViewModel = ObservedObject(wrappedValue: achievementsViewModel)
    }

    @State private var shouldNavigateToAI: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            (Color(hex: "#F5F6FB") ?? Color(uiColor: .systemGroupedBackground))
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    if showsEmbeddedNavigation {
                        dashboardTopBar
                    }

                    DashboardHeaderView(viewModel: dashboardViewModel)

                    BudgetSummaryCardView(
                        summary: dashboardViewModel.budgetSummary,
                        isLoading: dashboardViewModel.isLoadingSummary
                    )

                    TransactionsListSectionView(
                        viewModel: transactionsViewModel,
                        onAddTransaction: {
                            dashboardViewModel.resetDraft()
                            dashboardViewModel.isAddSheetPresented = true
                        }
                    )

                    AchievementBadgesView(viewModel: achievementsViewModel)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 120)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                shouldNavigateToAI = true
            } label: {
                Image(systemName: "ellipsis.bubble.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(hex: "#4C3FF4") ?? StatisticsPalette.primary,
                                Color(hex: "#1E3AA5") ?? StatisticsPalette.primary
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundStyle(Color.white)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.2), radius: 12, y: 8)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 36)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $shouldNavigateToAI) {
            AIChatRootView(environment: financeEnvironment)
        }
        .task {
            dashboardViewModel.loadSummary()
            transactionsViewModel.load()
            achievementsViewModel.refresh()
        }
        .onChange(of: dashboardViewModel.recentlyAdded, initial: false) { _, _ in
            transactionsViewModel.load()
            achievementsViewModel.refresh()
        }
    }
}

extension DashboardRootView {
    private var dashboardTopBar: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    // TODO: drawer action placeholder
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color(hex: "#3B82F6") ?? .blue)
                        .padding(8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: Color.black.opacity(0.05), radius: 6, y: 3)
                }

                Spacer()

                Text("鹅管钱")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Color.clear
                    .frame(width: 44, height: 44)
            }

            Divider()
        }
    }
}

private func makePreviewDependencies() -> (ModelContainer, ConnectivityService, FinanceEnvironment) {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: LedgerEntry.self,
                Transaction.self,
                TransactionCategory.self,
                BudgetPlan.self,
                BudgetSegment.self,
                PendingReceiptRecognition.self,
                RecognizedReceiptHistory.self,
                UserProfileEntity.self,
            configurations: config
        )
        let service = try ConnectivityService()

        let context = container.mainContext
        try FinanceSeeder.seedIfNeeded(in: context)

        return (container, service, FinanceEnvironment(context: context))
    } catch {
        fatalError("预览初始化失败：\(error)")
    }
}

#Preview("Dashboard") {
    let (container, service, financeEnvironment) = makePreviewDependencies()
    let achievementsVM = financeEnvironment.makeAchievementsViewModel()
    return NavigationStack {
        DashboardRootView(
            service: service,
            financeEnvironment: financeEnvironment,
            achievementsViewModel: achievementsVM
        )
    }
    .modelContainer(container)
}

