//
//  DecisionLogicTests.swift
//  MicLatch
//
//  Copyright © 2026 Mingxuan Wang. All rights reserved.
//

import CoreAudio
@testable import MicLatch
import Testing

// MARK: - MockAudioDeviceProvider

/// Mock provider for testing decision logic without real audio hardware.
/// Uses `nonisolated(unsafe)` for test-only mutable state since tests run sequentially.
final class MockAudioDeviceProvider: AudioDeviceProviding, @unchecked Sendable {
  // MARK: Internal

  // MARK: - Mock Device IDs

  static let builtInMic: AudioDeviceID = 100
  static let builtInSpeaker: AudioDeviceID = 101
  static let airPodsMic: AudioDeviceID = 200
  static let airPodsSpeaker: AudioDeviceID = 201

  // MARK: - Mock State (nonisolated unsafe for testing)

  nonisolated(unsafe) var currentInputID: AudioDeviceID? = MockAudioDeviceProvider.builtInMic
  nonisolated(unsafe) var currentOutputID: AudioDeviceID? = MockAudioDeviceProvider.builtInSpeaker
  nonisolated(unsafe) var setInputCalled = false
  nonisolated(unsafe) var lastSetInputID: AudioDeviceID?
  nonisolated(unsafe) var setInputShouldSucceed = true

  // MARK: - AudioDeviceProviding

  func defaultInputID() -> AudioDeviceID? {
    currentInputID
  }

  func defaultOutputID() -> AudioDeviceID? {
    currentOutputID
  }

  func name(of deviceID: AudioDeviceID) -> String? {
    switch deviceID {
    case Self.builtInMic:
      "MacBook Pro Microphone"

    case Self.builtInSpeaker:
      "MacBook Pro Speakers"

    case Self.airPodsMic:
      "AirPods Pro"

    case Self.airPodsSpeaker:
      "AirPods Pro"

    default:
      nil
    }
  }

  func transportTypeName(of deviceID: AudioDeviceID) -> String {
    switch deviceID {
    case Self.builtInMic,
         Self.builtInSpeaker:
      "built-in"

    case Self.airPodsMic,
         Self.airPodsSpeaker:
      "bluetooth"

    default:
      "unknown"
    }
  }

  func isBluetooth(_ deviceID: AudioDeviceID) -> Bool {
    deviceID == Self.airPodsMic || deviceID == Self.airPodsSpeaker
  }

  func setDefaultInput(_ deviceID: AudioDeviceID) -> Bool {
    setInputCalled = true
    lastSetInputID = deviceID
    if setInputShouldSucceed {
      currentInputID = deviceID
    }
    return setInputShouldSucceed
  }

  func allDeviceIDs() -> [AudioDeviceID] {
    [Self.builtInMic, Self.builtInSpeaker, Self.airPodsMic, Self.airPodsSpeaker]
  }

  func hasInput(_ deviceID: AudioDeviceID) -> Bool {
    deviceID == Self.builtInMic || deviceID == Self.airPodsMic
  }

  func hasOutput(_ deviceID: AudioDeviceID) -> Bool {
    deviceID == Self.builtInSpeaker || deviceID == Self.airPodsSpeaker
  }

  func addListener(
    selector: AudioObjectPropertySelector,
    handler: @escaping @Sendable () -> Void
  )
    -> (() -> Void)?
  {
    if selector == kAudioHardwarePropertyDefaultOutputDevice {
      outputChangeHandler = handler
    } else if selector == kAudioHardwarePropertyDefaultInputDevice {
      inputChangeHandler = handler
    }
    return { /* no-op for mock */ }
  }

  // MARK: - Test Helpers

  /// Simulate output device change and trigger listener.
  func changeOutput(to deviceID: AudioDeviceID) {
    currentOutputID = deviceID
    outputChangeHandler?()
  }

  /// Simulate input device change and trigger listener.
  func changeInput(to deviceID: AudioDeviceID) {
    currentInputID = deviceID
    inputChangeHandler?()
  }

  // MARK: Private

  // MARK: - Registered Listeners

  private nonisolated(unsafe) var outputChangeHandler: (@Sendable () -> Void)?
  private nonisolated(unsafe) var inputChangeHandler: (@Sendable () -> Void)?
}

// MARK: - DecisionLogicTests

/// Tests for the core decision logic: detecting linked vs manual input switches.
///
/// These tests use the `simulate*` methods which bypass the async listener mechanism,
/// allowing synchronous testing of the decision logic.
@Suite("Decision Logic Tests")
struct DecisionLogicTests {
  // MARK: - Linked Switch Detection

  @MainActor
  @Test("Linked switch: input change within window triggers restore")
  func linkedSwitchTriggersRestore() {
    let mock = MockAudioDeviceProvider()
    let service = AudioSwitchService(
      windowDuration: 0.5,
      startImmediately: false,
      deviceProvider: mock
    )
    service.start()

    // Initial state: built-in mic and speaker
    #expect(service.currentInputName == "MacBook Pro Microphone")
    #expect(service.currentOutputName == "MacBook Pro Speakers")

    // Simulate: output changes to AirPods (opens time window)
    mock.currentOutputID = MockAudioDeviceProvider.airPodsSpeaker
    service.simulateOutputChanged()

    // Window should be open
    #expect(service.isWindowOpen == true)
    #expect(service.currentOutputName == "AirPods Pro")

    // Simulate: system-linked input change to AirPods (within window)
    mock.currentInputID = MockAudioDeviceProvider.airPodsMic
    service.simulateInputChanged()

    // Service should have restored input to built-in mic
    #expect(mock.setInputCalled == true)
    #expect(mock.lastSetInputID == MockAudioDeviceProvider.builtInMic)
    #expect(service.currentInputName == "MacBook Pro Microphone")

    service.stop()
  }

  @MainActor
  @Test("Manual switch: input change outside window updates previous device")
  func manualSwitchUpdatesPreviousDevice() {
    let mock = MockAudioDeviceProvider()
    let service = AudioSwitchService(
      windowDuration: 0.5,
      startImmediately: false,
      deviceProvider: mock
    )
    service.start()

    // Initial state
    #expect(service.currentInputName == "MacBook Pro Microphone")

    // Simulate: manual input change (no output change, window is closed)
    #expect(service.isWindowOpen == false)
    mock.currentInputID = MockAudioDeviceProvider.airPodsMic
    service.simulateInputChanged()

    // Service should NOT try to restore (no setDefaultInput call)
    #expect(mock.setInputCalled == false)
    // Input should now be AirPods
    #expect(service.currentInputName == "AirPods Pro")

    service.stop()
  }

  @MainActor
  @Test("Window expires: input change after window is treated as manual")
  func windowExpiresAllowsManualChange() async {
    let mock = MockAudioDeviceProvider()
    // Use very short window for testing
    let service = AudioSwitchService(
      windowDuration: 0.05,
      startImmediately: false,
      deviceProvider: mock
    )
    service.start()

    // Simulate output change (opens window)
    mock.currentOutputID = MockAudioDeviceProvider.airPodsSpeaker
    service.simulateOutputChanged()
    #expect(service.isWindowOpen == true)

    // Wait for window to expire
    try? await Task.sleep(for: .milliseconds(100))

    // Window should be closed now
    #expect(service.isWindowOpen == false)

    // Simulate input change after window expired
    mock.currentInputID = MockAudioDeviceProvider.airPodsMic
    service.simulateInputChanged()

    // Should be treated as manual change (no restore attempt)
    #expect(mock.setInputCalled == false)
    #expect(service.currentInputName == "AirPods Pro")

    service.stop()
  }

  @MainActor
  @Test("No restore when input already matches previous device")
  func noRestoreWhenInputAlreadyMatches() {
    let mock = MockAudioDeviceProvider()
    let service = AudioSwitchService(
      windowDuration: 0.5,
      startImmediately: false,
      deviceProvider: mock
    )
    service.start()

    // Simulate output change
    mock.currentOutputID = MockAudioDeviceProvider.airPodsSpeaker
    service.simulateOutputChanged()
    #expect(service.isWindowOpen == true)

    // Simulate input "change" notification but input is still the same device
    // This tests the guard condition - no actual change occurred
    mock.currentInputID = MockAudioDeviceProvider.builtInMic
    service.simulateInputChanged()

    // No restore should be called since input didn't actually change
    #expect(mock.setInputCalled == false)

    service.stop()
  }

  @MainActor
  @Test("Restore fails gracefully when setDefaultInput returns false")
  func restoreFailsGracefully() {
    let mock = MockAudioDeviceProvider()
    mock.setInputShouldSucceed = false

    let service = AudioSwitchService(
      windowDuration: 0.5,
      startImmediately: false,
      deviceProvider: mock
    )
    service.start()

    // Simulate output change
    mock.currentOutputID = MockAudioDeviceProvider.airPodsSpeaker
    service.simulateOutputChanged()

    // Simulate linked input change
    mock.currentInputID = MockAudioDeviceProvider.airPodsMic
    service.simulateInputChanged()

    // Restore was attempted but failed
    #expect(mock.setInputCalled == true)
    // Input name should reflect the new (unrestored) state since setDefaultInput failed
    #expect(service.currentInputName == "AirPods Pro")

    service.stop()
  }

  // MARK: - Window State Tests

  @MainActor
  @Test("Multiple output changes reset the window")
  func multipleOutputChangesResetWindow() {
    let mock = MockAudioDeviceProvider()
    let service = AudioSwitchService(
      windowDuration: 0.5,
      startImmediately: false,
      deviceProvider: mock
    )
    service.start()

    // First output change
    mock.currentOutputID = MockAudioDeviceProvider.airPodsSpeaker
    service.simulateOutputChanged()
    #expect(service.isWindowOpen == true)

    // Second output change (back to speakers)
    mock.currentOutputID = MockAudioDeviceProvider.builtInSpeaker
    service.simulateOutputChanged()
    #expect(service.isWindowOpen == true)

    // Window should still be open (reset by second change)
    service.stop()
  }

  @MainActor
  @Test("Closing window manually prevents restore")
  func closingWindowPreventsRestore() {
    let mock = MockAudioDeviceProvider()
    let service = AudioSwitchService(
      windowDuration: 0.5,
      startImmediately: false,
      deviceProvider: mock
    )
    service.start()

    // Simulate output change
    mock.currentOutputID = MockAudioDeviceProvider.airPodsSpeaker
    service.simulateOutputChanged()
    #expect(service.isWindowOpen == true)

    // Manually close the window
    service.closeWindow()
    #expect(service.isWindowOpen == false)

    // Input change should now be treated as manual
    mock.currentInputID = MockAudioDeviceProvider.airPodsMic
    service.simulateInputChanged()
    #expect(mock.setInputCalled == false)

    service.stop()
  }
}
