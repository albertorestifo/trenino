#!/bin/bash
set -e

# Build script for Trenino desktop application
# This script builds the Elixir backend and packages it with Tauri

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

# Windows inputs are downloaded and verified below. Other targets require a
# standalone compatible native tool staged explicitly before any build work.
if [ "${TRENINO_BUILD_RUST:-0}" = "1" ] && [ "$PLATFORM" != "x86_64-pc-windows-msvc" ]; then
    for REQUIRED_INPUT in "$BINARIES_DIR/avrdude-$PLATFORM" "$BINARIES_DIR/avrdude.conf"; do
        if [ ! -f "$REQUIRED_INPUT" ]; then
            echo "Error: Rust bundle prerequisite missing: $REQUIRED_INPUT" >&2
            echo "Stage a standalone avrdude for $PLATFORM and its compatible avrdude.conf in $BINARIES_DIR before running this wrapper. Non-Windows downloads are not automated." >&2
            exit 1
        fi
    done
fi

mkdir -p "$BINARIES_DIR"
if [ "${TRENINO_BUILD_RUST:-0}" = "1" ]; then
    echo "==> Building Rust desktop frontend..."
    npm --prefix "$PROJECT_DIR/tauri/ui" ci
    npm --prefix "$PROJECT_DIR/tauri/ui" run build
else
# Step 1: Build Phoenix assets
echo "==> Building Phoenix assets..."
MIX_ENV=prod mix assets.deploy

# Step 2: Build Elixir release with Burrito
echo "==> Building Elixir release..."
MIX_ENV=prod mix release trenino_desktop

# Step 3: Copy binary to Tauri binaries folder with platform suffix
echo "==> Copying binary to Tauri..."
mkdir -p "$BINARIES_DIR"

# Find the burrito output
BURRITO_OUTPUT="$PROJECT_DIR/burrito_out"
if [ -d "$BURRITO_OUTPUT" ]; then
    # Find the built binary (name varies by platform)
    BINARY=$(find "$BURRITO_OUTPUT" -type f -name "trenino_desktop*" | head -1)
    if [ -n "$BINARY" ]; then
        TARGET="$BINARIES_DIR/trenino_backend-$PLATFORM"
        if [ "$PLATFORM" = "x86_64-pc-windows-msvc" ]; then
            TARGET="$TARGET.exe"
        fi
        cp "$BINARY" "$TARGET"
        chmod +x "$TARGET"
        echo "Copied: $TARGET"
    else
        echo "Error: Could not find built binary in $BURRITO_OUTPUT"
        exit 1
    fi
else
    echo "Error: Burrito output directory not found"
    exit 1
fi

fi

# Step 4: Stage the pinned avrdude sidecar required by the Windows Tauri config.
if [ "$PLATFORM" = "x86_64-pc-windows-msvc" ]; then
    echo "==> Staging verified avrdude $AVRDUDE_VERSION sidecar..."
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PROJECT_DIR/scripts/download-avrdude.ps1" -Version "$AVRDUDE_VERSION" -ExpectedSha256 "$AVRDUDE_WINDOWS_X64_SHA256" -DestinationDirectory "$BINARIES_DIR" -TargetTriple "$PLATFORM"
fi

# Step 5: Build keystroke utility
echo "==> Building keystroke utility..."
cd "$PROJECT_DIR/tauri/keystroke"
cargo build --release
if [ "$PLATFORM" = "x86_64-pc-windows-msvc" ]; then
    cp "target/release/keystroke.exe" "$BINARIES_DIR/keystroke-$PLATFORM.exe"
else
    cp "target/release/keystroke" "$BINARIES_DIR/keystroke-$PLATFORM"
fi
echo "Copied keystroke to: $BINARIES_DIR/keystroke-$PLATFORM"

if [ "${TRENINO_BUILD_RUST:-0}" != "1" ]; then
# Step 6: Build the persistent virtual joystick sidecar on every platform.
# Non-Windows builds contain the sidecar's explicit unsupported-platform stub.
echo "==> Building virtual joystick sidecar..."
cd "$PROJECT_DIR/tauri/virtual_joystick"
cargo build --release
if [ "$PLATFORM" = "x86_64-pc-windows-msvc" ]; then
    cp "target/release/virtual_joystick.exe" "$BINARIES_DIR/virtual_joystick-$PLATFORM.exe"
else
    cp "target/release/virtual_joystick" "$BINARIES_DIR/virtual_joystick-$PLATFORM"
fi
echo "Copied virtual joystick to: $BINARIES_DIR/virtual_joystick-$PLATFORM"

fi

# Step 7: Stage the pinned vJoy runtime for Windows. The release installer,
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
    trap 'if [ -n "${VJOY_STAGE:-}" ] && [ -d "$VJOY_STAGE" ]; then rm -r "$VJOY_STAGE"; fi' EXIT

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

# Step 8: Build Tauri application
echo "==> Building Tauri application..."
cd "$TAURI_DIR"
if [ "${TRENINO_BUILD_RUST:-0}" = "1" ]; then
    RUST_BUNDLE_CONFIG="tauri.rust.conf.json"
    if [ "$PLATFORM" = "x86_64-pc-windows-msvc" ]; then
        RUST_BUNDLE_CONFIG="tauri.rust.windows.conf.json"
    fi
    TRENINO_RUST_BUNDLE=1 cargo tauri build --features "rust-ui desktop-updater" --config "$RUST_BUNDLE_CONFIG"
else
    cargo tauri build
fi

echo "==> Build complete!"
echo "Output: $TAURI_DIR/target/release/bundle/"
