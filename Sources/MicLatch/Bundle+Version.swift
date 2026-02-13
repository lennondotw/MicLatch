//
//  Bundle+Version.swift
//  MicLatch
//
//  Created by Developer on 2/13/26.
//

import Foundation

extension Bundle {
    /// App version from Info.plist (CFBundleShortVersionString).
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// Build number from Info.plist (CFBundleVersion).
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
}
