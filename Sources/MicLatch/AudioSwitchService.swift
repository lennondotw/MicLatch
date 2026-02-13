//
//  AudioSwitchService.swift
//  MicLatch
//
//  Created by Developer on 2/13/26.
//

import CoreAudio
import Foundation

// MARK: - AudioSwitchService

/// Service that monitors audio device changes and restores input device
/// when output changes cause system-linked input switching.
///
/// ## How It Works
///
/// When the output device changes (e.g., switching to AirPods):
/// 1. We record the current input device as `previousInputDevice`
/// 2. We open a time window (`windowDuration`, default 500ms)
/// 3. If input changes within this window, we assume it's a system-linked switch
/// 4. We restore the input to `previousInputDevice`
/// 5. After the window expires, any input change is considered manual
///
@MainActor
final class AudioSwitchService: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(windowDuration: TimeInterval = 0.5) {
        self.windowDuration = windowDuration
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

    // MARK: - Public API

    /// Start monitoring audio device changes.
    func start() {
        guard !isMonitoring else {
            return
        }

        // Record initial state
        if let inputID = AudioDevice.defaultInputID() {
            previousInputDevice = inputID
            currentInputName = AudioDevice.name(of: inputID)
        }
        if let outputID = AudioDevice.defaultOutputID() {
            currentOutputName = AudioDevice.name(of: outputID)
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

    // MARK: - Private Methods

    private func setupListeners() {
        // Listen for output device changes
        if let remove = AudioDevice.addListener(
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
        if let remove = AudioDevice.addListener(
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
        if let remove = AudioDevice.addListener(
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
        let newOutputID = AudioDevice.defaultOutputID()
        let newOutput = newOutputID.flatMap { AudioDevice.name(of: $0) }

        // Skip if no actual change
        guard newOutput != oldOutput else {
            return
        }

        currentOutputName = newOutput
        Log.outputChanged(from: oldOutput, to: newOutput)

        // Record current input before system might change it
        if let currentInputID = AudioDevice.defaultInputID() {
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
            repeats: false,
            block: { [weak self] _ in
                Task { @MainActor in
                    self?.handleWindowExpired()
                }
            }
        )
    }

    private func handleInputChanged() {
        let oldInput = currentInputName
        guard let newInputID = AudioDevice.defaultInputID() else {
            return
        }
        let newInput = AudioDevice.name(of: newInputID)

        // Skip if no actual change
        guard newInput != oldInput else {
            return
        }

        currentInputName = newInput

        if outputSwitchPending {
            // Within window: check if this is a linked switch we should restore
            let elapsed = Date().timeIntervalSince(outputSwitchTime ?? Date())
            let elapsedMs = Int(elapsed * 1_000)

            Log.inputChanged(from: oldInput, to: newInput, isLinked: true)

            // Only restore if input changed to something different than our saved device
            if let previousID = previousInputDevice, newInputID != previousID {
                let previousName = AudioDevice.name(of: previousID) ?? "unknown"

                // Attempt to restore
                if AudioDevice.setDefaultInput(previousID) {
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
            Log.inputChanged(from: oldInput, to: newInput, isLinked: false)
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
        let allIDs = AudioDevice.allDeviceIDs()

        // For debug logging, we'd need to track previous list to compute added/removed
        // For now, just log the total count
        Log.deviceListChanged(added: [], removed: [], total: allIDs.count)

        // Log detailed info for each device at debug level
        for id in allIDs {
            let name = AudioDevice.name(of: id) ?? "unknown"
            let transport = AudioDevice.transportTypeName(of: id)
            let hasInput = AudioDevice.hasInput(id)
            let hasOutput = AudioDevice.hasOutput(id)
            let isAlive = AudioDevice.isAlive(id)

            Log.deviceState(
                id: id,
                name: name,
                transportType: transport,
                hasInput: hasInput,
                hasOutput: hasOutput,
                isAlive: isAlive
            )
        }

        // Log current defaults
        Log.defaultDevices(input: currentInputName, output: currentOutputName)
    }
}
