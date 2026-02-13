//
//  AppInfo.swift
//  MicLatch
//
//  Created by Developer on 2/13/26.
//

import Foundation

// MARK: - AppInfo

/// Application version and build information.
enum AppInfo {
    /// App version from Info.plist (CFBundleShortVersionString).
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// Build number from Info.plist (CFBundleVersion).
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
}
