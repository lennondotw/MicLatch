//
//  AudioEvent.swift
//  MicLatch
//
//  Copyright © 2026 Mingxuan Wang. All rights reserved.
//

import Foundation

// MARK: - InputChangeContext

/// Context for input device changes.
enum InputChangeContext: Equatable {
  /// Input changed within the linked time window (Bluetooth HFP).
  case linked

  /// Input changed outside the time window or non-Bluetooth device.
  case unlinked
}

// MARK: - AudioEvent

/// Represents an audio device event for the event history.
struct AudioEvent: Identifiable, Equatable {
  enum EventType: Equatable {
    /// Default output device changed.
    case outputChanged(from: String?, to: String)

    /// Default input device changed with context.
    case inputChanged(from: String?, to: String, context: InputChangeContext)

    /// Input was successfully restored after a linked switch.
    case inputRestored(deviceName: String)

    /// Restore attempt failed.
    case restoreFailed(deviceName: String)

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
        return "Output: \(to) (was \(from))"
      }
      return "Output: \(to)"

    case let .inputChanged(from, to, context):
      let label =
        switch context {
        case .linked:
          "Input (Linked)"

        case .unlinked:
          "Input (Unlinked)"
        }
      if let from {
        return "\(label): \(to) (was \(from))"
      }
      return "\(label): \(to)"

    case let .inputRestored(deviceName):
      return "Restored: \(deviceName)"

    case let .restoreFailed(deviceName):
      return "Restore Failed: \(deviceName)"

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
