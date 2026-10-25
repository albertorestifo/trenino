//! The vJoy lifecycle manager: persisted selected-device ownership with
//! acquire/neutralize/release transitions integrated with the shared resource
//! arbiter. Ported from `Trenino.VirtualJoystick.Manager` (states,
//! persist-after-confirmation, quarantine-and-retry) onto the adapter
//! contract; the Elixir configurator/bridge pair collapses into the single
//! [`VjoyAdapter`] acquire path.

use std::collections::{BTreeMap, BTreeSet};
use std::sync::{Arc, Mutex};

use trenino_core::{EntityId, OperationId};

use crate::resource::ResourceArbiter;
use crate::storage::Database;

use super::adapter::{
    DeviceDescriptor, REQUIRED_DESCRIPTOR, VjoyAdapter, VjoyDeviceStatus, VjoyError,
};
use super::store::{MappingDraft, MappingRecord};

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
        };
        if !supported {
            inner.status = VjoyStatus::Unsupported;
        } else if configuration.enabled {
            // Reconciliation failures mirror init: state records the outcome,
            // the persisted requested flag stays as committed.
            let _ = enable_locked(&db, &arbiter, &mut inner);
        } else {
            reconcile_not_requested(&mut inner);
        }
        Self {
            db,
            arbiter,
            inner: Mutex::new(inner),
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
        if inner.status == VjoyStatus::Active {
            return Ok(());
        }
        enable_locked(&self.db, &self.arbiter, &mut inner)
    }

    /// Neutralize and release every acquired device (reverse order), then
    /// persist `enabled = false` only after the releases completed. Idempotent
    /// when already off; clears quarantine like the Elixir `cancel_retry`.
    pub fn disable(&self) -> Result<(), VjoyError> {
        let mut inner = self.inner.lock().expect("vjoy manager poisoned");
        if inner.status == VjoyStatus::Off {
            inner.quarantined.clear();
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
        match self.db.vjoy_confirm_enabled(OperationId(0), false) {
            Ok(_) => {
                inner.requested = false;
                inner.status = VjoyStatus::Off;
                inner.reason = None;
                Ok(())
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
        if !matches!(inner.status, VjoyStatus::NeedsSetup | VjoyStatus::Error) {
            return Err(VjoyError::InvalidState(
                "retry requires needs_setup or error",
            ));
        }
        inner.quarantined.clear();
        inner.reason = None;
        enable_locked(&self.db, &self.arbiter, &mut inner)
    }

    /// Current mappings (the Elixir `reload_mappings` read path).
    pub fn mappings(&self) -> Result<Vec<MappingRecord>, VjoyError> {
        Ok(self.db.vjoy_list_mappings()?)
    }

    /// Reapply the neutral report to every acquired device. Hook for the
    /// shared arbiter's consumer chain: when a calibration/firmware lease
    /// suspends actuation, the compositor calls this so no held control keeps
    /// driving the virtual device while the port is owned elsewhere.
    pub fn neutralize_outputs(&self) -> Result<(), VjoyError> {
        let mut inner = self.inner.lock().expect("vjoy manager poisoned");
        if inner.status != VjoyStatus::Active {
            return Err(VjoyError::InvalidState(
                "outputs are only driven while active",
            ));
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
        Ok(self
            .db
            .vjoy_put_mapping(operation_id, input_id, draft, replace)?
            .record)
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
            Ok(VjoyDeviceStatus::Free) => leftover = true,
            Ok(VjoyDeviceStatus::Missing) | Ok(VjoyDeviceStatus::Unknown) => {}
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

    if let Err(error) = acquire_selection(inner) {
        // Rollback already happened inside acquire_selection; classify status.
        inner.status = match &error {
            VjoyError::DeviceMissing(_) => VjoyStatus::NeedsSetup,
            _ => VjoyStatus::Error,
        };
        inner.reason = Some(error.clone());
        return Err(error);
    }

    match db.vjoy_confirm_enabled(OperationId(0), true) {
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
fn acquire_selection<A: VjoyAdapter>(inner: &mut ManagerInner<A>) -> Result<(), VjoyError> {
    for device in inner.selection.clone() {
        match inner.adapter.device_status(device) {
            // Owned is either ours (acquire below is idempotent) or foreign
            // (acquire fails); Free proceeds; anything else refuses so an
            // unowned device is never acquired blindly.
            Ok(VjoyDeviceStatus::Owned) | Ok(VjoyDeviceStatus::Free) => {}
            Ok(VjoyDeviceStatus::Busy) => {
                let _ = release_all(inner);
                return Err(VjoyError::DeviceBusy(device));
            }
            Ok(VjoyDeviceStatus::Missing) => {
                let _ = release_all(inner);
                return Err(VjoyError::DeviceMissing(device));
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
