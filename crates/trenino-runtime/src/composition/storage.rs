use crate::{
    storage::{Database, DisplayType, HardwareSnapshot},
    train::{
        display_controller::{DisplayBindingConfig, DisplayBindingSource},
        output_controller::{
            HardwareDispatch, OutputBindingConfig, OutputBindingSource, OutputLevel,
        },
        script::{DisplayPort, HardwareOutputPort, ScriptDefinition, ScriptSource},
    },
};
use std::sync::Arc;
use trenino_core::{hardware::ht16k33::encode_string, train::output::OutputOperator, EntityId};
#[derive(Clone)]
pub struct DbSources(pub Arc<Database>);
fn report<T>(result: Result<T, crate::storage::StorageError>) -> Option<T> {
    match result {
        Ok(value) => Some(value),
        Err(error) => {
            eprintln!("runtime configuration: {error}");
            None
        }
    }
}
fn config(hw: &HardwareSnapshot, device: EntityId) -> Option<i64> {
    hw.devices
        .iter()
        .find(|d| d.id == device)?
        .config_id
        .map(|v| v.get() as i64)
}
impl ScriptSource for DbSources {
    fn enabled_scripts(&self, id: i64) -> Vec<ScriptDefinition> {
        report(self.0.list_enabled_scripts(EntityId(id)))
            .unwrap_or_default()
            .into_iter()
            .map(|s| ScriptDefinition {
                id: s.id.0,
                name: s.name,
                code: s.code,
                triggers: s.triggers,
            })
            .collect()
    }
}
impl OutputBindingSource for DbSources {
    fn enabled_output_bindings(&self, id: i64) -> Vec<OutputBindingConfig> {
        let Some((hw, _)) = report(self.0.hardware_snapshot()) else {
            return vec![];
        };
        report(self.0.list_enabled_output_bindings(EntityId(id)))
            .unwrap_or_default()
            .into_iter()
            .filter_map(|b| {
                let output = hw.outputs.iter().find(|o| o.id == b.output_id)?;
                use crate::storage::bindings::OutputBindingOperator as O;
                Some(OutputBindingConfig {
                    id: b.id.0,
                    endpoint: b.endpoint,
                    operator: match b.operator {
                        O::Gt => OutputOperator::Gt,
                        O::Gte => OutputOperator::Gte,
                        O::Lt => OutputOperator::Lt,
                        O::Lte => OutputOperator::Lte,
                        O::Between => OutputOperator::Between,
                        O::EqTrue => OutputOperator::EqTrue,
                        O::EqFalse => OutputOperator::EqFalse,
                    },
                    value_a: b.value_a,
                    value_b: b.value_b,
                    device_config_id: config(&hw, output.device_id)?,
                    pin: output.pin,
                })
            })
            .collect()
    }
}
impl DisplayBindingSource for DbSources {
    fn enabled_display_bindings(&self, id: i64) -> Vec<DisplayBindingConfig> {
        let Some((hw, _)) = report(self.0.hardware_snapshot()) else {
            return vec![];
        };
        report(self.0.list_enabled_display_bindings(EntityId(id)))
            .unwrap_or_default()
            .into_iter()
            .filter_map(|b| {
                let module = hw.i2c_modules.iter().find(|m| m.id == b.i2c_module_id)?;
                let p = module.params.as_ref()?;
                Some(DisplayBindingConfig {
                    id: b.id.0,
                    endpoint: b.endpoint,
                    format_string: b.format_string,
                    device_config_id: config(&hw, module.device_id)?,
                    i2c_address: module.i2c_address,
                    brightness: p.brightness,
                    num_digits: p.num_digits as usize,
                    seven_segment: p.display_type == DisplayType::SevenSegment,
                    has_dot: p.has_dot,
                    align_right: p.align_right,
                    min_value: p.min_value,
                })
            })
            .collect()
    }
}
pub struct ScriptHardware {
    pub db: Arc<Database>,
    pub dispatch: Arc<dyn HardwareDispatch>,
}
impl HardwareOutputPort for ScriptHardware {
    fn set_output(&self, id: i64, on: bool) {
        let result = (|| {
            let output = self
                .db
                .get_output(EntityId(id))
                .map_err(|e| e.to_string())?
                .ok_or("output not found")?;
            let device = self
                .db
                .get_device(output.device_id)
                .map_err(|e| e.to_string())?
                .ok_or("device not found")?;
            let config = device.config_id.ok_or("device not configured")?;
            let port = self
                .dispatch
                .resolve_port(config.get() as i64)
                .ok_or("device disconnected")?;
            self.dispatch.set_output(
                &port,
                output.pin,
                if on {
                    OutputLevel::High
                } else {
                    OutputLevel::Low
                },
            )
        })();
        if let Err(e) = result {
            eprintln!("script output: {e}");
        }
    }
}
impl DisplayPort for ScriptHardware {
    fn write_display(&self, address: i64, text: &str) {
        let result = (|| {
            let (hw, _) = self.db.hardware_snapshot().map_err(|e| e.to_string())?;
            let module = hw
                .i2c_modules
                .iter()
                .find(|m| m.i2c_address as i64 == address)
                .ok_or("display not found")?;
            let p = module.params.as_ref().ok_or("display parameters missing")?;
            let port = self
                .dispatch
                .resolve_port(config(&hw, module.device_id).ok_or("device not configured")?)
                .ok_or("display disconnected")?;
            self.dispatch.write_segments(
                &port,
                module.i2c_address,
                encode_string(
                    text,
                    p.num_digits as usize,
                    p.display_type == DisplayType::SevenSegment,
                    p.has_dot,
                    p.align_right,
                ),
            )
        })();
        if let Err(e) = result {
            eprintln!("script display: {e}");
        }
    }
}
