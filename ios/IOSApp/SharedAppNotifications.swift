import Foundation

enum SharedAppNotifications {
    private static let transactionsChangedName = CFNotificationName("com.yangjingchi.finance.transactionsChanged" as CFString)
    private static var transactionsObserver: DarwinNotificationObserver?

    static func startObserving(eventBus: FinanceEventBus) {
        guard transactionsObserver == nil else { return }
        transactionsObserver = DarwinNotificationObserver(name: transactionsChangedName) {
            Task { @MainActor in
                eventBus.send(.transactionsChanged(source: .sync))
            }
        }
    }

    static func postTransactionsChanged() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            transactionsChangedName,
            nil,
            nil,
            true
        )
    }
}

private final class DarwinNotificationObserver {
    private let name: CFNotificationName
    private let handler: () -> Void

    init(name: CFNotificationName, handler: @escaping () -> Void) {
        self.name = name
        self.handler = handler
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                let instance = Unmanaged<DarwinNotificationObserver>
                    .fromOpaque(observer)
                    .takeUnretainedValue()
                instance.handler()
            },
            name.rawValue,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            name,
            nil
        )
    }
}

