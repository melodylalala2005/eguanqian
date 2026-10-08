import Foundation
import Combine
import SwiftData
import SwiftUI

@Model
final class LedgerEntry {
    @Attribute(.unique) var id: UUID
    var amount: Decimal
    var purpose: String
    var status: String
    var createdAt: Date
    var rawJSON: String

    init(
        amount: Decimal,
        purpose: String,
        status: String,
        createdAt: Date = .now,
        rawJSON: String
    ) {
        self.id = UUID()
        self.amount = amount
        self.purpose = purpose
        self.status = status
        self.createdAt = createdAt
        self.rawJSON = rawJSON
    }
}

@MainActor
final class LedgerViewModel: ObservableObject {
    @Published var amountText: String = ""
    @Published var purpose: String = ""
    @Published var isSubmitting: Bool = false
    @Published var errorMessage: String?
    @Published var lastStatus: String?

    private let context: ModelContext
    private let service: ConnectivityService

    init(context: ModelContext, service: ConnectivityService) {
        self.context = context
        self.service = service
    }

    func submit() async {
        let trimmedPurpose = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPurpose.isEmpty else {
            errorMessage = "用途不能为空"
            return
        }

        let trimmedAmount = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = Decimal(string: trimmedAmount), amount > 0 else {
            errorMessage = "请输入有效的金额"
            return
        }

        isSubmitting = true
        errorMessage = nil

        do {
            let pingSucceeded = try await service.pingBaidu()
            let status = pingSucceeded ? "OK" : "Default"
            let jsonString = try service.buildJSON(
                amount: amount,
                purpose: trimmedPurpose,
                status: status
            )

            let entry = LedgerEntry(
                amount: amount,
                purpose: trimmedPurpose,
                status: status,
                rawJSON: jsonString
            )

            context.insert(entry)
            try context.save()

            await MainActor.run {
                amountText = ""
                purpose = ""
                lastStatus = status
            }
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }

        isSubmitting = false
    }
}
