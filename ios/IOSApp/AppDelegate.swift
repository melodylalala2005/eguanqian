import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var router: AppDeepLinkRouter?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard
            let deeplink = response.notification.request.content.userInfo[AppNotificationUserInfoKey.deeplink] as? String,
            deeplink == AppDeepLinkIdentifier.aiAssistantMessage.rawValue
        else { return }

        let message = response.notification.request.content.userInfo[AppNotificationUserInfoKey.aiMessage] as? String ?? AIAssistantNotificationText
        DeepLinkDiagnostics.log(
            "AppDelegate",
            "Notification tapped id=\(response.notification.request.identifier), route=\(deeplink), messagePreview=\(message.prefix(40))"
        )
        Task { @MainActor [weak self] in
            self?.router?.openAIAssistant(with: message)
        }
    }
}

