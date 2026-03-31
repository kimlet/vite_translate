#!/bin/bash
# Build whisper.cpp as a static xcframework for iOS.
# Outputs: native/build/ios/whisper.xcframework

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WHISPER_DIR="$PROJECT_ROOT/native/whisper.cpp"
BUILD_DIR="$PROJECT_ROOT/native/build/ios"
OUTPUT_DIR="$BUILD_DIR/xcframework"

echo "=== Building whisper.cpp for iOS ==="

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# --- Build for iOS device (arm64) ---
echo "--- Building for iOS device (arm64) ---"
cmake -S "$WHISPER_DIR" -B "$BUILD_DIR/ios-arm64" \
    -DCMAKE_TOOLCHAIN_FILE="$WHISPER_DIR/cmake/ios.toolchain.cmake" \
    -DPLATFORM=OS64 \
    -DCMAKE_OSX_ARCHITECTURES="arm64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DWHISPER_BUILD_EXAMPLES=OFF \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_SERVER=OFF \
    -DGGML_METAL=ON \
    -DGGML_ACCELERATE=ON \
    -DCMAKE_BUILD_TYPE=Release \
    2>&1 | tail -5

# If ios.toolchain.cmake doesn't exist, use standard iOS cross-compilation
if [ $? -ne 0 ]; then
    echo "--- Falling back to standard iOS cross-compilation ---"
    cmake -S "$WHISPER_DIR" -B "$BUILD_DIR/ios-arm64" \
        -G Xcode \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_ARCHITECTURES="arm64" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
        -DWHISPER_BUILD_EXAMPLES=OFF \
        -DWHISPER_BUILD_TESTS=OFF \
        -DWHISPER_BUILD_SERVER=OFF \
        -DGGML_METAL=ON \
        -DGGML_ACCELERATE=ON \
        -DCMAKE_BUILD_TYPE=Release \
        2>&1 | tail -5
fi

cmake --build "$BUILD_DIR/ios-arm64" --config Release -- -j$(sysctl -n hw.ncpu) 2>&1 | tail -10

# --- Build for iOS simulator (arm64 for Apple Silicon) ---
echo "--- Building for iOS simulator (arm64) ---"
cmake -S "$WHISPER_DIR" -B "$BUILD_DIR/ios-sim-arm64" \
    -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES="arm64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DWHISPER_BUILD_EXAMPLES=OFF \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_SERVER=OFF \
    -DGGML_METAL=ON \
    -DGGML_ACCELERATE=ON \
    -DCMAKE_BUILD_TYPE=Release \
    2>&1 | tail -5

cmake --build "$BUILD_DIR/ios-sim-arm64" --config Release -- -j$(sysctl -n hw.ncpu) 2>&1 | tail -10

# --- Find built static libraries ---
echo "--- Locating built libraries ---"
find "$BUILD_DIR/ios-arm64" -name "*.a" -not -path "*/CMakeFiles/*" 2>/dev/null | head -20

echo ""
echo "=== Build complete ==="
echo "Static libraries are in: $BUILD_DIR"
echo ""
echo "Next: Create xcframework and link into Xcode project"
