//! Typed hardware persistence on the database's existing bounded worker.
use super::{
    metadata_key, read_u64, validate_runtime_metadata, Connection, Database, DbResult, Request,
    RuntimeMetadata, SchemaMode, StorageError,
};
use rusqlite::{params, OptionalExtension, Transaction};
use serde::{Deserialize, Serialize};
use std::{any::Any, sync::mpsc};
use trenino_core::{ConfigId, EntityId, OperationId};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum InputKind {
    Analog,
    Button,
}

impl InputKind {
    fn as_db(self) -> &'static str {
        match self {
            Self::Analog => "analog",
            Self::Button => "button",
        }
    }
    fn parse(value: &str) -> DbResult<Self> {
        match value {
            "analog" => Ok(Self::Analog),
            "button" => Ok(Self::Button),
            _ => Err(invalid(format!("unknown input_type {value:?}"))),
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MatrixPinType {
    Row,
    Column,
}

impl MatrixPinType {
    pub fn as_db(self) -> &'static str {
        match self {
            Self::Row => "row",
            Self::Column => "col",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MutationOutcome {
    Committed,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MutationReceipt {
    pub operation_id: OperationId,
    pub outcome: MutationOutcome,
    pub metadata: RuntimeMetadata,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Mutation<T> {
    pub record: T,
    pub receipt: MutationReceipt,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DeviceRecord {
    pub id: EntityId,
    pub name: Option<String>,
    pub description: Option<String>,
    pub config_id: Option<ConfigId>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DeviceDraft {
    pub name: String,
    pub description: Option<String>,
    pub config_id: Option<ConfigId>,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct DevicePatch {
    pub name: Option<String>,
    pub description: Option<Option<String>>,
    pub config_id: Option<Option<ConfigId>>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CalibrationRecord {
    pub max_hardware_value: Option<i32>,
    pub min_value: Option<i32>,
    pub max_value: Option<i32>,
    pub has_rollover: bool,
    pub is_inverted: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CalibrationRow {
    pub id: EntityId,
    pub input_id: Option<EntityId>,
    pub value: CalibrationRecord,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct InputRecord {
    pub id: EntityId,
    pub pin: Option<i32>,
    pub kind: Option<InputKind>,
    pub sensitivity: Option<i32>,
    pub debounce: Option<i32>,
    pub device_id: Option<EntityId>,
    pub matrix_id: Option<EntityId>,
    pub name: Option<String>,
    pub calibration: Option<CalibrationRow>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct InputDraft {
    pub pin: i32,
    pub kind: InputKind,
    pub sensitivity: Option<i32>,
    pub debounce: Option<i32>,
    pub name: Option<String>,
    pub matrix_id: Option<EntityId>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct OutputRecord {
    pub id: EntityId,
    pub pin: i32,
    pub name: Option<String>,
    pub device_id: EntityId,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct OutputDraft {
    pub pin: i32,
    pub name: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MatrixPinRecord {
    pub id: EntityId,
    pub pin: i32,
    pub pin_type: MatrixPinType,
    pub position: i32,
    pub matrix_id: EntityId,
}

#[derive(Clone, Debug, PartialEq)]
pub struct MatrixRecord {
    pub id: EntityId,
    pub name: String,
    pub device_id: EntityId,
    pub row_pins: Vec<MatrixPinRecord>,
    pub col_pins: Vec<MatrixPinRecord>,
    pub buttons: Vec<InputRecord>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MatrixDraft {
    pub name: String,
    pub row_pins: Vec<i32>,
    pub col_pins: Vec<i32>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DisplayType {
    SevenSegment,
    FourteenSegment,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Ht16k33Params {
    pub brightness: i32,
    pub num_digits: i32,
    pub display_type: DisplayType,
    pub has_dot: bool,
    pub align_right: bool,
    pub min_value: Option<f64>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct I2cModuleRecord {
    pub id: EntityId,
    pub device_id: EntityId,
    pub name: Option<String>,
    pub module_chip: String,
    pub i2c_address: i32,
    pub params: Option<Ht16k33Params>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct I2cModuleDraft {
    pub name: Option<String>,
    pub module_chip: String,
    pub i2c_address: i32,
    pub params: Option<Ht16k33Params>,
}

#[derive(Clone, Debug, Partial)]
pub struct HardwareSnapshot {
    pub devices: Vec<DeviceRecord>,
    pub inputs: Vec<InputRecord>,
    pub outputs: Vec<OutputRecord>,
    pub matrices: Vec<MatrixRecord>,
    pub i2c_modules: Vec<I2cModuleRecord>,
    pub metadata: RuntimeMetadata,
}

impl Database {
    fn hardware_call<T: Send + 'static>(
        &self,
        operation: &'static str,
        f: impl FnOnce(&mut Connection) -> DbResult<T> + Send + 'static,
    ) -> DbResult<T> {
        let (reply_tx, reply_rx) = mpsc::channel();
        let job = Box::new(move |connection: &mut Connection, mode: SchemaMode| {
            let result = if mode == SchemaMode::Full {
                f(connection)
            } else {
                Err(StorageError::UnsupportedOperation { operation })
            };
            let _ = reply_tx.send(result);
        });
        self.worker
            .tx
            .lock()
            .map_err(|_| StorageError::WorkerStopped)?
            .as_ref()
            .ok_or(StorageError::WorkerStopped)?
            .send(Request::Hardware(job))
            .map_err(|_| StorageError::WorkerStopped)?;
        reply_rx.recv().map_err(|_| StorageError::WorkerStopped)?
    }

    pub fn hardware_snapshot(&self) -> DbResult<HardwareSnapshot> {
        self.hardware_call("hardware_snapshot", |connection| snapshot(connection))
    }

    pub fn get_device(&self, id: EntityId) -> DbResult<Option<DeviceRecord>> {
        self.hardware_call("get_device", move |c| get_device(c, id))
    }

    pub fn get_device_by_config_id(&self, config_id: ConfigId) -> DbResult<Option<DeviceRecord>> {
        self.hardware_call("get_device_by_config_id", move |c| get_device_config(c, config_id))
    }

    pub fn create_device(
        &self,
        operation_id: OperationId,
        draft: DeviceDraft,
    ) -> DbResult<Mutation<DeviceRecord>> {
        self.hardware_call("create_device", move |c| create_device(c, operation_id, draft))
    }

    pub fn update_device(
        &self,
        operation_id: OperationId,
        id: EntityId,
        patch: DevicePatch,
    ) -> DbResult<Mutation<DeviceRecord>> {
        self.hardware_call("update_device", move |c| update_device(c, operation_id, id, patch))
    }

    /// Internal destructive primitive. Application-facing deletion must first acquire
    /// the hardware service's fail-closed active-configuration exclusion guard.
    pub(crate) fn delete_device_unchecked(
        &self,
        operation_id: OperationId,
        id: EntityId,
    ) -> DbResult<Mutation<DeviceRecord>> {
        self.hardware_call("delete_device", move |c| delete_device(c, operation_id, id))
    }

    pub fn get_input(&self, id: EntityId) -> DbResult<Option<InputRecord>> {
        self.hardware_call("get_input", move |c| get_input(c, id))
    }

    pub fn inputs_for_device(&self, id: EntityId, include_virtual: bool) -> DbResult<Vec<InputRecord>> {
        self.hardware_call("inputs_for_device", move |c| inputs_for_device(c, id, include_virtual))
    }

    pub fn create_input(&self, operation_id: OperationId, device_id: EntityId, draft: InputDraft) -> DbResult<Mutation<InputRecord>> {
        self.hardware_call("create_input", move |c| create_input(c, operation_id, device_id, draft))
    }

    pub fn update_input(&self, operation_id: OperationId, id: EntityId, draft: InputDraft) -> DbResult<Mutation<InputRecord>> {
        self.hardware_call("update_input", move |c| update_input(c, operation_id, id, draft))
    }

    pub fn delete_input(&self, operation_id: OperationId, id: EntityId) -> DbResult<Mutation<InputRecord>> {
        self.hardware_call("delete_input", move |c| delete_input(c, operation_id, id))
    }

    pub fn get_output(&self, id: EntityId) -> DbResult<Option<OutputRecord>> {
        self.hardware_call("get_output", move |c| get_output(c, id))
    }

    pub fn outputs_for_device(&self, id: EntityId) -> DbResult<Vec<OutputRecord>> {
        self.hardware_call("outputs_for_device", move |c| outputs_for_device(c, id))
    }

    pub fn create_output(&self, operation_id: OperationId, device_id: EntityId, draft: OutputDraft) -> DbResult<Mutation<OutputRecord>> {
        self.hardware_call("create_output", move |c| create_output(c, operation_id, device_id, draft))
    }

    pub fn update_output(&self, operation_id: OperationId, id: EntityId, draft: OutputDraft) -> DbResult<Mutation<OutputRecord>> {
        self.hardware_call("update_output", move |c| update_output(c, operation_id, id, draft))
    }

    pub fn delete_output(&self, operation_id: OperationId, id: EntityId) -> DbResult<Mutation<OutputRecord>> {
        self.hardware_call("delete_output", move |c| delete_output(c, operation_id, id))
    }

    pub fn get_matrix(&self, id: EntityId) -> DbResult<Option<MatrixRecord>> {
        self.hardware_call("get_matrix", move |c| get_matrix(c, id))
    }

    pub fn matrices_for_device(&self, id: EntityId) -> DbResult<Vec<MatrixRecord>> {
        self.hardware_call("matrices_for_device", move |c| matrices_for_device(c, id))
    }

    pub fn create_matrix(&self, operation_id: OperationId, device_id: EntityId, draft: MatrixDraft) -> DbResult<Mutation<MatrixRecord>> {
        self.hardware_call("create_matrix", move |c| create_matrix(c, operation_id, device_id, draft))
    }

    pub fn replace_matrix_children(&self, operation_id: OperationId, id: EntityId, row_pins: Vec<i32>, col_pins: Vec<i32>) -> DbResult<Mutation<MatrixRecord>> {
        self.hardware_call("replace_matrix_children", move |c| replace_matrix_children(c, operation_id, id, row_pins, col_pins))
    }

    pub fn delete_matrix(&self, operation_id: OperationId, id: EntityId) -> DbResult<Mutation<MatrixRecord>> {
        self.hardware_call("delete_matrix", move |c| delete_matrix(c, operation_id, id))
    }

    pub fn i2c_modules_for_device(&self, id: EntityId) -> DbResult<Vec<I2cModuleRecord>> {
        self.hardware_call("i2c_modules_for_device", move |c| i2c_modules_for_device(c, id))
    }

    pub fn create_i2c_module(&self, operation_id: OperationId, device_id: EntityId, draft: I2cModuleDraft) -> DbResult<Mutation<I2cModuleRecord>> {
        self.hardware_call("create_i2c_module", move |c| create_i2c_module(c, operation_id, device_id, draft))
    }

    pub fn update_i2c_module(&self, operation_id: OperationId, id: EntityId, draft: I2cModuleDraft) -> DbResult<Mutation<I2cModuleRecord>> {
        self.hardware_call("update_i2c_module", move |c| update_i2c_module(c, operation_id, id, draft))
    }

    pub fn delete_i2c_module(&self, operation_id: OperationId, id: EntityId) -> DbResult<Mutation<I2cModuleRecord>> {
        self.hardware_call("delete_i2c_module", move |c| delete_i2c_module(c, operation_id, id))
    }

    pub fn save_calibration(&self, operation_id: OperationId, input_id: EntityId, value: CalibrationRecord) -> DbResult<Mutation<CalibrationRow>> {
        self.hardware_call("save_calibration", move |c| save_calibration(c, operation_id, input_id, value))
    }
}

fn invalid(detail: String) -> StorageError {
    StorageError::InvalidHardware { detail }
}

fn hardware_tx<T>(
    connection: &mut Connection,
    operation_id: OperationId,
    f: impl FnOnce(&Transaction<'_>) -> DbResult<T>,
) -> DbResult<Mutation<T>> {
    let tx = connection.transaction()?;
    if validate_runtime_metadata(&tx)?.is_none() {
        return Err(StorageError::InvalidLegacyData { detail: "runtime metadata has not been initialized".into() });
    }
    let record = f(&tx)?;
    let key = metadata_key("hardware")?;
    let current = read_u64(&tx, &key, 0)?;
    let revision = current.checked_add(1).ok_or_else(|| StorageError::InvalidLegacyData { detail: "hardware topic revision counter is exhausted".into() })?;
    tx.execute("INSERT INTO app_settings(key,value) VALUES(?1,?2) ON CONFLICT(key) DO UPDATE SET value=excluded.value", (&key, revision.to_string()))?;
    let epoch = read_u64(&tx, "__runtime.epoch", 0)?;
    tx.commit()?;
    Ok(Mutation { record, receipt: MutationReceipt { operation_id, outcome: MutationOutcome::Committed, metadata: RuntimeMetadata { epoch, revision } } })
}

fn snapshot(connection: &mut Connection) -> DbResult<HardwareSnapshot> {
    let tx = connection.transaction()?;
    if validate_runtime_metadata(&tx)?.is_none() {
        return Err(StorageError::InvalidLegacyData { detail: "runtime metadata has not been initialized".into() });
    }
    let devices = all_devices(&tx)?;
    let mut inputs = Vec::new();
    let mut outputs = Vec::new();
    let mut matrices = Vec::new();
    let mut i2c_modules = Vec::new();
    for device in &devices {
        inputs.extend(inputs_for_device_conn(&tx, device.id, true)?);
        outputs.extend(outputs_for_device_conn(&tx, device.id)?);
        matrices.extend(matrices_for_device_conn(&tx, device.id)?);
        i2c_modules.extend(i2c_modules_for_device_conn(&tx, device.id)?);
    }
    let metadata = RuntimeMetadata { epoch: read_u64(&tx, "__runtime.epoch", 0)?, revision: read_u64(&tx, &metadata_key("hardware")?, 0)? };
    tx.commit()?;
    Ok(HardwareSnapshot { devices, inputs, outputs, matrices, i2c_modules, metadata })
}

fn all_devices(c: &Connection) -> DbResult<Vec<DeviceRecord>> {
    let mut q = c.prepare("SELECT id,name,description,config_id FROM devices ORDER BY name,id")?;
    let rows = q.query_map([], device_row)?;
    rows.collect::<Result<Vec<_>, _>>().map_err(StorageError::from)
}

fn device_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<DeviceRecord> {
    let raw_config: Option<i64> = row.get(3)?;
    let config_id = raw_config.map(|value| ConfigId::new(value as u32).map_err(|_| rusqlite::Error::FromSqlConversionFailure(3, rusqlite::types::Type::Integer, "invalid ConfigId".into()))).transpose()?;
    Ok(DeviceRecord { id: EntityId(row.get(0)?), name: row.get(1)?, description: row.get(2)?, config_id })
}

fn get_device(c: &Connection, id: EntityId) -> DbResult<Option<DeviceRecord>> {
    c.query_row("SELECT id,name,description,config_id FROM devices WHERE id=?1", [id.0], device_row).optional().map_err(StorageError::from)
}

fn get_device_config(c: &Connection, id: ConfigId) -> DbResult<Option<DeviceRecord>> {
    c.query_row("SELECT id,name,description,config_id FROM devices WHERE config_id=?1", [id.get()], device_row).optional().map_err(StorageError::from)
}

fn create_device(c: &mut Connection, op: OperationId, draft: DeviceDraft) -> DbResult<Mutation<DeviceRecord>> {
    if draft.name.is_empty() { return Err(invalid("device name is required".into())); }
    hardware_tx(c, op, move |tx| {
        let config = match draft.config_id { Some(id) => Some(id), None => Some(generate_config_id(tx)?) };
        tx.execute("INSERT INTO devices(name,description,config_id,inserted_at,updated_at) VALUES(?1,?2,?3,?4,?4)", params![draft.name, draft.description, config.map(ConfigId::get), timestamp()])?;
        get_device(tx, EntityId(tx.last_insert_rowid()))?.ok_or(StorageError::NotFound)
    })
}

fn generate_config_id(tx: &Transaction<'_>) -> DbResult<ConfigId> {
    // Randomness comes from the OS; uniqueness is rechecked by SQLite at commit.
    for _ in 0..1024 {
        let mut bytes = [0u8; 4];
        getrandom::fill(&mut bytes).map_err(|e| StorageError::InvalidHardware { detail: format!("operating-system random source failed: {e}") })?;
        let raw = u32::from_ne_bytes(bytes) % i32::MAX as u32 + 1;
        let id = ConfigId::new(raw).map_err(|e| invalid(e.into()))?;
        let exists: bool = tx.query_row("SELECT EXISTS(SELECT 1 FROM devices WHERE config_id=?1)", [id.get()], |r| r.get(0))?;
        if !exists { return Ok(id); }
    }
    Err(invalid("could not allocate a unique configuration ID".into()))
}

fn update_device(c: &mut Connection, op: OperationId, id: EntityId, patch: DevicePatch) -> DbResult<Mutation<DeviceRecord>> {
    hardware_tx(c, op, move |tx| {
        let current = get_device(tx, id)?.ok_or(StorageError::NotFound)?;
        let name = patch.name.unwrap_or(current.name.unwrap_or_default());
        if name.is_empty() { return Err(invalid("device name is required".into())); }
        let description = patch.description.unwrap_or(current.description);
        let config = match patch.config_id { Some(Some(id)) => Some(id), Some(None) => Some(generate_config_id(tx)?), None => current.config_id };
        tx.execute("UPDATE devices SET name=?1,description=?2,config_id=?3,updated_at=?4 WHERE id=?5", params![name, description, config.map(ConfigId::get), timestamp(), id.0])?;
        get_device(tx, id)?.ok_or(StorageError::NotFound)
    })
}

fn delete_device(c: &mut Connection, op: OperationId, id: EntityId) -> DbResult<Mutation<DeviceRecord>> {
    hardware_tx(c, op, move |tx| {
        let record = get_device(tx, id)?.ok_or(StorageError::NotFound)?;
        // Ecto performed explicit input/calibration deletes before device delete;
        // database cascades preserve matrices/outputs/modules and downstream bindings.
        tx.execute("DELETE FROM device_input_calibrations WHERE input_id IN (SELECT id FROM device_inputs WHERE device_id=?1)", [id.0])?;
        tx.execute("DELETE FROM device_inputs WHERE device_id=?1", [id.0])?;
        tx.execute("DELETE FROM devices WHERE id=?1", [id.0])?;
        Ok(record)
    })
}

fn get_calibration(c: &Connection, input: EntityId) -> DbResult<Option<CalibrationRow>> {
    c.query_row("SELECT id,input_id,max_hardware_value,min_value,max_value,has_rollover,is_inverted FROM device_input_calibrations WHERE input_id=?1 ORDER BY id LIMIT 1", [input.0], |r| Ok(CalibrationRow { id: EntityId(r.get(0)?), input_id: r.get::<_, Option<i64>>(1)?.map(EntityId), value: CalibrationRecord { max_hardware_value: r.get(2)?, min_value: r.get(3)?, max_value: r.get(4)?, has_rollover: r.get::<_, i64>(5)? != 0, is_inverted: r.get::<_, i64>(6)? != 0 } })).optional().map_err(StorageError::from)
}

fn input_row(c: &Connection, id: EntityId) -> DbResult<Option<InputRecord>> {
    let raw = c.query_row("SELECT id,pin,input_type,sensitivity,debounce,device_id,matrix_id,name FROM device_inputs WHERE id=?1", [id.0], |r| Ok((r.get::<_, i64>(0)?, r.get::<_, Option<i32>>(1)?, r.get::<_, Option<String>>(2)?, r.get::<_, Option<i32>>(3)?, r.get::<_, Option<i32>>(4)?, r.get::<_, Option<i64>>(5)?, r.get::<_, Option<i64>>(6)?, r.get::<_, Option<String>>(7)?))).optional()?;
    raw.map(|(id,pin,kind,sensitivity,debounce,device_id,matrix_id,name)| Ok(InputRecord { id: EntityId(id), pin, kind: kind.as_deref().map(InputKind::parse).transpose()?, sensitivity, debounce, device_id: device_id.map(EntityId), matrix_id: matrix_id.map(EntityId), name, calibration: get_calibration(c, EntityId(id))? })).transpose()
}

fn get_input(c: &Connection, id: EntityId) -> DbResult<Option<InputRecord>> { input_row(c, id) }

fn inputs_for_device_conn(c: &Connection, id: EntityId, include_virtual: bool) -> DbResult<Vec<InputRecord>> {
    let mut q = c.prepare(if include_virtual { "SELECT id FROM device_inputs WHERE device_id=?1 ORDER BY pin,id" } else { "SELECT id FROM device_inputs WHERE device_id=?1 AND matrix_id IS NULL ORDER BY pin,id" })?;
    let ids = q.query_map([id.0], |r| r.get::<_, i64>(0))?.collect::<Result<Vec<_>,_>>()?;
    ids.into_iter().map(|id| input_row(c, EntityId(id))?.ok_or(StorageError::NotFound)).collect()
}
fn inputs_for_device(c: &Connection, id: EntityId, include: bool) -> DbResult<Vec<InputRecord>> { inputs_for_device_conn(c,id,include) }

fn validate_input(d: &InputDraft, matrix: bool) -> DbResult<()> {
    if matrix { if !(128..256).contains(&d.pin) { return Err(invalid("matrix virtual pin must be between 128 and 255".into())); } }
    else if !(0..128).contains(&d.pin) { return Err(invalid("physical input pin must be between 0 and 127".into())); }
    match d.kind {
        InputKind::Analog if !matches!(d.sensitivity, Some(1..=10)) => return Err(invalid("analog sensitivity must be between 1 and 10".into())),
        InputKind::Button if !matches!(d.debounce, Some(0..=255)) => return Err(invalid("button debounce must be between 0 and 255".into())),
        _ => {}
    }
    Ok(())
}

fn write_input(tx: &Transaction<'_>, id: Option<EntityId>, device_id: EntityId, d: InputDraft) -> DbResult<InputRecord> {
    validate_input(&d, d.matrix_id.is_some())?;
    if let Some(matrix) = d.matrix_id {
        let owner: Option<i64> = tx.query_row("SELECT device_id FROM device_matrices WHERE id=?1", [matrix.0], |r| r.get(0)).optional()?;
        if owner != Some(device_id.0) { return Err(StorageError::ForeignKey { detail: "matrix does not belong to this device".into() }); }
    }
    let now = timestamp();
    let (sensitivity, debounce) = (d.sensitivity, d.debounce);
    if let Some(id) = id {
        tx.execute("UPDATE device_inputs SET pin=?1,input_type=?2,sensitivity=?3,debounce=?4,name=?5,matrix_id=?6,updated_at=?7 WHERE id=?8 AND device_id=?9", params![d.pin,d.kind.as_db(),sensitivity,debounce,d.name,d.matrix_id.map(|x|x.0),now,id.0,device_id.0])?;
        if tx.changes()==0 { return Err(StorageError::NotFound); }
        input_row(tx,id)?.ok_or(StorageError::NotFound)
    } else {
        tx.execute("INSERT INTO device_inputs(pin,input_type,sensitivity,debounce,name,device_id,matrix_id,inserted_at,updated_at) VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?8)", params![d.pin,d.kind.as_db(),sensitivity,debounce,d.name,device_id.0,d.matrix_id.map(|x|x.0),now])?;
        input_row(tx,EntityId(tx.last_insert_rowid()))?.ok_or(StorageError::NotFound)
    }
}
fn create_input(c:&mut Connection,op:OperationId,device:EntityId,d:InputDraft)->DbResult<Mutation<InputRecord>> { hardware_tx(c,op,move|tx| write_input(tx,None,device,d)) }
fn update_input(c:&mut Connection,op:OperationId,id:EntityId,d:InputDraft)->DbResult<Mutation<InputRecord>> { hardware_tx(c,op,move|tx| { let device=input_row(tx,id)?.and_then(|r|r.device_id).ok_or(StorageError::NotFound)?; write_input(tx,Some(id),device,d) }) }
fn delete_input(c:&mut Connection,op:OperationId,id:EntityId)->DbResult<Mutation<InputRecord>> { hardware_tx(c,op,move|tx| { let r=input_row(tx,id)?.ok_or(StorageError::NotFound)?; tx.execute("DELETE FROM device_input_calibrations WHERE input_id=?1",[id.0])?; tx.execute("DELETE FROM device_inputs WHERE id=?1",[id.0])?; Ok(r) }) }

fn get_output(c:&Connection,id:EntityId)->DbResult<Option<OutputRecord>> { c.query_row("SELECT id,pin,name,device_id FROM device_outputs WHERE id=?1",[id.0],|r|Ok(OutputRecord{id:EntityId(r.get(0)?),pin:r.get(1)?,name:r.get(2)?,device_id:EntityId(r.get(3)?)})).optional().map_err(StorageError::from) }
fn outputs_for_device_conn(c:&Connection,id:EntityId)->DbResult<Vec<OutputRecord>> { let mut q=c.prepare("SELECT id,pin,name,device_id FROM device_outputs WHERE device_id=?1 ORDER BY pin,id")?; q.query_map([id.0],|r|Ok(OutputRecord{id:EntityId(r.get(0)?),pin:r.get(1)?,name:r.get(2)?,device_id:EntityId(r.get(3)?)}))?.collect::<Result<Vec<_>,_>>().map_err(StorageError::from) }
fn outputs_for_device(c:&Connection,id:EntityId)->DbResult<Vec<OutputRecord>> { outputs_for_device_conn(c,id) }
fn write_output(tx:&Transaction<'_>,id:Option<EntityId>,device:EntityId,d:OutputDraft)->DbResult<OutputRecord>{
    if !(0..256).contains(&d.pin) {return Err(invalid("output pin must be between 0 and 255".into()));}
    if d.name.as_ref().is_some_and(|n|n.chars().count()>100){return Err(invalid("output name may not exceed 100 characters".into()));}
    let now=timestamp();
    if let Some(id)=id { tx.execute("UPDATE device_outputs SET pin=?1,name=?2,updated_at=?3 WHERE id=?4 AND device_id=?5",params![d.pin,d.name,now,id.0,device.0])?; if tx.changes()==0{return Err(StorageError::NotFound);} }
    else {tx.execute("INSERT INTO device_outputs(pin,name,device_id,inserted_at,updated_at) VALUES(?1,?2,?3,?4,?4)",params![d.pin,d.name,device.0,now])?;}
    get_output(tx,id.unwrap_or(EntityId(tx.last_insert_rowid())))?.ok_or(StorageError::NotFound)
}
fn create_output(c:&mut Connection,op:OperationId,device:EntityId,d:OutputDraft)->DbResult<Mutation<OutputRecord>>{hardware_tx(c,op,move|tx|write_output(tx,None,device,d))}
fn update_output(c:&mut Connection,op:OperationId,id:EntityId,d:OutputDraft)->DbResult<Mutation<OutputRecord>>{hardware_tx(c,op,move|tx|{let device=get_output(tx,id)?.ok_or(StorageError::NotFound)?.device_id;write_output(tx,Some(id),device,d)})}
fn delete_output(c:&mut Connection,op:OperationId,id:EntityId)->DbResult<Mutation<OutputRecord>>{hardware_tx(c,op,move|tx|{let r=get_output(tx,id)?.ok_or(StorageError::NotFound)?;tx.execute("DELETE FROM device_outputs WHERE id=?1",[id.0])?;Ok(r)})}

fn matrix_pins(c:&Connection,id:EntityId,kind:MatrixPinType)->DbResult<Vec<MatrixPinRecord>>{let mut q=c.prepare("SELECT id,pin,pin_type,position,matrix_id FROM device_input_matrix_pins WHERE matrix_id=?1 AND pin_type=?2 ORDER BY position,id")?;let rows=q.query_map(params![id.0,kind.as_db()],|r|Ok((r.get::<_,i64>(0)?,r.get::<_,i32>(1)?,r.get::<_,String>(2)?,r.get::<_,i32>(3)?,r.get::<_,i64>(4)?)))?;rows.map(|r|{let(id,pin,typ,pos,matrix)=r?;Ok(MatrixPinRecord{id:EntityId(id),pin,pin_type:if typ=="row"{MatrixPinType::Row}else if typ=="col"{MatrixPinType::Column}else{return Err(StorageError::InvalidHardware{detail:format!("unknown matrix pin_type {typ:?}")})},position:pos,matrix_id:EntityId(matrix)})}).collect()}
fn get_matrix(c:&Connection,id:EntityId)->DbResult<Option<MatrixRecord>>{let row=c.query_row("SELECT id,name,device_id FROM device_matrices WHERE id=?1",[id.0],|r|Ok((r.get::<_,i64>(0)?,r.get::<_,String>(1)?,r.get::<_,i64>(2)?))).optional()?;row.map(|(id,name,device)|Ok(MatrixRecord{id:EntityId(id),name,device_id:EntityId(device),row_pins:matrix_pins(c,EntityId(id),MatrixPinType::Row)?,col_pins:matrix_pins(c,EntityId(id),MatrixPinType::Column)?,buttons:inputs_for_device_conn(c,EntityId(device),true)?.into_iter().filter(|i|i.matrix_id==Some(EntityId(id))).collect()})).transpose()}
fn matrices_for_device_conn(c:&Connection,id:EntityId)->DbResult<Vec<MatrixRecord>>{let mut q=c.prepare("SELECT id FROM device_matrices WHERE device_id=?1 ORDER BY name,id")?;let ids=q.query_map([id.0],|r|r.get::<_,i64>(0))?.collect::<Result<Vec<_>,_>>()?;ids.into_iter().map(|id|get_matrix(c,EntityId(id))?.ok_or(StorageError::NotFound)).collect()}
fn matrices_for_device(c:&Connection,id:EntityId)->DbResult<Vec<MatrixRecord>>{matrices_for_device_conn(c,id)}
fn validate_matrix(name:&str,rows:&[i32],cols:&[i32])->DbResult<()>{if name.is_empty()||name.chars().count()>100{return Err(invalid("matrix name must contain 1 to 100 characters".into()));}for pins in [rows,cols]{if pins.iter().any(|p|!(0..128).contains(p)){return Err(invalid("matrix pins must be between 0 and 127".into()));}let mut seen=std::collections::HashSet::new();if pins.iter().any(|pin|!seen.insert(*pin)){return Err(invalid("matrix pin positions must not repeat a pin".into()));}}let cells=rows.len().checked_mul(cols.len()).ok_or_else(||invalid("matrix dimensions overflow".into()))?;if cells>128{return Err(invalid("matrix may not generate more than 128 virtual inputs".into()));}Ok(())}
fn replace_children(tx:&Transaction<'_>,matrix:EntityId,device:EntityId,rows:Vec<i32>,cols:Vec<i32>)->DbResult<()> {validate_matrix("x",&rows,&cols)?;tx.execute("DELETE FROM device_inputs WHERE matrix_id=?1",[matrix.0])?;tx.execute("DELETE FROM device_input_matrix_pins WHERE matrix_id=?1",[matrix.0])?;let now=timestamp();for(kind,pins)in[(MatrixPinType::Row,rows.clone()),(MatrixPinType::Column,cols.clone())]{for(position,pin)in pins.into_iter().enumerate(){tx.execute("INSERT INTO device_input_matrix_pins(pin,pin_type,position,matrix_id,inserted_at,updated_at) VALUES(?1,?2,?3,?4,?5,?5)",params![pin,kind.as_db(),position as i32,matrix.0,now])?;}}
    // Legacy generation is row-major: virtual_pin = 128 + row * num_cols + col.
    for row in 0..rows.len(){for col in 0..cols.len(){let pin=128+(row*cols.len()+col)as i32;let draft=InputDraft{pin,kind:InputKind::Button,sensitivity:None,debounce:Some(50),name:Some(format!("R{row}C{col}")),matrix_id:Some(matrix)};write_input(tx,None,device,draft)?;}}
    Ok(())}
fn create_matrix(c:&mut Connection,op:OperationId,device:EntityId,d:MatrixDraft)->DbResult<Mutation<MatrixRecord>>{hardware_tx(c,op,move|tx|{validate_matrix(&d.name,&d.row_pins,&d.col_pins)?;let now=timestamp();tx.execute("INSERT INTO device_matrices(name,device_id,inserted_at,updated_at) VALUES(?1,?2,?3,?3)",params![d.name,device.0,now])?;let id=EntityId(tx.last_insert_rowid());replace_children(tx,id,device,d.row_pins,d.col_pins)?;get_matrix(tx,id)?.ok_or(StorageError::NotFound)})}
fn replace_matrix_children(c:&mut Connection,op:OperationId,id:EntityId,rows:Vec<i32>,cols:Vec<i32>)->DbResult<Mutation<MatrixRecord>>{hardware_tx(c,op,move|tx|{let mut matrix=get_matrix(tx,id)?.ok_or(StorageError::NotFound)?;replace_children(tx,id,matrix.device_id,rows,cols)?;tx.execute("UPDATE device_matrices SET updated_at=?1 WHERE id=?2",params![timestamp(),id.0])?;matrix=get_matrix(tx,id)?.ok_or(StorageError::NotFound)?;Ok(matrix)})}
fn delete_matrix(c:&mut Connection,op:OperationId,id:EntityId)->DbResult<Mutation<MatrixRecord>>{hardware_tx(c,op,move|tx|{let matrix=get_matrix(tx,id)?.ok_or(StorageError::NotFound)?;tx.execute("DELETE FROM device_matrices WHERE id=?1",[id.0])?;Ok(matrix)})}

fn module_row(c:&Connection,id:EntityId)->DbResult<Option<I2cModuleRecord>>{let raw=c.query_row("SELECT id,device_id,name,module_chip,i2c_address,params FROM device_i2c_modules WHERE id=?1",[id.0],|r|Ok((r.get::<_,i64>(0)?,r.get::<_,i64>(1)?,r.get::<_,Option<String>>(2)?,r.get::<_,String>(3)?,r.get::<_,i32>(4)?,r.get::<_,Option<String>>(5)?))).optional()?;raw.map(|(id,device_id,name,module_chip,i2c_address,params)|{let params=params.map(|json|serde_json::from_str::<Ht16k33Params>(&json).map_err(|e|invalid(format!("invalid HT16K33 params JSON: {e}")))).transpose()?;Ok(I2cModuleRecord{id:EntityId(id),device_id:EntityId(device_id),name,module_chip,i2c_address,params})}).transpose()}
fn i2c_modules_for_device_conn(c:&Connection,id:EntityId)->DbResult<Vec<I2cModuleRecord>>{let mut q=c.prepare("SELECT id FROM device_i2c_modules WHERE device_id=?1 ORDER BY i2c_address,id")?;let ids=q.query_map([id.0],|r|r.get::<_,i64>(0))?.collect::<Result<Vec<_>,_>>()?;ids.into_iter().map(|id|module_row(c,EntityId(id))?.ok_or(StorageError::NotFound)).collect()}
fn i2c_modules_for_device(c:&Connection,id:EntityId)->DbResult<Vec<I2cModuleRecord>>{i2c_modules_for_device_conn(c,id)}
fn validate_module(d:&I2cModuleDraft)->DbResult<()>{if d.module_chip!="ht16k33"{return Err(invalid("unsupported I2C module chip".into()));}if !(0..=255).contains(&d.i2c_address){return Err(invalid("I2C address must be between 0 and 255".into()));}if d.name.as_ref().is_some_and(|n|n.chars().count()>100){return Err(invalid("I2C module name may not exceed 100 characters".into()));}let p=d.params.as_ref().ok_or_else(||invalid("HT16K33 params are required".into()))?;if !(0..=15).contains(&p.brightness)||![4,8].contains(&p.num_digits)||p.min_value.is_some_and(|x|!x.is_finite()){return Err(invalid("invalid HT16K33 params".into()));}Ok(())}
fn write_module(tx:&Transaction<'_>,id:Option<EntityId>,device:EntityId,d:I2cModuleDraft)->DbResult<I2cModuleRecord>{validate_module(&d)?;let json=serde_json::to_string(d.params.as_ref().unwrap()).map_err(|e|invalid(e.to_string()))?;let now=timestamp();if let Some(id)=id{tx.execute("UPDATE device_i2c_modules SET name=?1,module_chip=?2,i2c_address=?3,params=?4,updated_at=?5 WHERE id=?6 AND device_id=?7",params![d.name,d.module_chip,d.i2c_address,json,now,id.0,device.0])?;if tx.changes()==0{return Err(StorageError::NotFound);}}else{tx.execute("INSERT INTO device_i2c_modules(device_id,name,module_chip,i2c_address,params,inserted_at,updated_at) VALUES(?1,?2,?3,?4,?5,?6,?6)",params![device.0,d.name,d.module_chip,d.i2c_address,json,now])?;}module_row(tx,id.unwrap_or(EntityId(tx.last_insert_rowid())))?.ok_or(StorageError::NotFound)}
fn create_i2c_module(c:&mut Connection,op:OperationId,device:EntityId,d:I2cModuleDraft)->DbResult<Mutation<I2cModuleRecord>>{hardware_tx(c,op,move|tx|write_module(tx,None,device,d))}
fn update_i2c_module(c:&mut Connection,op:OperationId,id:EntityId,d:I2cModuleDraft)->DbResult<Mutation<I2cModuleRecord>>{hardware_tx(c,op,move|tx|{let device=module_row(tx,id)?.ok_or(StorageError::NotFound)?.device_id;write_module(tx,Some(id),device,d)})}
fn delete_i2c_module(c:&mut Connection,op:OperationId,id:EntityId)->DbResult<Mutation<I2cModuleRecord>>{hardware_tx(c,op,move|tx|{let r=module_row(tx,id)?.ok_or(StorageError::NotFound)?;tx.execute("DELETE FROM device_i2c_modules WHERE id=?1",[id.0])?;Ok(r)})}

fn save_calibration(c:&mut Connection,op:OperationId,input:EntityId,value:CalibrationRecord)->DbResult<Mutation<CalibrationRow>>{hardware_tx(c,op,move|tx|{let exists:bool=tx.query_row("SELECT EXISTS(SELECT 1 FROM device_inputs WHERE id=?1)",[input.0],|r|r.get(0))?;if !exists{return Err(StorageError::ForeignKey{detail:"input does not exist".into()});}let now=timestamp();tx.execute("INSERT INTO device_input_calibrations(input_id,max_hardware_value,min_value,max_value,has_rollover,is_inverted,inserted_at,updated_at) VALUES(?1,?2,?3,?4,?5,?6,?7,?7) ON CONFLICT(input_id) DO UPDATE SET max_hardware_value=excluded.max_hardware_value,min_value=excluded.min_value,max_value=excluded.max_value,has_rollover=excluded.has_rollover,is_inverted=excluded.is_inverted,updated_at=excluded.updated_at",params![input.0,value.max_hardware_value,value.min_value,value.max_value,value.has_rollover,value.is_inverted,now])?;get_calibration(tx,input)?.ok_or(StorageError::NotFound)})}

fn timestamp()->String {
    let seconds=std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs() as i64;
    let days=seconds.div_euclid(86_400);let rem=seconds.rem_euclid(86_400);let z=days+719_468;let era=if z>=0{z}else{z-146_096}/146_097;let doe=z-era*146_097;let yoe=(doe-doe/1_460+doe/36_524-doe/146_096)/365;let y=yoe+era*400;let doy=doe-(365*yoe+yoe/4-yoe/100);let mp=(5*doy+2)/153;let d=doy-(153*mp+2)/5+1;let m=mp+if mp<10{3}else{-9};let year=y+if m<=2{1}else{0};format!("{year:04}-{m:02}-{d:02}T{:02}:{:02}:{:02}Z",rem/3_600,(rem%3_600)/60,rem%60)
}
