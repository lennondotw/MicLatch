//
//  MicLatchApp.swift
//  MicLatch
//
//  Created by Developer on 13/02/2026.
//

import MicLatchKit
import SwiftUI

// MARK: - MicLatchApp

@main
struct MicLatchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.fill")
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            Text("MicLatch")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Version \(MicLatchKit.version)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(minWidth: 300, minHeight: 200)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
