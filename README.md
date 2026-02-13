# MicLatch

A macOS application built with Swift and SwiftUI.

## Toolchain Requirements

| Tool | Version | Purpose |
|------|---------|---------|
| **Xcode** | 26.2 | IDE and build tools |
| **Swift** | 6.2.3 | Programming language |
| **macOS SDK** | 26.2 | Platform SDK |
| **iOS SDK** | 26.2 | Platform SDK (if needed) |
| **Deployment Target** | macOS 15.0+ | Minimum supported OS |

> **Note**: Requires macOS Sequoia 15.6 or later to run Xcode 26.2.

## Development Tools

| Tool | Purpose | Installation |
|------|---------|--------------|
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | Project generation from YAML | `brew install xcodegen` |
| [SwiftLint](https://github.com/realm/SwiftLint) | Swift linting | `brew install swiftlint` |
| [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) | Code formatting | `brew install swiftformat` |
| [just](https://just.systems) | Task runner | `brew install just` |
| [xcbeautify](https://github.com/cpisciotta/xcbeautify) | Build log formatter | `brew install xcbeautify` |

## Quick Start

```bash
# Install all dependencies
brew install xcodegen swiftlint swiftformat just xcbeautify

# Generate Xcode project
just generate

# Open in Xcode
just open

# Or build from command line
just build
```

## Project Structure

```
MicLatch/
├── Sources/
│   ├── MicLatch/              # macOS app target
│   │   ├── MicLatchApp.swift  # App entry point
│   │   ├── Info.plist
│   │   └── MicLatch.entitlements
│   └── MicLatchKit/           # Shared Swift Package
│       └── MicLatchKit.swift
├── Tests/
│   ├── MicLatchTests/         # App unit tests
│   └── MicLatchKitTests/      # Package unit tests
├── project.yml                # XcodeGen specification
├── Package.swift              # Swift Package manifest
├── justfile                   # Task definitions
├── .swiftlint.yml             # SwiftLint configuration
└── .swiftformat               # SwiftFormat configuration
```

## Available Commands

Run `just` to see all available commands:

### Project Management

```bash
just generate       # Generate Xcode project
just clean          # Clean build artifacts
just regen          # Clean and regenerate
just open           # Open project in Xcode
```

### Build

```bash
just build          # Build Debug configuration
just build-release  # Build Release configuration
just build-package  # Build Swift Package only
```

### Test

```bash
just test           # Run all tests
just test-package   # Run Swift Package tests
just test-coverage  # Run tests with coverage
```

### Lint & Format

```bash
just lint           # Run SwiftLint
just lint-fix       # Run SwiftLint with autocorrect
just format         # Format code with SwiftFormat
just format-check   # Check formatting without changes
just check          # Run all checks (lint + format)
just fix            # Fix all issues (lint + format)
```

### CI / Release

```bash
just ci             # Full CI pipeline
just archive        # Create release archive
```

### Setup

```bash
just setup          # Show setup instructions
just verify         # Verify toolchain versions
just info           # Print project information
```

## Swift Package

`MicLatchKit` is a Swift Package that can be consumed independently:

```swift
// Package.swift
dependencies: [
    .package(path: "../MicLatch")
]

// Target
.target(
    name: "YourTarget",
    dependencies: ["MicLatchKit"]
)
```

Or use it directly with Swift Package Manager:

```bash
swift build
swift test
```

## Configuration Files

### XcodeGen (`project.yml`)

Defines the Xcode project structure, targets, schemes, and build settings. Regenerate the `.xcodeproj` anytime this file changes:

```bash
just generate
```

### SwiftLint (`.swiftlint.yml`)

Enforces Swift style and conventions. Integrates with Xcode as a build phase.

### SwiftFormat (`.swiftformat`)

Automatically formats Swift code. Run before committing:

```bash
just format
```

## Code Style

- Swift 6 with strict concurrency
- 4-space indentation
- 120 character line limit
- Sorted imports
- File headers required

## License

[Add your license here]
