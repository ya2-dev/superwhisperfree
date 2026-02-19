#!/bin/bash
# Development build script for Superwhisperfree
# Compiles the Swift app without code signing

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="Superwhisperfree"
SOURCES_DIR="$PROJECT_DIR/Superwhisperfree/Sources"

echo "========================================="
echo "Building $APP_NAME (Development Build)"
echo "========================================="
echo ""

# Check for Xcode command line tools
if ! command -v swiftc &> /dev/null; then
    echo "Error: swiftc not found. Please install Xcode command line tools:"
    echo "  xcode-select --install"
    exit 1
fi

# Create build directory
mkdir -p "$BUILD_DIR"

echo "Finding Swift source files..."

# Use array to handle paths with spaces
SWIFT_FILES=()
while IFS= read -r -d '' file; do
    SWIFT_FILES+=("$file")
done < <(find "$SOURCES_DIR" -name "*.swift" -type f -print0)

# Count files for progress
FILE_COUNT=${#SWIFT_FILES[@]}
echo "Found $FILE_COUNT Swift files to compile."
echo ""

echo "Compiling..."

# Compile with swiftc
# -parse-as-library: Required for @main or explicit main.swift
# -target: macOS 13+ for modern APIs (SMAppService, etc.)
# -O: Optimization level (none for debug)
swiftc \
    -o "$BUILD_DIR/$APP_NAME" \
    -target arm64-apple-macos13.0 \
    -sdk "$(xcrun --show-sdk-path)" \
    -framework Cocoa \
    -framework AVFoundation \
    -framework Carbon \
    -framework ServiceManagement \
    -I "$SOURCES_DIR" \
    "${SWIFT_FILES[@]}"

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================="
    echo "Build successful!"
    echo "========================================="
    echo ""
    echo "Output: $BUILD_DIR/$APP_NAME"
    echo ""
    echo "To run:"
    echo "  $BUILD_DIR/$APP_NAME"
    echo ""
    echo "Or use: ./scripts/run-dev.sh"
else
    echo ""
    echo "Build failed!"
    exit 1
fi
