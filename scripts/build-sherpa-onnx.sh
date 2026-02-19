#!/bin/bash
set -e

# Build script for sherpa-onnx native library on macOS
# Prerequisites: cmake, git, C++ compiler (Xcode Command Line Tools)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VENDOR_DIR="$PROJECT_ROOT/vendor"
SHERPA_DIR="$VENDOR_DIR/sherpa-onnx"
BUILD_DIR="$SHERPA_DIR/build-macos"

echo "=== Building sherpa-onnx for macOS (arm64) ==="
echo "Project root: $PROJECT_ROOT"
echo "Vendor dir: $VENDOR_DIR"

# Check prerequisites
if ! command -v cmake &> /dev/null; then
    echo "ERROR: cmake is not installed."
    echo "Install with: brew install cmake"
    exit 1
fi

if ! command -v git &> /dev/null; then
    echo "ERROR: git is not installed."
    exit 1
fi

# Create vendor directory
mkdir -p "$VENDOR_DIR"

# Clone or update sherpa-onnx
if [ ! -d "$SHERPA_DIR" ]; then
    echo "Cloning sherpa-onnx..."
    cd "$VENDOR_DIR"
    git clone --depth 1 https://github.com/k2-fsa/sherpa-onnx.git
else
    echo "sherpa-onnx already cloned at $SHERPA_DIR"
fi

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure with CMake
echo "Configuring with CMake..."
cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DSHERPA_ONNX_ENABLE_BINARY=OFF \
  -DSHERPA_ONNX_ENABLE_PYTHON=OFF \
  -DSHERPA_ONNX_ENABLE_TESTS=OFF \
  -DSHERPA_ONNX_ENABLE_C_API=ON \
  -DCMAKE_OSX_ARCHITECTURES="arm64" \
  ..

# Build
echo "Building sherpa-onnx..."
cmake --build . --config Release -j4

# Verify build
echo ""
echo "=== Build Complete ==="
echo ""

# Find and display the built library
if [ -f "$BUILD_DIR/lib/libsherpa-onnx-c-api.a" ]; then
    echo "Static library: $BUILD_DIR/lib/libsherpa-onnx-c-api.a"
    ls -lh "$BUILD_DIR/lib/libsherpa-onnx-c-api.a"
elif [ -f "$BUILD_DIR/libsherpa-onnx-c-api.a" ]; then
    echo "Static library: $BUILD_DIR/libsherpa-onnx-c-api.a"
    ls -lh "$BUILD_DIR/libsherpa-onnx-c-api.a"
else
    echo "Looking for built libraries..."
    find "$BUILD_DIR" -name "*.a" -type f 2>/dev/null | head -20
fi

# Show header location
echo ""
echo "C API headers: $SHERPA_DIR/sherpa-onnx/c-api/"
ls -la "$SHERPA_DIR/sherpa-onnx/c-api/"*.h 2>/dev/null || echo "Headers not found in expected location"

echo ""
echo "Done!"
