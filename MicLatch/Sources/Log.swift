//
//  Log.swift
//  MicLatch
//
//  Copyright © 2026 Mingxuan Wang. All rights reserved.
//

import Foundation
import OSLog

// MARK: - Log

/// Structured logging for MicLatch using OSLog.
///
/// Categories:
/// - `events`: Audio device events (output/input changes)
/// - `decisions`: Routing decisions and actions taken
/// - `devices`: Device list changes (debug level)
enum Log {
  // MARK: Internal

  // MARK: - Device Debug Logging

  /// Summary info for a single device.
  struct DeviceInfo {
    let name: String
    let transport: String
    let hasInput: Bool
    let hasOutput: Bool
  }

  static let subsystem = "sh.lennon.MicLatch"

  // MARK: - Event Logging

  /// Log output device change.
  static func outputChanged(
    from oldDevice: String?,
    to newDevice: String?,
    transport: String?
  ) {
    let fromStr = oldDevice ?? "(none)"
    let toStr = newDevice ?? "(none)"
    let transportStr = transport.map { " [\($0)]" } ?? ""
    events
      .notice(
        "📤 OUTPUT | \"\(fromStr, privacy: .public)\" → \"\(toStr, privacy: .public)\"\(transportStr, privacy: .public)"
      )
  }

  /// Log input device change.
  static func inputChanged(
    from oldDevice: String?,
    to newDevice: String?,
    transport: String?,
    isLinked: Bool
  ) {
    let fromStr = oldDevice ?? "(none)"
    let toStr = newDevice ?? "(none)"
    let transportStr = transport.map { " [\($0)]" } ?? ""
    let linkTag = isLinked ? " (linked)" : ""
    events
      .notice(
        "📥 INPUT  | \"\(fromStr, privacy: .public)\" → \"\(toStr, privacy: .public)\"\(transportStr, privacy: .public)\(linkTag, privacy: .public)"
      )
  }

  /// Log window state change.
  static func windowStateChanged(isOpen: Bool, reason: String) {
    events
      .notice("🪟 WINDOW | \(isOpen ? "opened" : "closed", privacy: .public) | reason: \(reason, privacy: .public)")
  }

  // MARK: - Decision Logging

  /// Log a routing decision to restore input.
  static func decisionRestore(to deviceName: String, elapsedMs: Int) {
    decisions.notice("✅ RESTORE | Input → \"\(deviceName, privacy: .public)\" | elapsed: \(elapsedMs)ms")
  }

  /// Log a decision to skip intervention.
  static func decisionSkip(reason: String) {
    decisions.notice("⏭️ SKIP    | \(reason, privacy: .public)")
  }

  /// Log that no action was needed.
  static func decisionNoChange(currentDevice: String) {
    decisions.notice("🔄 NO_CHANGE | Input already \"\(currentDevice, privacy: .public)\"")
  }

  /// Log device list change with device summary.
  static func deviceListChanged(devices list: [DeviceInfo]) {
    let summary = list
      .map { info in
        let caps = [info.hasInput ? "in" : nil, info.hasOutput ? "out" : nil]
          .compactMap(\.self)
          .joined(separator: "+")
        return "\(info.name)(\(info.transport),\(caps))"
      }
      .joined(separator: ", ")
    devices.debug("🔌 DEVICES | count=\(list.count) | \(summary, privacy: .public)")
  }

  /// Log current default devices.
  static func defaultDevices(input: String?, output: String?) {
    let inputStr = input ?? "(none)"
    let outputStr = output ?? "(none)"
    devices.debug("🎯 DEFAULTS | input=\"\(inputStr, privacy: .public)\" output=\"\(outputStr, privacy: .public)\"")
  }

  // MARK: - Service Logging

  /// Log service lifecycle events.
  static func serviceStarted() {
    events.notice("🚀 SERVICE | Started monitoring")
  }

  /// Log service stopped.
  static func serviceStopped() {
    events.notice("🛑 SERVICE | Stopped monitoring")
  }

  /// Log service error.
  static func serviceError(_ message: String, code: Int32? = nil) {
    if let code {
      events.error("❌ ERROR   | \(message, privacy: .public) | OSStatus=\(code)")
    } else {
      events.error("❌ ERROR   | \(message, privacy: .public)")
    }
  }

  // MARK: Private

  // MARK: - Loggers

  private static let events = Logger(subsystem: subsystem, category: "events")
  private static let decisions = Logger(subsystem: subsystem, category: "decisions")
  private static let devices = Logger(subsystem: subsystem, category: "devices")
}
