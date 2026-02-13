//
//  AudioDevice.swift
//  MicLatch
//
//  Copyright © 2026 Mingxuan Wang. All rights reserved.
//

import CoreAudio
import Foundation

// MARK: - AudioDevice

/// Core Audio HAL helpers for device discovery and manipulation.
enum AudioDevice {
  // MARK: Internal

  /// System audio object ID.
  static let systemObjectID = AudioObjectID(kAudioObjectSystemObject)

  // MARK: - Device Discovery

  /// Get all audio device IDs in the system.
  static func allDeviceIDs() -> [AudioDeviceID] {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var dataSize: UInt32 = 0
    var status = AudioObjectGetPropertyDataSize(systemObjectID, &address, 0, nil, &dataSize)
    guard status == noErr, dataSize > 0 else {
      return []
    }

    let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
    var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

    status = AudioObjectGetPropertyData(systemObjectID, &address, 0, nil, &dataSize, &deviceIDs)
    guard status == noErr else {
      return []
    }

    return deviceIDs
  }

  // MARK: - Device Properties

  /// Get the name of an audio device.
  static func name(of deviceID: AudioDeviceID) -> String? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyDeviceNameCFString,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var name: Unmanaged<CFString>?
    var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)

    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &name)
    guard status == noErr, let nameRef = name else {
      return nil
    }

    return nameRef.takeRetainedValue() as String
  }

  /// Get the transport type of an audio device.
  static func transportType(of deviceID: AudioDeviceID) -> AudioDevicePropertyID {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyTransportType,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var transport: UInt32 = 0
    var dataSize = UInt32(MemoryLayout<UInt32>.size)

    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &transport)
    guard status == noErr else {
      return 0
    }

    return transport
  }

  /// Check if a device uses Bluetooth transport.
  static func isBluetooth(_ deviceID: AudioDeviceID) -> Bool {
    transportType(of: deviceID) == kAudioDeviceTransportTypeBluetooth
  }

  /// Get transport type as human-readable string.
  static func transportTypeName(of deviceID: AudioDeviceID) -> String {
    let transport = transportType(of: deviceID)
    return transportTypeNames[transport] ?? "unknown(\(transport))"
  }

  /// Check if a device is alive (connected and working).
  static func isAlive(_ deviceID: AudioDeviceID) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyDeviceIsAlive,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var isAlive: UInt32 = 0
    var dataSize = UInt32(MemoryLayout<UInt32>.size)

    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &isAlive)
    guard status == noErr else {
      return false
    }

    return isAlive != 0
  }

  // MARK: - Input/Output Capability

  /// Check if a device has input capability (microphone).
  static func hasInput(_ deviceID: AudioDeviceID) -> Bool {
    hasStreams(deviceID, scope: kAudioDevicePropertyScopeInput)
  }

  /// Check if a device has output capability (speaker/headphones).
  static func hasOutput(_ deviceID: AudioDeviceID) -> Bool {
    hasStreams(deviceID, scope: kAudioDevicePropertyScopeOutput)
  }

  // MARK: - Default Devices

  /// Get the default input device ID.
  static func defaultInputID() -> AudioDeviceID? {
    getDefaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice)
  }

  /// Get the default output device ID.
  static func defaultOutputID() -> AudioDeviceID? {
    getDefaultDevice(selector: kAudioHardwarePropertyDefaultOutputDevice)
  }

  /// Get the default system output device ID.
  static func defaultSystemOutputID() -> AudioDeviceID? {
    getDefaultDevice(selector: kAudioHardwarePropertyDefaultSystemOutputDevice)
  }

  // MARK: - Set Default Devices

  /// Set the default input device.
  /// - Returns: `true` if successful, `false` otherwise.
  @discardableResult
  static func setDefaultInput(_ deviceID: AudioDeviceID) -> Bool {
    setDefaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice, to: deviceID)
  }

  /// Set the default output device.
  /// - Returns: `true` if successful, `false` otherwise.
  @discardableResult
  static func setDefaultOutput(_ deviceID: AudioDeviceID) -> Bool {
    setDefaultDevice(selector: kAudioHardwarePropertyDefaultOutputDevice, to: deviceID)
  }

  // MARK: - Listeners

  /// Add a property listener to the system audio object.
  /// - Returns: A closure to remove the listener, or `nil` if adding failed.
  static func addListener(
    selector: AudioObjectPropertySelector,
    handler: @escaping () -> Void
  )
    -> (() -> Void)?
  {
    var address = AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    let listenerBlock: AudioObjectPropertyListenerBlock = { _, _ in
      handler()
    }

    let status = AudioObjectAddPropertyListenerBlock(systemObjectID, &address, nil, listenerBlock)

    guard status == noErr else {
      Log.serviceError("Failed to add property listener for \(selector)", code: status)
      return nil
    }

    return { [listenerBlock] in
      var addr = address
      AudioObjectRemovePropertyListenerBlock(Self.systemObjectID, &addr, nil, listenerBlock)
    }
  }

  // MARK: Private

  private static let transportTypeNames: [UInt32: String] = [
    kAudioDeviceTransportTypeBuiltIn: "built-in",
    kAudioDeviceTransportTypeBluetooth: "bluetooth",
    kAudioDeviceTransportTypeBluetoothLE: "bluetooth-le",
    kAudioDeviceTransportTypeUSB: "usb",
    kAudioDeviceTransportTypeFireWire: "firewire",
    kAudioDeviceTransportTypeAggregate: "aggregate",
    kAudioDeviceTransportTypeVirtual: "virtual",
    kAudioDeviceTransportTypeDisplayPort: "displayport",
    kAudioDeviceTransportTypeHDMI: "hdmi",
    kAudioDeviceTransportTypePCI: "pci",
    kAudioDeviceTransportTypeThunderbolt: "thunderbolt",
    kAudioDeviceTransportTypeAVB: "avb",
    kAudioDeviceTransportTypeAirPlay: "airplay",
    kAudioDeviceTransportTypeContinuityCaptureWired: "continuity-wired",
    kAudioDeviceTransportTypeContinuityCaptureWireless: "continuity-wireless",
  ]

  private static func hasStreams(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreams,
      mScope: scope,
      mElement: kAudioObjectPropertyElementMain
    )

    var dataSize: UInt32 = 0
    let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)
    guard status == noErr else {
      return false
    }

    return dataSize > 0
  }

  private static func getDefaultDevice(selector: AudioObjectPropertySelector) -> AudioDeviceID? {
    var address = AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var deviceID: AudioDeviceID = 0
    var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

    let status = AudioObjectGetPropertyData(systemObjectID, &address, 0, nil, &dataSize, &deviceID)
    guard status == noErr, deviceID != kAudioDeviceUnknown else {
      return nil
    }

    return deviceID
  }

  private static func setDefaultDevice(
    selector: AudioObjectPropertySelector, to deviceID: AudioDeviceID
  )
    -> Bool
  {
    var address = AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var mutableDeviceID = deviceID
    let status = AudioObjectSetPropertyData(
      systemObjectID,
      &address,
      0,
      nil,
      UInt32(MemoryLayout<AudioDeviceID>.size),
      &mutableDeviceID
    )

    if status != noErr {
      Log.serviceError("Failed to set default device", code: status)
    }
    return status == noErr
  }
}
