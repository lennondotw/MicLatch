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

    // Protection toggle
    Toggle("Enable Protection", isOn: Binding(
      get: { service.isMonitoring },
      set: { newValue in
        if newValue {
          service.start()
        } else {
          service.stop()
        }
      }
    ))

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
  return MenuBarView(service: AudioSwitchService(), updater: controller.updater)
}
