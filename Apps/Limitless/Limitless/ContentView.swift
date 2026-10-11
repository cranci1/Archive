//
//  ContentView.swift
//  Limitless
//
//  Created by Francesco on 14/06/26.
//

import SwiftUI
import FamilyControls

struct ContentView: View {
    @EnvironmentObject var model: BlockerModel
    @State private var pickerIsPresented = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Authorization")) {
                    if model.isAuthorized {
                        Label("Authorized", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button("Request Screen Time Permission") {
                            Task { await model.requestAuthorization() }
                        }
                    }
                }
                
                if model.isAuthorized {
                    Section(header: Text("Apps & Websites to Block")) {
                        Button("Select Apps") {
                            pickerIsPresented = true
                        }
                        .familyActivityPicker(isPresented: $pickerIsPresented,
                                              selection: $model.selection)
                        
                        if !model.selection.applicationTokens.isEmpty {
                            Text("\(model.selection.applicationTokens.count) app(s) selected")
                                .font(.caption)
                        }
                    }
                    
                    Section(header: Text("Blocking Control")) {
                        Toggle("Enable Blocking", isOn: $model.isBlockingEnabled)
                    }
                }
            }
            .navigationTitle("Doom Scroller")
        }
    }
}
