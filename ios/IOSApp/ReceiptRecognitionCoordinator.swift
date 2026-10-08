import Foundation
import Combine
import SwiftData

struct ReceiptRecognitionCoordinatorConfiguration: Sendable {
    var highBandwidthConcurrentUploads: Int = 3
    var constrainedBandwidthConcurrentUploads: Int = 1
    var retryDelays: [TimeInterval] = [5, 20, 60, 180]
}

@MainActor
final class ReceiptRecognitionCoordinator: ObservableObject {
    @Published private(set) var queue: [PendingReceiptRecognition] = []
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var lastError: Error?

    var onSuccess: ((PendingReceiptRecognition, ReceiptRecognitionResult) -> Void)?
    var onFailure: ((PendingReceiptRecognition, Error) -> Void)?
    var onHistoryChanged: (() -> Void)?
    var onHistoryAppended: ((RecognizedReceiptHistory) -> Void)?

    private let queueStore: ReceiptRecognitionQueueStore
    private let historyStore: ReceiptRecognitionHistoryStore
    private let preprocessor: ReceiptImagePreprocessor
    private let recognitionService: any ReceiptRecognitionService
    private let networkStatusService: NetworkStatusService
    private let configuration: ReceiptRecognitionCoordinatorConfiguration
    private var activeTasks: [UUID: Task<Void, Never>] = [:]
    private var cancellables: Set<AnyCancellable> = []

    init(
        queueStore: ReceiptRecognitionQueueStore,
        historyStore: ReceiptRecognitionHistoryStore,
        preprocessor: ReceiptImagePreprocessor,
        recognitionService: any ReceiptRecognitionService,
        networkStatusService: NetworkStatusService,
        configuration: ReceiptRecognitionCoordinatorConfiguration
    ) {
        self.queueStore = queueStore
        self.historyStore = historyStore
        self.preprocessor = preprocessor
        self.recognitionService = recognitionService
        self.networkStatusService = networkStatusService
        self.configuration = configuration

        networkStatusService.$status
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.scheduleProcessing()
                }
            }
            .store(in: &cancellables)

        Task { @MainActor in
            self.scheduleProcessing()
        }
    }

    // MARK: - Public API

    @discardableResult
    func enqueue(
        imageData: Data,
        billID: String,
        userID: String?,
        token: String?,
        provider: ReceiptRecognitionProvider = .baiduQwen
    ) throws -> PendingReceiptRecognition {
        let processed = try preprocessor.process(imageData: imageData, suggestedFilename: billID)
        let pending = try queueStore.enqueue(
            processedImage: processed,
            provider: provider,
            billID: billID,
            userID: userID,
            tokenSnapshot: token
        )
        scheduleProcessing()
        return pending
    }

    func retry(_ task: PendingReceiptRecognition) {
        do {
            try queueStore.update(task) { pending in
                pending.status = .queued
                pending.nextRetryAt = nil
                pending.lastErrorMessage = nil
            }
        } catch {
            lastError = error
        }
        scheduleProcessing()
    }

    func cancel(_ task: PendingReceiptRecognition) {
        do {
            try queueStore.update(task) { pending in
                pending.status = .cancelled
                pending.nextRetryAt = nil
            }
        } catch {
            lastError = error
        }
        scheduleProcessing()
    }

    func supplyToken(_ token: String) {
        do {
            let missingTokenTasks = try queueStore.fetchMissingToken()
            for task in missingTokenTasks {
                try queueStore.update(task) { pending in
                    pending.tokenSnapshot = token
                    if pending.status == .awaitingRetry {
                        pending.status = .queued
                    }
                    pending.nextRetryAt = nil
                }
            }
        } catch {
            lastError = error
        }
        scheduleProcessing()
    }

    func refresh() {
        scheduleProcessing()
    }

    // MARK: - Internal Scheduling

    private func scheduleProcessing() {
        do {
            queue = try queueStore.fetchQueued()
        } catch {
            lastError = error
            return
        }

        let maxConcurrent = max(currentMaxConcurrentUploads(), 0)
        isProcessing = !activeTasks.isEmpty

        for task in queue {
            guard activeTasks.count < maxConcurrent else { break }
            guard shouldAttempt(task) else { continue }
            start(task)
        }

        isProcessing = !activeTasks.isEmpty
    }

    private func currentMaxConcurrentUploads() -> Int {
        switch networkStatusService.currentStatus.bandwidth {
        case .high:
            return configuration.highBandwidthConcurrentUploads
        case .constrained:
            return configuration.constrainedBandwidthConcurrentUploads
        case .offline:
            return 0
        }
    }

    private func shouldAttempt(_ task: PendingReceiptRecognition) -> Bool {
        if activeTasks[task.id] != nil { return false }
        guard let token = task.tokenSnapshot, !token.isEmpty else { return false }
        if task.status == .awaitingRetry {
            if let nextRetryAt = task.nextRetryAt, nextRetryAt > .now {
                return false
            }
        }
        return true
    }

    private func start(_ task: PendingReceiptRecognition) {
        guard let token = task.tokenSnapshot else { return }

        do {
            try queueStore.update(task) { pending in
                pending.status = .uploading
                pending.lastAttemptAt = .now
                pending.nextRetryAt = nil
                pending.lastErrorMessage = nil
            }
        } catch {
            lastError = error
            return
        }

        let taskID = task.id
        let fileURL = task.imageFileURL
        let billID = task.billID

        let uploadTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            do {
                let data = try Data(contentsOf: fileURL)
                let result = try await self.recognitionService.recognizeWithBaiduQwen(
                    imageData: data,
                    token: token,
                    billID: billID
                )

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    do {
                        if let pendingTask = try self.queueStore.task(withID: taskID) {
                            let encoder = JSONEncoder()
                            encoder.keyEncodingStrategy = .convertToSnakeCase
                            let resultData = try encoder.encode(result)
                            let resultJSON = String(data: resultData, encoding: .utf8)

                            try self.queueStore.update(pendingTask) { pending in
                                pending.status = .completed
                                pending.recognizedAt = .now
                                pending.resultJSON = resultJSON
                                pending.lastErrorMessage = nil
                            }
                            let history = try self.historyStore.append(from: pendingTask, result: result)
                            self.onHistoryAppended?(history)
                            self.onSuccess?(pendingTask, result)
                            self.onHistoryChanged?()
                        }
                    } catch {
                        self.lastError = error
                    }
                }
            } catch {
                await MainActor.run {
                    self.handleFailure(forTaskID: taskID, error: error)
                }
            }

            await MainActor.run {
                self.activeTasks[taskID] = nil
                self.scheduleProcessing()
            }
        }

        activeTasks[taskID] = uploadTask
        isProcessing = true
    }

    private func handleFailure(forTaskID taskID: UUID, error: Error) {
        guard let task = queue.first(where: { $0.id == taskID }) ?? (try? queueStore.task(withID: taskID)) else {
            lastError = error
            return
        }
        handleFailure(for: task, error: error)
    }

    private func handleFailure(for task: PendingReceiptRecognition, error: Error) {
        var message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        var nextDelay = retryDelay(for: task.retryCount)
        var shouldRetry = nextDelay != nil
        var status: ReceiptRecognitionTaskStatus = shouldRetry ? .awaitingRetry : .failed
        var clearToken = false

        if let recognitionError = error as? ReceiptRecognitionError {
            switch recognitionError {
            case .unauthorized(let detail):
                message = detail ?? "登录信息失效，请重新登录后重试。"
                status = .awaitingRetry
                nextDelay = nil
                shouldRetry = true
                clearToken = true
            case .serverError(let statusCode, let detail) where statusCode >= 500:
                message = detail ?? "识别服务暂时不可用，请稍后重试。"
            default:
                break
            }
        } else if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .timedOut, .networkConnectionLost:
                message = "网络连接不可用，等待恢复后将自动重试。"
                status = .awaitingRetry
                if nextDelay == nil {
                    nextDelay = configuration.retryDelays.last ?? 60
                }
                shouldRetry = true
            default:
                break
            }
        }

        do {
            try queueStore.update(task) { pending in
                pending.retryCount += 1
                pending.status = status
                if shouldRetry, let delay = nextDelay {
                    pending.nextRetryAt = Date().addingTimeInterval(delay)
                } else {
                    pending.nextRetryAt = nil
                }
                if clearToken {
                    pending.tokenSnapshot = nil
                }
                pending.lastErrorMessage = message
            }
        } catch {
            lastError = error
        }

        onFailure?(task, error)
    }

    private func retryDelay(for retryCount: Int) -> TimeInterval? {
        guard retryCount < configuration.retryDelays.count else { return nil }
        return configuration.retryDelays[retryCount]
    }
}
