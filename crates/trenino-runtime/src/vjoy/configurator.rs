//! Bounded device setup/removal over an injected native platform boundary.
//! All resource names and elevated arguments are fixed by Trenino.

use std::path::{Component, Path, PathBuf};

pub const SETUP_TIMEOUT_MS: u64 = 10_000;
const POLL_INTERVAL_MS: u64 = 100;
const PROCESS_POLL_MS: u64 = 10;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ProcessOutput {
    pub status: i32,
    pub output: String,
    /// Backend monotonic clock at successful UAC acceptance/process spawn.
    pub accepted_at_ms: u64,
}

/// Spawn/poll/terminate/reap seam shared by native Windows execution and
/// portable timeout tests. `terminate_tree` must cover the elevated child.
pub trait BoundedProcess {
    type Child;
    fn now_ms(&self) -> u64;
    fn sleep_ms(&mut self, ms: u64);
    fn spawn(
        &mut self,
        executable: &Path,
        args: &[String],
    ) -> Result<Self::Child, ConfiguratorError>;
    fn poll(&mut self, child: &mut Self::Child) -> Result<Option<i32>, ConfiguratorError>;
    fn terminate_tree(&mut self, child: &mut Self::Child) -> Result<(), ConfiguratorError>;
    fn reap(&mut self, child: &mut Self::Child) -> Result<ProcessOutput, ConfiguratorError>;
    fn retain(&mut self, child: Self::Child);
}

pub fn run_bounded<P: BoundedProcess>(
    process: &mut P,
    executable: &Path,
    args: &[String],
    timeout_ms: u64,
) -> Result<ProcessOutput, ConfiguratorError> {
    let mut child = process.spawn(executable, args)?;
    let accepted_at_ms = process.now_ms();
    let deadline = accepted_at_ms.saturating_add(timeout_ms);
    loop {
        match process.poll(&mut child) {
            Ok(Some(_)) => match process.reap(&mut child) {
                Ok(mut output) => {
                    output.accepted_at_ms = accepted_at_ms;
                    return Ok(output);
                }
                Err(_) => {
                    process.retain(child);
                    return Err(ConfiguratorError::CleanupIncomplete);
                }
            },
            Ok(None) => {}
            Err(error) => {
                let terminated = process.terminate_tree(&mut child);
                let reaped = process.reap(&mut child);
                if terminated.is_err() || reaped.is_err() {
                    process.retain(child);
                    return Err(ConfiguratorError::CleanupIncomplete);
                }
                return Err(error);
            }
        }
        let remaining = deadline.saturating_sub(process.now_ms());
        if remaining == 0 {
            let terminated = process.terminate_tree(&mut child);
            let reaped = process.reap(&mut child);
            if terminated.is_err() || reaped.is_err() {
                process.retain(child);
                return Err(ConfiguratorError::CleanupIncomplete);
            }
            return Err(ConfiguratorError::Timeout);
        }
        process.sleep_ms(PROCESS_POLL_MS.min(remaining));
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum ConfigStatus {
    #[default]
    DriverMissing,
    Missing,
    Compatible,
    Incompatible,
    Busy,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ConfiguratorError {
    Unsupported,
    InvalidDevice,
    UntrustedResource,
    DriverMissing,
    Incompatible,
    Busy,
    ForeignDevice,
    UacCancelled,
    ProcessExit(i32),
    Timeout,
    CleanupIncomplete,
    MarkerWriteFailed,
    Native(String),
}

impl std::fmt::Display for ConfiguratorError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for ConfiguratorError {}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FileKind {
    Directory,
    Regular,
    LinkOrReparse,
    Missing,
    Other,
}

/// A platform-specific lstat/reparse probe. `Other` and `Missing` fail closed.
pub trait FileProbe {
    fn kind(&self, path: &Path) -> FileKind;
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ResourcePaths {
    /// Trusted absolute installation anchor (normally the desktop executable's directory).
    pub anchor: PathBuf,
    /// Trusted absolute resource directory under `anchor`.
    pub resources: PathBuf,
}

/// Validate the installation anchor and every component from it to one fixed
/// helper. Never resolve through PATH, CWD, a symlink, or a Windows reparse point.
pub fn trusted_resource<P: FileProbe>(
    probe: &P,
    paths: &ResourcePaths,
    name: &str,
) -> Result<PathBuf, ConfiguratorError> {
    if !matches!(
        name,
        "vJoyConfig.exe" | "vJoyInstall.dll" | "vJoyInterface.dll"
    ) || !paths.anchor.is_absolute()
        || !paths.resources.is_absolute()
        || paths.resources == paths.anchor
        || !paths.resources.starts_with(&paths.anchor)
        || paths
            .anchor
            .components()
            .any(|c| matches!(c, Component::ParentDir | Component::CurDir))
        || paths
            .resources
            .components()
            .any(|c| matches!(c, Component::ParentDir | Component::CurDir))
    {
        return Err(ConfiguratorError::UntrustedResource);
    }
    // lstat of the anchor alone follows any junction in its ancestors. Walk
    // from the absolute filesystem root so every traversed segment is checked.
    let mut current = PathBuf::new();
    for component in paths.anchor.components() {
        match component {
            Component::Prefix(_) => {
                current.push(component.as_os_str());
                continue;
            }
            Component::RootDir | Component::Normal(_) => current.push(component.as_os_str()),
            _ => return Err(ConfiguratorError::UntrustedResource),
        }
        if probe.kind(&current) != FileKind::Directory {
            return Err(ConfiguratorError::UntrustedResource);
        }
    }
    for component in paths
        .resources
        .strip_prefix(&paths.anchor)
        .map_err(|_| ConfiguratorError::UntrustedResource)?
        .components()
    {
        match component {
            Component::Normal(name) => current.push(name),
            _ => return Err(ConfiguratorError::UntrustedResource),
        }
        if probe.kind(&current) != FileKind::Directory {
            return Err(ConfiguratorError::UntrustedResource);
        }
    }
    let candidate = current.join(name);
    if probe.kind(&candidate) != FileKind::Regular {
        return Err(ConfiguratorError::UntrustedResource);
    }
    Ok(candidate)
}

/// Native process/registry/clock boundary. A timed-out `elevate` must kill and
/// reap its process tree before returning `Timeout`.
pub trait ConfiguratorBackend: FileProbe {
    fn now_ms(&self) -> u64;
    fn sleep_ms(&mut self, ms: u64);
    fn status(&mut self, device: u8, budget_ms: u64) -> Result<ConfigStatus, ConfiguratorError>;
    fn elevate(
        &mut self,
        executable: &Path,
        args: &[String],
        budget_ms: u64,
    ) -> Result<ProcessOutput, ConfiguratorError>;
    fn owned(&mut self, device: u8) -> Result<bool, ConfiguratorError>;
    fn mark_owned(&mut self, device: u8, owned: bool) -> Result<(), ConfiguratorError>;
    fn pending(&mut self, _device: u8) -> Result<bool, ConfiguratorError> {
        Ok(false)
    }
    fn mark_pending(&mut self, _device: u8, _pending: bool) -> Result<(), ConfiguratorError> {
        Ok(())
    }
    fn confirmed(&mut self, _device: u8) -> Result<bool, ConfiguratorError> {
        Ok(false)
    }
    fn mark_confirmed(&mut self, _device: u8, _confirmed: bool) -> Result<(), ConfiguratorError> {
        Ok(())
    }
    fn reconcile_processes(&mut self) -> Result<(), ConfiguratorError> {
        Ok(())
    }
}

#[derive(Clone, Debug)]
pub struct Configurator {
    paths: ResourcePaths,
}

impl Configurator {
    pub fn new(paths: ResourcePaths) -> Self {
        Self { paths }
    }

    pub fn create<B: ConfiguratorBackend>(
        &self,
        backend: &mut B,
        device: u8,
    ) -> Result<(), ConfiguratorError> {
        validate_device(device)?;
        backend.reconcile_processes()?;
        let preflight_deadline = backend.now_ms().saturating_add(SETUP_TIMEOUT_MS);
        match checked_status(backend, device, preflight_deadline)? {
            ConfigStatus::Compatible => {
                if backend.owned(device)? {
                    return Ok(());
                }
                if backend.confirmed(device)? {
                    backend.mark_owned(device, true)?;
                    backend.mark_confirmed(device, false)?;
                    backend.mark_pending(device, false)?;
                    return Ok(());
                }
                return Err(ConfiguratorError::ForeignDevice);
            }
            ConfigStatus::Missing => {}
            other => return Err(status_error(other)),
        }
        let config = self.validated_resources(backend, preflight_deadline)?;
        if backend.pending(device)? {
            backend.mark_pending(device, false)?;
        }
        backend.mark_pending(device, true)?;
        let args = create_arguments(device);
        let deadline = match elevate(backend, &config, &args) {
            Ok(deadline) => deadline,
            Err(ConfiguratorError::UacCancelled) => {
                backend.mark_pending(device, false)?;
                return Err(ConfiguratorError::UacCancelled);
            }
            Err(ConfiguratorError::CleanupIncomplete) => {
                return Err(ConfiguratorError::CleanupIncomplete)
            }
            Err(error) => return reconcile_create(backend, device, error),
        };
        if let Err(error) = wait_for(backend, device, ConfigStatus::Compatible, deadline) {
            return reconcile_create(backend, device, error);
        }
        // Only a successful helper followed by a compatible observation can
        // establish creation provenance. Persist that fact before the owned
        // marker so a marker-write failure can be retried safely.
        backend.mark_confirmed(device, true)?;
        backend.mark_owned(device, true)?;
        backend.mark_confirmed(device, false)?;
        backend.mark_pending(device, false)
    }

    pub fn delete<B: ConfiguratorBackend>(
        &self,
        backend: &mut B,
        device: u8,
    ) -> Result<(), ConfiguratorError> {
        validate_device(device)?;
        backend.reconcile_processes()?;
        let deadline = backend.now_ms().saturating_add(SETUP_TIMEOUT_MS);
        let mut owned = backend.owned(device)?;
        let pending = backend.pending(device)?;
        let confirmed = backend.confirmed(device)?;
        match checked_status(backend, device, deadline)? {
            ConfigStatus::Missing => {
                if owned {
                    backend.mark_owned(device, false)?;
                }
                if pending {
                    backend.mark_pending(device, false)?;
                }
                if confirmed {
                    backend.mark_confirmed(device, false)?;
                }
                return Ok(());
            }
            ConfigStatus::Compatible if owned => {}
            ConfigStatus::Compatible if confirmed => {
                backend.mark_owned(device, true)?;
                backend.mark_confirmed(device, false)?;
                backend.mark_pending(device, false)?;
                owned = true;
            }
            ConfigStatus::Compatible => return Err(ConfiguratorError::ForeignDevice),
            other => return Err(status_error(other)),
        }
        let config = self.validated_resources(backend, deadline)?;
        let deadline = match elevate(backend, &config, &["-d".into(), device.to_string()]) {
            Ok(deadline) => deadline,
            Err(ConfiguratorError::CleanupIncomplete) => {
                return Err(ConfiguratorError::CleanupIncomplete)
            }
            Err(error) => return reconcile_delete(backend, device, error),
        };
        if let Err(error) = wait_for(backend, device, ConfigStatus::Missing, deadline) {
            return reconcile_delete(backend, device, error);
        }
        if owned {
            backend.mark_owned(device, false)?;
        }
        backend.mark_confirmed(device, false)?;
        backend.mark_pending(device, false)
    }

    fn validated_resources<B: ConfiguratorBackend>(
        &self,
        backend: &B,
        deadline: u64,
    ) -> Result<PathBuf, ConfiguratorError> {
        let config = trusted_resource(backend, &self.paths, "vJoyConfig.exe")?;
        check_deadline(backend, deadline)?;
        trusted_resource(backend, &self.paths, "vJoyInstall.dll")?;
        check_deadline(backend, deadline)?;
        trusted_resource(backend, &self.paths, "vJoyInterface.dll")?;
        check_deadline(backend, deadline)?;
        Ok(config)
    }
}

pub fn create_arguments(device: u8) -> Vec<String> {
    [
        device.to_string(),
        "-a".into(),
        "x".into(),
        "y".into(),
        "z".into(),
        "rx".into(),
        "ry".into(),
        "rz".into(),
        "sl0".into(),
        "sl1".into(),
        "-b".into(),
        "32".into(),
        "-p".into(),
        "0".into(),
    ]
    .into()
}

/// The elevated broker accepts only one of our exact selected-ID commands.
/// It never forwards caller-controlled helper arguments.
pub fn broker_request(args: &[String]) -> Result<(&'static str, u8), ConfiguratorError> {
    if args.len() == 2 && args[0] == "-d" {
        let id = args[1]
            .parse::<u8>()
            .map_err(|_| ConfiguratorError::InvalidDevice)?;
        validate_device(id)?;
        return Ok(("delete", id));
    }
    let id = args
        .first()
        .ok_or(ConfiguratorError::InvalidDevice)?
        .parse::<u8>()
        .map_err(|_| ConfiguratorError::InvalidDevice)?;
    validate_device(id)?;
    if args == create_arguments(id) {
        Ok(("create", id))
    } else {
        Err(ConfiguratorError::InvalidDevice)
    }
}

pub fn marker_name(device: u8) -> Result<String, ConfiguratorError> {
    validate_device(device)?;
    Ok(format!("VJoyDevice{device}CreatedByTrenino"))
}

pub fn pending_marker_name(device: u8) -> Result<String, ConfiguratorError> {
    validate_device(device)?;
    Ok(format!("VJoyDevice{device}CreationPendingByTrenino"))
}

pub fn confirmed_marker_name(device: u8) -> Result<String, ConfiguratorError> {
    validate_device(device)?;
    Ok(format!("VJoyDevice{device}CreationConfirmedByTrenino"))
}

fn validate_device(device: u8) -> Result<(), ConfiguratorError> {
    if (1..=16).contains(&device) {
        Ok(())
    } else {
        Err(ConfiguratorError::InvalidDevice)
    }
}

fn remaining<B: ConfiguratorBackend>(backend: &B, deadline: u64) -> Result<u64, ConfiguratorError> {
    deadline
        .checked_sub(backend.now_ms())
        .ok_or(ConfiguratorError::Timeout)
}

fn check_deadline<B: ConfiguratorBackend>(
    backend: &B,
    deadline: u64,
) -> Result<(), ConfiguratorError> {
    if backend.now_ms() <= deadline {
        Ok(())
    } else {
        Err(ConfiguratorError::Timeout)
    }
}

fn checked_status<B: ConfiguratorBackend>(
    backend: &mut B,
    device: u8,
    deadline: u64,
) -> Result<ConfigStatus, ConfiguratorError> {
    let budget = remaining(backend, deadline)?;
    let status = backend.status(device, budget)?;
    check_deadline(backend, deadline)?;
    Ok(status)
}

fn elevate<B: ConfiguratorBackend>(
    backend: &mut B,
    config: &Path,
    args: &[String],
) -> Result<u64, ConfiguratorError> {
    let output = backend.elevate(config, args, SETUP_TIMEOUT_MS)?;
    match output.status {
        0 => {
            let deadline = output.accepted_at_ms.saturating_add(SETUP_TIMEOUT_MS);
            check_deadline(backend, deadline)?;
            Ok(deadline)
        }
        1223 => Err(ConfiguratorError::UacCancelled),
        code => Err(ConfiguratorError::ProcessExit(code)),
    }
}

fn reconcile_create<B: ConfiguratorBackend>(
    backend: &mut B,
    device: u8,
    error: ConfiguratorError,
) -> Result<(), ConfiguratorError> {
    backend.reconcile_processes()?;
    let deadline = backend.now_ms().saturating_add(SETUP_TIMEOUT_MS);
    match checked_status(backend, device, deadline)? {
        ConfigStatus::Compatible => Err(ConfiguratorError::ForeignDevice),
        ConfigStatus::Missing => {
            if !matches!(error, ConfiguratorError::CleanupIncomplete) {
                backend.mark_pending(device, false)?;
            }
            Err(error)
        }
        _ => Err(error),
    }
}

fn reconcile_delete<B: ConfiguratorBackend>(
    backend: &mut B,
    device: u8,
    error: ConfiguratorError,
) -> Result<(), ConfiguratorError> {
    backend.reconcile_processes()?;
    let deadline = backend.now_ms().saturating_add(SETUP_TIMEOUT_MS);
    if checked_status(backend, device, deadline)? == ConfigStatus::Missing {
        backend.mark_owned(device, false)?;
        backend.mark_pending(device, false)?;
        Ok(())
    } else {
        Err(error)
    }
}

fn wait_for<B: ConfiguratorBackend>(
    backend: &mut B,
    device: u8,
    expected: ConfigStatus,
    deadline: u64,
) -> Result<(), ConfiguratorError> {
    loop {
        let status = checked_status(backend, device, deadline)?;
        if status == expected {
            return Ok(());
        }
        let budget = remaining(backend, deadline)?;
        if budget == 0 {
            return Err(ConfiguratorError::Timeout);
        }
        backend.sleep_ms(POLL_INTERVAL_MS.min(budget));
    }
}

fn status_error(status: ConfigStatus) -> ConfiguratorError {
    match status {
        ConfigStatus::DriverMissing => ConfiguratorError::DriverMissing,
        ConfigStatus::Missing => ConfiguratorError::Native("device missing".into()),
        ConfigStatus::Compatible => ConfiguratorError::Native("unexpected compatible state".into()),
        ConfigStatus::Incompatible => ConfiguratorError::Incompatible,
        ConfigStatus::Busy => ConfiguratorError::Busy,
    }
}
