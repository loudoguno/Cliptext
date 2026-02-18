#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

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

echo "Built: build/Cliptext.app"
echo "Run with: open build/Cliptext.app"
