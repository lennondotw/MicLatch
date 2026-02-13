# MicLatch - macOS Audio Routing Protection
# Run `just` or `just --list` to see all available commands

set shell := ["bash", "-eo", "pipefail", "-c"]

project_name := "MicLatch"
scheme := "MicLatch"
derived_data := ".build/DerivedData"
app_path := derived_data / "Build/Products/Debug" / project_name + ".app"
app_path_release := derived_data / "Build/Products/Release" / project_name + ".app"

# Auto-derived from project.yml
app_version := `grep 'MARKETING_VERSION:' project.yml | sed "s/.*['\"]\\([^'\"]*\\)['\"].*/\\1/"`
app_build := `grep 'CURRENT_PROJECT_VERSION:' project.yml | sed "s/.*['\"]\\([^'\"]*\\)['\"].*/\\1/"`

# Release configuration (fixed for distribution)
release_team_id := "NAP6NNQHV6"

default:
    @just --list

# ─────────────────────────────────────────────────────────────────────────────
# Development
# ─────────────────────────────────────────────────────────────────────────────

# Generate Xcode project from project.yml
generate:
    xcodegen generate

# Generate buildServer.json for xcode-build-server (LSP support)
setup-lsp: generate
    #!/usr/bin/env bash
    set -euo pipefail
    xcode-build-server config -scheme {{ scheme }} -workspace {{ project_name }}.xcodeproj/project.xcworkspace
    tmp=$(mktemp)
    jq '.build_root = "{{ justfile_directory() }}/{{ derived_data }}/{{ project_name }}"' buildServer.json > "$tmp" && mv "$tmp" buildServer.json
    echo "buildServer.json configured with local DerivedData"

# Build Debug configuration
build: generate
    xcodebuild -scheme {{ scheme }} -configuration Debug -derivedDataPath {{ derived_data }} \
        CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO build | xcbeautify

# Build Release configuration
build-release: generate
    xcodebuild -scheme {{ scheme }} -configuration Release -derivedDataPath {{ derived_data }} \
        CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO build | xcbeautify

# Kill running app (if any)
kill:
    @-pkill -x "{{ project_name }}" 2>/dev/null || true

# Run already-built Debug app (requires prior `just build`)
run-built:
    open "{{ app_path }}"

# Build and run Debug app
run: kill build run-built

# Run already-built Debug app in foreground (stdout/stderr in terminal)
run-built-fg:
    disclaim "{{ app_path }}/Contents/MacOS/{{ project_name }}"

# Build and run Debug in foreground (stdout/stderr in terminal)
run-fg: kill build run-built-fg

# Stream app logs filtered by MicLatch subsystem (Ctrl-C to stop)
logs:
    log stream --level debug --predicate 'subsystem BEGINSWITH "sh.lennon.MicLatch"'

# ─────────────────────────────────────────────────────────────────────────────
# Test
# ─────────────────────────────────────────────────────────────────────────────

# Build for testing only
test-build: generate
    xcodebuild -scheme {{ scheme }} -configuration Debug -derivedDataPath {{ derived_data }} \
        CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO build-for-testing | xcbeautify

# Run tests without rebuilding (requires prior `just test-build`)
test-run:
    xcodebuild -scheme {{ scheme }} -configuration Debug -derivedDataPath {{ derived_data }} \
        CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO test-without-building | xcbeautify

# Build and run unit tests
test: test-build test-run

# ─────────────────────────────────────────────────────────────────────────────
# Code Quality
# ─────────────────────────────────────────────────────────────────────────────

# Run SwiftLint (fails on warnings)
lint:
    swiftlint --strict --config .swiftlint.yml

# Check formatting without changes
format-check:
    swiftformat MicLatch MicLatchTests --lint --config .swiftformat

# Apply SwiftFormat
format:
    swiftformat MicLatch MicLatchTests --config .swiftformat

# Run all checks (lint + format)
check: lint format-check

# Auto-fix all fixable issues
fix:
    swiftlint --fix --config .swiftlint.yml
    swiftformat MicLatch MicLatchTests --config .swiftformat

# ─────────────────────────────────────────────────────────────────────────────
# Cleanup
# ─────────────────────────────────────────────────────────────────────────────

# Clean build artifacts
clean:
    rm -rf {{ derived_data }} .build build
    @echo "Cleaned build artifacts"

# Remove generated Xcode project
clean-project:
    rm -rf {{ project_name }}.xcodeproj
    @echo "Cleaned Xcode project"

# Clean everything
clean-all: clean clean-project
    rm -rf SourcePackages
    @echo "Cleaned everything"

# ─────────────────────────────────────────────────────────────────────────────
# Release
# Requires: Developer ID certificate + `just setup-notarization` (one-time)
# ─────────────────────────────────────────────────────────────────────────────

# Create Release archive
archive: generate
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Archiving Release build..."
    xcodebuild -scheme {{ scheme }} \
        -configuration Release \
        -archivePath build/{{ project_name }}.xcarchive \
        archive | xcbeautify
    echo "Archive created at build/{{ project_name }}.xcarchive"

# Export signed .app from archive
export-app:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ ! -d "build/{{ project_name }}.xcarchive" ]]; then
        echo "Error: Archive not found. Run 'just archive' first."
        exit 1
    fi
    echo "Exporting signed app..."
    xcodebuild -exportArchive \
        -archivePath build/{{ project_name }}.xcarchive \
        -exportPath build/export \
        -exportOptionsPlist ExportOptions.plist | xcbeautify
    echo "Exported to build/export/"

# Create zip from exported app
create-zip:
    #!/usr/bin/env bash
    set -euo pipefail
    APP_PATH="build/export/{{ project_name }}.app"
    ZIP_PATH="build/{{ project_name }}-{{ app_version }}.zip"
    if [[ ! -d "$APP_PATH" ]]; then
        echo "Error: App not found. Run 'just export-app' first."
        exit 1
    fi
    echo "Creating zip..."
    rm -f "$ZIP_PATH"
    ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
    echo "Created $ZIP_PATH"

# Submit zip to Apple for notarization and staple ticket
notarize:
    #!/usr/bin/env bash
    set -euo pipefail
    ZIP_PATH="build/{{ project_name }}-{{ app_version }}.zip"
    if [[ ! -f "$ZIP_PATH" ]]; then
        echo "Error: zip not found. Run 'just create-zip' first."
        exit 1
    fi
    echo "Submitting for notarization..."
    xcrun notarytool submit "$ZIP_PATH" \
        --keychain-profile "AC_PASSWORD" \
        --wait
    echo "Stapling notarization ticket..."
    xcrun stapler staple "build/export/{{ project_name }}.app"
    echo "Recreating zip with stapled ticket..."
    rm -f "$ZIP_PATH"
    ditto -c -k --sequesterRsrc --keepParent "build/export/{{ project_name }}.app" "$ZIP_PATH"
    echo "Notarization complete!"

# Full release: archive → export → zip → notarize
release: archive export-app create-zip notarize
    @echo ""
    @echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    @echo "Release {{ app_version }} (build {{ app_build }}) complete!"
    @echo "Zip: build/{{ project_name }}-{{ app_version }}.zip"
    @echo ""
    @echo "Next step — create GitHub Release:"
    @echo "  gh release create v{{ app_version }} build/{{ project_name }}-{{ app_version }}.zip --title 'v{{ app_version }}'"
    @echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─────────────────────────────────────────────────────────────────────────────
# Beta Testing
# ─────────────────────────────────────────────────────────────────────────────

# Build for beta testing (signed but not notarized)
beta: generate
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Building for beta testing..."
    xcodebuild -scheme {{ scheme }} \
        -configuration Release \
        -derivedDataPath {{ derived_data }} \
        build | xcbeautify
    rm -rf build/beta
    mkdir -p build/beta
    cp -R "{{ app_path_release }}" build/beta/
    echo ""
    echo "Beta build ready: build/beta/{{ project_name }}.app"
    echo "Testers: right-click → Open to bypass Gatekeeper."

# Package beta build as zip
beta-zip: beta
    #!/usr/bin/env bash
    set -euo pipefail
    cd build/beta
    zip -r ../{{ project_name }}-beta.zip {{ project_name }}.app
    echo "Created build/{{ project_name }}-beta.zip"

# ─────────────────────────────────────────────────────────────────────────────
# Version Management
# ─────────────────────────────────────────────────────────────────────────────

# Show current version and build number
version:
    @echo "{{ app_version }} (build {{ app_build }})"

# Bump version: just bump-version major | minor | patch | 1.2.3
bump-version part:
    #!/usr/bin/env bash
    set -euo pipefail
    current="{{ app_version }}"
    IFS='.' read -r major minor patch <<< "$current"
    case "{{ part }}" in
        major) new="$((major + 1)).0.0" ;;
        minor) new="${major}.$((minor + 1)).0" ;;
        patch) new="${major}.${minor}.$((patch + 1))" ;;
        *)     new="{{ part }}" ;;
    esac
    sed -i '' "s/MARKETING_VERSION: '.*'/MARKETING_VERSION: '$new'/" project.yml
    echo "Version: $current → $new (build {{ app_build }})"
    echo "Run 'just generate' to apply."

# Increment build number
bump-build:
    #!/usr/bin/env bash
    set -euo pipefail
    next=$(({{ app_build }} + 1))
    sed -i '' "s/CURRENT_PROJECT_VERSION: '.*'/CURRENT_PROJECT_VERSION: '$next'/" project.yml
    echo "Version: {{ app_version }} (build {{ app_build }} → $next)"
    echo "Run 'just generate' to apply."

# ─────────────────────────────────────────────────────────────────────────────
# Utilities
# ─────────────────────────────────────────────────────────────────────────────

# List code signing certificates
show-certs:
    @security find-identity -v -p codesigning

# Open project in Xcode
xcode: generate
    open {{ project_name }}.xcodeproj

# Store notarization credentials in Keychain (one-time)
setup-notarization apple_id:
    @echo "You'll need an App-Specific Password from https://account.apple.com"
    xcrun notarytool store-credentials AC_PASSWORD --apple-id "{{ apple_id }}" --team-id {{ release_team_id }}
