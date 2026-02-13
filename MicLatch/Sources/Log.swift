//
//  Log.swift
//  MicLatch
//
//  Created by Developer on 2/13/26.
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

  static let subsystem = "sh.lennon.MicLatch"

  // MARK: - Event Logging

  /// Log output device change.
  static func outputChanged(from oldDevice: String?, to newDevice: String?) {
    let fromStr = oldDevice ?? "(none)"
    let toStr = newDevice ?? "(none)"
    events.info("📤 OUTPUT | \"\(fromStr, privacy: .public)\" → \"\(toStr, privacy: .public)\"")
  }

  /// Log input device change.
  static func inputChanged(from oldDevice: String?, to newDevice: String?, isLinked: Bool) {
    let fromStr = oldDevice ?? "(none)"
    let toStr = newDevice ?? "(none)"
    let linkTag = isLinked ? " [linked]" : ""
    events
      .info(
        "📥 INPUT  | \"\(fromStr, privacy: .public)\" → \"\(toStr, privacy: .public)\"\(linkTag, privacy: .public)"
      )
  }

  /// Log window state change.
  static func windowStateChanged(isOpen: Bool, reason: String) {
    events
      .info("🪟 WINDOW | \(isOpen ? "opened" : "closed", privacy: .public) | reason: \(reason, privacy: .public)")
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

  // MARK: - Device Debug Logging

  /// Log device list changes.
  static func deviceListChanged(added: [String], removed: [String], total: Int) {
    let addedStr = added.isEmpty ? "[]" : "[\(added.joined(separator: ", "))]"
    let removedStr = removed.isEmpty ? "[]" : "[\(removed.joined(separator: ", "))]"
    devices.debug("🔌 DEVICES | +\(addedStr, privacy: .public) -\(removedStr, privacy: .public) | total: \(total)")
  }

  /// Log detailed device state.
  static func deviceState(
    id: UInt32,
    name: String,
    transportType: String,
    hasInput: Bool,
    hasOutput: Bool,
    isAlive: Bool
  ) {
    devices.debug(
      """
      📱 DEVICE  | id=\(id) name=\"\(name, privacy: .public)\" \
      transport=\(transportType, privacy: .public) \
      input=\(hasInput) output=\(hasOutput) alive=\(isAlive)
      """
    )
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
    events.info("🚀 SERVICE | Started monitoring")
  }

  /// Log service stopped.
  static func serviceStopped() {
    events.info("🛑 SERVICE | Stopped monitoring")
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
