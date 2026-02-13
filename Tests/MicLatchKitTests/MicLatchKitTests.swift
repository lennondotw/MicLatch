//
//  MicLatchKitTests.swift
//  MicLatchKitTests
//
//  Created by Developer on 13/02/2026.
//

import Testing

@testable import MicLatchKit

// MARK: - MicLatchKitTests

@Suite("MicLatchKit Tests")
struct MicLatchKitTests {
    @Test("Version is correct")
    func versionIsCorrect() async throws {
        #expect(MicLatchKit.version == "1.0.0")
    }

    @Test("Version is not empty")
    func versionNotEmpty() async throws {
        #expect(!MicLatchKit.version.isEmpty)
    }
}
