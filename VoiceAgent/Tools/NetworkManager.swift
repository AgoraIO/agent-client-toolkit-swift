import Foundation

enum NetworkManagerError: LocalizedError {
    case invalidURL(String)
    case requestEncoding(url: String, reason: String)
    case transport(url: String, reason: String)
    case invalidResponse(url: String)
    case httpStatus(statusCode: Int, url: String, message: String?)
    case responseDecoding(url: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let value):
            return "Invalid backend URL: \(value)"
        case .requestEncoding(let url, let reason):
            return "Failed to encode request for \(url): \(reason)"
        case .transport(let url, let reason):
            return "Cannot reach backend at \(url): \(reason)"
        case .invalidResponse(let url):
            return "Backend at \(url) returned an invalid HTTP response"
        case .httpStatus(let statusCode, let url, let message):
            let suffix = message.map { ": \($0)" } ?? ""
            return "Backend request failed (HTTP \(statusCode)) at \(url)\(suffix)"
        case .responseDecoding(let url, let reason):
            return "Backend at \(url) returned an invalid response: \(reason)"
        }
    }
}

final class NetworkManager {
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
    }

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.urlCache = nil
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 30
            self.session = URLSession(configuration: configuration)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    func get<Response: Decodable>(
        url: URL,
        queryItems: [URLQueryItem] = [],
        responseType: Response.Type = Response.self
    ) async throws -> Response {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw NetworkManagerError.invalidURL(url.absoluteString)
        }
        if !queryItems.isEmpty {
            components.queryItems = (components.queryItems ?? []) + queryItems
        }
        guard let resolvedURL = components.url else {
            throw NetworkManagerError.invalidURL(url.absoluteString)
        }

        var request = URLRequest(
            url: resolvedURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 30
        )
        request.httpMethod = HTTPMethod.get.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(request, responseType: responseType)
    }

    func post<Body: Encodable, Response: Decodable>(
        url: URL,
        body: Body,
        responseType: Response.Type = Response.self
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw NetworkManagerError.requestEncoding(
                url: url.absoluteString,
                reason: error.localizedDescription
            )
        }
        return try await perform(request, responseType: responseType)
    }

    private func perform<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type
    ) async throws -> Response {
        #if DEBUG
        print("[NetworkManager] Request cURL: \(request.redactedCURL(pretty: true))")
        #endif

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NetworkManagerError.transport(
                url: request.url?.absoluteString ?? "<unknown>",
                reason: error.localizedDescription
            )
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkManagerError.invalidResponse(
                url: request.url?.absoluteString ?? "<unknown>"
            )
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkManagerError.httpStatus(
                statusCode: httpResponse.statusCode,
                url: request.url?.absoluteString ?? "<unknown>",
                message: Self.serverMessage(from: data)
            )
        }

        do {
            return try decoder.decode(responseType, from: data)
        } catch {
            throw NetworkManagerError.responseDecoding(
                url: request.url?.absoluteString ?? "<unknown>",
                reason: error.localizedDescription
            )
        }
    }

    private static func serverMessage(from data: Data) -> String? {
        guard !data.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return nil
        }

        for key in ["msg", "reason", "detail"] {
            if let value = dictionary[key] as? String, !value.isEmpty {
                return value
            }
        }
        if let details = dictionary["detail"] as? [[String: Any]],
           let first = details.first,
           let message = first["msg"] as? String,
           !message.isEmpty {
            return message
        }
        return nil
    }
}

#if DEBUG
private extension URLRequest {
    func redactedCURL(pretty: Bool = false) -> String {
        let newLine = pretty ? "\\\n" : ""
        let method = (pretty ? "--request " : "-X ") + "\(httpMethod ?? "GET") \(newLine)"
        let url = (pretty ? "--url " : "") + "'\(redactedURLString())' \(newLine)"
        var headers = ""

        for key in (allHTTPHeaderFields ?? [:]).keys.sorted() {
            guard let value = allHTTPHeaderFields?[key] else { continue }
            headers += (pretty ? "--header " : "-H ")
                + "'\(key): \(Self.redactedHeaderValue(key: key, value: value))' \(newLine)"
        }

        var data = ""
        if let httpBody,
           let bodyString = redactedBodyString(from: httpBody),
           !bodyString.isEmpty {
            data = "--data '\(bodyString)'"
        }
        return "curl " + method + url + headers + data
    }

    static func shouldFullyRedact(key: String) -> Bool {
        let key = key.lowercased()
        return key.contains("secret") || key.contains("certificate")
    }

    static func shouldPartiallyRedact(key: String) -> Bool {
        let key = key.lowercased()
        return key.contains("authorization")
            || key.contains("app_id")
            || key.contains("token")
            || key.contains("api_key")
            || key.contains("apikey")
            || key == "key"
            || key == "voice_id"
    }

    static func partialRedactionPrefixLength(key: String) -> Int {
        let key = key.lowercased()
        return key.contains("app_id") || key == "voice_id" ? 2 : 3
    }

    static func partiallyRedact(_ value: String, prefixLength: Int = 3) -> String {
        let prefix = String(value.prefix(prefixLength))
        return prefix.isEmpty ? "<redacted>" : "\(prefix)***"
    }

    static func redactedHeaderValue(key: String, value: String) -> String {
        if shouldFullyRedact(key: key) {
            return "<redacted>"
        }
        guard shouldPartiallyRedact(key: key) else {
            return value
        }
        return partiallyRedact(value, prefixLength: partialRedactionPrefixLength(key: key))
    }

    func redactedURLString() -> String {
        guard let url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url?.absoluteString ?? ""
        }
        components.queryItems = components.queryItems?.map { item in
            guard let value = item.value,
                  Self.shouldPartiallyRedact(key: item.name) || Self.shouldFullyRedact(key: item.name) else {
                return item
            }
            let redacted = Self.shouldFullyRedact(key: item.name)
                ? "<redacted>"
                : Self.partiallyRedact(value, prefixLength: Self.partialRedactionPrefixLength(key: item.name))
            return URLQueryItem(name: item.name, value: redacted)
        }
        return components.url?.absoluteString ?? url.absoluteString
    }

    func redactedBodyString(from bodyData: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: bodyData) else {
            return nil
        }
        guard let data = try? JSONSerialization.data(
            withJSONObject: Self.redact(object),
            options: [.sortedKeys]
        ) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func redact(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, item in
                let key = item.key
                if shouldFullyRedact(key: key) {
                    result[key] = "<redacted>"
                } else if shouldPartiallyRedact(key: key), let string = item.value as? String {
                    result[key] = partiallyRedact(
                        string,
                        prefixLength: partialRedactionPrefixLength(key: key)
                    )
                } else {
                    result[key] = redact(item.value)
                }
            }
        }
        if let array = value as? [Any] {
            return array.map(redact)
        }
        return value
    }
}
#endif
