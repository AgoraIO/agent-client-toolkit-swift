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
        print("[NetworkManager] Request cURL: \(request.cURL(pretty: true))")
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
            case 200...201:
                if let resultData = data {
                    let result = try? JSONSerialization.jsonObject(with: resultData)
                    success?(result as! [String : Any])
                } else {
                    failure?("Error in the request status code \(httpResponse.statusCode), response: \(String(describing: response)), body: \(responseBody)")
                }
            default:
                failure?("Error in the request status code \(httpResponse.statusCode), response: \(String(describing: response)), body: \(responseBody)")
            }
        } else {
            failure?("Error in the request status code 400, response: \(String(describing: response)), body: \(responseBody)")
        }
    }
}

public extension URLRequest {
    func cURL(pretty: Bool = false) -> String {
        let newLine = pretty ? "\\\n" : ""
        let method = (pretty ? "--request " : "-X ") + "\(httpMethod ?? "GET") \(newLine)"
        let url: String = (pretty ? "--url " : "") + "\'\(url?.absoluteString ?? "")\' \(newLine)"

        var cURL = "curl "
        var header = ""
        var data = ""

        if let httpHeaders = allHTTPHeaderFields, httpHeaders.keys.count > 0 {
            for (key, value) in httpHeaders {
                if key.lowercased() == "content-type" && value.lowercased().contains("multipart/form-data") {
                    header += (pretty ? "--header " : "-H ") + "\'\(key): \(value)\' \(newLine)"
                    data = "--data '@image_data'"
                    continue
                }
                header += (pretty ? "--header " : "-H ") + "\'\(key): \(value)\' \(newLine)"
            }
        }

        if data.isEmpty, let bodyData = httpBody {
            if let bodyString = String(data: bodyData, encoding: .utf8), !bodyString.isEmpty {
                data = "--data '\(bodyString)'"
            } else {
                data = "--data '@binary_data'"
            }
        }

        cURL += method + url + header + data

        return cURL
    }
}

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
