//
//  MicLatchApp.swift
//  MicLatch
//
//  Copyright © 2026 Mingxuan Wang. All rights reserved.
//

import MenuBarExtraAccess
import Sparkle
import SwiftUI

// MARK: - MicLatchApp

@main
struct MicLatchApp: App {
  // MARK: Lifecycle

  init() {
    self.updaterController = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )
  }

  // MARK: Internal

  var body: some Scene {
    MenuBarExtra {
      MenuBarView(service: service, updater: updaterController.updater)
    } label: {
      menuBarIcon
    }
    .menuBarExtraAccess(isPresented: $menuPresented) { item in
      statusItem = item
      updateStatusItemAppearance()
    }
    .onChange(of: service.isMonitoring) {
      updateStatusItemAppearance()
    }
    .onChange(of: menuPresented) { _, isPresented in
      // Option+Click: toggle monitoring without showing menu
      if isPresented, NSEvent.modifierFlags.contains(.option) {
        menuPresented = false
        if service.isMonitoring {
          service.stop()
        } else {
          service.start()
        }
      }
    }
  }

  // MARK: Private

  @StateObject private var service = AudioSwitchService()
  @State private var statusItem: NSStatusItem?
  @State private var menuPresented = false

  private let updaterController: SPUStandardUpdaterController

  private var iconName: String {
    service.isMonitoring ? "microphone.badge.plus.fill" : "microphone.slash.fill"
  }

  // swiftlint:disable:next attributes
  @ViewBuilder
  private var menuBarIcon: some View {
    #if DEBUG
      Image(nsImage: Self.makeDebugMenuBarIcon(symbolName: iconName))
    #else
      Image(systemName: iconName)
    #endif
  }

  #if DEBUG
    /// Creates a menu bar icon with a small yellow indicator dot for debug builds.
    /// Uses SF Symbol palette rendering with `NSColor.labelColor` so the icon
    /// adapts to the menu bar appearance, while the dot stays yellow.
    private static func makeDebugMenuBarIcon(symbolName: String) -> NSImage {
      let symbolConfig = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        .applying(.init(paletteColors: [.labelColor]))

      guard let baseIcon = NSImage(
        systemSymbolName: symbolName,
        accessibilityDescription: "MicLatch"
      )?.withSymbolConfiguration(symbolConfig)
      else {
        // swiftlint:disable:next force_unwrapping
        return NSImage(systemSymbolName: symbolName, accessibilityDescription: "MicLatch")!
      }

      let dotDiameter: CGFloat = 5
      let cutoutPadding: CGFloat = 1.5
      let cutoutDiameter = dotDiameter + cutoutPadding * 2
      let baseSize = baseIcon.size

      // Dot center at bottom-right corner
      let dotCenter = NSPoint(
        x: baseSize.width - dotDiameter / 2,
        y: dotDiameter / 2
      )

      let image = NSImage(size: baseSize, flipped: false) { _ in
        guard let ctx = NSGraphicsContext.current?.cgContext else {
          return false
        }

        // 1) Draw base icon
        baseIcon.draw(in: NSRect(origin: .zero, size: baseSize))

        // 2) Punch out a circular cutout around the dot using .clear blend mode
        ctx.setBlendMode(.clear)
        ctx.fillEllipse(in: CGRect(
          x: dotCenter.x - cutoutDiameter / 2,
          y: dotCenter.y - cutoutDiameter / 2,
          width: cutoutDiameter,
          height: cutoutDiameter
        ))

        // 3) Draw the yellow dot on top
        ctx.setBlendMode(.normal)
        ctx.setFillColor(NSColor.systemYellow.cgColor)
        ctx.fillEllipse(in: CGRect(
          x: dotCenter.x - dotDiameter / 2,
          y: dotCenter.y - dotDiameter / 2,
          width: dotDiameter,
          height: dotDiameter
        ))

        return true
      }

      // Non-template to preserve the yellow dot color
      image.isTemplate = false
      return image
    }
  #endif

  private func updateStatusItemAppearance() {
    statusItem?.button?.appearsDisabled = !service.isMonitoring
  }
}
