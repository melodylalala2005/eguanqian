import Foundation
import SwiftData

struct FinanceSeeder {
    static func seedIfNeeded(in context: ModelContext) throws {
        try seed(categories: CategoryDefinitions.expenseEntries, kind: .expense, in: context)
        try seed(categories: CategoryDefinitions.incomeEntries, kind: .income, in: context)

        if context.hasChanges {
            try context.save()
        }
    }

    private static func seed(categories entries: [CategoryDefinitions.Entry], kind: CategoryKind, in context: ModelContext) throws {
        var cache = try context.fetch(FetchDescriptor<TransactionCategory>())

        for entry in entries {
            if let existing = cache.first(where: { $0.name == entry.name && $0.kind == kind }) {
                if existing.emoji != entry.emoji {
                    existing.emoji = entry.emoji
                }
                if existing.colorHex != entry.colorHex {
                    existing.colorHex = entry.colorHex
                }
            } else {
                let category = TransactionCategory(
                    name: entry.name,
                    emoji: entry.emoji,
                    kind: kind,
                    colorHex: entry.colorHex
                )
                context.insert(category)
                cache.append(category)
            }
        }
    }
}

