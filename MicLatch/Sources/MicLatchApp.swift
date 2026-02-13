//
//  MicLatchApp.swift
//  MicLatch
//
//  Copyright © 2026 Mingxuan Wang. All rights reserved.
//

import Sparkle
import SwiftUI

// MARK: - MicLatchApp

@main
struct MicLatchApp: App {
  @StateObject private var service = AudioSwitchService()
  private let updaterController: SPUStandardUpdaterController

  init() {
    self.updaterController = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )
  }

  var body: some Scene {
    MenuBarExtra {
      MenuBarView(service: service, updater: updaterController.updater)
    } label: {
      Label("MicLatch", systemImage: service.isMonitoring ? "mic.fill" : "mic.slash")
    }
  }
}
