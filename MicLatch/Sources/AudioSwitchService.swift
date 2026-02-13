//
//  AudioSwitchService.swift
//  MicLatch
//
//  Copyright © 2026 Mingxuan Wang. All rights reserved.
//

import CoreAudio
import Foundation

// MARK: - AudioDeviceProviding

/// Protocol for audio device operations, enabling dependency injection for testing.
protocol AudioDeviceProviding: Sendable {
  func defaultInputID() -> AudioDeviceID?
  func defaultOutputID() -> AudioDeviceID?
  func name(of deviceID: AudioDeviceID) -> String?
  func transportTypeName(of deviceID: AudioDeviceID) -> String
  func setDefaultInput(_ deviceID: AudioDeviceID) -> Bool
  func allDeviceIDs() -> [AudioDeviceID]
  func hasInput(_ deviceID: AudioDeviceID) -> Bool
  func hasOutput(_ deviceID: AudioDeviceID) -> Bool
  func addListener(
    selector: AudioObjectPropertySelector,
    handler: @escaping @Sendable () -> Void
  )
    -> (() -> Void)?
}

// MARK: - RealAudioDeviceProvider

/// Production implementation that delegates to AudioDevice.
struct RealAudioDeviceProvider: AudioDeviceProviding {
  func defaultInputID() -> AudioDeviceID? {
    AudioDevice.defaultInputID()
  }

  func defaultOutputID() -> AudioDeviceID? {
    AudioDevice.defaultOutputID()
  }

  func name(of deviceID: AudioDeviceID) -> String? {
    AudioDevice.name(of: deviceID)
  }

  func transportTypeName(of deviceID: AudioDeviceID) -> String {
    AudioDevice.transportTypeName(of: deviceID)
  }

  func setDefaultInput(_ deviceID: AudioDeviceID) -> Bool {
    AudioDevice.setDefaultInput(deviceID)
  }

  func allDeviceIDs() -> [AudioDeviceID] {
    AudioDevice.allDeviceIDs()
  }

  func hasInput(_ deviceID: AudioDeviceID) -> Bool {
    AudioDevice.hasInput(deviceID)
  }

  func hasOutput(_ deviceID: AudioDeviceID) -> Bool {
    AudioDevice.hasOutput(deviceID)
  }

  func addListener(
    selector: AudioObjectPropertySelector,
    handler: @escaping @Sendable () -> Void
  )
    -> (() -> Void)?
  {
    AudioDevice.addListener(selector: selector, handler: handler)
  }
}

// MARK: - AudioSwitchService

/// Service that monitors audio device changes and restores input device
/// when output changes cause system-linked input switching.
///
/// ## How It Works
///
/// When the output device changes (e.g., switching to AirPods):
/// 1. We record the current input device as `previousInputDevice`
/// 2. We open a time window (`windowDuration`, default 2s)
/// 3. If input changes within this window, we assume it's a system-linked switch
/// 4. We restore the input to `previousInputDevice`
/// 5. After the window expires, any input change is considered manual
///
@MainActor
final class AudioSwitchService: ObservableObject {
  // MARK: Lifecycle

  // MARK: - Initialization

  init(
    windowDuration: TimeInterval = 2.0,
    startImmediately: Bool = true,
    deviceProvider: any AudioDeviceProviding = RealAudioDeviceProvider()
  ) {
    self.windowDuration = windowDuration
    self.deviceProvider = deviceProvider
    if startImmediately {
      start()
    }
  }

  // MARK: Internal

  // MARK: - Published State

  /// Whether monitoring is currently active.
  @Published private(set) var isMonitoring = false

  /// Name of the current input device.
  @Published private(set) var currentInputName: String?

  /// Name of the current output device.
  @Published private(set) var currentOutputName: String?

  // MARK: - Configuration

  /// Duration of the time window after output change (in seconds).
  let windowDuration: TimeInterval

  /// The audio device provider (injectable for testing).
  let deviceProvider: any AudioDeviceProviding

  // MARK: - Public API

  /// Start monitoring audio device changes.
  func start() {
    guard !isMonitoring else {
      return
    }

    // Record initial state
    if let inputID = deviceProvider.defaultInputID() {
      previousInputDevice = inputID
      currentInputName = deviceProvider.name(of: inputID)
    }
    if let outputID = deviceProvider.defaultOutputID() {
      currentOutputName = deviceProvider.name(of: outputID)
    }

    // Initialize device list state for change detection
    let allIDs = deviceProvider.allDeviceIDs()
    previousDeviceIDs = Set(allIDs)
    for id in allIDs {
      if let name = deviceProvider.name(of: id) {
        previousDeviceInfos[id] = Log.DeviceInfo(
          name: name,
          transport: deviceProvider.transportTypeName(of: id),
          hasInput: deviceProvider.hasInput(id),
          hasOutput: deviceProvider.hasOutput(id)
        )
      }
    }

    setupListeners()
    isMonitoring = true

    Log.serviceStarted()
    Log.defaultDevices(input: currentInputName, output: currentOutputName)
  }

  /// Stop monitoring audio device changes.
  func stop() {
    guard isMonitoring else {
      return
    }

    pendingTimer?.invalidate()
    pendingTimer = nil
    outputSwitchPending = false

    for remove in listenerRemovers {
      remove()
    }
    listenerRemovers.removeAll()

    isMonitoring = false
    Log.serviceStopped()
  }

  // MARK: - Testing Support

  #if DEBUG
    /// Simulate an output device change (for testing).
    func simulateOutputChanged() {
      handleOutputChanged()
    }

    /// Simulate an input device change (for testing).
    func simulateInputChanged() {
      handleInputChanged()
    }

    /// Check if the time window is currently open (for testing).
    var isWindowOpen: Bool {
      outputSwitchPending
    }

    /// Force close the time window (for testing).
    func closeWindow() {
      handleWindowExpired()
    }
  #endif

  // MARK: Private

  // MARK: - Private State

  /// The input device ID to restore to when linked switch detected.
  private var previousInputDevice: AudioDeviceID?

  /// Whether we're in the active time window after output change.
  private var outputSwitchPending = false

  /// Timer for the time window.
  private var pendingTimer: Timer?

  /// Timestamp when output change was detected.
  private var outputSwitchTime: Date?

  /// Listener cleanup closures.
  private var listenerRemovers: [() -> Void] = []

  /// Previous device IDs for change detection.
  private var previousDeviceIDs: Set<AudioDeviceID> = []

  /// Previous device info for removed device logging.
  private var previousDeviceInfos: [AudioDeviceID: Log.DeviceInfo] = [:]

  // MARK: - Private Methods

  private func setupListeners() {
    // Listen for output device changes
    if let remove = deviceProvider.addListener(
      selector: kAudioHardwarePropertyDefaultOutputDevice,
      handler: { [weak self] in
        Task { @MainActor in
          self?.handleOutputChanged()
        }
      }
    ) {
      listenerRemovers.append(remove)
    }

    // Listen for input device changes
    if let remove = deviceProvider.addListener(
      selector: kAudioHardwarePropertyDefaultInputDevice,
      handler: { [weak self] in
        Task { @MainActor in
          self?.handleInputChanged()
        }
      }
    ) {
      listenerRemovers.append(remove)
    }

    // Listen for device list changes (debug logging)
    if let remove = deviceProvider.addListener(
      selector: kAudioHardwarePropertyDevices,
      handler: { [weak self] in
        Task { @MainActor in
          self?.handleDeviceListChanged()
        }
      }
    ) {
      listenerRemovers.append(remove)
    }
  }

  private func handleOutputChanged() {
    let oldOutput = currentOutputName
    let newOutputID = deviceProvider.defaultOutputID()
    let newOutput = newOutputID.flatMap { deviceProvider.name(of: $0) }
    let transport = newOutputID.map { deviceProvider.transportTypeName(of: $0) }

    // Skip if no actual change
    guard newOutput != oldOutput else {
      return
    }

    currentOutputName = newOutput
    Log.outputChanged(from: oldOutput, to: newOutput, transport: transport)

    // Record current input before system might change it
    if let currentInputID = deviceProvider.defaultInputID() {
      previousInputDevice = currentInputID
      Log.windowStateChanged(
        isOpen: true,
        reason: "output changed to \(newOutput ?? "unknown")"
      )
    }

    // Start time window
    outputSwitchPending = true
    outputSwitchTime = Date()

    pendingTimer?.invalidate()
    pendingTimer = Timer.scheduledTimer(
      withTimeInterval: windowDuration,
      repeats: false
    ) { [weak self] _ in
      Task { @MainActor in
        self?.handleWindowExpired()
      }
    }
  }

  private func handleInputChanged() {
    let oldInput = currentInputName
    guard let newInputID = deviceProvider.defaultInputID() else {
      return
    }
    let newInput = deviceProvider.name(of: newInputID)
    let transport = deviceProvider.transportTypeName(of: newInputID)

    // Skip if no actual change
    guard newInput != oldInput else {
      return
    }

    currentInputName = newInput

    if outputSwitchPending {
      // Within window: check if this is a linked switch we should restore
      let elapsed = Date().timeIntervalSince(outputSwitchTime ?? Date())
      let elapsedMs = Int(elapsed * 1000)

      Log.inputChanged(from: oldInput, to: newInput, transport: transport, isLinked: true)

      // Only restore if input changed to something different than our saved device
      if let previousID = previousInputDevice, newInputID != previousID {
        let previousName = deviceProvider.name(of: previousID) ?? "unknown"

        // Attempt to restore
        if deviceProvider.setDefaultInput(previousID) {
          Log.decisionRestore(to: previousName, elapsedMs: elapsedMs)
          currentInputName = previousName
        } else {
          Log.decisionSkip(reason: "failed to restore input to \(previousName)")
        }
      } else {
        // Input is already what we want (maybe we just set it)
        Log.decisionNoChange(currentDevice: newInput ?? "unknown")
      }
    } else {
      // Outside window: this is a manual change, update our record
      Log.inputChanged(from: oldInput, to: newInput, transport: transport, isLinked: false)
      previousInputDevice = newInputID
    }
  }

  private func handleWindowExpired() {
    guard outputSwitchPending else {
      return
    }

    outputSwitchPending = false
    pendingTimer = nil

    Log.windowStateChanged(isOpen: false, reason: "timer expired")
  }

  private func handleDeviceListChanged() {
    let allIDs = deviceProvider.allDeviceIDs()
    let currentIDSet = Set(allIDs)

    // Build device info map
    var deviceInfoMap: [AudioDeviceID: Log.DeviceInfo] = [:]
    for id in allIDs {
      guard let name = deviceProvider.name(of: id) else {
        continue
      }
      deviceInfoMap[id] = Log.DeviceInfo(
        name: name,
        transport: deviceProvider.transportTypeName(of: id),
        hasInput: deviceProvider.hasInput(id),
        hasOutput: deviceProvider.hasOutput(id)
      )
    }

    // Detect added and removed devices
    let addedIDs = currentIDSet.subtracting(previousDeviceIDs)
    let removedIDs = previousDeviceIDs.subtracting(currentIDSet)

    let addedDevices = addedIDs.compactMap { deviceInfoMap[$0] }
    let removedDevices = removedIDs.compactMap { previousDeviceInfos[$0] }

    // Build separate input and output lists
    let inputDevices = deviceInfoMap.values.filter(\.hasInput)
    let outputDevices = deviceInfoMap.values.filter(\.hasOutput)

    // Log the changes
    Log.deviceListChanged(
      inputs: Array(inputDevices),
      outputs: Array(outputDevices),
      added: addedDevices,
      removed: removedDevices,
      defaultInput: currentInputName,
      defaultOutput: currentOutputName
    )

    // Update previous state for next comparison
    previousDeviceIDs = currentIDSet
    previousDeviceInfos = deviceInfoMap
  }
}
