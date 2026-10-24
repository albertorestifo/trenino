#[derive(Clone, Debug, Eq, PartialEq)]
pub enum Message {
    IdentityRequest {
        request_id: u32,
    },
    IdentityResponse {
        request_id: u32,
        major: u8,
        minor: u8,
        patch: u8,
        config_id: u32,
    },
    ConfigureAnalog {
        config_id: u32,
        total_parts: u8,
        part_number: u8,
        pin: u8,
        sensitivity: u8,
    },
    ConfigureButton {
        config_id: u32,
        total_parts: u8,
        part_number: u8,
        pin: u8,
        debounce: u8,
    },
    ConfigureMatrix {
        config_id: u32,
        total_parts: u8,
        part_number: u8,
        row_pins: Vec<u8>,
        col_pins: Vec<u8>,
    },
    ConfigureHt16k33 {
        config_id: u32,
        total_parts: u8,
        part_number: u8,
        address: u8,
        brightness: u8,
        num_digits: u8,
    },
    ConfigurationStored {
        config_id: u32,
    },
    ConfigurationError {
        config_id: u32,
    },
    InputValue {
        pin: u8,
        value: i16,
    },
    Heartbeat,
    SetOutput {
        pin: u8,
        high: bool,
    },
    RetryCalibration {
        pin: u8,
    },
    WriteSegments {
        address: u8,
        data: Vec<u8>,
    },
    SetModuleBrightness {
        address: u8,
        brightness: u8,
    },
    ModuleError {
        address: u8,
        error_code: u8,
    },
}
impl Message {
    pub(crate) fn set_part(&mut self, total: u8, part: u8) {
        match self {
            Self::ConfigureAnalog {
                total_parts,
                part_number,
                ..
            }
            | Self::ConfigureButton {
                total_parts,
                part_number,
                ..
            }
            | Self::ConfigureMatrix {
                total_parts,
                part_number,
                ..
            }
            | Self::ConfigureHt16k33 {
                total_parts,
                part_number,
                ..
            } => {
                *total_parts = total;
                *part_number = part
            }
            _ => {}
        }
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum ProtocolError {
    InsufficientData,
    UnknownMessageType(u8),
    InvalidMessage,
    InvalidField(&'static str),
}
fn u32le(b: &[u8]) -> u32 {
    u32::from_le_bytes(b.try_into().unwrap())
}
fn put32(v: u32, o: &mut Vec<u8>) {
    o.extend(v.to_le_bytes())
}
pub fn encode_message(m: &Message) -> Result<Vec<u8>, ProtocolError> {
    use Message::*;
    let mut o = Vec::new();
    match m {
        IdentityRequest { request_id } => {
            o.push(0);
            put32(*request_id, &mut o)
        }
        IdentityResponse {
            request_id,
            major,
            minor,
            patch,
            config_id,
        } => {
            o.push(1);
            put32(*request_id, &mut o);
            o.extend([*major, *minor, *patch]);
            put32(*config_id, &mut o)
        }
        ConfigureAnalog {
            config_id,
            total_parts,
            part_number,
            pin,
            sensitivity,
        } => {
            o.push(2);
            put32(*config_id, &mut o);
            o.extend([*total_parts, *part_number, 0, *pin, *sensitivity])
        }
        ConfigureButton {
            config_id,
            total_parts,
            part_number,
            pin,
            debounce,
        } => {
            o.push(2);
            put32(*config_id, &mut o);
            o.extend([*total_parts, *part_number, 1, *pin, *debounce])
        }
        ConfigureMatrix {
            config_id,
            total_parts,
            part_number,
            row_pins,
            col_pins,
        } => {
            if row_pins.len() > 255 || col_pins.len() > 255 {
                return Err(ProtocolError::InvalidField("matrix count"));
            }
            o.push(2);
            put32(*config_id, &mut o);
            o.extend([
                *total_parts,
                *part_number,
                2,
                row_pins.len() as u8,
                col_pins.len() as u8,
            ]);
            o.extend(row_pins);
            o.extend(col_pins)
        }
        ConfigureHt16k33 {
            config_id,
            total_parts,
            part_number,
            address,
            brightness,
            num_digits,
        } => {
            o.push(2);
            put32(*config_id, &mut o);
            o.extend([
                *total_parts,
                *part_number,
                4,
                *address,
                *brightness,
                *num_digits,
            ])
        }
        ConfigurationStored { config_id } | ConfigurationError { config_id } => {
            o.push(if matches!(m, ConfigurationStored { .. }) {
                3
            } else {
                4
            });
            put32(*config_id, &mut o)
        }
        InputValue { pin, value } => {
            o.extend([5, *pin]);
            o.extend(value.to_le_bytes())
        }
        Heartbeat => o.push(6),
        SetOutput { pin, high } => o.extend([7, *pin, u8::from(*high)]),
        RetryCalibration { pin } => o.extend([8, *pin]),
        WriteSegments { address, data } => {
            if data.len() > 16 {
                return Err(ProtocolError::InvalidField("segment data length"));
            }
            o.extend([13, *address, data.len() as u8]);
            o.extend(data)
        }
        SetModuleBrightness {
            address,
            brightness,
        } => {
            if *brightness > 15 {
                return Err(ProtocolError::InvalidField("brightness"));
            }
            o.extend([14, *address, *brightness])
        }
        ModuleError {
            address,
            error_code,
        } => o.extend([15, *address, *error_code]),
    }
    Ok(o)
}
pub fn decode_message(b: &[u8]) -> Result<Message, ProtocolError> {
    use Message::*;
    if b.is_empty() {
        return Err(ProtocolError::InsufficientData);
    }
    let ty = b[0];
    let x = &b[1..];
    let need = |n| {
        if x.len() == n {
            Ok(())
        } else {
            Err(ProtocolError::InvalidMessage)
        }
    };
    Ok(match ty {
        0 => {
            need(4)?;
            IdentityRequest {
                request_id: u32le(x),
            }
        }
        1 => {
            need(11)?;
            IdentityResponse {
                request_id: u32le(&x[..4]),
                major: x[4],
                minor: x[5],
                patch: x[6],
                config_id: u32le(&x[7..]),
            }
        }
        2 => {
            if x.len() < 7 {
                return Err(ProtocolError::InvalidMessage);
            }
            let id = u32le(&x[..4]);
            let t = x[4];
            let p = x[5];
            match x[6] {
                0 => {
                    need(9)?;
                    ConfigureAnalog {
                        config_id: id,
                        total_parts: t,
                        part_number: p,
                        pin: x[7],
                        sensitivity: x[8],
                    }
                }
                1 => {
                    need(9)?;
                    ConfigureButton {
                        config_id: id,
                        total_parts: t,
                        part_number: p,
                        pin: x[7],
                        debounce: x[8],
                    }
                }
                2 => {
                    if x.len() < 9 {
                        return Err(ProtocolError::InvalidMessage);
                    }
                    let nr = x[7] as usize;
                    let nc = x[8] as usize;
                    need(9 + nr + nc)?;
                    ConfigureMatrix {
                        config_id: id,
                        total_parts: t,
                        part_number: p,
                        row_pins: x[9..9 + nr].to_vec(),
                        col_pins: x[9 + nr..].to_vec(),
                    }
                }
                _ => return Err(ProtocolError::InvalidMessage),
            }
        }
        3 | 4 => {
            need(4)?;
            if ty == 3 {
                ConfigurationStored {
                    config_id: u32le(x),
                }
            } else {
                ConfigurationError {
                    config_id: u32le(x),
                }
            }
        }
        5 => {
            need(3)?;
            InputValue {
                pin: x[0],
                value: i16::from_le_bytes([x[1], x[2]]),
            }
        }
        6 => {
            need(0)?;
            Heartbeat
        }
        7 => {
            need(2)?;
            match x[1] {
                0 => SetOutput {
                    pin: x[0],
                    high: false,
                },
                1 => SetOutput {
                    pin: x[0],
                    high: true,
                },
                _ => return Err(ProtocolError::InvalidMessage),
            }
        }
        8 => {
            need(1)?;
            RetryCalibration { pin: x[0] }
        }
        13 => {
            if x.len() < 2 {
                return Err(ProtocolError::InvalidMessage);
            }
            need(2 + x[1] as usize)?;
            WriteSegments {
                address: x[0],
                data: x[2..].to_vec(),
            }
        }
        14 => {
            need(2)?;
            if x[1] > 15 {
                return Err(ProtocolError::InvalidMessage);
            }
            SetModuleBrightness {
                address: x[0],
                brightness: x[1],
            }
        }
        15 => {
            need(2)?;
            ModuleError {
                address: x[0],
                error_code: x[1],
            }
        }
        _ => return Err(ProtocolError::UnknownMessageType(ty)),
    })
}
#[derive(Default)]
pub struct FrameDecoder {
    buffer: Vec<u8>,
    discarding: bool,
}
// Largest accepted payload is a ConfigureMatrix: type (1), config id (4),
// part metadata/subtype/counts (5), and up to 255 row + 255 column bytes = 520.
// WriteSegments is at most type + address + length + 16 data = 19 bytes, so
// the matrix is the maximum accepted layout. The custom trailing-zero COBS
// convention adds at most ceil(520 / 254) code bytes, so at most 523
// non-delimiter encoded bytes are buffered.
const MAX_ENCODED_FRAME_BYTES: usize = 523;
impl FrameDecoder {
    pub fn encode_frame(payload: &[u8]) -> Vec<u8> {
        let mut raw = payload.to_vec();
        raw.push(0);
        let mut out = Vec::new();
        let mut i = 0;
        loop {
            let start = i;
            while i < raw.len() && raw[i] != 0 && i - start < 254 {
                i += 1
            }
            let count = i - start;
            out.push((count + 1) as u8);
            out.extend_from_slice(&raw[start..i]);
            if i == raw.len() {
                break;
            }
            if raw[i] == 0 && count < 254 {
                i += 1;
                if i == raw.len() {
                    break;
                }
            }
        }
        out.push(0);
        out
    }
    pub fn push(&mut self, bytes: &[u8]) -> Vec<Result<Vec<u8>, ProtocolError>> {
        let mut result = Vec::new();
        for b in bytes {
            if *b == 0 {
                if self.discarding {
                    self.discarding = false;
                    self.buffer.clear();
                    continue;
                }
                if self.buffer.is_empty() {
                    continue;
                }
                result.push(decode_cobs(&self.buffer).map(|mut p| {
                    if !p.is_empty() {
                        p.pop();
                    }
                    p
                }));
                self.buffer.clear()
            } else {
                if self.discarding {
                    continue;
                }
                if self.buffer.len() == MAX_ENCODED_FRAME_BYTES {
                    self.buffer.clear();
                    self.discarding = true;
                    result.push(Err(ProtocolError::InvalidMessage));
                } else {
                    self.buffer.push(*b)
                }
            }
        }
        result
    }
}
fn decode_cobs(b: &[u8]) -> Result<Vec<u8>, ProtocolError> {
    let mut o = Vec::new();
    let mut i = 0;
    while i < b.len() {
        let code = b[i];
        if code == 0 {
            return Err(ProtocolError::InvalidMessage);
        }
        i += 1;
        let n = (code - 1) as usize;
        if b.len() - i < n {
            return Err(ProtocolError::InvalidMessage);
        }
        o.extend_from_slice(&b[i..i + n]);
        i += n;
        if code < 255 {
            o.push(0)
        }
    }
    Ok(o)
}
