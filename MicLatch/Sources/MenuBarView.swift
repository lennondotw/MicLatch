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
  // MARK: Internal

  @ObservedObject var service: AudioSwitchService

  let updater: SPUUpdater

  var body: some View {
    // Device status (read-only info)
    Text("Output: \(service.currentOutputName ?? "Unknown")")
    Text("Input: \(service.currentInputName ?? "Unknown")")

    Divider()

    // Statistics
    // - Linked Restores: Input device auto-restored after Bluetooth output switch within time window
    // - Unlinked Switches: Input changes outside time window or from non-Bluetooth devices
    // - Last Change: Most recent input change event with status (Restored/Failed/Non-Linked)
    Text("Linked Restores: \(service.inputRestoreCount)")
    Text("Unlinked Switches: \(service.nonLinkedInputSwitchCount)")
    Text("Last Change: \(formatLastInputChange(service.lastInputChange, at: service.currentTime))")

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

  // MARK: Private

  private func formatLastInputChange(_ change: LastInputChange?, at now: Date) -> String {
    guard let change else {
      return "None"
    }
    switch change {
    case let .restored(deviceName, timestamp):
      return "Restored → \(deviceName) (\(relativeTime(from: timestamp, to: now)))"

    case let .restoreFailed(deviceName, timestamp):
      return "Failed → \(deviceName) (\(relativeTime(from: timestamp, to: now)))"

    case let .nonLinked(_, to, timestamp):
      return "Non-Linked → \(to) (\(relativeTime(from: timestamp, to: now)))"
    }
  }

  private func relativeTime(from date: Date, to now: Date) -> String {
    let seconds = Int(now.timeIntervalSince(date))
    if seconds < 60 {
      return "\(seconds)s ago"
    } else if seconds < 3600 {
      return "\(seconds / 60)m ago"
    } else {
      return "\(seconds / 3600)h ago"
    }
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
