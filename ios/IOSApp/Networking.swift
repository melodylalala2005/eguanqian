import Foundation

struct APIConfiguration {
    var baseURL: URL
    var userID: String
    var recognitionToken: String

    /// 本地联调默认值。正式构建请通过环境变量或 Info.plist 覆盖，不要直接改这里。
    static let `default` = APIConfiguration(
        baseURL: URL(string: ProcessInfo.processInfo.environment["API_BASE_URL"] ??
                     (Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String ?? "http://localhost:8000"))!,
        userID: ProcessInfo.processInfo.environment["API_USER_ID"] ??
            (Bundle.main.object(forInfoDictionaryKey: "APIUserID") as? String ?? "replace-with-user-id"),
        recognitionToken: ProcessInfo.processInfo.environment["OCR_RECOGNITION_TOKEN"] ??
            (Bundle.main.object(forInfoDictionaryKey: "APIRecognitionToken") as? String ?? "")
    )
}

enum APIError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String?)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器返回了无效响应"
        case let .serverError(statusCode, message):
            if let message {
                return "服务器错误 (\(statusCode))：\(message)"
            } else {
                return "服务器错误 (\(statusCode))"
            }
        case let .decodingError(error):
            return "数据解析失败：\(error.localizedDescription)"
        case let .networkError(error):
            return "网络请求失败：\(error.localizedDescription)"
        }
    }
}

struct ManualBillResponse: Decodable {
    let status: String
    let message: String
    let bill_id: String?
}

private struct ManualBillAPIRequest: APIRequest {
    typealias Response = ManualBillResponse

    let payload: Data

    var path: String { "/manual_bill" }
    var method: HTTPMethod { .post }
    var headers: [String: String] { ["Content-Type": "application/json"] }

    func body() throws -> Data? {
        payload
    }
}

@MainActor
protocol BillSyncService {
    func sync(transaction: Transaction, configuration: APIConfiguration) async throws -> ManualBillResponse
}

struct NetworkBillSyncService: BillSyncService {
    private var client: FinanceAPIClient

    init(client: FinanceAPIClient) {
        self.client = client
    }

    func sync(transaction: Transaction, configuration: APIConfiguration) async throws -> ManualBillResponse {
        var workingClient = client
        workingClient.baseURL = configuration.baseURL

        struct RequestBody: Encodable {
            struct Bill: Encodable {
                let billId: String
                let category: String
                let amount: Decimal
                let date: String
                let description: String
                let spendingType: String?
            }

            let userId: String
            let bill: Bill
        }

        struct TransactionMetadata: Decodable {
            let billId: String?
            let spendingType: String?

            enum CodingKeys: String, CodingKey {
                case billId = "bill_id"
                case spendingType = "spending_type"
            }
        }

        let metadata: TransactionMetadata? = {
            guard let raw = transaction.rawJSON,
                  let data = raw.data(using: .utf8) else {
                return nil
            }
            return try? JSONDecoder().decode(TransactionMetadata.self, from: data)
        }()

        let resolvedBillID = metadata?.billId ?? transaction.cloudID ?? transaction.id.uuidString

        let resolvedSpendingType = transaction.spendingType?.rawValue ?? metadata?.spendingType

        let requestBody = RequestBody(
            userId: configuration.userID,
            bill: .init(
                billId: resolvedBillID,
                category: transaction.category?.name ?? "未分类",
                amount: transaction.amount,
                date: Self.dateFormatter.string(from: transaction.occurredAt),
                description: transaction.note?.isEmpty == false ? transaction.note! : transaction.name,
                spendingType: resolvedSpendingType
            )
        )

        let payload: Data
        do {
            workingClient.encoder.keyEncodingStrategy = .convertToSnakeCase
            payload = try workingClient.encoder.encode(requestBody)
        } catch {
            throw APIError.decodingError(error)
        }

        let request = ManualBillAPIRequest(payload: payload)

        do {
            return try await workingClient.send(request)
        } catch let financeError as FinanceAPIError {
            switch financeError {
            case let FinanceAPIError.serverError(statusCode, message):
                throw APIError.serverError(statusCode: statusCode, message: message)
            case let FinanceAPIError.decodingError(decodingError):
                throw APIError.decodingError(decodingError)
            case let FinanceAPIError.transportError(urlError):
                throw APIError.networkError(urlError)
            case FinanceAPIError.invalidURL:
                throw APIError.invalidResponse
            case let FinanceAPIError.encodingError(encodingError):
                throw APIError.decodingError(encodingError)
            }
        } catch {
            throw APIError.networkError(error)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

