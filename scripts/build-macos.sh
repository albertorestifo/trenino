#!/usr/bin/env bash
#
# Build tsw_io desktop application for macOS (Apple Silicon)
#
# Usage: ./scripts/build-macos.sh
#

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly TAURI_TARGET="aarch64-apple-darwin"

# Export for Burrito
export BURRITO_TARGET="macos_arm64"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_command() {
    local cmd="$1"
    local name="${2:-$cmd}"
    if ! command -v "$cmd" &> /dev/null; then
        log_error "$name is not installed"
        return 1
    fi
    return 0
}

check_dependencies() {
    log_info "Checking dependencies..."

    local missing=0

    if ! check_command "mise" "mise"; then
        log_error "mise is required. Install from https://mise.jdx.dev/"
        missing=1
    fi

    if ! check_command "xz" "xz"; then
        log_error "xz is required. Install with: brew install xz"
        missing=1
    fi

    if [[ $missing -eq 1 ]]; then
        exit 1
    fi

    # Ensure mise tools are installed
    log_info "Ensuring mise tools are installed..."
    mise install

    # Verify tools are available via mise
    local tools=("elixir" "node" "zig" "cargo")
    for tool in "${tools[@]}"; do
        if ! mise which "$tool" &> /dev/null; then
            log_error "$tool not available via mise. Run 'mise install' first."
            missing=1
        fi
    done

    if [[ $missing -eq 1 ]]; then
        exit 1
    fi

    log_info "All dependencies satisfied"
}

build_elixir_backend() {
    log_info "Building Elixir backend..."

    cd "$PROJECT_ROOT"

    export MIX_ENV=prod

    log_info "Installing dependencies..."
    mise exec -- mix deps.get --only prod

    log_info "Building assets..."
    mise exec -- mix assets.deploy

    log_info "Building release with Burrito..."
    mise exec -- mix release tsw_io_desktop --overwrite

    local binary_path="$PROJECT_ROOT/burrito_out/tsw_io_desktop_${BURRITO_TARGET}"
    if [[ ! -f "$binary_path" ]]; then
        log_error "Expected binary not found at: $binary_path"
        exit 1
    fi

    log_info "Elixir backend built successfully"
}

prepare_tauri_binary() {
    log_info "Preparing binary for Tauri..."

    local src="$PROJECT_ROOT/burrito_out/tsw_io_desktop_${BURRITO_TARGET}"
    local dest_dir="$PROJECT_ROOT/tauri/src-tauri/binaries"
    local dest="$dest_dir/tsw_io_backend-${TAURI_TARGET}"

    mkdir -p "$dest_dir"
    cp "$src" "$dest"
    chmod +x "$dest"

    log_info "Binary prepared at: $dest"
}

build_tauri_app() {
    log_info "Building Tauri application..."

    cd "$PROJECT_ROOT/tauri"

    log_info "Installing Node dependencies..."
    mise exec -- npm install

    log_info "Building Tauri app..."
    mise exec -- npx tauri build --target "$TAURI_TARGET"

    log_info "Tauri build complete"
}

main() {
    log_info "Starting macOS build for tsw_io..."

    check_dependencies
    build_elixir_backend
    prepare_tauri_binary
    build_tauri_app

    local bundle_dir="$PROJECT_ROOT/tauri/src-tauri/target/${TAURI_TARGET}/release/bundle"

    log_info "Build complete!"
    echo ""
    echo "Output files:"
    echo "  DMG: ${bundle_dir}/dmg/"
    echo "  App: ${bundle_dir}/macos/"
}

main "$@"
