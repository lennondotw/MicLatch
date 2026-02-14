//
//  AudioSwitchService.swift
//  MicLatch
//
//  Copyright © 2026 Mingxuan Wang. All rights reserved.
//

import Combine
import CoreAudio
import Foundation

// MARK: - AudioDeviceProviding

/// Protocol for audio device operations, enabling dependency injection for testing.
protocol AudioDeviceProviding: Sendable {
  func defaultInputID() -> AudioDeviceID?
  func defaultOutputID() -> AudioDeviceID?
  func name(of deviceID: AudioDeviceID) -> String?
  func transportTypeName(of deviceID: AudioDeviceID) -> String
  func isBluetooth(_ deviceID: AudioDeviceID) -> Bool
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

  func isBluetooth(_ deviceID: AudioDeviceID) -> Bool {
    AudioDevice.isBluetooth(deviceID)
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

// MARK: - LastInputChange

/// Represents the most recent input device change event.
enum LastInputChange: Equatable {
  /// Input was successfully restored after a linked switch.
  case restored(deviceName: String, timestamp: Date)

  /// Restore attempt failed.
  case restoreFailed(deviceName: String, timestamp: Date)

  /// Non-linked input switch (outside time window, or non-Bluetooth device).
  case nonLinked(from: String, to: String, timestamp: Date)
}

// MARK: - RecentInputChange

/// Records a recent input change for lookback detection.
struct RecentInputChange {
  let timestamp: Date
  let newInputID: AudioDeviceID
  let newInput: String?
  let oldInput: String?
  let previousInputDevice: AudioDeviceID?
  let transport: String
  let isBluetooth: Bool
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
    windowDuration: TimeInterval = 1.5,
    lookbackDuration: TimeInterval = 0.5,
    startImmediately: Bool = true,
    deviceProvider: any AudioDeviceProviding = RealAudioDeviceProvider()
  ) {
    self.windowDuration = windowDuration
    self.lookbackDuration = lookbackDuration
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

  /// Count of successful input restores (linked switch prevention).
  @Published private(set) var inputRestoreCount = 0

  /// Count of manual input switches (outside time window).
  @Published private(set) var nonLinkedInputSwitchCount = 0

  /// The most recent input change event.
  @Published private(set) var lastInputChange: LastInputChange?

  /// History of audio events (most recent first, limited to last 20).
  @Published private(set) var eventHistory: [AudioEvent] = []

  // MARK: - Configuration

  /// Duration of the time window after output change (in seconds).
  let windowDuration: TimeInterval

  /// Duration to look back for recent input changes when output changes (in seconds).
  let lookbackDuration: TimeInterval

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

    // Log initial device list
    let inputDevices = previousDeviceInfos.values.filter(\.hasInput)
    let outputDevices = previousDeviceInfos.values.filter(\.hasOutput)
    Log.initialDeviceList(
      inputs: Array(inputDevices),
      outputs: Array(outputDevices),
      defaultInput: currentInputName,
      defaultOutput: currentOutputName
    )
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

  /// Maximum number of events to keep in history.
  private let maxEventHistory = 20

  // MARK: - Private State

  /// The input device ID to restore to when linked switch detected.
  private var previousInputDevice: AudioDeviceID?

  /// Whether we're in the active time window after output change.
  private var outputSwitchPending = false

  /// Timer for the time window.
  private var pendingTimer: Timer?

  /// Timestamp when output change was detected.
  private var outputSwitchTime: Date?

  /// Number of restores performed in the current window.
  private var windowRestoreCount = 0

  /// Maximum restores allowed per window before auto-closing.
  private let maxRestoresPerWindow = 3

  /// Listener cleanup closures.
  private var listenerRemovers: [() -> Void] = []

  /// Previous device IDs for change detection.
  private var previousDeviceIDs: Set<AudioDeviceID> = []

  /// Previous device info for removed device logging.
  private var previousDeviceInfos: [AudioDeviceID: Log.DeviceInfo] = [:]

  /// Recent input change for lookback detection.
  private var recentInputChange: RecentInputChange?

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
    guard let newOutputID = deviceProvider.defaultOutputID()
    else {
      return
    }
    let newOutput = deviceProvider.name(of: newOutputID)
    let transport = deviceProvider.transportTypeName(of: newOutputID)
    let isBluetooth = deviceProvider.isBluetooth(newOutputID)

    // Skip if no actual change
    guard newOutput != oldOutput else {
      return
    }

    currentOutputName = newOutput
    Log.outputChanged(from: oldOutput, to: newOutput, transport: transport)

    // Record event and send notification for default output change
    if let newOutput {
      addEvent(.outputChanged(from: oldOutput, to: newOutput))
      NotificationService.shared.notifyDefaultOutputChanged(from: oldOutput, to: newOutput)
    }

    // Only enable protection for Bluetooth output switches (HFP concern)
    guard isBluetooth
    else {
      Log.debug("Output is not Bluetooth, skipping protection window")
      return
    }

    // Check lookback: was there a recent input change that should be linked?
    if let recent = recentInputChange,
       recent.isBluetooth,
       Date().timeIntervalSince(recent.timestamp) <= lookbackDuration
    {
      handleRetroactiveLinkedChange(recent)
      recentInputChange = nil
      return
    }

    // NOTE: We do NOT query defaultInputID() here because the system's linked switch
    // may have already completed by the time we receive the output change notification.
    // Instead, we rely on the previousInputDevice that was set during start() or
    // updated during non-linked input changes.
    Log.windowStateChanged(
      isOpen: true,
      reason: "Bluetooth output changed to \(newOutput ?? "unknown")"
    )

    // Start/reset time window (consecutive BT output changes reset the window)
    outputSwitchPending = true
    outputSwitchTime = Date()
    windowRestoreCount = 0

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
    guard let newInputID = deviceProvider.defaultInputID()
    else {
      return
    }
    let newInput = deviceProvider.name(of: newInputID)
    let transport = deviceProvider.transportTypeName(of: newInputID)

    // Skip if no actual change
    guard newInput != oldInput
    else {
      return
    }

    // Save previous input device before it gets overwritten
    let savedPreviousInputDevice = previousInputDevice

    currentInputName = newInput

    // Event recording and notification are handled in handleLinkedInputChange/recordNonLinkedChange
    // to provide proper context (linked/unlinked)

    if outputSwitchPending {
      handleLinkedInputChange(
        newInputID: newInputID,
        newInput: newInput,
        oldInput: oldInput,
        transport: transport
      )
    } else {
      recordNonLinkedChange(
        newInputID: newInputID,
        newInput: newInput,
        oldInput: oldInput,
        transport: transport,
        savedPreviousInputDevice: savedPreviousInputDevice
      )
    }
  }

  private func handleLinkedInputChange(
    newInputID: AudioDeviceID,
    newInput: String?,
    oldInput: String?,
    transport: String
  ) {
    let elapsed = Date().timeIntervalSince(outputSwitchTime ?? Date())
    let elapsedMs = Int(elapsed * 1000)
    let isBluetooth = deviceProvider.isBluetooth(newInputID)

    // Clear recent input change since we're handling a linked change now
    recentInputChange = nil

    // Only restore if input switched to a Bluetooth device (HFP concern)
    guard isBluetooth else {
      Log.inputChanged(from: oldInput, to: newInput, transport: transport, isLinked: false)
      Log.debug("Input is not Bluetooth, treating as non-linked change")
      recordNonLinkedChange(
        newInputID: newInputID,
        newInput: newInput,
        oldInput: oldInput,
        transport: transport,
        skipLog: true
      )
      return
    }

    Log.inputChanged(from: oldInput, to: newInput, transport: transport, isLinked: true)

    // Record input change event with linked context
    if let newInput {
      addEvent(.inputChanged(from: oldInput, to: newInput, context: .linked))
      NotificationService.shared.notifyDefaultInputChanged(from: oldInput, to: newInput, context: .linked)
    }

    // Only restore if input changed to something different than our saved device
    guard let previousID = previousInputDevice, newInputID != previousID else {
      Log.decisionNoChange(currentDevice: newInput ?? "unknown")
      return
    }

    let previousName = deviceProvider.name(of: previousID) ?? "unknown"
    if deviceProvider.setDefaultInput(previousID) {
      Log.decisionRestore(to: previousName, elapsedMs: elapsedMs)
      currentInputName = previousName
      inputRestoreCount += 1
      windowRestoreCount += 1
      lastInputChange = .restored(deviceName: previousName, timestamp: Date())
      addEvent(.inputRestored(deviceName: previousName))
      // Send notification for input restored (the primary feature)
      NotificationService.shared.notifyInputRestored(deviceName: previousName)

      // Close window if max restores reached
      if windowRestoreCount >= maxRestoresPerWindow {
        Log.windowStateChanged(isOpen: false, reason: "max restores (\(maxRestoresPerWindow)) reached")
        outputSwitchPending = false
        pendingTimer?.invalidate()
        pendingTimer = nil
      }
    } else {
      Log.decisionSkip(reason: "failed to restore input to \(previousName)")
      lastInputChange = .restoreFailed(deviceName: previousName, timestamp: Date())
      addEvent(.restoreFailed(deviceName: previousName))
    }
  }

  private func recordNonLinkedChange(
    newInputID: AudioDeviceID,
    newInput: String?,
    oldInput: String?,
    transport: String,
    skipLog: Bool = false,
    savedPreviousInputDevice: AudioDeviceID? = nil
  ) {
    if !skipLog {
      Log.inputChanged(from: oldInput, to: newInput, transport: transport, isLinked: false)
    }

    let isBluetooth = deviceProvider.isBluetooth(newInputID)

    // Save for lookback detection (only if Bluetooth, which might be linked)
    if isBluetooth {
      recentInputChange = RecentInputChange(
        timestamp: Date(),
        newInputID: newInputID,
        newInput: newInput,
        oldInput: oldInput,
        previousInputDevice: savedPreviousInputDevice ?? previousInputDevice,
        transport: transport,
        isBluetooth: true
      )
    } else {
      // Clear lookback if non-Bluetooth (can't be linked)
      recentInputChange = nil
    }

    previousInputDevice = newInputID
    nonLinkedInputSwitchCount += 1
    lastInputChange = .nonLinked(
      from: oldInput ?? "(none)",
      to: newInput ?? "(none)",
      timestamp: Date()
    )

    // Record input change event with unlinked context
    if let newInput {
      addEvent(.inputChanged(from: oldInput, to: newInput, context: .unlinked))
      NotificationService.shared.notifyDefaultInputChanged(from: oldInput, to: newInput, context: .unlinked)
    }
  }

  private func handleRetroactiveLinkedChange(_ recent: RecentInputChange) {
    let elapsed = Date().timeIntervalSince(recent.timestamp)
    let elapsedMs = Int(elapsed * 1000)

    Log.decisionReclassified(from: recent.oldInput, to: recent.newInput ?? "unknown", elapsedMs: elapsedMs)

    // Send reclassification notification
    if let newInput = recent.newInput {
      addEvent(.inputReclassifiedAsLinked(from: recent.oldInput, to: newInput))
      NotificationService.shared.notifyInputReclassifiedAsLinked(from: recent.oldInput, to: newInput)
    }

    // Decrement non-linked count (was incorrectly counted)
    if nonLinkedInputSwitchCount > 0 {
      nonLinkedInputSwitchCount -= 1
    }

    // Only restore if input changed to something different than our saved device
    guard let previousID = recent.previousInputDevice, recent.newInputID != previousID else {
      Log.decisionNoChange(currentDevice: recent.newInput ?? "unknown")
      return
    }

    let previousName = deviceProvider.name(of: previousID) ?? "unknown"
    if deviceProvider.setDefaultInput(previousID) {
      Log.decisionRestore(to: previousName, elapsedMs: -elapsedMs)
      currentInputName = previousName
      inputRestoreCount += 1
      lastInputChange = .restored(deviceName: previousName, timestamp: Date())
      addEvent(.inputRestored(deviceName: previousName))
      NotificationService.shared.notifyInputRestored(deviceName: previousName)
      // Update previousInputDevice to the restored device
      previousInputDevice = previousID
    } else {
      Log.decisionSkip(reason: "failed to restore input to \(previousName)")
      lastInputChange = .restoreFailed(deviceName: previousName, timestamp: Date())
      addEvent(.restoreFailed(deviceName: previousName))
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

  /// Add an event to the history (most recent first, limited size).
  private func addEvent(_ type: AudioEvent.EventType) {
    let event = AudioEvent(type: type, timestamp: Date())
    eventHistory.insert(event, at: 0)
    if eventHistory.count > maxEventHistory {
      eventHistory.removeLast()
    }
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

    // Skip logging if no actual device changes
    guard !addedDevices.isEmpty || !removedDevices.isEmpty else {
      // Still update state for next comparison
      previousDeviceIDs = currentIDSet
      previousDeviceInfos = deviceInfoMap
      return
    }

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

    // Record events and send notifications for device changes
    for device in removedDevices where device.hasInput {
      addEvent(.inputDeviceRemoved(deviceName: device.name))
      NotificationService.shared.notifyInputDeviceRemoved(deviceName: device.name)
    }
    for device in removedDevices where device.hasOutput {
      addEvent(.outputDeviceRemoved(deviceName: device.name))
      NotificationService.shared.notifyOutputDeviceRemoved(deviceName: device.name)
    }
    for device in addedDevices where device.hasInput {
      addEvent(.inputDeviceConnected(deviceName: device.name))
      NotificationService.shared.notifyInputDeviceConnected(deviceName: device.name)
    }
    for device in addedDevices where device.hasOutput {
      addEvent(.outputDeviceConnected(deviceName: device.name))
      NotificationService.shared.notifyOutputDeviceConnected(deviceName: device.name)
    }

    // Update previous state for next comparison
    previousDeviceIDs = currentIDSet
    previousDeviceInfos = deviceInfoMap
  }
}
