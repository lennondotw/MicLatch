# MicLatch

Prevent macOS from hijacking your microphone when connecting Bluetooth audio devices.

## The Problem

When you connect AirPods or other Bluetooth headphones to your Mac, macOS automatically switches both the **output** (speakers) and **input** (microphone) to the Bluetooth device. This triggers HFP (Hands-Free Profile) mode, which:

- Degrades audio quality significantly (narrowband codec)
- Forces your AirPods into a suboptimal mode designed for phone calls
- Happens even when you just want to listen to music with your preferred mic (e.g., a USB condenser mic)

## The Solution

MicLatch monitors audio device changes and intelligently restores your preferred input device when macOS performs a "linked switch" — where an output device change automatically triggers an input device change.

**Key Features:**

- Detects system-initiated input switches vs. user manual changes
- Restores your *previous* input device, not a hardcoded one
- Uses a time-window algorithm (500ms) to distinguish linked switches
- Lightweight menu bar app with minimal resource usage
- Built-in auto-update via Sparkle

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│  Output Switch Detected (e.g., AirPods connected)               │
│                           │                                     │
│                           ▼                                     │
│              Record current input device                        │
│              Start 500ms time window                            │
│                           │                                     │
│                           ▼                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Input switch within window?                              │   │
│  │   YES → System linked switch → Restore previous input    │   │
│  │   NO  → User manual switch → Do nothing                  │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

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
