//
//  FollowersService.swift
//  Bloom
//
//  Created by Francesco on 04/05/26.
//

import Foundation

@MainActor
final class FollowersService: ObservableObject {
    @Published private(set) var shouldShowChanges: Bool = false
    
    @Published private(set) var followers: [Follower] = []
    @Published private(set) var followings: [Follower] = []
    @Published private(set) var iDontFollowBack: [Follower] = []
    @Published private(set) var dontFollowMeBack: [Follower] = []
    @Published private(set) var apiLogs: [InstagramRequestLog] = []
    @Published private(set) var changes: FollowerChanges = FollowerChanges()
    
    var lastRawResponse: String {
        apiLogs.map(\.responseBody).joined(separator: "\n---PAGE BREAK---\n")
    }
    
    private let persistence = FollowersPersistence()
    private let instagramAPI = InstagramAPIClient()
    
    func clearStoredData() {
        persistence.clearStoredFollowers()
        followers = []
        followings = []
        dontFollowMeBack = []
        iDontFollowBack = []
        changes = FollowerChanges()
        shouldShowChanges = false
        apiLogs = []
    }
    
    func fetchFollowers(for username: String, platform: Platform) async throws -> [Follower] {
        guard platform == .instagram else {
            throw InstagramAPIError(message: "Only Instagram is supported")
        }
        
        do {
            let (fetchedFollowers, fetchedFollowings, logs) = try await instagramAPI.fetchFollowersAndFollowings(for: username)
            apply(logs: logs, followers: fetchedFollowers, followings: fetchedFollowings, username: username, platform: platform)
            return fetchedFollowers
        } catch {
            self.apiLogs = await instagramAPI.lastLogs
            throw error
        }
    }
    
    private func apply(
        logs: [InstagramRequestLog],
        followers fetchedFollowers: [Follower],
        followings fetchedFollowings: [Follower],
        username: String,
        platform: Platform
    ) {
        apiLogs = logs
        
        let previous = persistence.loadFollowers(for: username, platform: platform)
        if previous.isEmpty {
            changes = FollowerChanges()
            shouldShowChanges = false
        } else {
            let (added, removed) = Self.detectChanges(old: previous, new: fetchedFollowers)
            changes = FollowerChanges(added: added, removed: removed)
            shouldShowChanges = true
        }
        
        persistence.saveFollowers(fetchedFollowers, for: username, platform: platform)
        persistence.saveFollowings(fetchedFollowings, for: username, platform: platform)
        
        followers = fetchedFollowers
        followings = fetchedFollowings
        
        let followerIDs = Set(fetchedFollowers.map(\.username))
        let followingIDs = Set(fetchedFollowings.map(\.username))
        
        dontFollowMeBack = fetchedFollowings.filter { !followerIDs.contains($0.username) }
        iDontFollowBack  = fetchedFollowers.filter  { !followingIDs.contains($0.username) }
    }
    
    static func detectChanges(old: [Follower], new: [Follower]) -> (added: [Follower], removed: [Follower]) {
        let oldIDs = Set(old.map(\.id))
        let newIDs = Set(new.map(\.id))
        return (
            added:   new.filter { !oldIDs.contains($0.id) },
            removed: old.filter { !newIDs.contains($0.id) }
        )
    }
}

private final class FollowersPersistence {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager = FileManager.default
    
    func saveFollowers(_ followers: [Follower], for username: String, platform: Platform) {
        save(followers, key: key("followers", username, platform))
    }
    
    func loadFollowers(for username: String, platform: Platform) -> [Follower] {
        load(key: key("followers", username, platform))
    }
    
    func saveFollowings(_ followings: [Follower], for username: String, platform: Platform) {
        save(followings, key: key("followings", username, platform))
    }
    
    func loadFollowings(for username: String, platform: Platform) -> [Follower] {
        load(key: key("followings", username, platform))
    }
    
    func clearStoredFollowers() {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let filePrefixes = ["followers.", "followings."]
        
        if let items = try? fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil) {
            for item in items where filePrefixes.contains(where: { item.lastPathComponent.hasPrefix($0) }) {
                try? fileManager.removeItem(at: item)
            }
        }
        
        let legacyFolder = documentsDirectory.appendingPathComponent("BloomFollowers", isDirectory: true)
        if fileManager.fileExists(atPath: legacyFolder.path) {
            try? fileManager.removeItem(at: legacyFolder)
        }
    }
    
    private func key(_ kind: String, _ username: String, _ platform: Platform) -> String {
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(kind).\(platform.rawValue).\(normalizedUsername)"
    }
    
    private func save(_ value: [Follower], key: String) {
        guard let data = try? encoder.encode(value) else { return }
        do {
            let url = try fileURL(for: key)
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic])
        } catch {
            return
        }
    }
    
    private func load(key: String) -> [Follower] {
        do {
            let url = try fileURL(for: key)
            guard fileManager.fileExists(atPath: url.path) else { return [] }
            let data = try Data(contentsOf: url)
            return (try? decoder.decode([Follower].self, from: data)) ?? []
        } catch {
            return []
        }
    }
    
    private func fileURL(for key: String) throws -> URL {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        
        let safeName = key
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return documentsDirectory.appendingPathComponent("\(safeName).json", isDirectory: false)
    }
}
