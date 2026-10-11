//
//  LiquidGlassBackground.swift
//  Bloom
//
//  Created by Francesco on 04/05/26.
//

import SwiftUI

extension View {
    @ViewBuilder
    func applyLiquidGlassBackground(cornerRadius: CGFloat, fallbackFill: Color? = nil, fallbackMaterial: Material = .ultraThickMaterial, glassTint: Color? = nil) -> some View {
#if compiler(>=6.0)
        if #available(iOS 26.0, macOS 15.0, tvOS 20.0, *) {
            self
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(alignment: .center) {
                    if let glassTint {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(glassTint)
                            .allowsHitTesting(false)
                    }
                }
        } else {
            OldBackgroundContainer(content: self, cornerRadius: cornerRadius, fallbackFill: fallbackFill, fallbackMaterial: fallbackMaterial)
        }
#else
        OldBackgroundContainer(content: self, cornerRadius: cornerRadius, fallbackFill: fallbackFill, fallbackMaterial: fallbackMaterial)
#endif
    }
}

private struct OldBackgroundContainer<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let fallbackFill: Color?
    let fallbackMaterial: Material
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let fill = fallbackFill ?? (colorScheme == .light ? Color.white.opacity(0.2) : Color.black.opacity(0.2))
        
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(fallbackMaterial)
                    )
            )
    }
}
