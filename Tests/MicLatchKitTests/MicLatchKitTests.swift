//
//  MicLatchKitTests.swift
//  MicLatch
//
//  Created by Developer on 2/13/26.
//

@testable import MicLatchKit
import Testing

// MARK: - MicLatchKitTests

@Suite("MicLatchKit Tests")
struct MicLatchKitTests {
    @Test("Version is correct")
    func versionIsCorrect() {
        #expect(MicLatchKit.version == "1.0.0")
    }

    @Test("Version is not empty")
    func versionNotEmpty() {
        #expect(!MicLatchKit.version.isEmpty)
    }
}
