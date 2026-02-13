//
//  MenuBarView.swift
//  MicLatch
//
//  Created by Developer on 2/13/26.
//

import SwiftUI

// MARK: - MenuBarView

struct MenuBarView: View {
    // MARK: Internal

    @ObservedObject var service: AudioSwitchService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerSection

            Divider()

            // Device Status
            deviceStatusSection

            Divider()

            // Controls
            controlsSection

            Divider()

            // Footer
            footerSection
        }
        .frame(width: 280)
    }

    // MARK: Private

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            Image(systemName: service.isMonitoring ? "mic.fill" : "mic.slash")
                .font(.title2)
                .foregroundStyle(service.isMonitoring ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("MicLatch")
                    .font(.headline)

                Text(service.isMonitoring ? "Monitoring active" : "Monitoring paused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var deviceStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            deviceRow(
                icon: "speaker.wave.2.fill",
                label: "Output",
                value: service.currentOutputName ?? "Unknown"
            )

            deviceRow(
                icon: "mic.fill",
                label: "Input",
                value: service.currentInputName ?? "Unknown"
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var controlsSection: some View {
        VStack(spacing: 4) {
            Toggle(isOn: Binding(
                get: { service.isMonitoring },
                set: { newValue in
                    if newValue {
                        service.start()
                    } else {
                        service.stop()
                    }
                }
            )) {
                Text("Enable Protection")
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var footerSection: some View {
        HStack {
            Text("v\(AppInfo.version)")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Components

    private func deviceRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 45, alignment: .leading)

            Text(value)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    MenuBarView(service: AudioSwitchService())
        .frame(width: 280, height: 200)
}
