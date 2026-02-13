//
//  MicLatchApp.swift
//  MicLatch
//
//  Created by Developer on 2/13/26.
//

import MicLatchKit
import SwiftUI

// MARK: - MicLatchApp

@main
struct MicLatchApp: App {
    @StateObject private var service = AudioSwitchService()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(service: service)
        } label: {
            Label("MicLatch", systemImage: service.isMonitoring ? "mic.fill" : "mic.slash")
        }
    }
}
