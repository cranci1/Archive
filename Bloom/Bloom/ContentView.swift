//
//  ContentView.swift
//  Bloom
//
//  Created by Francesco on 04/05/26.
//

import WebKit
import SwiftUI
import Kingfisher

struct ContentView: View {
    enum RowStyle {
        case normal
        case warning
    }
    
    @StateObject private var service = FollowersService()
    
    @State private var showLogs = false
    @State private var isLoading = false
    @State private var isClearingData = false
    @State private var errorMessage: String?
    @State private var selectedList: UserListCategory?
    
    @Environment(\.openURL) private var openURL
    
    @AppStorage("lastUsername") private var username: String = ""
    @AppStorage("isLoggedInInstagram") private var isLoggedIn: Bool = false
    @AppStorage("openProfilesInInstagram") private var openProfilesInInstagram: Bool = false
    
    private var normalizedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    var body: some View {
        Group {
            if isLoggedIn {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Bloom")
                                .font(.system(size: 40, weight: .heavy, design: .rounded))
                            
                            controlsCard
                            
                            if let errorMessage {
                                ErrorBanner(message: errorMessage)
                            }
                            
                            if service.shouldShowChanges {
                                changesSection
                            }
                            
                            resultsSection(
                                title: "Followers",
                                subtitle: "People who follow this account",
                                items: service.followers,
                                emptyTitle: "No followers loaded",
                                emptyMessage: "Fetch an account to populate this list.",
                                emptyIcon: "person.2.slash",
                                rowStyle: .normal,
                                category: .followers
                            )
                            
                            resultsSection(
                                title: "Followings",
                                subtitle: "Accounts this profile follows",
                                items: service.followings,
                                emptyTitle: "No followings loaded",
                                emptyMessage: "Fetch an account to populate this list.",
                                emptyIcon: "person.crop.circle.badge.questionmark",
                                rowStyle: .normal,
                                category: .followings
                            )
                            
                            resultsSection(
                                title: "Don't follow me back",
                                subtitle: "Accounts that do not follow this profile",
                                items: service.dontFollowMeBack,
                                emptyTitle: "Everyone follows back",
                                emptyMessage: "Nothing to show here right now.",
                                emptyIcon: "checkmark.circle",
                                rowStyle: .warning,
                                category: .dontFollowMeBack
                            )
                            
                            resultsSection(
                                title: "I don't follow back",
                                subtitle: "Followers not present in the following list",
                                items: service.iDontFollowBack,
                                emptyTitle: "No one to review",
                                emptyMessage: "Nothing to show here right now.",
                                emptyIcon: "checkmark.circle",
                                rowStyle: .normal,
                                category: .iDontFollowBack
                            )
                        }
                        .padding(20)
                    }
                    .refreshable {
                        await fetch()
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .navigationBarTrailing) {
                            Button {
                                showLogs = true
                            } label: {
                                Image(systemName: "doc.text.magnifyingglass")
                            }
                            logoutButton
                        }
                    }
                    .sheet(isPresented: $showLogs) {
                        LogsView(logs: service.apiLogs)
                    }
                    .navigationDestination(item: $selectedList) { category in
                        UserListView(
                            category: category,
                            items: category.items(from: service),
                            openProfilesInInstagram: openProfilesInInstagram
                        )
                    }
                }
            } else {
                LoginView(isLoggedIn: $isLoggedIn)
            }
        }
    }
    
    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Fetch account")
                .font(.headline)
            
            TextField("Username", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            Button(action: { Task { await fetch() } }) {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(isLoading ? "Fetching" : "Fetch")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.95, green: 0.55, blue: 0.18))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .disabled(normalizedUsername.isEmpty || isLoading)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .applyLiquidGlassBackground(cornerRadius: 32)
    }
    
    private var changesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Changes since last fetch")
                    .font(.headline)
                Text("What changed since the previous sync")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if service.changes.added.isEmpty && service.changes.removed.isEmpty {
                EmptyStateCard(
                    title: "No new changes yet",
                    message: "Run another fetch after some time to compare follower changes.",
                    icon: "sparkles"
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(service.changes.added) { follower in
                        ChangeRow(
                            follower: follower,
                            title: "Added",
                            color: .green,
                            showsOpenIndicator: openProfilesInInstagram
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            openInstagramProfile(for: follower)
                        }
                    }
                    ForEach(service.changes.removed) { follower in
                        ChangeRow(
                            follower: follower,
                            title: "Removed",
                            color: .red,
                            showsOpenIndicator: openProfilesInInstagram
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            openInstagramProfile(for: follower)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .applyLiquidGlassBackground(cornerRadius: 32)
    }
    
    private func resultsSection(
        title: String,
        subtitle: String,
        items: [Follower],
        emptyTitle: String,
        emptyMessage: String,
        emptyIcon: String,
        rowStyle: RowStyle,
        category: UserListCategory
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(title) (\(items.count))")
                        .font(.headline)
                    Spacer()
                    if items.count > 6 {
                        Button("Show all") {
                            selectedList = category
                        }
                        .font(.footnote.weight(.semibold))
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if items.isEmpty {
                EmptyStateCard(title: emptyTitle, message: emptyMessage, icon: emptyIcon)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(items.prefix(6)) { follower in
                        PersonRow(
                            follower: follower,
                            rowStyle: rowStyle,
                            showsOpenIndicator: openProfilesInInstagram
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            openInstagramProfile(for: follower)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .applyLiquidGlassBackground(cornerRadius: 32)
    }
    
    private var logoutButton: some View {
        Menu {
            Toggle(isOn: $openProfilesInInstagram) {
                Label("Open profile on tap", systemImage: "link")
            }
            
            Button(role: .destructive) {
                Task { await clearCachesAndDocuments() }
            } label: {
                Label("Clear caches", systemImage: "trash")
            }
            .disabled(isClearingData)
            
            Button(action: logout) {
                Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Image(systemName: "gear")
        }
    }
    
    private func openInstagramProfile(for follower: Follower) {
        guard openProfilesInInstagram else { return }
        
        guard let url = instagramProfileURL(for: follower.username) else {
            return
        }
        
        openURL(url)
    }
    
    private func logout() {
        isLoggedIn = false
        username = ""
        
        HTTPCookieStorage.shared.cookies?.forEach {
            HTTPCookieStorage.shared.deleteCookie($0)
        }
        
        URLCache.shared.removeAllCachedResponses()
        
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        dataStore.removeData(ofTypes: dataTypes, modifiedSince: Date(timeIntervalSince1970: 0)) { }
    }
    
    @MainActor
    private func clearCachesAndDocuments() async {
        guard !isClearingData else { return }
        
        isClearingData = true
        defer { isClearingData = false }
        
        errorMessage = nil
        showLogs = false
        selectedList = nil
        service.clearStoredData()
        URLCache.shared.removeAllCachedResponses()
        await ImageCache.default.clearCache()
    }
    
    @MainActor
    private func fetch() async {
        let trimmedUsername = normalizedUsername
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            _ = try await service.fetchFollowers(for: trimmedUsername, platform: .instagram)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ErrorBanner: View {
    let message: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Something went wrong", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.semibold))
            Text(message)
                .font(.footnote)
        }
        .foregroundStyle(Color(red: 0.55, green: 0.11, blue: 0.11))
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct EmptyStateCard: View {
    let title: String
    let message: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(Color.primary.opacity(0.08), in: Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct PersonRow: View {
    let follower: Follower
    let rowStyle: ContentView.RowStyle
    let showsOpenIndicator: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: follower.avatarURL)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(follower.username)
                    .font(.subheadline.weight(.semibold))
                if let displayName = follower.displayName, !displayName.isEmpty {
                    Text(displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer(minLength: 12)
            
            if rowStyle == .warning {
                Text("Missing")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.red.opacity(0.10), in: Capsule())
            }
            
            if showsOpenIndicator {
                Image(systemName: "arrow.up.right.square")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ChangeRow: View {
    let follower: Follower
    let title: String
    let color: Color
    let showsOpenIndicator: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: follower.avatarURL)
            VStack(alignment: .leading, spacing: 2) {
                Text(follower.username)
                    .font(.subheadline.weight(.semibold))
                if let displayName = follower.displayName, !displayName.isEmpty {
                    Text(displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(color.opacity(0.12), in: Capsule())
            
            if showsOpenIndicator {
                Image(systemName: "arrow.up.right.square")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct AvatarView: View {
    let url: URL?
    
    var body: some View {
        Group {
            if let url {
                KFImage(url)
                    .placeholder {
                        ProgressView().frame(width: 44, height: 44)
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 44, height: 44)
            }
        }
    }
}


private enum UserListCategory: String, Identifiable, Hashable {
    case followers
    case followings
    case dontFollowMeBack
    case iDontFollowBack
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .followers: return "Followers"
        case .followings: return "Followings"
        case .dontFollowMeBack: return "Don't follow me back"
        case .iDontFollowBack: return "I don't follow back"
        }
    }
    
    @MainActor
    func items(from service: FollowersService) -> [Follower] {
        switch self {
        case .followers: return service.followers
        case .followings: return service.followings
        case .dontFollowMeBack: return service.dontFollowMeBack
        case .iDontFollowBack: return service.iDontFollowBack
        }
    }
}

private struct UserListView: View {
    let category: UserListCategory
    let items: [Follower]
    let openProfilesInInstagram: Bool
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(category.title) (\(items.count))")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                
                if items.isEmpty {
                    EmptyStateCard(
                        title: "No users",
                        message: "There are no users in this category yet.",
                        icon: "person.crop.circle.badge.questionmark"
                    )
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(items) { follower in
                            PersonRow(
                                follower: follower,
                                rowStyle: rowStyle,
                                showsOpenIndicator: openProfilesInInstagram
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                openInstagramProfile(for: follower)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var rowStyle: ContentView.RowStyle {
        switch category {
        case .dontFollowMeBack:
            return .warning
        default:
            return .normal
        }
    }
    
    private func openInstagramProfile(for follower: Follower) {
        guard openProfilesInInstagram else { return }
        
        guard let url = instagramProfileURL(for: follower.username) else {
            return
        }
        
        openURL(url)
    }
}

private func instagramProfileURL(for username: String) -> URL? {
    let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedUsername.isEmpty else {
        return nil
    }
    
    var components = URLComponents()
    components.scheme = "instagram"
    components.host = "user"
    components.queryItems = [URLQueryItem(name: "username", value: normalizedUsername)]
    return components.url
}
