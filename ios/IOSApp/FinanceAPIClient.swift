//
//  FinanceAPIClient.swift
//  IOS测试
//
//  Created by GPT-5 Codex on 2025-11-10.
//

import Foundation

/// 表示 HTTP 方法的简单枚举。
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// 统一管理 API 请求身份认证的方式。
enum APIAuthMethod: Equatable {
    case none
    case basic(username: String, password: String)
    case bearer(token: String)

    func apply(to request: inout URLRequest) {
        switch self {
        case .none:
            break
        case let .basic(username, password):
            let credentials = "\(username):\(password)"
            guard let data = credentials.data(using: .utf8) else { return }
            let header = data.base64EncodedString()
            request.setValue("Basic \(header)", forHTTPHeaderField: "Authorization")
        case let .bearer(token):
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
}

/// API 请求约定：描述路径、方法、头、查询参数和可选请求体。
protocol APIRequest {
    associatedtype Response: Decodable
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get }
    var queryItems: [URLQueryItem]? { get }
    func body() throws -> Data?
}

extension APIRequest {
    var headers: [String: String] { [:] }
    var queryItems: [URLQueryItem]? { nil }
    func body() throws -> Data? { nil }
}

/// 统一的 API 错误类型。
enum FinanceAPIError: LocalizedError {
    case invalidURL
    case transportError(URLError)
    case serverError(statusCode: Int, message: String?)
    case decodingError(Error)
    case encodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "请求 URL 无效。"
        case let .transportError(error):
            return "网络请求失败：\(error.localizedDescription)"
        case let .serverError(statusCode, message):
            return "服务器错误 \(statusCode)：\(message ?? "未知错误")"
        case let .decodingError(error):
            return "响应解析失败：\(error.localizedDescription)"
        case let .encodingError(error):
            return "请求编码失败：\(error.localizedDescription)"
        }
    }
}

/// 负责发起网络请求、处理编码解码和身份认证的统一客户端。
struct FinanceAPIClient {
    var baseURL: URL
    var authMethod: APIAuthMethod = .none
    var session: URLSession = .shared
    var encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
    var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    func send<Request: APIRequest>(_ request: Request) async throws -> Request.Response {
        guard var url = URL(string: request.path, relativeTo: baseURL) else {
            throw FinanceAPIError.invalidURL
        }

        if let queryItems = request.queryItems, !queryItems.isEmpty {
            if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                components.queryItems = queryItems
                url = components.url ?? url
            }
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        request.headers.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        if let bodyData = try request.body() {
            urlRequest.httpBody = bodyData
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        authMethod.apply(to: &urlRequest)

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FinanceAPIError.serverError(statusCode: -1, message: "无效的服务器响应")
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8)
                throw FinanceAPIError.serverError(statusCode: httpResponse.statusCode, message: message)
            }
            do {
                return try decoder.decode(Request.Response.self, from: data)
            } catch {
                throw FinanceAPIError.decodingError(error)
            }
        } catch let error as URLError {
            throw FinanceAPIError.transportError(error)
        } catch {
            throw error
        }
    }
}


