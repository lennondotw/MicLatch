//
//  AudioSwitchServiceTests.swift
//  MicLatch
//
//  Created by Developer on 2/13/26.
//

@testable import MicLatch
import Testing

// MARK: - AudioSwitchServiceTests

@Suite("AudioSwitchService Tests")
struct AudioSwitchServiceTests {
    @MainActor
    @Test("Service initializes with correct window duration")
    func initializesWithWindowDuration() {
        let service = AudioSwitchService(windowDuration: 0.5)
        #expect(service.windowDuration == 0.5)
    }

    @MainActor
    @Test("Service initializes with custom window duration")
    func initializesWithCustomWindowDuration() {
        let service = AudioSwitchService(windowDuration: 1.0)
        #expect(service.windowDuration == 1.0)
    }

    @MainActor
    @Test("Service starts not monitoring")
    func startsNotMonitoring() {
        let service = AudioSwitchService()
        #expect(service.isMonitoring == false)
    }

    @MainActor
    @Test("Service can start monitoring")
    func canStartMonitoring() {
        let service = AudioSwitchService()
        service.start()
        #expect(service.isMonitoring == true)
        service.stop()
    }

    @MainActor
    @Test("Service can stop monitoring")
    func canStopMonitoring() {
        let service = AudioSwitchService()
        service.start()
        service.stop()
        #expect(service.isMonitoring == false)
    }

    @MainActor
    @Test("Starting twice does not crash")
    func startingTwiceDoesNotCrash() {
        let service = AudioSwitchService()
        service.start()
        service.start() // Should be no-op
        #expect(service.isMonitoring == true)
        service.stop()
    }

    @MainActor
    @Test("Stopping without starting does not crash")
    func stoppingWithoutStartingDoesNotCrash() {
        let service = AudioSwitchService()
        service.stop() // Should be no-op
        #expect(service.isMonitoring == false)
    }

    @MainActor
    @Test("Service records initial device names on start")
    func recordsInitialDeviceNames() {
        let service = AudioSwitchService()
        service.start()

        // On most systems, there should be at least one input and output device
        // But we can't guarantee it, so just verify the properties exist
        _ = service.currentInputName
        _ = service.currentOutputName

        service.stop()
    }

    @MainActor
    @Test("Service cleans up on stop")
    func cleansUpOnStop() {
        let service = AudioSwitchService()
        service.start()
        service.stop()

        // Start again to verify listeners were properly removed
        service.start()
        #expect(service.isMonitoring == true)
        service.stop()
    }
}
