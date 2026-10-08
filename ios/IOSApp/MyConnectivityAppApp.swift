import SwiftData
import SwiftUI

@main
struct MyConnectivityAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var deepLinkRouter: AppDeepLinkRouter
    private let connectivityService: ConnectivityService
    private let modelContainer: ModelContainer
    private let financeEnvironment: FinanceEnvironment

    init() {
        do {
            _deepLinkRouter = StateObject(wrappedValue: AppDeepLinkRouter())
            self.connectivityService = try ConnectivityService()
            self.modelContainer = try SharedModelContainerProvider.makeContainer()
            self.financeEnvironment = FinanceEnvironment(context: modelContainer.mainContext)
            SharedAppNotifications.startObserving(eventBus: financeEnvironment.eventBus)
            appDelegate.router = deepLinkRouter
        } catch {
            fatalError("初始化失败：\(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(
                service: connectivityService,
                environment: financeEnvironment
            )
            .environmentObject(deepLinkRouter)
        }
        .modelContainer(modelContainer)
    }
}
