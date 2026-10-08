import Combine
import SwiftUI

struct AIChatRootView: View {
    @StateObject private var viewModel: AIChatViewModel
    @EnvironmentObject private var router: AppDeepLinkRouter

    init(environment: FinanceEnvironment) {
        _viewModel = StateObject(wrappedValue: environment.makeAIChatViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if viewModel.messages.count == 1 {
                quickPrompts
            }
            Divider()
            messageList
            inputArea
        }
        .background(
            LinearGradient(
                colors: [StatisticsPalette.pageBackgroundTop, StatisticsPalette.pageBackgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("AI 理财助手")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.isSettingsPresented) {
            settingsSheet
        }
        .onReceive(router.$pendingAIChatMessage.compactMap { $0 }) { _ in
            processPendingMessageIfNeeded()
        }
        .task {
            processPendingMessageIfNeeded()
        }
    }

    private func processPendingMessageIfNeeded() {
        if let message = router.consumeAIChatMessage() {
            DeepLinkDiagnostics.log("AIChatView", "Injecting pending AI message length=\(message.count)")
            viewModel.injectAssistantBroadcast(message)
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(StatisticsPalette.primary.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(StatisticsPalette.primary)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text("AI 理财助手")
                    .font(.headline)
                Text(viewModel.personaDisplayName)
                    .font(.subheadline.weight(.semibold))
                Text(viewModel.personaSubtitle)
                    .font(.caption)
                    .foregroundStyle(StatisticsPalette.mutedText)
            }
            Spacer()
            HStack(spacing: 8) {
                Button {
                    viewModel.voiceEnabled.toggle()
                } label: {
                    Image(systemName: viewModel.voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 18, weight: .medium))
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.isSettingsPresented = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .medium))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var quickPrompts: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("快速开始")
                .font(.footnote.weight(.medium))
                .foregroundStyle(StatisticsPalette.mutedText)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(viewModel.quickPrompts) { prompt in
                    Button {
                        viewModel.handleQuickPrompt(prompt)
                    } label: {
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: prompt.iconName)
                                .font(.system(size: 16))
                                .foregroundStyle(prompt.tint)
                            Text(prompt.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: StatisticsPalette.cardShadow.opacity(0.7), radius: 10, y: 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(viewModel.messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let lastID = viewModel.messages.last?.id {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var inputArea: some View {
        VStack(spacing: 8) {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack(spacing: 12) {
                TextField("输入你的问题...", text: $viewModel.input)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        viewModel.send()
                    }
                Button {
                    viewModel.send()
                } label: {
                    Image(systemName: viewModel.isSending ? "hourglass" : "paperplane.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(viewModel.input.trimmingCharacters(in: .whitespaces).isEmpty ? StatisticsPalette.mutedText : Color.white)
                        .padding(12)
                        .background(viewModel.input.trimmingCharacters(in: .whitespaces).isEmpty ? StatisticsPalette.primarySoft : StatisticsPalette.primary)
                        .clipShape(Circle())
                }
                .disabled(viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(Color(uiColor: .systemBackground).opacity(0.9))
    }

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("AI 性格") {
                    ForEach(AIPersonality.allCases, id: \.self) { personality in
                        Button {
                            viewModel.selectedPersonality = personality
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(personality.displayName)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text(personality.description)
                                        .font(.caption)
                                        .foregroundStyle(StatisticsPalette.mutedText)
                                }
                                Spacer()
                                if viewModel.selectedPersonality == personality {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(StatisticsPalette.primary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("自定义性格") {
                    CustomPersonaCard(viewModel: viewModel)
                }

                Section("语音选择") {
                    Picker("语音", selection: $viewModel.selectedVoice) {
                        ForEach(AIVoice.allCases, id: \.self) { voice in
                            Text(voice.displayName)
                                .tag(voice)
                        }
                    }
                    VoiceCloneCard(viewModel: viewModel)
                }
            }
            .navigationTitle("AI 助手设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        viewModel.isSettingsPresented = false
                    }
                }
            }
            .sheet(isPresented: $viewModel.isCustomPersonaEditorPresented) {
                CustomPersonaEditorView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.isVoiceCloneSheetPresented) {
                VoiceCloneSheet(viewModel: viewModel)
            }
        }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .assistant {
                bubble
                Spacer()
            } else {
                Spacer()
                bubble
            }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            if message.role == .assistant {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(StatisticsPalette.primary)
                    Text("AI 助手")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(StatisticsPalette.primary)
                }
            }
            Text(message.content)
                .font(.body)
                .foregroundStyle(message.role == .assistant ? Color.primary : Color.white)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(message.role == .assistant ? Color.white : StatisticsPalette.primary)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: StatisticsPalette.cardShadow.opacity(message.role == .assistant ? 1 : 0.5), radius: 10, y: 5)
    }
}

// MARK: - Settings Support Views

private struct CustomPersonaCard: View {
    @ObservedObject var viewModel: AIChatViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.customPersona == nil ? "开启自定义性格" : "当前自定义性格")
                        .font(.headline)
                    Text(viewModel.customPersona?.summary ?? "打造独一无二的表达方式，让 AI 更贴近你的口吻。")
                        .font(.caption)
                        .foregroundStyle(StatisticsPalette.mutedText)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if viewModel.useCustomPersona, viewModel.customPersona != nil {
                    Text("已启用")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(StatisticsPalette.primary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 12) {
                Button {
                    viewModel.isCustomPersonaEditorPresented = true
                } label: {
                    HStack(spacing: 6) {
                        Spacer(minLength: 0)
                        Image(systemName: "slider.horizontal.3")
                        Text(viewModel.customPersona == nil ? "创建性格" : "编辑性格")
                        Spacer(minLength: 0)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if viewModel.customPersona != nil {
                    Button(role: .destructive) {
                        viewModel.clearCustomPersona()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }

            Toggle(isOn: $viewModel.useCustomPersona) {
                Text("启用自定义性格")
                    .font(.subheadline)
            }
            .disabled(viewModel.customPersona == nil)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

private struct VoiceCloneCard: View {
    @ObservedObject var viewModel: AIChatViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("克隆音色")
                        .font(.headline)
                    Text(viewModel.clonedVoice?.subtitle ?? "上传 15 秒语音样本，生成专属于你的 AI 声音。")
                        .font(.caption)
                        .foregroundStyle(StatisticsPalette.mutedText)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if viewModel.isCloningVoice {
                    ProgressView(value: viewModel.voiceCloneProgress)
                        .frame(width: 70)
                }
            }

            Button {
                viewModel.isVoiceCloneSheetPresented = true
            } label: {
                HStack {
                    Image(systemName: "mic.fill.badge.plus")
                    Text(viewModel.clonedVoice == nil ? "开始克隆" : "管理克隆音色")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Toggle(isOn: $viewModel.useClonedVoice) {
                Text("启用克隆音色播放")
                    .font(.subheadline)
            }
            .disabled(viewModel.clonedVoice == nil)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

private struct CustomPersonaEditorView: View {
    @ObservedObject var viewModel: AIChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var toneKeywords: String
    @State private var guidance: String
    @State private var validationMessage: String?

    init(viewModel: AIChatViewModel) {
        self._viewModel = ObservedObject(initialValue: viewModel)
        if let persona = viewModel.customPersona {
            _name = State(initialValue: persona.name)
            _toneKeywords = State(initialValue: persona.toneKeywords)
            _guidance = State(initialValue: persona.guidance)
        } else {
            _name = State(initialValue: "")
            _toneKeywords = State(initialValue: "")
            _guidance = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("角色名称") {
                    TextField("例如：冷静分析师", text: $name)
                }
                Section("表达关键词") {
                    TextField("例如：理性、沉着、逻辑清晰", text: $toneKeywords)
                }
                Section("回复风格 & 指南") {
                    TextEditor(text: $guidance)
                        .frame(minHeight: 120)
                }
                if let message = validationMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("自定义性格")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        savePersona()
                    }
                }
            }
        }
    }

    private func savePersona() {
        let draft = CustomPersonaDraft(name: name, toneKeywords: toneKeywords, guidance: guidance)
        guard viewModel.saveCustomPersonaDraft(draft) else {
            validationMessage = "请填写完整的名称、关键词和回复指南。"
            return
        }
        validationMessage = nil
        dismiss()
    }
}

private struct VoiceCloneSheet: View {
    @ObservedObject var viewModel: AIChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("上传 15 秒左右的语音样本，我们会生成与你声线相似的 AI 音色，用于朗读助手回复。")
                    .font(.body)
                    .foregroundStyle(StatisticsPalette.mutedText)

                if viewModel.isCloningVoice {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("正在克隆中……")
                            .font(.headline)
                        ProgressView(value: viewModel.voiceCloneProgress)
                            .progressViewStyle(.linear)
                        Text("\(Int(viewModel.voiceCloneProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(StatisticsPalette.mutedText)
                    }
                } else if let profile = viewModel.clonedVoice {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("克隆成功")
                            .font(.headline)
                        Text(profile.subtitle)
                            .font(.caption)
                            .foregroundStyle(StatisticsPalette.mutedText)
                    }
                }

                if let error = viewModel.voiceCloneErrorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    viewModel.beginVoiceCloneSimulation()
                } label: {
                    Label(viewModel.isCloningVoice ? "正在克隆..." : "上传并克隆", systemImage: "waveform.badge.mic")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isCloningVoice)

                if viewModel.clonedVoice != nil {
                    Button("重置克隆音色", role: .destructive) {
                        viewModel.resetClonedVoice()
                    }
                    .frame(maxWidth: .infinity)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("克隆音色")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

