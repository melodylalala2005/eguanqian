import SwiftUI

struct AppRootView: View {
    let service: ConnectivityService
    let environment: FinanceEnvironment

    @State private var isAuthenticated: Bool = false

    var body: some View {
        Group {
            if isAuthenticated {
                FinanceShellView(
                    service: service,
                    environment: environment
                )
            } else {
                LoginFlowView { draft in
                    handleLoginCompletion(with: draft)
                }
            }
        }
        .task {
            if environment.userProfileService.currentProfile != nil {
                withAnimation(.easeInOut) {
                    isAuthenticated = true
                }
            }
        }
    }

    private func handleLoginCompletion(with draft: UserProfileDraft) {
        Task { @MainActor in
            do {
                try environment.userProfileService.saveProfile(
                    for: environment.apiConfiguration.userID,
                    from: draft
                )
            } catch {
                print("⚠️ 用户画像保存失败：\(error.localizedDescription)")
            }
            withAnimation(.easeInOut) {
                isAuthenticated = true
            }
        }
    }
}
