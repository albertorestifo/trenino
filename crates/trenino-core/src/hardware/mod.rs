pub mod calibration;
pub mod ht16k33;
pub mod protocol;

pub use crate::ConfigId;
use serde::{Deserialize, Serialize};
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum Input {
    Analog { pin: u8, sensitivity: u8 },
    Button { pin: u8, debounce: u16 },
}
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct AnalogInput {
    pub pin: u8,
    pub sensitivity: u8,
}
impl AnalogInput {
    pub fn validate(&self) -> Result<(), String> {
        if self.pin > 127 {
            return Err("physical pin must be 0..127".into());
        }
        if !(1..=10).contains(&self.sensitivity) {
            return Err("sensitivity must be 1..10".into());
        }
        Ok(())
    }
}
impl From<AnalogInput> for Input {
    fn from(x: AnalogInput) -> Self {
        Self::Analog {
            pin: x.pin,
            sensitivity: x.sensitivity,
        }
    }
}
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct ButtonInput {
    pub pin: u8,
    pub debounce: u16,
}
impl ButtonInput {
    pub fn validate(&self) -> Result<(), String> {
        if self.pin > 127 {
            return Err("physical pin must be 0..127".into());
        }
        if self.debounce > 255 {
            return Err("debounce must be 0..255".into());
        }
        Ok(())
    }
}
impl From<ButtonInput> for Input {
    fn from(x: ButtonInput) -> Self {
        Self::Button {
            pin: x.pin,
            debounce: x.debounce,
        }
    }
}
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct Matrix {
    pub row_pins: Vec<u8>,
    pub col_pins: Vec<u8>,
}
impl Matrix {
    pub fn validate(&self) -> Result<(), String> {
        if self.row_pins.is_empty() || self.col_pins.is_empty() {
            return Err("matrix must have at least one row and one column".into());
        }
        if self.row_pins.iter().chain(&self.col_pins).any(|p| *p > 127) {
            return Err("matrix physical pins must be 0..127".into());
        }
        if self.row_pins.len() > 255 || self.col_pins.len() > 255 {
            return Err("matrix pin count exceeds wire limit".into());
        }
        if self.row_pins.len().saturating_mul(self.col_pins.len()) > 128 {
            return Err("matrix exceeds virtual pin range".into());
        }
        Ok(())
    }
    pub fn virtual_pin(row: usize, col: usize, num_cols: usize) -> Option<u8> {
        let n = 128usize.checked_add(row.checked_mul(num_cols)?.checked_add(col)?)?;
        if n <= 255 {
            Some(n as u8)
        } else {
            None
        }
    }
}
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum Module {
    Ht16k33 {
        address: u16,
        brightness: u8,
        num_digits: u8,
    },
}
impl Module {
    pub fn validate(&self) -> Result<(), String> {
        match self {
            Self::Ht16k33 {
                address,
                brightness,
                num_digits,
            } => {
                if *address > 255 {
                    return Err("I2C address must be 0..255".into());
                }
                if *brightness > 15 {
                    return Err("brightness must be 0..15".into());
                }
                if ![4, 8].contains(num_digits) {
                    return Err("digit count must be 4 or 8".into());
                }
                Ok(())
            }
        }
    }
    pub fn parse_address(s: &str) -> Option<u16> {
        if let Some(h) = s.strip_prefix("0x") {
            u16::from_str_radix(h, 16).ok().filter(|v| *v <= 255)
        } else {
            s.parse::<u16>().ok().filter(|v| *v <= 255)
        }
    }
}
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct DeviceConfiguration {
    pub inputs: Vec<Input>,
    pub matrices: Vec<Matrix>,
    pub modules: Vec<Module>,
}
pub fn build_configuration(
    c: &DeviceConfiguration,
    id: ConfigId,
) -> Result<Vec<protocol::Message>, String> {
    if c.inputs.is_empty() && c.matrices.is_empty() && c.modules.is_empty() {
        return Err("configuration has no inputs".into());
    }

    let mut input_pins = std::collections::HashSet::new();
    for input in &c.inputs {
        let pin = match input {
            Input::Analog { pin, sensitivity } => {
                AnalogInput {
                    pin: *pin,
                    sensitivity: *sensitivity,
                }
                .validate()?;
                *pin
            }
            Input::Button { pin, debounce } => {
                ButtonInput {
                    pin: *pin,
                    debounce: *debounce,
                }
                .validate()?;
                *pin
            }
        };
        if !input_pins.insert(pin) {
            return Err(format!(
                "physical input pin {pin} is assigned more than once"
            ));
        }
    }

    let mut module_addresses = std::collections::HashSet::new();
    for module in &c.modules {
        module.validate()?;
        let address = match module {
            Module::Ht16k33 { address, .. } => *address,
        };
        if !module_addresses.insert(address) {
            return Err(format!("I2C address {address} is assigned more than once"));
        }
    }

    let mut virtual_pins = std::collections::HashSet::new();
    for matrix in &c.matrices {
        matrix.validate()?;
        for row in 0..matrix.row_pins.len() {
            for col in 0..matrix.col_pins.len() {
                let pin = Matrix::virtual_pin(row, col, matrix.col_pins.len())
                    .ok_or_else(|| "matrix exceeds virtual pin range".to_string())?;
                if !virtual_pins.insert(pin) {
                    return Err(format!(
                        "generated matrix virtual pin {pin} is assigned more than once"
                    ));
                }
            }
        }
    }

    let mut out = Vec::new();
    let mut inputs = c.inputs.clone();
    inputs.sort_by_key(|i| match i {
        Input::Analog { pin, .. } | Input::Button { pin, .. } => *pin,
    });
    for input in &inputs {
        match input {
            Input::Analog { pin, sensitivity } => {
                let x = AnalogInput {
                    pin: *pin,
                    sensitivity: *sensitivity,
                };
                x.validate()?;
                out.push(protocol::Message::ConfigureAnalog {
                    config_id: id.get(),
                    total_parts: 0,
                    part_number: 0,
                    pin: *pin,
                    sensitivity: *sensitivity,
                });
            }
            Input::Button { pin, debounce } => {
                let x = ButtonInput {
                    pin: *pin,
                    debounce: *debounce,
                };
                x.validate()?;
                out.push(protocol::Message::ConfigureButton {
                    config_id: id.get(),
                    total_parts: 0,
                    part_number: 0,
                    pin: *pin,
                    debounce: *debounce as u8,
                });
            }
        }
    }
    for m in &c.matrices {
        m.validate()?;
        out.push(protocol::Message::ConfigureMatrix {
            config_id: id.get(),
            total_parts: 0,
            part_number: 0,
            row_pins: m.row_pins.clone(),
            col_pins: m.col_pins.clone(),
        });
    }
    let mut modules = c.modules.iter().collect::<Vec<_>>();
    modules.sort_by_key(|m| match m {
        Module::Ht16k33 { address, .. } => *address,
    });
    for m in modules {
        m.validate()?;
        match m {
            Module::Ht16k33 {
                address,
                brightness,
                num_digits,
            } => out.push(protocol::Message::ConfigureHt16k33 {
                config_id: id.get(),
                total_parts: 0,
                part_number: 0,
                address: *address as u8,
                brightness: *brightness,
                num_digits: *num_digits,
            }),
        }
    }
    if out.len() > 255 {
        return Err("configuration exceeds 255 parts".into());
    }
    let total = out.len() as u8;
    for (i, m) in out.iter_mut().enumerate() {
        m.set_part(total, i as u8)
    }
    Ok(out)
}
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub enum InputKind {
    #[default]
    Any,
    Analog,
    Button,
}
#[derive(Default)]
pub struct InputDetection {
    filter: InputKind,
    baselines: std::collections::HashMap<u64, i32>,
}
impl InputDetection {
    pub fn new(filter: InputKind) -> Self {
        Self {
            filter,
            baselines: Default::default(),
        }
    }
    pub fn observe(&mut self, key: u64, value: i32, kind: InputKind) -> bool {
        let Some(old) = self.baselines.get(&key).copied() else {
            self.baselines.insert(key, value);
            return false;
        };
        (self.filter == InputKind::Any || self.filter == kind)
            && match kind {
                InputKind::Button => old != value,
                InputKind::Analog => (i64::from(value) - i64::from(old)).abs() > 50,
                InputKind::Any => false,
            }
    }
}
