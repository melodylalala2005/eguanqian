import Foundation

struct CategoryDefinitions {
    struct Entry {
        let name: String
        let emoji: String
        let colorHex: String
    }

    static let expenseEntries: [Entry] = [
        Entry(name: "餐饮", emoji: "🍜", colorHex: "#F97316"),
        Entry(name: "购物", emoji: "🛍️", colorHex: "#EC4899"),
        Entry(name: "交通", emoji: "🚗", colorHex: "#3B82F6"),
        Entry(name: "住房", emoji: "🏠", colorHex: "#6366F1"),
        Entry(name: "休闲娱乐", emoji: "🎮", colorHex: "#A855F7"),
        Entry(name: "学习办公", emoji: "🧑‍💻", colorHex: "#0EA5E9"),
        Entry(name: "医疗健康", emoji: "💊", colorHex: "#EF4444"),
        Entry(name: "保险理财", emoji: "🛡️", colorHex: "#10B981"),
        Entry(name: "宠物", emoji: "🐾", colorHex: "#FBBF24"),
        Entry(name: "母婴", emoji: "🍼", colorHex: "#FB7185"),
        Entry(name: "文化娱乐", emoji: "🎬", colorHex: "#D946EF"),
        Entry(name: "资金往来", emoji: "💱", colorHex: "#14B8A6"),
        Entry(name: "其他支出", emoji: "📦", colorHex: "#94A3B8")
    ]

    static let incomeEntries: [Entry] = [
        Entry(name: "工资", emoji: "💰", colorHex: "#10B981"),
        Entry(name: "奖金", emoji: "🎁", colorHex: "#22C55E"),
        Entry(name: "投资收益", emoji: "📈", colorHex: "#14B8A6"),
        Entry(name: "其他收入", emoji: "🔄", colorHex: "#06B6D4")
    ]

    private static let expenseOrder: [String: Int] = {
        Dictionary(uniqueKeysWithValues: expenseEntries.enumerated().map { index, entry in
            (entry.name, index)
        })
    }()

    private static let incomeOrder: [String: Int] = {
        Dictionary(uniqueKeysWithValues: incomeEntries.enumerated().map { index, entry in
            (entry.name, index)
        })
    }()

    static func orderIndex(for name: String, kind: CategoryKind) -> Int {
        switch kind {
        case .expense:
            return expenseOrder[name] ?? Int.max
        case .income:
            return incomeOrder[name] ?? Int.max
        }
    }
}

