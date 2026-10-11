//
//  Models.swift
//  Bloom
//
//  Created by Francesco on 04/05/26.
//

import Foundation

enum Platform: String, CaseIterable, Codable {
    case instagram
    
    var displayName: String {
        switch self {
        case .instagram: return "Instagram"
        }
    }
}

struct Follower: Identifiable, Codable, Equatable {
    let id: String
    let username: String
    let displayName: String?
    let avatarURL: URL?
    
    init(id: String, username: String, displayName: String? = nil, avatarURL: URL? = nil) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
    }
}

struct FollowerChanges: Codable {
    var added: [Follower] = []
    var removed: [Follower] = []
}

struct InstagramRequestLog: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let label: String
    let requestURL: String
    let requestHeaders: [String: String]
    let responseStatusCode: Int?
    let responseHeaders: [String: String]
    let responseBody: String
    let errorMessage: String?
    
    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        label: String,
        requestURL: String,
        requestHeaders: [String: String] = [:],
        responseStatusCode: Int? = nil,
        responseHeaders: [String: String] = [:],
        responseBody: String = "",
        errorMessage: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.label = label
        self.requestURL = requestURL
        self.requestHeaders = requestHeaders
        self.responseStatusCode = responseStatusCode
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
        self.errorMessage = errorMessage
    }
}
