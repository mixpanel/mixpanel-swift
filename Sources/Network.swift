//
//  Network.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/2/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

struct BasePath {
    static let DefaultMixpanelAPI = "https://api.mixpanel.com"
    static var namedBasePaths = [String: String]()
    
    static func buildURL(base: String, path: String, queryItems: [URLQueryItem]?) -> URL? {
        guard let url = URL(string: base) else {
            return nil
        }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return nil
        }
        components.path += path
        components.queryItems = queryItems
        // adding workaround to replece + for %2B as it's not done by default within URLComponents
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components.url
    }
    
    static func getServerURL(identifier: String) -> String {
        return namedBasePaths[identifier] ?? DefaultMixpanelAPI
    }
}

enum RequestMethod: String {
    case get
    case post
}

struct Resource<A> {
    let path: String
    let method: RequestMethod
    let requestBody: Data?
    let queryItems: [URLQueryItem]?
    let headers: [String: String]
    let parse: (Data) -> A?
}

enum Reason {
    case parseError
    case noData
    case notOKStatusCode(statusCode: Int)
    case other(Error)
}

class Network {
    
    let basePathIdentifier: String
    
    required init(basePathIdentifier: String) {
        self.basePathIdentifier = basePathIdentifier
    }
    
    class func apiRequest<A>(base: String,
                             resource: Resource<A>,
                             failure: @escaping (Reason, Data?, URLResponse?) -> Void,
                             success: @escaping (A, URLResponse?) -> Void) {
        guard let request = buildURLRequest(base, resource: resource) else {
            return
        }
        
        URLSession.shared.dataTask(with: request) { (data, response, error) -> Void in
            guard let httpResponse = response as? HTTPURLResponse else {
                
                if let hasError = error {
                    failure(.other(hasError), data, response)
                } else {
                    failure(.noData, data, response)
                }
                return
            }
            guard httpResponse.statusCode == 200 else {
                failure(.notOKStatusCode(statusCode: httpResponse.statusCode), data, response)
                return
            }
            guard let responseData = data else {
                failure(.noData, data, response)
                return
            }
            guard let result = resource.parse(responseData) else {
                failure(.parseError, data, response)
                return
            }
            
            success(result, response)
        }.resume()
    }
    
    private class func buildURLRequest<A>(_ base: String, resource: Resource<A>) -> URLRequest? {
        guard let url = BasePath.buildURL(base: base,
                                          path: resource.path,
                                          queryItems: resource.queryItems) else {
            return nil
        }
        
        Logger.debug(message: "Fetching URL")
        Logger.debug(message: url.absoluteURL)
        var request = URLRequest(url: url)
        request.httpMethod = resource.method.rawValue
        request.httpBody = resource.requestBody
        
        for (k, v) in resource.headers {
            request.setValue(v, forHTTPHeaderField: k)
        }
        return request as URLRequest
    }
    
    class func buildResource<A>(path: String,
                                method: RequestMethod,
                                requestBody: Data? = nil,
                                queryItems: [URLQueryItem]? = nil,
                                headers: [String: String],
                                parse: @escaping (Data) -> A?) -> Resource<A> {
        return Resource(path: path,
                        method: method,
                        requestBody: requestBody,
                        queryItems: queryItems,
                        headers: headers,
                        parse: parse)
    }
    
    class func sendHttpEvent(serverURL: String,
                             eventName: String,
                             apiToken: String,
                             distinctId: String,
                             properties: Properties = [:],
                             updatePeople: Bool = true,
                             completion: ((Bool) -> Void)? = nil) {
        let trackProperties = properties.merging(["token": apiToken,
                                                  "mp_lib": "swift",
                                                  "distinct_id": distinctId,
                                                  "$lib_version": AutomaticProperties.libVersion(),
                                                  "Project Token": distinctId,
                                                  "DevX": true]) {(current, _) in current }
        let requestData = JSONHandler.encodeAPIData([["event": eventName, "properties": trackProperties] as [String : Any]])
        
        let responseParser: (Data) -> Int? = { data in
            let response = String(data: data, encoding: String.Encoding.utf8)
            if let response = response {
                return Int(response) ?? 0
            }
            return nil
        }
        
        if let requestData = requestData {
            let requestBody = "ip=1&data=\(requestData)"
                .data(using: String.Encoding.utf8)
            
            let resource = Network.buildResource(path: FlushType.events.rawValue,
                                                 method: .post,
                                                 requestBody: requestBody,
                                                 headers: ["Accept-Encoding": "gzip"],
                                                 parse: responseParser)
            
            Network.apiRequest(base: serverURL,
                               resource: resource,
                               failure: { (_, _, _) in
                Logger.debug(message: "failed to track \(eventName)")
                if let completion = completion {
                    completion(false)
                }
                
            },
                               success: { (_, _) in
                Logger.debug(message: "\(eventName) tracked")
                if let completion = completion {
                    completion(true)
                }
            }
            )
        }
        if updatePeople {
            let engageData = JSONHandler.encodeAPIData([["$token": apiToken, "$distinct_id": distinctId, "$add": [eventName: 1]] as [String : Any]])
            if let engageData = engageData {
                let engageBody = "ip=1&data=\(engageData)".data(using: String.Encoding.utf8)
                let engageResource = Network.buildResource(path: FlushType.people.rawValue,
                                                           method: .post,
                                                           requestBody: engageBody,
                                                           headers: ["Accept-Encoding": "gzip"],
                                                           parse: responseParser)
                Network.apiRequest(base: serverURL, resource: engageResource) { _, _, _ in } success: { _, _ in }
            }
        }
    }
}
