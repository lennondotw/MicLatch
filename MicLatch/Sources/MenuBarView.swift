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
  @ObservedObject var notificationSettings = NotificationService.shared.settings
  @ObservedObject var launchAtLogin = LaunchAtLoginService.shared

  let updater: SPUUpdater

  var body: some View {
    // Suspend/Resume toggle (most important action)
    Button(service.isMonitoring ? "Suspend Protection" : "Resume Protection") {
      if service.isMonitoring {
        service.stop()
      } else {
        service.start()
      }
    }

    // Notifications submenu
    Menu("Notifications") {
      Toggle("Input Restored", isOn: $notificationSettings.inputRestored)
      Toggle("Default Input Changed", isOn: $notificationSettings.defaultInputChanged)
      Toggle("Default Output Changed", isOn: $notificationSettings.defaultOutputChanged)

      Divider()

      Toggle("Input Device Connected", isOn: $notificationSettings.inputDeviceConnected)
      Toggle("Input Device Removed", isOn: $notificationSettings.inputDeviceRemoved)
      Toggle("Output Device Connected", isOn: $notificationSettings.outputDeviceConnected)
      Toggle("Output Device Removed", isOn: $notificationSettings.outputDeviceRemoved)
    }

    Divider()

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
    Text("Last Change: \(formatLastInputChange(service.lastInputChange))")

    Divider()

    // Launch at login toggle
    Toggle("Launch at Login", isOn: $launchAtLogin.isEnabled)

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

  /// Formatter for displaying event timestamps.
  /// Uses short time format (e.g., "14:32") to show when an event occurred.
  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .none
    return formatter
  }()

  private func formatLastInputChange(_ change: LastInputChange?) -> String {
    guard let change else {
      return "None"
    }
    switch change {
    case let .restored(deviceName, timestamp):
      return "Restored → \(deviceName) (at \(Self.timeFormatter.string(from: timestamp)))"

    case let .restoreFailed(deviceName, timestamp):
      return "Failed → \(deviceName) (at \(Self.timeFormatter.string(from: timestamp)))"

    case let .nonLinked(_, to, timestamp):
      return "Unlinked → \(to) (at \(Self.timeFormatter.string(from: timestamp)))"
    }
  }
}

// MARK: - Preview

#Preview {
  MenuBarView(
    service: AudioSwitchService(startImmediately: false),
    updater: SPUStandardUpdaterController(
      startingUpdater: false,
      updaterDelegate: nil,
      userDriverDelegate: nil
    ).updater
  )
}
