//
//  LogsView.swift
//  Bloom
//
//  Created by Francesco on 04/05/26.
//

import SwiftUI

struct LogsView: View {
    let logs: [InstagramRequestLog]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            Group {
                if logs.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(logs.sorted(by: { $0.timestamp < $1.timestamp })) { log in
                                LogCard(log: log)
                            }
                        }
                        .padding(16)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("API Logs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        UIPasteboard.general.string = formattedLogs
                    } label: {
                        Label("Copy All", systemImage: "doc.on.doc")
                    }
                    .disabled(logs.isEmpty)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 34, weight: .semibold))
                .frame(width: 72, height: 72)
                .background(Color.primary.opacity(0.08), in: Circle())
            Text("No logs yet")
                .font(.headline)
            Text("Run a fetch to see the exact request URL, headers, response status, and raw data returned by Instagram.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
    
    private var formattedLogs: String {
        logs.sorted(by: { $0.timestamp < $1.timestamp }).map { log in
            var lines: [String] = []
            lines.append("=== \(log.label) ===")
            lines.append("Time: \(log.timestamp.formatted(date: .abbreviated, time: .standard))")
            lines.append("URL: \(log.requestURL)")
            if !log.requestHeaders.isEmpty {
                lines.append("Request Headers:")
                log.requestHeaders.sorted(by: { $0.key < $1.key }).forEach { lines.append("  \($0.key): \($0.value)") }
            }
            if let status = log.responseStatusCode {
                lines.append("Status: \(status)")
            }
            if !log.responseHeaders.isEmpty {
                lines.append("Response Headers:")
                log.responseHeaders.sorted(by: { $0.key < $1.key }).forEach { lines.append("  \($0.key): \($0.value)") }
            }
            if let errorMessage = log.errorMessage {
                lines.append("Error: \(errorMessage)")
            }
            lines.append("Body:")
            lines.append(log.responseBody.isEmpty ? "<empty>" : log.responseBody)
            lines.append("")
            return lines.joined(separator: "\n")
        }.joined(separator: "\n")
    }
}

private struct LogCard: View {
    let log: InstagramRequestLog
    @State private var expanded = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(log.label)
                        .font(.headline)
                    Text(log.timestamp.formatted(date: .abbreviated, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let status = log.responseStatusCode {
                    Text("HTTP \(status)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(status >= 200 && status < 300 ? .green : .red)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }
            }
            
            Text(log.requestURL)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            
            if let errorMessage = log.errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(colorScheme == .dark ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                
                if log.responseBody.hasPrefix("KLUv/W") {
                    Text("The response is zstd-compressed. Add the ZstdSwift package to decompress it automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            
            DisclosureGroup(isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 12) {
                    if !log.requestHeaders.isEmpty {
                        logHeaders(title: "Request Headers", headers: log.requestHeaders)
                    }
                    if !log.responseHeaders.isEmpty {
                        logHeaders(title: "Response Headers", headers: log.responseHeaders)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Body")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Button {
                                UIPasteboard.general.string = log.responseBody
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(log.responseBody.isEmpty ? "<empty>" : log.responseBody)
                                .font(.system(.caption2, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .frame(maxHeight: 280)
                    }
                }
                .padding(.top, 8)
            } label: {
                Text("Show details")
                    .font(.footnote.weight(.semibold))
            }
            .tint(.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.10), lineWidth: 1)
        )
    }
    
    private func logHeaders(title: String, headers: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            VStack(alignment: .leading, spacing: 4) {
                ForEach(headers.keys.sorted(), id: \.self) { key in
                    Text("\(key): \(headers[key] ?? "")")
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
