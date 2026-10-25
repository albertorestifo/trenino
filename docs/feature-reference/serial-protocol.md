# Serial transport and byte protocol

This is the implemented host contract at commit `188f35e4108733358730e92ebd98f1912af5173a`, reviewed on 2026-10-25. It describes the Elixir host, not an independently verified firmware implementation. No real port was opened during this review. For configuration semantics see [hardware](hardware.md), flashing and port ownership see [firmware](firmware.md), and executable acceptance stories see [hardware user stories](hardware-user-stories.md).

## Transport and framing

[Connection](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/connection.ex) opens each eligible UART with `active: false`, `speed: 115_200`, `framing: Trenino.Serial.Framing`, and `rx_framing_timeout: 1_000`. Other line settings are left to Circuits.UART defaults; this repository does not explicitly select parity, data bits, or stop bits. After the identity handshake it switches to `active: true`. Bootloader uploads use their separate board-specific baud rates.

[Framing](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/framing.ex) sends one message payload per zero-delimited COBS frame:

1. Append a zero to the payload.
2. Split it at zeros or after 254 nonzero bytes. Each block has a leading code equal to nonzero byte count plus one; a full 254-byte block uses `FF`.
3. Append a literal `00` frame delimiter to the encoded bytes.

The appended-zero implementation detail matters at block boundaries: 254 `AA` payload bytes become `FF` + 254 × `AA` + `01 00` (257 bytes); 255 `AA` bytes become `FF` + 254 × `AA` + `02 AA 00`. An ordinary heartbeat payload `06` becomes `02 06 00`; payload `00 11 00` becomes `01 02 11 01 00`. There is no packet length prefix outside message bodies, checksum, CRC, sequence number, encryption, or transport acknowledgement in this framing code.

Receive buffering concatenates new bytes, splits on every `00`, and processes all complete frames in order. Empty encoded frames are ignored. Decoding appends an implied zero after every block with code below `FF`, then removes exactly one final decoded byte. A code claiming more bytes than remain raises `ArgumentError`, which is caught and causes that frame to be dropped; following valid frames are still processed. A remaining incomplete buffer returns `:in_frame`; an empty buffer returns `:ok`. `flush/2` clears buffered bytes. `frame_timeout/1` returns no frames and retains state. Although `init/1` stores a `max_length` option, nothing enforces it: an undelimited stream can grow indefinitely. These are source observations; corruption detection beyond structural COBS checks is absent.

Evidence: [framing tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/framing_test.exs) cover standard examples, 254/255-byte boundaries, split frames, 500-byte random round trips, corrupt frames, and recovery to the next frame.

## Message notation and dispatch

All layouts below are **decoded payload bytes**, before COBS. Offset zero is always the type byte. `u8` is one unsigned byte; `u32le` is four unsigned little-endian bytes; `i16le` is a signed two's-complement little-endian two-byte value. Fixed-size decoder patterns require exactly the shown size, including rejection of trailing bytes. Wire config IDs permit unsigned 32-bit values even though normally generated application IDs are positive signed-32-bit-range integers.

[Message.decode/1](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/protocol/message.ex) dispatches by the first byte. Empty binary returns `{:error, :insufficient_data}`; an unrecognized byte returns `{:error, :unknown_message_type}`; nonbinary input returns `{:error, :invalid_input}`. Known messages with a bad body return `{:error, :invalid_message}`. Struct APIs represent input/output kinds with atoms and encoders convert to integer tags. Most encoders rely on binary construction rather than full field validation: callers must not assume the Ecto constraints are repeated at the wire boundary.

| Type | Message; usual direction | Exact decoded layout; total length | Host behavior |
|---|---|---|---|
| `00` | IdentityRequest; host → device | `00`, request_id `u32le` at 1–4; 5 bytes | Discovery writes and drains a fresh request on each attempt. |
| `01` | IdentityResponse; device → host | `01`, request_id `u32le` at 1–4, major `u8` at 5, minor at 6, patch at 7, config_id `u32le` at 8–11; 12 bytes | Converts version bytes to `"major.minor.patch"`; records firmware version/config ID. No board type, serial number, USB identity, or device ID is present. |
| `02` | Configure; host → device | Header and discriminated payload detailed below; variable length | One frame per direct input, matrix, or I2C module. |
| `03` | ConfigurationStored; device → host | `03`, config_id `u32le` at 1–4; 5 bytes | Completes matching in-flight configuration; no per-part ACK. |
| `04` | ConfigurationError; device → host | `04`, config_id `u32le` at 1–4; 5 bytes | Completes matching request with `:device_rejected`; no numeric reason/detail. |
| `05` | InputValue; device → host | `05`, pin `u8` at 1, value `i16le` at 2–3; 4 bytes | Caches/broadcasts raw integer values by receiving port and pin. **There is no config_id in this message.** |
| `06` | Heartbeat; nominally both directions | `06`; 1 byte, empty body | Codec exists; Connection only broadcasts it. No periodic heartbeat writer, pong handler, missed-heartbeat timer, or liveness enforcement exists in these modules. |
| `07` | SetOutput; host → device | `07`, pin `u8` at 1, value `u8` at 2 (`00` low, `01` high); 3 bytes | Fire and forget; invalid value atom returns `:invalid_value`; other received value bytes reject. |
| `08` | RetryCalibration; host → device | `08`, pin `u8` at 1; 2 bytes | Encoder explicitly accepts integer 0–255, otherwise `:invalid_pin`; codec support does not make this part of the host sampling wizard. |
| `09`–`0C` | Reserved, removed BLDC stubs | No supported payload | Dispatcher returns unknown-message-type. |
| `0D` | WriteSegments; host → device | `0D`, I2C address `u8` at 1, byte count `N:u8` at 2, N raw bytes at 3 onward; `3+N` bytes | Encoder permits at most 16 data bytes, otherwise `:data_too_long`. Decoder requires precisely N bytes but does **not** itself cap N at 16. |
| `0E` | SetModuleBrightness; host → device | `0E`, I2C address `u8` at 1, brightness `u8` at 2; 3 bytes | Encode/decode restrict brightness to 0–15; invalid encode returns `:invalid_brightness`. No acknowledgement. |
| `0F` | ModuleError; device → host | `0F`, I2C address `u8` at 1, error_code `u8` at 2; 3 bytes | ConfigurationManager logs a warning. No error-code enum, persistent status, retry, or failed-configuration event is defined. Module documentation says it follows ConfigurationStored for each failed module. |

IdentityRequest/Response sources: [request](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/protocol/identity_request.ex), [response](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/protocol/identity_response.ex). Response encoding splits a string into exactly three integer components; malformed versions can raise rather than return an error tuple. Configuration responses: [stored](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/protocol/configuration_stored.ex), [error](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/protocol/configuration_error.ex). Remaining codecs: [input](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/protocol/input_value.ex), [heartbeat](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/protocol/heartbeat.ex), [output](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/protocol/set_output.ex), [retry](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/protocol/retry_calibration.ex), [segments](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/protocol/write_segments.ex), [brightness](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/protocol/set_module_brightness.ex), [module error](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/protocol/module_error.ex). ModuleError encoding checks integer types but not byte bounds.

Byte examples established by [protocol tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/protocol/protocol_test.exs): request ID `12345678` hex is transmitted `00 78 56 34 12`; IdentityResponse with that request, version `1.2.3`, config `DEADBEEF` is `01 78 56 34 12 01 02 03 EF BE AD DE`; input pin 10/value −1 is `05 0A FF FF`. Signed minimum −32768 round-trips; data is not constrained to 0–1023 by the protocol.

## Configure discriminated union

[Configure](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/protocol/configure.ex) calls this protocol v2.0.0. Every part has this eight-byte common header:

| Offset | Field | Encoding |
|---|---|---|
| 0 | message type | `02` |
| 1–4 | config_id | `u32le` |
| 5 | total_parts | `u8`, number of frames for the complete configuration |
| 6 | part_number | `u8`, **zero based** index |
| 7 | input_type | `00` analog, `01` button, `02` matrix, `04` HT16K33; `03` reserved/removed BLDC |

| Kind | Bytes after offset 7 | Total decoded length |
|---|---|---|
| Analog `00` | offset 8 pin `u8`; offset 9 sensitivity `u8` | 10 |
| Button `01` | offset 8 pin `u8`; offset 9 debounce `u8` | 10 |
| Matrix `02` | offset 8 row count `R:u8`; offset 9 column count `C:u8`; offsets 10…`9+R` ordered row pins; following C ordered column pins | `10+R+C` |
| HT16K33 `04` | offset 8 address `u8`; offset 9 brightness `u8`; offset 10 num_digits `u8` | 11 |

For matrix bodies, `byte_size(rest)` must equal R+C. No minimum row/column count is enforced in the codec and empty lists round-trip. HT16K33 **encoding is implemented but decoding is missing**: `Configure.decode_body/1` has only analog, button, matrix clauses and its catch-all rejects HT16K33. The host sends this type successfully; a rewrite reproducing a symmetric codec should treat this as a known implementation asymmetry, not an intended wire prohibition. Wire encoder tests even encode `num_digits: 6`; persistent model validation permits only 4 or 8. Display type, dot handling, alignment, and minimum value are host-only parameters and are not sent in Configure. Outputs and virtual matrix button Input rows are also not separate configuration parts.

Example: config 42, one HT16K33 part at address `70`, brightness 8, four digits: `02 2A 00 00 00 01 00 04 70 08 04`. Matrix example, config `12345678`, three total parts, part one, rows 2/3/4 and cols 5/6: `02 78 56 34 12 03 01 02 03 02 02 03 04 05 06`.

Tests: [Configure variants](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/protocol/configure_test.exs), [general codec round trips](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/protocol/protocol_test.exs), [retry range](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/protocol/retry_calibration_test.exs), [module errors](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/protocol/module_error_test.exs), [brightness range](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/protocol/set_module_brightness_test.exs), [segments](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/protocol/write_segments_test.exs).

## Discovery and connection lifecycle

[Discovery.discover/1](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/discovery.ex) waits 3,000 ms for DTR-triggered reset/bootloader settling, flushes receive bytes (flush return is ignored), then makes up to **five** write/drain/read attempts. Each uses `:erlang.unique_integer([:positive])` as request ID and `UART.read(pid, 1_000)`. A valid IdentityResponse succeeds regardless of whether its request ID matches. Empty successful reads, unexpected messages, and decode errors cause a new request; `{:error, reason}` from read/write/drain is returned immediately. Exhaustion returns `:no_valid_response`. The moduledoc and [discovery tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/discovery_test.exs) describe three attempts, but those tests implement their own mock algorithm and do not invoke production Discovery; the source's five-attempt loop governs actual behavior.

[Connection](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/connection.ex) is one registered GenServer with a [State](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/connection/state.ex) map keyed by port name. [DeviceConnection](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/connection/device_connection.ex) fields are `port`, `status`, `pid`, `device_config_id`, `device_version`, `failed_at`, `upload_token`, `error_reason`, `error_type`.

| Transition | Trigger and state effects |
|---|---|
| untracked → connecting | Eligible scan result, UART process started/monitored; tracked immediately before open. |
| connecting → discovering | Open succeeds; schedule 10,000 ms discovery failsafe; run handshake in a Task. |
| discovering → connected | Handshake returns IdentityResponse and active-mode configure succeeds; save version/config ID and broadcast device list. |
| connecting/discovering/connected → disconnecting | Open error, discovery error/timeout, UART error, or explicit disconnect; preserve formatted reason and start async cleanup. |
| disconnecting → failed | Cleanup completion or 5,000 ms cleanup failsafe; clear pid and store monotonic `failed_at`; broadcast. |
| active UART dies → failed | `:DOWN` finds matching pid; use reason `"Connection lost unexpectedly"`; cleanup-state transitions directly. |
| failed → fresh connecting | Failed timestamp at least 30,000 ms old on subsequent scan; manual scan instead deletes all failed entries immediately. |
| any tracked/untracked → uploading | Exclusive firmware access request closes existing UART and generates Base64 token from 16 random bytes; pid becomes nil. |
| uploading → untracked | Matching token released; entry deleted, list broadcast, scan scheduled 500 ms later (no failed-port backoff). |

Initial automatic scan is scheduled after 1,000 ms; subsequent scans every 60,000 ms. Ports containing `Bluetooth`, `debug`, or `TONE`, case insensitively anywhere, are ignored. Public enumeration returns sorted names; discovery enumeration uses UART map keys. Scans cast per-port connect messages and eligibility is checked again at execution to avoid duplicate opening. A manual scan broadcasts `:scan_complete` immediately after queuing candidates; it does not mean all asynchronous handshakes have finished. No explicit physical port-presence diff runs: disconnect is detected by UART errors/process loss, not merely by a port disappearing from enumeration.

Discovery Tasks keep the server responsive during 3-second settling and reads; `UART.open` still runs in the Connection GenServer and can block it. Its exit signals are caught as error results; handshake exits are also caught in the Task. Late discovery results are ignored unless the port is currently `:discovering`. Timeouts are keyed only by port, not a generation/token. Cleanup closes the UART; if close fails/exits, it stops the process with a 100 ms deadline, then kills if needed. A successful normal cleanup close does not explicitly stop the UART process. Failsafes and statuses guard usual races, but this is not a fully generation-tagged state machine.

Only one port in the entire Connection state may be `:uploading`; requesting any second upload returns `:upload_in_progress`. An unknown port can be reserved for avrdude, enabling flashing before Trenino firmware is installed. Wrong/missing tokens return `:invalid_token`. The pure `DeviceConnection.release_upload/2` helper transitions to failed with a fresh timestamp; the actual Connection API instead deletes the entry for fast rediscovery. These are separate behaviors.

## Public calls, broadcasts, and failures

`connected_devices/0` returns only status `:connected`; `list_devices/0` returns all tracked statuses. Both catch any GenServer call exit and return `[]`, including unavailable or blocked Connection; default timeout 5,000 ms is overrideable with `:serial_connection_call_timeout_ms`. This means an empty list can mean temporary service failure, not only no hardware. `send_message/2` is a regular GenServer call: connected ports encode using `message.__struct__.encode/1` and pass bytes to UART.write; encoder error becomes `{:error, {:encode_failed, reason}}`; known nonconnected ports return `{:error, {:not_connected, status}}`; absent ports return `{:error, :unknown_port}`. UART write results are returned unchanged. That call does not share the defensive list-call catch.

| Topic | Event | Producers/consumers |
|---|---|---|
| `device_updates` | `{:devices_updated, all_tracked_connections}` | Connection; navigation, ConfigurationManager, train controllers, joystick manager, UpdateChecker consume. This list contains failed/disconnecting/uploading entries. |
| `device_updates` | `:scan_complete` | Manual scan only; consumers can stop scan indicators before discovery completes. |
| `serial:messages:{port}` | `{:serial_message, port, decoded_struct}` | Connection; ConfigurationManager subscribes lazily through apply/input subscriptions. Invalid payloads are logged and not broadcast. |
| `hardware:input_values:{port}` | `{:input_value_updated, port, pin, value}` | ConfigurationManager translates InputValue to cached/raw value events; calibration, input detection, train, display/UI, joystick paths use these. |
| `hardware:configuration` | `{:configuration_applied, port, device, config_id}` or `{:configuration_failed, port, device_id, reason}` | ConfigurationManager; configuration/device UI consumes. |

Atom errors retain `error_type`; tuple/string errors have nil type. Display strings map eacces → Permission denied, enoent → Port not found, ebusy → Port is busy (in use by another program), eagain → Resource temporarily unavailable, eio → I/O error, einval → Invalid port configuration, enxio → Device not configured, eperm → Operation not permitted, no_valid_response → No Trenino firmware detected, timeout → Connection timed out, port_timed_out → Device not responding. Other atoms replace underscores/capitalize; other terms use inspect.

Evidence: [connection state tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/connection/state_test.exs), [lifecycle/token tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/connection/device_connection_test.exs), [connection pure-behavior tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/connection_test.exs), and [port-timeout/responsiveness tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/connection_port_timeout_test.exs). The latter exercise actual Connection with mocked UART, including `:port_timed_out`, fallback empty lists during blocked open, immediate responses during discovery, and ignored stale discovery success. [Test isolation](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/test_isolation_test.exs) explicitly verifies that no application-owned serial process survives into forbidden real-hardware test contexts.

## Rewrite constraints and unresolved firmware facts

The [older hardware guide](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/docs/hardware-setup.md) describes an eight-byte InputValue containing config_id; the actual four-byte source/test contract above supersedes that text. Its nominal bidirectional heartbeat is a codec capability, not a host keepalive service. Configuration ID matching, part ordering and acknowledgement, and host timeout behavior are implemented; firmware EEPROM atomicity, firmware-side pin capacity, sampling rates, debounce timing units, module error-code meanings, and actual handling of RetryCalibration are not established by this host repository. Do not infer those from old prose or the existence of a codec. A rewrite needs captured-device or firmware-source verification for those details.
