//! Keystroke adapter and held-key ownership tests.
//!
//! Mirrors the Elixir oracles:
//! * `lib/trenino/keyboard.ex` — `key_down/key_up/tap` over the bundled
//!   executable with the `<action> <combo>` CLI, failures reported as
//!   command errors, executable only from a trusted absolute path.
//! * `tauri/keystroke/src/main.rs` — modifier press order (modifiers → main
//!   key) and release order (main key → modifiers reversed), combo aliases.
//! * `docs/superpowers/plans/2026-10-24-rust-controls.md` task 5: shared
//!   modifiers, simultaneous bindings, release failures, owner drop, and
//!   shutdown force-release.
//!
//! The process adapter is exercised against deterministic `/bin/sh` arg-capture
//! scripts from a temp directory; the ownership layer runs on the in-memory
//! fake adapter. No real keyboard input is generated.

#![cfg(unix)]

use std::fs;
use std::path::PathBuf;

use tempfile::TempDir;
use trenino_core::EntityId;
use trenino_runtime::keyboard::{
    combo_of, key_actions, parse_keystroke, FakeAdapter, HoldOwner, KeystrokeAction,
    KeystrokeAdapter, KeystrokeError, KeyboardOwnership, Key, ProcessKeystrokeAdapter,
};

fn owner(id: i64, generation: u64) -> HoldOwner {
    HoldOwner {
        owner: EntityId(id),
        generation,
    }
}

fn binding(id: i64) -> EntityId {
    EntityId(id)
}

fn calls(fake: &FakeAdapter) -> Vec<(String, String)> {
    fake.calls()
}

// ---------------------------------------------------------------------------
// Parser parity (aliases and ordering kept from the sidecar)
// ---------------------------------------------------------------------------

#[test]
fn parser_keeps_sidecar_aliases() {
    let (mods, main) = parse_keystroke("ctrl+shift+s");
    assert_eq!(mods, vec![Key::Control, Key::Shift]);
    assert_eq!(main, Some(Key::Unicode('s')));

    let (mods, main) = parse_keystroke("WIN+F1");
    assert_eq!(mods, vec![Key::Meta]);
    assert_eq!(main, Some(Key::Function(1)));

    let (mods, main) = parse_keystroke("ARROWUP");
    assert!(mods.is_empty());
    assert_eq!(main, Some(Key::UpArrow));
}

#[test]
fn action_order_matches_sidecar() {
    // Down: modifiers then main. Up: main then modifiers reversed.
    // Tap: modifiers, click, modifiers reversed.
    let down = key_actions(KeystrokeAction::Down, "CTRL+SHIFT+S");
    assert_eq!(
        down,
        vec![
            trenino_runtime::keyboard::KeyAction::Press(Key::Control),
            trenino_runtime::keyboard::KeyAction::Press(Key::Shift),
            trenino_runtime::keyboard::KeyAction::Press(Key::Unicode('s')),
        ]
    );
    let up = key_actions(KeystrokeAction::Up, "CTRL+SHIFT+S");
    let tap = key_actions(KeystrokeAction::Tap, "CTRL+SHIFT+S");
    assert_eq!(up.len(), 3);
    assert_eq!(tap.len(), 5);
}

#[test]
fn combo_of_round_trips_through_parser() {
    let plain = [
        Key::Function(12),
        Key::Space,
        Key::Return,
        Key::Escape,
        Key::UpArrow,
        Key::Numpad(3),
        Key::Unicode('w'),
    ];
    for key in plain {
        let combo = combo_of(key);
        let (mods, main) = parse_keystroke(&combo);
        assert!(mods.is_empty(), "{combo} parsed as modifier");
        assert_eq!(main, Some(key), "{combo} did not round-trip");
    }
    for key in [Key::Control, Key::Shift, Key::Alt, Key::Meta] {
        let (mods, main) = parse_keystroke(&combo_of(key));
        assert_eq!(mods, vec![key]);
        assert_eq!(main, None);
    }
}

// ---------------------------------------------------------------------------
// Ownership layer (fake adapter)
// ---------------------------------------------------------------------------

#[test]
fn press_sends_keys_in_sidecar_order() {
    let fake = FakeAdapter::new();
    let mut kb = KeyboardOwnership::new(&fake);
    assert!(kb
        .press(owner(1, 0), binding(10), "CTRL+SHIFT+S")
        .is_empty());
    assert_eq!(
        calls(&fake),
        vec![
            ("down".into(), "CTRL".into()),
            ("down".into(), "SHIFT".into()),
            ("down".into(), "S".into()),
        ]
    );
}

#[test]
fn release_reverses_order_main_key_first() {
    let fake = FakeAdapter::new();
    let mut kb = KeyboardOwnership::new(&fake);
    kb.press(owner(1, 0), binding(10), "CTRL+SHIFT+S");
    fake.clear();
    assert!(kb.release(owner(1, 0), binding(10)).is_empty());
    assert_eq!(
        calls(&fake),
        vec![
            ("up".into(), "S".into()),
            ("up".into(), "SHIFT".into()),
            ("up".into(), "CTRL".into()),
        ]
    );
}

#[test]
fn shared_modifier_pressed_once_released_by_last_holder() {
    let fake = FakeAdapter::new();
    let mut kb = KeyboardOwnership::new(&fake);

    // Two simultaneous bindings sharing CTRL.
    kb.press(owner(1, 0), binding(10), "CTRL+S");
    kb.press(owner(1, 0), binding(11), "CTRL+D");
    assert_eq!(
        calls(&fake),
        vec![
            ("down".into(), "CTRL".into()),
            ("down".into(), "S".into()),
            // CTRL already physically down; only D is pressed.
            ("down".into(), "D".into()),
        ]
    );

    // First release must NOT release the shared CTRL.
    kb.release(owner(1, 0), binding(10));
    assert_eq!(
        calls(&fake),
        vec![
            ("down".into(), "CTRL".into()),
            ("down".into(), "S".into()),
            ("down".into(), "D".into()),
            ("up".into(), "S".into()),
        ]
    );
    assert_eq!(kb.holders_of(Key::Control), 1);

    // Last holder releases: S already gone, D then CTRL.
    kb.release(owner(1, 0), binding(11));
    assert_eq!(
        calls(&fake),
        vec![
            ("down".into(), "CTRL".into()),
            ("down".into(), "S".into()),
            ("down".into(), "D".into()),
            ("up".into(), "S".into()),
            ("up".into(), "D".into()),
            ("up".into(), "CTRL".into()),
        ]
    );
    assert_eq!(kb.holders_of(Key::Control), 0);
}

#[test]
fn shared_modifier_across_different_owners() {
    let fake = FakeAdapter::new();
    let mut kb = KeyboardOwnership::new(&fake);
    kb.press(owner(1, 0), binding(10), "SHIFT+W");
    kb.press(owner(2, 0), binding(20), "SHIFT+E");
    // SHIFT pressed once even across owners.
    assert_eq!(
        calls(&fake),
        vec![
            ("down".into(), "SHIFT".into()),
            ("down".into(), "W".into()),
            ("down".into(), "E".into()),
        ]
    );
    kb.owner_gone(owner(1, 0));
    // E and SHIFT still held by owner 2... W released, SHIFT kept.
    let recorded = calls(&fake);
    assert!(recorded.contains(&("up".into(), "W".into())));
    assert!(!recorded.contains(&("up".into(), "SHIFT".into())));
    assert_eq!(kb.holders_of(Key::Shift), 1);
}

#[test]
fn no_duplicate_down_for_same_holder() {
    let fake = FakeAdapter::new();
    let mut kb = KeyboardOwnership::new(&fake);
    kb.press(owner(1, 0), binding(10), "W");
    fake.clear();
    // Repeat press by the same holder of the same binding: no-op.
    assert!(kb.press(owner(1, 0), binding(10), "W").is_empty());
    assert!(calls(&fake).is_empty());

    // A different binding by the same holder may press other keys.
    kb.press(owner(1, 0), binding(11), "W");
    assert_eq!(
        calls(&fake),
        vec![
            // W already physically held by the same owner's other binding.
        ]
    );
    assert_eq!(kb.holders_of(Key::Unicode('w')), 2);
}

#[test]
fn release_wins_over_repeats() {
    let fake = FakeAdapter::new();
    let mut kb = KeyboardOwnership::new(&fake);
    kb.press(owner(1, 0), binding(10), "W");
    kb.release(owner(1, 0), binding(10));
    fake.clear();
    assert!(!kb.is_held(owner(1, 0), binding(10)));

    // A late repeat for a released holder re-presses from a clean slate
    // (exactly one down), never a duplicate.
    kb.press(owner(1, 0), binding(10), "W");
    assert_eq!(
        calls(&fake),
        vec![("down".into(), "W".into())]
    );

    // A stale generation never owns the live generation's keys.
    kb.owner_gone(owner(1, 5)); // wrong generation: nothing held under it
    assert_eq!(calls(&fake), vec![("down".into(), "W".into())]);
    assert!(kb.is_held(owner(1, 0), binding(10)));
}

#[test]
fn release_failure_retried_once_and_reported() {
    let fake = FakeAdapter::new();
    fake.fail_once(
        "up",
        "W",
        KeystrokeError::CommandFailed {
            exit_code: Some(1),
            output: "boom".into(),
        },
    );
    let mut kb = KeyboardOwnership::new(&fake);
    kb.press(owner(1, 0), binding(10), "W");
    fake.clear();

    // First up fails, the single retry succeeds: no error reported; only
    // the successful attempt is recorded.
    assert!(kb.release(owner(1, 0), binding(10)).is_empty());
    assert_eq!(calls(&fake), vec![("up".into(), "W".into())]);
    assert_eq!(kb.holders_of(Key::Unicode('w')), 0);

    // Both attempts failing: reported once, bookkeeping still cleared.
    fake.fail_once(
        "up",
        "W",
        KeystrokeError::CommandFailed {
            exit_code: Some(1),
            output: "boom".into(),
        },
    );
    fake.fail_once(
        "up",
        "W",
        KeystrokeError::CommandFailed {
            exit_code: Some(2),
            output: "boom2".into(),
        },
    );
    kb.press(owner(1, 0), binding(10), "W");
    fake.clear();
    let errors = kb.release(owner(1, 0), binding(10));
    assert_eq!(errors.len(), 1);
    assert_eq!(
        errors[0],
        KeystrokeError::CommandFailed {
            exit_code: Some(2),
            output: "boom2".into(),
        }
    );
    assert!(!kb.is_held(owner(1, 0), binding(10)));
    // And the key can be pressed again afterwards.
    assert!(kb.press(owner(1, 0), binding(10), "W").is_empty());
}

#[test]
fn simultaneous_holds_and_owner_drop_mid_hold() {
    let fake = FakeAdapter::new();
    let mut kb = KeyboardOwnership::new(&fake);
    kb.press(owner(7, 3), binding(1), "CTRL+A");
    kb.press(owner(7, 3), binding(2), "CTRL+B");
    kb.press(owner(8, 3), binding(3), "C");
    fake.clear();

    // Owner 7 disappears mid-hold: A, B released, CTRL released (owner 8
    // holds only C), C stays.
    let errors = kb.owner_gone(owner(7, 3));
    assert!(errors.is_empty());
    let recorded = calls(&fake);
    assert!(recorded.contains(&("up".into(), "A".into())));
    assert!(recorded.contains(&("up".into(), "B".into())));
    assert!(recorded.contains(&("up".into(), "CTRL".into())));
    assert!(!recorded.contains(&("up".into(), "C".into())));
    assert!(kb.is_held(owner(8, 3), binding(3)));
    assert!(!kb.is_held(owner(7, 3), binding(1)));
}

#[test]
fn shutdown_force_releases_every_held_key() {
    let fake = FakeAdapter::new();
    let mut kb = KeyboardOwnership::new(&fake);
    kb.press(owner(1, 0), binding(10), "CTRL+SHIFT+S");
    kb.press(owner(2, 0), binding(11), "ALT+D");
    fake.clear();

    let errors = kb.shutdown();
    assert!(errors.is_empty());
    let released: Vec<String> = calls(&fake)
        .into_iter()
        .filter(|(action, _)| action == "up")
        .map(|(_, combo)| combo)
        .collect();
    for combo in ["CTRL", "SHIFT", "S", "ALT", "D"] {
        assert!(released.contains(&combo.to_string()), "missing up {combo}");
    }
    assert_eq!(kb.holders_of(Key::Control), 0);
    assert!(!kb.is_held(owner(1, 0), binding(10)));
    assert!(!kb.is_held(owner(2, 0), binding(11)));

    // Shutdown is idempotent and a failed release does not block the rest.
    fake.fail_once(
        "up",
        "W",
        KeystrokeError::CommandFailed {
            exit_code: Some(9),
            output: "no".into(),
        },
    );
    fake.fail_once(
        "up",
        "W",
        KeystrokeError::CommandFailed {
            exit_code: Some(9),
            output: "no".into(),
        },
    );
    kb.press(owner(1, 0), binding(10), "W");
    kb.press(owner(1, 0), binding(11), "X");
    let errors = kb.shutdown();
    assert_eq!(errors.len(), 1);
    assert!(!kb.is_held(owner(1, 0), binding(11)));
}

#[test]
fn tap_passthrough_uses_adapter() {
    let fake = FakeAdapter::new();
    let kb = KeyboardOwnership::new(&fake);
    // Taps are not held; the button controller calls the adapter directly.
    kb.adapter().key_tap("F5").unwrap();
    assert_eq!(calls(&fake), vec![("tap".into(), "F5".into())]);
}

// ---------------------------------------------------------------------------
// ProcessKeystrokeAdapter (arg-capture script, unix)
// ---------------------------------------------------------------------------

/// Creates an executable shell script appending `"$@"` (one per line) to
/// `log` inside `dir`, exiting with `exit_code`.
fn capture_script(dir: &TempDir, name: &str, log_name: &str, exit_code: i32) -> PathBuf {
    let path = dir.path().join(name);
    let log = dir.path().join(log_name).display().to_string();
    let body = if exit_code == 0 {
        format!("#!/bin/sh\nprintf '%s\\n' \"$@\" >> \"{log}\"\nexit 0\n")
    } else {
        format!(
            "#!/bin/sh\nprintf '%s\\n' \"$@\" >> \"{log}\"\necho \"kaput\" >&2\nexit {exit_code}\n"
        )
    };
    fs::write(&path, body).unwrap();
    let mut perms = fs::metadata(&path).unwrap().permissions();
    use std::os::unix::fs::PermissionsExt;
    perms.set_mode(0o755);
    fs::set_permissions(&path, perms).unwrap();
    path
}

fn log_lines(dir: &TempDir) -> Vec<String> {
    let log = dir.path().join("args.log");
    match fs::read_to_string(&log) {
        Ok(text) => text.lines().map(str::to_string).collect(),
        Err(_) => Vec::new(),
    }
}

#[test]
fn process_adapter_invokes_exact_sidecar_cli() {
    let dir = TempDir::new().unwrap();
    let exe = capture_script(&dir, "keystroke", "args.log", 0);
    let adapter = ProcessKeystrokeAdapter::new(exe.clone()).unwrap();

    adapter.key_down("CTRL+S").unwrap();
    adapter.key_up("CTRL+S").unwrap();
    adapter.key_tap("SHIFT+F1").unwrap();

    assert_eq!(
        log_lines(&dir),
        vec!["down", "CTRL+S", "up", "CTRL+S", "tap", "SHIFT+F1"]
    );
}

#[test]
fn process_adapter_reports_command_failure_with_output() {
    let dir = TempDir::new().unwrap();
    let exe = capture_script(&dir, "keystroke-fail", "args.log", 3);
    let adapter = ProcessKeystrokeAdapter::new(exe).unwrap();

    let err = adapter.key_down("W").unwrap_err();
    assert_eq!(
        err,
        KeystrokeError::CommandFailed {
            exit_code: Some(3),
            output: "kaput\n".into(),
        }
    );
}

#[test]
fn process_adapter_is_fail_closed_on_untrusted_paths() {
    let dir = TempDir::new().unwrap();
    // Relative path: rejected even if it exists.
    let rel = {
        let abs = capture_script(&dir, "keystroke-rel", "args.log", 0);
        let cwd = std::env::current_dir().unwrap();
        std::path::Path::new(&abs)
            .strip_prefix(&cwd)
            .map(PathBuf::from)
            .unwrap_or(abs.clone())
    };
    if rel.is_relative() {
        assert!(matches!(
            ProcessKeystrokeAdapter::new(rel),
            Err(KeystrokeError::UntrustedPath(_))
        ));
    }
    // Non-existent path: rejected.
    assert!(matches!(
        ProcessKeystrokeAdapter::new(PathBuf::from("/nonexistent/keystroke-xyz")),
        Err(KeystrokeError::UntrustedPath(_))
    ));
}

#[test]
fn process_adapter_reports_spawn_failure() {
    let dir = TempDir::new().unwrap();
    let exe = capture_script(&dir, "keystroke-noperm", "args.log", 0);
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = fs::metadata(&exe).unwrap().permissions();
        perms.set_mode(0o644);
        fs::set_permissions(&exe, perms).unwrap();
    }
    let adapter = ProcessKeystrokeAdapter::new(exe).unwrap();
    assert!(matches!(adapter.key_tap("W"), Err(KeystrokeError::Spawn(_))));
}

#[test]
fn process_adapter_works_behind_ownership_layer() {
    let dir = TempDir::new().unwrap();
    let exe = capture_script(&dir, "keystroke", "args.log", 0);
    let adapter = ProcessKeystrokeAdapter::new(exe).unwrap();
    let mut kb = KeyboardOwnership::new(adapter);
    assert!(kb.press(owner(1, 0), binding(10), "CTRL+S").is_empty());
    assert!(kb.press(owner(1, 0), binding(11), "CTRL+D").is_empty());
    assert!(kb.release(owner(1, 0), binding(10)).is_empty());
    assert!(kb.shutdown().is_empty());
    // Press/release order is deterministic until shutdown, which
    // force-releases the remaining keys (up D, up CTRL) in unspecified order.
    let lines = log_lines(&dir);
    assert_eq!(
        &lines[..7],
        &["down", "CTRL", "down", "S", "down", "D", "up"]
    );
    let mut tail: Vec<String> = lines[7..].to_vec();
    tail.sort();
    assert_eq!(
        tail,
        vec!["CTRL", "D", "S", "up", "up"]
            .into_iter()
            .map(String::from)
            .collect::<Vec<_>>()
    );
}

