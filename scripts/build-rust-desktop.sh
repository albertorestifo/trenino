#!/bin/bash
# Prepare a Rust-only distribution using the existing verified native inputs.
# The legacy release path remains the default until native acceptance passes.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRENINO_BUILD_RUST=1 exec "$SCRIPT_DIR/build-desktop.sh" "$@"
