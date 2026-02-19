#!/bin/bash
# Run the development build of Superwhisperfree

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="Superwhisperfree"

# Build first
echo "Building..."
"$PROJECT_DIR/scripts/dev-build.sh"

echo ""
echo "Starting $APP_NAME..."
echo "Press Ctrl+C to quit"
echo ""

# Change to project directory so relative paths work
cd "$PROJECT_DIR"

# Run the app
"$BUILD_DIR/$APP_NAME"
