//
//  NotificationService.swift
//  MicLatch
//
//  Copyright © 2026 Mingxuan Wang. All rights reserved.
//

import Foundation
import UserNotifications

// MARK: - NotificationSettings

/// User preferences for which notifications to show.
@MainActor
final class NotificationSettings: ObservableObject {
  // MARK: Lifecycle

  private init() {
    Self.registerDefaults()
    // Load initial values without triggering didSet
    _inputRestored = Published(initialValue: UserDefaults.standard.bool(forKey: Keys.inputRestored))
    _defaultInputChanged = Published(initialValue: UserDefaults.standard.bool(forKey: Keys.defaultInputChanged))
    _defaultOutputChanged = Published(initialValue: UserDefaults.standard.bool(forKey: Keys.defaultOutputChanged))
    _inputDeviceRemoved = Published(initialValue: UserDefaults.standard.bool(forKey: Keys.inputDeviceRemoved))
    _outputDeviceRemoved = Published(initialValue: UserDefaults.standard.bool(forKey: Keys.outputDeviceRemoved))
    _inputDeviceConnected = Published(initialValue: UserDefaults.standard.bool(forKey: Keys.inputDeviceConnected))
    _outputDeviceConnected = Published(initialValue: UserDefaults.standard.bool(forKey: Keys.outputDeviceConnected))
  }

  // MARK: Internal

  static let shared = NotificationSettings()

  /// Default ON
  @Published var inputRestored: Bool {
    didSet { UserDefaults.standard.set(inputRestored, forKey: Keys.inputRestored) }
  }

  @Published var defaultInputChanged: Bool {
    didSet { UserDefaults.standard.set(defaultInputChanged, forKey: Keys.defaultInputChanged) }
  }

  @Published var defaultOutputChanged: Bool {
    didSet { UserDefaults.standard.set(defaultOutputChanged, forKey: Keys.defaultOutputChanged) }
  }

  /// Default OFF
  @Published var inputDeviceRemoved: Bool {
    didSet { UserDefaults.standard.set(inputDeviceRemoved, forKey: Keys.inputDeviceRemoved) }
  }

  @Published var outputDeviceRemoved: Bool {
    didSet { UserDefaults.standard.set(outputDeviceRemoved, forKey: Keys.outputDeviceRemoved) }
  }

  @Published var inputDeviceConnected: Bool {
    didSet { UserDefaults.standard.set(inputDeviceConnected, forKey: Keys.inputDeviceConnected) }
  }

  @Published var outputDeviceConnected: Bool {
    didSet { UserDefaults.standard.set(outputDeviceConnected, forKey: Keys.outputDeviceConnected) }
  }

  // MARK: Private

  private enum Keys {
    static let inputRestored = "notification.inputRestored"
    static let defaultInputChanged = "notification.defaultInputChanged"
    static let defaultOutputChanged = "notification.defaultOutputChanged"
    static let inputDeviceRemoved = "notification.inputDeviceRemoved"
    static let outputDeviceRemoved = "notification.outputDeviceRemoved"
    static let inputDeviceConnected = "notification.inputDeviceConnected"
    static let outputDeviceConnected = "notification.outputDeviceConnected"
  }

  private static func registerDefaults() {
    UserDefaults.standard.register(defaults: [
      Keys.inputRestored: true,
      Keys.defaultInputChanged: true,
      Keys.defaultOutputChanged: true,
      Keys.inputDeviceRemoved: false,
      Keys.outputDeviceRemoved: false,
      Keys.inputDeviceConnected: false,
      Keys.outputDeviceConnected: false,
    ])
  }
}

// MARK: - NotificationService

/// Service for sending user notifications about audio device events.
@MainActor
final class NotificationService {
  // MARK: Lifecycle

  private init() {}

  // MARK: Internal

  static let shared = NotificationService()

  let settings = NotificationSettings.shared

  /// Request notification permission. Call this at app startup.
  func requestAuthorization() async {
    do {
      let granted = try await center.requestAuthorization(options: [.alert, .sound])
      Log.debug("Notification authorization \(granted ? "granted" : "denied")")
    } catch {
      Log.serviceError("Failed to request notification authorization: \(error.localizedDescription)")
    }
  }

  /// Notify that input device was restored after a linked switch.
  /// This is the primary notification users care about.
  func notifyInputRestored(deviceName: String) {
    guard settings.inputRestored else {
      return
    }
    send(
      title: "Input Restored",
      body: "Microphone automatically restored to \"\(deviceName)\""
    )
  }

  /// Notify that the default input device changed.
  func notifyDefaultInputChanged(from oldDevice: String?, to newDevice: String) {
    guard settings.defaultInputChanged else {
      return
    }
    let body =
      if let oldDevice {
        "\"\(newDevice)\" (was \"\(oldDevice)\")"
      } else {
        "\"\(newDevice)\""
      }
    send(title: "Default Input Changed", body: body)
  }

  /// Notify that the default output device changed.
  func notifyDefaultOutputChanged(from oldDevice: String?, to newDevice: String) {
    guard settings.defaultOutputChanged else {
      return
    }
    let body =
      if let oldDevice {
        "\"\(newDevice)\" (was \"\(oldDevice)\")"
      } else {
        "\"\(newDevice)\""
      }
    send(title: "Default Output Changed", body: body)
  }

  /// Notify that an input device was removed/disconnected.
  func notifyInputDeviceRemoved(deviceName: String) {
    guard settings.inputDeviceRemoved else {
      return
    }
    send(
      title: "Input Device Disconnected",
      body: "Input device \"\(deviceName)\" has been disconnected"
    )
  }

  /// Notify that an output device was removed/disconnected.
  func notifyOutputDeviceRemoved(deviceName: String) {
    guard settings.outputDeviceRemoved else {
      return
    }
    send(
      title: "Output Device Disconnected",
      body: "Output device \"\(deviceName)\" has been disconnected"
    )
  }

  /// Notify that an input device was connected.
  func notifyInputDeviceConnected(deviceName: String) {
    guard settings.inputDeviceConnected else {
      return
    }
    send(
      title: "Input Device Connected",
      body: "Input device \"\(deviceName)\" has been connected"
    )
  }

  /// Notify that an output device was connected.
  func notifyOutputDeviceConnected(deviceName: String) {
    guard settings.outputDeviceConnected else {
      return
    }
    send(
      title: "Output Device Connected",
      body: "Output device \"\(deviceName)\" has been connected"
    )
  }

  // MARK: Private

  private let center = UNUserNotificationCenter.current()

  private func send(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = nil // Silent notification for device events

    let identifier = "miclatch_\(Date().timeIntervalSince1970)"
    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

    center.add(request) { error in
      if let error {
        Log.serviceError("Failed to send notification: \(error.localizedDescription)")
      }
    }
  }
}
