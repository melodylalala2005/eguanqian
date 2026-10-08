import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import PhotosUI

struct DashboardHeaderView: View {
    @ObservedObject var viewModel: DashboardViewModel

    private var addSheetBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isAddSheetPresented },
            set: { viewModel.isAddSheetPresented = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(viewModel.greeting)！👋")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
            Text("鹅来守护你的财务健康💪")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.55))

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(StatisticsPalette.expense)
                    .padding(.top, 6)
            } else if let info = viewModel.infoMessage {
                Text(info)
                    .font(.footnote)
                    .foregroundStyle(StatisticsPalette.mutedText)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.top, 8)
        .sheet(isPresented: addSheetBinding) {
            QuickAddTransactionSheet(viewModel: viewModel)
        }
    }
}

private struct QuickAddTransactionSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isImportingMedia: Bool = false
    @State private var isHistoryPresented: Bool = false
    #if canImport(UIKit)
    @State private var isCameraPresented: Bool = false
    #endif

    private enum Field {
        case name
        case amount
        case note
    }

    private var categoryOptions: [CategoryOption] {
        viewModel.categoryOptions(for: viewModel.draft.type)
    }

    private let categoryGrid: [GridItem] = [
        GridItem(.adaptive(minimum: 96), spacing: 16)
    ]

    private func categoryTile(for option: CategoryOption, isSelected: Bool) -> some View {
        VStack(spacing: 6) {
            Text(option.emoji)
                .font(.title3)
            Text(option.name)
                .font(.footnote)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(
                    color: Color.black.opacity(isSelected ? 0.12 : 0.06),
                    radius: isSelected ? 12 : 8,
                    y: isSelected ? 8 : 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isSelected ? StatisticsPalette.primary : Color.clear,
                    lineWidth: 2
                )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("交易名称")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("例如：星巴克咖啡", text: $viewModel.draft.name)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .name)
                    }

                    Group {
                        Text("金额")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $viewModel.draftAmountText)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .amount)
                    }

                    Group {
                        Text("类型")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("", selection: Binding(
                            get: { viewModel.draft.type },
                            set: { viewModel.updateType($0) }
                        )) {
                            Text("支出").tag(TransactionType.expense)
                            Text("收入").tag(TransactionType.income)
                        }
                        .pickerStyle(.segmented)
                    }

                    if viewModel.draft.type == .expense {
                        spendingTypeSection
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("分类")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if categoryOptions.isEmpty {
                            Text("暂无分类，请先在数据层添加分类。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            LazyVGrid(columns: categoryGrid, spacing: 16) {
                                ForEach(categoryOptions) { option in
                                    Button {
                                        viewModel.selectCategory(option.id)
                                    } label: {
                                        categoryTile(for: option, isSelected: viewModel.isCategorySelected(option.id))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    Group {
                        Text("日期")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker(
                            "",
                            selection: $viewModel.draftDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("备注")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("可选备注", text: $viewModel.draftNote, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .note)
                    }

                    recognitionSection

                    if let info = viewModel.infoMessage {
                        Text(info)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("添加交易")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        viewModel.resetDraft()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.submitDraft()
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .tint(.accentColor)
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(viewModel.isSubmitting)
                }
            }
        }
        .task {
            viewModel.refreshRecognitionQueue()
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            handleSelectedPhotos(newItems)
        }
        .sheet(isPresented: $isHistoryPresented) {
            RecognitionHistorySheet(viewModel: viewModel)
        }
        #if canImport(UIKit)
        .sheet(isPresented: $isCameraPresented) {
            ReceiptCameraCaptureView(
                isPresented: $isCameraPresented,
                onCapture: { data in
                    handleCameraCapture(data)
                },
                onCancel: {
                    handleCameraCancellation()
                }
            )
        }
        #endif
    }

    @ViewBuilder
    private var recognitionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("自动识别", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Toggle(isOn: Binding(
                    get: { viewModel.recognitionFlowSavingEnabled },
                    set: { viewModel.setRecognitionFlowSavingMode($0) }
                )) {
                    Text("节约流量")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .labelsHidden()
            }

            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 10,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    if isImportingMedia {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                    Text(isImportingMedia ? "正在导入图片..." : "从相册选择账单图片（可多选）")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Spacer()
                    if !selectedPhotoItems.isEmpty {
                        Text("已选 \(selectedPhotoItems.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.accentColor.opacity(0.12))
                .foregroundStyle(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(isImportingMedia)

            #if canImport(UIKit)
            Button {
                presentCamera()
            } label: {
                HStack {
                    Image(systemName: "camera")
                    Text("拍照识别账单")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.accentColor.opacity(0.12))
                .foregroundStyle(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(isImportingMedia)
            #endif

            if let result = viewModel.lastRecognitionResult {
                recognitionResultSummary(result)
            }

            queueSection

            Button {
                isHistoryPresented = true
            } label: {
                Label("查看识别历史", systemImage: "clock.arrow.circlepath")
                    .font(.footnote.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var spendingTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("支出类型")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if selectedSpendingType != nil {
                    Button("清除") {
                        viewModel.setSpendingType(nil)
                    }
                    .font(.caption)
                }
            }

            HStack(spacing: 12) {
                ForEach(SpendingType.allCases) { type in
                    Button {
                        toggleSpendingType(type)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: type.iconName)
                            Text(type.rawValue)
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white)
                            .shadow(
                                color: Color.black.opacity(selectedSpendingType == type ? 0.15 : 0.05),
                                radius: selectedSpendingType == type ? 12 : 6,
                                y: selectedSpendingType == type ? 8 : 3
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                selectedSpendingType == type ? StatisticsPalette.primary : Color.clear,
                                lineWidth: 2
                            )
                    )
                }
            }

            Text(selectedSpendingType?.rawValue ?? "尚未选择支出类型。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("识别任务队列")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if viewModel.isRecognitionProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                Button {
                    viewModel.refreshRecognitionQueue()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if viewModel.recognitionQueue.isEmpty {
                Text("当前没有待处理的识别任务。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.recognitionQueue, id: \.id) { task in
                        queueRow(for: task)
                        if task.id != viewModel.recognitionQueue.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func queueRow(for task: PendingReceiptRecognition) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("账单 ID：\(task.billID)")
                    .font(.footnote.weight(.semibold))
                Spacer()
                Text(statusDescription(for: task.status))
                    .font(.footnote)
                    .foregroundStyle(statusColor(for: task.status))
            }

            if let next = nextRetryDescription(for: task) {
                Text(next)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = task.lastErrorMessage, !error.isEmpty {
                Text("错误：\(error)")
                    .font(.caption)
                    .foregroundStyle(StatisticsPalette.expense)
            }

            HStack(spacing: 12) {
                if canRetry(task) {
                    Button {
                        viewModel.retryRecognitionTask(task)
                    } label: {
                        Text("重试")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if canCancel(task) {
                    Button(role: .destructive) {
                        viewModel.cancelRecognitionTask(task)
                    } label: {
                        Text("取消")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func recognitionResultSummary(_ result: ReceiptRecognitionResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("最近识别结果")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("已自动记账")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .clipShape(Capsule())
                Button {
                    viewModel.clearRecognitionResult()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text("金额：\(viewModel.decimalString(result.amount.magnitude))")
                .font(.footnote)
            Text("日期：\(result.date)")
                .font(.footnote)
            Text("分类：\(result.category)")
                .font(.footnote)
            if let classification = result.spendingCategoryName {
                Text("支出类型：\(classification)")
                    .font(.footnote)
            }
            if !result.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("描述：\(result.description)")
                    .font(.footnote)
            }
            Text("这笔账单已自动写入最近交易。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func canRetry(_ task: PendingReceiptRecognition) -> Bool {
        task.status == .failed || task.status == .awaitingRetry
    }

    private func canCancel(_ task: PendingReceiptRecognition) -> Bool {
        !task.status.isTerminal
    }

    private func statusDescription(for status: ReceiptRecognitionTaskStatus) -> String {
        switch status {
        case .queued:
            return "待上传"
        case .preprocessing:
            return "预处理"
        case .uploading:
            return "上传中"
        case .awaitingRetry:
            return "等待重试"
        case .completed:
            return "已完成"
        case .failed:
            return "失败"
        case .cancelled:
            return "已取消"
        }
    }

    private var selectedSpendingType: SpendingType? {
        viewModel.draft.spendingType
    }

    private func toggleSpendingType(_ type: SpendingType) {
        if selectedSpendingType == type {
            viewModel.setSpendingType(nil)
        } else {
            viewModel.setSpendingType(type)
        }
    }

    private func statusColor(for status: ReceiptRecognitionTaskStatus) -> Color {
        switch status {
        case .completed:
            return .green
        case .failed:
            return StatisticsPalette.expense
        case .cancelled:
            return .secondary
        case .awaitingRetry:
            return .orange
        case .uploading:
            return .accentColor
        case .queued, .preprocessing:
            return .secondary
        }
    }

    private func nextRetryDescription(for task: PendingReceiptRecognition) -> String? {
        if task.status == .awaitingRetry, let next = task.nextRetryAt {
            let relative = QuickAddTransactionSheet.retryFormatter.localizedString(for: next, relativeTo: Date())
            return "下一次重试：\(relative)"
        }
        if task.status == .uploading {
            return "正在上传..."
        }
        if task.status == .completed, let date = task.recognizedAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return "完成时间：" + formatter.string(from: date)
        }
        return nil
    }

    private func handleSelectedPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }

        Task {
            await MainActor.run {
                isImportingMedia = true
            }

            var successCount = 0
            var failureMessages: [String] = []

            for item in items {
                do {
                    if let data = try await loadImageData(from: item) {
                        await MainActor.run {
                            viewModel.enqueueReceiptImage(data)
                        }
                        successCount += 1
                    } else {
                        failureMessages.append("无法读取所选图片，请重试。")
                    }
                } catch {
                    failureMessages.append(error.localizedDescription)
                }
            }

            await MainActor.run {
                isImportingMedia = false
                selectedPhotoItems = []

                if successCount > 1 {
                    viewModel.infoMessage = "已加入 \(successCount) 张图片至识别队列。"
                }

                if failureMessages.isEmpty {
                    if successCount > 0 {
                        viewModel.errorMessage = nil
                    }
                } else {
                    viewModel.errorMessage = failureMessages.joined(separator: "\n")
                }
            }
        }
    }

    private func loadImageData(from item: PhotosPickerItem) async throws -> Data? {
        try await item.loadTransferable(type: Data.self)
    }

    #if canImport(UIKit)
    private func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            viewModel.errorMessage = "当前设备不支持拍照，请改用相册导入。"
            return
        }
        isCameraPresented = true
    }

    private func handleCameraCapture(_ data: Data) {
        Task { @MainActor in
            isCameraPresented = false
            isImportingMedia = true
            viewModel.enqueueReceiptImage(data)
            isImportingMedia = false
        }
    }

    private func handleCameraCancellation() {
        Task { @MainActor in
            isCameraPresented = false
        }
    }
    #endif

    private static let retryFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .numeric
        formatter.unitsStyle = .short
        return formatter
    }()
}

private struct RecognitionHistorySheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.recognitionHistory.isEmpty {
                    ContentUnavailableView(
                        "暂无识别历史",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("完成识别后会在此展示，便于重复使用。")
                    )
                } else {
                    List {
                        ForEach(viewModel.recognitionHistory, id: \.id) { item in
                            historyRow(item)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                guard viewModel.recognitionHistory.indices.contains(index) else { continue }
                                let item = viewModel.recognitionHistory[index]
                                viewModel.deleteHistoryItem(item)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("识别历史")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("刷新") {
                        viewModel.refreshRecognitionHistory()
                    }
                }
            }
            .onAppear {
                viewModel.refreshRecognitionHistory()
            }
        }
    }

    private func historyRow(_ item: RecognizedReceiptHistory) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(dateFormatter.string(from: item.recognizedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let result = item.result {
                    Text(result.description.isEmpty ? result.category : result.description)
                        .font(.headline)
                    Text("金额：" + viewModel.decimalString(result.amount.magnitude))
                        .font(.footnote)
                    Text("日期：" + result.date)
                        .font(.footnote)
                    Text("分类：" + result.category)
                        .font(.footnote)
                    if let classification = result.spendingCategoryName {
                        Text("支出类型：" + classification)
                            .font(.footnote)
                    }
                } else {
                    Text("无法解析识别内容")
                        .font(.footnote)
                        .foregroundStyle(StatisticsPalette.expense)
                }

                if let appliedID = item.appliedTransactionID {
                    Text("已应用到交易：\(appliedID.uuidString.prefix(8))…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(spacing: 8) {
                statusChip(for: item)

                Button(role: .destructive) {
                    viewModel.deleteHistoryItem(item)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func statusChip(for item: RecognizedReceiptHistory) -> some View {
        if item.appliedTransactionID != nil {
            Text("已自动记账")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.15))
                .foregroundStyle(Color.green)
                .clipShape(Capsule())
        } else {
            Text("等待处理")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15))
                .foregroundStyle(Color.orange)
                .clipShape(Capsule())
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

struct BudgetSummaryCardView: View {
    var summary: BudgetSummary?
    var isLoading: Bool

    private let gradient = LinearGradient(
        colors: [
            Color(hex: "#5F52F3") ?? Color.indigo,
            Color(hex: "#4338F6") ?? Color.blue
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(gradient)

            VStack(alignment: .leading, spacing: 20) {
                Text("本月总支出")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))

                if let summary {
                    Text(summary.spent.formattedCurrency())
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 16) {
                        summaryMetric(title: "预算", value: summary.total)
                        Spacer()
                        summaryMetric(title: "剩余", value: summary.remaining)
                    }

                    progressSection(for: summary)
                } else if isLoading {
                    VStack(alignment: .leading, spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("正在加载预算信息…")
                            .font(.footnote)
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("暂无预算数据")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("添加预算计划即可开始追踪支出。")
                            .font(.footnote)
                            .foregroundStyle(Color.white.opacity(0.75))
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("$")
                .font(.system(size: 80, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.12))
                .padding(.trailing, 28)
                .padding(.top, 18)
        }
        .shadow(color: Color(hex: "#4338F6")?.opacity(0.2) ?? .black.opacity(0.2), radius: 18, y: 12)
    }

    private func summaryMetric(title: String, value: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.75))
            Text(value.formattedCurrency())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
    }

    private func progressSection(for summary: BudgetSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(height: 8)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(8, proxy.size.width * CGFloat(summary.progress)), height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text("已使用 \(Int(summary.progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.85))
                Spacer()
                Text("剩余 \(summary.daysLeft) 天")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.85))
            }
        }
    }
}

struct TransactionsListSectionView: View {
    @ObservedObject var viewModel: TransactionsViewModel
    var onAddTransaction: () -> Void

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("最近交易")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: onAddTransaction) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#5F52F3") ?? Color.indigo,
                                    Color(hex: "#4338F6") ?? Color.blue
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("新增一笔交易")
            }

            if viewModel.isLoading {
                ProgressView("正在加载交易…")
                    .progressViewStyle(.circular)
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(StatisticsPalette.expense)
            } else if viewModel.sections.isEmpty {
                Text("暂时还没有账单记录，点击右上角按钮开始记账吧。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 20) {
                    ForEach(displayedSections) { section in
                        VStack(alignment: .leading, spacing: 16) {
                            Text(sectionTitle(for: section.date))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.secondary)

                            let transactions = displayedTransactions(for: section)
                            ForEach(Array(transactions.enumerated()), id: \.element.id) { pair in
                                let index = pair.offset
                                let transaction = pair.element
                                transactionRow(transaction)
                                if index < transactions.count - 1 {
                                    Divider()
                                        .padding(.leading, 52)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 16, y: 10)
        .sheet(isPresented: editorSheetBinding, onDismiss: {
            viewModel.cancelEditing()
        }) {
            TransactionEditorSheet(viewModel: viewModel)
        }
    }

    private func transactionRow(_ transaction: Transaction) -> some View {
        HStack(spacing: 16) {
            Text(transaction.category?.emoji ?? "💵")
                .font(.system(size: 22))
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(Color(uiColor: .systemGray6))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(transaction.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(transaction.category?.name ?? "未分类")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.primary.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#EEF0FF") ?? Color(uiColor: .systemGray5))
                        .clipShape(Capsule())

                    Text(timeFormatter.string(from: transaction.occurredAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(formattedAmount(for: transaction))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(transaction.type == .income ? StatisticsPalette.income : StatisticsPalette.expense)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.beginEditing(transaction)
        }
    }

    private func formattedAmount(for transaction: Transaction) -> String {
        let sign = transaction.type == .income ? "+" : "-"
        return sign + transaction.amount.formattedCurrency()
    }

    private var displayedSections: [TransactionSection] {
        Array(viewModel.sections.prefix(3))
    }

    private func displayedTransactions(for section: TransactionSection) -> [Transaction] {
        Array(section.transactions.prefix(5))
    }

    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        }
        return dateFormatter.string(from: date)
    }

    private var editorSheetBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isPresentingEditor },
            set: { newValue in
                if newValue {
                    viewModel.isPresentingEditor = true
                } else {
                    viewModel.cancelEditing()
                }
            }
        )
    }

}

private struct TransactionEditorSheet: View {
    @ObservedObject var viewModel: TransactionsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if let state = viewModel.editorState {
                Form {
                    Section("交易名称") {
                        TextField("请输入名称", text: Binding(
                            get: { viewModel.editorState?.name ?? "" },
                            set: { viewModel.updateEditorName($0) }
                        ))
                        .textInputAutocapitalization(.none)
                    }

                    Section("金额") {
                        TextField("0.00", text: Binding(
                            get: { viewModel.editorState?.amountText ?? "" },
                            set: { viewModel.updateEditorAmount($0) }
                        ))
                        .keyboardType(.decimalPad)
                    }

                    Section("类型与分类") {
                        Picker("类型", selection: Binding(
                            get: { viewModel.editorState?.type ?? .expense },
                            set: { viewModel.updateEditorType($0) }
                        )) {
                            Text("支出").tag(TransactionType.expense)
                            Text("收入").tag(TransactionType.income)
                        }
                        .pickerStyle(.segmented)

                        if state.type == .expense {
                            editorSpendingTypeSection(state: state)
                        }

                        categoryGrid(for: state.type)
                            .padding(.top, 6)
                    }

                    Section("日期") {
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { viewModel.editorState?.date ?? .now },
                                set: { viewModel.updateEditorDate($0) }
                            ),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                    }

                    Section("备注") {
                        TextField("可选备注", text: Binding(
                            get: { viewModel.editorState?.note ?? "" },
                            set: { viewModel.updateEditorNote($0) }
                        ), axis: .vertical)
                    }

                    if let error = viewModel.errorMessage {
                        Section {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(StatisticsPalette.expense)
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            viewModel.deleteCurrent()
                            dismiss()
                        } label: {
                            Text("删除这条记录")
                        }
                    }
                }
                .navigationTitle("编辑交易")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            viewModel.cancelEditing()
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task {
                                await viewModel.saveEditor()
                                if viewModel.editorState == nil {
                                    dismiss()
                                }
                            }
                        } label: {
                            if viewModel.isSaving {
                                ProgressView()
                            } else {
                                Text("保存")
                            }
                        }
                        .disabled(viewModel.isSaving)
                    }
                }
            } else {
                ProgressView("正在准备编辑…")
                    .navigationTitle("编辑交易")
            }
        }
    }

    @ViewBuilder
    private func categoryGrid(for type: TransactionType) -> some View {
        let options = viewModel.categoryOptions(for: type)
        if options.isEmpty {
            Text("暂无分类，请先添加分类。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 12)], spacing: 12) {
                ForEach(options) { option in
                    Button {
                        viewModel.selectEditorCategory(option.id)
                    } label: {
                        VStack(spacing: 6) {
                            Text(option.emoji)
                                .font(.title3)
                            Text(option.name)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .background(
                        viewModel.isEditorCategorySelected(option.id)
                        ? StatisticsPalette.primary.opacity(0.15)
                        : Color(uiColor: .secondarySystemBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                viewModel.isEditorCategorySelected(option.id)
                                ? StatisticsPalette.primary
                                : Color.clear,
                                lineWidth: 2
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private func editorSpendingTypeSection(state: TransactionsViewModel.EditorState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("支出类型")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(SpendingType.allCases) { type in
                    Button {
                        if state.spendingType == type {
                            viewModel.updateEditorSpendingType(nil)
                        } else {
                            viewModel.updateEditorSpendingType(type)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: type.iconName)
                            Text(type.rawValue)
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white)
                            .shadow(
                                color: Color.black.opacity(state.spendingType == type ? 0.15 : 0.05),
                                radius: state.spendingType == type ? 12 : 6,
                                y: state.spendingType == type ? 8 : 3
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                state.spendingType == type ? StatisticsPalette.primary : Color.clear,
                                lineWidth: 2
                            )
                    )
                }
            }
        }
    }
}

private extension SpendingType {
    var iconName: String {
        switch self {
        case .basic: return "creditcard.fill"
        case .entertainment: return "sparkles"
        }
    }
}

struct AchievementBadgesView: View {
    @ObservedObject var viewModel: AchievementsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("成就进度", systemImage: "medal.fill")
                    .font(.headline)
                Spacer()
                Text("已达成 \(viewModel.unlockedCount)/\(viewModel.totalCount)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: viewModel.progressPercent) {
                Text("整体进度")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .progressViewStyle(.linear)

            if viewModel.streakDays > 0 {
                Text("连续记账：\(viewModel.streakDays) 天")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if viewModel.badges.isEmpty {
                Text("还没有解锁任何徽章，坚持记账就能获得奖励！")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.badges, id: \.self) { badge in
                            Text(badge)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(StatisticsPalette.badgeBackground)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            let highlighted = Array(viewModel.achievements.prefix(3))
            if highlighted.isEmpty {
                Text("继续努力解锁更多成就！")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(highlighted) { item in
                        AchievementRow(item: item)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 16, y: 10)
    }
}

private struct AchievementRow: View {
    let item: AchievementDetailItem

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: item.iconName)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(item.color)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                    if item.isUnlocked {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                }
                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ProgressView(value: item.progressPercent) {
                    Text(item.isUnlocked ? "已解锁" : "进度 \(Int(item.progressPercent * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .progressViewStyle(.linear)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}