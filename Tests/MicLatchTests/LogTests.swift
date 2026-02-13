//
//  LogTests.swift
//  MicLatch
//
//  Created by Developer on 2/13/26.
//

@testable import MicLatch
import Testing

// MARK: - LogTests

@Suite("Log Tests")
struct LogTests {
    @Test("Log subsystem is correctly configured")
    func subsystemIsCorrect() {
        #expect(Log.subsystem == "com.reeky.MicLatch")
    }

    @Test("Event logging does not crash")
    func eventLoggingDoesNotCrash() {
        // These should not throw or crash
        Log.outputChanged(from: "Device A", to: "Device B")
        Log.outputChanged(from: nil, to: "Device B")
        Log.inputChanged(from: "Mic A", to: "Mic B", isLinked: true)
        Log.inputChanged(from: "Mic A", to: "Mic B", isLinked: false)
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
        Log.deviceListChanged(added: ["AirPods Pro"], removed: [], total: 5)
        Log.deviceListChanged(added: [], removed: ["AirPods Pro"], total: 4)
        Log.deviceListChanged(added: ["Device A"], removed: ["Device B"], total: 4)
        Log.deviceState(
            id: 42,
            name: "AirPods Pro",
            transportType: "bluetooth",
            hasInput: true,
            hasOutput: true,
            isAlive: true
        )
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
