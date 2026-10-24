use std::fmt::Display;

#[derive(Debug, Copy, Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Default)]
pub enum ButtonState {
    #[default]
    Released = 0,
    Pressed,
}
impl ButtonState {
    fn default() -> ButtonState {
        ButtonState::Released
    }
}

impl Display for ButtonState {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let str = match *self {
            ButtonState::Released => "released",
            ButtonState::Pressed => "pressed",
        };
        f.write_fmt(format_args!("{}", str))
    }
}

#[derive(Debug, Clone, Copy)]
/// Current state of an enabled device button.
///
/// Range of IDs is 1..=128 for consistency with the .dll.
pub struct Button {
    pub(crate) id: u8,
    pub(crate) state: ButtonState,
}

impl Button {
    #[profiling::function]
    pub fn get(&self) -> ButtonState {
        self.state
    }

    #[profiling::function]
    pub fn set(&mut self, value: ButtonState) {
        self.state = value;
    }

    #[profiling::function]
    pub fn reset(&mut self) {
        self.state = ButtonState::default();
    }
}

impl Display for Button {
    #[profiling::function]
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_fmt(format_args!(
            "Button ID: {} | state: {}",
            self.id, self.state
        ))
    }
}
