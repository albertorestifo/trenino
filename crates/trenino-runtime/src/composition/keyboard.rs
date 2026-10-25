use crate::{
    keyboard::{
        HoldOwner, KeyboardOwnership, KeystrokeAdapter, KeystrokeError, ProcessKeystrokeAdapter,
    },
    train::button_controller::{ButtonKeystrokes, KeystrokeOwner},
};
use std::sync::Mutex;
use trenino_core::EntityId;
pub struct NativeKeyboard(Mutex<KeyboardOwnership<OptionalKeyboard>>);
struct OptionalKeyboard(Result<ProcessKeystrokeAdapter, KeystrokeError>);
impl KeystrokeAdapter for OptionalKeyboard {
    fn key_down(&self, c: &str) -> Result<(), KeystrokeError> {
        self.0.as_ref().map_err(Clone::clone)?.key_down(c)
    }
    fn key_up(&self, c: &str) -> Result<(), KeystrokeError> {
        self.0.as_ref().map_err(Clone::clone)?.key_up(c)
    }
    fn key_tap(&self, c: &str) -> Result<(), KeystrokeError> {
        self.0.as_ref().map_err(Clone::clone)?.key_tap(c)
    }
}
fn outcome(errors: Vec<KeystrokeError>) -> Result<(), String> {
    if errors.is_empty() {
        Ok(())
    } else {
        Err(format!("keyboard: {errors:?}"))
    }
}
fn owner(o: KeystrokeOwner) -> HoldOwner {
    HoldOwner {
        owner: o.owner,
        generation: o.generation,
    }
}
impl NativeKeyboard {
    pub fn new(probe: &crate::executable::ExecutableProbe) -> Self {
        Self(Mutex::new(KeyboardOwnership::new(OptionalKeyboard(
            ProcessKeystrokeAdapter::discover(probe),
        ))))
    }
    pub fn shutdown(&self) -> Result<(), String> {
        outcome(self.0.lock().expect("keyboard").shutdown())
    }
}
impl ButtonKeystrokes for NativeKeyboard {
    fn press(&self, o: KeystrokeOwner, b: EntityId, c: &str) -> Result<(), String> {
        outcome(self.0.lock().expect("keyboard").press(owner(o), b, c))
    }
    fn release(&self, o: KeystrokeOwner, b: EntityId) -> Result<(), String> {
        outcome(self.0.lock().expect("keyboard").release(owner(o), b))
    }
    fn owner_gone(&self, o: KeystrokeOwner) {
        if let Err(e) = outcome(self.0.lock().expect("keyboard").owner_gone(owner(o))) {
            eprintln!("{e}");
        }
    }
}
