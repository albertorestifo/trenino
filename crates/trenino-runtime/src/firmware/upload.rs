//! Owned avrdude upload lifecycle: 1200-bps bootloader touch, bootloader
//! port-change polling, avrdude subprocess execution with output
//! classification, exclusive port leases, cancellation with kill/reap, and
//! upload history recording.
//!
//! Behavior port from the Elixir oracle:
//!
//! * `Trenino.Firmware.Uploader` — argument building, the
//!   `port_not_found` single retry, the alternate-Nano baud retry, the
//!   1200-bps touch + bootloader port polling, error classification and
//!   friendly error messages (`lib/trenino/firmware/uploader.ex`).
//! * `Trenino.Firmware.AvrdudeRunner` — subprocess spawn with merged
//!   stdout/stderr, progress parsing, and the collect timeout message
//!   (`lib/trenino/firmware/avrdude_runner.ex`).
//! * `Trenino.Firmware.UploadManager` — one upload at a time, port
//!   reservation released before history updates, terminal history
//!   statuses (`started`/`completed`/`failed`/`cancelled`), the cancelled +
//!   timeout broadcast pair, and crash handling
//!   (`lib/trenino/firmware/upload_manager.ex`).
//!
//! Divergences required by the Rust platform contract: avrdude is launched
//! from one configured absolute path (no PATH/CWD search, per the packaging
//! constraints), the Erlang Port/Task plumbing maps onto a worker thread plus
//! a watchdog thread, the Phoenix PubSub broadcast maps onto an injectable
//! event sink, and captured avrdude output is bounded (`max_output_bytes`).

use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{mpsc, Arc, Condvar, Mutex};
use std::thread::{self, JoinHandle};
use std::time::{Duration, Instant};

use trenino_core::firmware::{Programmer, UploadConfig};
use trenino_core::EntityId;

use crate::hardware::transport::SerialTransport;
use crate::resource::{LeaseKind, LeaseToken, ResourceArbiter, ResourceError};

/// Why an upload was cancelled. The first recorded kind wins, mirroring the
/// Elixir manager where a late `{:upload_timeout, _}` message is ignored once
/// `current_upload` has been cleared by user cancellation.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CancelKind {
    User,
    Timeout,
}

/// Shared cancellation flag for one upload. The manager (or watchdog) marks
/// it and kills the avrdude child; the worker observes it at every phase
/// boundary and inside every wait loop.
#[derive(Clone, Default)]
pub struct UploadCancelHandle(Arc<CancelInner>);

#[derive(Default)]
struct CancelInner {
    cancelled: AtomicBool,
    kind: Mutex<Option<CancelKind>>,
}

impl UploadCancelHandle {
    pub fn new() -> Self {
        Self::default()
    }

    /// Record a cancellation request. Returns `true` when this call is the
    /// first request; later requests are ignored.
    pub fn request(&self, kind: CancelKind) -> bool {
        let mut recorded = self.0.kind.lock().expect("upload cancel state poisoned");
        if recorded.is_some() {
            return false;
        }
        *recorded = Some(kind);
        self.0.cancelled.store(true, Ordering::Release);
        true
    }

    pub fn is_cancelled(&self) -> bool {
        self.0.cancelled.load(Ordering::Acquire)
    }

    pub fn kind(&self) -> Option<CancelKind> {
        *self.0.kind.lock().expect("upload cancel state poisoned")
    }
}

/// Terminal classification of an upload attempt, mirroring the Elixir
/// `Uploader` error atoms plus the manager-level `:cancelled` and `:crash`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum UploadFailure {
    PortNotFound,
    BootloaderNotResponding,
    WrongBoardType,
    VerificationFailed,
    Timeout,
    PermissionDenied,
    HexFileNotFound,
    AvrdudeNotFound,
    BootloaderPortNotFound,
    UnknownDevice,
    UnknownError,
    Cancelled,
    Crash,
}

impl UploadFailure {
    /// Atom-style key recorded in the upload history `error_message` column
    /// (the Elixir manager stores `to_string(reason)`).
    pub fn error_key(&self) -> &'static str {
        match self {
            Self::PortNotFound => "port_not_found",
            Self::BootloaderNotResponding => "bootloader_not_responding",
            Self::WrongBoardType => "wrong_board_type",
            Self::VerificationFailed => "verification_failed",
            Self::Timeout => "timeout",
            Self::PermissionDenied => "permission_denied",
            Self::HexFileNotFound => "hex_file_not_found",
            Self::AvrdudeNotFound => "avrdude_not_found",
            Self::BootloaderPortNotFound => "bootloader_port_not_found",
            Self::UnknownDevice => "unknown_device",
            Self::UnknownError => "unknown_error",
            Self::Cancelled => "cancelled",
            Self::Crash => "crash",
        }
    }

    /// User-facing message, ported verbatim from `Uploader.error_message/1`.
    pub fn friendly_message(&self) -> String {
        match self {
            Self::PortNotFound => "Device not found. Please check:\n\
                - Device is connected via USB\n\
                - USB cable supports data (not charge-only)\n\
                - Device appears in the connected devices list\n"
                .to_string(),
            Self::BootloaderNotResponding => "Bootloader not responding. For Pro Micro, \
                Leonardo, and Micro boards:\n\
                - Double-tap the reset button to enter bootloader mode\n\
                - Start the upload within 8 seconds\n\n\
                For other boards, verify:\n\
                - Selected board type matches your physical board\n\
                - Device is powered on and connected\n\
                - Try a different USB port or cable\n"
                .to_string(),
            Self::WrongBoardType => "Board type mismatch. The selected board type doesn't \
                match\nthe connected device. Please select the correct board type\nand try \
                again.\n"
                .to_string(),
            Self::VerificationFailed => "Upload verification failed. The firmware was \
                written but\ncould not be verified. This may be caused by:\n\
                - Unstable USB connection\n\
                - Power supply issues\n\
                - Hardware defect\n\n\
                Please try again with a different USB port or cable.\n"
                .to_string(),
            Self::Timeout => "Upload timed out. The device stopped responding during\n\
                the upload process. Please:\n\
                - Check the USB connection\n\
                - Verify the board type is correct\n\
                - Try a different USB port or cable\n"
                .to_string(),
            Self::PermissionDenied => "Permission denied accessing the serial port. You may \
                need to:\n\
                - Add your user to the dialout group (Linux)\n\
                - Grant terminal access to serial ports (macOS)\n\
                - Run as administrator (Windows)\n"
                .to_string(),
            Self::HexFileNotFound => {
                "Firmware file not found. Please download the firmware first.".to_string()
            }
            Self::AvrdudeNotFound => "avrdude not found. Please ensure avrdude is \
                installed:\n\
                - macOS: brew install avrdude\n\
                - Linux: apt-get install avrdude\n\
                - Windows: Download from https://github.com/avrdudes/avrdude/releases\n"
                .to_string(),
            Self::BootloaderPortNotFound => "Bootloader port not found. The device \
                disconnected but the bootloader\ndid not appear on any port. Please try:\n\
                - Double-tap the reset button to manually enter bootloader mode\n\
                - Start the upload within 8 seconds\n\
                - Try a different USB port\n"
                .to_string(),
            Self::UnknownDevice => "Unknown device type. The selected device is not \
                recognized.\nPlease check for updates or try selecting a different board \
                type.\n"
                .to_string(),
            Self::UnknownError => {
                "An unknown error occurred during upload. Please check the log for details."
                    .to_string()
            }
            Self::Cancelled => "Upload cancelled by user".to_string(),
            Self::Crash => "Upload task crashed unexpectedly".to_string(),
        }
    }
}

/// Alternate STK500v1 baud rates by programmer. New-bootloader Nanos
/// (Optiboot) run 115200; old-bootloader clones run 57600
/// (`Uploader.@alternate_baud_rates`).
pub fn retryable_baud_rates(programmer: &Programmer, tried_baud_rate: u32) -> Vec<u32> {
    const ARDUINO_ALTERNATES: [u32; 2] = [57_600, 115_200];
    if programmer.as_str() != "arduino" {
        return Vec::new();
    }
    ARDUINO_ALTERNATES
        .into_iter()
        .filter(|rate| *rate != tried_baud_rate)
        .collect()
}

/// Classify avrdude output. Order matters; the patterns are ported verbatim
/// from `Uploader.@error_patterns` (single strings match on containment,
/// tuple entries must all be present).
pub fn parse_error_output(output: &str) -> UploadFailure {
    let contains = |pattern: &str| output.contains(pattern);
    if contains("permission denied") {
        return UploadFailure::PermissionDenied;
    }
    if contains("can't open device") || contains("cannot open port") {
        return UploadFailure::PortNotFound;
    }
    if contains("programmer is not responding")
        || contains("not in sync")
        || (contains("stk500") && contains("not responding"))
        || contains("initialization failed")
        || (contains("butterfly") && contains("AVR910"))
    {
        return UploadFailure::BootloaderNotResponding;
    }
    if contains("device signature") {
        return UploadFailure::WrongBoardType;
    }
    if contains("verification error") {
        return UploadFailure::VerificationFailed;
    }
    if contains("Timeout") {
        return UploadFailure::Timeout;
    }
    UploadFailure::UnknownError
}

/// Configured trusted avrdude location. The path must be absolute; avrdude is
/// always spawned from exactly this path with no PATH or working-directory
/// fallback (packaging constraint from the rewrite handoff).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct UploadTooling {
    pub avrdude_path: PathBuf,
    pub avrdude_conf: Option<PathBuf>,
}

impl UploadTooling {
    /// Resolve avrdude through the 3-tier probe ported from
    /// `Trenino.Firmware.Avrdude.executable_path/0` (avrdude.ex:20-34):
    /// configured absolute path → app-resource dir → bundled dir/PATH.
    /// Dev-only relative candidates are never probed in release builds.
    pub fn discover_avrdude(
        probe: &crate::executable::ExecutableProbe,
    ) -> Result<Self, crate::executable::ExecutableError> {
        Ok(Self {
            avrdude_path: probe.resolve()?,
            avrdude_conf: None,
        })
    }
}

/// Every wait, poll and bound used by the upload lifecycle, defaulting to the
/// Elixir oracle's constants. Tests shrink the values to stay fast and
/// deterministic.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct UploadTimings {
    /// Manager watchdog: overall upload deadline (`@upload_timeout_ms`).
    pub upload_timeout: Duration,
    /// Per-attempt wait for avrdude to exit (`@collect_timeout_ms`).
    pub collect_timeout: Duration,
    /// Pause between the 1200-bps open and close (`@bootloader_initial_wait_ms`).
    pub bootloader_initial_wait: Duration,
    /// Bootloader port poll interval (`@bootloader_poll_interval_ms`).
    pub bootloader_poll_interval: Duration,
    /// Bootloader port poll deadline (`@bootloader_poll_deadline_ms`).
    pub bootloader_poll_deadline: Duration,
    /// Delay before the single port-not-found retry (2 s in the oracle).
    pub port_retry_delay: Duration,
    /// Timeout handed to the serial transport when opening for the touch.
    pub serial_open_timeout: Duration,
    /// Granularity of child-exit/cancel polling loops.
    pub poll_interval: Duration,
    /// Bound on captured avrdude output (the oracle captured unbounded
    /// output; bounded capture is a platform requirement here).
    pub max_output_bytes: usize,
    /// Delay before the post-upload rescan hook fires —
    /// `connection.ex:249` `Process.send_after(self(), :post_upload_scan, 500)`.
    pub reconnect_delay: Duration,
    /// Bound on acknowledged cancellation cleanup, independent of upload duration.
    pub cleanup_timeout: Duration,
}

impl Default for UploadTimings {
    fn default() -> Self {
        Self {
            upload_timeout: Duration::from_millis(120_000),
            collect_timeout: Duration::from_millis(120_000),
            bootloader_initial_wait: Duration::from_millis(100),
            bootloader_poll_interval: Duration::from_millis(300),
            bootloader_poll_deadline: Duration::from_millis(5_000),
            port_retry_delay: Duration::from_millis(2_000),
            serial_open_timeout: Duration::from_millis(2_000),
            poll_interval: Duration::from_millis(2),
            max_output_bytes: 1024 * 1024,
            reconnect_delay: Duration::from_millis(500),
            cleanup_timeout: Duration::from_secs(15),
        }
    }
}

/// One device upload passed to [`run_device_upload`] — the equivalent of
/// `Uploader.upload/4` arguments.
pub struct DeviceUpload<'a> {
    pub port: &'a str,
    pub environment: &'a str,
    pub hex_path: &'a Path,
    pub config: &'a UploadConfig,
}

/// Result of one device upload run (`Uploader.upload/4` return shape). For
/// [`UploadFailure::Crash`] the `output` field carries the
/// `"Task crashed: …"` detail, mirroring the Elixir crash history entry.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum UploadRunResult {
    Success {
        output: String,
        duration_ms: u64,
    },
    Failure {
        reason: UploadFailure,
        output: Option<String>,
        duration_ms: u64,
    },
}

/// Records the `firmware_upload_history` lifecycle. Wave-2 storage wiring
/// implements this port against the runtime database; the Elixir oracle
/// writes `status = started` on start, then exactly one of completed/failed/
/// cancelled.
pub trait UploadHistoryPort: Send + Sync + 'static {
    fn record_started(&self, record: &UploadStartRecord) -> Result<(), String>;
    fn record_completed(
        &self,
        upload_id: &str,
        avrdude_output: &str,
        duration_ms: u64,
    ) -> Result<(), String>;
    fn record_failed(
        &self,
        upload_id: &str,
        error_message: &str,
        avrdude_output: Option<&str>,
        duration_ms: u64,
    ) -> Result<(), String>;
    fn record_cancelled(&self, upload_id: &str, duration_ms: u64) -> Result<(), String>;
}

/// Fields of the initial history row (`UploadHistory.start_changeset/1`).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct UploadStartRecord {
    pub upload_id: String,
    pub port: String,
    pub board_type: String,
    pub firmware_file_id: EntityId,
}

/// Broadcast parity with the `firmware:uploads` PubSub topic.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum UploadEvent {
    Started {
        upload_id: String,
        port: String,
        environment: String,
    },
    Progress {
        upload_id: String,
        percent: u32,
        message: String,
    },
    Completed {
        upload_id: String,
        duration_ms: u64,
    },
    Failed {
        upload_id: String,
        reason: UploadFailure,
        message: String,
    },
}

/// Terminal history status (`UploadHistory.status`).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum UploadStatus {
    Completed,
    Failed,
    Cancelled,
}

/// Terminal observation for one upload. The timeout path records
/// `status = Cancelled` with `reason = Timeout`, exactly like the Elixir
/// manager whose timeout handler cancels the upload before broadcasting the
/// timeout failure.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct UploadOutcome {
    pub upload_id: String,
    pub status: UploadStatus,
    pub reason: Option<UploadFailure>,
    pub message: Option<String>,
    pub duration_ms: u64,
}

/// Live upload description (`UploadManager.State.upload_info`).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct UploadInfo {
    pub upload_id: String,
    pub port: String,
    pub environment: String,
    pub firmware_file_id: EntityId,
    pub lease: LeaseToken,
    pub generation: u64,
    pub started_at: Instant,
}

/// Everything `start_upload` needs beside the manager wiring. The hex path is
/// verified before the lease is taken; `generation` identifies the hardware
/// generation the firmware lease pins.
pub struct UploadRequest {
    pub port: String,
    pub environment: String,
    pub firmware_file_id: EntityId,
    pub hex_path: PathBuf,
    pub upload_config: UploadConfig,
    pub generation: u64,
}

/// Errors returned by [`UploadManager::start_upload`]. `UploadInProgress`
/// and `FirmwareNotDownloaded` mirror the Elixir `{:error, …}` tuples; the
/// lease variant wraps the resource arbiter's fail-closed refusals.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum UploadStartError {
    UploadInProgress,
    FirmwareNotDownloaded,
    Lease(ResourceError),
    History(String),
    SpawnFailed(String),
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum UploadCancelError {
    NotFound,
    Timeout,
    CleanupIncomplete,
}

/// Coordinates scanner ownership with the firmware worker's existing lease.
/// A failed/uncertain handoff must remain reserved until `finish` confirms
/// cleanup. Methods must be bounded and idempotent for retryable shutdown.
pub trait UploadSerialOwnership: Send + Sync + 'static {
    fn prepare(
        &self,
        lease: LeaseToken,
        port: &str,
        generation: u64,
        cancel: &UploadCancelHandle,
    ) -> Result<(), String>;
    fn finish(&self, lease: LeaseToken, port: &str, generation: u64) -> Result<(), String>;
}

/// PubSub-equivalent upload event sink.
pub type UploadEventSink = Arc<dyn Fn(&UploadEvent) + Send + Sync>;
/// Post-flash reconnect hook (the Elixir connection layer triggers an
/// immediate scan when upload access is released).
pub type ReconnectHook = Arc<dyn Fn(&str) + Send + Sync>;

/// Optional sinks hooked into the manager: the PubSub-equivalent event sink
#[derive(Default)]
pub struct UploadHooks {
    pub on_event: Option<UploadEventSink>,
    pub reconnect: Option<ReconnectHook>,
}

/// The shared avrdude child slot. The worker polls the child through it; the
/// manager or watchdog may take the child out to kill and reap it, which
/// guarantees no zombie and no orphaned port reservation on cancellation.
#[derive(Default)]
struct ChildSlot {
    child: Mutex<Option<Child>>,
    killed: AtomicBool,
}

impl ChildSlot {
    fn kill_child(&self) {
        let mut guard = self.child.lock().expect("avrdude child slot poisoned");
        if let Some(mut child) = guard.take() {
            let _ = child.kill();
            let _ = child.wait();
        }
        self.killed.store(true, Ordering::Release);
    }

    fn killed_externally(&self) -> bool {
        self.killed.load(Ordering::Acquire)
    }
}

struct OutputBuffer {
    text: Mutex<String>,
    max: usize,
}

impl OutputBuffer {
    fn new(max: usize) -> Self {
        Self {
            text: Mutex::new(String::new()),
            max,
        }
    }

    /// Append bytes, stopping at `max` bytes (never reslicing past a UTF-8
    /// character boundary). Later appends are dropped once the bound is hit.
    fn append(&self, bytes: &[u8]) {
        if bytes.is_empty() {
            return;
        }
        let chunk = String::from_utf8_lossy(bytes);
        let mut text = self.text.lock().expect("avrdude output lock poisoned");
        if text.len() >= self.max {
            return;
        }
        let remaining = self.max - text.len();
        if chunk.len() <= remaining {
            text.push_str(&chunk);
            return;
        }
        let mut boundary = remaining;
        while boundary > 0 && !chunk.is_char_boundary(boundary) {
            boundary -= 1;
        }
        text.push_str(&chunk[..boundary]);
    }

    /// Bytes appended since `offset`, plus the new offset.
    fn advance(&self, offset: usize) -> (String, usize) {
        let text = self.text.lock().expect("avrdude output lock poisoned");
        if text.len() > offset {
            (text[offset..].to_string(), text.len())
        } else {
            (String::new(), offset)
        }
    }

    fn snapshot(&self) -> String {
        self.text
            .lock()
            .expect("avrdude output lock poisoned")
            .clone()
    }
}

/// Matches `(Reading|Writing|Verifying)\s+\|.*?\|\s+(\d+)%` on one fragment
/// (the oracle splits each received chunk on newlines and matches every
/// fragment), returning the progress message formatting from
/// `AvrdudeRunner.format_operation/2`.
fn parse_progress_fragment(fragment: &str) -> Option<(u32, String)> {
    const KEYWORDS: [&str; 3] = ["Reading", "Writing", "Verifying"];
    let bytes = fragment.as_bytes();
    for (index, _) in fragment.char_indices() {
        for keyword in KEYWORDS {
            if !fragment[index..].starts_with(keyword) {
                continue;
            }
            let mut cursor = index + keyword.len();
            // `\s+`
            if cursor >= bytes.len() || !bytes[cursor].is_ascii_whitespace() {
                continue;
            }
            while cursor < bytes.len() && bytes[cursor].is_ascii_whitespace() {
                cursor += 1;
            }
            // first `|`
            if cursor >= bytes.len() || bytes[cursor] != b'|' {
                continue;
            }
            cursor += 1;
            // `.*?\|` — non-greedy up to the next `|`
            let Some(relative) = fragment[cursor..].find('|') else {
                continue;
            };
            cursor += relative + 1;
            // `\s+`
            if cursor >= bytes.len() || !bytes[cursor].is_ascii_whitespace() {
                continue;
            }
            while cursor < bytes.len() && bytes[cursor].is_ascii_whitespace() {
                cursor += 1;
            }
            // `(\d+)%`
            let digits_start = cursor;
            while cursor < bytes.len() && bytes[cursor].is_ascii_digit() {
                cursor += 1;
            }
            if cursor == digits_start || cursor >= bytes.len() || bytes[cursor] != b'%' {
                continue;
            }
            let Ok(percent) = fragment[digits_start..cursor].parse::<u32>() else {
                continue;
            };
            let message = match keyword {
                "Reading" => "Reading device...".to_string(),
                "Writing" => format!("Writing flash ({percent}%)"),
                _ => format!("Verifying ({percent}%)"),
            };
            return Some((percent, message));
        }
    }
    None
}

enum ChildOutcome {
    Exited { success: bool, output: String },
    TimedOut { output: String },
    Cancelled,
    SpawnFailed(String),
}

fn spawn_reader<R: Read + Send + 'static>(
    mut pipe: R,
    buffer: Arc<OutputBuffer>,
    done: mpsc::Sender<()>,
) {
    thread::spawn(move || {
        let mut chunk = [0u8; 4096];
        loop {
            match pipe.read(&mut chunk) {
                Ok(0) | Err(_) => break,
                Ok(read) => buffer.append(&chunk[..read]),
            }
        }
        let _ = done.send(());
    });
}

fn drain_readers(done: &mpsc::Receiver<()>) {
    // Both readers signal EOF; a slow grandchild holding the pipe can only
    // delay us for the grace period, never block the upload lifecycle.
    for _ in 0..2 {
        let _ = done.recv_timeout(Duration::from_millis(500));
    }
}

fn emit_progress(buffer: &OutputBuffer, parsed_offset: &mut usize, progress: &dyn Fn(u32, &str)) {
    let (fresh, offset) = buffer.advance(*parsed_offset);
    *parsed_offset = offset;
    for fragment in fresh.split('\n') {
        if let Some((percent, message)) = parse_progress_fragment(fragment) {
            progress(percent, &message);
        }
    }
}

/// Executes avrdude once, collecting merged stdout/stderr with the collect
/// timeout and cancellation semantics of `AvrdudeRunner.run/3`.
fn run_avrdude(
    tooling: &UploadTooling,
    args: &[String],
    timings: &UploadTimings,
    cancel: &UploadCancelHandle,
    slot: &ChildSlot,
    progress: &dyn Fn(u32, &str),
) -> ChildOutcome {
    if cancel.is_cancelled() {
        return ChildOutcome::Cancelled;
    }
    let mut command = Command::new(&tooling.avrdude_path);
    command
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    let mut child = match command.spawn() {
        Ok(child) => child,
        Err(error) => return ChildOutcome::SpawnFailed(error.to_string()),
    };
    let stdout = child.stdout.take().expect("avrdude stdout piped");
    let stderr = child.stderr.take().expect("avrdude stderr piped");
    let buffer = Arc::new(OutputBuffer::new(timings.max_output_bytes));
    let (done_tx, done_rx) = mpsc::channel();
    spawn_reader(stdout, buffer.clone(), done_tx.clone());
    spawn_reader(stderr, buffer.clone(), done_tx);
    *slot.child.lock().expect("avrdude child slot poisoned") = Some(child);

    let started = Instant::now();
    let mut parsed_offset = 0usize;
    loop {
        if cancel.is_cancelled() {
            slot.kill_child();
            drain_readers(&done_rx);
            return ChildOutcome::Cancelled;
        }
        if slot.killed_externally() {
            drain_readers(&done_rx);
            return ChildOutcome::Cancelled;
        }
        let exited = {
            let mut guard = slot.child.lock().expect("avrdude child slot poisoned");
            match guard.as_mut() {
                Some(child) => child.try_wait().expect("avrdude child wait failed"),
                None => None,
            }
        };
        if let Some(status) = exited {
            drain_readers(&done_rx);
            emit_progress(&buffer, &mut parsed_offset, progress);
            return ChildOutcome::Exited {
                success: status.success(),
                output: buffer.snapshot(),
            };
        }
        emit_progress(&buffer, &mut parsed_offset, progress);
        if started.elapsed() >= timings.collect_timeout {
            slot.kill_child();
            drain_readers(&done_rx);
            emit_progress(&buffer, &mut parsed_offset, progress);
            let mut output = buffer.snapshot();
            output.push_str("\n[Timeout: avrdude did not respond within 2 minutes]");
            return ChildOutcome::TimedOut { output };
        }
        thread::sleep(timings.poll_interval);
    }
}

/// Builds the avrdude argument vector exactly like `Uploader.build_args/3`:
/// optional `-C conf`, then `-c programmer -p mcu -P port -b baud -D
/// -U flash:w:<hex>:i -v`. MCU names use the manifest's normalized short
/// codes and the hex path is passed through unchanged (avrdude 8.x parses
/// Windows drive-letter paths correctly).
fn build_args(
    tooling: &UploadTooling,
    config: &UploadConfig,
    port: &str,
    baud_rate: u32,
    hex_path: &Path,
) -> Vec<String> {
    let mut args = Vec::new();
    if let Some(conf) = &tooling.avrdude_conf {
        args.push("-C".to_string());
        args.push(conf.display().to_string());
    }
    args.extend([
        "-c".to_string(),
        config.protocol.as_str().to_string(),
        "-p".to_string(),
        config.normalized_mcu().to_string(),
        "-P".to_string(),
        port.to_string(),
        "-b".to_string(),
        baud_rate.to_string(),
        "-D".to_string(),
        "-U".to_string(),
        format!("flash:w:{}:i", hex_path.display()),
        "-v".to_string(),
    ]);
    args
}

enum Attempt {
    Success(String),
    Failure(UploadFailure, String),
    Cancelled,
    Crash(String),
}

struct AttemptContext<'a> {
    tooling: &'a UploadTooling,
    timings: &'a UploadTimings,
    hex_path: &'a Path,
    cancel: &'a UploadCancelHandle,
    progress: &'a dyn Fn(u32, &str),
}

fn attempt_upload(
    context: &AttemptContext<'_>,
    config: &UploadConfig,
    port: &str,
    baud_rate: u32,
    slot: &ChildSlot,
) -> Attempt {
    let args = build_args(context.tooling, config, port, baud_rate, context.hex_path);
    match run_avrdude(
        context.tooling,
        &args,
        context.timings,
        context.cancel,
        slot,
        context.progress,
    ) {
        ChildOutcome::Exited {
            success: true,
            output,
        } => Attempt::Success(output),
        ChildOutcome::Exited { output, .. } | ChildOutcome::TimedOut { output } => {
            Attempt::Failure(parse_error_output(&output), output)
        }
        ChildOutcome::Cancelled => Attempt::Cancelled,
        ChildOutcome::SpawnFailed(error) => Attempt::Crash(error),
    }
}

/// Sleep in cancellation-sized slices. Returns `false` when a cancellation
/// was observed before the full delay elapsed.
fn sleep_cancelable(total: Duration, poll_interval: Duration, cancel: &UploadCancelHandle) -> bool {
    let deadline = Instant::now() + total;
    loop {
        if cancel.is_cancelled() {
            return false;
        }
        let now = Instant::now();
        if now >= deadline {
            return true;
        }
        thread::sleep(poll_interval.min(deadline.saturating_duration_since(now)));
    }
}

enum TouchOutcome {
    SamePort,
    NewPort(String),
    BootloaderPortNotFound,
    Cancelled,
}

/// The 1200-bps bootloader touch and port-change poll from
/// `Uploader.maybe_trigger_bootloader/2` + `poll_for_bootloader_port/3`.
/// A failed touch open logs-and-continues on the original port; exactly one
/// new port is used directly, several new ports resolve to the lexicographic
/// maximum, a still-present original port is reused, and a port that never
/// comes back within the deadline yields `BootloaderPortNotFound`.
fn maybe_trigger_bootloader(
    transport: &dyn SerialTransport,
    timings: &UploadTimings,
    port: &str,
    enabled: bool,
    cancel: &UploadCancelHandle,
) -> TouchOutcome {
    if !enabled {
        return TouchOutcome::SamePort;
    }
    let mut ports_before = transport.enumerate().unwrap_or_default();
    ports_before.sort();
    ports_before.dedup();
    let Ok(handle) = transport.open(port, 1200, timings.serial_open_timeout) else {
        // "Could not open port for 1200bps touch" — the oracle falls back to
        // the original port instead of failing the upload.
        return TouchOutcome::SamePort;
    };
    if !sleep_cancelable(
        timings.bootloader_initial_wait,
        timings.poll_interval,
        cancel,
    ) {
        drop(handle);
        return TouchOutcome::Cancelled;
    }
    drop(handle);
    let deadline = Instant::now() + timings.bootloader_poll_deadline;
    loop {
        let mut ports_after = transport.enumerate().unwrap_or_default();
        ports_after.sort();
        let mut new_ports: Vec<String> = ports_after
            .iter()
            .filter(|candidate| !ports_before.contains(candidate))
            .cloned()
            .collect();
        new_ports.sort();
        match new_ports.len() {
            1 => return TouchOutcome::NewPort(new_ports.remove(0)),
            count if count > 1 => {
                // Enum.max over the newly appeared ports.
                return TouchOutcome::NewPort(new_ports.remove(count - 1));
            }
            _ => {}
        }
        if ports_after.iter().any(|candidate| candidate == port) {
            return TouchOutcome::SamePort;
        }
        if Instant::now() >= deadline {
            return TouchOutcome::BootloaderPortNotFound;
        }
        if !sleep_cancelable(
            timings.bootloader_poll_interval,
            timings.poll_interval,
            cancel,
        ) {
            return TouchOutcome::Cancelled;
        }
    }
}

/// Runs one full device upload — the direct port of `Uploader.upload/4`
/// including the single port-not-found retry and the alternate-baud retry.
/// `slot` lets an owner kill the live avrdude child from another thread.
pub fn run_device_upload(
    transport: &dyn SerialTransport,
    tooling: &UploadTooling,
    timings: &UploadTimings,
    upload: DeviceUpload<'_>,
    cancel: &UploadCancelHandle,
    progress: &dyn Fn(u32, &str),
) -> UploadRunResult {
    let start = Instant::now();
    let duration_ms = || start.elapsed().as_millis() as u64;

    // `Avrdude.executable_path/0` — absolute, existing, never searched on PATH.
    if !tooling.avrdude_path.is_absolute() || !tooling.avrdude_path.is_file() {
        return UploadRunResult::Failure {
            reason: UploadFailure::AvrdudeNotFound,
            output: None,
            duration_ms: duration_ms(),
        };
    }
    // `DeviceRegistry` drops devices with unsupported upload protocols.
    if !upload.config.protocol.is_supported() {
        return UploadRunResult::Failure {
            reason: UploadFailure::UnknownDevice,
            output: Some(format!(
                "Unknown device environment: {}",
                upload.environment
            )),
            duration_ms: duration_ms(),
        };
    }
    // `Uploader.verify_hex_file/1`.
    if !upload.hex_path.is_file() {
        return UploadRunResult::Failure {
            reason: UploadFailure::HexFileNotFound,
            output: Some(format!(
                "Firmware file not found: {}",
                upload.hex_path.display()
            )),
            duration_ms: duration_ms(),
        };
    }
    if cancel.is_cancelled() {
        return UploadRunResult::Failure {
            reason: UploadFailure::Cancelled,
            output: None,
            duration_ms: duration_ms(),
        };
    }

    let slot = ChildSlot::default();
    let upload_port = match maybe_trigger_bootloader(
        transport,
        timings,
        upload.port,
        upload.config.requires_1200bps_touch,
        cancel,
    ) {
        TouchOutcome::SamePort => upload.port.to_string(),
        TouchOutcome::NewPort(port) => port,
        TouchOutcome::BootloaderPortNotFound => {
            return UploadRunResult::Failure {
                reason: UploadFailure::BootloaderPortNotFound,
                output: None,
                duration_ms: duration_ms(),
            }
        }
        TouchOutcome::Cancelled => {
            return UploadRunResult::Failure {
                reason: UploadFailure::Cancelled,
                output: None,
                duration_ms: duration_ms(),
            }
        }
    };

    let context = AttemptContext {
        tooling,
        timings,
        hex_path: upload.hex_path,
        cancel,
        progress,
    };
    // `Uploader.upload_with_retries/6`.
    match attempt_upload(
        &context,
        upload.config,
        &upload_port,
        upload.config.speed,
        &slot,
    ) {
        Attempt::Success(output) => UploadRunResult::Success {
            output,
            duration_ms: duration_ms(),
        },
        Attempt::Cancelled => UploadRunResult::Failure {
            reason: UploadFailure::Cancelled,
            output: None,
            duration_ms: duration_ms(),
        },
        Attempt::Crash(detail) => UploadRunResult::Failure {
            reason: UploadFailure::Crash,
            output: Some(format!("Task crashed: {detail}")),
            duration_ms: duration_ms(),
        },
        Attempt::Failure(UploadFailure::PortNotFound, first_output) => {
            // Single retry after a short delay; any second failure reports
            // port_not_found with the FIRST attempt's output.
            progress(0, "Port not found, retrying...");
            if !sleep_cancelable(timings.port_retry_delay, timings.poll_interval, cancel) {
                return UploadRunResult::Failure {
                    reason: UploadFailure::Cancelled,
                    output: None,
                    duration_ms: duration_ms(),
                };
            }
            match attempt_upload(
                &context,
                upload.config,
                &upload_port,
                upload.config.speed,
                &slot,
            ) {
                Attempt::Success(output) => UploadRunResult::Success {
                    output,
                    duration_ms: duration_ms(),
                },
                _ => UploadRunResult::Failure {
                    reason: UploadFailure::PortNotFound,
                    output: Some(first_output),
                    duration_ms: duration_ms(),
                },
            }
        }
        Attempt::Failure(UploadFailure::BootloaderNotResponding, first_output) => {
            // Alternate baud rates for old-bootloader Nanos; exhaustion keeps
            // the FIRST attempt's output.
            for baud_rate in retryable_baud_rates(&upload.config.protocol, upload.config.speed) {
                progress(0, &format!("Retrying at {baud_rate} baud..."));
                if cancel.is_cancelled() {
                    return UploadRunResult::Failure {
                        reason: UploadFailure::Cancelled,
                        output: None,
                        duration_ms: duration_ms(),
                    };
                }
                match attempt_upload(&context, upload.config, &upload_port, baud_rate, &slot) {
                    Attempt::Success(output) => {
                        return UploadRunResult::Success {
                            output,
                            duration_ms: duration_ms(),
                        }
                    }
                    Attempt::Failure(UploadFailure::BootloaderNotResponding, _) => continue,
                    Attempt::Failure(reason, output) => {
                        return UploadRunResult::Failure {
                            reason,
                            output: Some(output),
                            duration_ms: duration_ms(),
                        }
                    }
                    Attempt::Cancelled => {
                        return UploadRunResult::Failure {
                            reason: UploadFailure::Cancelled,
                            output: None,
                            duration_ms: duration_ms(),
                        }
                    }
                    Attempt::Crash(detail) => {
                        return UploadRunResult::Failure {
                            reason: UploadFailure::Crash,
                            output: Some(format!("Task crashed: {detail}")),
                            duration_ms: duration_ms(),
                        }
                    }
                }
            }
            UploadRunResult::Failure {
                reason: UploadFailure::BootloaderNotResponding,
                output: Some(first_output),
                duration_ms: duration_ms(),
            }
        }
        Attempt::Failure(reason, output) => UploadRunResult::Failure {
            reason,
            output: Some(output),
            duration_ms: duration_ms(),
        },
    }
}

struct ManagerShared {
    arbiter: Arc<ResourceArbiter>,
    transport: Arc<dyn SerialTransport>,
    tooling: UploadTooling,
    timings: UploadTimings,
    history: Arc<dyn UploadHistoryPort>,
    on_event: Option<UploadEventSink>,
    reconnect: Option<ReconnectHook>,
    serial_ownership: Option<Arc<dyn UploadSerialOwnership>>,
    pending_cleanup: Mutex<Vec<UploadInfo>>,
}

impl ManagerShared {
    fn emit(&self, event: UploadEvent) {
        if let Some(sink) = &self.on_event {
            sink(&event);
        }
    }
}

#[derive(Default)]
struct ManagerState {
    current: Option<CurrentUpload>,
    terminal: Option<TerminalRecord>,
}

struct TerminalWatcher {
    state: Mutex<ManagerState>,
    changed: Condvar,
}

struct CurrentUpload {
    in_flight: InFlight,
    worker: Option<JoinHandle<()>>,
    watchdog: Option<JoinHandle<()>>,
}

#[derive(Clone)]
struct InFlight {
    info: UploadInfo,
    cancel: UploadCancelHandle,
    child: Arc<ChildSlot>,
}

struct TerminalRecord {
    upload_id: String,
    outcome: UploadOutcome,
}

fn upload_active(state: &ManagerState, upload_id: &str) -> bool {
    state
        .current
        .as_ref()
        .map(|current| current.in_flight.info.upload_id.as_str())
        == Some(upload_id)
}

fn generate_upload_id() -> String {
    // 8 random bytes, lowercase hex — `:crypto.strong_rand_bytes(8)`.
    let mut bytes = [0u8; 8];
    getrandom::fill(&mut bytes).expect("system randomness unavailable");
    bytes.iter().map(|byte| format!("{byte:02x}")).collect()
}

fn duration_since(start: Instant) -> u64 {
    start.elapsed().as_millis() as u64
}

fn panic_message(payload: &(dyn std::any::Any + Send)) -> String {
    if let Some(text) = payload.downcast_ref::<&str>() {
        (*text).to_string()
    } else if let Some(text) = payload.downcast_ref::<String>() {
        text.clone()
    } else {
        "unknown panic".to_string()
    }
}

/// Terminal sequence shared by every outcome: release the port lease, run the
/// reconnect hook, record history, broadcast, then publish the terminal
/// outcome. The Elixir manager releases upload access before updating
/// history, and its timeout handler records `cancelled` while broadcasting
/// both `cancelled` and `timeout` failures.
fn finalize_upload(
    shared: &Arc<ManagerShared>,
    watcher: &TerminalWatcher,
    info: &UploadInfo,
    cancel: &UploadCancelHandle,
    result: UploadRunResult,
) -> UploadOutcome {
    let cleanup = shared.serial_ownership.as_ref().map_or(Ok(()), |owner| {
        owner.finish(info.lease, &info.port, info.generation)
    });
    let result = match cleanup {
        Ok(()) => match shared.arbiter.release(info.lease) {
            Ok(()) => result,
            Err(error) => {
                shared
                    .pending_cleanup
                    .lock()
                    .expect("upload cleanup poisoned")
                    .push(info.clone());
                UploadRunResult::Failure {
                    reason: UploadFailure::Crash,
                    output: Some(format!("firmware lease cleanup incomplete: {error:?}")),
                    duration_ms: duration_since(info.started_at),
                }
            }
        },
        Err(error) => {
            shared
                .pending_cleanup
                .lock()
                .expect("upload cleanup poisoned")
                .push(info.clone());
            UploadRunResult::Failure {
                reason: UploadFailure::Crash,
                output: Some(format!("serial handoff cleanup incomplete: {error}")),
                duration_ms: duration_since(info.started_at),
            }
        }
    };
    let cancelled_event = || UploadEvent::Failed {
        upload_id: info.upload_id.clone(),
        reason: UploadFailure::Cancelled,
        message: "Upload cancelled by user".to_string(),
    };
    let outcome = match result {
        UploadRunResult::Success {
            output,
            duration_ms,
        } => {
            let _ = shared
                .history
                .record_completed(&info.upload_id, &output, duration_ms);
            shared.emit(UploadEvent::Completed {
                upload_id: info.upload_id.clone(),
                duration_ms,
            });
            UploadOutcome {
                upload_id: info.upload_id.clone(),
                status: UploadStatus::Completed,
                reason: None,
                message: None,
                duration_ms,
            }
        }
        UploadRunResult::Failure {
            reason: UploadFailure::Cancelled,
            ..
        } => {
            let duration_ms = duration_since(info.started_at);
            let _ = shared
                .history
                .record_cancelled(&info.upload_id, duration_ms);
            if cancel.kind() == Some(CancelKind::Timeout) {
                shared.emit(cancelled_event());
                let message = UploadFailure::Timeout.friendly_message();
                shared.emit(UploadEvent::Failed {
                    upload_id: info.upload_id.clone(),
                    reason: UploadFailure::Timeout,
                    message: message.clone(),
                });
                UploadOutcome {
                    upload_id: info.upload_id.clone(),
                    status: UploadStatus::Cancelled,
                    reason: Some(UploadFailure::Timeout),
                    message: Some(message),
                    duration_ms,
                }
            } else {
                shared.emit(cancelled_event());
                UploadOutcome {
                    upload_id: info.upload_id.clone(),
                    status: UploadStatus::Cancelled,
                    reason: Some(UploadFailure::Cancelled),
                    message: Some("Upload cancelled by user".to_string()),
                    duration_ms,
                }
            }
        }
        UploadRunResult::Failure {
            reason: UploadFailure::Crash,
            output,
            ..
        } => {
            let duration_ms = duration_since(info.started_at);
            let detail = output.unwrap_or_else(|| "Task crashed".to_string());
            let _ = shared
                .history
                .record_failed(&info.upload_id, &detail, None, duration_ms);
            let message = UploadFailure::Crash.friendly_message();
            shared.emit(UploadEvent::Failed {
                upload_id: info.upload_id.clone(),
                reason: UploadFailure::Crash,
                message: message.clone(),
            });
            UploadOutcome {
                upload_id: info.upload_id.clone(),
                status: UploadStatus::Failed,
                reason: Some(UploadFailure::Crash),
                message: Some(message),
                duration_ms,
            }
        }
        UploadRunResult::Failure { reason, output, .. } => {
            let duration_ms = duration_since(info.started_at);
            let _ = shared.history.record_failed(
                &info.upload_id,
                reason.error_key(),
                output.as_deref(),
                duration_ms,
            );
            let message = reason.friendly_message();
            shared.emit(UploadEvent::Failed {
                upload_id: info.upload_id.clone(),
                reason: reason.clone(),
                message: message.clone(),
            });
            UploadOutcome {
                upload_id: info.upload_id.clone(),
                status: UploadStatus::Failed,
                reason: Some(reason),
                message: Some(message),
                duration_ms,
            }
        }
    };
    // Keep the delayed reconnect on the owned upload worker. Terminal
    // acknowledgement follows this hook, so cancellation/shutdown cannot
    // leave a detached timer that scans after serial teardown. History and
    // completion events above remain visible during the legacy 500ms delay.
    if shared
        .pending_cleanup
        .lock()
        .expect("upload cleanup poisoned")
        .is_empty()
    {
        if let Some(hook) = &shared.reconnect {
            thread::sleep(shared.timings.reconnect_delay);
            hook(&info.port);
        }
    }
    let mut state = watcher.state.lock().expect("upload manager state poisoned");
    if upload_active(&state, &info.upload_id) {
        state.current = None;
    }
    state.terminal = Some(TerminalRecord {
        upload_id: info.upload_id.clone(),
        outcome: outcome.clone(),
    });
    watcher.changed.notify_all();
    outcome
}

fn run_worker(
    shared: Arc<ManagerShared>,
    watcher: Arc<TerminalWatcher>,
    in_flight: InFlight,
    upload_config: UploadConfig,
    environment: String,
    hex_path: PathBuf,
) {
    let info = in_flight.info.clone();
    let progress = |percent: u32, message: &str| {
        shared.emit(UploadEvent::Progress {
            upload_id: info.upload_id.clone(),
            percent,
            message: message.to_string(),
        });
    };
    let run = || {
        if let Some(owner) = &shared.serial_ownership {
            if let Err(error) =
                owner.prepare(info.lease, &info.port, info.generation, &in_flight.cancel)
            {
                return UploadRunResult::Failure {
                    reason: UploadFailure::Crash,
                    output: Some(format!("serial handoff failed: {error}")),
                    duration_ms: duration_since(info.started_at),
                };
            }
        }
        run_device_upload(
            &*shared.transport,
            &shared.tooling,
            &shared.timings,
            DeviceUpload {
                port: &info.port,
                environment: &environment,
                hex_path: &hex_path,
                config: &upload_config,
            },
            &in_flight.cancel,
            &progress,
        )
    };
    let result = match std::panic::catch_unwind(std::panic::AssertUnwindSafe(run)) {
        Ok(result) => result,
        Err(payload) => UploadRunResult::Failure {
            reason: UploadFailure::Crash,
            output: Some(format!("Task crashed: {}", panic_message(&*payload))),
            duration_ms: duration_since(info.started_at),
        },
    };
    finalize_upload(&shared, &watcher, &info, &in_flight.cancel, result);
}

fn spawn_watchdog(
    watcher: Arc<TerminalWatcher>,
    in_flight: InFlight,
    timeout: Duration,
) -> std::io::Result<JoinHandle<()>> {
    let upload_id = in_flight.info.upload_id.clone();
    thread::Builder::new()
        .name(format!("firmware-upload-watchdog-{upload_id}"))
        .spawn(move || {
            let deadline = Instant::now() + timeout;
            let mut state = watcher.state.lock().expect("upload manager state poisoned");
            loop {
                if !upload_active(&state, &upload_id) {
                    return;
                }
                let now = Instant::now();
                if now >= deadline {
                    break;
                }
                let (next, _) = watcher
                    .changed
                    .wait_timeout(state, deadline.saturating_duration_since(now))
                    .expect("upload manager state poisoned");
                state = next;
            }
            // `{:upload_timeout, upload_id}`: cancel like a user cancellation,
            // then also broadcast the timeout failure. The worker performs
            // the shared cleanup (lease release + history + broadcasts).
            in_flight.cancel.request(CancelKind::Timeout);
            drop(state);
            in_flight.child.kill_child();
            let deadline = Instant::now() + timeout + Duration::from_secs(5);
            let mut state = watcher.state.lock().expect("upload manager state poisoned");
            while upload_active(&state, &upload_id) {
                let now = Instant::now();
                if now >= deadline {
                    return;
                }
                let (next, _) = watcher
                    .changed
                    .wait_timeout(state, deadline.saturating_duration_since(now))
                    .expect("upload manager state poisoned");
                state = next;
            }
        })
}

/// Owns at most one in-flight upload and its exclusive port lease. Mirrors
/// `Trenino.Firmware.UploadManager`: a single upload at a time, port
/// reservation through the shared resource arbiter (fail-closed when busy),
/// cancellation with child kill/reap, a watchdog timeout, and history
/// recording through [`UploadHistoryPort`]. Clones share the same state.
#[derive(Clone)]
pub struct UploadManager {
    shared: Arc<ManagerShared>,
    watcher: Arc<TerminalWatcher>,
    /// Held for its [`Drop`] alone; never read directly.
    #[allow(dead_code)]
    lifecycle: Arc<ManagerLifecycle>,
}

/// Shares the drop-cleanup across clones: the reap below runs exactly once,
/// when the last [`UploadManager`] handle is released — dropping a clone
/// handed to another thread never cancels a live upload.
struct ManagerLifecycle {
    watcher: Arc<TerminalWatcher>,
}

impl Drop for ManagerLifecycle {
    /// Cancel any in-flight upload, kill and reap its child, and join the
    /// lifecycle threads — dropping the last manager handle can never leak a
    /// running avrdude process or an orphaned port lease.
    fn drop(&mut self) {
        let current = self
            .watcher
            .state
            .lock()
            .expect("upload manager state poisoned")
            .current
            .take();
        let Some(mut current) = current else {
            return;
        };
        current.in_flight.cancel.request(CancelKind::User);
        current.in_flight.child.kill_child();
        if let Some(worker) = current.worker.take() {
            let _ = worker.join();
        }
        if let Some(watchdog) = current.watchdog.take() {
            let _ = watchdog.join();
        }
    }
}

impl UploadManager {
    pub fn new(
        arbiter: Arc<ResourceArbiter>,
        transport: Arc<dyn SerialTransport>,
        tooling: UploadTooling,
        timings: UploadTimings,
        history: Arc<dyn UploadHistoryPort>,
        hooks: UploadHooks,
    ) -> Self {
        let watcher = Arc::new(TerminalWatcher {
            state: Mutex::new(ManagerState::default()),
            changed: Condvar::new(),
        });
        Self {
            shared: Arc::new(ManagerShared {
                arbiter,
                transport,
                tooling,
                timings,
                history,
                on_event: hooks.on_event,
                reconnect: hooks.reconnect,
                serial_ownership: None,
                pending_cleanup: Mutex::new(Vec::new()),
            }),
            lifecycle: Arc::new(ManagerLifecycle {
                watcher: watcher.clone(),
            }),
            watcher,
        }
    }

    /// Construct a manager attached to the scanner's exclusive handoff owner.
    pub fn new_with_serial_ownership(
        arbiter: Arc<ResourceArbiter>,
        transport: Arc<dyn SerialTransport>,
        tooling: UploadTooling,
        timings: UploadTimings,
        history: Arc<dyn UploadHistoryPort>,
        hooks: UploadHooks,
        ownership: Arc<dyn UploadSerialOwnership>,
    ) -> Self {
        let mut manager = Self::new(arbiter, transport, tooling, timings, history, hooks);
        // Fresh constructor; no handles to shared state have escaped.
        Arc::get_mut(&mut manager.shared)
            .expect("fresh upload manager")
            .serial_ownership = Some(ownership);
        manager
    }

    /// Retry uncertain serial cleanup before hardware/network teardown. A
    /// failure retains the lease and record for the next shutdown attempt.
    pub fn retry_cleanup(&self) -> Result<(), String> {
        let mut pending = self
            .shared
            .pending_cleanup
            .lock()
            .map_err(|_| "upload cleanup poisoned")?;
        let mut failures = Vec::new();
        pending.retain(|info| {
            let result = self
                .shared
                .serial_ownership
                .as_ref()
                .map_or(Ok(()), |owner| {
                    owner.finish(info.lease, &info.port, info.generation)
                })
                .and_then(|()| {
                    self.shared
                        .arbiter
                        .release(info.lease)
                        .map_err(|e| format!("{e:?}"))
                });
            if let Err(error) = result {
                failures.push(error);
                true
            } else {
                false
            }
        });
        if failures.is_empty() {
            Ok(())
        } else {
            Err(failures.join("; "))
        }
    }

    /// Start an upload. Errors before any state is created, exactly like the
    /// Elixir `handle_call({:start_upload, …})` ordering: single-flight
    /// check, downloaded-firmware check, then port reservation.
    pub fn start_upload(&self, request: UploadRequest) -> Result<String, UploadStartError> {
        let mut state = self
            .watcher
            .state
            .lock()
            .expect("upload manager state poisoned");
        if state.current.is_some() {
            return Err(UploadStartError::UploadInProgress);
        }
        if !request.hex_path.is_file() {
            return Err(UploadStartError::FirmwareNotDownloaded);
        }
        let lease = self
            .shared
            .arbiter
            .acquire(LeaseKind::Firmware {
                port: request.port.clone(),
                generation: request.generation,
            })
            .map_err(UploadStartError::Lease)?;
        let upload_id = generate_upload_id();
        let record = UploadStartRecord {
            upload_id: upload_id.clone(),
            port: request.port.clone(),
            board_type: request.environment.clone(),
            firmware_file_id: request.firmware_file_id,
        };
        if let Err(error) = self.shared.history.record_started(&record) {
            let _ = self.shared.arbiter.release(lease);
            return Err(UploadStartError::History(error));
        }
        let info = UploadInfo {
            upload_id: upload_id.clone(),
            port: request.port.clone(),
            environment: request.environment.clone(),
            firmware_file_id: request.firmware_file_id,
            lease,
            generation: request.generation,
            started_at: Instant::now(),
        };
        self.shared.emit(UploadEvent::Started {
            upload_id: upload_id.clone(),
            port: request.port.clone(),
            environment: request.environment.clone(),
        });
        let in_flight = InFlight {
            info,
            cancel: UploadCancelHandle::new(),
            child: Arc::new(ChildSlot::default()),
        };
        let worker = {
            let shared = Arc::clone(&self.shared);
            let watcher = Arc::clone(&self.watcher);
            let in_flight = in_flight.clone();
            let upload_config = request.upload_config.clone();
            let environment = request.environment.clone();
            let hex_path = request.hex_path.clone();
            thread::Builder::new()
                .name(format!("firmware-upload-{upload_id}"))
                .spawn(move || {
                    run_worker(
                        shared,
                        watcher,
                        in_flight,
                        upload_config,
                        environment,
                        hex_path,
                    );
                })
        };
        let worker = match worker {
            Ok(handle) => Some(handle),
            Err(error) => {
                in_flight.cancel.request(CancelKind::User);
                in_flight.child.kill_child();
                let _ = self.shared.arbiter.release(lease);
                return Err(UploadStartError::SpawnFailed(error.to_string()));
            }
        };
        match spawn_watchdog(
            Arc::clone(&self.watcher),
            in_flight.clone(),
            self.shared.timings.upload_timeout,
        ) {
            Ok(watchdog) => {
                state.current = Some(CurrentUpload {
                    in_flight,
                    worker,
                    watchdog: Some(watchdog),
                });
                Ok(upload_id)
            }
            Err(error) => {
                in_flight.cancel.request(CancelKind::User);
                in_flight.child.kill_child();
                drop(state);
                if let Some(worker) = worker {
                    let _ = worker.join();
                }
                let _ = self.shared.arbiter.release(lease);
                Err(UploadStartError::SpawnFailed(error.to_string()))
            }
        }
    }

    /// Cancel the current upload. Kills and reaps the avrdude child and waits
    /// for the worker's terminal cleanup, so the port reservation is released
    /// once this returns.
    pub fn cancel_upload(&self, upload_id: &str) -> Result<(), UploadCancelError> {
        let in_flight = {
            let state = self
                .watcher
                .state
                .lock()
                .expect("upload manager state poisoned");
            match &state.current {
                Some(current) if current.in_flight.info.upload_id == upload_id => {
                    current.in_flight.clone()
                }
                _ => {
                    return if self
                        .shared
                        .pending_cleanup
                        .lock()
                        .expect("upload cleanup poisoned")
                        .iter()
                        .any(|info| info.upload_id == upload_id)
                    {
                        Err(UploadCancelError::CleanupIncomplete)
                    } else {
                        Err(UploadCancelError::NotFound)
                    };
                }
            }
        };
        in_flight.cancel.request(CancelKind::User);
        in_flight.child.kill_child();
        let deadline = Instant::now() + self.shared.timings.cleanup_timeout;
        let mut state = self
            .watcher
            .state
            .lock()
            .expect("upload manager state poisoned");
        while upload_active(&state, upload_id) {
            let now = Instant::now();
            if now >= deadline {
                // Cancellation was requested and the child is dead; the
                // worker is still unwinding its terminal cleanup.
                return Err(UploadCancelError::Timeout);
            }
            let (next, _) = self
                .watcher
                .changed
                .wait_timeout(state, deadline.saturating_duration_since(now))
                .expect("upload manager state poisoned");
            state = next;
        }
        drop(state);
        if self
            .shared
            .pending_cleanup
            .lock()
            .expect("upload cleanup poisoned")
            .iter()
            .any(|info| info.upload_id == upload_id)
        {
            Err(UploadCancelError::CleanupIncomplete)
        } else {
            Ok(())
        }
    }

    /// The current in-flight upload, if any.
    pub fn current_upload(&self) -> Option<UploadInfo> {
        self.watcher
            .state
            .lock()
            .expect("upload manager state poisoned")
            .current
            .as_ref()
            .map(|current| current.in_flight.info.clone())
    }

    /// Block until the given upload reaches a terminal outcome (or `timeout`
    /// elapses). Only the most recent terminal outcome is retained.
    pub fn wait_for_completion(&self, upload_id: &str, timeout: Duration) -> Option<UploadOutcome> {
        let deadline = Instant::now() + timeout;
        let mut state = self
            .watcher
            .state
            .lock()
            .expect("upload manager state poisoned");
        loop {
            if let Some(record) = &state.terminal {
                if record.upload_id == upload_id {
                    return Some(record.outcome.clone());
                }
            }
            let now = Instant::now();
            if now >= deadline {
                return None;
            }
            let (next, _) = self
                .watcher
                .changed
                .wait_timeout(state, deadline.saturating_duration_since(now))
                .expect("upload manager state poisoned");
            state = next;
        }
    }
}
