#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# Kill running instance
pkill -x Cliptext 2>/dev/null && sleep 0.5 || true

echo "Building Cliptext..."
swift build -c release 2>&1

# Create .app bundle
APP_DIR="build/Cliptext.app/Contents"
mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources"

# Copy binary
cp .build/release/Cliptext "$APP_DIR/MacOS/Cliptext"

# Copy Info.plist
cp Sources/Cliptext/Info.plist "$APP_DIR/Info.plist"

# Reset Accessibility permission so macOS re-trusts the new binary.
# You'll need to re-toggle in System Settings > Accessibility after this.
tccutil reset Accessibility uno.loudog.Cliptext 2>/dev/null || true

echo ""
echo "Built: build/Cliptext.app"
echo "Run:   open build/Cliptext.app"
echo ""
echo "⚠️  Accessibility permission was reset (new binary)."
echo "   After launching, re-enable in: System Settings > Privacy > Accessibility"
