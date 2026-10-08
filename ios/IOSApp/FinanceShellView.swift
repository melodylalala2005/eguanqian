import Combine
import SwiftUI

enum FinanceRoute: Hashable {
    case dashboard
    case statistics
    case goals
    case aiAssistant
    case achievements

    var title: String {
        switch self {
        case .dashboard:
            return "首页"
        case .statistics:
            return "统计"
        case .goals:
            return "财务健康管理"
        case .aiAssistant:
            return "AI 助手"
        case .achievements:
            return "成就"
        }
    }

    var iconName: String {
        switch self {
        case .dashboard:
            return "house.fill"
        case .statistics:
            return "chart.bar.fill"
        case .goals:
            return "target"
        case .aiAssistant:
            return "message.fill"
        case .achievements:
            return "trophy.fill"
        }
    }
}

struct FinanceShellView: View {
    let service: ConnectivityService
    let environment: FinanceEnvironment

    @StateObject private var achievementsViewModel: AchievementsViewModel
    @State private var selection: FinanceRoute = .dashboard
    @State private var isMenuPresented: Bool = false
    @EnvironmentObject private var router: AppDeepLinkRouter

    init(service: ConnectivityService, environment: FinanceEnvironment) {
        self.service = service
        self.environment = environment
        _achievementsViewModel = StateObject(wrappedValue: environment.makeAchievementsViewModel())
    }

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 700

            Group {
                if isCompact {
                    ZStack(alignment: .leading) {
                        VStack(spacing: 0) {
                            mobileHeader
                            contentView(isCompact: isCompact)
                                .disabled(isMenuPresented)
                                .overlay {
                                    if isMenuPresented {
                                        Color.black.opacity(0.3)
                                            .ignoresSafeArea()
                                            .onTapGesture {
                                                withAnimation(.easeInOut) {
                                                    isMenuPresented = false
                                                }
                                            }
                                    }
                                }
                        }

                        FinanceSidebar(
                            selection: $selection,
                            closeAction: {
                                withAnimation(.easeInOut) {
                                    isMenuPresented = false
                                }
                            }
                        )
                        .frame(width: 260)
                        .frame(maxHeight: .infinity)
                        .background(Color(uiColor: .systemBackground))
                        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 4)
                        .offset(x: isMenuPresented ? 0 : -300)
                    }
                    .animation(.easeInOut(duration: 0.22), value: isMenuPresented)
                } else {
                    HStack(spacing: 0) {
                        FinanceSidebar(selection: $selection)
                            .frame(width: 260)
                        contentView(isCompact: isCompact)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .onReceive(router.$targetRoute.compactMap { $0 }) { route in
            DeepLinkDiagnostics.log("FinanceShellView", "onReceive targetRoute=\(route)")
            selection = route
            if route == .aiAssistant {
                withAnimation(.easeInOut) {
                    isMenuPresented = false
                }
            }
            router.clearRoute()
        }
        .task {
            processPendingRouteIfNeeded()
        }
    }

    @ViewBuilder
    private func contentView(isCompact: Bool) -> some View {
        NavigationStack {
            switch selection {
            case .dashboard:
                DashboardRootView(
                    service: service,
                    financeEnvironment: environment,
                    achievementsViewModel: achievementsViewModel,
                    showsEmbeddedNavigation: !isCompact
                )
            case .statistics:
                StatisticsAnalyticsView(viewModel: environment.makeStatisticsAnalyticsViewModel())
            case .goals:
                FinancialHealthView(viewModel: environment.makeFinancialHealthViewModel())
            case .aiAssistant:
                AIChatRootView(environment: environment)
            case .achievements:
                AchievementsRootView(viewModel: achievementsViewModel)
            }
        }
    }

    private func processPendingRouteIfNeeded() {
        if let route = router.consumeTargetRoute() {
            DeepLinkDiagnostics.log("FinanceShellView", "processPendingRouteIfNeeded applied route=\(route)")
            selection = route
            if route == .aiAssistant {
                withAnimation(.easeInOut) {
                    isMenuPresented = false
                }
            }
        }
    }

    private var mobileHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut) {
                    isMenuPresented = true
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }

            Text("鹅管钱")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea(edges: .top))
    }
}

private struct FinanceSidebar: View {
    @Binding var selection: FinanceRoute
    var closeAction: (() -> Void)?

    private struct SidebarMenuItem: Identifiable {
        let id = UUID()
        let route: FinanceRoute
    }

    private let menuItems: [SidebarMenuItem] = [
        SidebarMenuItem(route: .dashboard),
        SidebarMenuItem(route: .statistics),
        SidebarMenuItem(route: .goals),
        SidebarMenuItem(route: .aiAssistant),
        SidebarMenuItem(route: .achievements)
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            menu
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("鹅管钱")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Color(uiColor: .systemBackground)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .foregroundStyle(Color(uiColor: .separator))
                        .frame(height: 0.5)
                }
        )
    }

    private var menu: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(menuItems) { item in
                    let isActive = selection == item.route
                    Button {
                        selection = item.route
                        closeAction?()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.route.iconName)
                                .font(.system(size: 18, weight: .semibold))
                            Text(item.route.title)
                                .font(.system(size: 15, weight: .medium))
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .foregroundStyle(isActive ? Color.white : Color.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isActive ? StatisticsPalette.primary : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
        }
    }

    private var footer: some View {
        Spacer(minLength: 0)
    }
}

private struct PlaceholderView: View {
    let title: String

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

