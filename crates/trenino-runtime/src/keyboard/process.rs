//! Deadline-bound sidecar execution. Pipe reads are nonblocking and bounded;
//! descendants cannot retain an EOF wait or a reader thread during shutdown.
use super::KeystrokeError;
use std::{
    io::{self, Read},
    path::Path,
    process::{Command, Stdio},
    time::{Duration, Instant},
};
const ACTION_TIMEOUT: Duration = Duration::from_secs(2);
const CAPTURE_LIMIT: usize = 64 * 1024;
fn failure(error: impl ToString) -> KeystrokeError {
    KeystrokeError::Spawn(error.to_string())
}
pub(super) fn execute(executable: &Path, action: &str, combo: &str) -> Result<(), KeystrokeError> {
    let mut command = Command::new(executable);
    command
        .arg(action)
        .arg(combo)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    #[cfg(unix)]
    {
        use std::os::unix::process::CommandExt;
        command.process_group(0);
    }
    #[cfg(windows)]
    suspend_command(&mut command);
    let mut child = command.spawn().map_err(failure)?;
    let group = match ProcessGroup::new(&child) {
        Ok(group) => group,
        Err(e) => {
            let _ = child.kill();
            let _ = child.wait();
            return Err(failure(e));
        }
    };
    #[cfg(windows)]
    if let Err(error) = resume_suspended(child.id()) {
        group.terminate();
        let _ = child.kill();
        let _ = child.wait();
        return Err(failure(error));
    }
    let mut stdout = child.stdout.take().expect("piped stdout");
    let mut stderr = child.stderr.take().expect("piped stderr");
    if let Err(error) = prepare(&stdout).and_then(|()| prepare(&stderr)) {
        group.terminate();
        let _ = child.kill();
        let _ = child.wait();
        return Err(failure(error));
    }
    let deadline = Instant::now() + ACTION_TIMEOUT;
    let mut output = Vec::new();
    let result = loop {
        if let Err(e) =
            capture(&mut stdout, &mut output).and_then(|()| capture(&mut stderr, &mut output))
        {
            break Err(failure(e));
        }
        match child.try_wait() {
            Ok(Some(status)) => {
                for _ in 0..8 {
                    let _ = capture(&mut stdout, &mut output);
                    let _ = capture(&mut stderr, &mut output);
                }
                break if status.success() {
                    Ok(())
                } else {
                    Err(KeystrokeError::CommandFailed {
                        exit_code: status.code(),
                        output: String::from_utf8_lossy(&output).into_owned(),
                    })
                };
            }
            Err(e) => break Err(failure(e)),
            Ok(None) => {}
        }
        if Instant::now() >= deadline {
            break Err(KeystrokeError::CommandFailed {
                exit_code: None,
                output: format!(
                    "native keystroke action exceeded {}ms deadline",
                    ACTION_TIMEOUT.as_millis()
                ),
            });
        }
        std::thread::sleep(Duration::from_millis(5));
    };
    // Even on success, the sidecar has no legitimate long-lived descendants.
    group.terminate();
    let _ = child.kill();
    let _ = child.wait();
    result
}
#[cfg(unix)]
fn prepare<T: std::os::fd::AsRawFd>(pipe: &T) -> io::Result<()> {
    let fd = pipe.as_raw_fd();
    let flags = unsafe { libc::fcntl(fd, libc::F_GETFL) };
    if flags < 0 || unsafe { libc::fcntl(fd, libc::F_SETFL, flags | libc::O_NONBLOCK) } < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}
#[cfg(unix)]
fn capture<T: Read + std::os::fd::AsRawFd>(pipe: &mut T, out: &mut Vec<u8>) -> io::Result<()> {
    read_available(pipe, out, 8192)
}
#[cfg(windows)]
fn prepare<T: std::os::windows::io::AsRawHandle>(_: &T) -> io::Result<()> {
    Ok(())
}
#[cfg(windows)]
fn capture<T: Read + std::os::windows::io::AsRawHandle>(
    pipe: &mut T,
    out: &mut Vec<u8>,
) -> io::Result<()> {
    use windows_sys::Win32::{Foundation::ERROR_BROKEN_PIPE, System::Pipes::PeekNamedPipe};
    let mut available = 0;
    let success = unsafe {
        PeekNamedPipe(
            pipe.as_raw_handle(),
            std::ptr::null_mut(),
            0,
            std::ptr::null_mut(),
            &mut available,
            std::ptr::null_mut(),
        )
    };
    if success == 0 {
        let error = io::Error::last_os_error();
        return if error.raw_os_error() == Some(ERROR_BROKEN_PIPE as i32) {
            Ok(())
        } else {
            Err(error)
        };
    }
    if available == 0 {
        return Ok(());
    }
    read_available(pipe, out, (available as usize).min(8192))
}
fn read_available<T: Read>(pipe: &mut T, out: &mut Vec<u8>, limit: usize) -> io::Result<()> {
    let mut buffer = [0; 8192];
    match pipe.read(&mut buffer[..limit]) {
        Ok(n) => {
            let keep = n.min(CAPTURE_LIMIT.saturating_sub(out.len()));
            out.extend_from_slice(&buffer[..keep]);
            Ok(())
        }
        Err(e)
            if matches!(
                e.kind(),
                io::ErrorKind::WouldBlock | io::ErrorKind::Interrupted
            ) =>
        {
            Ok(())
        }
        Err(e) => Err(e),
    }
}
#[cfg(unix)]
struct ProcessGroup(u32);
#[cfg(unix)]
impl ProcessGroup {
    fn new(child: &std::process::Child) -> io::Result<Self> {
        Ok(Self(child.id()))
    }
    fn terminate(&self) {
        unsafe { libc::kill(-(self.0 as i32), libc::SIGKILL) };
    }
}
#[cfg(windows)]
struct ProcessGroup(windows_sys::Win32::Foundation::HANDLE);
#[cfg(windows)]
impl ProcessGroup {
    fn new(child: &std::process::Child) -> io::Result<Self> {
        use std::os::windows::io::AsRawHandle;
        use windows_sys::Win32::System::JobObjects::*;
        let job = unsafe { CreateJobObjectW(std::ptr::null(), std::ptr::null()) };
        if job.is_null() {
            return Err(io::Error::last_os_error());
        }
        let group = Self(job);
        let mut limits: JOBOBJECT_EXTENDED_LIMIT_INFORMATION = unsafe { std::mem::zeroed() };
        limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        if unsafe {
            SetInformationJobObject(
                job,
                JobObjectExtendedLimitInformation,
                &limits as *const _ as *const _,
                std::mem::size_of_val(&limits) as u32,
            )
        } == 0
            || unsafe { AssignProcessToJobObject(job, child.as_raw_handle()) } == 0
        {
            return Err(io::Error::last_os_error());
        }
        Ok(group)
    }
    fn terminate(&self) {
        unsafe { windows_sys::Win32::System::JobObjects::TerminateJobObject(self.0, 1) };
    }
}
#[cfg(windows)]
impl Drop for ProcessGroup {
    fn drop(&mut self) {
        unsafe { windows_sys::Win32::Foundation::CloseHandle(self.0) };
    }
}

/// CREATE_SUSPENDED leaves exactly the initial thread before any user code runs.
/// Keep it suspended if enumeration/open fails or the invariant is not satisfied.
#[cfg(windows)]
fn resume_suspended(process_id: u32) -> io::Result<()> {
    use windows_sys::Win32::{
        Foundation::{CloseHandle, ERROR_NO_MORE_FILES, INVALID_HANDLE_VALUE},
        System::{
            Diagnostics::ToolHelp::{
                CreateToolhelp32Snapshot, Thread32First, Thread32Next, TH32CS_SNAPTHREAD,
                THREADENTRY32,
            },
            Threading::{OpenThread, ResumeThread, THREAD_SUSPEND_RESUME},
        },
    };
    let snapshot = unsafe { CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0) };
    if snapshot == INVALID_HANDLE_VALUE {
        return Err(io::Error::last_os_error());
    }
    let mut entry: THREADENTRY32 = unsafe { std::mem::zeroed() };
    entry.dwSize = std::mem::size_of_val(&entry) as u32;
    let mut thread_ids = Vec::new();
    let mut found = unsafe { Thread32First(snapshot, &mut entry) };
    while found != 0 {
        if entry.th32OwnerProcessID == process_id {
            thread_ids.push(entry.th32ThreadID);
        }
        entry.dwSize = std::mem::size_of_val(&entry) as u32;
        found = unsafe { Thread32Next(snapshot, &mut entry) };
    }
    let error = io::Error::last_os_error();
    unsafe { CloseHandle(snapshot) };
    if error.raw_os_error() != Some(ERROR_NO_MORE_FILES as i32) {
        return Err(error);
    }
    if thread_ids.len() != 1 {
        return Err(io::Error::other(
            "suspended sidecar must have exactly one initial thread",
        ));
    }
    let thread = unsafe { OpenThread(THREAD_SUSPEND_RESUME, 0, thread_ids[0]) };
    if thread.is_null() {
        return Err(io::Error::last_os_error());
    }
    let previous = unsafe { ResumeThread(thread) };
    let error = io::Error::last_os_error();
    unsafe { CloseHandle(thread) };
    if previous == u32::MAX {
        Err(error)
    } else if previous != 1 {
        Err(io::Error::other(
            "unexpected initial thread suspension count",
        ))
    } else {
        Ok(())
    }
}

#[cfg(windows)]
fn suspend_command(command: &mut Command) {
    use std::os::windows::process::CommandExt;
    // std closes the initial thread handle. Reopen it only after job assignment.
    command.creation_flags(windows_sys::Win32::System::Threading::CREATE_SUSPENDED);
}

#[cfg(all(test, windows))]
mod tests {
    use super::*;
    fn test_name(name: &str) -> String {
        // libtest names omit the crate segment present in module_path!().
        format!("{}::{name}", module_path!().split_once("::").unwrap().1)
    }

    #[test]
    fn sentinel_helper() {
        let Some(directory) = std::env::var_os("TRENINO_KEYBOARD_SENTINEL_DIR") else {
            return;
        };
        std::fs::write(Path::new(&directory).join("started"), b"started").unwrap();
        Command::new(std::env::current_exe().unwrap())
            .args(["--exact", &test_name("sentinel_descendant")])
            .spawn()
            .unwrap();
    }

    #[test]
    fn sentinel_descendant() {
        let Some(directory) = std::env::var_os("TRENINO_KEYBOARD_SENTINEL_DIR") else {
            return;
        };
        std::thread::sleep(Duration::from_millis(350));
        std::fs::write(Path::new(&directory).join("escaped"), b"escaped").unwrap();
    }

    #[test]
    fn suspended_launch_cannot_execute_before_job_assignment_or_escape_after_exit() {
        let directory = tempfile::tempdir().unwrap();
        let mut command = Command::new(std::env::current_exe().unwrap());
        command
            .args(["--exact", &test_name("sentinel_helper")])
            .env("TRENINO_KEYBOARD_SENTINEL_DIR", directory.path())
            .stdout(Stdio::null())
            .stderr(Stdio::null());
        suspend_command(&mut command);
        let mut child = command.spawn().unwrap();
        // Deliberately widen the old spawn-to-assignment race. No helper code
        // can execute during this interval, even on an otherwise idle machine.
        std::thread::sleep(Duration::from_millis(150));
        let started_early = directory.path().join("started").exists();
        let group = ProcessGroup::new(&child).unwrap();
        resume_suspended(child.id()).unwrap();
        let deadline = Instant::now() + ACTION_TIMEOUT;
        let completed = loop {
            if let Some(status) = child.try_wait().unwrap() {
                break status.success();
            }
            if Instant::now() >= deadline {
                break false;
            }
            std::thread::sleep(Duration::from_millis(5));
        };
        group.terminate();
        let _ = child.kill();
        let _ = child.wait();
        assert!(!started_early, "sidecar executed before assignment");
        assert!(completed, "harmless helper did not exit promptly");
        assert!(directory.path().join("started").exists());
        std::thread::sleep(Duration::from_millis(500));
        assert!(
            !directory.path().join("escaped").exists(),
            "descendant escaped its job"
        );
    }
}
