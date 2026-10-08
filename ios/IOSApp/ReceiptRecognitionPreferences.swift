import Foundation
import Combine

@MainActor
final class ReceiptRecognitionPreferences: ObservableObject {
    @Published var flowSavingModeEnabled: Bool {
        didSet {
            userDefaults.set(flowSavingModeEnabled, forKey: Self.flowSavingKey)
        }
    }

    private let userDefaults: UserDefaults
    private static let flowSavingKey = "receiptRecognition.flowSavingModeEnabled"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if userDefaults.object(forKey: Self.flowSavingKey) == nil {
            self.flowSavingModeEnabled = false
        } else {
            self.flowSavingModeEnabled = userDefaults.bool(forKey: Self.flowSavingKey)
        }
    }

    func setFlowSavingMode(_ enabled: Bool) {
        flowSavingModeEnabled = enabled
    }

    func toggleFlowSavingMode() {
        flowSavingModeEnabled.toggle()
    }
}
