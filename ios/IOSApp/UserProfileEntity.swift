import Foundation
import SwiftData

@Model
final class UserProfileEntity {
    @Attribute(.unique) var userID: String
    var ageRangeRaw: String?
    var occupationRaw: String?
    var incomeBracketRaw: String?
    var goalsRaw: [String]
    var targetTimelineRaw: String?
    var targetAmount: Decimal?
    var savedAmount: Decimal?
    var updatedAt: Date

    init(userID: String) {
        self.userID = userID
        self.goalsRaw = []
        self.updatedAt = .now
    }
}

extension UserProfileEntity {
    func apply(from draft: UserProfileDraft) {
        ageRangeRaw = draft.ageRange?.rawValue
        occupationRaw = draft.occupation?.rawValue
        incomeBracketRaw = draft.incomeBracket?.rawValue
        goalsRaw = draft.goals.map { $0.rawValue }.sorted()
        targetTimelineRaw = draft.targetTimeline?.rawValue
        targetAmount = draft.targetAmount
        savedAmount = draft.savedAmount
        updatedAt = .now
    }

    var snapshot: UserProfileSnapshot {
        UserProfileSnapshot(
            userID: userID,
            ageRange: ageRangeRaw.flatMap(AgeRange.init(rawValue:)),
            occupation: occupationRaw.flatMap(Occupation.init(rawValue:)),
            incomeBracket: incomeBracketRaw.flatMap(IncomeBracket.init(rawValue:)),
            goals: Set(goalsRaw.compactMap(FinancialGoal.init(rawValue:))),
            targetTimeline: targetTimelineRaw.flatMap(GoalTimeline.init(rawValue:)),
            targetAmount: targetAmount,
            savedAmount: savedAmount,
            updatedAt: updatedAt
        )
    }
}
