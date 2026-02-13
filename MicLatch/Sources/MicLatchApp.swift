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
  // MARK: Lifecycle

  init() {
    self.updaterController = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )
  }

  // MARK: Internal

  var body: some Scene {
    MenuBarExtra {
      MenuBarView(service: service, updater: updaterController.updater)
    } label: {
      Image(systemName: service.isMonitoring ? "microphone.badge.plus.fill" : "microphone.slash.fill")
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(service.isMonitoring ? .primary : .secondary)
    }
  }

  // MARK: Private

  @StateObject private var service = AudioSwitchService()

  private let updaterController: SPUStandardUpdaterController
}
