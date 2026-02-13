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
    .menuBarExtraAccess(isPresented: $menuPresented) { item in
      statusItem = item
      updateStatusItemAppearance()
    }
    .onChange(of: service.isMonitoring) {
      updateStatusItemAppearance()
    }
    .onChange(of: menuPresented) { _, isPresented in
      // Option+Click: toggle monitoring without showing menu
      if isPresented, NSEvent.modifierFlags.contains(.option) {
        menuPresented = false
        if service.isMonitoring {
          service.stop()
        } else {
          service.start()
        }
      }
    }
  }

  // MARK: Private

  @StateObject private var service = AudioSwitchService()
  @State private var statusItem: NSStatusItem?
  @State private var menuPresented = false

  private let updaterController: SPUStandardUpdaterController

  private func updateStatusItemAppearance() {
    statusItem?.button?.appearsDisabled = !service.isMonitoring
  }
}
