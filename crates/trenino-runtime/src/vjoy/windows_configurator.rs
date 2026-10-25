//! Native Windows boundary for the portable configurator state machine.
//! Only fixed bundled resources and fixed selected IDs reach elevation.

use std::ffi::OsStr;
use std::io::Read;
use std::os::windows::ffi::OsStrExt;
use std::os::windows::fs::MetadataExt;
use std::os::windows::process::CommandExt;
use std::path::Path;
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

use windows_sys::Win32::Foundation::{
    CloseHandle, GetLastError, ERROR_ALREADY_EXISTS, ERROR_CANCELLED, ERROR_FILE_NOT_FOUND,
    ERROR_PATH_NOT_FOUND, WAIT_OBJECT_0, WAIT_TIMEOUT,
};
use windows_sys::Win32::System::JobObjects::{
    AssignProcessToJobObject, CreateJobObjectW, IsProcessInJob,
    JobObjectBasicAccountingInformation, JobObjectExtendedLimitInformation, OpenJobObjectW,
    QueryInformationJobObject, SetInformationJobObject, TerminateJobObject,
    JOBOBJECT_BASIC_ACCOUNTING_INFORMATION, JOBOBJECT_EXTENDED_LIMIT_INFORMATION,
    JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE,
};
use windows_sys::Win32::System::Registry::{
    RegCloseKey, RegCreateKeyExW, RegDeleteValueW, RegOpenKeyExW, RegQueryValueExW, RegSetValueExW,
    HKEY, HKEY_CURRENT_USER, KEY_QUERY_VALUE, KEY_SET_VALUE, REG_DWORD,
};
use windows_sys::Win32::System::Threading::{
    CreateProcessW, GetCurrentProcess, GetExitCodeProcess, ResumeThread, TerminateProcess,
    WaitForSingleObject, CREATE_NO_WINDOW, CREATE_SUSPENDED, PROCESS_INFORMATION, STARTUPINFOW,
};
use windows_sys::Win32::UI::Shell::{ShellExecuteExW, SEE_MASK_NOCLOSEPROCESS, SHELLEXECUTEINFOW};

use super::adapter::{VjoyAdapter, VjoyDeviceStatus, REQUIRED_DESCRIPTOR};
use super::configurator::{
    broker_request, confirmed_marker_name, create_arguments, marker_name, pending_marker_name,
    run_bounded, trusted_resource, BoundedProcess, ConfigStatus, ConfiguratorBackend,
    ConfiguratorError, FileKind, FileProbe, ProcessOutput, ResourcePaths,
};
use super::windows::WindowsVjoyAdapter;

const KEY: &str = "Software\\Trenino";
const REPARSE_POINT: u32 = 0x400;
const JOB_OBJECT_QUERY_ACCESS: u32 = 0x0004;

fn fresh_job_name() -> Result<String, ConfiguratorError> {
    let mut nonce = [0u8; 16];
    getrandom::fill(&mut nonce).map_err(|e| ConfiguratorError::Native(e.to_string()))?;
    Ok(format!(
        "Local\\TreninoVjoy-{}",
        nonce.iter().map(|b| format!("{b:02x}")).collect::<String>()
    ))
}

fn wide(value: impl AsRef<OsStr>) -> Vec<u16> {
    value
        .as_ref()
        .encode_wide()
        .chain(std::iter::once(0))
        .collect()
}

fn native_error() -> ConfiguratorError {
    ConfiguratorError::Native(std::io::Error::last_os_error().to_string())
}

impl FileProbe for WindowsVjoyAdapter {
    fn kind(&self, path: &Path) -> FileKind {
        match std::fs::symlink_metadata(path) {
            Ok(metadata)
                if metadata.file_attributes() & REPARSE_POINT != 0
                    || metadata.file_type().is_symlink() =>
            {
                FileKind::LinkOrReparse
            }
            Ok(metadata) if metadata.is_dir() => FileKind::Directory,
            Ok(metadata) if metadata.is_file() => FileKind::Regular,
            Ok(_) => FileKind::Other,
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => FileKind::Missing,
            Err(_) => FileKind::Other,
        }
    }
}

struct KeyHandle(HKEY);
impl Drop for KeyHandle {
    fn drop(&mut self) {
        unsafe {
            RegCloseKey(self.0);
        }
    }
}

fn open_key(write: bool, create: bool) -> Result<Option<KeyHandle>, ConfiguratorError> {
    let mut key = std::ptr::null_mut();
    let path = wide(KEY);
    let status = unsafe {
        if create {
            RegCreateKeyExW(
                HKEY_CURRENT_USER,
                path.as_ptr(),
                0,
                std::ptr::null(),
                0,
                KEY_QUERY_VALUE | KEY_SET_VALUE,
                std::ptr::null(),
                &mut key,
                std::ptr::null_mut(),
            )
        } else {
            RegOpenKeyExW(
                HKEY_CURRENT_USER,
                path.as_ptr(),
                0,
                if write {
                    KEY_SET_VALUE
                } else {
                    KEY_QUERY_VALUE
                },
                &mut key,
            )
        }
    };
    if status == 0 {
        Ok(Some(KeyHandle(key)))
    } else if !create && (status == ERROR_FILE_NOT_FOUND || status == ERROR_PATH_NOT_FOUND) {
        Ok(None)
    } else {
        Err(ConfiguratorError::MarkerWriteFailed)
    }
}

fn read_marker(name: &str) -> Result<bool, ConfiguratorError> {
    let name = wide(name);
    let Some(key) = open_key(false, false)? else {
        return Ok(false);
    };
    let mut kind = 0;
    let mut value = 0u32;
    let mut size = std::mem::size_of::<u32>() as u32;
    let status = unsafe {
        RegQueryValueExW(
            key.0,
            name.as_ptr(),
            std::ptr::null(),
            &mut kind,
            (&mut value as *mut u32).cast(),
            &mut size,
        )
    };
    match status {
        0 => Ok(kind == REG_DWORD && size == 4 && value == 1),
        ERROR_FILE_NOT_FOUND => Ok(false),
        _ => Err(ConfiguratorError::MarkerWriteFailed),
    }
}

fn write_marker(name: &str, owned: bool) -> Result<(), ConfiguratorError> {
    let name = wide(name);
    if owned {
        let key = open_key(true, true)?.expect("created registry key");
        let value = 1u32;
        let status = unsafe {
            RegSetValueExW(
                key.0,
                name.as_ptr(),
                0,
                REG_DWORD,
                (&value as *const u32).cast(),
                4,
            )
        };
        if status != 0 {
            return Err(ConfiguratorError::MarkerWriteFailed);
        }
    } else if let Some(key) = open_key(true, false)? {
        let status = unsafe { RegDeleteValueW(key.0, name.as_ptr()) };
        if status != 0 && status != ERROR_FILE_NOT_FOUND {
            return Err(ConfiguratorError::MarkerWriteFailed);
        }
    }
    Ok(())
}

struct NativeProcess<'a> {
    started: Instant,
    pending: &'a mut Vec<NativeChild>,
}
pub(super) struct NativeChild {
    process: windows_sys::Win32::Foundation::HANDLE,
    job: windows_sys::Win32::Foundation::HANDLE,
    contained: bool,
}
unsafe impl Send for NativeChild {}

impl Drop for NativeChild {
    fn drop(&mut self) {
        unsafe {
            CloseHandle(self.process);
            CloseHandle(self.job);
        }
    }
}

/// ShellExecuteExW elevates only the controlled Trenino broker. The broker
/// starts the fixed helper suspended in its own kill-on-close job before any
/// helper instruction or descendant can run.
impl BoundedProcess for NativeProcess<'_> {
    type Child = NativeChild;

    fn now_ms(&self) -> u64 {
        self.started.elapsed().as_millis().min(u128::from(u64::MAX)) as u64
    }
    fn sleep_ms(&mut self, ms: u64) {
        std::thread::sleep(Duration::from_millis(ms));
    }

    fn spawn(
        &mut self,
        executable: &Path,
        arguments: &[String],
    ) -> Result<Self::Child, ConfiguratorError> {
        let (operation, device) = broker_request(arguments)?;
        let broker =
            std::env::current_exe().map_err(|e| ConfiguratorError::Native(e.to_string()))?;
        let expected_helper = broker
            .parent()
            .ok_or(ConfiguratorError::UntrustedResource)?
            .join("resources")
            .join("vJoyConfig.exe");
        if executable != expected_helper {
            return Err(ConfiguratorError::UntrustedResource);
        }
        let job_name = fresh_job_name()?;
        let job_wide = wide(&job_name);
        let job = unsafe { CreateJobObjectW(std::ptr::null(), job_wide.as_ptr()) };
        if job.is_null() {
            return Err(native_error());
        }
        if unsafe { GetLastError() } == ERROR_ALREADY_EXISTS {
            unsafe {
                CloseHandle(job);
            }
            return Err(ConfiguratorError::CleanupIncomplete);
        }
        let mut limit = JOBOBJECT_EXTENDED_LIMIT_INFORMATION::default();
        limit.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        if unsafe {
            SetInformationJobObject(
                job,
                JobObjectExtendedLimitInformation,
                (&limit as *const JOBOBJECT_EXTENDED_LIMIT_INFORMATION).cast(),
                std::mem::size_of::<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>() as u32,
            )
        } == 0
        {
            unsafe {
                CloseHandle(job);
            }
            return Err(native_error());
        }
        let verb = wide("runas");
        let file = wide(broker.as_os_str());
        let params = wide(format!(
            "--internal-vjoy-broker {operation} {device} {job_name}"
        ));
        let directory = wide(
            broker
                .parent()
                .ok_or(ConfiguratorError::UntrustedResource)?
                .as_os_str(),
        );
        let mut info = SHELLEXECUTEINFOW {
            cbSize: std::mem::size_of::<SHELLEXECUTEINFOW>() as u32,
            fMask: SEE_MASK_NOCLOSEPROCESS,
            hwnd: std::ptr::null_mut(),
            lpVerb: verb.as_ptr(),
            lpFile: file.as_ptr(),
            lpParameters: params.as_ptr(),
            lpDirectory: directory.as_ptr(),
            nShow: 1,
            ..Default::default()
        };
        if unsafe { ShellExecuteExW(&mut info) } == 0 {
            unsafe {
                CloseHandle(job);
            }
            return if std::io::Error::last_os_error().raw_os_error() == Some(ERROR_CANCELLED as i32)
            {
                Err(ConfiguratorError::UacCancelled)
            } else {
                Err(native_error())
            };
        }
        if info.hProcess.is_null() {
            unsafe {
                CloseHandle(job);
            }
            return Err(ConfiguratorError::Native(
                "elevated helper returned no process handle".into(),
            ));
        }
        let mut child = NativeChild {
            process: info.hProcess,
            job,
            contained: false,
        };
        if unsafe { AssignProcessToJobObject(job, child.process) } == 0 {
            // Without containment, descendants cannot be accounted for.
            // Stop the process, retain its handle and refuse further setup.
            unsafe {
                TerminateProcess(child.process, 1);
                WaitForSingleObject(child.process, 5_000);
            }
            self.retain(child);
            return Err(ConfiguratorError::CleanupIncomplete);
        }
        child.contained = true;
        Ok(child)
    }

    fn poll(&mut self, child: &mut Self::Child) -> Result<Option<i32>, ConfiguratorError> {
        match unsafe { WaitForSingleObject(child.process, 0) } {
            WAIT_OBJECT_0 => {
                let mut code = 0;
                if unsafe { GetExitCodeProcess(child.process, &mut code) } == 0 {
                    Err(native_error())
                } else {
                    Ok(Some(code as i32))
                }
            }
            WAIT_TIMEOUT => Ok(None),
            _ => Err(native_error()),
        }
    }

    fn terminate_tree(&mut self, child: &mut Self::Child) -> Result<(), ConfiguratorError> {
        if unsafe { TerminateJobObject(child.job, 1) } != 0 {
            Ok(())
        } else {
            Err(native_error())
        }
    }

    fn reap(&mut self, child: &mut Self::Child) -> Result<ProcessOutput, ConfiguratorError> {
        if unsafe { WaitForSingleObject(child.process, 5_000) } != WAIT_OBJECT_0 {
            return Err(ConfiguratorError::Native(
                "elevated helper could not be reaped".into(),
            ));
        }
        let mut drained = false;
        for _ in 0..500 {
            let mut accounting = JOBOBJECT_BASIC_ACCOUNTING_INFORMATION::default();
            if unsafe {
                QueryInformationJobObject(
                    child.job,
                    JobObjectBasicAccountingInformation,
                    (&mut accounting as *mut JOBOBJECT_BASIC_ACCOUNTING_INFORMATION).cast(),
                    std::mem::size_of::<JOBOBJECT_BASIC_ACCOUNTING_INFORMATION>() as u32,
                    std::ptr::null_mut(),
                )
            } == 0
            {
                return Err(native_error());
            }
            if accounting.ActiveProcesses == 0 {
                drained = true;
                break;
            }
            std::thread::sleep(Duration::from_millis(10));
        }
        if !drained {
            return Err(ConfiguratorError::CleanupIncomplete);
        }
        let mut code = 0;
        if unsafe { GetExitCodeProcess(child.process, &mut code) } == 0 {
            return Err(native_error());
        }
        Ok(ProcessOutput {
            status: code as i32,
            output: String::new(),
            accepted_at_ms: 0,
        })
    }

    fn retain(&mut self, child: Self::Child) {
        self.pending.push(child);
    }
}

struct StatusProcess<'a> {
    started: Instant,
    pending: &'a mut Vec<std::process::Child>,
}

impl BoundedProcess for StatusProcess<'_> {
    type Child = std::process::Child;
    fn now_ms(&self) -> u64 {
        self.started.elapsed().as_millis().min(u128::from(u64::MAX)) as u64
    }
    fn sleep_ms(&mut self, ms: u64) {
        std::thread::sleep(Duration::from_millis(ms));
    }
    fn spawn(
        &mut self,
        executable: &Path,
        args: &[String],
    ) -> Result<Self::Child, ConfiguratorError> {
        Command::new(executable)
            .args(args)
            .creation_flags(0x08000000)
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()
            .map_err(|e| ConfiguratorError::Native(e.to_string()))
    }
    fn poll(&mut self, child: &mut Self::Child) -> Result<Option<i32>, ConfiguratorError> {
        child
            .try_wait()
            .map(|status| status.map(|status| status.code().unwrap_or(1)))
            .map_err(|e| ConfiguratorError::Native(e.to_string()))
    }
    fn terminate_tree(&mut self, child: &mut Self::Child) -> Result<(), ConfiguratorError> {
        if child
            .try_wait()
            .map_err(|e| ConfiguratorError::Native(e.to_string()))?
            .is_some()
        {
            return Ok(());
        }
        child
            .kill()
            .map_err(|e| ConfiguratorError::Native(e.to_string()))
    }
    fn reap(&mut self, child: &mut Self::Child) -> Result<ProcessOutput, ConfiguratorError> {
        let mut status = None;
        for _ in 0..500 {
            status = child
                .try_wait()
                .map_err(|e| ConfiguratorError::Native(e.to_string()))?;
            if status.is_some() {
                break;
            }
            std::thread::sleep(Duration::from_millis(10));
        }
        let status = status.ok_or(ConfiguratorError::CleanupIncomplete)?;
        let mut output = String::new();
        if let Some(stdout) = child.stdout.take() {
            stdout
                .take(64)
                .read_to_string(&mut output)
                .map_err(|e| ConfiguratorError::Native(e.to_string()))?;
        }
        Ok(ProcessOutput {
            status: status.code().unwrap_or(1),
            output,
            accepted_at_ms: 0,
        })
    }
    fn retain(&mut self, child: Self::Child) {
        self.pending.push(child);
    }
}

fn raw_status(adapter: &mut WindowsVjoyAdapter, device: u8) -> ConfigStatus {
    if adapter.raw_driver_available().is_err() {
        return ConfigStatus::DriverMissing;
    }
    match adapter.raw_device_status(device) {
        Ok(VjoyDeviceStatus::Missing) => ConfigStatus::Missing,
        Ok(VjoyDeviceStatus::Busy | VjoyDeviceStatus::Unknown) => ConfigStatus::Busy,
        Ok(VjoyDeviceStatus::Owned | VjoyDeviceStatus::Free) => match adapter.descriptor(device) {
            Ok(descriptor) if descriptor == REQUIRED_DESCRIPTOR => ConfigStatus::Compatible,
            _ => ConfigStatus::Incompatible,
        },
        Err(_) => ConfigStatus::DriverMissing,
    }
}

/// Call before Tauri, plugins and the single-instance hook are initialized.
/// The parent runs this mode in a bounded child so a native SDK stall cannot
/// monopolize the manager lock or crash the application process.
pub fn status_worker_entry() -> Option<i32> {
    let mut args = std::env::args_os();
    let _exe = args.next();
    let mode = args.next()?;
    let mode = mode.to_string_lossy();
    if mode == "--internal-vjoy-broker" {
        return Some(broker_entry(args));
    }
    if mode == "--internal-vjoy-driver" {
        if args.next().is_some() {
            return Some(2);
        }
        let mut adapter = WindowsVjoyAdapter::new();
        println!(
            "{}",
            if adapter.raw_driver_available().is_ok() {
                "enabled"
            } else {
                "driver_missing"
            }
        );
        return Some(0);
    }
    if mode != "--internal-vjoy-status" && mode != "--internal-vjoy-device" {
        return None;
    }
    let Some(device) = args
        .next()
        .and_then(|id| id.to_string_lossy().parse::<u8>().ok())
    else {
        return Some(2);
    };
    if !(1..=16).contains(&device) || args.next().is_some() {
        return Some(2);
    }
    let mut adapter = WindowsVjoyAdapter::new();
    if mode == "--internal-vjoy-device" {
        let token = if adapter.raw_driver_available().is_err() {
            "driver_missing"
        } else {
            match adapter.raw_device_status(device) {
                Ok(VjoyDeviceStatus::Missing) => "missing",
                Ok(VjoyDeviceStatus::Free) => "free",
                Ok(VjoyDeviceStatus::Owned) => "owned",
                Ok(VjoyDeviceStatus::Busy) => "busy",
                Ok(VjoyDeviceStatus::Unknown) => "unknown",
                Err(_) => "driver_missing",
            }
        };
        println!("{token}");
        return Some(0);
    }
    let status = raw_status(&mut adapter, device);
    let token = match status {
        ConfigStatus::DriverMissing => "driver_missing",
        ConfigStatus::Missing => "missing",
        ConfigStatus::Compatible => "compatible",
        ConfigStatus::Incompatible => "incompatible",
        ConfigStatus::Busy => "busy",
    };
    println!("{token}");
    Some(0)
}

/// Runs only in the elevated same-executable broker process. The helper is
/// suspended until its process has joined a broker-owned kill-on-close job.
/// The broker keeps that job open until the whole job is drained; if the
/// broker dies, Windows closes its handles and kills the contained tree.
fn broker_entry(mut args: impl Iterator<Item = std::ffi::OsString>) -> i32 {
    let operation = args.next().and_then(|a| a.into_string().ok());
    let device = args
        .next()
        .and_then(|a| a.into_string().ok())
        .and_then(|id| id.parse::<u8>().ok());
    let job_name = args.next().and_then(|a| a.into_string().ok());
    if args.next().is_some() {
        return 2;
    }
    let Some(device) = device.filter(|id| (1..=16).contains(id)) else {
        return 2;
    };
    let arguments = match operation.as_deref() {
        Some("create") => create_arguments(device),
        Some("delete") => vec!["-d".into(), device.to_string()],
        _ => return 2,
    };
    let Some(job_name) = job_name else {
        return 2;
    };
    broker_run(&arguments, &job_name).unwrap_or(1)
}

fn broker_run(arguments: &[String], parent_job_name: &str) -> Result<i32, ConfiguratorError> {
    if !parent_job_name.starts_with("Local\\TreninoVjoy-")
        || parent_job_name.len() != "Local\\TreninoVjoy-".len() + 32
        || !parent_job_name["Local\\TreninoVjoy-".len()..]
            .bytes()
            .all(|b| b.is_ascii_hexdigit())
    {
        return Err(ConfiguratorError::InvalidDevice);
    }
    let parent_name = wide(parent_job_name);
    let started = Instant::now();
    loop {
        let parent_job =
            unsafe { OpenJobObjectW(JOB_OBJECT_QUERY_ACCESS, 0, parent_name.as_ptr()) };
        if !parent_job.is_null() {
            let mut associated = 0;
            let queried =
                unsafe { IsProcessInJob(GetCurrentProcess(), parent_job, &mut associated) };
            unsafe {
                CloseHandle(parent_job);
            }
            if queried == 0 {
                return Err(native_error());
            }
            if associated != 0 {
                break;
            }
        }
        if started.elapsed() >= Duration::from_secs(10) {
            return Err(ConfiguratorError::Timeout);
        }
        std::thread::sleep(Duration::from_millis(10));
    }
    let exe = std::env::current_exe().map_err(|e| ConfiguratorError::Native(e.to_string()))?;
    let anchor = exe
        .parent()
        .ok_or(ConfiguratorError::UntrustedResource)?
        .to_path_buf();
    let resources = anchor.join("resources");
    let paths = ResourcePaths { anchor, resources };
    let probe = WindowsVjoyAdapter::new();
    let helper = trusted_resource(&probe, &paths, "vJoyConfig.exe")?;
    trusted_resource(&probe, &paths, "vJoyInstall.dll")?;
    trusted_resource(&probe, &paths, "vJoyInterface.dll")?;
    broker_request(arguments)?;

    let job = unsafe { CreateJobObjectW(std::ptr::null(), std::ptr::null()) };
    if job.is_null() {
        return Err(native_error());
    }
    let mut limit = JOBOBJECT_EXTENDED_LIMIT_INFORMATION::default();
    limit.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if unsafe {
        SetInformationJobObject(
            job,
            JobObjectExtendedLimitInformation,
            (&limit as *const JOBOBJECT_EXTENDED_LIMIT_INFORMATION).cast(),
            std::mem::size_of::<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>() as u32,
        )
    } == 0
    {
        unsafe {
            CloseHandle(job);
        }
        return Err(native_error());
    }
    let application = wide(helper.as_os_str());
    let command = format!("\"{}\" {}", helper.display(), arguments.join(" "));
    let mut command = wide(command);
    let directory = wide(
        helper
            .parent()
            .ok_or(ConfiguratorError::UntrustedResource)?
            .as_os_str(),
    );
    let startup = STARTUPINFOW {
        cb: std::mem::size_of::<STARTUPINFOW>() as u32,
        ..Default::default()
    };
    let mut info = PROCESS_INFORMATION::default();
    if unsafe {
        CreateProcessW(
            application.as_ptr(),
            command.as_mut_ptr(),
            std::ptr::null(),
            std::ptr::null(),
            0,
            CREATE_SUSPENDED | CREATE_NO_WINDOW,
            std::ptr::null(),
            directory.as_ptr(),
            &startup,
            &mut info,
        )
    } == 0
    {
        unsafe {
            CloseHandle(job);
        }
        return Err(native_error());
    }
    let mut child = NativeChild {
        process: info.hProcess,
        job,
        contained: false,
    };
    if unsafe { AssignProcessToJobObject(job, child.process) } == 0 {
        unsafe {
            TerminateProcess(child.process, 1);
            WaitForSingleObject(child.process, 5_000);
            CloseHandle(info.hThread);
        }
        return Err(ConfiguratorError::CleanupIncomplete);
    }
    child.contained = true;
    if unsafe { ResumeThread(info.hThread) } == u32::MAX {
        unsafe {
            CloseHandle(info.hThread);
        }
        let mut pending = Vec::new();
        let mut process = NativeProcess {
            started: Instant::now(),
            pending: &mut pending,
        };
        process.terminate_tree(&mut child)?;
        process.reap(&mut child)?;
        return Err(ConfiguratorError::CleanupIncomplete);
    }
    unsafe {
        CloseHandle(info.hThread);
    }
    let mut pending = Vec::new();
    let mut process = NativeProcess {
        started: Instant::now(),
        pending: &mut pending,
    };
    let deadline = process.now_ms().saturating_add(10_000);
    loop {
        if let Some(code) = process.poll(&mut child)? {
            process.reap(&mut child)?;
            return Ok(code);
        }
        if process.now_ms() >= deadline {
            process.terminate_tree(&mut child)?;
            process.reap(&mut child)?;
            return Err(ConfiguratorError::Timeout);
        }
        process.sleep_ms(10);
    }
}

fn run_status_worker(
    adapter: &mut WindowsVjoyAdapter,
    args: &[String],
    budget_ms: u64,
) -> Result<String, ConfiguratorError> {
    let exe = std::env::current_exe().map_err(|e| ConfiguratorError::Native(e.to_string()))?;
    let expected = exe
        .parent()
        .ok_or(ConfiguratorError::UntrustedResource)?
        .join("resources");
    if adapter
        .paths
        .as_ref()
        .is_none_or(|paths| paths.resources != expected)
    {
        return Err(ConfiguratorError::UntrustedResource);
    }
    let mut process = StatusProcess {
        started: adapter.started,
        pending: &mut adapter.pending_status,
    };
    let output = run_bounded(&mut process, &exe, args, budget_ms)?;
    if output.status != 0 {
        return Err(ConfiguratorError::Native("status worker failed".into()));
    }
    Ok(output.output.trim().to_owned())
}

pub(super) fn probe_driver(
    adapter: &mut WindowsVjoyAdapter,
) -> Result<(), super::adapter::VjoyError> {
    match run_status_worker(adapter, &["--internal-vjoy-driver".into()], 10_000)
        .map_err(super::adapter::VjoyError::Configurator)?
        .as_str()
    {
        "enabled" => Ok(()),
        "driver_missing" => Err(super::adapter::VjoyError::DriverUnavailable(
            "vJoy driver unavailable".into(),
        )),
        _ => Err(super::adapter::VjoyError::Configurator(
            ConfiguratorError::Native("invalid status worker response".into()),
        )),
    }
}

pub(super) fn probe_device(
    adapter: &mut WindowsVjoyAdapter,
    device: u8,
) -> Result<VjoyDeviceStatus, super::adapter::VjoyError> {
    let args = ["--internal-vjoy-device".into(), device.to_string()];
    match run_status_worker(adapter, &args, 10_000)
        .map_err(super::adapter::VjoyError::Configurator)?
        .as_str()
    {
        "missing" => Ok(VjoyDeviceStatus::Missing),
        "free" => Ok(VjoyDeviceStatus::Free),
        "owned" => Ok(VjoyDeviceStatus::Owned),
        "busy" => Ok(VjoyDeviceStatus::Busy),
        "unknown" => Ok(VjoyDeviceStatus::Unknown),
        "driver_missing" => Err(super::adapter::VjoyError::DriverUnavailable(
            "vJoy driver unavailable".into(),
        )),
        _ => Err(super::adapter::VjoyError::Configurator(
            ConfiguratorError::Native("invalid status worker response".into()),
        )),
    }
}

fn settle_pending(adapter: &mut WindowsVjoyAdapter) -> Result<(), ConfiguratorError> {
    let mut pending_elevated = Vec::new();
    for mut child in std::mem::take(&mut adapter.pending_elevated) {
        if !child.contained {
            pending_elevated.push(child);
            continue;
        }
        let mut process = NativeProcess {
            started: adapter.started,
            pending: &mut pending_elevated,
        };
        let terminated = process.terminate_tree(&mut child);
        let reaped = process.reap(&mut child);
        if terminated.is_err() || reaped.is_err() {
            pending_elevated.push(child);
        }
    }
    adapter.pending_elevated = pending_elevated;
    let mut pending_status = Vec::new();
    for mut child in std::mem::take(&mut adapter.pending_status) {
        let mut process = StatusProcess {
            started: adapter.started,
            pending: &mut pending_status,
        };
        let terminated = process.terminate_tree(&mut child);
        let reaped = process.reap(&mut child);
        if terminated.is_err() || reaped.is_err() {
            pending_status.push(child);
        }
    }
    adapter.pending_status = pending_status;
    if adapter.pending_elevated.is_empty() && adapter.pending_status.is_empty() {
        Ok(())
    } else {
        Err(ConfiguratorError::CleanupIncomplete)
    }
}

impl ConfiguratorBackend for WindowsVjoyAdapter {
    fn now_ms(&self) -> u64 {
        self.started.elapsed().as_millis().min(u128::from(u64::MAX)) as u64
    }
    fn sleep_ms(&mut self, ms: u64) {
        std::thread::sleep(Duration::from_millis(ms));
    }

    fn status(&mut self, device: u8, budget_ms: u64) -> Result<ConfigStatus, ConfiguratorError> {
        match run_status_worker(
            self,
            &["--internal-vjoy-status".into(), device.to_string()],
            budget_ms,
        )?
        .as_str()
        {
            "driver_missing" => Ok(ConfigStatus::DriverMissing),
            "missing" => Ok(ConfigStatus::Missing),
            "compatible" => Ok(ConfigStatus::Compatible),
            "incompatible" => Ok(ConfigStatus::Incompatible),
            "busy" => Ok(ConfigStatus::Busy),
            _ => Err(ConfiguratorError::Native(
                "invalid status worker response".into(),
            )),
        }
    }

    fn elevate(
        &mut self,
        executable: &Path,
        args: &[String],
        budget_ms: u64,
    ) -> Result<ProcessOutput, ConfiguratorError> {
        let mut process = NativeProcess {
            started: self.started,
            pending: &mut self.pending_elevated,
        };
        run_bounded(&mut process, executable, args, budget_ms)
    }

    fn owned(&mut self, device: u8) -> Result<bool, ConfiguratorError> {
        read_marker(&marker_name(device)?)
    }
    fn mark_owned(&mut self, device: u8, owned: bool) -> Result<(), ConfiguratorError> {
        write_marker(&marker_name(device)?, owned)
    }
    fn pending(&mut self, device: u8) -> Result<bool, ConfiguratorError> {
        read_marker(&pending_marker_name(device)?)
    }
    fn mark_pending(&mut self, device: u8, pending: bool) -> Result<(), ConfiguratorError> {
        write_marker(&pending_marker_name(device)?, pending)
    }
    fn confirmed(&mut self, device: u8) -> Result<bool, ConfiguratorError> {
        read_marker(&confirmed_marker_name(device)?)
    }
    fn mark_confirmed(&mut self, device: u8, confirmed: bool) -> Result<(), ConfiguratorError> {
        write_marker(&confirmed_marker_name(device)?, confirmed)
    }
    fn reconcile_processes(&mut self) -> Result<(), ConfiguratorError> {
        settle_pending(self)
    }
}
