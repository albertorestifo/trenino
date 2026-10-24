# Hardware coding slice report

Worktree: `C:/Users/Alberto/.codex/worktrees/rust-rewrite/tsw_io`, branch `codex/rust-rewrite`.

## Implemented

- `crates/trenino-core/src/hardware/protocol/`: exact encoders/decoders for host message IDs 0x00–0x08 and 0x0D–0x0F, including host-only HT16K33 Configure encoding. Reserved IDs and HT16K33 Configure decode remain rejected as in the legacy source. Streaming COBS preserves its appended-zero convention, fragment/coalescing behavior, empty delimiters, 254-byte boundary, and malformed-frame recovery.
- `crates/trenino-core/src/hardware/mod.rs`: uses foundation's checked shared `ConfigId`; validates inputs, matrix axes and module parameters; rejects duplicate physical input pins, duplicate I2C addresses, and overlapping generated virtual pins; builds ordered configure messages; and provides pure detection baseline logic.
- `crates/trenino-core/src/hardware/ht16k33.rs`: all legacy 14/7-segment mappings and encoding behavior, with legacy grapheme-based alignment and dot width accounting. Added `unicode-segmentation` to `trenino-core` for exact grapheme counting.
- `crates/trenino-core/src/hardware/calibration/mod.rs`: sweep inversion/rollover analysis, endpoint selection, total travel and normalization, including widened arithmetic for malformed extremes.
- Tests: `crates/trenino-core/tests/hardware_protocol.rs`, `hardware_models.rs`, `hardware_calibration.rs`.

## Review round 1 fixes

- Rejected repeated physical input pin assignments, repeated module addresses, and matrix virtual pin overlaps while preserving `128 + row * num_cols + col`.
- Rejected either empty matrix axis.
- Matched legacy alignment for 14-segment dots and combining Unicode graphemes.
- Added exact configure packet golden bytes, all two-chunk split points over coalesced frames, malformed-frame recovery with empty delimiters, button press/release and type-filter detection, short sweeps, negative even-median rounding, strict rollover thresholds, and dead-zone midpoint boundaries.

## Validation

- `cargo test -p trenino-core --test hardware_protocol --test hardware_models --test hardware_calibration` — passed (20 tests: 7 protocol, 8 models, 5 calibration).
- `cargo clippy -p trenino-core --tests -- -D warnings` — passed.
- `rustfmt --edition 2021` applied to all `.rs` files under the owned hardware subtree and test files.

## Remaining scope

No serial port discovery/connection runtime, configuration persistence/acknowledgment workflow, matrix virtual-button persistence, hardware I/O, timeout/cancellation behavior, calibration collection sessions, or firmware flashing was implemented. `DeviceConfiguration` expects matrices in legacy name order from its caller because the pure DTO has no matrix name/order field; row and column order is preserved as supplied. No physical hardware was accessed. The decoder buffer remains unbounded until a delimiter; choosing a compatibility-safe maximum remains deferred as required by the migration plan.
