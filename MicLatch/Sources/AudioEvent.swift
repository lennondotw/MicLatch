//
//  AudioEvent.swift
//  MicLatch
//
//  Copyright © 2026 Mingxuan Wang. All rights reserved.
//

import Foundation

// MARK: - AudioEvent

/// Represents an audio device event for the event history.
struct AudioEvent: Identifiable, Equatable {
  enum EventType: Equatable {
    /// Default output device changed.
    case outputChanged(from: String?, to: String)
    /// Default input device changed (before any restore).
    case inputChanged(from: String?, to: String)
    /// Input was successfully restored after a linked switch.
    case inputRestored(deviceName: String)
    /// Restore attempt failed.
    case restoreFailed(deviceName: String)
    /// Linked input switch detected (Bluetooth HFP).
    case linkedInputChange(from: String, to: String)
    /// Non-linked input switch (outside time window, or non-Bluetooth device).
    case unlinkedInputChange(from: String, to: String)
    /// Input device connected.
    case inputDeviceConnected(deviceName: String)
    /// Input device removed.
    case inputDeviceRemoved(deviceName: String)
    /// Output device connected.
    case outputDeviceConnected(deviceName: String)
    /// Output device removed.
    case outputDeviceRemoved(deviceName: String)
  }

  let id = UUID()
  let type: EventType
  let timestamp: Date

  /// Returns a user-friendly description of the event.
  var description: String {
    switch type {
    case let .outputChanged(from, to):
      if let from {
        return "Output: \(from) → \(to)"
      }
      return "Output: \(to)"

    case let .inputChanged(from, to):
      if let from {
        return "Input: \(from) → \(to)"
      }
      return "Input: \(to)"

    case let .inputRestored(deviceName):
      return "Restored: \(deviceName)"

    case let .restoreFailed(deviceName):
      return "Restore Failed: \(deviceName)"

    case let .linkedInputChange(from, to):
      return "Linked: \(from) → \(to)"

    case let .unlinkedInputChange(from, to):
      return "Unlinked: \(from) → \(to)"

    case let .inputDeviceConnected(deviceName):
      return "Input Connected: \(deviceName)"

    case let .inputDeviceRemoved(deviceName):
      return "Input Removed: \(deviceName)"

    case let .outputDeviceConnected(deviceName):
      return "Output Connected: \(deviceName)"

    case let .outputDeviceRemoved(deviceName):
      return "Output Removed: \(deviceName)"
    }
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }
}
