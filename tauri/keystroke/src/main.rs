use clap::{Parser, ValueEnum};
use enigo::{Enigo, Key, Keyboard, Settings};

#[derive(Parser)]
#[command(name = "keystroke")]
#[command(about = "Simulate keyboard keystrokes", long_about = None)]
struct Cli {
    /// Action to perform
    #[arg(value_enum)]
    action: Action,

    /// Key combination (e.g., "W", "CTRL+S", "SHIFT+F1")
    key: String,
}

#[derive(Copy, Clone, PartialEq, Eq, ValueEnum)]
enum Action {
    /// Press key down (hold)
    Down,
    /// Release key
    Up,
    /// Press and release key
    Tap,
}

fn main() {
    let cli = Cli::parse();

    let mut enigo = Enigo::new(&Settings::default()).expect("Failed to initialize enigo");

    // Parse the key combination
    let parts: Vec<&str> = cli.key.split('+').collect();
    let (modifiers, main_key) = parse_key_parts(&parts);

    match cli.action {
        Action::Down => {
            // Press modifiers first, then the main key
            for modifier in &modifiers {
                let _ = enigo.key(*modifier, enigo::Direction::Press);
            }
            if let Some(key) = main_key {
                let _ = enigo.key(key, enigo::Direction::Press);
            }
        }
        Action::Up => {
            // Release main key first, then modifiers (reverse order)
            if let Some(key) = main_key {
                let _ = enigo.key(key, enigo::Direction::Release);
            }
            for modifier in modifiers.iter().rev() {
                let _ = enigo.key(*modifier, enigo::Direction::Release);
            }
        }
        Action::Tap => {
            // Press modifiers, tap main key, release modifiers
            for modifier in &modifiers {
                let _ = enigo.key(*modifier, enigo::Direction::Press);
            }
            if let Some(key) = main_key {
                let _ = enigo.key(key, enigo::Direction::Click);
            }
            for modifier in modifiers.iter().rev() {
                let _ = enigo.key(*modifier, enigo::Direction::Release);
            }
        }
    }
}

fn parse_key_parts(parts: &[&str]) -> (Vec<Key>, Option<Key>) {
    let mut modifiers = Vec::new();
    let mut main_key = None;

    for part in parts {
        let upper = part.to_uppercase();
        match upper.as_str() {
            // Modifiers
            "CTRL" | "CONTROL" => modifiers.push(Key::Control),
            "SHIFT" => modifiers.push(Key::Shift),
            "ALT" => modifiers.push(Key::Alt),
            "META" | "WIN" | "SUPER" => modifiers.push(Key::Meta),

            // Function keys
            "F1" => main_key = Some(Key::F1),
            "F2" => main_key = Some(Key::F2),
            "F3" => main_key = Some(Key::F3),
            "F4" => main_key = Some(Key::F4),
            "F5" => main_key = Some(Key::F5),
            "F6" => main_key = Some(Key::F6),
            "F7" => main_key = Some(Key::F7),
            "F8" => main_key = Some(Key::F8),
            "F9" => main_key = Some(Key::F9),
            "F10" => main_key = Some(Key::F10),
            "F11" => main_key = Some(Key::F11),
            "F12" => main_key = Some(Key::F12),

            // Special keys
            "SPACE" => main_key = Some(Key::Space),
            "ENTER" | "RETURN" => main_key = Some(Key::Return),
            "TAB" => main_key = Some(Key::Tab),
            "ESCAPE" | "ESC" => main_key = Some(Key::Escape),
            "BACKSPACE" => main_key = Some(Key::Backspace),
            "DELETE" | "DEL" => main_key = Some(Key::Delete),
            "INSERT" | "INS" => main_key = Some(Key::Insert),
            "HOME" => main_key = Some(Key::Home),
            "END" => main_key = Some(Key::End),
            "PAGEUP" | "PGUP" => main_key = Some(Key::PageUp),
            "PAGEDOWN" | "PGDN" => main_key = Some(Key::PageDown),

            // Arrow keys
            "UP" | "ARROWUP" => main_key = Some(Key::UpArrow),
            "DOWN" | "ARROWDOWN" => main_key = Some(Key::DownArrow),
            "LEFT" | "ARROWLEFT" => main_key = Some(Key::LeftArrow),
            "RIGHT" | "ARROWRIGHT" => main_key = Some(Key::RightArrow),

            // Numpad
            "NUMPAD0" => main_key = Some(Key::Numpad0),
            "NUMPAD1" => main_key = Some(Key::Numpad1),
            "NUMPAD2" => main_key = Some(Key::Numpad2),
            "NUMPAD3" => main_key = Some(Key::Numpad3),
            "NUMPAD4" => main_key = Some(Key::Numpad4),
            "NUMPAD5" => main_key = Some(Key::Numpad5),
            "NUMPAD6" => main_key = Some(Key::Numpad6),
            "NUMPAD7" => main_key = Some(Key::Numpad7),
            "NUMPAD8" => main_key = Some(Key::Numpad8),
            "NUMPAD9" => main_key = Some(Key::Numpad9),

            // Single character (letter or number)
            s if s.len() == 1 => {
                let c = s.chars().next().unwrap();
                main_key = Some(Key::Unicode(c.to_ascii_lowercase()));
            }

            // Unknown key - try as unicode
            s => {
                eprintln!("Warning: Unknown key '{}', treating as unicode", s);
                if let Some(c) = s.chars().next() {
                    main_key = Some(Key::Unicode(c.to_ascii_lowercase()));
                }
            }
        }
    }

    (modifiers, main_key)
}
