//
//  MicLatchApp.swift
//  MicLatch
//
//  Copyright © 2026 Mingxuan Wang. All rights reserved.
//

import MenuBarExtraAccess
import Sparkle
import SwiftUI

// MARK: - StatusItemController

/// Handles Option+Click on the menu bar status item using local event monitor.
/// Normal clicks let the system show the menu naturally.
@MainActor
private final class StatusItemController {
  // MARK: Internal

  weak var statusItem: NSStatusItem?
  var onOptionClick: (() -> Void)?

  /// Configures the status item for Option+Click handling.
  func configure(statusItem: NSStatusItem) {
    guard self.statusItem !== statusItem
    else {
      return
    }
    self.statusItem = statusItem
    startMonitor()
    Log.uiDebug("StatusItemController configured")
  }

  // MARK: Private

  private var monitor: Any?

  private func startMonitor() {
    guard monitor == nil
    else {
      return
    }

    // Use local monitor - it can consume the event to prevent menu
    monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
      guard let self,
            let button = statusItem?.button,
            let buttonWindow = button.window
      else {
        return event
      }

      // Check if click is on our status item
      let clickLocation = NSEvent.mouseLocation
      let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
      guard buttonFrame.contains(clickLocation) else {
        return event
      }

      // Check if Option key is pressed
      if event.modifierFlags.contains(.option) {
        Log.uiDebug("Option+Click detected")

        // Show native highlight feedback
        button.isHighlighted = true

        // Clear highlight on mouse up
        var mouseUpMonitor: Any?
        mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { event in
          button.isHighlighted = false
          if let monitor = mouseUpMonitor {
            NSEvent.removeMonitor(monitor)
          }
          return event
        }

        onOptionClick?()
        return nil // Consume event to prevent menu
      }

      return event // Let system handle normal click (show menu)
    }
  }
}

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
    .menuBarExtraAccess(isPresented: .constant(false)) { item in
      statusItemController.configure(statusItem: item)
      statusItemController.onOptionClick = { [service] in
        if service.isMonitoring {
          service.stop()
        } else {
          service.start()
        }
      }
      updateStatusItemAppearance(item)
    }
    .onChange(of: service.isMonitoring) {
      if let item = statusItemController.statusItem {
        updateStatusItemAppearance(item)
      }
    }
  }

  // MARK: Private

  @StateObject private var service = AudioSwitchService()

  private let updaterController: SPUStandardUpdaterController
  private let statusItemController = StatusItemController()

  private var iconName: String {
    service.isMonitoring ? "microphone.badge.plus.fill" : "microphone.slash.fill"
  }

  @ViewBuilder
  private var menuBarIcon: some View {
    #if DEBUG
      Image(nsImage: Self.makeDebugMenuBarIcon(symbolName: iconName))
        .frame(width: 20, height: 18)
    #else
      Image(systemName: iconName)
        .frame(width: 18, height: 18)
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

      // Use fixed canvas size to ensure consistent image dimensions
      let canvasSize = NSSize(width: 20, height: 18)
      let iconSize = baseIcon.size

      // Center the icon in the canvas
      let iconOrigin = NSPoint(
        x: (canvasSize.width - iconSize.width) / 2,
        y: (canvasSize.height - iconSize.height) / 2
      )

      // Dot center at bottom-right corner of canvas
      let dotCenter = NSPoint(
        x: canvasSize.width - dotDiameter / 2,
        y: dotDiameter / 2
      )

      let image = NSImage(size: canvasSize, flipped: false) { _ in
        guard let ctx = NSGraphicsContext.current?.cgContext else {
          return false
        }

        // 1) Draw base icon centered
        baseIcon.draw(in: NSRect(origin: iconOrigin, size: iconSize))

        // 2) Punch out a circular cutout around the dot using .clear blend mode
        ctx.setBlendMode(.clear)
        ctx.fillEllipse(
          in: CGRect(
            x: dotCenter.x - cutoutDiameter / 2,
            y: dotCenter.y - cutoutDiameter / 2,
            width: cutoutDiameter,
            height: cutoutDiameter
          )
        )

        // 3) Draw the yellow dot on top
        ctx.setBlendMode(.normal)
        ctx.setFillColor(NSColor.systemYellow.cgColor)
        ctx.fillEllipse(
          in: CGRect(
            x: dotCenter.x - dotDiameter / 2,
            y: dotCenter.y - dotDiameter / 2,
            width: dotDiameter,
            height: dotDiameter
          )
        )

        return true
      }

      // Non-template to preserve the yellow dot color
      image.isTemplate = false
      return image
    }
  #endif

  private func updateStatusItemAppearance(_ item: NSStatusItem) {
    item.button?.appearsDisabled = !service.isMonitoring
  }
}
