//
//  LaunchAtLoginService.swift
//  MicLatch
//
//  Copyright © 2026 Mingxuan Wang. All rights reserved.
//

import ServiceManagement
import SwiftUI

// MARK: - LaunchAtLoginService

/// Service for managing launch at login functionality using SMAppService.
@MainActor
final class LaunchAtLoginService: ObservableObject {
  // MARK: Lifecycle

  private init() {
    _isEnabled = Published(initialValue: Self.currentStatus == .enabled)
  }

  // MARK: Internal

  static let shared = LaunchAtLoginService()

  /// Whether launch at login is currently enabled.
  @Published var isEnabled: Bool {
    didSet {
      guard oldValue != isEnabled else {
        return
      }
      setLaunchAtLogin(isEnabled)
    }
  }

  // MARK: Private

  private static var currentStatus: SMAppService.Status {
    SMAppService.mainApp.status
  }

  private func setLaunchAtLogin(_ enable: Bool) {
    do {
      if enable {
        try SMAppService.mainApp.register()
        Log.debug("Launch at login enabled")
      } else {
        try SMAppService.mainApp.unregister()
        Log.debug("Launch at login disabled")
      }
    } catch {
      Log.serviceError("Failed to \(enable ? "enable" : "disable") launch at login: \(error.localizedDescription)")
      // Revert the state if the operation failed
      _isEnabled = Published(initialValue: Self.currentStatus == .enabled)
      objectWillChange.send()
    }
  }
}
