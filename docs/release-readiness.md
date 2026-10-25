# 0.8.0 release readiness

This release adds display modules, virtual joystick support, multiple train
identifiers and Train Sim World 7 support. It changes HTTP/MCP train payloads from
`identifier` to `identifiers`; clients must update before upgrading.

## Verification before publishing

Run the Rust and UI gates and the native sidecar tests:

```bash
cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace -- --test-threads=1
npm --prefix tauri/ui run check && npm --prefix tauri/ui test && npm --prefix tauri/ui run build
cargo test --manifest-path tauri/virtual_joystick/Cargo.toml
```

Check that the Tauri configuration, Cargo package/lockfile, npm package/lockfile
and splash screen all identify the application as 0.8.0. Keep the changelog
unreleased until a release is actually published.

## Validation completed on October 23, 2026

- `mix precommit`: compilation and strict Credo passed; 1,549 tests passed,
  3 excluded (`skip_without_avrdude`).
- Native virtual joystick tests: 16 passed on macOS. This exercises the portable
  protocol/adapter code, not the Windows driver.
- `mix hex.audit`: no retired packages or security advisory packages found.
- Desktop Cargo metadata resolves with `--locked`; eight application-version
  locations agree at 0.8.0.
- Chromium checks passed for display settings surviving validation, blank minimum
  retention, entering a train name before its identifier, required identifier
  protection, modal Escape/focus return, and navigation at 390px width.
- Independent code re-review confirmed all final findings addressed.
- Desktop light/dark and narrow-window screenshots were reviewed independently.
  No important introduced visual issues remained.

## Platform and hardware checks

These require the actual Windows package and connected equipment; passing unit
tests on macOS does not perform them.

- Upgrade a copied v0.7.4 configuration database. Confirm train identifiers and
  existing control/calibration data remain available.
- Install the signed Windows NSIS package on a disposable Windows 10/11 machine.
  Check vJoy installation, activation, UAC cancellation, recovery and shared-driver
  uninstall behavior. MSI does not manage the driver lifecycle.
- Verify Train Sim World 7 key detection and Train Sim World 6 fallback. Connect,
  drive, disconnect and reconnect while moving a lever; check for lag or freezes.
- Deploy a display-only configuration, test its segments, bind a stable simulator
  value, disconnect/reconnect the Arduino, and verify the unchanged value returns.
- Check a physical 7-segment and 14-segment display, brightness, decimal points,
  alignment and eight-digit configurations.
- Test joystick axes/buttons with calibrated hardware; disconnect a source device
  and verify its axes center and buttons release. Confirm destination conflicts
  require explicit replacement rather than silently changing a train binding.
- Exercise setup by keyboard, both themes, long train identifiers and a narrow
  window. The navigation and edit/delete actions must remain reachable.

Publishing, tagging and driver installation are separate release operations.
