# MicLatch Development Tasks
# https://just.systems/man/en/

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

# Default recipe to run when just is called without arguments
default:
    @just --list

# Project configuration
project_name := "MicLatch"
scheme := "MicLatch"
destination_macos := "platform=macOS"
derived_data := ".build/DerivedData"

# Toolchain versions (pinned)
xcode_version := "26.2"
swift_version := "6.0"
ios_deployment := "18.0"
macos_deployment := "15.0"

# ─────────────────────────────────────────────────────────────────────────────
# Project Generation
# ─────────────────────────────────────────────────────────────────────────────

# Generate Xcode project from project.yml
[group('project')]
generate:
    @echo "🔧 Generating Xcode project..."
    xcodegen generate
    @echo "✅ Project generated: {{project_name}}.xcodeproj"

# Clean generated project and derived data
[group('project')]
clean:
    @echo "🧹 Cleaning..."
    rm -rf "{{project_name}}.xcodeproj"
    rm -rf "{{derived_data}}"
    rm -rf .build
    rm -rf DerivedData
    @echo "✅ Clean complete"

# Regenerate project (clean + generate)
[group('project')]
regen: clean generate

# ─────────────────────────────────────────────────────────────────────────────
# Build
# ─────────────────────────────────────────────────────────────────────────────

# Build for macOS (Debug)
[group('build')]
build: generate
    @echo "🏗️  Building {{project_name}} (Debug)..."
    set -o pipefail && xcodebuild build \
        -project "{{project_name}}.xcodeproj" \
        -scheme "{{scheme}}" \
        -configuration Debug \
        -destination "{{destination_macos}}" \
        -derivedDataPath "{{derived_data}}" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        | xcbeautify
    @echo "✅ Build succeeded"

# Build for macOS (Release)
[group('build')]
build-release: generate
    @echo "🏗️  Building {{project_name}} (Release)..."
    set -o pipefail && xcodebuild build \
        -project "{{project_name}}.xcodeproj" \
        -scheme "{{scheme}}" \
        -configuration Release \
        -destination "{{destination_macos}}" \
        -derivedDataPath "{{derived_data}}" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        | xcbeautify
    @echo "✅ Release build succeeded"

# Build Swift Package only
[group('build')]
build-package:
    @echo "📦 Building Swift Package..."
    swift build
    @echo "✅ Package build succeeded"

# ─────────────────────────────────────────────────────────────────────────────
# Test
# ─────────────────────────────────────────────────────────────────────────────

# Run all tests
[group('test')]
test: generate
    @echo "🧪 Running tests..."
    set -o pipefail && xcodebuild test \
        -project "{{project_name}}.xcodeproj" \
        -scheme "{{scheme}}" \
        -destination "{{destination_macos}}" \
        -derivedDataPath "{{derived_data}}" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        | xcbeautify
    @echo "✅ Tests passed"

# Run Swift Package tests only
[group('test')]
test-package:
    @echo "🧪 Running Swift Package tests..."
    swift test
    @echo "✅ Package tests passed"

# Run tests with coverage
[group('test')]
test-coverage: generate
    @echo "🧪 Running tests with coverage..."
    set -o pipefail && xcodebuild test \
        -project "{{project_name}}.xcodeproj" \
        -scheme "{{scheme}}" \
        -destination "{{destination_macos}}" \
        -derivedDataPath "{{derived_data}}" \
        -enableCodeCoverage YES \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        | xcbeautify
    @echo "✅ Tests with coverage complete"

# ─────────────────────────────────────────────────────────────────────────────
# Lint & Format
# ─────────────────────────────────────────────────────────────────────────────

# Run SwiftLint
[group('lint')]
lint:
    @echo "🔍 Running SwiftLint..."
    swiftlint lint --config .swiftlint.yml
    @echo "✅ Lint complete"

# Run SwiftLint with autocorrect
[group('lint')]
lint-fix:
    @echo "🔧 Running SwiftLint with autocorrect..."
    swiftlint lint --config .swiftlint.yml --fix
    @echo "✅ Lint fix complete"

# Run SwiftFormat (check only)
[group('lint')]
format-check:
    @echo "🔍 Checking formatting..."
    swiftformat Sources Tests --lint --config .swiftformat
    @echo "✅ Format check complete"

# Run SwiftFormat (apply changes)
[group('lint')]
format:
    @echo "✨ Formatting code..."
    swiftformat Sources Tests --config .swiftformat
    @echo "✅ Format complete"

# Run both lint and format check
[group('lint')]
check: lint format-check
    @echo "✅ All checks passed"

# Fix all lint and format issues
[group('lint')]
fix: lint-fix format
    @echo "✅ All fixes applied"

# ─────────────────────────────────────────────────────────────────────────────
# Development
# ─────────────────────────────────────────────────────────────────────────────

# Open project in Xcode
[group('dev')]
open: generate
    @echo "📂 Opening Xcode..."
    open "{{project_name}}.xcodeproj"

# Run the app
[group('dev')]
run: build
    @echo "🚀 Running {{project_name}}..."
    open "{{derived_data}}/Build/Products/Debug/{{project_name}}.app"

# Watch for changes and rebuild (requires watchexec)
[group('dev')]
watch:
    @echo "👀 Watching for changes..."
    watchexec -e swift,yml -w Sources -w Tests -- just build

# ─────────────────────────────────────────────────────────────────────────────
# CI / Release
# ─────────────────────────────────────────────────────────────────────────────

# Full CI pipeline: lint, format check, build, test
[group('ci')]
ci: check build test
    @echo "✅ CI pipeline complete"

# Archive for distribution
[group('ci')]
archive: generate
    @echo "📦 Creating archive..."
    set -o pipefail && xcodebuild archive \
        -project "{{project_name}}.xcodeproj" \
        -scheme "{{scheme}}" \
        -configuration Release \
        -archivePath "{{derived_data}}/{{project_name}}.xcarchive" \
        | xcbeautify
    @echo "✅ Archive created: {{derived_data}}/{{project_name}}.xcarchive"

# ─────────────────────────────────────────────────────────────────────────────
# Setup
# ─────────────────────────────────────────────────────────────────────────────

# Install development dependencies (Homebrew)
[group('setup')]
setup:
    @echo "📥 Installing development dependencies..."
    @echo "⚠️  This will install packages via Homebrew. Please run manually:"
    @echo ""
    @echo "    brew install xcodegen swiftlint swiftformat just xcbeautify"
    @echo ""
    @echo "Or if you prefer to install now, run: just setup-force"

# Force install dependencies
[group('setup')]
setup-force:
    @echo "📥 Installing development dependencies..."
    brew install xcodegen swiftlint swiftformat just xcbeautify || true
    @echo "✅ Setup complete"

# Verify toolchain versions
[group('setup')]
verify:
    @echo "🔍 Verifying toolchain..."
    @echo ""
    @echo "Expected versions:"
    @echo "  Xcode:  {{xcode_version}}"
    @echo "  Swift:  {{swift_version}}"
    @echo ""
    @echo "Installed versions:"
    @xcodebuild -version | head -2
    @swift --version | head -1
    @echo ""
    @echo "Tool versions:"
    @xcodegen --version || echo "❌ xcodegen not installed"
    @swiftlint --version || echo "❌ swiftlint not installed"
    @swiftformat --version || echo "❌ swiftformat not installed"
    @xcbeautify --version || echo "❌ xcbeautify not installed"
    @just --version || echo "❌ just not installed"

# Print environment info
[group('setup')]
info:
    @echo "📋 Project Information"
    @echo "────────────────────────────────────────"
    @echo "Project:          {{project_name}}"
    @echo "Scheme:           {{scheme}}"
    @echo "Xcode Version:    {{xcode_version}}"
    @echo "Swift Version:    {{swift_version}}"
    @echo "iOS Deployment:   {{ios_deployment}}"
    @echo "macOS Deployment: {{macos_deployment}}"
    @echo "────────────────────────────────────────"
