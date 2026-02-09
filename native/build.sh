#!/usr/bin/env bash
#
# Builds the dnsolve_native library for the current platform.
#
# Usage:
#   ./build.sh            # Release build
#   ./build.sh --debug    # Debug build
#
# Output:
#   macOS:   target/release/libdnsolve_native.dylib
#   Linux:   target/release/libdnsolve_native.so
#   Windows: target/release/dnsolve_native.dll

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PROFILE="release"
if [[ "${1:-}" == "--debug" ]]; then
  PROFILE="debug"
fi

echo "Building dnsolve_native ($PROFILE)..."
cargo build --profile "$PROFILE"

# Determine the output library path.
OS="$(uname -s)"
case "$OS" in
  Darwin)
    LIB_NAME="libdnsolve_native.dylib"
    ;;
  Linux)
    LIB_NAME="libdnsolve_native.so"
    ;;
  MINGW*|MSYS*|CYGWIN*)
    LIB_NAME="dnsolve_native.dll"
    ;;
  *)
    echo "Unsupported OS: $OS"
    exit 1
    ;;
esac

LIB_PATH="target/$PROFILE/$LIB_NAME"

if [[ -f "$LIB_PATH" ]]; then
  echo ""
  echo "Build successful: $LIB_PATH"
  echo ""
  echo "To use with Dart, ensure the library is on the library search path:"
  echo "  - macOS/Linux: export LD_LIBRARY_PATH=\"$SCRIPT_DIR/target/$PROFILE:\$LD_LIBRARY_PATH\""
  echo "  - macOS:       export DYLD_LIBRARY_PATH=\"$SCRIPT_DIR/target/$PROFILE:\$DYLD_LIBRARY_PATH\""
  echo "  - Or copy $LIB_NAME next to your Dart executable."
else
  echo "Build failed: $LIB_PATH not found."
  exit 1
fi
