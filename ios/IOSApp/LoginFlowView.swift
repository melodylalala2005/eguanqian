import SwiftUI

struct LoginFlowView: View {
    enum Phase {
        case onboarding
        case login
        case questionnaire
    }

    @State private var phase: Phase = .onboarding
    @State private var draft = UserProfileDraft()
    @State private var isAuthenticating: Bool = false
    let onCompletion: (UserProfileDraft) -> Void

    var body: some View {
        ZStack {
            switch phase {
            case .onboarding:
                OnboardingCarouselView {
                    withAnimation(.easeInOut) {
                        phase = .login
                    }
                }
            case .login:
                LoginFormView(isAuthenticating: $isAuthenticating) {
                    withAnimation(.easeInOut) {
                        phase = .questionnaire
                    }
                }
            case .questionnaire:
                QuestionnaireFlowView(draft: $draft) { completedDraft in
                    onCompletion(completedDraft)
                } onSkip: {
                    onCompletion(draft)
                }
            }
        }
        .animation(.easeInOut, value: phase)
    }
}

// MARK: - Onboarding

private struct OnboardingCarouselView: View {
    private let images = [
        "onboarding_penguin_1",
        "onboarding_penguin_2",
        "onboarding_penguin_3"
    ]

    @State private var index: Int = 0
    let onContinue: () -> Void

    var body: some View {
        VStack {
            TabView(selection: $index) {
                ForEach(Array(images.enumerated()), id: \.offset) { item in
                    Image(item.element)
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 36)
                        .tag(item.offset)
                        .accessibilityLabel("Onboarding illustration \(item.offset + 1)")
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .padding(.top, 32)

            Spacer()

            Button {
                if index < images.count - 1 {
                    withAnimation(.easeInOut) {
                        index = min(index + 1, images.count - 1)
                    }
                } else {
                    onContinue()
                }
            } label: {
                Text(index == images.count - 1 ? "开始体验" : "继续")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [Color.white, Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

// MARK: - Login Form

private struct LoginFormView: View {
    @Binding var isAuthenticating: Bool
    @State private var username: String = ""
    @State private var password: String = ""
    let onLoginSuccess: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            VStack(alignment: .leading, spacing: 12) {
                Text("欢迎回来")
                    .font(.system(size: 32, weight: .bold))
                Text("登录账户继续使用智能记账")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 18) {
                RoundedInputField(title: "账号", placeholder: "请输入手机号或邮箱", text: $username)
                RoundedSecureField(title: "密码", placeholder: "请输入密码", text: $password)
            }

            Button(action: authenticate) {
                HStack {
                    if isAuthenticating {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("登录")
                        .font(.system(size: 18, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(username.isEmpty || password.isEmpty ? Color.gray.opacity(0.4) : Color.accentColor)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .disabled(username.isEmpty || password.isEmpty || isAuthenticating)

            Spacer()

            Button("还没有账户？立即注册") {
                // 留作未来实现
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(Color.accentColor)
        }
        .padding(32)
        .background(
            LinearGradient(colors: [Color(.systemBackground), Color(.systemGroupedBackground)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private func authenticate() {
        guard !username.isEmpty, !password.isEmpty else { return }
        isAuthenticating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isAuthenticating = false
            onLoginSuccess()
        }
    }
}

private struct RoundedInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.05), radius: 10, y: 6)
        }
    }
}

private struct RoundedSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            SecureField(placeholder, text: $text)
                .textContentType(.password)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.05), radius: 10, y: 6)
        }
    }
}

// MARK: - Questionnaire Flow

private enum ProfileQuestionStep: Int, CaseIterable {
    case age
    case occupation
    case income
    case goals
    case timeline
    case amounts

    var title: String {
        switch self {
        case .age: return "您的年龄段"
        case .occupation: return "您的职业"
        case .income: return "月收入区间"
        case .goals: return "理财目标"
        case .timeline: return "实现时间"
        case .amounts: return "目标金额"
        }
    }

    var subtitle: String {
        switch self {
        case .age: return "帮助我们提供更贴合的预算建议"
        case .occupation: return "了解职业背景，提供针对性建议"
        case .income: return "制定与收入匹配的理财规划"
        case .goals: return "今年想实现的目标（可多选）"
        case .timeline: return "希望多久内实现您的理财目标"
        case .amounts: return "设置目标金额与当前已积累金额"
        }
    }

    var progress: Double {
        Double(rawValue + 1) / Double(ProfileQuestionStep.allCases.count)
    }

    func next() -> ProfileQuestionStep? {
        ProfileQuestionStep(rawValue: rawValue + 1)
    }

    func previous() -> ProfileQuestionStep? {
        ProfileQuestionStep(rawValue: rawValue - 1)
    }
}

private struct QuestionnaireFlowView: View {
    @Binding var draft: UserProfileDraft
    @State private var currentStep: ProfileQuestionStep = .age
    @FocusState private var amountsFieldFocus: AmountsField?

    let onFinish: (UserProfileDraft) -> Void
    let onSkip: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground()
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 24) {
                    ProgressDots(currentStep: currentStep)
                        .frame(maxWidth: .infinity, alignment: .center)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(currentStep.title)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(Color.primary)
                        Text(currentStep.subtitle)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.black.opacity(0.6))
                    }

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            stepContent
                        }
                        .padding(.vertical, 6)
                    }

                    ActionArea(
                        showBack: currentStep.previous() != nil,
                        isPrimaryDisabled: isPrimaryButtonDisabled,
                        primaryTitle: currentStep == .amounts ? "完成" : "下一步",
                        onBack: goToPreviousStep,
                        onPrimary: handlePrimaryAction
                    )
                }
                .padding(.horizontal, 28)
                .padding(.top, 32)
                .padding(.bottom, 28)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("跳过") {
                        onSkip()
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.65))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .age:
            OptionList(options: AgeRange.allCases, selection: Binding(
                get: { draft.ageRange },
                set: { draft.ageRange = $0 }
            )) { $0.displayName }
        case .occupation:
            OptionList(options: Occupation.allCases, selection: Binding(
                get: { draft.occupation },
                set: { draft.occupation = $0 }
            )) { $0.displayName }
        case .income:
            OptionList(options: IncomeBracket.allCases, selection: Binding(
                get: { draft.incomeBracket },
                set: { draft.incomeBracket = $0 }
            )) { $0.displayName }
        case .goals:
            MultiOptionList(options: FinancialGoal.allCases, selection: Binding(
                get: { draft.goals },
                set: { draft.goals = $0 }
            )) { $0.displayName }
        case .timeline:
            OptionList(options: GoalTimeline.allCases, selection: Binding(
                get: { draft.targetTimeline },
                set: { draft.targetTimeline = $0 }
            )) { $0.displayName }
        case .amounts:
            VStack(spacing: 16) {
                amountField(title: "目标金额（元）", text: $draft.targetAmountText)
                    .focused($amountsFieldFocus, equals: .target)
                amountField(title: "已存金额（元）", text: $draft.savedAmountText)
                    .focused($amountsFieldFocus, equals: .saved)
            }
        }
    }

    private func amountField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.05), radius: 10, y: 6)
        }
    }

    private var isPrimaryButtonDisabled: Bool {
        switch currentStep {
        case .age: return draft.ageRange == nil
        case .occupation: return draft.occupation == nil
        case .income: return draft.incomeBracket == nil
        case .goals: return draft.goals.isEmpty
        case .timeline: return draft.targetTimeline == nil
        case .amounts: return false
        }
    }

    private func goToPreviousStep() {
        if let previous = currentStep.previous() {
            withAnimation(.easeInOut) {
                currentStep = previous
            }
        }
    }

    private func handlePrimaryAction() {
        if let next = currentStep.next() {
            withAnimation(.easeInOut) {
                currentStep = next
            }
        } else {
            onFinish(draft)
        }
    }
}

private enum AmountsField: Hashable {
    case target
    case saved
}

// MARK: - Reusable Components
private struct GradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(hex: "#EEF0FF") ?? Color(.systemGray6),
                Color(hex: "#F8ECFF") ?? Color(.systemGroupedBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct ProgressDots: View {
    let currentStep: ProfileQuestionStep

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ProfileQuestionStep.allCases, id: \.self) { step in
                Capsule()
                    .fill(step == currentStep ? activeGradient : inactiveGradient)
                    .frame(width: step == currentStep ? 28 : 10, height: 8)
                    .animation(.easeInOut(duration: 0.25), value: currentStep)
            }
        }
    }

    private var activeGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "#9C8BFF") ?? .purple,
                Color(hex: "#7F9CFF") ?? .blue
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var inactiveGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.6),
                Color.white.opacity(0.4)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

private struct OptionButton: View {
    let title: String
    let isSelected: Bool
    let allowsMultiple: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.black.opacity(0.82))
                Spacer()
                if allowsMultiple && isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white)
                }
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .background(background)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(isSelected ? 0.18 : 0.08), radius: isSelected ? 22 : 10, x: 0, y: isSelected ? 12 : 6)
        }
        .buttonStyle(.plain)
    }

    private var background: some View {
        Group {
            if isSelected {
                LinearGradient(
                    colors: [
                        Color(hex: "#9C8BFF") ?? .purple,
                        Color(hex: "#7C9BFF") ?? .blue
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else {
                Color.white.opacity(0.96)
            }
        }
    }
}

private struct OptionList<Option: Identifiable & Hashable>: View {
    let options: [Option]
    @Binding var selection: Option?
    let label: (Option) -> String

    var body: some View {
        VStack(spacing: 16) {
            ForEach(options) { option in
                OptionButton(title: label(option), isSelected: selection == option, allowsMultiple: false) {
                    selection = option
                }
            }
        }
    }
}

private struct MultiOptionList<Option: Identifiable & Hashable>: View {
    let options: [Option]
    @Binding var selection: Set<Option>
    let label: (Option) -> String

    var body: some View {
        VStack(spacing: 16) {
            ForEach(options) { option in
                let isSelected = selection.contains(option)
                OptionButton(title: label(option), isSelected: isSelected, allowsMultiple: true) {
                    if isSelected {
                        selection.remove(option)
                    } else {
                        selection.insert(option)
                    }
                }
            }
        }
    }
}

private struct ActionArea: View {
    let showBack: Bool
    let isPrimaryDisabled: Bool
    let primaryTitle: String
    let onBack: () -> Void
    let onPrimary: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            if showBack {
                Button(action: onBack) {
                    Text("上一步")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            Button(action: onPrimary) {
                Text(primaryTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(primaryBackground)
                    .clipShape(Capsule())
            }
            .disabled(isPrimaryDisabled)
            .opacity(isPrimaryDisabled ? 0.5 : 1)
        }
    }

    private var primaryBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "#A38BFF") ?? .purple,
                Color(hex: "#7F9BFF") ?? .blue
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
