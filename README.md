# MicLatch

Prevent macOS from hijacking your microphone when connecting Bluetooth audio devices.

## The Problem

When you connect AirPods or other Bluetooth headphones to your Mac, macOS automatically switches both the **output** (speakers) and **input** (microphone) to the Bluetooth device. This triggers HFP (Hands-Free Profile) mode, which:

- Degrades audio quality significantly (narrowband codec)
- Forces your AirPods into a suboptimal mode designed for phone calls
- Happens even when you just want to listen to music with your preferred mic (e.g., a USB condenser mic)

## The Solution

MicLatch monitors audio device changes and intelligently restores your preferred input device when macOS performs a "linked switch" — where a Bluetooth output device change automatically triggers an input device change.

**Key Features:**

- **Bluetooth-aware**: Only triggers protection when Bluetooth devices are involved (both output and input)
- Detects system-initiated linked switches vs. non-linked changes
- Restores your *previous* input device, not a hardcoded one
- Uses a time-window algorithm (2s) to distinguish linked switches
- **Statistics dashboard**: tracks linked restores and unlinked switch count
- **Last Change**: shows the most recent input action with status
- Lightweight menu bar app with minimal resource usage
- Built-in auto-update via Sparkle

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│  Bluetooth Output Switch Detected (e.g., AirPods connected)     │
│                           │                                     │
│                           ▼                                     │
│              Record current input device                        │
│              Start 2s time window                               │
│                           │                                     │
│                           ▼                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Bluetooth input switch within window?                    │   │
│  │   YES → System linked switch → Restore previous input    │   │
│  │   NO  → Non-linked switch → Do nothing                   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

**Note:** Protection only activates when **both** the output and input switches involve Bluetooth devices. This avoids false positives when connecting USB audio interfaces, HDMI displays, or other non-Bluetooth devices.

## Requirements

- macOS 15.0 (Sequoia) or later

## Installation

Download the latest release from [GitHub Releases](https://github.com/lennondotw/MicLatch/releases/latest).

The app will automatically check for updates via Sparkle.

## Usage

1. Launch MicLatch — it appears as a microphone icon in the menu bar
2. Toggle "Enable Protection" to start monitoring
3. Connect your Bluetooth headphones as usual
4. MicLatch automatically restores your preferred microphone

**Menu Bar Dashboard:**

- **Output/Input**: Current audio devices
- **Linked Restores**: Input device auto-restored after Bluetooth output switch within time window
- **Unlinked Switches**: Input changes outside time window or from non-Bluetooth devices
- **Last Change**: Most recent input change event with status:
  - Restored → device was successfully restored
  - Failed → restore attempt failed (device unavailable)
  - Non-Linked → input changed outside protection scope

## Development

```bash
# Install dependencies
brew install xcodegen swiftlint swiftformat just xcbeautify

# Generate project and build
just build

# Run tests
just test

# Run the app
just run
```

See `just --list` for all available commands.

## License

MIT License. Copyright © 2026 Mingxuan Wang.
