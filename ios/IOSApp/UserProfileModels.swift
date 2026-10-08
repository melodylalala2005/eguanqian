import Foundation

enum AgeRange: String, CaseIterable, Identifiable {
    case under22
    case between22And30
    case between31And40
    case between41And50
    case above50

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .under22: return "<22"
        case .between22And30: return "22-30"
        case .between31And40: return "31-40"
        case .between41And50: return "41-50"
        case .above50: return ">50"
        }
    }
}

enum Occupation: String, CaseIterable, Identifiable {
    case student
    case technology
    case finance
    case education
    case healthcare
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .student: return "学生"
        case .technology: return "互联网/科技"
        case .finance: return "金融/投资"
        case .education: return "教育/培训"
        case .healthcare: return "医疗/健康"
        case .other: return "其他"
        }
    }
}

enum IncomeBracket: String, CaseIterable, Identifiable {
    case under3000
    case between3000And6000
    case between6000And10000
    case between10000And20000
    case above20000

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .under3000: return "<3000"
        case .between3000And6000: return "3000-6000"
        case .between6000And10000: return "6000-10000"
        case .between10000And20000: return "10000-20000"
        case .above20000: return ">20000"
        }
    }
}

enum FinancialGoal: String, CaseIterable, Identifiable {
    case emergencyFund
    case travel
    case homePurchase
    case educationFund
    case entrepreneurship
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .emergencyFund: return "存一笔应急金"
        case .travel: return "存钱去旅游"
        case .homePurchase: return "买房或首付"
        case .educationFund: return "孩子教育基金"
        case .entrepreneurship: return "创业"
        case .other: return "其他"
        }
    }
}

enum GoalTimeline: String, CaseIterable, Identifiable {
    case threeMonths
    case sixMonths
    case oneYear
    case threeYears
    case fiveYearsPlus

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .threeMonths: return "三个月"
        case .sixMonths: return "半年"
        case .oneYear: return "1年"
        case .threeYears: return "3年"
        case .fiveYearsPlus: return "五年以上"
        }
    }
}

struct UserProfileDraft {
    var ageRange: AgeRange?
    var occupation: Occupation?
    var incomeBracket: IncomeBracket?
    var goals: Set<FinancialGoal> = []
    var targetTimeline: GoalTimeline?
    var targetAmountText: String = ""
    var savedAmountText: String = ""

    var targetAmount: Decimal? {
        Decimal(string: targetAmountText.filter { !$0.isWhitespace })
    }

    var savedAmount: Decimal? {
        Decimal(string: savedAmountText.filter { !$0.isWhitespace })
    }

    var isComplete: Bool {
        ageRange != nil &&
        occupation != nil &&
        incomeBracket != nil &&
        !goals.isEmpty &&
        targetTimeline != nil
    }
}

struct UserProfileSnapshot: Equatable {
    let userID: String
    var ageRange: AgeRange?
    var occupation: Occupation?
    var incomeBracket: IncomeBracket?
    var goals: Set<FinancialGoal>
    var targetTimeline: GoalTimeline?
    var targetAmount: Decimal?
    var savedAmount: Decimal?
    var updatedAt: Date

    init(
        userID: String,
        ageRange: AgeRange? = nil,
        occupation: Occupation? = nil,
        incomeBracket: IncomeBracket? = nil,
        goals: Set<FinancialGoal> = [],
        targetTimeline: GoalTimeline? = nil,
        targetAmount: Decimal? = nil,
        savedAmount: Decimal? = nil,
        updatedAt: Date = .now
    ) {
        self.userID = userID
        self.ageRange = ageRange
        self.occupation = occupation
        self.incomeBracket = incomeBracket
        self.goals = goals
        self.targetTimeline = targetTimeline
        self.targetAmount = targetAmount
        self.savedAmount = savedAmount
        self.updatedAt = updatedAt
    }

    static func empty(userID: String) -> UserProfileSnapshot {
        UserProfileSnapshot(userID: userID)
    }
}
