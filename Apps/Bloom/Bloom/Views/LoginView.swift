//
//  LoginView.swift
//  Bloom
//
//  Created by Francesco on 04/05/26.
//

import WebKit
import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @State private var errorMessage: String?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                
                if let error = errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                
                VStack(alignment: .leading, spacing: 14) {
                    Text("Instagram session")
                        .font(.headline)
                    
                    InstagramWebView(isLoggedIn: $isLoggedIn, errorMessage: $errorMessage)
                        .frame(minHeight: 540)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.10), lineWidth: 1)
                        )
                }
                .padding(16)
                .applyLiquidGlassBackground(cornerRadius: 32)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Login stays on device", systemImage: "shield.lefthalf.filled")
                        .font(.footnote.weight(.semibold))
                    Text("If this page doesn't redirect you to the main view then try to interact with the webKit or restart Bloom.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .applyLiquidGlassBackground(cornerRadius: 32)
            }
            .padding(20)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Bloom")
    }
    
    private var header: some View {
        Text("Bloom")
            .font(.system(size: 40, weight: .heavy, design: .rounded))
    }
}

struct InstagramWebView: UIViewRepresentable {
    @Binding var isLoggedIn: Bool
    @Binding var errorMessage: String?
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: URL(string: "https://www.instagram.com/accounts/login/")!))
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isLoggedIn: $isLoggedIn, errorMessage: $errorMessage)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoggedIn: Bool
        @Binding var errorMessage: String?
        
        init(isLoggedIn: Binding<Bool>, errorMessage: Binding<String?>) {
            self._isLoggedIn = isLoggedIn
            self._errorMessage = errorMessage
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            syncCookies(from: webView) { [weak self] in
                self?.updateLoginState()
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            errorMessage = "Failed to load Instagram: \(error.localizedDescription)"
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            errorMessage = "Connection error: \(error.localizedDescription)"
        }
        
        private func syncCookies(from webView: WKWebView, completion: @escaping () -> Void) {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                cookies.forEach { cookie in
                    HTTPCookieStorage.shared.setCookie(cookie)
                }
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
        
        private func updateLoginState() {
            guard HTTPCookieStorage.shared.cookies?.contains(where: { $0.name == "sessionid" }) == true else {
                return
            }
            
            isLoggedIn = true
        }
    }
}
