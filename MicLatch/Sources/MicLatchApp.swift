//
//  MicLatchApp.swift
//  MicLatch
//
//  Copyright © 2026 Mingxuan Wang. All rights reserved.
//

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
