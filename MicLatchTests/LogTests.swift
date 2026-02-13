//
//  LogTests.swift
//  MicLatch
//
//  Copyright © 2026 Mingxuan Wang. All rights reserved.
//

@testable import MicLatch
import Testing

// MARK: - LogTests

@Suite("Log Tests")
struct LogTests {
  @Test("Log subsystem is correctly configured")
  func subsystemIsCorrect() {
    #expect(Log.subsystem == "sh.lennon.MicLatch")
  }

  @Test("Event logging does not crash")
  func eventLoggingDoesNotCrash() {
    // These should not throw or crash
    Log.outputChanged(from: "Device A", to: "Device B", transport: "bluetooth")
    Log.outputChanged(from: nil, to: "Device B", transport: nil)
    Log.inputChanged(from: "Mic A", to: "Mic B", transport: "built-in", isLinked: true)
    Log.inputChanged(from: "Mic A", to: "Mic B", transport: nil, isLinked: false)
    Log.windowStateChanged(isOpen: true, reason: "output changed")
    Log.windowStateChanged(isOpen: false, reason: "timer expired")
  }

  @Test("Decision logging does not crash")
  func decisionLoggingDoesNotCrash() {
    Log.decisionRestore(to: "MacBook Microphone", elapsedMs: 150)
    Log.decisionSkip(reason: "manual change outside window")
    Log.decisionNoChange(currentDevice: "MacBook Microphone")
  }

  @Test("Device debug logging does not crash")
  func deviceLoggingDoesNotCrash() {
    Log.deviceListChanged(devices: [
      ("AirPods Pro", "bluetooth", true, true),
      ("MacBook Pro Microphone", "built-in", true, false),
      ("MacBook Pro Speakers", "built-in", false, true),
    ])
    Log.deviceListChanged(devices: [])
    Log.defaultDevices(input: "MacBook Microphone", output: "AirPods Pro")
    Log.defaultDevices(input: nil, output: nil)
  }

  @Test("Service logging does not crash")
  func serviceLoggingDoesNotCrash() {
    Log.serviceStarted()
    Log.serviceStopped()
    Log.serviceError("Test error")
    Log.serviceError("Test error with code", code: -1)
  }
}
