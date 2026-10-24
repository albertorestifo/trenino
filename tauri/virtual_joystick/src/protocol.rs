use std::io::{self, BufRead, Write};

use serde::{Deserialize, Serialize};

use crate::vjoy::{AxisRange, DeviceStatus, Report, VJoy, VJoyError};

pub const PROTOCOL_VERSION: u16 = 1;
pub const DEVICE: u8 = 1;
pub const MAX_LINE_BYTES: usize = 16 * 1024;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Axis {
    X,
    Y,
    Z,
    Rx,
    Ry,
    Rz,
    #[serde(rename = "slider_1")]
    Slider1,
    #[serde(rename = "slider_2")]
    Slider2,
}

impl Axis {
    pub const ALL: [Self; 8] = [
        Self::X,
        Self::Y,
        Self::Z,
        Self::Rx,
        Self::Ry,
        Self::Rz,
        Self::Slider1,
        Self::Slider2,
    ];
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case")]
pub enum Command {
    Hello {
        protocol: u16,
        #[serde(default)]
        device: Option<u8>,
    },
    SetAxis {
        request_id: u64,
        device: u8,
        axis: Axis,
        value: i32,
    },
    SetButton {
        request_id: u64,
        device: u8,
        button: u8,
        pressed: bool,
    },
    Reset {
        request_id: u64,
        device: u8,
    },
    Shutdown,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(tag = "event", rename_all = "snake_case")]
pub enum Response {
    Ready {
        protocol: u16,
        device: u8,
        axis_min: i32,
        axis_max: i32,
    },
    Applied {
        request_id: u64,
    },
    Stopped,
    DeviceBusy {
        device: u8,
    },
    DeviceRemoved {
        device: u8,
        #[serde(skip_serializing_if = "Option::is_none")]
        request_id: Option<u64>,
    },
    InvalidCommand {
        code: &'static str,
        message: String,
        #[serde(skip_serializing_if = "Option::is_none")]
        request_id: Option<u64>,
    },
    Error {
        code: &'static str,
        message: String,
        #[serde(skip_serializing_if = "Option::is_none")]
        request_id: Option<u64>,
    },
}

pub struct HandleResult {
    pub response: Response,
    pub shutdown: bool,
}

pub struct Session<T: VJoy> {
    vjoy: T,
    selected_device: Option<u8>,
    range: Option<AxisRange>,
    report: Option<Report>,
    acquired: bool,
}

impl<T: VJoy> Session<T> {
    pub fn new(vjoy: T) -> Self {
        Self {
            vjoy,
            selected_device: None,
            range: None,
            report: None,
            acquired: false,
        }
    }

    pub fn handle_line(&mut self, line: &str) -> HandleResult {
        let command = match parse_command(line, self.range) {
            Ok(command) => command,
            Err(message) => {
                return HandleResult {
                    response: Response::InvalidCommand {
                        code: "invalid_command",
                        message,
                        request_id: request_id(line),
                    },
                    shutdown: false,
                }
            }
        };
        match command {
            Command::Hello { device, .. } => self.hello(device.unwrap_or(DEVICE)),
            Command::SetAxis {
                request_id,
                device,
                axis,
                value,
            } => {
                if let Some(result) = self.validate_selected_device(device, request_id) {
                    result
                } else {
                    self.mutate(request_id, |report| report.set_axis(axis, value))
                }
            }
            Command::SetButton {
                request_id,
                device,
                button,
                pressed,
            } => {
                if let Some(result) = self.validate_selected_device(device, request_id) {
                    result
                } else {
                    self.mutate(request_id, |report| report.set_button(button, pressed))
                }
            }
            Command::Reset { request_id, device } => {
                if let Some(result) = self.validate_selected_device(device, request_id) {
                    result
                } else if let Some(range) = self.range {
                    self.mutate(request_id, |report| report.reset(range))
                } else {
                    self.not_ready(request_id)
                }
            }
            Command::Shutdown => {
                let cleanup = if self.acquired {
                    self.release_selected_device()
                } else {
                    Ok(())
                };
                HandleResult {
                    response: cleanup.map_or_else(
                        |message| Response::Error {
                            code: "shutdown_failed",
                            message,
                            request_id: None,
                        },
                        |_| Response::Stopped,
                    ),
                    shutdown: true,
                }
            }
        }
    }

    fn hello(&mut self, device: u8) -> HandleResult {
        if self.acquired {
            if self.selected_device != Some(device) {
                return invalid_device_selection(device, self.selected_device);
            }
            let range = self.range.expect("acquired sessions have a range");
            return HandleResult {
                response: Response::Ready {
                    protocol: PROTOCOL_VERSION,
                    device,
                    axis_min: range.min,
                    axis_max: range.max,
                },
                shutdown: false,
            };
        }
        let response = match self.vjoy.enabled() {
            Ok(true) => match self.vjoy.status(device) {
                Ok(DeviceStatus::Busy) => Response::DeviceBusy { device },
                Ok(DeviceStatus::Missing) => Response::DeviceRemoved {
                    device,
                    request_id: None,
                },
                Ok(DeviceStatus::Free | DeviceStatus::Owned) => match self.vjoy.acquire(device) {
                    Ok(()) => {
                        // Track ownership before any operation that may fail so
                        // every post-acquisition exit neutralizes and releases.
                        self.selected_device = Some(device);
                        self.acquired = true;
                        match self.axis_range(device) {
                            Ok(range) => {
                                self.range = Some(range);
                                let report = Report::centered(range);
                                match self.vjoy.update(device, &report) {
                                    Ok(()) => {
                                        self.report = Some(report);
                                        Response::Ready {
                                            protocol: PROTOCOL_VERSION,
                                            device,
                                            axis_min: range.min,
                                            axis_max: range.max,
                                        }
                                    }
                                    Err(error) => {
                                        let cleanup = self.release_selected_device();
                                        error_with_cleanup(error, None, device, cleanup)
                                    }
                                }
                            }
                            Err(error) => {
                                let cleanup = self.release_selected_device();
                                error_with_cleanup(error, None, device, cleanup)
                            }
                        }
                    }
                    Err(error) => error_response(error, None, device),
                },
                Err(error) => error_response(error, None, device),
            },
            Ok(false) => Response::Error {
                code: "vjoy_disabled",
                message: "vJoy is not enabled".into(),
                request_id: None,
            },
            Err(error) => error_response(error, None, device),
        };
        HandleResult {
            response,
            shutdown: false,
        }
    }

    fn axis_range(&mut self, device: u8) -> Result<AxisRange, VJoyError> {
        let mut expected = None;
        for axis in Axis::ALL {
            let range = self.vjoy.axis_range(device, axis)?;
            if range.min > range.max {
                return Err(VJoyError::Sdk {
                    operation: "axis_range",
                    message: format!("axis {axis:?} has an inverted range"),
                });
            }
            match expected {
                None => expected = Some(range),
                Some(first) if first == range => {}
                Some(_) => {
                    return Err(VJoyError::Sdk {
                        operation: "axis_range",
                        message: "all axes must use the same logical range".into(),
                    });
                }
            }
        }
        expected.ok_or_else(|| VJoyError::Sdk {
            operation: "axis_range",
            message: "device has no axes".into(),
        })
    }

    fn validate_selected_device(&self, device: u8, request_id: u64) -> Option<HandleResult> {
        match self.selected_device {
            Some(selected) if selected != device => Some(HandleResult {
                response: Response::InvalidCommand {
                    code: "invalid_command",
                    message: format!("session is using device {selected}, not device {device}"),
                    request_id: Some(request_id),
                },
                shutdown: false,
            }),
            _ => None,
        }
    }

    fn mutate(&mut self, request_id: u64, change: impl FnOnce(&mut Report)) -> HandleResult {
        if !self.acquired {
            return self.not_ready(request_id);
        }
        let report = self
            .report
            .as_mut()
            .expect("acquired sessions have reports");
        change(report);
        let device = self.selected_device.unwrap_or(DEVICE);
        let response = match self.vjoy.update(device, report) {
            Ok(()) => Response::Applied { request_id },
            Err(error) => {
                let cleanup = self.release_selected_device();
                error_with_cleanup(error, Some(request_id), device, cleanup)
            }
        };
        HandleResult {
            response,
            shutdown: false,
        }
    }

    fn release_selected_device(&mut self) -> Result<(), String> {
        let Some(device) = self.selected_device else {
            self.clear_selection();
            return Ok(());
        };

        let neutralize_error = self.vjoy.neutralize(device).err();
        let relinquish_error = self.vjoy.relinquish(device).err();
        self.clear_selection();

        let errors = [neutralize_error, relinquish_error]
            .into_iter()
            .flatten()
            .map(|error| format!("{error:?}"))
            .collect::<Vec<_>>();
        if errors.is_empty() {
            Ok(())
        } else {
            Err(errors.join("; "))
        }
    }

    fn clear_selection(&mut self) {
        self.acquired = false;
        self.selected_device = None;
        self.range = None;
        self.report = None;
    }

    fn not_ready(&self, request_id: u64) -> HandleResult {
        HandleResult {
            response: Response::Error {
                code: "not_ready",
                message: "send hello before updating controls".into(),
                request_id: Some(request_id),
            },
            shutdown: false,
        }
    }
}

impl<T: VJoy> Drop for Session<T> {
    fn drop(&mut self) {
        if self.acquired {
            let _ = self.release_selected_device();
        }
    }
}

pub fn parse_command(line: &str, range: Option<AxisRange>) -> Result<Command, String> {
    let command: Command = serde_json::from_str(line).map_err(|error| error.to_string())?;
    match command {
        Command::Hello { protocol, .. } if protocol != PROTOCOL_VERSION => {
            Err(format!("unsupported protocol version {protocol}"))
        }
        Command::Hello {
            device: Some(device),
            ..
        } => {
            validate_device(device)?;
            Ok(command)
        }
        Command::SetAxis { device, value, .. } => {
            validate_device(device)?;
            let range = range.ok_or_else(|| "send hello before setting axes".to_string())?;
            if value < range.min || value > range.max {
                Err(format!(
                    "axis value must be between {} and {}",
                    range.min, range.max
                ))
            } else {
                Ok(command)
            }
        }
        Command::SetButton { device, button, .. } => {
            validate_device(device)?;
            if !(1..=32).contains(&button) {
                Err("button must be between 1 and 32".into())
            } else {
                Ok(command)
            }
        }
        Command::Reset { device, .. } => {
            validate_device(device)?;
            Ok(command)
        }
        _ => Ok(command),
    }
}

fn validate_device(device: u8) -> Result<(), String> {
    if (1..=16).contains(&device) {
        Ok(())
    } else {
        Err("device must be between 1 and 16".into())
    }
}
fn request_id(line: &str) -> Option<u64> {
    serde_json::from_str::<serde_json::Value>(line)
        .ok()?
        .get("request_id")?
        .as_u64()
}
fn invalid_device_selection(device: u8, selected: Option<u8>) -> HandleResult {
    HandleResult {
        response: Response::InvalidCommand {
            code: "invalid_command",
            message: format!(
                "session is already using device {}, not device {device}",
                selected.unwrap_or(DEVICE)
            ),
            request_id: None,
        },
        shutdown: false,
    }
}

fn error_response(error: VJoyError, request_id: Option<u64>, device: u8) -> Response {
    match error {
        VJoyError::DeviceRemoved => Response::DeviceRemoved { device, request_id },
        VJoyError::UnsupportedPlatform => Response::Error {
            code: "unsupported_platform",
            message: "vJoy is supported only on Windows".into(),
            request_id,
        },
        VJoyError::Sdk { operation, message } => Response::Error {
            code: "sdk_error",
            message: format!("{operation}: {message}"),
            request_id,
        },
    }
}

fn error_with_cleanup(
    error: VJoyError,
    request_id: Option<u64>,
    device: u8,
    cleanup: Result<(), String>,
) -> Response {
    match cleanup {
        Ok(()) => error_response(error, request_id, device),
        Err(cleanup_error) => Response::Error {
            code: "cleanup_failed",
            message: format!("operation failed: {error:?}; cleanup failed: {cleanup_error}"),
            request_id,
        },
    }
}

pub fn serve<R: BufRead, W: Write, T: VJoy>(
    mut input: R,
    output: &mut W,
    vjoy: T,
) -> io::Result<()> {
    let mut session = Session::new(vjoy);
    loop {
        let Some(line) = read_bounded_line(&mut input)? else {
            break;
        };
        let result = if line.oversized {
            HandleResult {
                response: Response::InvalidCommand {
                    code: "input_too_large",
                    message: format!("input line exceeds {MAX_LINE_BYTES} bytes"),
                    request_id: None,
                },
                shutdown: false,
            }
        } else {
            let mut bytes = line.bytes;
            if bytes.ends_with(b"\r") {
                bytes.pop();
            }
            match std::str::from_utf8(&bytes) {
                Ok(line) => session.handle_line(line),
                Err(_) => HandleResult {
                    response: Response::InvalidCommand {
                        code: "invalid_command",
                        message: "input must be UTF-8".into(),
                        request_id: None,
                    },
                    shutdown: false,
                },
            }
        };
        serde_json::to_writer(&mut *output, &result.response)?;
        output.write_all(b"\n")?;
        output.flush()?;
        if result.shutdown {
            break;
        }
    }
    Ok(())
}

struct BoundedLine {
    bytes: Vec<u8>,
    oversized: bool,
}

fn read_bounded_line<R: BufRead>(input: &mut R) -> io::Result<Option<BoundedLine>> {
    let mut bytes = Vec::with_capacity(MAX_LINE_BYTES);
    let mut oversized = false;
    let mut read_any = false;

    loop {
        let (consume, newline) = {
            let available = input.fill_buf()?;
            if available.is_empty() {
                return if read_any {
                    Ok(Some(BoundedLine { bytes, oversized }))
                } else {
                    Ok(None)
                };
            }
            read_any = true;
            let newline_at = available.iter().position(|byte| *byte == b'\n');
            let content = newline_at.unwrap_or(available.len());
            let consume = content + usize::from(newline_at.is_some());
            if !oversized {
                let remaining = MAX_LINE_BYTES.saturating_sub(bytes.len());
                let stored = content.min(remaining);
                bytes.extend_from_slice(&available[..stored]);
                oversized = stored < content;
            }
            (consume, newline_at.is_some())
        };
        input.consume(consume);
        if newline {
            return Ok(Some(BoundedLine { bytes, oversized }));
        }
    }
}
