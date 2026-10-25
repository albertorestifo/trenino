//! The vJoy lifecycle manager: persisted selected-device ownership with
//! acquire/neutralize/release transitions integrated with the shared resource
//! arbiter. Ported from `Trenino.VirtualJoystick.Manager` (states,
//! persist-after-confirmation, quarantine-and-retry) onto the adapter
//! contract; the Elixir configurator/bridge pair collapses into the single
//! [`VjoyAdapter`] acquire path.

use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use trenino_core::hardware::calibration::Calibration;
use trenino_core::{ConfigId, EntityId, OperationId};

use crate::resource::ResourceArbiter;
use crate::routing::{InputEvent, InputIdentity};
use crate::storage::Database;

use super::adapter::{
    neutral_axis_value, DeviceDescriptor, VjoyAdapter, VjoyDeviceStatus, VjoyError,
    REQUIRED_DESCRIPTOR,
};
use super::mapper::axis_value;
use super::store::{MappingDraft, MappingRecord, Target};

/// Lifecycle status. Mirrors the Elixir manager's status atoms; `needs_cleanup`
/// reports an unrequested-but-present selected device (leftover), and the
/// bridge-only `degraded` state does not apply because acquisition, reports and
/// release share one synchronous adapter.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum VjoyStatus {
    /// This platform cannot host vJoy; no adapter calls are ever made.
    Unsupported,
    /// Not requested and nothing acquired.
    Off,
    /// Acquire transition in progress.
    Enabling,
    /// Every selected device acquired and neutralized.
    Active,
    /// Release transition in progress.
    Disabling,
    /// Requested (persisted `enabled`) but a selected device is missing from
    /// the driver; an explicit retry re-attempts setup.
    NeedsSetup,
    /// Not requested, but a selected device exists unowned (leftover).
    NeedsCleanup,
    /// A requested and previously active device lost its native report path.
    Degraded,
    /// Terminal failure; an explicit retry clears quarantine and re-attempts.
    Error,
}

/// Whether one command may run in the current status. Ported from the Elixir
/// `transition_in_progress` guard; `unsupported` never transitions.
fn allows_transition(status: VjoyStatus) -> bool {
    !matches!(
        status,
        VjoyStatus::Enabling | VjoyStatus::Disabling | VjoyStatus::Unsupported
    )
}

struct ManagerInner<A: VjoyAdapter> {
    adapter: A,
    status: VjoyStatus,
    reason: Option<VjoyError>,
    /// Devices quarantined after a failed acquire, with the failure reason. A
    /// non-empty map blocks automatic re-enable; `retry` clears it.
    quarantined: BTreeMap<u8, VjoyError>,
    /// Devices currently acquired through the adapter.
    acquired: BTreeSet<u8>,
    selection: Vec<u8>,
    /// Mirrors the persisted `enabled` flag; the database remains authoritative.
    requested: bool,
    closing: bool,
    mappings: HashMap<EntityId, LiveMapping>,
    ports: HashMap<String, LivePort>,
    next_sample_sequence: u64,
    reported_from: HashMap<EntityId, String>,
    retry_attempt: usize,
    retry_deadline: Option<Instant>,
}

const RETRY_DELAYS_MS: [u64; 5] = [250, 500, 1_000, 2_000, 4_000];

#[derive(Clone)]
struct LiveMapping {
    record: MappingRecord,
    config_id: ConfigId,
    calibration: Option<Calibration>,
}

#[derive(Clone)]
struct LivePort {
    generation: u64,
    config_id: ConfigId,
    revoked: bool,
    suspended: bool,
    raw: HashMap<EntityId, RawSample>,
}

#[derive(Clone, Copy)]
struct RawSample {
    value: i16,
    sequence: u64,
}

impl LivePort {
    fn fresh(generation: u64, config_id: ConfigId) -> Self {
        Self {
            generation,
            config_id,
            revoked: false,
            suspended: false,
            raw: HashMap::new(),
        }
    }
}

/// Single owner of the vJoy devices selected in persistent storage. All
/// commands serialize on one lock; adapter calls happen under that lock, so
/// statuses observed between commands are deterministic.
pub struct VjoyManager<A: VjoyAdapter> {
    db: Database,
    arbiter: Arc<ResourceArbiter>,
    inner: Mutex<ManagerInner<A>>,
}

impl<A: VjoyAdapter> VjoyManager<A> {
    /// Build the manager and reconcile from persisted state, mirroring the
    /// Elixir `init/1` startup table:
    ///
    /// - unsupported platform → `Unsupported`, no adapter calls;
    /// - requested → acquire now (failures quarantine and land in
    ///   `Error`/`NeedsSetup` without clearing the persisted flag);
    /// - not requested → `Off`, unless a selected device exists unowned
    ///   (`NeedsCleanup`, leftover) or is busy/foreign-owned (`Error`).
    pub fn new(db: Database, arbiter: Arc<ResourceArbiter>, adapter: A) -> Self {
        let configuration = db.vjoy_configuration().ok().unwrap_or_default();
        let selection = db.vjoy_selected_devices().unwrap_or_default();
        let supported = adapter.supported();
        let mut inner = ManagerInner {
            adapter,
            status: VjoyStatus::Off,
            reason: None,
            quarantined: BTreeMap::new(),
            acquired: BTreeSet::new(),
            selection: selection.clone(),
            requested: configuration.enabled,
            closing: false,
            mappings: load_live_mappings(&db).unwrap_or_default(),
            ports: HashMap::new(),
            next_sample_sequence: 0,
            reported_from: HashMap::new(),
            retry_attempt: 0,
            retry_deadline: None,
        };
        if !supported {
            inner.status = VjoyStatus::Unsupported;
        } else if configuration.enabled {
            // Reconciliation failures mirror init: state records the outcome,
            // the persisted requested flag stays as committed.
            let _ = enable_locked(&db, &arbiter, &mut inner, false);
        } else {
            reconcile_not_requested(&mut inner);
        }
        Self {
            db,
            arbiter,
            inner: Mutex::new(inner),
        }
    }

    /// Fence new actuation/lifecycle admission before output cleanup starts.
    pub fn stop_admission(&self) {
        let mut inner = self.inner.lock().expect("vjoy manager poisoned");
        inner.closing = true;
        inner.retry_deadline = None;
    }

    /// Release native ownership without editing the user's enabled flag.
    /// Failed neutralizations retain their handles for acknowledged retry.
    pub fn release_runtime(&self) -> Result<(), VjoyError> {
        let mut inner = self.inner.lock().expect("vjoy manager poisoned");
        inner.closing = true;
        inner.retry_deadline = None;
        let mut failure = None;
        for device in inner.acquired.clone().into_iter().rev() {
            match inner.adapter.neutralize_device(device) {
                Ok(()) => {
                    inner.adapter.release_device(device);
                    inner.acquired.remove(&device);
                }
                Err(error) => {
                    failure = failure.or(Some(error));
                }
            }
        }
        if let Err(error) = inner.adapter.settle_configurator() {
            failure = failure.or(Some(error));
        }
        inner.reported_from.clear();
        if let Some(error) = failure {
            inner.status = VjoyStatus::Error;
            inner.reason = Some(error.clone());
            Err(error)
        } else {
            if inner.status != VjoyStatus::Unsupported {
                inner.status = VjoyStatus::Off;
            }
            inner.reason = None;
            Ok(())
        }
    }

    /// Current lifecycle status.
    pub fn status(&self) -> VjoyStatus {
        self.inner.lock().expect("vjoy manager poisoned").status
    }

    /// Status plus its last reason, mirroring `status_details/0`.
    pub fn status_details(&self) -> (VjoyStatus, Option<VjoyError>) {
        let inner = self.inner.lock().expect("vjoy manager poisoned");
        (inner.status, inner.reason.clone())
    }

    /// The persisted selected-device set (sorted ascending).
    pub fn selection(&self) -> Vec<u8> {
        self.inner
            .lock()
            .expect("vjoy manager poisoned")
            .selection
            .clone()
    }

    /// Devices quarantined after a failed acquire, with their reasons.
    pub fn quarantined(&self) -> BTreeMap<u8, VjoyError> {
        self.inner
            .lock()
            .expect("vjoy manager poisoned")
            .quarantined
            .clone()
    }

    /// Persist a new selected-device set. Refused while `Active`: ownership
    /// changes must go through disable/enable so every release is neutralized
    /// and confirmed rather than partially re-acquired mid-flight.
    pub fn set_selection(
        &self,
        operation_id: OperationId,
        devices: &[u8],
    ) -> Result<Vec<u8>, VjoyError> {
        let mut inner = self.inner.lock().expect("vjoy manager poisoned");
        if inner.closing {
            return Err(VjoyError::InvalidState("runtime shutting down"));
        }
        if inner.status == VjoyStatus::Active {
            return Err(VjoyError::InvalidState(
                "selection cannot change while active",
            ));
        }
        let mutation = self.db.vjoy_set_selected_devices(operation_id, devices)?;
        inner.selection = mutation.record.clone();
        if !inner.requested {
            reconcile_not_requested(&mut inner);
        }
        Ok(mutation.record)
    }

    /// Acquire every selected device, validate descriptors, apply the initial
    /// neutral report and only then persist `enabled = true`. Idempotent when
    /// already active; refused while a calibration/firmware lease is held on
    /// the shared arbiter, while a transition runs, or while a failed acquire
    /// left a device quarantined (use [`Self::retry`]).
    pub fn enable(&self) -> Result<(), VjoyError> {
        let mut inner = self.inner.lock().expect("vjoy manager poisoned");
        if inner.closing {
            return Err(VjoyError::InvalidState("runtime shutting down"));
        }
        if inner.status == VjoyStatus::Active {
            return Ok(());
        }
        inner.selection = self.db.vjoy_selected_devices()?;
        enable_locked(&self.db, &self.arbiter, &mut inner, true)?;
        if let Err(error) = publish_current_state(&mut inner) {
            runtime_loss(&mut inner, error.clone());
            return Err(error);
        }
        Ok(())
    }

    /// Neutralize and release every acquired device (reverse order), then
    /// persist `enabled = false` only after the releases completed. Idempotent
    /// when already off; clears quarantine like the Elixir `cancel_retry`.
    pub fn disable(&self) -> Result<(), VjoyError> {
        let mut inner = self.inner.lock().expect("vjoy manager poisoned");
        if inner.closing {
            return Err(VjoyError::InvalidState("runtime shutting down"));
        }
        if inner.status == VjoyStatus::Off {
            inner.quarantined.clear();
            inner.retry_deadline = None;
            inner.retry_attempt = 0;
            return Ok(());
        }
        if !inner.adapter.supported() {
            return Err(VjoyError::Unsupported);
        }
        if !allows_transition(inner.status) {
            return Err(VjoyError::InvalidState("transition_in_progress"));
        }
        inner.status = VjoyStatus::Disabling;
        inner.reason = None;
        // The SDK cannot report release failure, so a neutralization error is
        // carried as the command result while the release still proceeds —
        // the Elixir `stop_bridge_safely` ignores reset failures the same way.
        let released = release_all(&mut inner);
        inner.quarantined.clear();
        inner.ports.clear();
        inner.reported_from.clear();
        inner.retry_deadline = None;
        inner.retry_attempt = 0;
        // A native installation created by Trenino belongs to this selection
        // only. Never remove a foreign or busy device, or another selected ID.
        let cleanup = if released.is_ok() {
            cleanup_selected(&mut inner)
        } else {
            Ok(())
        };
        if let Err(error) = cleanup {
            inner.status = VjoyStatus::Error;
            inner.reason = Some(error.clone());
            return Err(error);
        }
        match self.db.vjoy_confirm_enabled(OperationId(0), false) {
            Ok(_) => {
                inner.requested = false;
                match released {
                    Ok(()) => {
                        inner.status = VjoyStatus::Off;
                        inner.reason = None;
                        Ok(())
                    }
                    Err(error) => {
                        inner.status = VjoyStatus::Error;
                        inner.reason = Some(error.clone());
                        Err(error)
                    }
                }
            }
            Err(error) => {
                inner.status = VjoyStatus::Error;
                let error = VjoyError::Storage(error.to_string());
                inner.reason = Some(error.clone());
                Err(released.err().unwrap_or(error))
            }
        }
    }

    /// Explicit retry: clears quarantine and re-attempts the acquire path.
    /// Valid from `NeedsSetup` and `Error` (Elixir: retry starts setup from
    /// `needs_setup` and restarts the bridge from `degraded`/`error`).
    pub fn retry(&self) -> Result<(), VjoyError> {
        let mut inner = self.inner.lock().expect("vjoy manager poisoned");
        if inner.closing {
            return Err(VjoyError::InvalidState("runtime shutting down"));
        }
        if !matches!(
            inner.status,
            VjoyStatus::NeedsSetup | VjoyStatus::Error | VjoyStatus::Degraded
        ) {
            return Err(VjoyError::InvalidState(
                "retry requires needs_setup or error",
            ));
        }
        inner.quarantined.clear();
        inner.reason = None;
        inner.retry_deadline = None;
        inner.retry_attempt = 0;
        inner.selection = self.db.vjoy_selected_devices()?;
        enable_locked(&self.db, &self.arbiter, &mut inner, true)?;
        if let Err(error) = publish_current_state(&mut inner) {
            runtime_loss(&mut inner, error.clone());
            return Err(error);
        }
        Ok(())
    }

    /// Recheck a failed installation without implicitly changing persisted
    /// requested state. For requested devices, a healthy installation can
    /// reacquire; unrequested devices remain unowned.
    pub fn repair(&self) -> Result<(), VjoyError> {
        let mut inner = self.inner.lock().expect("vjoy manager poisoned");
        if inner.closing {
            return Err(VjoyError::InvalidState("runtime shutting down"));
        }
        if inner.status != VjoyStatus::Error {
            return Err(VjoyError::InvalidState("repair requires error"));
        }
        inner.quarantined.clear();
        inner.retry_deadline = None;
        inner.retry_attempt = 0;
        if inner.requested {
            enable_locked(&self.db, &self.arbiter, &mut inner, true)?;
            if let Err(error) = publish_current_state(&mut inner) {
                runtime_loss(&mut inner, error.clone());
                return Err(error);
            }
        } else {
            reconcile_not_requested(&mut inner);
        }
        Ok(())
    }

    /// Remove only selected, Trenino-owned leftovers after a prior shutdown.
    /// A foreign or busy selected device is never passed to the configurator.
    pub fn remove_leftover(&self) -> Result<(), VjoyError> {
        let mut inner = self.inner.lock().expect("vjoy manager poisoned");
        if inner.closing {
            return Err(VjoyError::InvalidState("runtime shutting down"));
        }
        if inner.status != VjoyStatus::NeedsCleanup || inner.requested {
            return Err(VjoyError::InvalidState(
                "remove_leftover requires needs_cleanup",
            ));
        }
        inner.status = VjoyStatus::Disabling;
        if let Err(error) = cleanup_selected(&mut inner) {
            inner.status = VjoyStatus::Error;
            inner.reason = Some(error.clone());
            return Err(error);
        }
        reconcile_not_requested(&mut inner);
        Ok(())
    }

    /// Current mappings (the Elixir `reload_mappings` read path).
    pub fn mappings(&self) -> Result<Vec<MappingRecord>, VjoyError> {
        Ok(self.db.vjoy_list_mappings()?)
    }

    /// When an external runtime pump should next call `poll_recovery_at`.
    pub fn next_retry_deadline(&self) -> Option<Instant> {
        self.inner
            .lock()
            .expect("vjoy manager poisoned")
            .retry_deadline
    }

    /// The Elixir bounded backoff step currently scheduled, if any.
    pub fn next_retry_delay(&self) -> Option<Duration> {
        let inner = self.inner.lock().expect("vjoy manager poisoned");
        inner
            .retry_deadline
            .map(|_| Duration::from_millis(RETRY_DELAYS_MS[inner.retry_attempt]))
    }

    /// Run one due recovery attempt. The caller supplies time for deterministic
    /// tests and must schedule calls at `next_retry_deadline` in production.
    pub fn poll_recovery_at(&self, now: Instant) -> Result<bool, VjoyError> {
        let mut inner = self.inner.lock().expect("vjoy manager poisoned");
        if inner.closing {
            return Err(VjoyError::InvalidState("runtime shutting down"));
        }
        let Some(deadline) = inner.retry_deadline else {
            return Ok(false);
        };
        if now < deadline {
            return Ok(false);
        }
        inner.retry_deadline = None;
        inner.retry_attempt += 1;
        inner.quarantined.clear();
        let result = enable_locked(&self.db, &self.arbiter, &mut inner, false)
            .and_then(|()| publish_current_state(&mut inner));
        match result {
            Ok(()) => {
                inner.retry_attempt = 0;
                inner.reason = None;
                Ok(true)
            }
            Err(error) => {
                let _ = release_all(&mut inner);
                inner.reason = Some(error.clone());
                schedule_retry(&mut inner, now);
                Err(error)
            }
        }
    }

    /// Accept a hardware-service resolved, generation-fenced input sample.
    /// The input identity and persisted configuration are checked again here
    /// so a stale or mismatched caller cannot drive an unrelated target.
    pub fn input_value(
        &self,
        port: &str,
        identity: InputIdentity,
        event: InputEvent,
    ) -> Result<(), VjoyError> {
        let mut inner = self.inner.lock().expect("vjoy manager poisoned");
        if inner.closing {
            return Ok(());
        }
        let mapping = inner.mappings.get(&identity.input_id).cloned();
        if mapping.as_ref().is_some_and(|mapping| {
            mapping.record.input_device != Some(identity.device_id)
                || mapping.config_id != event.config_id
                || mapping.record.input_pin != Some(i32::from(event.pin))
        }) {
            return Ok(());
        }
        let leased = self.arbiter.is_suspended();
        if !upsert_port(
            &mut inner,
            port,
            event.port_generation,
            event.config_id,
            !leased,
        )? {
            return Ok(());
        }
        inner.next_sample_sequence = inner.next_sample_sequence.saturating_add(1);
        let sequence = inner.next_sample_sequence;
        let state = inner.ports.get_mut(port).expect("port was accepted above");
        state.raw.insert(
            identity.input_id,
            RawSample {
                value: event.value,
                sequence,
            },
        );
        if !leased {
            state.suspended = false;
        }
        if inner.status == VjoyStatus::Active && !leased {
            if let Some(mapping) = mapping {
                if !inner.acquired.contains(&mapping.record.device_index) {
                    return Ok(());
                }
                if let Err(error) = send_mapping(&mut inner.adapter, &mapping, event.value) {
                    runtime_loss(&mut inner, error.clone());
                    return Err(error);
                }
                inner
                    .reported_from
                    .insert(identity.input_id, port.to_owned());
            }
        }
        Ok(())
    }

    /// Seed current samples on a connected generation, including while off.
    /// A subsequent activation publishes these samples; unseeded mappings on
    /// the port receive safe reports.
    pub fn seed_port(
        &self,
        port: &str,
        generation: u64,
        config_id: ConfigId,
        samples: &[(InputIdentity, u8, i16)],
    ) -> Result<(), VjoyError> {
        self.observe_port(port, generation, config_id)?;
        for (identity, pin, value) in samples {
            self.input_value(
                port,
                *identity,
                InputEvent {
                    port_generation: generation,
                    config_id,
                    pin: *pin,
                    value: *value,
                },
            )?;
        }
        Ok(())
    }

    pub fn observe_port(
        &self,
        port: &str,
        generation: u64,
        config_id: ConfigId,
    ) -> Result<(), VjoyError> {
        let mut inner = self.inner.lock().expect("vjoy manager poisoned");
        upsert_port(
            &mut inner,
            port,
            generation,
            config_id,
            !self.arbiter.is_suspended(),
        )?;
        Ok(())
    }

    /// Revoke only the current port generation and neutralize its mapped
    /// targets. Reports from other ports remain untouched.
    pub fn source_lost(&self, port: &str, generation: u64) -> Result<(), VjoyError> {
        let mut inner = self.inner.lock().expect("vjoy manager poisoned");
        let Some(state) = inner.ports.get_mut(port) else {
            return Ok(());
        };
        if state.generation != generation || state.revoked {
            return Ok(());
        }
        state.revoked = true;
        let config_id = state.config_id;
        state.raw.clear();
        neutralize_port_outputs(&mut inner, port, config_id, !self.arbiter.is_suspended())
    }

    /// Neutralize mapped targets for a temporarily suspended port without
    /// revoking its generation; a fresh sample may resume that generation.
    pub fn suspend_port(&self, port: &str) -> Result<(), VjoyError> {
        let mut inner = self.inner.lock().expect("vjoy manager poisoned");
        let Some(config_id) = inner.ports.get_mut(port).filter(|p| !p.revoked).map(|p| {
            p.suspended = true;
            p.config_id
        }) else {
            return Ok(());
        };
        neutralize_port_outputs(&mut inner, port, config_id, !self.arbiter.is_suspended())
    }

    /// Refresh the one authoritative mapping snapshot after DB mutation or
    /// hardware reconfiguration. Active targets are republished immediately.
    pub fn reload_mappings(&self) -> Result<(), VjoyError> {
        let mappings = load_live_mappings(&self.db)?;
        let mut inner = self.inner.lock().expect("vjoy manager poisoned");
        if inner.closing {
            return Err(VjoyError::InvalidState("runtime shutting down"));
        }
        let removed: Vec<LiveMapping> = inner
            .mappings
            .values()
            .filter(|old| {
                !mappings.values().any(|new| {
                    new.record.device_index == old.record.device_index
                        && new.record.target == old.record.target
                })
            })
            .cloned()
            .collect();
        // The database commit is authoritative even if a native safe report
        // fails. Recovery must never replay a deleted route.
        inner.mappings = mappings;
        let retained_ids: BTreeSet<EntityId> = inner.mappings.keys().copied().collect();
        inner
            .reported_from
            .retain(|id, _| retained_ids.contains(id));
        if inner.status == VjoyStatus::Active {
            for mapping in removed {
                if inner.acquired.contains(&mapping.record.device_index) {
                    if let Err(error) = send_safe_mapping(&mut inner.adapter, &mapping) {
                        runtime_loss(&mut inner, error.clone());
                        return Err(error);
                    }
                }
            }
        }
        if self.arbiter.is_suspended() {
            for port in inner.ports.values_mut() {
                port.suspended = true;
            }
            return Ok(());
        }
        if inner.status == VjoyStatus::Active {
            if let Err(error) = publish_current_state(&mut inner) {
                runtime_loss(&mut inner, error.clone());
                return Err(error);
            }
        }
        Ok(())
    }

    /// Reapply the neutral report to every acquired device. Hook for the
    /// shared arbiter's consumer chain: when a calibration/firmware lease
    /// suspends actuation, the compositor calls this so no held control keeps
    /// driving the virtual device while the port is owned elsewhere.
    pub fn neutralize_outputs(&self) -> Result<(), VjoyError> {
        let mut inner = self.inner.lock().expect("vjoy manager poisoned");
        if inner.status != VjoyStatus::Active {
            return Ok(());
        }
        for port in inner.ports.values_mut() {
            port.suspended = true;
        }
        let devices: Vec<u8> = inner.acquired.iter().copied().collect();
        let mut failure = None;
        for device in devices {
            if let Err(error) = inner.adapter.neutralize_device(device) {
                failure = failure.or(Some(error));
            }
        }
        failure.map_or(Ok(()), Err)
    }

    /// Insert or update a mapping through the persistence contract; see
    /// [`Database::vjoy_put_mapping`].
    pub fn put_mapping(
        &self,
        operation_id: OperationId,
        input_id: EntityId,
        draft: MappingDraft,
        replace: bool,
    ) -> Result<MappingRecord, VjoyError> {
        if self.inner.lock().expect("vjoy manager poisoned").closing {
            return Err(VjoyError::InvalidState("runtime shutting down"));
        }
        let record = self
            .db
            .vjoy_put_mapping(operation_id, input_id, draft, replace)?
            .record;
        self.reload_mappings()?;
        Ok(record)
    }
}

fn upsert_port<A: VjoyAdapter>(
    inner: &mut ManagerInner<A>,
    port: &str,
    generation: u64,
    config_id: ConfigId,
    allow_live: bool,
) -> Result<bool, VjoyError> {
    match inner.ports.get(port) {
        Some(state)
            if generation < state.generation
                || (generation == state.generation && state.revoked) =>
        {
            return Ok(false)
        }
        Some(state) if generation > state.generation || config_id != state.config_id => {
            let old_config = state.config_id;
            inner
                .ports
                .insert(port.to_owned(), LivePort::fresh(generation, config_id));
            neutralize_port_outputs(inner, port, old_config, allow_live)?;
        }
        None => {
            inner
                .ports
                .insert(port.to_owned(), LivePort::fresh(generation, config_id));
        }
        _ => {}
    }
    Ok(true)
}

fn neutralize_port_outputs<A: VjoyAdapter>(
    inner: &mut ManagerInner<A>,
    port: &str,
    config_id: ConfigId,
    allow_live: bool,
) -> Result<(), VjoyError> {
    if inner.status != VjoyStatus::Active {
        return Ok(());
    }
    let mappings: Vec<LiveMapping> = inner
        .mappings
        .values()
        .filter(|m| m.config_id == config_id && inner.acquired.contains(&m.record.device_index))
        .cloned()
        .collect();
    for mapping in mappings {
        let id = mapping.record.input_id;
        if inner
            .reported_from
            .get(&id)
            .is_some_and(|supplier| supplier != port)
        {
            continue;
        }
        let survivor = if allow_live {
            latest_sample(inner, &mapping, Some(port))
        } else {
            None
        };
        let result = match &survivor {
            Some((_, raw)) => send_mapping(&mut inner.adapter, &mapping, *raw),
            None => send_safe_mapping(&mut inner.adapter, &mapping),
        };
        if let Err(error) = result {
            runtime_loss(inner, error.clone());
            return Err(error);
        }
        match survivor {
            Some((supplier, _)) => {
                inner.reported_from.insert(id, supplier);
            }
            None => {
                inner.reported_from.remove(&id);
            }
        }
    }
    Ok(())
}

fn load_live_mappings(db: &Database) -> Result<HashMap<EntityId, LiveMapping>, VjoyError> {
    let mut result = HashMap::new();
    for record in db.vjoy_list_mappings()? {
        let Some(input) = db.get_input(record.input_id)? else {
            continue;
        };
        let Some(device_id) = input.device_id else {
            continue;
        };
        let Some(device) = db.get_device(device_id)? else {
            continue;
        };
        let Some(config_id) = device.config_id else {
            continue;
        };
        let calibration = input.calibration.and_then(|row| {
            let c = row.value;
            Some(Calibration {
                min_value: c.min_value?,
                max_value: c.max_value?,
                max_hardware_value: c.max_hardware_value?,
                inverted: c.is_inverted,
                rollover: c.has_rollover,
            })
        });
        result.insert(
            record.input_id,
            LiveMapping {
                record,
                config_id,
                calibration,
            },
        );
    }
    Ok(result)
}

fn send_mapping<A: VjoyAdapter>(
    adapter: &mut A,
    mapping: &LiveMapping,
    raw: i16,
) -> Result<(), VjoyError> {
    let device = mapping.record.device_index;
    match mapping.record.target {
        Target::Axis(axis) => {
            let range = adapter.axis_range(device, axis)?;
            if let Ok(value) = axis_value(
                i32::from(raw),
                mapping.calibration.as_ref(),
                mapping.record.inverted,
                range,
            ) {
                adapter.set_axis(device, axis, value)?;
            }
        }
        Target::Button(button) => adapter.set_button(device, button, raw != 0)?,
    }
    Ok(())
}

fn send_safe_mapping<A: VjoyAdapter>(
    adapter: &mut A,
    mapping: &LiveMapping,
) -> Result<(), VjoyError> {
    let device = mapping.record.device_index;
    match mapping.record.target {
        Target::Axis(axis) => {
            let (min, max) = adapter.axis_range(device, axis)?;
            adapter.set_axis(device, axis, neutral_axis_value(min, max))
        }
        Target::Button(button) => adapter.set_button(device, button, false),
    }
}

fn publish_current_state<A: VjoyAdapter>(inner: &mut ManagerInner<A>) -> Result<(), VjoyError> {
    let mappings: Vec<LiveMapping> = inner.mappings.values().cloned().collect();
    for mapping in mappings {
        if !inner.acquired.contains(&mapping.record.device_index) {
            continue;
        }
        let source = latest_sample(inner, &mapping, None);
        match source {
            Some((port, raw)) => {
                send_mapping(&mut inner.adapter, &mapping, raw)?;
                inner.reported_from.insert(mapping.record.input_id, port);
            }
            None => {
                send_safe_mapping(&mut inner.adapter, &mapping)?;
                inner.reported_from.remove(&mapping.record.input_id);
            }
        }
    }
    Ok(())
}

fn latest_sample<A: VjoyAdapter>(
    inner: &ManagerInner<A>,
    mapping: &LiveMapping,
    excluding: Option<&str>,
) -> Option<(String, i16)> {
    inner
        .ports
        .iter()
        .filter(|(port, state)| {
            excluding != Some(port.as_str())
                && !state.revoked
                && !state.suspended
                && state.config_id == mapping.config_id
        })
        .filter_map(|(port, state)| {
            state
                .raw
                .get(&mapping.record.input_id)
                .map(|sample| (port.clone(), *sample))
        })
        .max_by_key(|(_, sample)| sample.sequence)
        .map(|(port, sample)| (port, sample.value))
}

fn runtime_loss<A: VjoyAdapter>(inner: &mut ManagerInner<A>, error: VjoyError) {
    let _ = release_all(inner);
    inner.reason = Some(error);
    inner.retry_attempt = 0;
    schedule_retry(inner, Instant::now());
}

fn schedule_retry<A: VjoyAdapter>(inner: &mut ManagerInner<A>, now: Instant) {
    if inner.requested && inner.retry_attempt < RETRY_DELAYS_MS.len() {
        inner.status = VjoyStatus::Degraded;
        inner.retry_deadline =
            Some(now + Duration::from_millis(RETRY_DELAYS_MS[inner.retry_attempt]));
    } else {
        inner.status = VjoyStatus::Error;
        inner.retry_deadline = None;
    }
}

impl<A: VjoyAdapter> Drop for VjoyManager<A> {
    /// Mirror the Elixir `terminate/2`: neutralize and release what we own
    /// without deleting driver devices. Persistence is untouched — the
    /// requested flag stays as last confirmed.
    fn drop(&mut self) {
        let mut inner = self.inner.lock().expect("vjoy manager poisoned");
        if inner.status == VjoyStatus::Unsupported {
            return;
        }
        let _ = release_all(&mut inner);
    }
}

/// Startup reconciliation for the not-requested branch of the Elixir table:
/// all missing → `Off`; any free → `NeedsCleanup` (leftover); busy/owned or
/// driver failure → `Error`.
fn reconcile_not_requested<A: VjoyAdapter>(inner: &mut ManagerInner<A>) {
    if let Err(error) = inner.adapter.driver_available() {
        inner.status = VjoyStatus::Error;
        inner.reason = Some(error);
        return;
    }
    let mut leftover = false;
    for device in inner.selection.clone() {
        match inner.adapter.device_status(device) {
            Ok(VjoyDeviceStatus::Busy) | Ok(VjoyDeviceStatus::Owned) => {
                inner.status = VjoyStatus::Error;
                inner.reason = Some(VjoyError::DeviceBusy(device));
                return;
            }
            Ok(VjoyDeviceStatus::Free) => match inner.adapter.ownership_marker(device) {
                Ok(true) => leftover = true,
                Ok(false) => match inner.adapter.creation_confirmed_marker(device) {
                    Ok(true) => leftover = true,
                    Ok(false) => {}
                    Err(error) => {
                        inner.status = VjoyStatus::Error;
                        inner.reason = Some(error);
                        return;
                    }
                },
                Err(error) => {
                    inner.status = VjoyStatus::Error;
                    inner.reason = Some(error);
                    return;
                }
            },
            Ok(VjoyDeviceStatus::Missing) => match inner.adapter.ownership_marker(device) {
                Ok(true) => leftover = true,
                Ok(false) => match inner.adapter.creation_confirmed_marker(device) {
                    Ok(true) => leftover = true,
                    Ok(false) => {}
                    Err(error) => {
                        inner.status = VjoyStatus::Error;
                        inner.reason = Some(error);
                        return;
                    }
                },
                Err(error) => {
                    inner.status = VjoyStatus::Error;
                    inner.reason = Some(error);
                    return;
                }
            },
            Ok(VjoyDeviceStatus::Unknown) => {}
            Err(error) => {
                inner.status = VjoyStatus::Error;
                inner.reason = Some(error);
                return;
            }
        }
    }
    if leftover {
        inner.status = VjoyStatus::NeedsCleanup;
        inner.reason = None;
    } else {
        inner.status = VjoyStatus::Off;
        inner.reason = None;
    }
}

/// The acquire transition shared by `enable`, `retry` and startup
/// reconciliation. On any failure every already-acquired device is neutralized
/// and released (reverse order) before the error surfaces; a failed acquire
/// additionally quarantines that device so nothing re-attempts it implicitly.
fn enable_locked<A: VjoyAdapter>(
    db: &Database,
    arbiter: &ResourceArbiter,
    inner: &mut ManagerInner<A>,
    allow_setup: bool,
) -> Result<(), VjoyError> {
    if !inner.adapter.supported() {
        return Err(VjoyError::Unsupported);
    }
    if !allows_transition(inner.status) {
        return Err(VjoyError::InvalidState(match inner.status {
            VjoyStatus::Enabling | VjoyStatus::Disabling => "transition_in_progress",
            _ => "unsupported",
        }));
    }
    if let Some((device, reason)) = inner.quarantined.iter().next() {
        return Err(VjoyError::Quarantined(*device, reason.to_string()));
    }
    if arbiter.is_suspended() {
        inner.reason = Some(VjoyError::ArbiterBusy);
        return Err(VjoyError::ArbiterBusy);
    }
    if let Err(error) = inner.adapter.driver_available() {
        inner.status = VjoyStatus::Error;
        inner.reason = Some(error.clone());
        return Err(error);
    }
    inner.status = VjoyStatus::Enabling;
    inner.reason = None;

    if let Err(error) = acquire_selection(inner, allow_setup) {
        // Rollback already happened inside acquire_selection; classify status.
        inner.status = match &error {
            VjoyError::DeviceMissing(_) => VjoyStatus::NeedsSetup,
            _ => VjoyStatus::Error,
        };
        inner.reason = Some(error.clone());
        return Err(error);
    }

    let persisted = if inner.requested {
        Ok(())
    } else {
        db.vjoy_confirm_enabled(OperationId(0), true).map(|_| ())
    };
    match persisted {
        Ok(_) => {
            inner.requested = true;
            inner.status = VjoyStatus::Active;
            inner.reason = None;
            Ok(())
        }
        Err(error) => {
            let _ = release_all(inner);
            let error = VjoyError::Storage(error.to_string());
            inner.status = VjoyStatus::Error;
            inner.reason = Some(error.clone());
            Err(error)
        }
    }
}

/// Acquire each selected device in ascending order. On failure, roll back every
/// acquisition so far (neutralize, then release, reverse order). Only acquire
/// failures quarantine their device.
fn acquire_selection<A: VjoyAdapter>(
    inner: &mut ManagerInner<A>,
    allow_setup: bool,
) -> Result<(), VjoyError> {
    for device in inner.selection.clone() {
        match inner.adapter.device_status(device) {
            // Owned is either ours (acquire below is idempotent) or foreign
            // (acquire fails); Free proceeds; anything else refuses so an
            // unowned device is never acquired blindly.
            Ok(VjoyDeviceStatus::Owned) | Ok(VjoyDeviceStatus::Free) => {
                if inner.adapter.can_configure()
                    && !match inner.adapter.ownership_marker(device) {
                        Ok(marked) => marked,
                        Err(error) => return Err(rollback_with_error(inner, error)),
                    }
                {
                    let confirmed = match inner.adapter.creation_confirmed_marker(device) {
                        Ok(confirmed) => confirmed,
                        Err(error) => return Err(rollback_with_error(inner, error)),
                    };
                    if confirmed && allow_setup {
                        if let Err(error) = inner.adapter.configure_create(device) {
                            let _ = release_all(inner);
                            return Err(error);
                        }
                    } else {
                        let _ = release_all(inner);
                        return Err(VjoyError::Configurator(
                            super::configurator::ConfiguratorError::ForeignDevice,
                        ));
                    }
                }
            }
            Ok(VjoyDeviceStatus::Busy) => {
                let _ = release_all(inner);
                return Err(VjoyError::DeviceBusy(device));
            }
            Ok(VjoyDeviceStatus::Missing) => {
                if !allow_setup || !inner.adapter.can_configure() {
                    let _ = release_all(inner);
                    return Err(VjoyError::DeviceMissing(device));
                }
                if let Err(error) = inner.adapter.configure_create(device) {
                    let _ = release_all(inner);
                    return Err(error);
                }
                let observed = inner.adapter.device_status(device);
                if !matches!(observed, Ok(VjoyDeviceStatus::Free)) {
                    let _ = release_all(inner);
                    return Err(observed.err().unwrap_or(VjoyError::DeviceMissing(device)));
                }
            }
            Ok(VjoyDeviceStatus::Unknown) => {
                let _ = release_all(inner);
                return Err(VjoyError::DeviceBusy(device));
            }
            Err(error) => {
                let _ = release_all(inner);
                return Err(error);
            }
        }
        match check_descriptor(&mut inner.adapter, device) {
            Ok(()) => {}
            Err(error) => {
                let _ = release_all(inner);
                return Err(error);
            }
        }
        match inner.adapter.acquire_device(device) {
            Ok(()) => {
                inner.acquired.insert(device);
            }
            Err(error) => {
                let _ = release_all(inner);
                inner.quarantined.insert(device, error.clone());
                return Err(error);
            }
        }
        if let Err(error) = inner.adapter.neutralize_device(device) {
            inner.acquired.remove(&device);
            inner.adapter.release_device(device);
            let _ = release_all(inner);
            return Err(error);
        }
    }
    Ok(())
}

fn cleanup_selected<A: VjoyAdapter>(inner: &mut ManagerInner<A>) -> Result<(), VjoyError> {
    if !inner.adapter.can_configure() {
        return Ok(());
    }
    let mut owned = Vec::new();
    let mut recover = Vec::new();
    for device in inner.selection.clone() {
        let marked = inner.adapter.ownership_marker(device)?;
        let confirmed = inner.adapter.creation_confirmed_marker(device)?;
        match inner.adapter.device_status(device)? {
            VjoyDeviceStatus::Free => {
                if marked {
                    owned.push(device);
                } else if confirmed {
                    recover.push(device);
                    owned.push(device);
                } else {
                    return Err(VjoyError::Configurator(
                        super::configurator::ConfiguratorError::ForeignDevice,
                    ));
                }
            }
            VjoyDeviceStatus::Missing => {
                if marked || confirmed {
                    owned.push(device);
                }
            }
            VjoyDeviceStatus::Busy | VjoyDeviceStatus::Owned | VjoyDeviceStatus::Unknown => {
                return Err(VjoyError::DeviceBusy(device));
            }
        }
    }
    for device in recover {
        inner.adapter.configure_create(device)?;
    }
    for device in owned {
        inner.adapter.configure_delete(device)?;
    }
    Ok(())
}

/// Descriptor gate: facts must equal [`REQUIRED_DESCRIPTOR`] before any
/// acquisition, mirroring the Elixir capability probe (eight axes, no extras,
/// 32 buttons, no POV, no force feedback).
fn check_descriptor<A: VjoyAdapter>(adapter: &mut A, device: u8) -> Result<(), VjoyError> {
    match adapter.descriptor(device) {
        Ok(descriptor) if descriptor == REQUIRED_DESCRIPTOR => Ok(()),
        Ok(descriptor) => Err(incompatible(device, &descriptor)),
        Err(error) => Err(error),
    }
}

fn incompatible(device: u8, found: &DeviceDescriptor) -> VjoyError {
    VjoyError::IncompatibleDevice(
        device,
        format!(
            "requires {} axes, {} buttons, {} povs and no force feedback; found {} axes, {} buttons, {} povs, force feedback {}",
            REQUIRED_DESCRIPTOR.axes,
            REQUIRED_DESCRIPTOR.buttons,
            REQUIRED_DESCRIPTOR.povs,
            found.axes,
            found.buttons,
            found.povs,
            found.force_feedback
        ),
    )
}

/// Neutralize and release everything acquired, reverse order. Neutralization
/// failures do not block release (the SDK's relinquish cannot report failure
/// and a stuck axis must not pin ownership); the first failure is returned.
fn release_all<A: VjoyAdapter>(inner: &mut ManagerInner<A>) -> Result<(), VjoyError> {
    let mut failure = None;
    for device in inner.acquired.clone().into_iter().rev() {
        if let Err(error) = inner.adapter.neutralize_device(device) {
            failure = failure.or(Some(error));
        }
        inner.adapter.release_device(device);
        inner.acquired.remove(&device);
    }
    failure.map_or(Ok(()), Err)
}

fn rollback_with_error<A: VjoyAdapter>(inner: &mut ManagerInner<A>, error: VjoyError) -> VjoyError {
    release_all(inner).err().unwrap_or(error)
}
