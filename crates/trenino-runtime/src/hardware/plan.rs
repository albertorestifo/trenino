//! Compile a committed stored configuration into the existing fenced apply
//! operation. Virtual matrix inputs are resolver entries, never physical
//! ConfigureButton packets.
use super::configuration::ConfigurationApply;
use crate::{
    routing::InputIdentity,
    storage::{Database, InputKind},
};
use std::time::Duration;
use trenino_core::{
    hardware::{build_configuration, DeviceConfiguration, Input, Matrix, Module},
    EntityId,
};

pub fn configuration_request(
    db: &Database,
    device_id: EntityId,
    port: &str,
    generation: u64,
) -> Result<ConfigurationApply<Vec<(u8, InputIdentity)>>, String> {
    if generation == 0 {
        return Err("Select a current serial connection generation.".into());
    }
    let (hardware, _) = db.hardware_snapshot().map_err(|error| error.to_string())?;
    let device = hardware
        .devices
        .iter()
        .find(|d| d.id == device_id)
        .ok_or("Configuration not found.")?;
    let config_id = device
        .config_id
        .ok_or("Configuration has no firmware identity.")?;
    let mut inputs = Vec::new();
    let mut mappings = Vec::new();
    for input in hardware
        .inputs
        .iter()
        .filter(|i| i.device_id == Some(device_id))
    {
        let pin = u8::try_from(input.pin.ok_or("Input has no pin.")?)
            .map_err(|_| "Input pin is outside the firmware range.")?;
        mappings.push((
            pin,
            InputIdentity {
                device_id,
                input_id: input.id,
            },
        ));
        if input.matrix_id.is_some() {
            continue;
        }
        inputs.push(match input.kind.ok_or("Input has no kind.")? {
            InputKind::Analog => Input::Analog {
                pin,
                sensitivity: u8::try_from(
                    input.sensitivity.ok_or("Analog sensitivity is missing.")?,
                )
                .map_err(|_| "Invalid sensitivity.")?,
            },
            InputKind::Button => Input::Button {
                pin,
                debounce: u16::try_from(input.debounce.ok_or("Button debounce is missing.")?)
                    .map_err(|_| "Invalid debounce.")?,
            },
        });
    }
    let matrices = hardware
        .matrices
        .iter()
        .filter(|m| m.device_id == device_id)
        .map(|m| {
            let pins = |rows: &[crate::storage::MatrixPinRecord]| -> Result<Vec<u8>, String> {
                let mut rows = rows.iter().collect::<Vec<_>>();
                rows.sort_by_key(|p| p.position);
                rows.into_iter()
                    .map(|p| {
                        u8::try_from(p.pin)
                            .map_err(|_| "Matrix pin is outside the firmware range.".into())
                    })
                    .collect()
            };
            Ok(Matrix {
                row_pins: pins(&m.row_pins)?,
                col_pins: pins(&m.col_pins)?,
            })
        })
        .collect::<Result<Vec<_>, String>>()?;
    let modules = hardware
        .i2c_modules
        .iter()
        .filter(|m| m.device_id == device_id)
        .map(|m| {
            if m.module_chip != "ht16k33" {
                return Err("Unsupported I2C module.".to_string());
            }
            let params = m
                .params
                .as_ref()
                .ok_or("Display configuration is missing.")?;
            Ok(Module::Ht16k33 {
                address: u16::try_from(m.i2c_address).map_err(|_| "Invalid I2C address.")?,
                brightness: u8::try_from(params.brightness).map_err(|_| "Invalid brightness.")?,
                num_digits: u8::try_from(params.num_digits).map_err(|_| "Invalid digit count.")?,
            })
        })
        .collect::<Result<Vec<_>, String>>()?;
    let messages = build_configuration(
        &DeviceConfiguration {
            inputs,
            matrices,
            modules,
        },
        config_id,
    )?;
    mappings.sort_by_key(|(pin, _)| *pin);
    Ok(ConfigurationApply {
        port_name: port.into(),
        generation,
        device_id,
        config_id,
        messages,
        mappings,
        timeout: Duration::from_secs(10),
    })
}
