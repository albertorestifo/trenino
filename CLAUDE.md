# Claude Code Instructions

## Project Overview

Trenino is a Rust desktop application that bridges custom hardware controllers to
Train Sim World via a local MCP server. A Tokio-based runtime provides the backend;
a Tauri/Svelte shell provides the desktop UI. Key subsystems:

- `crates/trenino-core/` — shared domain types and wire contracts: serial protocol
  codec, calibration math, train/lever/notch model, HT16K33 display driver,
  simulator types, decimal rounding helpers
- `crates/trenino-runtime/` — services: hardware sessions and serial transport,
  firmware catalog/download/upload, train controllers (lever/button/output/display),
  simulator connection and detection, Lua script runner, Windows vJoy, SQLite
  storage, MCP server, legacy JSON HTTP API, production composition
- `tauri/src-tauri/` — Tauri shell: `rust-ui` IPC commands, updater, sidecar wiring
- `tauri/ui/` — Svelte/TypeScript desktop frontend (typed bridge in `src/bridge/`)
- `tauri/keystroke/`, `tauri/virtual_joystick/` — native sidecars (keyboard input,
  Windows vJoy feeder)

## Commands

```bash
# Rust gates (same as .github/workflows/rust-parity.yml)
cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace -- --test-threads=1

# Desktop UI gates
npm --prefix tauri/ui ci
npm --prefix tauri/ui run check && npm --prefix tauri/ui test
npm --prefix tauri/ui run build

# Run the desktop app locally (build UI assets first)
npm --prefix tauri/ui run build
cargo run --manifest-path tauri/src-tauri/Cargo.toml --features rust-ui

# Package an installer
./scripts/build-rust-desktop.sh
```

## Skills

Project skills live in `.claude/skills/`. Invoke them by name when relevant:

- `/trenino-mcp` — MCP server interaction and tool usage
- `/train-setup` — Train configuration workflow
- `/lua-scripting` — Lua scripting API for train automation

## MCP Tools

MCP tool handlers live in `crates/trenino-runtime/src/mcp/tools.rs`, grouped into
category modules (`simulator`, `train`, `element`, `device`, `output_binding`,
`button_binding`, `sequence`, `script`, `detection`, `display_binding`, `vjoy`).
Each module exposes a `TOOL_NAMES` constant and a `tools()` constructor; the
registry currently serves 47 tools over the SSE/POST HTTP transport
(`GET /mcp/sse`, `POST /mcp/messages?session_id=...`, bound to `127.0.0.1:4000`
by default). When adding or removing a tool:

1. Update the category module's `TOOL_NAMES` and `tools()` in
   `crates/trenino-runtime/src/mcp/tools.rs`
2. Update any tool-count assertions in the runtime MCP tests
   (`crates/trenino-runtime/tests/mcp_server.rs` and related suites)

Use the `sequence` module as the canonical CRUD pattern. Tool logic does not touch
the database directly: it goes through the ports in
`crates/trenino-runtime/src/mcp/ports.rs` (storage-backed by
`storage_ports.rs`) — check there before writing new tool logic.

## Rust Coding Guidelines

### Type Safety

Model domain data as strongly-typed structs and enums (see `crates/trenino-core`),
not untyped maps. When JSON is unavoidable (MCP, HTTP API, IPC), derive `Serialize`
/ `Deserialize` on dedicated wire types.

### Float Value Precision

Round float values to 2 decimal places for simulator inputs/outputs, calibration
values, notch values, and any user-facing float data. Use the shared helper, which
rounds the exact binary value with ties away from zero:

```rust
use trenino_core::rounding::round_elixir;

let value = round_elixir(raw_value, 2).ok_or(MyError::NonFinite)?;
```

Do not use the `(x * 100.0).round() / 100.0` idiom: it rounds the intermediate
product to another binary float and moves values such as `2.675` across the
decimal midpoint. For fixed-width display strings use
`trenino_core::rounding::format_elixir_decimal`.

Apply in: simulator client reads, calibration recording, notch value storage,
UI display.

### Protocol Messages

Keep the Rust API using enum variants and the wire format using integers.
Convert in encode/decode with byte-pattern matching
(`crates/trenino-core/src/hardware/protocol/codec.rs`):

```rust
pub fn encode_message(m: &Message) -> Result<Vec<u8>, ProtocolError> {
    let mut out = Vec::new();
    match m {
        Message::SetOutput { pin, high } => {
            out.extend([0x07, *pin, u8::from(*high)]);
        }
        // ...
    }
    Ok(out)
}

pub fn decode_message(bytes: &[u8]) -> Result<Message, ProtocolError> {
    match bytes.first() {
        Some(0x00) => /* IdentityRequest */,
        Some(0x01) => /* IdentityResponse */,
        // ...
        _ => Err(ProtocolError::UnknownMessageType(type_byte)),
    }
}
```
