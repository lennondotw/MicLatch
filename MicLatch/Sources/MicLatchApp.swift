//
//  MicLatchApp.swift
//  MicLatch
//
//  Copyright © 2026 Mingxuan Wang. All rights reserved.
//

import MenuBarExtraAccess
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
    }
    .menuBarExtraAccess(isPresented: .constant(false)) { item in
      statusItem = item
      updateStatusItemAppearance()
    }
    .onChange(of: service.isMonitoring) {
      updateStatusItemAppearance()
    }
  }

  // MARK: Private

  @StateObject private var service = AudioSwitchService()
  @State private var statusItem: NSStatusItem?

  private let updaterController: SPUStandardUpdaterController

  private func updateStatusItemAppearance() {
    statusItem?.button?.appearsDisabled = !service.isMonitoring
  }
}
