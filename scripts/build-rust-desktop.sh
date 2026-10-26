#!/bin/bash
set -euo pipefail

# Build script for the Trenino Rust desktop application.
# Builds the Rust UI, stages the native sidecars/resources, and packages the
# Tauri app with the Rust bundle configuration.
#
# Extra arguments are forwarded to the Tauri build
# (e.g. ./scripts/build-rust-desktop.sh --bundles appimage).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TAURI_DIR="$PROJECT_DIR/tauri/src-tauri"
BINARIES_DIR="$TAURI_DIR/binaries"
RESOURCES_DIR="$TAURI_DIR/resources"
AVRDUDE_VERSION="8.1"
AVRDUDE_WINDOWS_X64_SHA256="e4d571d81fee3387d51bfdedd0b6565e4c201e974101cac2caec7adfd6201da3"
AVRDUDE_MACOS_X86_64_SHA256="d7739fbb5d1fe649511121a695dac3f4ca5ccb348919bf1f45f9bc5a2ea0ce72"
VJOY_VERSION="2.2.2.0"

# Detect current platform
detect_platform() {
    case "$(uname -s)" in
        Darwin)
            case "$(uname -m)" in
                arm64) echo "aarch64-apple-darwin" ;;
                x86_64) echo "x86_64-apple-darwin" ;;
            esac
            ;;
        Linux)
            echo "x86_64-unknown-linux-gnu"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "x86_64-pc-windows-msvc"
            ;;
    esac
}

PLATFORM=$(detect_platform)
echo "Building for platform: $PLATFORM"

cd "$PROJECT_DIR"

# Step 1: Stage the avrdude sidecar. Windows downloads its pinned build below
# and macOS (Apple Silicon) fetches the official release; other targets
# require a standalone compatible tool staged explicitly before building.
if [ "$PLATFORM" = "aarch64-apple-darwin" ]; then
    # Upstream publishes no Apple Silicon macOS build; prefer a natively
    # installed avrdude (brew install avrdude) and fall back to the official
    # x86_64 build, which requires Rosetta 2 to run on Apple Silicon.
    mkdir -p "$BINARIES_DIR"
    AVRDUDE_BIN="$(command -v avrdude || true)"
    AVRDUDE_CONF=""
    if [ -n "$AVRDUDE_BIN" ]; then
        AVRDUDE_ROOT="$(cd "$(dirname "$AVRDUDE_BIN")/.." && pwd)"
        for CANDIDATE in "$AVRDUDE_ROOT/etc/avrdude.conf" /opt/homebrew/etc/avrdude.conf /usr/local/etc/avrdude.conf; do
            if [ -f "$CANDIDATE" ]; then AVRDUDE_CONF="$CANDIDATE"; break; fi
        done
    fi
    if [ -z "$AVRDUDE_BIN" ] || [ -z "$AVRDUDE_CONF" ]; then
        echo "==> Fetching official avrdude $AVRDUDE_VERSION for macOS (x86_64; requires Rosetta 2)..."
        AVRDUDE_STAGE=$(mktemp -d)
        if [ -z "$AVRDUDE_STAGE" ] || [ ! -d "$AVRDUDE_STAGE" ]; then
            echo "Error: could not create the avrdude staging directory" >&2
            exit 1
        fi
        trap 'if [ -n "${AVRDUDE_STAGE:-}" ] && [ -d "${AVRDUDE_STAGE:-}" ]; then rm -r "$AVRDUDE_STAGE"; fi' EXIT
        curl -fL -o "$AVRDUDE_STAGE/avrdude.tar.gz" \
            "https://github.com/avrdudes/avrdude/releases/download/v${AVRDUDE_VERSION}/avrdude_v${AVRDUDE_VERSION}_macOS_64bit.tar.gz"
        echo "$AVRDUDE_MACOS_X86_64_SHA256  $AVRDUDE_STAGE/avrdude.tar.gz" | shasum -a 256 -c -
        tar -xzf "$AVRDUDE_STAGE/avrdude.tar.gz" -C "$AVRDUDE_STAGE"
        AVRDUDE_BIN=$(find "$AVRDUDE_STAGE" -name "avrdude" -type f | head -1)
        AVRDUDE_CONF=$(find "$AVRDUDE_STAGE" -name "avrdude.conf" -type f | head -1)
        if [ -z "$AVRDUDE_BIN" ] || [ -z "$AVRDUDE_CONF" ]; then
            echo "Error: avrdude or avrdude.conf not found in the official archive" >&2
            exit 1
        fi
        echo "Warning: no native avrdude found; bundled the x86_64 build. Install one with 'brew install avrdude' for a native sidecar." >&2
    fi
    install -m 755 "$AVRDUDE_BIN" "$BINARIES_DIR/avrdude-$PLATFORM"
    install -m 644 "$AVRDUDE_CONF" "$BINARIES_DIR/avrdude.conf"
    if [ -n "${AVRDUDE_STAGE:-}" ] && [ -d "$AVRDUDE_STAGE" ]; then
        rm -r "$AVRDUDE_STAGE"
        unset AVRDUDE_STAGE
        trap - EXIT
    fi
elif [ "$PLATFORM" != "x86_64-pc-windows-msvc" ]; then
    for REQUIRED_INPUT in "$BINARIES_DIR/avrdude-$PLATFORM" "$BINARIES_DIR/avrdude.conf"; do
        if [ ! -f "$REQUIRED_INPUT" ]; then
            echo "Error: Rust bundle prerequisite missing: $REQUIRED_INPUT" >&2
            echo "Stage a standalone avrdude for $PLATFORM and its compatible avrdude.conf in $BINARIES_DIR before running this script. Non-Windows downloads are not automated." >&2
            exit 1
        fi
    done
fi

 # Step 2: Build the desktop UI and install the pinned Tauri CLI
 echo "==> Building Rust desktop UI..."
npm --prefix "$PROJECT_DIR/tauri" ci
 npm --prefix "$PROJECT_DIR/tauri/ui" ci
 npm --prefix "$PROJECT_DIR/tauri/ui" run build

# Step 3: Stage the pinned avrdude sidecar required by the Windows Tauri config.
if [ "$PLATFORM" = "x86_64-pc-windows-msvc" ]; then
    echo "==> Staging verified avrdude $AVRDUDE_VERSION sidecar..."
    mkdir -p "$BINARIES_DIR"
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PROJECT_DIR/scripts/download-avrdude.ps1" -Version "$AVRDUDE_VERSION" -ExpectedSha256 "$AVRDUDE_WINDOWS_X64_SHA256" -DestinationDirectory "$BINARIES_DIR" -TargetTriple "$PLATFORM"
fi

# Step 4: Build keystroke utility
echo "==> Building keystroke utility..."
cd "$PROJECT_DIR/tauri/keystroke"
cargo build --release
if [ "$PLATFORM" = "x86_64-pc-windows-msvc" ]; then
    install -m 755 "target/release/keystroke.exe" "$BINARIES_DIR/keystroke-$PLATFORM.exe"
else
    install -m 755 "target/release/keystroke" "$BINARIES_DIR/keystroke-$PLATFORM"
fi
echo "Copied keystroke to: $BINARIES_DIR/keystroke-$PLATFORM"

# Step 5: Stage the pinned vJoy runtime for Windows. The shared PowerShell
# helper downloads with checksum verification, checks the installer's
# Authenticode signature, and extracts the packaged resources.
if [ "$PLATFORM" = "x86_64-pc-windows-msvc" ]; then
    echo "==> Staging verified vJoy $VJOY_VERSION runtime..."
    mkdir -p "$RESOURCES_DIR"
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PROJECT_DIR/scripts/stage-vjoy-resources.ps1" -DestinationDirectory "$RESOURCES_DIR"
fi

# Step 6: Build Tauri application
echo "==> Building Tauri application..."
cd "$PROJECT_DIR/tauri"
RUST_BUNDLE_CONFIG="tauri.rust.conf.json"
if [ "$PLATFORM" = "x86_64-pc-windows-msvc" ]; then
    RUST_BUNDLE_CONFIG="tauri.rust.windows.conf.json"
fi
TRENINO_RUST_BUNDLE=1 npx tauri build --features "rust-ui" --config "src-tauri/$RUST_BUNDLE_CONFIG" "$@"

echo "==> Build complete!"
echo "Output: $TAURI_DIR/target/release/bundle/"
