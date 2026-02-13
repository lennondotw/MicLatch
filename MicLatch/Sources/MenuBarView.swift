//
//  MenuBarView.swift
//  MicLatch
//
//  Copyright © 2026 Mingxuan Wang. All rights reserved.
//

import Sparkle
import SwiftUI

// MARK: - MenuBarView

struct MenuBarView: View {
  @ObservedObject var service: AudioSwitchService

  let updater: SPUUpdater

  var body: some View {
    // Device status (read-only info)
    Text("Output: \(service.currentOutputName ?? "Unknown")")
    Text("Input: \(service.currentInputName ?? "Unknown")")

    Divider()

    // Suspend/Resume toggle
    Button(service.isMonitoring ? "Suspend Protection" : "Resume Protection") {
      if service.isMonitoring {
        service.stop()
      } else {
        service.start()
      }
    }

    Divider()

    // Updates
    Button("Check for Updates…") {
      updater.checkForUpdates()
    }

    Divider()

    // Quit
    Button("Quit MicLatch") {
      NSApplication.shared.terminate(nil)
    }
    .keyboardShortcut("q")
  }
}

// MARK: - Preview

#Preview {
  let controller = SPUStandardUpdaterController(
    startingUpdater: false,
    updaterDelegate: nil,
    userDriverDelegate: nil
  )
  return MenuBarView(
    service: AudioSwitchService(startImmediately: false),
    updater: controller.updater
  )
}
