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
    range: Option<AxisRange>,
    report: Option<Report>,
    acquired: bool,
}

impl<T: VJoy> Session<T> {
    pub fn new(vjoy: T) -> Self {
        Self {
            vjoy,
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
            Command::Hello { .. } => self.hello(),
            Command::SetAxis {
                request_id,
                axis,
                value,
                ..
            } => self.mutate(request_id, |report| report.set_axis(axis, value)),
            Command::SetButton {
                request_id,
                button,
                pressed,
                ..
            } => self.mutate(request_id, |report| report.set_button(button, pressed)),
            Command::Reset { request_id, .. } => {
                let range = self.range.expect("validated reset needs handshake");
                self.mutate(request_id, |report| report.reset(range))
            }
            Command::Shutdown => {
                if self.acquired {
                    self.vjoy.relinquish(DEVICE);
                    self.acquired = false;
                }
                HandleResult {
                    response: Response::Stopped,
                    shutdown: true,
                }
            }
        }
    }

    fn hello(&mut self) -> HandleResult {
        if self.acquired {
            let range = self.range.expect("acquired sessions have a range");
            return HandleResult {
                response: Response::Ready {
                    protocol: PROTOCOL_VERSION,
                    device: DEVICE,
                    axis_min: range.min,
                    axis_max: range.max,
                },
                shutdown: false,
            };
        }
        let response = match self.vjoy.enabled() {
            Ok(true) => match self.vjoy.status(DEVICE) {
                Ok(DeviceStatus::Busy) => Response::DeviceBusy { device: DEVICE },
                Ok(DeviceStatus::Missing) => Response::DeviceRemoved {
                    device: DEVICE,
                    request_id: None,
                },
                Ok(DeviceStatus::Free | DeviceStatus::Owned) => match self
                    .vjoy
                    .acquire(DEVICE)
                    .and_then(|_| self.vjoy.axis_range(DEVICE, Axis::X))
                {
                    Ok(range) => {
                        self.range = Some(range);
                        self.report = Some(Report::centered(range));
                        self.acquired = true;
                        Response::Ready {
                            protocol: PROTOCOL_VERSION,
                            device: DEVICE,
                            axis_min: range.min,
                            axis_max: range.max,
                        }
                    }
                    Err(error) => error_response(error, None),
                },
                Err(error) => error_response(error, None),
            },
            Ok(false) => Response::Error {
                code: "vjoy_disabled",
                message: "vJoy is not enabled".into(),
                request_id: None,
            },
            Err(error) => error_response(error, None),
        };
        HandleResult {
            response,
            shutdown: false,
        }
    }

    fn mutate(&mut self, request_id: u64, change: impl FnOnce(&mut Report)) -> HandleResult {
        if !self.acquired {
            return HandleResult {
                response: Response::Error {
                    code: "not_ready",
                    message: "send hello before updating controls".into(),
                    request_id: Some(request_id),
                },
                shutdown: false,
            };
        }
        let report = self
            .report
            .as_mut()
            .expect("acquired sessions have reports");
        change(report);
        let response = match self.vjoy.update(DEVICE, report) {
            Ok(()) => Response::Applied { request_id },
            Err(error) => error_response(error, Some(request_id)),
        };
        HandleResult {
            response,
            shutdown: false,
        }
    }
}

pub fn parse_command(line: &str, range: Option<AxisRange>) -> Result<Command, String> {
    let command: Command = serde_json::from_str(line).map_err(|error| error.to_string())?;
    match command {
        Command::Hello { protocol } if protocol != PROTOCOL_VERSION => {
            Err(format!("unsupported protocol version {protocol}"))
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
    if device == DEVICE {
        Ok(())
    } else {
        Err("only device 1 is supported".into())
    }
}
fn request_id(line: &str) -> Option<u64> {
    serde_json::from_str::<serde_json::Value>(line)
        .ok()?
        .get("request_id")?
        .as_u64()
}
fn error_response(error: VJoyError, request_id: Option<u64>) -> Response {
    match error {
        VJoyError::DeviceRemoved => Response::DeviceRemoved {
            device: DEVICE,
            request_id,
        },
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

pub fn serve<R: BufRead, W: Write, T: VJoy>(
    mut input: R,
    output: &mut W,
    vjoy: T,
) -> io::Result<()> {
    let mut session = Session::new(vjoy);
    loop {
        let mut bytes = Vec::with_capacity(MAX_LINE_BYTES + 1);
        let read = input.read_until(b'\n', &mut bytes)?;
        if read == 0 {
            break;
        }
        let result = if bytes.len() > MAX_LINE_BYTES {
            HandleResult {
                response: Response::InvalidCommand {
                    code: "input_too_large",
                    message: format!("input line exceeds {MAX_LINE_BYTES} bytes"),
                    request_id: None,
                },
                shutdown: false,
            }
        } else {
            if bytes.ends_with(b"\n") {
                bytes.pop();
                if bytes.ends_with(b"\r") {
                    bytes.pop();
                }
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
