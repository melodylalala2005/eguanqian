import Combine
import Foundation
import SwiftUI

enum AppDeepLinkIdentifier: String {
    case aiAssistantMessage = "ai_assistant_message"
}

enum AppNotificationUserInfoKey {
    static let deeplink = "app_deeplink"
    static let aiMessage = "app_ai_message"
}

let AIAssistantNotificationText = "嗨小王！看到你新买了一个耳机🎧，好漂亮呢！😍但是的确有点超出预算啦，不过你别担心，我已经给你更新了新的预算规划，接下来要努力按照我们的规划执行哦💪"

@MainActor
final class AppDeepLinkRouter: ObservableObject {
    @Published private(set) var targetRoute: FinanceRoute?
    @Published private(set) var pendingAIChatMessage: String?

    func openAIAssistant(with message: String) {
        targetRoute = .aiAssistant
        pendingAIChatMessage = message
        DeepLinkDiagnostics.log("AppDeepLinkRouter", "Prepared AI route with messageLength=\(message.count)")
    }

    func consumeTargetRoute() -> FinanceRoute? {
        let route = targetRoute
        targetRoute = nil
        if let route {
            DeepLinkDiagnostics.log("AppDeepLinkRouter", "Consuming pending route \(route)")
        }
        return route
    }

    func clearRoute() {
        if targetRoute != nil {
            DeepLinkDiagnostics.log("AppDeepLinkRouter", "Clearing route after navigation")
        }
        targetRoute = nil
    }

    func consumeAIChatMessage() -> String? {
        let message = pendingAIChatMessage
        pendingAIChatMessage = nil
        if let message {
            DeepLinkDiagnostics.log("AppDeepLinkRouter", "Delivering AI message of length \(message.count)")
        }
        return message
    }
}

