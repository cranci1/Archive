//
//  LimitlessApp.swift
//  Limitless
//
//  Created by Francesco on 14/06/26.
//

import SwiftUI
import FamilyControls

@main
struct LimitlessApp: App {
    @StateObject private var blockerModel = BlockerModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(blockerModel)
                .onAppear {
                    Task {
                        await blockerModel.requestAuthorization()
                    }
                }
        }
    }
}
