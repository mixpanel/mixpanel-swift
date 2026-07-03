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
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(
            of: "+", with: "%2B")
        return components.url
    }

    /// Builds a base URL that targets `backupHost` while preserving the scheme and port of `base`.
    ///
    /// `backupHost` is treated as a host name (e.g. "api-backup.mixpanel.com"), mirroring the
    /// Android SDK's `backupHost`. As a convenience, a full URL (e.g.
    /// "https://api-backup.mixpanel.com") is also accepted — only its host is used; the scheme and
    /// port always come from `base`.
    ///
    /// Returns nil when `base` has no host or the substitution can't produce a valid URL, in which
    /// case the caller should skip the backup attempt.
    static func backupBaseURL(base: String, backupHost: String) -> String? {
        guard var components = URLComponents(string: base), components.host != nil else {
            return nil
        }
        let resolvedHost: String
        if backupHost.contains("://"),
            let parsed = URLComponents(string: backupHost),
            let parsedHost = parsed.host
        {
            resolvedHost = parsedHost
        } else {
            resolvedHost = backupHost
        }
        guard !resolvedHost.isEmpty else {
            return nil
        }
        components.host = resolvedHost
        return components.string
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

public struct ServerProxyResource {
    public init(queryItems: [URLQueryItem]? = nil, headers: [String: String]) {
        self.queryItems = queryItems
        self.headers = headers
    }

    public let queryItems: [URLQueryItem]?
    public let headers: [String: String]
}

class Network {

    var serverURL: String

    /// Optional fallback host (e.g. "api-backup.mixpanel.com"). When set, a request that fails to
    /// reach the primary `serverURL` is retried against this host before being reported as failed.
    var backupHost: String?

    required init(serverURL: String) {
        self.serverURL = serverURL
    }

    class func apiRequest<A>(
        base: String,
        resource: Resource<A>,
        failure: @escaping (Reason, Data?, URLResponse?) -> Void,
        success: @escaping (A, URLResponse?) -> Void
    ) {
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
        guard
            let url = BasePath.buildURL(
                base: base,
                path: resource.path,
                queryItems: resource.queryItems)
        else {
            return nil
        }

        MixpanelLogger.debug(message: "Fetching URL")
        MixpanelLogger.debug(message: url.absoluteURL)
        var request = URLRequest(url: url)
        request.httpMethod = resource.method.rawValue
        request.httpBody = resource.requestBody

        for (k, v) in resource.headers {
            request.setValue(v, forHTTPHeaderField: k)
        }
        return request as URLRequest
    }

    class func buildResource<A>(
        path: String,
        method: RequestMethod,
        requestBody: Data? = nil,
        queryItems: [URLQueryItem]? = nil,
        headers: [String: String],
        parse: @escaping (Data) -> A?
    ) -> Resource<A> {
        return Resource(
            path: path,
            method: method,
            requestBody: requestBody,
            queryItems: queryItems,
            headers: headers,
            parse: parse)
    }
}
