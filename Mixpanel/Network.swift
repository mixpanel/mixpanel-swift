//
//  Network.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/2/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation


struct BasePath {
    static var MixpanelAPI = "https://api.mixpanel.com"

    static func buildURL(base: String, path: String) -> URL? {
        guard let url = URL(string: base)?.appendingPathComponent(path) else {
            return nil
        }

        return url
    }

}

enum Method: String {
    case GET
    case POST
}

struct Resource<A> {
    let path: String
    let method: Method
    let requestBody: Data?
    let headers: [String:String]
    let parse: (Data) -> A?
}

enum Reason {
    case parseError
    case noData
    case notOKStatusCode(statusCode: Int)
    case other(NSError)
}

class Network {

    class func apiRequest<A>(base: String,
                          resource: Resource<A>,
                          failure: @escaping (Reason, Data?, URLResponse?) -> (),
                          success: @escaping (A, URLResponse?) -> ()) {
        guard let request = buildURLRequest(base, resource: resource) else {
            return
        }

        let session = URLSession.shared
        session.dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            guard let httpResponse = response as? HTTPURLResponse else {
                failure(Reason.other(error! as NSError), data, response)
                return
            }
            guard httpResponse.statusCode == 200 else {
                failure(Reason.notOKStatusCode(statusCode: httpResponse.statusCode), data, response)
                return
            }
            guard let responseData = data else {
                failure(Reason.noData, data, response)
                return
            }
            guard let result = resource.parse(responseData) else {
                failure(Reason.parseError, data, response)
                return
            }

            success(result, response)
        }) .resume()
    }

    fileprivate class func buildURLRequest<A>(_ base: String, resource: Resource<A>) -> URLRequest? {
        guard let url = BasePath.buildURL(base: base, path: resource.path) else {
            return nil
        }

        let request = NSMutableURLRequest(url: url)
        request.httpMethod = resource.method.rawValue
        request.httpBody = resource.requestBody

        for (k, v) in resource.headers {
            request.setValue(v, forHTTPHeaderField: k)
        }
        return request as URLRequest
    }

    class func buildResource<A>(path: String,
                             method: Method,
                             requestBody: Data?,
                             headers: [String: String],
                             parse: @escaping (Data) -> A?) -> Resource<A> {
        return Resource(path: path, method: method, requestBody: requestBody, headers: headers, parse: parse)
    }

    class func trackIntegration(apiToken: String, completion: @escaping (Bool) -> ()) {
        let properties: [String: Any] = ["token": "85053bf24bba75239b16a601d9387e17",
                          "mp_lib": "swift",
                          "version": "2.3",
                          "distinct_id": apiToken]
        let obj: [String: Any] = ["event": "Integration", "properties": properties]
        let array: [Any] = [obj]
        let requestData = JSONHandler.encodeAPIData(array as JSONHandler.MPObjectToParse)

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

            let resource = Network.buildResource(path: FlushType.Events.rawValue,
                                                 method: Method.POST,
                                                 requestBody: requestBody,
                                                 headers: ["Accept-Encoding": "gzip"],
                                                 parse: responseParser)

            Network.apiRequest(base: BasePath.MixpanelAPI,
                               resource: resource,
                               failure: { (reason, data, response) in
                                Logger.debug(message: "failed to track integration")
                                completion(false)
                },
                               success: { (result, response) in
                                Logger.debug(message: "integration tracked")
                                completion(true)
                }
            )
        }
    }
}
