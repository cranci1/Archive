//
//  InstagramAPIClient.swift
//  Bloom
//
//  Created by Francesco on 04/05/26.
//

import SwiftZSTD
import SwiftyJSON
import Foundation

private struct GraphQLVariables: Encodable {
    let id: String
    let include_reel: Bool
    let fetch_mutual: Bool
    let first: Int
    let after: String?
}

private final class LogManager {
    private(set) var logs: [InstagramRequestLog] = []
    
    func reset() { logs = [] }
    
    func append(label: String, request: URLRequest, response: HTTPURLResponse?, body: Data, errorMessage: String? = nil) {
        logs.append(InstagramRequestLog(
            label: label,
            requestURL: request.url?.absoluteString ?? "",
            requestHeaders: request.allHTTPHeaderFields ?? [:],
            responseStatusCode: response?.statusCode,
            responseHeaders: response.map { Self.headers(from: $0.allHeaderFields) } ?? [:],
            responseBody: Self.bodyString(from: body),
            errorMessage: errorMessage
        ))
    }
    
    func annotateLastEntry(error: Error) {
        guard let last = logs.last, last.errorMessage == nil else { return }
        logs[logs.count - 1] = InstagramRequestLog(
            id: last.id,
            timestamp: last.timestamp,
            label: last.label,
            requestURL: last.requestURL,
            requestHeaders: last.requestHeaders,
            responseStatusCode: last.responseStatusCode,
            responseHeaders: last.responseHeaders,
            responseBody: last.responseBody,
            errorMessage: error.localizedDescription
        )
    }
    
    func annotateLastEntry(bodyPreview: String, error: Error) {
        guard let last = logs.last else { return }
        logs[logs.count - 1] = InstagramRequestLog(
            id: last.id,
            timestamp: last.timestamp,
            label: last.label,
            requestURL: last.requestURL,
            requestHeaders: last.requestHeaders,
            responseStatusCode: last.responseStatusCode,
            responseHeaders: last.responseHeaders,
            responseBody: bodyPreview,
            errorMessage: error.localizedDescription
        )
    }
    
    private static func headers(from raw: [AnyHashable: Any]) -> [String: String] {
        raw.reduce(into: [:]) { $0[String(describing: $1.key)] = String(describing: $1.value) }
    }
    
    private static func bodyString(from data: Data) -> String {
        if let string = String(data: data, encoding: .utf8), !string.isEmpty {
            return string
        }
        return data.base64EncodedString()
    }
}

actor InstagramAPIClient {
    private let followersQueryHash = "c76146de99bb02f6415203be841dd25a"
    private let followingsQueryHash = "d04b0a864b4b54837c0d870b0e77e076"
    private let referer = "https://www.instagram.com/accounts/onetap/?next="
    private let logManager = LogManager()
    
    var lastLogs: [InstagramRequestLog] { logManager.logs }
    
    private nonisolated lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()
    
    func fetchFollowersAndFollowings(
        for username: String
    ) async throws -> (followers: [Follower], followings: [Follower], logs: [InstagramRequestLog]) {
        logManager.reset()
        let userId = try await getUserId(for: username)
        
        async let followers = fetchEdges(
            label: "Followers",
            edgeKey: "edge_followed_by",
            queryHash: followersQueryHash,
            userId: userId
        )
        async let followings = fetchEdges(
            label: "Followings",
            edgeKey: "edge_follow",
            queryHash: followingsQueryHash,
            userId: userId
        )
        
        return try await (followers, followings, logManager.logs)
    }
    
    private func buildRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        
        let headers: KeyValuePairs<String, String> = [
            "User-Agent":      UserAgents.randomUserAgent,
            "Accept":          "*/*",
            "Accept-Language": "it-IT,it;q=0.9,en-US;q=0.8,en;q=0.7",
            "Accept-Encoding": "gzip, deflate, br, zstd",
            "Referer":         referer,
            "Sec-GPC":         "1",
            "Connection":      "keep-alive",
            "Sec-Fetch-Dest":  "empty",
            "Sec-Fetch-Mode":  "cors",
            "Sec-Fetch-Site":  "same-origin",
            "Priority":        "u=4",
        ]
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        if let cookieHeader = HTTPCookieStorage.shared
            .cookies(for: url)
            .map({ HTTPCookie.requestHeaderFields(with: $0)["Cookie"] })
            .flatMap({ $0 }) {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        
        return request
    }
    
    private func performRequest(label: String, request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            let http = response as? HTTPURLResponse
            logManager.append(label: label, request: request, response: http, body: data)
            
            guard let http, (200...299).contains(http.statusCode) else {
                throw InstagramAPIError(message: "\(label) request failed (HTTP \(http?.statusCode ?? 0))")
            }
            
            return try decompressIfNeeded(data)
        } catch {
            logManager.annotateLastEntry(error: error)
            throw error
        }
    }
    
    private static let zstdMagic: [UInt8] = [0x28, 0xB5, 0x2F, 0xFD]
    
    private func decompressIfNeeded(_ data: Data) throws -> Data {
        guard data.count >= 4, Array(data.prefix(4)) == Self.zstdMagic else { return data }
        
        do {
            return try ZSTDProcessor(useContext: true).decompressFrame(data)
        } catch {
            throw InstagramAPIError(message: "Failed to decompress zstd data: \(error.localizedDescription)")
        }
    }
    
    private func getUserId(for username: String) async throws -> Int {
        guard let url = URL(string: "https://www.instagram.com/web/search/topsearch/?query=\(username)") else {
            throw InstagramAPIError(message: "Invalid search URL for username '\(username)'")
        }
        
        let data = try await performRequest(label: "Search user", request: buildRequest(url: url))
        let json = try parseJSON(from: data)
        
        guard let users = json["users"].array else {
            throw InstagramAPIError(message: "Invalid response: no users array")
        }
        guard let user = users.first(where: { $0["user"]["username"].string == username }) else {
            throw InstagramAPIError(message: "User '\(username)' not found")
        }
        
        return try extractId(from: user["user"])
    }
    
    private func extractId(from userNode: JSON) throws -> Int {
        let candidates = [userNode["pk"], userNode["id"]]
        for candidate in candidates {
            if let value = candidate.int { return value }
            if let string = candidate.string, let value = Int(string) { return value }
        }
        throw InstagramAPIError(message: "Could not extract user ID from response")
    }
    
    private func fetchEdges(label: String, edgeKey: String, queryHash: String, userId: Int) async throws -> [Follower] {
        var results: [Follower] = []
        var cursor: String? = nil
        var hasNextPage = true
        
        while hasNextPage {
            let variables = GraphQLVariables(
                id: String(userId),
                include_reel: true,
                fetch_mutual: true,
                first: 50,
                after: cursor
            )
            let variablesJSON = try String(data: JSONEncoder().encode(variables), encoding: .utf8) ?? ""
            
            var components = URLComponents(string: "https://www.instagram.com/graphql/query/")!
            components.queryItems = [
                URLQueryItem(name: "query_hash", value: queryHash),
                URLQueryItem(name: "variables",  value: variablesJSON),
            ]
            guard let url = components.url else {
                throw InstagramAPIError(message: "Invalid GraphQL URL")
            }
            
            let data = try await performRequest(label: label, request: buildRequest(url: url))
            let json = try parseJSON(from: data)
            
            guard json["data"]["user"].exists() else {
                throw InstagramAPIError(message: "Invalid response: missing user data")
            }
            guard json["data"]["user"][edgeKey].exists() else {
                throw InstagramAPIError(message: "Invalid response: missing \(edgeKey)")
            }
            
            let edgeNode = json["data"]["user"][edgeKey]
            
            results += (edgeNode["edges"].array ?? []).compactMap { edge -> Follower? in
                guard let username = edge["node"]["username"].string else { return nil }
                return Follower(
                    id: username,
                    username: username,
                    displayName: edge["node"]["full_name"].string,
                    avatarURL: edge["node"]["profile_pic_url"].string.flatMap(URL.init(string:))
                )
            }
            
            hasNextPage = edgeNode["page_info"]["has_next_page"].bool ?? false
            cursor      = edgeNode["page_info"]["end_cursor"].string
            
            try await Task.sleep(nanoseconds: 800_000_000)
        }
        
        return results
    }
    
    private func parseJSON(from data: Data) throws -> JSON {
        do {
            return try JSON(data: data)
        } catch {
            let preview = String(data: data, encoding: .utf8) ?? data.base64EncodedString()
            logManager.annotateLastEntry(
                bodyPreview: preview,
                error: InstagramAPIError(message: "JSON decode error: \(error.localizedDescription)")
            )
            throw error
        }
    }
}
