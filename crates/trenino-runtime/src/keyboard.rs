use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KeystrokeAction {
    Down,
    Up,
    Tap,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Key {
    Control,
    Shift,
    Alt,
    Meta,
    Function(u8),
    Space,
    Return,
    Tab,
    Escape,
    Backspace,
    Delete,
    Insert,
    Home,
    End,
    PageUp,
    PageDown,
    UpArrow,
    DownArrow,
    LeftArrow,
    RightArrow,
    Numpad(u8),
    Unicode(char),
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "action", content = "key", rename_all = "snake_case")]
pub enum KeyAction {
    Press(Key),
    Release(Key),
    Click(Key),
}

pub fn parse_keystroke(raw: &str) -> (Vec<Key>, Option<Key>) {
    let mut modifiers = Vec::new();
    let mut main = None;
    for part in raw.split('+') {
        let upper = part.to_uppercase();
        match upper.as_str() {
            "CTRL" | "CONTROL" => modifiers.push(Key::Control),
            "SHIFT" => modifiers.push(Key::Shift),
            "ALT" => modifiers.push(Key::Alt),
            "META" | "WIN" | "SUPER" => modifiers.push(Key::Meta),
            _ => {
                if let Some(key) = named_key(&upper) {
                    main = Some(key)
                } else if upper.len() == 1 {
                    main = upper
                        .chars()
                        .next()
                        .map(|c| Key::Unicode(c.to_ascii_lowercase()))
                } else if let Some(c) = upper.chars().next() {
                    main = Some(Key::Unicode(c.to_ascii_lowercase()))
                }
            }
        }
    }
    (modifiers, main)
}
pub fn key_actions(action: KeystrokeAction, raw: &str) -> Vec<KeyAction> {
    let (modifiers, key) = parse_keystroke(raw);
    let mut actions = Vec::new();
    match action {
        KeystrokeAction::Down => {
            actions.extend(modifiers.iter().copied().map(KeyAction::Press));
            if let Some(key) = key {
                actions.push(KeyAction::Press(key))
            }
        }
        KeystrokeAction::Up => {
            if let Some(key) = key {
                actions.push(KeyAction::Release(key))
            }
            actions.extend(modifiers.iter().rev().copied().map(KeyAction::Release))
        }
        KeystrokeAction::Tap => {
            actions.extend(modifiers.iter().copied().map(KeyAction::Press));
            if let Some(key) = key {
                actions.push(KeyAction::Click(key))
            }
            actions.extend(modifiers.iter().rev().copied().map(KeyAction::Release))
        }
    }
    actions
}
fn named_key(name: &str) -> Option<Key> {
    Some(match name {
        "F1" => Key::Function(1),
        "F2" => Key::Function(2),
        "F3" => Key::Function(3),
        "F4" => Key::Function(4),
        "F5" => Key::Function(5),
        "F6" => Key::Function(6),
        "F7" => Key::Function(7),
        "F8" => Key::Function(8),
        "F9" => Key::Function(9),
        "F10" => Key::Function(10),
        "F11" => Key::Function(11),
        "F12" => Key::Function(12),
        "SPACE" => Key::Space,
        "ENTER" | "RETURN" => Key::Return,
        "TAB" => Key::Tab,
        "ESCAPE" | "ESC" => Key::Escape,
        "BACKSPACE" => Key::Backspace,
        "DELETE" | "DEL" => Key::Delete,
        "INSERT" | "INS" => Key::Insert,
        "HOME" => Key::Home,
        "END" => Key::End,
        "PAGEUP" | "PGUP" => Key::PageUp,
        "PAGEDOWN" | "PGDN" => Key::PageDown,
        "UP" | "ARROWUP" => Key::UpArrow,
        "DOWN" | "ARROWDOWN" => Key::DownArrow,
        "LEFT" | "ARROWLEFT" => Key::LeftArrow,
        "RIGHT" | "ARROWRIGHT" => Key::RightArrow,
        "NUMPAD0" => Key::Numpad(0),
        "NUMPAD1" => Key::Numpad(1),
        "NUMPAD2" => Key::Numpad(2),
        "NUMPAD3" => Key::Numpad(3),
        "NUMPAD4" => Key::Numpad(4),
        "NUMPAD5" => Key::Numpad(5),
        "NUMPAD6" => Key::Numpad(6),
        "NUMPAD7" => Key::Numpad(7),
        "NUMPAD8" => Key::Numpad(8),
        "NUMPAD9" => Key::Numpad(9),
        _ => return None,
    })
}

use std::collections::HashMap;
use std::path::PathBuf;
use std::process::Command;

use trenino_core::EntityId;

/// Failures reported by a [`KeystrokeAdapter`], mirroring
/// `Trenino.Keyboard.execute/2` (`{:command_failed, exit_code, output}`).
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum KeystrokeError {
    /// The bundled executable exited non-zero (oracle: `{:command_failed, _}`).
    CommandFailed { exit_code: Option<i32>, output: String },
    /// The executable could not be spawned (missing, not executable, ...).
    Spawn(String),
    /// The configured executable path is not a trusted absolute file path.
    UntrustedPath(PathBuf),
}

impl std::fmt::Display for KeystrokeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            KeystrokeError::CommandFailed { exit_code, output } => write!(
                f,
                "keystroke command failed (exit_code={exit_code:?}, output={output})"
            ),
            KeystrokeError::Spawn(msg) => write!(f, "keystroke spawn failed: {msg}"),
            KeystrokeError::UntrustedPath(path) => {
                write!(f, "keystroke executable path is not trusted: {}", path.display())
            }
        }
    }
}

impl std::error::Error for KeystrokeError {}

/// Low-level keystroke backend. Methods take a combo string (e.g. `"W"`,
/// `"CTRL+S"`) exactly as the bundled `tauri/keystroke` executable does
/// (`keystroke <down|up|tap> <combo>`); modifier press order and reversed
/// release order live inside the adapter, not the caller.
pub trait KeystrokeAdapter {
    fn key_down(&self, combo: &str) -> Result<(), KeystrokeError>;
    fn key_up(&self, combo: &str) -> Result<(), KeystrokeError>;
    fn key_tap(&self, combo: &str) -> Result<(), KeystrokeError>;
}

/// Deterministic in-memory adapter: records every invocation and can be
/// scripted to fail specific calls. Tests only; never touches the OS.
#[derive(Debug, Default)]
pub struct FakeAdapter {
    calls: std::sync::Mutex<Vec<(&'static str, String)>>,
    failures: std::sync::Mutex<Vec<(&'static str, String, KeystrokeError)>>,
}

impl FakeAdapter {
    pub fn new() -> Self {
        Self::default()
    }

    /// Fail the next matching invocation with `error` (consumed on first hit).
    pub fn fail_once(&self, action: &'static str, combo: &str, error: KeystrokeError) {
        self.failures
            .lock()
            .unwrap()
            .push((action, combo.to_string(), error));
    }

    /// Drop recorded calls (test window reset); scripted failures remain.
    pub fn clear(&self) {
        self.calls.lock().unwrap().clear();
    }

    pub fn calls(&self) -> Vec<(String, String)> {
        self.calls
            .lock()
            .unwrap()
            .iter()
            .map(|(a, c)| ((*a).to_string(), c.clone()))
            .collect()
    }

    fn dispatch(&self, action: &'static str, combo: &str) -> Result<(), KeystrokeError> {
        let mut failures = self.failures.lock().unwrap();
        if let Some(pos) = failures
            .iter()
            .position(|(a, c, _)| *a == action && c == combo)
        {
            let (_, _, error) = failures.remove(pos);
            return Err(error);
        }
        self.calls.lock().unwrap().push((action, combo.to_string()));
        Ok(())
    }
}

impl KeystrokeAdapter for FakeAdapter {
    fn key_down(&self, combo: &str) -> Result<(), KeystrokeError> {
        self.dispatch("down", combo)
    }

    fn key_up(&self, combo: &str) -> Result<(), KeystrokeError> {
        self.dispatch("up", combo)
    }

    fn key_tap(&self, combo: &str) -> Result<(), KeystrokeError> {
        self.dispatch("tap", combo)
    }
}

/// Spawns the bundled keystroke executable (`tauri/keystroke`) with the exact
/// CLI protocol `<exe> <down|up|tap> <combo>`; stdout+stderr are captured
/// (`stderr_to_stdout: true` in the oracle) and a non-zero exit maps to
/// [`KeystrokeError::CommandFailed`].
///
/// Fail-closed: the executable must be a configured **absolute** path to an
/// existing file — no PATH search and no fallback probing, matching the
/// avrdude tooling rule from the packaging constraints. The oracle's
/// APP_PATH/priv/bin/target probing belongs to configuration discovery, not
/// to execution, so it is intentionally not reproduced here.
///
/// Construction is opt-in: nothing in the runtime wires this adapter
/// automatically; owners decide when a real OS adapter may be used.
#[derive(Clone, Debug)]
pub struct ProcessKeystrokeAdapter {
    executable: PathBuf,
}

impl ProcessKeystrokeAdapter {
    /// Build the adapter from a trusted absolute path to an existing file.
    pub fn new(executable: PathBuf) -> Result<Self, KeystrokeError> {
        if !executable.is_absolute() || !executable.is_file() {
            return Err(KeystrokeError::UntrustedPath(executable));
        }
        Ok(Self { executable })
    }

    fn execute(&self, action: &str, combo: &str) -> Result<(), KeystrokeError> {
        let output = Command::new(&self.executable)
            .arg(action)
            .arg(combo)
            .output()
            .map_err(|e| KeystrokeError::Spawn(e.to_string()))?;
        if output.status.success() {
            return Ok(());
        }
        let mut text = String::from_utf8_lossy(&output.stdout).into_owned();
        if !output.stderr.is_empty() {
            if !text.is_empty() {
                text.push('\n');
            }
            text.push_str(&String::from_utf8_lossy(&output.stderr));
        }
        Err(KeystrokeError::CommandFailed {
            exit_code: output.status.code(),
            output: text,
        })
    }
}

impl KeystrokeAdapter for ProcessKeystrokeAdapter {
    fn key_down(&self, combo: &str) -> Result<(), KeystrokeError> {
        self.execute("down", combo)
    }

    fn key_up(&self, combo: &str) -> Result<(), KeystrokeError> {
        self.execute("up", combo)
    }

    fn key_tap(&self, combo: &str) -> Result<(), KeystrokeError> {
        self.execute("tap", combo)
    }
}

/// Identity of the party holding a key: the runtime entity plus an activation
/// generation, so a stale generation's late events never own live keys.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct HoldOwner {
    pub owner: EntityId,
    pub generation: u64,
}

/// One held binding registration: which owner holds which binding.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
struct HoldId {
    owner: HoldOwner,
    binding: EntityId,
}

/// Held-key ownership over a [`KeystrokeAdapter`].
///
/// Keys are refcounted per physical [`Key`] across every active holder:
/// * a modifier shared by two simultaneous bindings is pressed once and
///   released only when the last holder releases (press order modifiers →
///   main key, release order main key → modifiers reversed, as the sidecar);
/// * the same holder pressing the same binding again is a no-op (no duplicate
///   down, so a repeat can never double-press);
/// * release always wins over repeats: bookkeeping is dropped even when the
///   adapter reports failure (one retry, then reported), so a later press by
///   the same holder starts from a clean slate instead of leaking;
/// * when an owner (id + generation) disappears mid-hold, every key it held
///   is released (stuck-key cleanup);
/// * [`KeyboardOwnership::shutdown`] force-releases all held keys.
///
/// Failures are reported (never swallowed) but never block cleanup.
pub struct KeyboardOwnership<A: KeystrokeAdapter> {
    adapter: A,
    /// Physically held key → every holder currently counted on that key.
    held: HashMap<Key, Vec<HoldId>>,
    /// Active registrations: holder → (binding, pressed keys in press order).
    holds: HashMap<HoldId, (EntityId, Vec<Key>)>,
}

impl<A: KeystrokeAdapter> KeyboardOwnership<A> {
    pub fn new(adapter: A) -> Self {
        Self {
            adapter,
            held: HashMap::new(),
            holds: HashMap::new(),
        }
    }

    pub fn adapter(&self) -> &A {
        &self.adapter
    }

    /// Press `combo` on behalf of `owner` for `binding`. Duplicate presses by
    /// the same holder are ignored; only keys not already physically down are
    /// sent to the adapter, in press order (modifiers first).
    pub fn press(
        &mut self,
        owner: HoldOwner,
        binding: EntityId,
        combo: &str,
    ) -> Vec<KeystrokeError> {
        let hold = HoldId { owner, binding };
        if self.holds.contains_key(&hold) {
            return Vec::new();
        }
        let (modifiers, main) = parse_keystroke(combo);
        let mut keys = Vec::with_capacity(modifiers.len() + 1);
        let mut errors = Vec::new();
        for key in modifiers.iter().copied().chain(main.into_iter()) {
            let fresh = self
                .held
                .get(&key)
                .is_none_or(|holders| holders.is_empty());
            if fresh {
                if let Err(error) = self.adapter.key_down(&combo_of(key)) {
                    errors.push(error);
                }
            }
            self.held.entry(key).or_default().push(hold);
            keys.push(key);
        }
        self.holds.insert(hold, (binding, keys));
        errors
    }

    /// Release the binding held by `owner`. The main key is released first,
    /// then modifiers in reverse press order; a key reaches the adapter only
    /// when its last holder releases. A failed release is retried once and
    /// reported; the bookkeeping is removed regardless so the key can be
    /// re-pressed cleanly later.
    pub fn release(&mut self, owner: HoldOwner, binding: EntityId) -> Vec<KeystrokeError> {
        let hold = HoldId { owner, binding };
        let Some((_, keys)) = self.holds.remove(&hold) else {
            return Vec::new();
        };
        self.drop_keys(keys, hold)
    }

    /// Release everything a (possibly stale) owner generation still holds.
    /// Stuck-key cleanup when an owner disappears mid-hold.
    pub fn owner_gone(&mut self, owner: HoldOwner) -> Vec<KeystrokeError> {
        let stale: Vec<HoldId> = self
            .holds
            .keys()
            .copied()
            .filter(|hold| hold.owner == owner)
            .collect();
        let mut errors = Vec::new();
        for hold in stale {
            if let Some((_, keys)) = self.holds.remove(&hold) {
                errors.extend(self.drop_keys(keys, hold));
            }
        }
        errors
    }

    /// Force-release every held key (shutdown path). Every key is attempted
    /// even if earlier ones fail; afterwards no holds remain.
    pub fn shutdown(&mut self) -> Vec<KeystrokeError> {
        let keys: Vec<Key> = self
            .held
            .iter()
            .filter(|(_, holders)| !holders.is_empty())
            .map(|(key, _)| *key)
            .collect();
        let mut errors = Vec::new();
        for key in keys {
            if let Err(error) = self.release_with_retry(key) {
                errors.push(error);
            }
        }
        self.held.clear();
        self.holds.clear();
        errors
    }

    /// Number of holders currently counted on `key` (diagnostics/tests).
    pub fn holders_of(&self, key: Key) -> usize {
        self.held.get(&key).map_or(0, Vec::len)
    }

    /// Whether `owner` currently holds `binding`.
    pub fn is_held(&self, owner: HoldOwner, binding: EntityId) -> bool {
        self.holds.contains_key(&HoldId { owner, binding })
    }

    /// Release `keys` for `hold`: reverse press order (main first), adapter
    /// call only when the last holder of a key goes away.
    fn drop_keys(&mut self, keys: Vec<Key>, hold: HoldId) -> Vec<KeystrokeError> {
        let mut errors = Vec::new();
        for key in keys.iter().rev() {
            let last = {
                let holders = self
                    .held
                    .get_mut(key)
                    .expect("held key missing from refcounts");
                holders.retain(|h| *h != hold);
                holders.is_empty()
            };
            if last {
                if let Err(error) = self.release_with_retry(*key) {
                    errors.push(error);
                }
                self.held.remove(key);
            }
        }
        errors
    }

    fn release_with_retry(&self, key: Key) -> Result<(), KeystrokeError> {
        let combo = combo_of(key);
        // One retry: a transient failure is healed, a persistent one reported.
        if self.adapter.key_up(&combo).is_ok() {
            Ok(())
        } else {
            self.adapter.key_up(&combo)
        }
    }
}

/// Canonical single-key combo string used for adapter down/up calls. These
/// strings parse back to the same [`Key`] through `parse_keystroke`
/// (`"CTRL"`, `"SHIFT"`, `"F5"`, `"W"`, ...), matching the sidecar aliases.
pub fn combo_of(key: Key) -> String {
    match key {
        Key::Control => "CTRL".into(),
        Key::Shift => "SHIFT".into(),
        Key::Alt => "ALT".into(),
        Key::Meta => "META".into(),
        Key::Function(n) => format!("F{n}"),
        Key::Space => "SPACE".into(),
        Key::Return => "RETURN".into(),
        Key::Tab => "TAB".into(),
        Key::Escape => "ESCAPE".into(),
        Key::Backspace => "BACKSPACE".into(),
        Key::Delete => "DELETE".into(),
        Key::Insert => "INSERT".into(),
        Key::Home => "HOME".into(),
        Key::End => "END".into(),
        Key::PageUp => "PAGEUP".into(),
        Key::PageDown => "PAGEDOWN".into(),
        Key::UpArrow => "UP".into(),
        Key::DownArrow => "DOWN".into(),
        Key::LeftArrow => "LEFT".into(),
        Key::RightArrow => "RIGHT".into(),
        Key::Numpad(n) => format!("NUMPAD{n}"),
        Key::Unicode(c) => c.to_ascii_uppercase().to_string(),
    }
}

impl<A: KeystrokeAdapter> KeystrokeAdapter for &A {
    fn key_down(&self, combo: &str) -> Result<(), KeystrokeError> {
        (**self).key_down(combo)
    }

    fn key_up(&self, combo: &str) -> Result<(), KeystrokeError> {
        (**self).key_up(combo)
    }

    fn key_tap(&self, combo: &str) -> Result<(), KeystrokeError> {
        (**self).key_tap(combo)
    }
}
