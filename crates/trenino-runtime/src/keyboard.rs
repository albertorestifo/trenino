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
