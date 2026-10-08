import Foundation

enum ConnectivityServiceError: LocalizedError {
    case invalidURL
    case requestFailed(underlying: Error)
    case serializationFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无法构建百度请求地址"
        case .requestFailed(let underlying):
            return "网络请求失败：\(underlying.localizedDescription)"
        case .serializationFailed:
            return "JSON 序列化失败"
        }
    }
}

struct ConnectivityService {
    private let session: URLSession
    private let pingURL: URL
    private let dateFormatter: ISO8601DateFormatter

    init(session: URLSession = .shared) throws {
        guard let url = URL(string: "https://www.baidu.com") else {
            throw ConnectivityServiceError.invalidURL
        }
        self.session = session
        self.pingURL = url
        self.dateFormatter = ISO8601DateFormatter()
        self.dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func pingBaidu() async throws -> Bool {
        var request = URLRequest(url: pingURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10

        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return (200..<400).contains(httpResponse.statusCode)
        } catch {
            throw ConnectivityServiceError.requestFailed(underlying: error)
        }
    }

    func buildJSON(
        amount: Decimal,
        purpose: String,
        status: String
    ) throws -> String {
        let payload: [String: Any] = [
            "amount": NSDecimalNumber(decimal: amount),
            "purpose": purpose,
            "status": status,
            "timestamp": dateFormatter.string(from: .now)
        ]

        guard JSONSerialization.isValidJSONObject(payload) else {
            throw ConnectivityServiceError.serializationFailed
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw ConnectivityServiceError.serializationFailed
            }
            return jsonString
        } catch {
            throw ConnectivityServiceError.serializationFailed
        }
    }
}
