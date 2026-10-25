//! Firmware upload lifecycle tests.
//!
//! Mirrors the Elixir oracle suites:
//! * `test/trenino/firmware/uploader_test.exs` — error classification,
//!   friendly messages, retryable baud rates.
//! * `test/trenino/firmware/upload_flow_test.exs` — end-to-end device upload
//!   flows through fake avrdude transcripts and fake serial enumeration.
//! * `test/trenino/firmware/upload_manager_test.exs` — cancellation and
//!   timeout killing the live avrdude child, releasing the port, and
//!   broadcasting failures.
//!
//! avrdude is faked with deterministic `/bin/sh` scripts from a temp
//! directory; serial ports are a scripted fake transport. No real hardware,
//! user database, or network is touched.

#![cfg(unix)]

use std::io;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use tempfile::TempDir;
use trenino_core::firmware::{Programmer, UploadConfig};
use trenino_core::EntityId;
use trenino_runtime::firmware::{
    parse_error_output, retryable_baud_rates, DeviceUpload, UploadCancelHandle, UploadEvent,
    UploadFailure, UploadHooks, UploadHistoryPort, UploadManager, UploadRequest, UploadRunResult,
    UploadStartError, UploadStartRecord, UploadStatus, UploadTimings, UploadTooling,
};
use trenino_runtime::hardware::transport::{SerialIo, SerialTransport};
use trenino_runtime::resource::{LeaseKind, ResourceArbiter, ResourceConsumers, ResourceError};

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

struct NullPort;
impl SerialIo for NullPort {
    fn read(&mut self, _buffer: &mut [u8]) -> io::Result<usize> {
        Err(io::ErrorKind::TimedOut.into())
    }
    fn write_all(&mut self, _bytes: &[u8]) -> io::Result<()> {
        Ok(())
    }
    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}

/// Scripted serial transport: `enumerate` replays a port-list sequence (the
/// last entry repeats), `open` records every (port, baud) pair and can be
/// told to fail the 1200-bps touch.
#[derive(Clone, Default)]
struct FakeSerial {
    sequence: Arc<Mutex<Vec<Vec<String>>>>,
    opens: Arc<Mutex<Vec<(String, u32)>>>,
    fail_open: Arc<AtomicBool>,
    panic_on_enumerate: Arc<AtomicBool>,
}

impl FakeSerial {
    fn with_sequence(sequence: Vec<Vec<String>>) -> Self {
        Self {
            sequence: Arc::new(Mutex::new(sequence)),
            ..Self::default()
        }
    }
}

impl SerialTransport for FakeSerial {
    fn enumerate(&self) -> io::Result<Vec<String>> {
        if self.panic_on_enumerate.load(Ordering::SeqCst) {
            panic!("transport exploded");
        }
        let mut sequence = self.sequence.lock().unwrap();
        if sequence.len() > 1 {
            Ok(sequence.remove(0))
        } else {
            Ok(sequence.first().cloned().unwrap_or_default())
        }
    }

    fn open(&self, port: &str, baud: u32, _timeout: Duration) -> io::Result<Box<dyn SerialIo>> {
        self.opens.lock().unwrap().push((port.to_string(), baud));
        if self.fail_open.load(Ordering::SeqCst) {
            return Err(io::Error::new(io::ErrorKind::PermissionDenied, "busy"));
        }
        Ok(Box::new(NullPort))
    }
}

#[derive(Clone, Debug, PartialEq)]
enum HistoryCall {
    Started {
        upload_id: String,
        port: String,
        board_type: String,
        firmware_file_id: EntityId,
    },
    Completed {
        upload_id: String,
        output: String,
        duration_ms: u64,
    },
    Failed {
        upload_id: String,
        error_message: String,
        output: Option<String>,
        duration_ms: u64,
    },
    Cancelled {
        upload_id: String,
        duration_ms: u64,
    },
}

#[derive(Default)]
struct HistoryFake {
    calls: Mutex<Vec<HistoryCall>>,
}
impl UploadHistoryPort for HistoryFake {
    fn record_started(&self, record: &UploadStartRecord) -> Result<(), String> {
        self.calls.lock().unwrap().push(HistoryCall::Started {
            upload_id: record.upload_id.clone(),
            port: record.port.clone(),
            board_type: record.board_type.clone(),
            firmware_file_id: record.firmware_file_id,
        });
        Ok(())
    }
    fn record_completed(
        &self,
        upload_id: &str,
        avrdude_output: &str,
        duration_ms: u64,
    ) -> Result<(), String> {
        self.calls.lock().unwrap().push(HistoryCall::Completed {
            upload_id: upload_id.to_string(),
            output: avrdude_output.to_string(),
            duration_ms,
        });
        Ok(())
    }
    fn record_failed(
        &self,
        upload_id: &str,
        error_message: &str,
        avrdude_output: Option<&str>,
        duration_ms: u64,
    ) -> Result<(), String> {
        self.calls.lock().unwrap().push(HistoryCall::Failed {
            upload_id: upload_id.to_string(),
            error_message: error_message.to_string(),
            output: avrdude_output.map(str::to_string),
            duration_ms,
        });
        Ok(())
    }
    fn record_cancelled(&self, upload_id: &str, duration_ms: u64) -> Result<(), String> {
        self.calls.lock().unwrap().push(HistoryCall::Cancelled {
            upload_id: upload_id.to_string(),
            duration_ms,
        });
        Ok(())
    }
}

#[derive(Default)]
struct EventLog {
    events: Mutex<Vec<UploadEvent>>,
}

#[derive(Default)]
struct ConsumerLog {
    calls: Mutex<Vec<&'static str>>,
}
impl ResourceConsumers for ConsumerLog {
    fn suspend_actuation(&self, _port: &str) -> Result<(), String> {
        self.calls.lock().unwrap().push("suspend");
        Ok(())
    }
    fn cancel_calibration(&self, _port: &str) -> Result<(), String> {
        self.calls.lock().unwrap().push("cancel-calibration");
        Ok(())
    }
    fn source_lost(&self, _port: &str, _generation: u64) -> Result<(), String> {
        self.calls.lock().unwrap().push("source-lost");
        Ok(())
    }
    fn resume_after_fresh_sample(&self, _port: &str) -> Result<(), String> {
        self.calls.lock().unwrap().push("resume-fresh");
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

fn write_executable(dir: &TempDir, name: &str, body: &str) -> PathBuf {
    let path = dir.path().join(name);
    std::fs::write(&path, body).unwrap();
    use std::os::unix::fs::PermissionsExt;
    std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o755)).unwrap();
    path
}

fn hex_file(dir: &TempDir) -> PathBuf {
    let path = dir.path().join("firmware.hex");
    std::fs::write(&path, ":00000001FF\n").unwrap();
    path
}

const SUCCESS_BODY: &str = "#!/bin/sh
echo 'avrdude: Version 7.1, compiled on Mar 10 2023 at 12:30:00'
echo 'Reading | ####################                   | 42% 0.10s'
echo 'Writing | ####################                   | 50% 0.42s'
echo 'Verifying | ##################################   | 100% 0.15s'
echo 'avrdude done.  Thank you.'
exit 0
";

const SIGNATURE_MISMATCH_BODY: &str = "#!/bin/sh
echo 'avrdude: AVR device initialized and ready to accept instructions'
echo 'avrdude: device signature = 0x1e9514 (probably m32u4)'
echo 'avrdude: Expected signature for ATmega328P is 1E 95 0F'
exit 1
";

const VERIFICATION_ERROR_BODY: &str = "#!/bin/sh
echo 'avrdude: verification error, first mismatch at byte 0x0100'
echo '         0x3c != 0x1c'
exit 1
";

const ARGS_ECHO_BODY: &str = "#!/bin/sh
echo \"args: $*\"
echo 'avrdude done.  Thank you.'
exit 0
";

/// Fails at 115200 baud with the old-bootloader Nano transcript, succeeds at
/// any other rate — mirrors `AvrdudeFixtures.old_bootloader_nano_115200_fail`
/// combined with a baud-aware stub (upload_flow_test "baud-rate retry").
const BAUD_AWARE_BODY: &str = "#!/bin/sh
baud=''
prev=''
for arg in \"$@\"; do
  if [ \"$prev\" = '-b' ]; then baud=\"$arg\"; fi
  prev=\"$arg\"
done
if [ \"$baud\" = '115200' ]; then
  echo 'avrdude: stk500_getsync() attempt 1 of 10: not in sync: resp=0x00'
  echo 'avrdude: stk500_recv(): programmer is not responding'
  exit 1
fi
echo 'Writing | ################################## | 100% 0.10s'
echo 'avrdude done.  Thank you.'
exit 0
";

/// Prints `<line>` annotated with a per-script invocation counter, exits 1.
fn counter_script(dir: &TempDir, counter: &Path, line: &str) -> PathBuf {
    let body = format!(
        "#!/bin/sh\n\
         n=$(cat \"{}\" 2>/dev/null || echo 0)\n\
         n=$((n+1))\n\
         echo $n > \"{}\"\n\
         echo \"avrdude attempt $n: {line}\"\n\
         exit 1\n",
        counter.display(),
        counter.display()
    );
    write_executable(dir, "avrdude-counter", &body)
}

/// Writes its own pid then replaces itself with one long `sleep`, so a kill
/// reaps exactly this pid while the child idles (no CPU burn, no
/// grandchildren holding the output pipes).
fn blocking_script(dir: &TempDir, pid_file: &Path) -> PathBuf {
    let body = format!(
        "#!/bin/sh\necho $$ > \"{}\"\nexec sleep 30\n",
        pid_file.display()
    );
    write_executable(dir, "avrdude-block", &body)
}



fn uno_config() -> UploadConfig {
    UploadConfig {
        protocol: Programmer::Arduino,
        mcu: "atmega328p".to_string(),
        speed: 115_200,
        requires_1200bps_touch: false,
    }
}

fn nano_config() -> UploadConfig {
    uno_config()
}

fn micro_config() -> UploadConfig {
    UploadConfig {
        protocol: Programmer::Avr109,
        mcu: "atmega32u4".to_string(),
        speed: 57_600,
        requires_1200bps_touch: true,
    }
}

fn fast_timings() -> UploadTimings {
    UploadTimings {
        bootloader_initial_wait: Duration::from_millis(5),
        bootloader_poll_interval: Duration::from_millis(10),
        bootloader_poll_deadline: Duration::from_millis(400),
        port_retry_delay: Duration::from_millis(30),
        serial_open_timeout: Duration::from_millis(200),
        poll_interval: Duration::from_millis(2),
        ..UploadTimings::default()
    }
}

fn run_direct(
    transport: &FakeSerial,
    tooling: &UploadTooling,
    timings: &UploadTimings,
    port: &str,
    environment: &str,
    hex_path: &Path,
    config: &UploadConfig,
    progress: &dyn Fn(u32, &str),
) -> UploadRunResult {
    trenino_runtime::firmware::run_device_upload(
        transport,
        tooling,
        timings,
        DeviceUpload {
            port,
            environment,
            hex_path,
            config,
        },
        &UploadCancelHandle::new(),
        progress,
    )
}

fn no_progress(_percent: u32, _message: &str) {}

fn wait_for_file(path: &Path, timeout: Duration) -> String {
    let deadline = Instant::now() + timeout;
    loop {
        if let Ok(content) = std::fs::read_to_string(path) {
            return content.trim().to_string();
        }
        assert!(
            Instant::now() < deadline,
            "fake avrdude never wrote {}",
            path.display()
        );
        thread::sleep(Duration::from_millis(2));
    }
}

fn process_alive(pid: u32) -> bool {
    Command::new("/bin/sh")
        .arg("-c")
        .arg(format!("kill -0 {pid} 2>/dev/null"))
        .status()
        .unwrap()
        .success()
}

fn manager_fixture(
    avrdude: PathBuf,
    timings: UploadTimings,
    transport: FakeSerial,
) -> (
    UploadManager,
    Arc<ResourceArbiter>,
    Arc<HistoryFake>,
    Arc<EventLog>,
    Arc<Mutex<Vec<String>>>,
) {
    let arbiter = Arc::new(ResourceArbiter::new(Arc::new(ConsumerLog::default())));
    let history = Arc::new(HistoryFake::default());
    let events = Arc::new(EventLog::default());
    let reconnect = Arc::new(Mutex::new(Vec::new()));
    let manager = UploadManager::new(
        arbiter.clone(),
        Arc::new(transport),
        UploadTooling {
            avrdude_path: avrdude,
            avrdude_conf: None,
        },
        timings,
        history.clone(),
        UploadHooks {
            on_event: Some({
                let events = events.clone();
                Arc::new(move |event: &UploadEvent| {
                    events.events.lock().unwrap().push(event.clone());
                })
            }),
            reconnect: Some({
                let reconnect = reconnect.clone();
                Arc::new(move |port: &str| {
                    reconnect.lock().unwrap().push(port.to_string());
                })
            }),
        },
    );
    (manager, arbiter, history, events, reconnect)
}

fn upload_request(port: &str, hex_path: &Path, config: &UploadConfig) -> UploadRequest {
    UploadRequest {
        port: port.to_string(),
        environment: "uno".to_string(),
        firmware_file_id: EntityId(7),
        hex_path: hex_path.to_path_buf(),
        upload_config: config.clone(),
        generation: 3,
    }
}

// ---------------------------------------------------------------------------
// Error classification — mirrors uploader_test.exs "parse_error_output/1"
// ---------------------------------------------------------------------------

#[test]
fn parses_avrdude_error_transcripts_like_the_oracle() {
    let cases = [
        (
            "avrdude: can't open device /dev/ttyUSB0: No such file",
            UploadFailure::PortNotFound,
        ),
        (
            "error: cannot open port /dev/ttyUSB0",
            UploadFailure::PortNotFound,
        ),
        (
            "avrdude: stk500_recv(): programmer is not responding",
            UploadFailure::BootloaderNotResponding,
        ),
        (
            "avrdude: stk500_getsync(): not in sync: resp=0x00",
            UploadFailure::BootloaderNotResponding,
        ),
        (
            "avrdude: stk500v2_recv(): not responding",
            UploadFailure::BootloaderNotResponding,
        ),
        (
            "avrdude: initialization failed, rc=-1",
            UploadFailure::BootloaderNotResponding,
        ),
        (
            "butterfly and AVR910 mode",
            UploadFailure::BootloaderNotResponding,
        ),
        (
            "avrdude: device signature = 0x1e950f",
            UploadFailure::WrongBoardType,
        ),
        (
            "avrdude: verification error, first mismatch at byte 0x0100",
            UploadFailure::VerificationFailed,
        ),
        (
            "[Timeout: avrdude did not respond within 2 minutes]",
            UploadFailure::Timeout,
        ),
        (
            "avrdude: ser_open(): permission denied accessing /dev/ttyUSB0",
            UploadFailure::PermissionDenied,
        ),
        (
            "some random error that doesn't match patterns",
            UploadFailure::UnknownError,
        ),
    ];
    for (output, expected) in cases {
        assert_eq!(parse_error_output(output), expected, "output: {output}");
    }
}

// Mirrors uploader_test.exs "retryable_baud_rates/2".
#[test]
fn retryable_baud_rates_match_the_oracle() {
    assert_eq!(
        retryable_baud_rates(&Programmer::Arduino, 115_200),
        vec![57_600]
    );
    assert_eq!(
        retryable_baud_rates(&Programmer::Arduino, 57_600),
        vec![115_200]
    );
    assert_eq!(retryable_baud_rates(&Programmer::Avrisp, 115_200), Vec::<u32>::new());
    assert_eq!(
        retryable_baud_rates(&Programmer::Arduino, 9_600),
        vec![57_600, 115_200]
    );
}

// Mirrors uploader_test.exs "error_message/1" spot checks.
#[test]
fn friendly_messages_match_the_oracle() {
    assert!(UploadFailure::PortNotFound
        .friendly_message()
        .starts_with("Device not found. Please check:"));
    assert_eq!(
        UploadFailure::HexFileNotFound.friendly_message(),
        "Firmware file not found. Please download the firmware first."
    );
    assert_eq!(
        UploadFailure::Cancelled.friendly_message(),
        "Upload cancelled by user"
    );
    assert_eq!(
        UploadFailure::Crash.friendly_message(),
        "Upload task crashed unexpectedly"
    );
    assert_eq!(
        UploadFailure::UnknownError.friendly_message(),
        "An unknown error occurred during upload. Please check the log for details."
    );
}

// ---------------------------------------------------------------------------
// Device upload flows — mirrors upload_flow_test.exs
// ---------------------------------------------------------------------------

// Mirrors upload_flow_test.exs "successful upload".
#[test]
fn successful_upload_returns_output_and_duration() {
    let dir = TempDir::new().unwrap();
    let avrdude = write_executable(&dir, "avrdude-ok", SUCCESS_BODY);
    let hex = hex_file(&dir);
    let result = run_direct(
        &FakeSerial::default(),
        &UploadTooling {
            avrdude_path: avrdude,
            avrdude_conf: None,
        },
        &fast_timings(),
        "COM3",
        "uno",
        &hex,
        &uno_config(),
        &no_progress,
    );
    let UploadRunResult::Success {
        output,
        duration_ms,
    } = result
    else {
        panic!("expected success, got {result:?}");
    };
    assert!(output.contains("avrdude done.  Thank you."));
    assert!(duration_ms < 10_000);
}

// Mirrors the argument inspection in upload_flow_test.exs baud stub plus the
// build_args contract (conf path, normalized MCU, -U flash:w:hex:i).
#[test]
fn avrdude_invocation_arguments_match_build_args() {
    let dir = TempDir::new().unwrap();
    let avrdude = write_executable(&dir, "avrdude-args", ARGS_ECHO_BODY);
    let conf = dir.path().join("avrdude.conf");
    std::fs::write(&conf, "").unwrap();
    let hex = hex_file(&dir);
    let result = run_direct(
        &FakeSerial::default(),
        &UploadTooling {
            avrdude_path: avrdude,
            avrdude_conf: Some(conf.clone()),
        },
        &fast_timings(),
        "COM5",
        "nanoatmega328",
        &hex,
        &nano_config(),
        &no_progress,
    );
    let UploadRunResult::Success { output, .. } = result else {
        panic!("expected success, got {result:?}");
    };
    let expected_tail = format!(
        "-c arduino -p m328p -P COM5 -b 115200 -D -U flash:w:{}:i -v",
        hex.display()
    );
    assert!(
        output.contains(&expected_tail),
        "args missing expected tail: {output}"
    );
    assert!(
        output.contains(&format!("-C {}", conf.display())),
        "args missing -C conf: {output}"
    );
}

// Mirrors upload_flow_test.exs "returns :wrong_board_type immediately on
// device signature mismatch".
#[test]
fn wrong_board_type_fails_immediately() {
    let dir = TempDir::new().unwrap();
    let avrdude = write_executable(&dir, "avrdude-sig", SIGNATURE_MISMATCH_BODY);
    let hex = hex_file(&dir);
    let result = run_direct(
        &FakeSerial::default(),
        &UploadTooling {
            avrdude_path: avrdude,
            avrdude_conf: None,
        },
        &fast_timings(),
        "COM3",
        "uno",
        &hex,
        &uno_config(),
        &no_progress,
    );
    assert_eq!(
        result,
        UploadRunResult::Failure {
            reason: UploadFailure::WrongBoardType,
            output: Some(
                "avrdude: AVR device initialized and ready to accept instructions\navrdude: device signature = 0x1e9514 (probably m32u4)\navrdude: Expected signature for ATmega328P is 1E 95 0F\n"
                    .to_string()
            ),
            duration_ms: result_duration(&result),
        }
    );
}

fn result_duration(result: &UploadRunResult) -> u64 {
    match result {
        UploadRunResult::Success { duration_ms, .. } => *duration_ms,
        UploadRunResult::Failure { duration_ms, .. } => *duration_ms,
    }
}

// Mirrors upload_flow_test.exs "returns :permission_denied immediately
// without retry" — the counter proves avrdude ran exactly once.
#[test]
fn permission_denied_fails_immediately_without_retry() {
    let dir = TempDir::new().unwrap();
    let counter = dir.path().join("counter");
    let avrdude = counter_script(&dir, &counter, "permission denied accessing /dev/ttyUSB0");
    let hex = hex_file(&dir);
    let result = run_direct(
        &FakeSerial::default(),
        &UploadTooling {
            avrdude_path: avrdude,
            avrdude_conf: None,
        },
        &fast_timings(),
        "COM3",
        "uno",
        &hex,
        &uno_config(),
        &no_progress,
    );
    let UploadRunResult::Failure {
        reason,
        output,
        ..
    } = result
    else {
        panic!("expected failure, got {result:?}");
    };
    assert_eq!(reason, UploadFailure::PermissionDenied);
    assert!(output.as_deref().unwrap().contains("permission denied"));
    assert_eq!(std::fs::read_to_string(&counter).unwrap().trim(), "1");
}

// Mirrors upload_flow_test.exs "returns :verification_failed immediately
// without retry".
#[test]
fn verification_failed_fails_immediately() {
    let dir = TempDir::new().unwrap();
    let avrdude = write_executable(&dir, "avrdude-verify", VERIFICATION_ERROR_BODY);
    let hex = hex_file(&dir);
    let result = run_direct(
        &FakeSerial::default(),
        &UploadTooling {
            avrdude_path: avrdude,
            avrdude_conf: None,
        },
        &fast_timings(),
        "COM3",
        "uno",
        &hex,
        &uno_config(),
        &no_progress,
    );
    let UploadRunResult::Failure { reason, .. } = result else {
        panic!("expected failure, got {result:?}");
    };
    assert_eq!(reason, UploadFailure::VerificationFailed);
}

// Mirrors upload_flow_test.exs "returns :hex_file_not_found when hex file
// does not exist".
#[test]
fn missing_hex_file_fails_with_hex_file_not_found() {
    let dir = TempDir::new().unwrap();
    let avrdude = write_executable(&dir, "avrdude-ok", SUCCESS_BODY);
    let missing = dir.path().join("nonexistent.hex");
    let result = run_direct(
        &FakeSerial::default(),
        &UploadTooling {
            avrdude_path: avrdude,
            avrdude_conf: None,
        },
        &fast_timings(),
        "COM3",
        "uno",
        &missing,
        &uno_config(),
        &no_progress,
    );
    let UploadRunResult::Failure {
        reason,
        output,
        ..
    } = result
    else {
        panic!("expected failure, got {result:?}");
    };
    assert_eq!(reason, UploadFailure::HexFileNotFound);
    assert!(output.as_deref().unwrap().contains("not found"));
}

// Mirrors upload_flow_test.exs "returns :unknown_device for unrecognised
// environment" — the DeviceRegistry drops unsupported programmers.
#[test]
fn unsupported_programmer_fails_with_unknown_device() {
    let dir = TempDir::new().unwrap();
    let avrdude = write_executable(&dir, "avrdude-ok", SUCCESS_BODY);
    let hex = hex_file(&dir);
    let config = UploadConfig {
        protocol: Programmer::Unsupported("esp32".to_string()),
        mcu: "esp32".to_string(),
        speed: 115_200,
        requires_1200bps_touch: false,
    };
    let result = run_direct(
        &FakeSerial::default(),
        &UploadTooling {
            avrdude_path: avrdude,
            avrdude_conf: None,
        },
        &fast_timings(),
        "COM3",
        "totally_unknown_board",
        &hex,
        &config,
        &no_progress,
    );
    assert_eq!(
        result,
        UploadRunResult::Failure {
            reason: UploadFailure::UnknownDevice,
            output: Some(
                "Unknown device environment: totally_unknown_board".to_string()
            ),
            duration_ms: result_duration(&result),
        }
    );
}

// Mirrors the {:error, :avrdude_not_found} path of Avrdude.executable_path/0;
// the relative path proves no PATH search fallback either.
#[test]
fn missing_or_relative_avrdude_path_fails_closed() {
    let dir = TempDir::new().unwrap();
    let hex = hex_file(&dir);
    for path in [dir.path().join("missing-avrdude"), PathBuf::from("avrdude")] {
        let result = run_direct(
            &FakeSerial::default(),
            &UploadTooling {
                avrdude_path: path,
                avrdude_conf: None,
            },
            &fast_timings(),
            "COM3",
            "uno",
            &hex,
            &uno_config(),
            &no_progress,
        );
        assert_eq!(
            result,
            UploadRunResult::Failure {
                reason: UploadFailure::AvrdudeNotFound,
                output: None,
                duration_ms: result_duration(&result),
            }
        );
    }
}

// Mirrors upload_flow_test.exs "retries at 57600 when 115200 fails with
// not-in-sync".
#[test]
fn old_bootloader_nano_retries_at_alternate_baud() {
    let dir = TempDir::new().unwrap();
    let avrdude = write_executable(&dir, "avrdude-baud", BAUD_AWARE_BODY);
    let hex = hex_file(&dir);
    let progress_messages = Mutex::new(Vec::new());
    let result = run_direct(
        &FakeSerial::default(),
        &UploadTooling {
            avrdude_path: avrdude,
            avrdude_conf: None,
        },
        &fast_timings(),
        "COM3",
        "nanoatmega328",
        &hex,
        &nano_config(),
        &|percent, message| progress_messages.lock().unwrap().push((percent, message.to_string())),
    );
    let UploadRunResult::Success { output, .. } = result else {
        panic!("expected success, got {result:?}");
    };
    assert!(output.contains("avrdude done.  Thank you."));
    assert!(progress_messages
        .lock()
        .unwrap()
        .iter()
        .any(|(percent, message)| *percent == 0
            && message == "Retrying at 57600 baud..."));
}

// Mirrors upload_flow_test.exs "returns :bootloader_not_responding when all
// baud rates fail"; the FIRST attempt's output is reported.
#[test]
fn exhausted_baud_retries_report_first_output() {
    let dir = TempDir::new().unwrap();
    let counter = dir.path().join("counter");
    let avrdude = counter_script(
        &dir,
        &counter,
        "stk500_getsync(): not in sync: resp=0x00",
    );
    let hex = hex_file(&dir);
    let result = run_direct(
        &FakeSerial::default(),
        &UploadTooling {
            avrdude_path: avrdude,
            avrdude_conf: None,
        },
        &fast_timings(),
        "COM3",
        "nanoatmega328",
        &hex,
        &nano_config(),
        &no_progress,
    );
    let UploadRunResult::Failure {
        reason,
        output,
        ..
    } = result
    else {
        panic!("expected failure, got {result:?}");
    };
    assert_eq!(reason, UploadFailure::BootloaderNotResponding);
    let output = output.unwrap();
    assert!(output.contains("attempt 1"), "first output kept: {output}");
    assert!(!output.contains("attempt 2"), "first output kept: {output}");
    // Initial 115200 attempt plus the single 57600 alternate.
    assert_eq!(std::fs::read_to_string(&counter).unwrap().trim(), "2");
}

// Mirrors Uploader.retry_port_not_found: one retry, then port_not_found with
// the FIRST attempt's output.
#[test]
fn port_not_found_retries_once_then_reports_first_output() {
    let dir = TempDir::new().unwrap();
    let counter = dir.path().join("counter");
    let avrdude = counter_script(
        &dir,
        &counter,
        "can't open device \"/dev/ttyUSB0\": No such file or directory",
    );
    let hex = hex_file(&dir);
    let progress_messages = Mutex::new(Vec::new());
    let result = run_direct(
        &FakeSerial::default(),
        &UploadTooling {
            avrdude_path: avrdude,
            avrdude_conf: None,
        },
        &fast_timings(),
        "COM3",
        "uno",
        &hex,
        &uno_config(),
        &|percent, message| progress_messages.lock().unwrap().push((percent, message.to_string())),
    );
    let UploadRunResult::Failure {
        reason,
        output,
        ..
    } = result
    else {
        panic!("expected failure, got {result:?}");
    };
    assert_eq!(reason, UploadFailure::PortNotFound);
    let output = output.unwrap();
    assert!(output.contains("attempt 1"), "first output kept: {output}");
    assert_eq!(std::fs::read_to_string(&counter).unwrap().trim(), "2");
    assert!(progress_messages
        .lock()
        .unwrap()
        .iter()
        .any(|(percent, message)| *percent == 0
            && message == "Port not found, retrying..."));
}
// Mirrors upload_flow_test.exs "1200bps touch + bootloader port polling" —
// the Windows scenario where the bootloader COM port takes three polls.
#[test]
fn bootloader_port_appearing_after_three_polls_is_used() {
    let dir = TempDir::new().unwrap();
    let avrdude = write_executable(&dir, "avrdude-args", ARGS_ECHO_BODY);
    let hex = hex_file(&dir);
    let transport = FakeSerial::with_sequence(vec![
        vec!["COM5".to_string()],
        Vec::new(),
        Vec::new(),
        vec!["COM5".to_string(), "COM6".to_string()],
    ]);
    let result = run_direct(
        &transport,
        &UploadTooling {
            avrdude_path: avrdude,
            avrdude_conf: None,
        },
        &fast_timings(),
        "COM5",
        "micro",
        &hex,
        &micro_config(),
        &no_progress,
    );
    let UploadRunResult::Success { output, .. } = result else {
        panic!("expected success, got {result:?}");
    };
    assert!(
        output.contains("-P COM6"),
        "bootloader port not used: {output}"
    );
    assert_eq!(
        transport.opens.lock().unwrap().clone(),
        vec![("COM5".to_string(), 1200)]
    );
}

// Mirrors poll_for_bootloader_port's multiple-new-ports branch (Enum.max).
#[test]
fn multiple_new_bootloader_ports_use_the_maximum() {
    let dir = TempDir::new().unwrap();
    let avrdude = write_executable(&dir, "avrdude-args", ARGS_ECHO_BODY);
    let hex = hex_file(&dir);
    let transport = FakeSerial::with_sequence(vec![
        vec!["COM5".to_string()],
        vec!["COM5".to_string(), "COM6".to_string(), "COM7".to_string()],
    ]);
    let result = run_direct(
        &transport,
        &UploadTooling {
            avrdude_path: avrdude,
            avrdude_conf: None,
        },
        &fast_timings(),
        "COM5",
        "micro",
        &hex,
        &micro_config(),
        &no_progress,
    );
    let UploadRunResult::Success { output, .. } = result else {
        panic!("expected success, got {result:?}");
    };
    assert!(output.contains("-P COM7"), "max port not used: {output}");
}

// Mirrors poll_for_bootloader_port's original-port-still-available branch.
#[test]
fn original_port_still_available_is_reused() {
    let dir = TempDir::new().unwrap();
    let avrdude = write_executable(&dir, "avrdude-args", ARGS_ECHO_BODY);
    let hex = hex_file(&dir);
    let transport =
        FakeSerial::with_sequence(vec![vec!["COM5".to_string()], vec!["COM5".to_string()]]);
    let result = run_direct(
        &transport,
        &UploadTooling {
            avrdude_path: avrdude,
            avrdude_conf: None,
        },
        &fast_timings(),
        "COM5",
        "micro",
        &hex,
        &micro_config(),
        &no_progress,
    );
    let UploadRunResult::Success { output, .. } = result else {
        panic!("expected success, got {result:?}");
    };
    assert!(output.contains("-P COM5"), "original port not used: {output}");
}

// Mirrors the {:error, :bootloader_port_not_found} deadline branch.
#[test]
fn boot_port_that_never_returns_fails_with_bootloader_port_not_found() {
    let dir = TempDir::new().unwrap();
    let avrdude = write_executable(&dir, "avrdude-ok", SUCCESS_BODY);
    let hex = hex_file(&dir);
    let transport = FakeSerial::with_sequence(vec![
        vec!["COM5".to_string()],
        Vec::<String>::new(),
    ]);
    let result = run_direct(
        &transport,
        &UploadTooling {
            avrdude_path: avrdude,
            avrdude_conf: None,
        },
        &fast_timings(),
        "COM5",
        "micro",
        &hex,
        &micro_config(),
        &no_progress,
    );
    assert_eq!(
        result,
        UploadRunResult::Failure {
            reason: UploadFailure::BootloaderPortNotFound,
            output: None,
            duration_ms: result_duration(&result),
        }
    );
}

// Mirrors the touch-open-failure fallback: the oracle logs a warning and
// uploads on the original port anyway.
#[test]
fn failed_touch_open_falls_back_to_the_original_port() {
    let dir = TempDir::new().unwrap();
    let avrdude = write_executable(&dir, "avrdude-args", ARGS_ECHO_BODY);
    let hex = hex_file(&dir);
    let transport = FakeSerial::with_sequence(vec![vec!["COM5".to_string()]]);
    transport.fail_open.store(true, Ordering::SeqCst);
    let result = run_direct(
        &transport,
        &UploadTooling {
            avrdude_path: avrdude,
            avrdude_conf: None,
        },
        &fast_timings(),
        "COM5",
        "micro",
        &hex,
        &micro_config(),
        &no_progress,
    );
    let UploadRunResult::Success { output, .. } = result else {
        panic!("expected success, got {result:?}");
    };
    assert!(output.contains("-P COM5"), "original port not used: {output}");
    // The touch was attempted at 1200 baud even though it failed.
    assert_eq!(
        transport.opens.lock().unwrap().clone(),
        vec![("COM5".to_string(), 1200)]
    );
}

// Mirrors AvrdudeRunner's @collect_timeout_ms path: kill, append the timeout
// notice, and classify as :timeout.
#[test]
fn collect_timeout_appends_notice_and_classifies_as_timeout() {
    let dir = TempDir::new().unwrap();
    let pid_file = dir.path().join("pid");
    let avrdude = blocking_script(&dir, &pid_file);
    let hex = hex_file(&dir);
    let timings = UploadTimings {
        collect_timeout: Duration::from_millis(3_000),
        ..fast_timings()
    };
    let start = Instant::now();
    let result = run_direct(
        &FakeSerial::default(),
        &UploadTooling {
            avrdude_path: avrdude,
            avrdude_conf: None,
        },
        &timings,
        "COM3",
        "uno",
        &hex,
        &uno_config(),
        &no_progress,
    );
    assert!(start.elapsed() < Duration::from_secs(5));
    let UploadRunResult::Failure {
        reason,
        output,
        ..
    } = result
    else {
        panic!("expected failure, got {result:?}");
    };
    assert_eq!(reason, UploadFailure::Timeout);
    assert!(output
        .as_deref()
        .unwrap()
        .contains("\n[Timeout: avrdude did not respond within 2 minutes]"));
    let pid: u32 = std::fs::read_to_string(&pid_file).unwrap().trim().parse().unwrap();
    assert!(!process_alive(pid), "timed-out avrdude must be killed");
}

// Mirrors uploader_test.exs "progress parsing patterns" +
// AvrdudeRunner.format_operation/2 message formatting.
#[test]
fn progress_lines_map_to_operation_messages() {
    let dir = TempDir::new().unwrap();
    let avrdude = write_executable(&dir, "avrdude-ok", SUCCESS_BODY);
    let hex = hex_file(&dir);
    let progress = Mutex::new(Vec::new());
    let result = run_direct(
        &FakeSerial::default(),
        &UploadTooling {
            avrdude_path: avrdude,
            avrdude_conf: None,
        },
        &fast_timings(),
        "COM3",
        "uno",
        &hex,
        &uno_config(),
        &|percent, message| progress.lock().unwrap().push((percent, message.to_string())),
    );
    assert!(matches!(result, UploadRunResult::Success { .. }));
    let progress = progress.into_inner().unwrap();
    assert!(progress.contains(&(42, "Reading device...".to_string())));
    assert!(progress.contains(&(50, "Writing flash (50%)".to_string())));
    assert!(progress.contains(&(100, "Verifying (100%)".to_string())));
}

// Bounded output capture (a Rust-platform requirement; the oracle captured
// unbounded output).
#[test]
fn avrdude_output_capture_is_bounded() {
    let dir = TempDir::new().unwrap();
    let body = "#!/bin/sh\ni=0\nwhile [ $i -lt 200 ]; do echo '0123456789ABCDEF line fill'; i=$((i+1)); done\necho 'avrdude done.  Thank you.'\nexit 0\n";
    let avrdude = write_executable(&dir, "avrdude-big", body);
    let hex = hex_file(&dir);
    let timings = UploadTimings {
        max_output_bytes: 1024,
        ..fast_timings()
    };
    let result = run_direct(
        &FakeSerial::default(),
        &UploadTooling {
            avrdude_path: avrdude,
            avrdude_conf: None,
        },
        &timings,
        "COM3",
        "uno",
        &hex,
        &uno_config(),
        &no_progress,
    );
    let UploadRunResult::Success { output, .. } = result else {
        panic!("expected success, got {result:?}");
    };
    assert!(output.len() <= 1024, "output not bounded: {}", output.len());
}

// ---------------------------------------------------------------------------
// Manager lifecycle — mirrors upload_manager_test.exs and the UploadManager
// history/broadcast semantics
// ---------------------------------------------------------------------------

// Happy path: history started+completed, started/completed events, lease
// released, reconnect hook fired, upload id shape.
#[test]
fn manager_happy_path_records_history_events_and_reconnects() {
    let dir = TempDir::new().unwrap();
    let avrdude = write_executable(&dir, "avrdude-ok", SUCCESS_BODY);
    let hex = hex_file(&dir);
    let (manager, arbiter, history, events, reconnect) = manager_fixture(
        avrdude,
        fast_timings(),
        FakeSerial::default(),
    );
    let upload_id = manager
        .start_upload(upload_request("/dev/ttyUSB0", &hex, &uno_config()))
        .unwrap();
    assert_eq!(upload_id.len(), 16);
    assert!(upload_id.bytes().all(|b| b.is_ascii_hexdigit()));
    assert_eq!(manager.current_upload().unwrap().upload_id, upload_id);
    let outcome = manager
        .wait_for_completion(&upload_id, Duration::from_secs(10))
        .expect("upload should complete");
    assert_eq!(outcome.status, UploadStatus::Completed);
    assert!(outcome.duration_ms < 10_000);
    assert!(manager.current_upload().is_none());
    assert!(!arbiter.is_suspended(), "lease must be released");

    let calls = history.calls.lock().unwrap().clone();
    assert_eq!(
        calls[0],
        HistoryCall::Started {
            upload_id: upload_id.clone(),
            port: "/dev/ttyUSB0".to_string(),
            board_type: "uno".to_string(),
            firmware_file_id: EntityId(7),
        }
    );
    let HistoryCall::Completed {
        output,
        duration_ms,
        ..
    } = &calls[1]
    else {
        panic!("expected completion record, got {calls:?}");
    };
    assert!(output.contains("avrdude done.  Thank you."));
    assert_eq!(*duration_ms, outcome.duration_ms);
    assert_eq!(calls.len(), 2);

    let events = events.events.lock().unwrap().clone();
    assert_eq!(
        events[0],
        UploadEvent::Started {
            upload_id: upload_id.clone(),
            port: "/dev/ttyUSB0".to_string(),
            environment: "uno".to_string(),
        }
    );
    assert_eq!(
        events.last().unwrap(),
        &UploadEvent::Completed {
            upload_id: upload_id.clone(),
            duration_ms: outcome.duration_ms,
        }
    );
    assert_eq!(
        reconnect.lock().unwrap().clone(),
        vec!["/dev/ttyUSB0".to_string()]
    );
}

// Mirrors the {:error, :upload_in_progress} single-flight rule.
#[test]
fn manager_rejects_second_upload_while_one_is_running() {
    let dir = TempDir::new().unwrap();
    let pid_file = dir.path().join("pid");
    let avrdude = blocking_script(&dir, &pid_file);
    let hex = hex_file(&dir);
    let (manager, _arbiter, _history, _events, _reconnect) = manager_fixture(
        avrdude,
        fast_timings(),
        FakeSerial::default(),
    );
    let first = manager
        .start_upload(upload_request("/dev/ttyUSB0", &hex, &uno_config()))
        .unwrap();
    wait_for_file(&pid_file, Duration::from_secs(5));
    assert_eq!(
        manager.start_upload(upload_request("/dev/ttyUSB1", &hex, &uno_config())),
        Err(UploadStartError::UploadInProgress)
    );
    manager.cancel_upload(&first).unwrap();
}

// Mirrors {:error, :firmware_not_downloaded}: no history, no lease, no events.
#[test]
fn manager_rejects_missing_firmware_file_before_any_side_effect() {
    let dir = TempDir::new().unwrap();
    let avrdude = write_executable(&dir, "avrdude-ok", SUCCESS_BODY);
    let missing = dir.path().join("not-downloaded.hex");
    let (manager, arbiter, history, events, _reconnect) = manager_fixture(
        avrdude,
        fast_timings(),
        FakeSerial::default(),
    );
    assert_eq!(
        manager.start_upload(upload_request("/dev/ttyUSB0", &missing, &uno_config())),
        Err(UploadStartError::FirmwareNotDownloaded)
    );
    assert!(history.calls.lock().unwrap().is_empty());
    assert!(events.events.lock().unwrap().is_empty());
    assert!(!arbiter.is_suspended());
}

// Mirrors upload_manager_test.exs "kills the avrdude task process": the
// child dies, the port is released, and the cancellation is broadcast.
#[test]
fn cancel_mid_run_kills_child_releases_lease_and_records_history() {
    let dir = TempDir::new().unwrap();
    let pid_file = dir.path().join("pid");
    let avrdude = blocking_script(&dir, &pid_file);
    let hex = hex_file(&dir);
    let (manager, arbiter, history, events, _reconnect) = manager_fixture(
        avrdude,
        fast_timings(),
        FakeSerial::default(),
    );
    let upload_id = manager
        .start_upload(upload_request("/dev/ttyUSB0", &hex, &uno_config()))
        .unwrap();
    let pid: u32 = wait_for_file(&pid_file, Duration::from_secs(5)).parse().unwrap();
    assert!(process_alive(pid));

    manager.cancel_upload(&upload_id).unwrap();

    assert!(!process_alive(pid), "avrdude child must be killed and reaped");
    assert!(!arbiter.is_suspended(), "port reservation must be released");
    assert!(manager.current_upload().is_none());
    let outcome = manager
        .wait_for_completion(&upload_id, Duration::from_secs(5))
        .unwrap();
    assert_eq!(outcome.status, UploadStatus::Cancelled);
    assert_eq!(outcome.reason, Some(UploadFailure::Cancelled));
    assert_eq!(outcome.message.as_deref(), Some("Upload cancelled by user"));

    let calls = history.calls.lock().unwrap().clone();
    assert_eq!(
        calls[0],
        HistoryCall::Started {
            upload_id: upload_id.clone(),
            port: "/dev/ttyUSB0".to_string(),
            board_type: "uno".to_string(),
            firmware_file_id: EntityId(7),
        }
    );
    assert!(matches!(
        &calls[1],
        HistoryCall::Cancelled { upload_id: id, duration_ms } if id == &upload_id && *duration_ms < 10_000
    ));
    assert_eq!(calls.len(), 2);
    assert_eq!(
        events.events.lock().unwrap().last().unwrap().clone(),
        UploadEvent::Failed {
            upload_id: upload_id.clone(),
            reason: UploadFailure::Cancelled,
            message: "Upload cancelled by user".to_string(),
        }
    );
}

// Mirrors the {:error, :not_found} cancel path, including double-cancel after
// the first cancellation completed.
#[test]
fn cancel_of_unknown_or_finished_upload_is_not_found() {
    let dir = TempDir::new().unwrap();
    let pid_file = dir.path().join("pid");
    let avrdude = blocking_script(&dir, &pid_file);
    let hex = hex_file(&dir);
    let (manager, _arbiter, _history, _events, _reconnect) = manager_fixture(
        avrdude,
        fast_timings(),
        FakeSerial::default(),
    );
    let upload_id = manager
        .start_upload(upload_request("/dev/ttyUSB0", &hex, &uno_config()))
        .unwrap();
    wait_for_file(&pid_file, Duration::from_secs(5));
    // Unknown ids never match.
    assert!(manager.cancel_upload("bogus").is_err());
    manager.cancel_upload(&upload_id).unwrap();
    // Once the first cancel finished, the current upload is gone.
    assert!(manager.cancel_upload(&upload_id).is_err());
}

// Mirrors upload_manager_test.exs "upload timeout kills the avrdude task":
// timeout kills the child, records a cancelled history entry, and broadcasts
// the cancelled + timeout failure pair.
#[test]
fn watchdog_timeout_cancels_child_and_broadcasts_timeout() {
    let dir = TempDir::new().unwrap();
    let pid_file = dir.path().join("pid");
    let avrdude = blocking_script(&dir, &pid_file);
    let hex = hex_file(&dir);
    let timings = UploadTimings {
        upload_timeout: Duration::from_millis(5_000),
        ..fast_timings()
    };
    let (manager, arbiter, history, events, _reconnect) = manager_fixture(
        avrdude,
        timings,
        FakeSerial::default(),
    );
    let upload_id = manager
        .start_upload(upload_request("/dev/ttyUSB0", &hex, &uno_config()))
        .unwrap();
    let pid: u32 = wait_for_file(&pid_file, Duration::from_secs(5)).parse().unwrap();
    let outcome = manager
        .wait_for_completion(&upload_id, Duration::from_secs(10))
        .expect("timeout should terminate the upload");

    assert!(!process_alive(pid), "timed-out avrdude must be killed");
    assert_eq!(outcome.status, UploadStatus::Cancelled);
    assert_eq!(outcome.reason, Some(UploadFailure::Timeout));
    assert!(outcome
        .message
        .as_deref()
        .unwrap()
        .starts_with("Upload timed out."));
    assert!(!arbiter.is_suspended(), "lease must be released");

    let calls = history.calls.lock().unwrap().clone();
    assert!(matches!(&calls[1], HistoryCall::Cancelled { upload_id: id, .. } if id == &upload_id));

    let events = events.events.lock().unwrap().clone();
    let failures: Vec<_> = events
        .iter()
        .filter(|event| matches!(event, UploadEvent::Failed { .. }))
        .cloned()
        .collect();
    assert_eq!(
        failures,
        vec![
            UploadEvent::Failed {
                upload_id: upload_id.clone(),
                reason: UploadFailure::Cancelled,
                message: "Upload cancelled by user".to_string(),
            },
            UploadEvent::Failed {
                upload_id: upload_id.clone(),
                reason: UploadFailure::Timeout,
                message: UploadFailure::Timeout.friendly_message(),
            },
        ]
    );
}

// Fail-closed lease contention: an active calibration lease elsewhere blocks
// the firmware lease and no history/events are produced.
#[test]
fn lease_contention_fails_closed_without_side_effects() {
    let dir = TempDir::new().unwrap();
    let avrdude = write_executable(&dir, "avrdude-ok", SUCCESS_BODY);
    let hex = hex_file(&dir);
    let (manager, arbiter, history, events, _reconnect) = manager_fixture(
        avrdude,
        fast_timings(),
        FakeSerial::default(),
    );
    let calibration = arbiter
        .acquire(LeaseKind::Calibration {
            port: "COM9".to_string(),
            generation: 2,
        })
        .unwrap();
    assert_eq!(
        manager.start_upload(upload_request("/dev/ttyUSB1", &hex, &uno_config())),
        Err(UploadStartError::Lease(ResourceError::Busy))
    );
    assert!(history.calls.lock().unwrap().is_empty());
    assert!(events.events.lock().unwrap().is_empty());
    arbiter.release(calibration).unwrap();
    // After release the same start succeeds.
    manager
        .start_upload(upload_request("/dev/ttyUSB1", &hex, &uno_config()))
        .unwrap();
}

// Same-port calibration hands the lease over to firmware once released
// (ResourceArbiter acquire semantics relied on by the upload flow).
#[test]
fn same_port_calibration_releases_into_firmware_lease() {
    let dir = TempDir::new().unwrap();
    let avrdude = write_executable(&dir, "avrdude-ok", SUCCESS_BODY);
    let hex = hex_file(&dir);
    let consumers = Arc::new(ConsumerLog::default());
    let arbiter = Arc::new(ResourceArbiter::new(consumers.clone()));
    let history = Arc::new(HistoryFake::default());
    let events = Arc::new(EventLog::default());
    let manager = UploadManager::new(
        arbiter.clone(),
        Arc::new(FakeSerial::default()),
        UploadTooling {
            avrdude_path: avrdude,
            avrdude_conf: None,
        },
        fast_timings(),
        history.clone(),
        UploadHooks {
            on_event: Some({
                let events = events.clone();
                Arc::new(move |event: &UploadEvent| {
                    events.events.lock().unwrap().push(event.clone());
                })
            }),
            reconnect: None,
        },
    );
    let calibration = arbiter
        .acquire(LeaseKind::Calibration {
            port: "COM5".to_string(),
            generation: 4,
        })
        .unwrap();
    let starter = thread::spawn({
        let manager = manager.clone();
        let hex = hex.clone();
        move || manager.start_upload(upload_request("COM5", &hex, &uno_config()))
    });
    let deadline = Instant::now() + Duration::from_secs(5);
    while !consumers
        .calls
        .lock()
        .unwrap()
        .contains(&"cancel-calibration")
    {
        assert!(Instant::now() < deadline, "calibration never cancelled");
        thread::sleep(Duration::from_millis(2));
    }
    arbiter.release(calibration).unwrap();
    let upload_id = starter.join().unwrap().unwrap();
    let outcome = manager
        .wait_for_completion(&upload_id, Duration::from_secs(10))
        .unwrap();
    assert_eq!(outcome.status, UploadStatus::Completed);
}

// Mirrors handle_upload_crash/2: a crashed worker records a failed history
// entry, broadcasts :crash, releases the lease, and the manager recovers.
#[test]
fn crashed_worker_records_failure_and_recovers() {
    let dir = TempDir::new().unwrap();
    let avrdude = write_executable(&dir, "avrdude-ok", SUCCESS_BODY);
    let hex = hex_file(&dir);
    let transport = FakeSerial::default();
    transport.panic_on_enumerate.store(true, Ordering::SeqCst);
    let (manager, arbiter, history, events, _reconnect) = manager_fixture(
        avrdude.clone(),
        fast_timings(),
        transport.clone(),
    );
    let upload_id = manager
        .start_upload(upload_request("/dev/ttyUSB0", &hex, &micro_config()))
        .unwrap();
    let outcome = manager
        .wait_for_completion(&upload_id, Duration::from_secs(10))
        .unwrap();
    assert_eq!(outcome.status, UploadStatus::Failed);
    assert_eq!(outcome.reason, Some(UploadFailure::Crash));
    assert_eq!(
        outcome.message.as_deref(),
        Some("Upload task crashed unexpectedly")
    );
    assert!(!arbiter.is_suspended(), "lease must be released after a crash");

    let calls = history.calls.lock().unwrap().clone();
    let HistoryCall::Failed {
        error_message,
        output,
        ..
    } = &calls[1]
    else {
        panic!("expected failure record, got {calls:?}");
    };
    assert!(error_message.starts_with("Task crashed: "), "{error_message}");
    assert!(output.is_none());

    assert_eq!(
        events.events.lock().unwrap().last().unwrap().clone(),
        UploadEvent::Failed {
            upload_id: upload_id.clone(),
            reason: UploadFailure::Crash,
            message: "Upload task crashed unexpectedly".to_string(),
        }
    );

    // Recovery: with the transport healthy again a new upload completes.
    transport.panic_on_enumerate.store(false, Ordering::SeqCst);
    let retry_id = manager
        .start_upload(upload_request("/dev/ttyUSB0", &hex, &uno_config()))
        .unwrap();
    let outcome = manager
        .wait_for_completion(&retry_id, Duration::from_secs(10))
        .unwrap();
    assert_eq!(outcome.status, UploadStatus::Completed);
}

// Crash-reap: dropping the manager mid-upload kills and reaps the avrdude
// child and leaves no orphaned port reservation.
#[test]
fn dropping_manager_mid_upload_reaps_child_and_lease() {
    let dir = TempDir::new().unwrap();
    let pid_file = dir.path().join("pid");
    let avrdude = blocking_script(&dir, &pid_file);
    let hex = hex_file(&dir);
    let (manager, arbiter, history, _events, _reconnect) = manager_fixture(
        avrdude,
        fast_timings(),
        FakeSerial::default(),
    );
    let upload_id = manager
        .start_upload(upload_request("/dev/ttyUSB0", &hex, &uno_config()))
        .unwrap();
    let pid: u32 = wait_for_file(&pid_file, Duration::from_secs(5)).parse().unwrap();
    drop(manager);
    assert!(!process_alive(pid), "drop must kill and reap the child");
    assert!(!arbiter.is_suspended(), "drop must release the port lease");
    assert!(matches!(
        history.calls.lock().unwrap()[1],
        HistoryCall::Cancelled { .. }
    ));
    let _ = upload_id;
}

// A slow-but-failing avrdude still records failure output and duration in
// history (fail_upload/3 with avrdude output).
#[test]
fn manager_records_failure_output_and_duration() {
    let dir = TempDir::new().unwrap();
    let avrdude = write_executable(&dir, "avrdude-sig", SIGNATURE_MISMATCH_BODY);
    let hex = hex_file(&dir);
    let (manager, arbiter, history, events, _reconnect) = manager_fixture(
        avrdude,
        fast_timings(),
        FakeSerial::default(),
    );
    let upload_id = manager
        .start_upload(upload_request("/dev/ttyUSB0", &hex, &uno_config()))
        .unwrap();
    let outcome = manager
        .wait_for_completion(&upload_id, Duration::from_secs(10))
        .unwrap();
    assert_eq!(outcome.status, UploadStatus::Failed);
    assert_eq!(outcome.reason, Some(UploadFailure::WrongBoardType));
    assert!(outcome.duration_ms < 10_000);
    assert!(!arbiter.is_suspended());

    let calls = history.calls.lock().unwrap().clone();
    let HistoryCall::Failed {
        error_message,
        output,
        duration_ms,
        ..
    } = &calls[1]
    else {
        panic!("expected failure record, got {calls:?}");
    };
    assert_eq!(error_message, "wrong_board_type");
    assert!(output.as_deref().unwrap().contains("device signature"));
    assert_eq!(*duration_ms, outcome.duration_ms);

    assert_eq!(
        events.events.lock().unwrap().last().unwrap().clone(),
        UploadEvent::Failed {
            upload_id: upload_id.clone(),
            reason: UploadFailure::WrongBoardType,
            message: UploadFailure::WrongBoardType.friendly_message(),
        }
    );
}

