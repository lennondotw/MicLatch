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
    Text("Linked Input Change (Restored): \(service.inputRestoreCount)")
    Text("Unlinked Input Change (Ignored): \(service.nonLinkedInputSwitchCount)")

    // Event History submenu
    Menu("Event History") {
      if service.eventHistory.isEmpty {
        Text("No events yet")
      } else {
        ForEach(service.eventHistory) { event in
          Text("\(Self.timeFormatter.string(from: event.timestamp)) \(event.description)")
        }
      }
    }

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
