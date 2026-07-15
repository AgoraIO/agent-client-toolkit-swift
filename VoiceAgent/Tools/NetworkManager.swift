//
//  NetworkManager.swift
//  VoiceAgent
//
//  Generic HTTP helpers.
//
import Foundation

// MARK: - NetworkManager

public class NetworkManager: NSObject {
    enum HTTPMethods: String {
        case GET
        case POST
    }

    public typealias SuccessClosure = ([String: Any]) -> Void
    public typealias FailClosure = (String) -> Void

    private var sessionConfig: URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Content-Type": "application/json",
        ]
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        return config
    }

    public static let shared = NetworkManager()
    
    public func getRequest(urlString: String, params: [String: Any]?, headers: [String: String]? = nil, success: SuccessClosure?, failure: FailClosure?) {
        DispatchQueue.global().async {
            self.request(urlString: urlString, params: params, method: .GET, headers: headers, success: success, failure: failure)
        }
    }

    public func postRequest(urlString: String, params: [String: Any]?, headers: [String: String]? = nil, success: SuccessClosure?, failure: FailClosure?) {
        DispatchQueue.global().async {
            self.request(urlString: urlString, params: params, method: .POST, headers: headers, success: success, failure: failure)
        }
    }

    private func request(urlString: String,
                         params: [String: Any]?,
                         method: HTTPMethods,
                         headers: [String: String]? = nil,
                         success: SuccessClosure?,
                         failure: FailClosure?) {
        let session = URLSession(configuration: sessionConfig)
        guard let request = getRequest(urlString: urlString,
                                       params: params,
                                       method: method,
                                       headers: headers,
                                       success: success,
                                       failure: failure) else { return }
        #if DEBUG
        print("[NetworkManager] Request cURL: \(request.redactedCURL(pretty: true))")
        #endif
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.checkResponse(response: response, data: data, success: success, failure: failure)
            }
        }.resume()
    }

    private func getRequest(urlString: String,
                            params: [String: Any]?,
                            method: HTTPMethods,
                            headers: [String: String]? = nil,
                            success: SuccessClosure?,
                            failure: FailClosure?) -> URLRequest? {
        var string = urlString
        if method == .GET {
            string = string.appendingParameters(parameters: params)
        }
        
        guard let url = URL(string: string) else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add custom request headers
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        if method == .POST {
            // Send an empty JSON object when params is nil.
            let bodyParams = params ?? [:]
            request.httpBody = try? JSONSerialization.data(withJSONObject: bodyParams,
                                                           options: .sortedKeys)
        }
        
        return request
    }

    private func checkResponse(response: URLResponse?, data: Data?, success: SuccessClosure?, failure: FailClosure?) {
        let responseBody: String
        if let data, let body = String(data: data, encoding: .utf8), !body.isEmpty {
            responseBody = body
        } else {
            responseBody = "<empty>"
        }

        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200...299:
                guard let resultData = data, !resultData.isEmpty else {
                    success?([:])
                    return
                }

                do {
                    let result = try JSONSerialization.jsonObject(with: resultData)
                    guard let object = result as? [String: Any] else {
                        failure?("Invalid JSON object response for status code \(httpResponse.statusCode), body: \(responseBody)")
                        return
                    }
                    success?(object)
                } catch {
                    failure?("Invalid JSON response for status code \(httpResponse.statusCode), error: \(error.localizedDescription), body: \(responseBody)")
                }
            default:
                failure?("Error in the request status code \(httpResponse.statusCode), response: \(String(describing: response)), body: \(responseBody)")
            }
        } else {
            failure?("Error in the request status code 400, response: \(String(describing: response)), body: \(responseBody)")
        }
    }
}

#if DEBUG
private extension URLRequest {
    func redactedCURL(pretty: Bool = false) -> String {
        let newLine = pretty ? "\\\n" : ""
        let method = (pretty ? "--request " : "-X ") + "\(httpMethod ?? "GET") \(newLine)"
        let url: String = (pretty ? "--url " : "") + "'\(redactedURLString())' \(newLine)"

        var cURL = "curl "
        var header = ""
        var data = ""

        if let httpHeaders = allHTTPHeaderFields, !httpHeaders.isEmpty {
            for key in httpHeaders.keys.sorted() {
                guard let value = httpHeaders[key] else { continue }
                let redactedValue = Self.redactedHeaderValue(key: key, value: value)
                if key.lowercased() == "content-type" && value.lowercased().contains("multipart/form-data") {
                    header += (pretty ? "--header " : "-H ") + "'\(key): \(redactedValue)' \(newLine)"
                    data = "--data '@image_data'"
                    continue
                }
                header += (pretty ? "--header " : "-H ") + "'\(key): \(redactedValue)' \(newLine)"
            }
        }

        if data.isEmpty, let bodyData = httpBody {
            if let bodyString = redactedBodyString(from: bodyData), !bodyString.isEmpty {
                data = "--data '\(bodyString)'"
            } else {
                data = "--data '@binary_data'"
            }
        }

        cURL += method + url + header + data

        return cURL
    }

    static func shouldFullyRedact(key: String) -> Bool {
        let normalizedKey = key.lowercased()
        return normalizedKey.contains("secret")
            || normalizedKey.contains("certificate")
    }

    static func shouldPartiallyRedact(key: String) -> Bool {
        let normalizedKey = key.lowercased()
        return normalizedKey.contains("authorization")
            || normalizedKey.contains("app_id")
            || normalizedKey.contains("token")
            || normalizedKey.contains("api_key")
            || normalizedKey.contains("apikey")
            || normalizedKey == "key"
            || normalizedKey == "voice_id"
    }

    static func partialRedactionPrefixLength(key: String) -> Int {
        let normalizedKey = key.lowercased()
        if normalizedKey.contains("app_id") || normalizedKey == "voice_id" {
            return 2
        }
        return 3
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

        if key.lowercased().contains("authorization") {
            let prefix = "agora token="
            if value.lowercased().hasPrefix(prefix) {
                let token = String(value.dropFirst(prefix.count))
                return prefix + partiallyRedact(token, prefixLength: 3)
            }
        }

        return partiallyRedact(value, prefixLength: partialRedactionPrefixLength(key: key))
    }

    func redactedURLString() -> String {
        guard let url else { return "" }
        var redactedURL = url.absoluteString
        let projectPattern = #"/projects/([^/]+)"#
        let range = NSRange(location: 0, length: redactedURL.utf16.count)
        guard let regex = try? NSRegularExpression(pattern: projectPattern),
              let match = regex.firstMatch(in: redactedURL, options: [], range: range),
              let appIdRange = Range(match.range(at: 1), in: redactedURL) else {
            return redactedURL
        }

        redactedURL.replaceSubrange(appIdRange, with: Self.partiallyRedact(String(redactedURL[appIdRange]), prefixLength: 2))
        return redactedURL
    }

    func redactedBodyString(from bodyData: Data) -> String? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: bodyData) else {
            return String(data: bodyData, encoding: .utf8)
        }

        let redactedObject = Self.redact(jsonObject)
        guard let redactedData = try? JSONSerialization.data(withJSONObject: redactedObject, options: .sortedKeys) else {
            return String(data: bodyData, encoding: .utf8)
        }
        return String(data: redactedData, encoding: .utf8)
    }

    static func redact(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            var redacted: [String: Any] = [:]
            for (key, value) in dictionary {
                if shouldFullyRedact(key: key) {
                    redacted[key] = "<redacted>"
                } else if shouldPartiallyRedact(key: key), let stringValue = value as? String {
                    redacted[key] = partiallyRedact(stringValue, prefixLength: partialRedactionPrefixLength(key: key))
                } else {
                    redacted[key] = redact(value)
                }
            }
            return redacted
        }

        if let array = value as? [Any] {
            return array.map { redact($0) }
        }

        return value
    }
}
#endif

extension String {
    func appendingParameters(parameters: [String: Any]?) -> String {
        guard let parameters = parameters else {
            return self
        }
        var url = self
        if !parameters.isEmpty {
            let paramComponents = parameters.map { "\($0.key)=\($0.value)" }
            let paramString = paramComponents.joined(separator: "&")
            url += "?\(paramString)"
        }
        return url
    }
}
