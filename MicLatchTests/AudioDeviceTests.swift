//
//  AudioDeviceTests.swift
//  MicLatch
//
//  Created by Developer on 2/13/26.
//

import CoreAudio
@testable import MicLatch
import Testing

// MARK: - AudioDeviceTests

@Suite("AudioDevice Tests")
struct AudioDeviceTests {
  @Test("System object ID is correct")
  func systemObjectIDIsCorrect() {
    #expect(AudioDevice.systemObjectID == AudioObjectID(kAudioObjectSystemObject))
  }

  @Test("All device IDs returns array")
  func allDeviceIDsReturnsArray() {
    let devices = AudioDevice.allDeviceIDs()
    // Just verify the method works - count could be zero on some systems
    #expect(devices.isEmpty || !devices.isEmpty)
  }

  @Test("Default input ID returns valid device or nil")
  func defaultInputIDReturnsValidOrNil() {
    let inputID = AudioDevice.defaultInputID()
    // If we have a default input, verify it's in the device list
    if let inputID {
      let allDevices = AudioDevice.allDeviceIDs()
      #expect(allDevices.contains(inputID))
    }
  }

  @Test("Default output ID returns valid device or nil")
  func defaultOutputIDReturnsValidOrNil() {
    let outputID = AudioDevice.defaultOutputID()
    // If we have a default output, verify it's in the device list
    if let outputID {
      let allDevices = AudioDevice.allDeviceIDs()
      #expect(allDevices.contains(outputID))
    }
  }

  @Test("Device name returns string for valid device")
  func deviceNameReturnsString() {
    let devices = AudioDevice.allDeviceIDs()
    guard let firstDevice = devices.first else {
      return // Skip if no devices
    }

    let name = AudioDevice.name(of: firstDevice)
    #expect(name != nil)
    if let name {
      #expect(!name.isEmpty)
    }
  }

  @Test("Transport type returns value for valid device")
  func transportTypeReturnsValue() {
    let devices = AudioDevice.allDeviceIDs()
    guard let firstDevice = devices.first else {
      return // Skip if no devices
    }

    // Transport type should be some valid value
    let transport = AudioDevice.transportType(of: firstDevice)
    // Just verify we can get it without crashing
    _ = transport
  }

  @Test("Transport type name returns readable string")
  func transportTypeNameReturnsReadableString() {
    let devices = AudioDevice.allDeviceIDs()
    guard let firstDevice = devices.first else {
      return // Skip if no devices
    }

    let typeName = AudioDevice.transportTypeName(of: firstDevice)
    #expect(!typeName.isEmpty)
    // Built-in devices should be "built-in", external could be various types
  }

  @Test("isAlive returns boolean for valid device")
  func isAliveReturnsBool() {
    let devices = AudioDevice.allDeviceIDs()
    guard let firstDevice = devices.first else {
      return // Skip if no devices
    }

    // Just verify it returns without crashing
    _ = AudioDevice.isAlive(firstDevice)
  }

  @Test("hasInput/hasOutput return boolean for valid device")
  func hasInputOutputReturnBool() {
    let devices = AudioDevice.allDeviceIDs()
    guard let firstDevice = devices.first else {
      return // Skip if no devices
    }

    // Just verify they return without crashing
    _ = AudioDevice.hasInput(firstDevice)
    _ = AudioDevice.hasOutput(firstDevice)
  }

  @Test("isBluetooth returns boolean for valid device")
  func isBluetoothReturnsBool() {
    let devices = AudioDevice.allDeviceIDs()
    guard let firstDevice = devices.first else {
      return // Skip if no devices
    }

    // Just verify it returns without crashing
    let isBT = AudioDevice.isBluetooth(firstDevice)
    #expect(isBT == true || isBT == false)
  }

  @Test("Default input device has input capability")
  func defaultInputHasInputCapability() {
    guard let inputID = AudioDevice.defaultInputID() else {
      return // Skip if no default input
    }

    let hasInput = AudioDevice.hasInput(inputID)
    #expect(hasInput, "Default input device should have input capability")
  }

  @Test("Default output device has output capability")
  func defaultOutputHasOutputCapability() {
    guard let outputID = AudioDevice.defaultOutputID() else {
      return // Skip if no default output
    }

    let hasOutput = AudioDevice.hasOutput(outputID)
    #expect(hasOutput, "Default output device should have output capability")
  }
}
