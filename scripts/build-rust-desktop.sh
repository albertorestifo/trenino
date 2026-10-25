#!/bin/bash
set -euo pipefail

# Build script for the Trenino Rust desktop application.
# Builds the Rust UI, stages the native sidecars/resources, and packages the
# Tauri app with the Rust bundle configuration.
#
# Extra arguments are forwarded to `cargo tauri build`
# (e.g. ./scripts/build-rust-desktop.sh --bundles appimage).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TAURI_DIR="$PROJECT_DIR/tauri/src-tauri"
BINARIES_DIR="$TAURI_DIR/binaries"
RESOURCES_DIR="$TAURI_DIR/resources"
AVRDUDE_VERSION="8.1"
AVRDUDE_WINDOWS_X64_SHA256="e4d571d81fee3387d51bfdedd0b6565e4c201e974101cac2caec7adfd6201da3"
VJOY_VERSION="2.2.2.0"
VJOY_RELEASE_BASE="https://github.com/BrunnerInnovation/vJoy/releases/download/v$VJOY_VERSION"
VJOY_INSTALLER_SHA256="ef569a3105cd301b89580f18f60c66b339e95296acf2c0dfcaf4b4bbf8ab68fe"
VJOY_SDK_SHA256="0e796b185b66819d5fbeae645f3f038ecbfbbde837d3d3f06cba82ae1db07c67"
VJOY_LICENSE_SHA256="7f0ed151caab68bbfd1a37727c8fe75c94be45aff98a88d63bc7e46e3fb0c5e1"

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
    echo "==> Fetching avrdude $AVRDUDE_VERSION for macOS ARM64..."
    AVRDUDE_STAGE=$(mktemp -d)
    if [ -z "$AVRDUDE_STAGE" ] || [ ! -d "$AVRDUDE_STAGE" ]; then
        echo "Error: could not create the avrdude staging directory" >&2
        exit 1
    fi
    trap 'if [ -n "${AVRDUDE_STAGE:-}" ] && [ -d "${AVRDUDE_STAGE:-}" ]; then rm -r "$AVRDUDE_STAGE"; fi' EXIT
    mkdir -p "$BINARIES_DIR"
    curl -fL -o "$AVRDUDE_STAGE/avrdude.tar.gz" \
        "https://github.com/avrdudes/avrdude/releases/download/v${AVRDUDE_VERSION}/avrdude-v${AVRDUDE_VERSION}-macOS-arm64.tar.gz"
    tar -xzf "$AVRDUDE_STAGE/avrdude.tar.gz" -C "$AVRDUDE_STAGE"
    AVRDUDE_BIN=$(find "$AVRDUDE_STAGE" -name "avrdude" -type f | head -1)
    if [ -z "$AVRDUDE_BIN" ]; then
        echo "Error: avrdude binary not found in the official archive" >&2
        exit 1
    fi
    cp "$AVRDUDE_BIN" "$BINARIES_DIR/avrdude-$PLATFORM"
    chmod +x "$BINARIES_DIR/avrdude-$PLATFORM"
    AVRDUDE_CONF=$(find "$AVRDUDE_STAGE" -name "avrdude.conf" -type f | head -1)
    if [ -n "$AVRDUDE_CONF" ]; then
        cp "$AVRDUDE_CONF" "$BINARIES_DIR/avrdude.conf"
    else
        echo "Error: avrdude.conf not found in the official archive" >&2
        exit 1
    fi
    rm -r "$AVRDUDE_STAGE"
    unset AVRDUDE_STAGE
    trap - EXIT
elif [ "$PLATFORM" != "x86_64-pc-windows-msvc" ]; then
    for REQUIRED_INPUT in "$BINARIES_DIR/avrdude-$PLATFORM" "$BINARIES_DIR/avrdude.conf"; do
        if [ ! -f "$REQUIRED_INPUT" ]; then
            echo "Error: Rust bundle prerequisite missing: $REQUIRED_INPUT" >&2
            echo "Stage a standalone avrdude for $PLATFORM and its compatible avrdude.conf in $BINARIES_DIR before running this script. Non-Windows downloads are not automated." >&2
            exit 1
        fi
    done
fi

# Step 2: Build the desktop UI
echo "==> Building Rust desktop UI..."
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
    cp "target/release/keystroke.exe" "$BINARIES_DIR/keystroke-$PLATFORM.exe"
else
    cp "target/release/keystroke" "$BINARIES_DIR/keystroke-$PLATFORM"
fi
echo "Copied keystroke to: $BINARIES_DIR/keystroke-$PLATFORM"

# Step 5: Stage the pinned vJoy runtime for Windows. The release installer,
# SDK and license are independently checksum verified before extraction.
if [ "$PLATFORM" = "x86_64-pc-windows-msvc" ]; then
    echo "==> Staging verified vJoy $VJOY_VERSION runtime..."
    mkdir -p "$RESOURCES_DIR"
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PROJECT_DIR/scripts/download-vjoy.ps1" -Version "$VJOY_VERSION" -Url "$VJOY_RELEASE_BASE/vJoySetup_v2.2.2.0_Win10_Win11.exe" -ExpectedSha256 "$VJOY_INSTALLER_SHA256" -Destination "$RESOURCES_DIR/vJoySetup.exe"
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PROJECT_DIR/scripts/download-vjoy.ps1" -Version "$VJOY_VERSION-sdk" -Url "$VJOY_RELEASE_BASE/SDK.zip" -ExpectedSha256 "$VJOY_SDK_SHA256" -Destination "$RESOURCES_DIR/SDK.zip"
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PROJECT_DIR/scripts/download-vjoy.ps1" -Version "$VJOY_VERSION-license" -Url "https://raw.githubusercontent.com/BrunnerInnovation/vJoy/v$VJOY_VERSION/LICENSE.txt" -ExpectedSha256 "$VJOY_LICENSE_SHA256" -Destination "$RESOURCES_DIR/vJoy-LICENSE.txt"

    VJOY_STAGE=$(mktemp -d)
    if [ -z "$VJOY_STAGE" ] || [ ! -d "$VJOY_STAGE" ]; then
        echo "Error: could not create the vJoy staging directory"
        exit 1
    fi
    trap 'if [ -n "${VJOY_STAGE:-}" ] && [ -d "${VJOY_STAGE:-}" ]; then rm -r "$VJOY_STAGE"; fi' EXIT

    mkdir -p "$VJOY_STAGE/sdk"
    7z x -y -o"$VJOY_STAGE/sdk" "$RESOURCES_DIR/SDK.zip" >/dev/null
    cp "$VJOY_STAGE/sdk/SDK/lib/x64/vJoyInterface.dll" "$RESOURCES_DIR/vJoyInterface.dll"

    # vJoySetup.exe is an Inno Setup installer, so use its dedicated extractor.
    # 7-Zip remains in use above for the SDK.zip archive.
    mkdir -p "$VJOY_STAGE/installer"
    innoextract --silent --extract --output-dir "$VJOY_STAGE/installer" "$RESOURCES_DIR/vJoySetup.exe"
    VJOY_CONFIG="$VJOY_STAGE/installer/app/x64/vJoyConfig.exe"
    if [ ! -f "$VJOY_CONFIG" ]; then
        echo "Error: vJoyConfig.exe was not found in the verified installer"
        exit 1
    fi
    cp "$VJOY_CONFIG" "$RESOURCES_DIR/vJoyConfig.exe"
    VJOY_INSTALL_DLL="$VJOY_STAGE/installer/app/x64/vJoyInstall.dll"
    if [ ! -f "$VJOY_INSTALL_DLL" ]; then
        echo "Error: vJoyInstall.dll was not found in the verified installer"
        exit 1
    fi
    cp "$VJOY_INSTALL_DLL" "$RESOURCES_DIR/vJoyInstall.dll"
    rm "$RESOURCES_DIR/SDK.zip"
    rm -r "$VJOY_STAGE"
    unset VJOY_STAGE
    trap - EXIT
fi

# Step 6: Build Tauri application
echo "==> Building Tauri application..."
cd "$TAURI_DIR"
RUST_BUNDLE_CONFIG="tauri.rust.conf.json"
if [ "$PLATFORM" = "x86_64-pc-windows-msvc" ]; then
    RUST_BUNDLE_CONFIG="tauri.rust.windows.conf.json"
fi
TRENINO_RUST_BUNDLE=1 cargo tauri build --features "rust-ui desktop-updater" --config "$RUST_BUNDLE_CONFIG" "$@"

echo "==> Build complete!"
echo "Output: $TAURI_DIR/target/release/bundle/"
