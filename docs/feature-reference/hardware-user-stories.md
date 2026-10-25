# Hardware and firmware acceptance stories

These stories describe current behavior for a future rewrite, traced to commit `188f35e4108733358730e92ebd98f1912af5173a` (reviewed 2026-10-25). “Acceptance” means behavior established by implementation or identified tests, not a claim that this review ran hardware or tests. Source-derived gaps are marked explicitly. [Hardware](hardware.md), [serial protocol](serial-protocol.md), and [firmware](firmware.md) provide exact models, algorithms, bytes, and events; these stories add user intent, preconditions, workflows, failure paths, and evidence. UI-specific event names/forms belong in the UI reference.

## Hardware stories

<a id="hw-001"></a>

### HW-001 — Create and retrieve a reusable panel configuration

**Story.** As a controller builder, I want a named reusable hardware configuration so that a physical board can be associated with the same logical panel across port changes.

**Preconditions.** App database available; no hardware connection required.

**Happy path.** Create Device with name and optional description; app generates config_id; add/edit metadata; list configurations and open by ID or reported config_id.

**Acceptance criteria.** Name/config_id required; normal generated ID is 1…2,147,483,647 and checked against existing Device IDs; database unique constraint is final guard. Listing sorts by name. ID lookup returns requested preloads; config-ID lookup preloads inputs. Editing metadata preserves ID unless explicitly supplied replacement; saving DB does not implicitly reconfigure a board. ConfigId.parse requires a complete in-range decimal string, with no suffix.

**Failures/recovery.** Blank name returns changeset; duplicate config ID returns constraint error; absent lookup returns not_found. Generator retries collisions but supplied config_id is not constrained by valid? in Device changeset. A rewrite should decide whether to enforce that gap consistently.

**Evidence.** [Hardware context](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware.ex), [Device](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/device.ex), [ConfigId](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/config_id.ex); [context tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/hardware_test.exs).

<a id="hw-002"></a>

### HW-002 — Define physical analog and button inputs

**Story.** As a builder, I want each wired input named and typed so train bindings and joystick mappings can select it.

**Preconditions.** Saved Device; chosen physical pin; no hardware needed to prepare configuration.

**Happy path.** Add analog input with pin/sensitivity or button with pin/debounce; optionally name it; edit and list; remove obsolete input.

**Acceptance criteria.** Types analog/button only. Physical pin 0–127; analog sensitivity1–10 required; button debounce0–255 required; device/type/pin required. Inputs unique by device+pin, same pin allowed on different Devices. Form string values cast through Ecto. Lists sort pin and preload calibration. Direct API has no schema sensitivity/debounce default. Update/delete applies DB changes only.

**Failures/recovery.** Missing/invalid fields return changeset; duplicate pin rejects; unknown integer delete returns not_found. No shared pin-conflict check exists against outputs/matrix physical pins or board-specific capabilities; a rewrite must not advertise those as validated.

**Evidence.** [Input](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/input.ex), [Hardware](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware.ex); [Input tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/hardware/input_test.exs), [creation/range/uniqueness tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/hardware_test.exs).

<a id="hw-003"></a>

### HW-003 — Scan and identify a USB controller

**Story.** As an operator, I want plugged-in controllers discovered and identified without entering port parameters.

**Preconditions.** Serial.Connection running; device available on nonignored port; firmware speaks implemented protocol.

**Happy path.** Automatic scan starts1s after service startup and repeats every60s, or operator manually scans; open UART115200 in passive framed mode; settle3s; request identity; switch active; show connected port, firmware version, and config association.

**Acceptance criteria.** Ignore Bluetooth/debug/TONE substrings case-insensitively. Track connecting→discovering→connected; handshake up to5 writes/reads at1s per read; record version/config_id; manual :scan_complete is emitted when candidates queued, before all handshake tasks finish. Connection listings include status distinctions; connected_devices includes only connected. Port name is transient identity; saved config ID links configuration. Discovery accepts any valid IdentityResponse without request-ID comparison.

**Failures/recovery.** Empty successful read, malformed/unexpected message retries; UART error returns immediately; exhausted handshake becomes no_valid_response, then cleanup/failed. Open/discovery exits such as port_timed_out are caught; discovery failsafe10s. List APIs catch timeout/unavailable service and return[]. Those fallback lists do not prove no physical devices. No heartbeat timeout detects a silent connected board.

**Evidence.** [Connection](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/connection.ex), [Discovery](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/discovery.ex), [wire protocol](serial-protocol.md); [port-timeout tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/connection_port_timeout_test.exs), [connection tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/connection_test.exs). [Discovery tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/discovery_test.exs) use copied mock logic with3 attempts; production source governs5.

<a id="hw-004"></a>

### HW-004 — Disconnect, diagnose, and retry a port

**Story.** As an operator, I want a failed controller isolated with an understandable error while other ports remain usable.

**Preconditions.** Tracked port in active lifecycle; UART error/process loss or explicit disconnect.

**Happy path.** Store reason, mark disconnecting, close asynchronously, mark failed with timestamp; display formatted error; rescan/retry after repair.

**Acceptance criteria.** Cleanup failsafe5s; failed timestamp preserved on duplicate failure; pid cleared; retry eligible at≥30s on periodic scan; manual scan clears failed entries immediately to bypass backoff. Repeated disconnect of unknown/disconnecting/failed no-ops. Discovery task does not block list calls; stale success ignored after port leaves discovering. Permissions/busy/not-found/no-firmware/timeout receive specific display text.

**Failures/recovery.** Cleanup close failure exits/stops/kills safely; UART DOWN marks failed immediately with connection-lost text. Normal open still blocks Connection while UART.open pending. Generation-less port timeout/cleanup messages and success-close process lifecycle remain source-derived race/resource concerns; do not infer comprehensive cancellation from statuses alone.

**Evidence.** [Connection](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/connection.ex), [DeviceConnection](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/connection/device_connection.ex), [State](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/connection/state.ex); [lifecycle tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/connection/device_connection_test.exs), [state tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/connection/state_test.exs), [timeout/nonblocking/stale-result tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/connection_port_timeout_test.exs).

<a id="hw-005"></a>

### HW-005 — Apply a complete configuration and await confirmation

**Story.** As a builder, I want saved inputs/matrix/displays sent to the selected controller and a clear stored/failed result.

**Preconditions.** Existing Device; at least one direct input, matrix, or I2C module; connected target for successful serial writes.

**Happy path.** Apply; send Configure frames in direct-input pin order, matrix name order, display address order; use existing stable config_id, common total count, zero-based indices; await ConfigurationStored; persist confirmation/update connection; notify UI.

**Acceptance criteria.** `{:ok, config_id}` means submitted, not confirmed. Each matrix/module one part; virtual buttons and Outputs not separate parts. Display-only configuration allowed. ConfigurationStored produces `{:configuration_applied,port,device,config_id}` on hardware:configuration; reject/timeout produce configuration_failed. Completion deadline10s after all sends. Reapplying preserves config ID. No per-part ACK or auto retry.

**Failures/recovery.** Missing Device not_found; no parts no_inputs; nonconnected/unknown port/encode/UART errors propagate and stop sends, possibly after partial transmission. ConfigurationError→device_rejected; deadline→timeout; unknown/late ACK ignored. DB confirmation failure reports reason even after physical ACK. In-flight map keyed only config_id has no per-port exclusion or received-port correlation; concurrent reapply can overwrite timer tracking. This gap requires rewrite policy, not acceptance as desirable behavior.

**Evidence.** [ConfigurationManager](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/configuration_manager.ex), [Configure codec](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/protocol/configure.ex); [manager tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/hardware/configuration_manager_test.exs), [Configure bytes](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/protocol/configure_test.exs), [protocol tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/protocol/protocol_test.exs).

<a id="hw-006"></a>

### HW-006 — Inspect live raw control values

**Story.** As a builder/operator, I want the last value for each pin and a live stream for diagnostics and downstream controls.

**Preconditions.** Subscriber requests Hardware.subscribe_input_values(port) or an apply caused manager serial subscription; active board reports InputValue.

**Happy path.** Decode four-byte InputValue, cache pin→integer under port, publish each update; UI/train/calibration/joystick consumer reads map or subscribes.

**Acceptance criteria.** Topic hardware:input_values:{port}; exact event `{:input_value_updated,port,pin,value}`. Last value replaces prior one; pins/ports independent; negative signed values preserved. Unseen port returns%{}. No normalization/deduplication/timestamp is added in manager. Serial input has no config_id; receiving port determines association.

**Failures/recovery.** Bad binary logs and drops at serial layer. Cache purge removes ports absent from device_updates; implementation does not filter failed statuses, so retained failed entries can retain stale values. No freshness timeout exists. Rewrite must decide how to indicate stale data rather than assuming cache implies connection.

**Evidence.** [InputValue](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/protocol/input_value.ex), [ConfigurationManager](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/configuration_manager.ex); [cache/negative/purge/subscription tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/hardware/configuration_manager_test.exs), [signed-byte tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/protocol/protocol_test.exs).

<a id="hw-007"></a>

### HW-007 — Create a button matrix with virtual input identities

**Story.** As a panel builder, I want a row/column button grid exposed as bindable button inputs.

**Preconditions.** Device with unused virtual pin range; atom-keyed row_pins/col_pins arrays and name.

**Happy path.** Transaction inserts Matrix, ordered MatrixPins, and virtual button per cell. Open grid, rename buttons if desired through input API, and bind them like physical buttons.

**Acceptance criteria.** Physical row/column pins0–127; positions preserved. Cell r,c uses128+r*C+c, name RrCc, debounce50, typebutton, parent matrix. Lists preload ordered pins/buttons. Regular list_inputs hides virtual children; include_virtual_buttons opts in. A2×3 grid gives pins128…133. Any insert failure rolls whole matrix creation back.

**Failures/recovery.** Invalid physical pin/name/FK/virtual collision returns error. Multiple matrices collide because each begins128; >128 cells exceeds range. Row-column overlap/direct-pin overlap/empty dimensions have no dedicated validation and are unverified/unsafe cases, not advertised support.

**Evidence.** [Matrix](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/matrix.ex), [MatrixPin](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/input/matrix_pin.ex), [Hardware helpers](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware.ex); [matrix/context tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/hardware_test.exs).

<a id="hw-008"></a>

### HW-008 — Edit or remove a matrix while understanding binding loss

**Story.** As a builder, I want matrix wiring edits to yield a consistent new grid and predictable removal of obsolete bindings.

**Preconditions.** Existing Matrix; related virtual inputs may already be bound.

**Happy path.** Rename only to preserve children, or submit both new row/col arrays to recreate grid; delete matrix when removed physically.

**Acceptance criteria.** Name-only preserves virtual IDs and wiring. Both arrays trigger transaction deleting/recreating all MatrixPins and virtual Inputs, including when supplied arrays equal old arrays; dependent virtual button bindings cascade-delete. Only one array nonnil means no pin update. Empty attrs is no-op. Delete cascades children; ID delete missing returns not_found.

**Failures/recovery.** Invalid replacement rolls transaction back; callers should warn that successful resize loses old button identities/bindings and require separate configuration apply. UI guard details are separate; context itself does not prompt.

**Evidence.** [Hardware update_matrix/delete_matrix](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware.ex); [rename/resize/delete/filter tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/hardware_test.exs).

<a id="hw-009"></a>

### HW-009 — Calibrate an analog lever through endpoint and sweep samples

**Story.** As an operator, I want saved physical travel, inversion, and rollover so downstream controls use my lever correctly.

**Preconditions.** Selected saved Input, chosen port/pin, live input events; default max ADC1023, overridable.

**Happy path.** Start supervised session, subscribe to hardware:calibration:{input_id}; advance ready→collecting_min, collect endpoint data; sweep physical minimum toward maximum; collect maximum endpoint; finish analysis/save and receive calibration_result.

**Acceptance criteria.** Endpoint phases require≥10 samples and≥3 unique readings; sweep≥10 with no uniqueness condition. Public state exposes counts/unique counts/step/can_advance/result. Samples collect only during three collection phases; no same-pin values in ready. Analyzer uses signed median-delta inversion and large absolute-delta wrap heuristic, endpoint extrema chosen by direction. Save upserts one calibration; emits success/error then normal stop. No hardware firmware RetryCalibration request is part of this host wizard.

**Failures/recovery.** Insufficient endpoint→insufficient_samples, sweep→insufficient_sweep_samples; state unchanged. Invalid advance→invalid_step. Cancel stops without save/result; DB error returns result error. No inactivity timeout/device-disconnect cancellation/input-type check/one-session-per-input lock. Source uses default permanent supervised child restart despite “temporary” comments, so normal stop may restart a session; this is a lifecycle gap requiring explicit correction/decision in rewrite. No automated Session workflow test is assigned in current suite; do not imply complete wizard coverage.

**Evidence.** [Session](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/calibration/session.ex), [SessionSupervisor](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/calibration/session_supervisor.ex), [Analyzer](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/calibration/analyzer.ex), [Calibration schema](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/input/calibration.ex); [Analyzer tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/hardware/calibration/analyzer_test.exs), [Calculator tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/hardware/calibration/calculator_test.exs).

<a id="hw-010"></a>

### HW-010 — Normalize simple, inverted, and wrapped travel

**Story.** As a binding consumer, I want calibration applied deterministically across zero crossings and out-of-range motion.

**Preconditions.** Persisted Calibration with coherent physical endpoint/flags/H values.

**Happy path.** Normalize raw integer and read total_travel; downstream consumer scales as needed.

**Acceptance criteria.** Output integer0…total_travel, not0…1. Normal100→900 gives travel800; inverted900→100 also800; wrap900→100/H1023 gives224, raw1023→123 and0→124; inverted wrap550→735 gives839, raw0→550 and1023→551. Dead-zone midpoint selects nearest endpoint with exact rules in [hardware arithmetic](hardware.md#exact-normalization-arithmetic). Both wrap formulas include+1 for boundary crossing. Analyzer with<2 samples reports false flags; noisy majority direction supported.

**Failures/recovery.** Outside travel clamps. Direct save accepts inconsistent endpoints/H/range (required fields only); Calculator does not reject zero/negative travel. No notch recognition exists in hardware Analyzer. Rewrite should add validation only as an explicit behavior change.

**Evidence.** [Calculator](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/calibration/calculator.ex), [Analyzer](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/calibration/analyzer.ex), [Calibration](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/input/calibration.ex); [four-quadrant arithmetic tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/hardware/calibration/calculator_test.exs), [sweep tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/hardware/calibration/analyzer_test.exs).

<a id="hw-011"></a>

### HW-011 — Identify an input by moving or pressing it

**Story.** As someone assigning a control, I want to interact physically instead of remembering pin numbers.

**Preconditions.** Configured Input present in startup snapshot; its real connected port is publishing hardware values. Calibration is not required. Callback process alive.

**Happy path.** Start unlinked detection with any/button/analog filter and default60s deadline; first known event establishes baseline; subsequent significant move/press sends input metadata and value; session ends.

**Acceptance criteria.** Button any baseline inequality (press or release); analog absolute change strictly>50 from original baseline. Detection payload contains input_id,pin,input_type,name,device_id,device_name,value. Unknown pins and wrong type ignore. Matrix inputs included. Timeout sends detection_timeout; callback death/explicit stop terminates and cancels timer. Exactly one detection wins.

**Failures/recovery.** First press alone may establish baseline and require release/another movement. Exactly50 analog units does not detect; accumulated small moves eventually can. Snapshot does not include later connections/edits. Direct topic subscriptions do not ensure manager serial subscription; synthetic test_port is always subscribed and collisions overwrite. These are source limitations. Tests using synthetic values do not establish first-use real-port readiness.

**Evidence.** [InputDetectionSession](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/input_detection_session.ex); [detection/filter/timeout/caller-lifecycle tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/hardware/input_detection_session_test.exs).

<a id="hw-012"></a>

### HW-012 — Register and toggle a digital indicator output

**Story.** As a builder, I want named output pins that simulator output bindings or manual tests can switch high/low.

**Preconditions.** Device saved for metadata; target connected for successful command.

**Happy path.** Create/update Output with pin/optional name, select it in binding UI, or call set_output(port,pin,:high/:low).

**Acceptance criteria.** Saved pin0–255, name≤100, unique per Device; same pin across Devices allowed. Lists sort pin; get preloads Device. Configure does not include outputs. Command payload `07 pin 00|01`; fire and forget; caller receives UART result, not hardware state confirmation. Raw set API need not find an Output record.

**Failures/recovery.** Invalid metadata changeset; duplicate pin error; missing ID not_found; nonconnected/unknown port errors from Connection; invalid output enum codec invalid_value. No cross-table input/output conflict validation/readback/latched host cache is established.

**Evidence.** [Output](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/output.ex), [Hardware](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware.ex), [SetOutput](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/protocol/set_output.ex); [Output tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/hardware/output_test.exs), [protocol tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/protocol/protocol_test.exs).

<a id="hw-013"></a>

### HW-013 — Add an HT16K33 display and configure rendering

**Story.** As a cab-panel builder, I want physical display metadata and rendering settings reusable by train display bindings.

**Preconditions.** Device saved; known HT16K33 address; wiring validation is external to host model.

**Happy path.** Add module_chip ht16k33, address/name, embedded settings; list/edit/delete; apply Device configuration; bind/test from UI.

**Acceptance criteria.** Address0–255 unique per Device; parse decimal or lowercase0x; optional name≤100; params required. Defaults brightness8,digits4,14segment,dotfalse,right-aligntrue,min0.0; brightness0–15, digits4/8, display type7/14; nullable minimum supports no lower clamp in higher-level consumer. Display-only Device deploys. Only address/brightness/digits sent in Configure; render type/dot/alignment/min remain host metadata.

**Failures/recovery.** Missing fields/invalid params reject; uppercase0X prefix rejected. ModuleError after stored config only logs address/error code and does not roll back configuration. No host supported-address range narrower than byte or per-board I2C capacity validation exists. Saving metadata alone does not initialize physical module.

**Evidence.** [I2cModule](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/i2c_module.ex), [Params](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/ht16k33/params.ex), [ConfigurationManager](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/configuration_manager.ex); [I2C changeset/parser tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/hardware/i2c_module_test.exs), [renderer/params tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/hardware/ht16k33_test.exs), [display-only deploy test](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/hardware/configuration_manager_test.exs).

<a id="hw-014"></a>

### HW-014 — Render text/numbers and send display updates

**Story.** As a display-binding consumer, I want stable physical glyphs, padding, and decimal point handling.

**Preconditions.** Params chosen; connected port/module for real output; pure encoding itself needs no hardware.

**Happy path.** Encode string to seven-/fourteen-segment bytes, honor alignment and digits, then Hardware.write_segments.

**Acceptance criteria.** Fourteen-seg exactly2×digits bytes (low/high), table covers ASCII space…z, unmapped glyph blank; seven-seg exactlydigits bytes, limited glyph table, decimal bit80. Short strings padded, long prefix truncated. Right alignment prepends effective-length spaces. Seven-seg dot merges into previous slot if enabled; disabled dots skip; leading dot blank+DP. WriteSegments header0D,address,count plus≤16 bytes. Runtime brightness command0E,address,level0–15 is separately available at protocol layer.

**Failures/recovery.** Unknown characters render blank. Dot after last filled slot is ignored; fourteen-seg dot consumes a slot even when alignment subtracts it. >16 bytes encoding returns data_too_long; port errors propagate. Firmware ACK/readback absent. HT16K33 Configure encoding exists but host decode rejects it; rewrite should deliberately fix codec asymmetry.

**Evidence.** [HT16K33](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/ht16k33.ex), [WriteSegments](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/protocol/write_segments.ex), [brightness](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/protocol/set_module_brightness.ex), [Configure](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/protocol/configure.ex); [font/alignment/dot tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/hardware/ht16k33_test.exs), [segments tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/protocol/write_segments_test.exs), [brightness tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/protocol/set_module_brightness_test.exs).

<a id="hw-015"></a>

### HW-015 — Delete a configuration without removing a live panel association

**Story.** As an operator, I want protection against deleting the definition currently reported by a connected panel.

**Preconditions.** Existing Device; serial Connection query available for reliable safety check.

**Happy path.** Delete offline configuration; remove inputs/calibrations/matrices and Device; dependent relations cascade by DB policy. If connected board reports matching config_id, refuse.

**Acceptance criteria.** Connected matching config_id returns configuration_active. Matching failed/uploading/disconnecting entries do not block. All virtual inputs included in cleanup. No firmware erase is sent; a later board may still report an ID whose definition was removed.

**Failures/recovery.** DB deletions are sequential/nontransactional and intermediate results mostly ignored; Connection list fallback[] can weaken guard when unavailable. These are source-derived gaps, not desired destructive semantics. Existing tests prove ordinary cascade cases, not every partial failure/active-guard scenario.

**Evidence.** [Hardware.delete_device](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware.ex); [device deletion tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/hardware_test.exs), [serial list fallback tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/connection_port_timeout_test.exs).

<a id="hw-016"></a>

### HW-016 — Preserve protocol interoperability through malformed traffic

**Story.** As a firmware implementer, I want an exact binary contract and recoverable stream parser.

**Preconditions.** COBS-framed UART115200; message layouts in [serial reference](serial-protocol.md).

**Happy path.** Encode/decode known messages with unsigned little32 IDs, signed little16 values, exact bodies; buffer partial frames and decode multiple frames in order.

**Acceptance criteria.** Known types00–08,0D–0F;09–0C reserved/unknown. InputValue4 bytes, no config ID. Heartbeat empty body only. Matrix pin counts exact; Configure part indices zero based. Corrupt COBS frame is dropped while following valid frame survives. Empty delimiters ignored; flush clears buffer;254-byte block boundary matches documented bytes.

**Failures/recovery.** Unknown type/empty/nonbinary/invalid body return distinct errors; invalid UART payload logs/drops. No CRC, packet authentication, max buffer enforcement, or heartbeat-based liveness. RetryCalibration08 exists as codec but no host wizard caller/firmware execution guarantee is established here. Test isolation forbids accidental real serial enumeration.

**Evidence.** [Framing](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/framing.ex), [Message](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/protocol/message.ex), [RetryCalibration](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/protocol/retry_calibration.ex); [framing tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/framing_test.exs), [codec tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/protocol/protocol_test.exs), [retry tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/protocol/retry_calibration_test.exs), [ModuleError tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/protocol/module_error_test.exs), [serial isolation test](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/test_isolation_test.exs).

## Firmware stories

<a id="fw-001"></a>

### FW-001 — Refresh the release catalogue from firmware manifests

**Story.** As an operator, I want available firmware releases and exact device assets loaded into the app.

**Preconditions.** HTTP access to configured GitHub endpoint, Repo, running DeviceRegistry; optional github_token.

**Happy path.** Check releases; fetch each release.json; validate structure; upsert tag/release/files; reload registry; show refreshed catalogue.

**Acceptance criteria.** Endpoint/headers and required manifest fields in [firmware](firmware.md#release-fetch-and-manifest-validation). GitHub tag determines version; ISO publish date determines ordering. Only exact manifest-listed asset filenames create file rows; missing assets skip files, unrelated assets ignore. Repeat check updates same tag ID/notes; returned list includes updated releases. Valid manifest needed; no legacy filename fallback. One invalid manifest skips its release without discarding successful others.

**Failures/recovery.** HTTP status failure returns github_api_error; transport error propagates; malformed/missing manifest logs/skips. Structural checks do not validate full value types. Registry reload/file upsert results not transactional; response iteration can leave registry on older manifest. No pagination/checksum enforcement. User can retry after network issue.

**Evidence.** [Downloader](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/downloader.ex), [Firmware](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware.ex); [download/catalogue tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/downloader_test.exs), [manifest integration tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/release_manifest_integration_test.exs).

<a id="fw-002"></a>

### FW-002 — Select a manifest-supported device environment

**Story.** As a builder, I want the board choice to carry correct uploader parameters without maintaining a separate local hardcoded list.

**Preconditions.** Registry loaded from valid manifest.

**Happy path.** List alphabetically named board options; select environment; lookup programmer/MCU/speed/touch config; match release file environment.

**Acceptance criteria.** Runtime keys strings; config includes environment,display_name,firmware_file,mcu,programmer,baud_rate,use_1200bps_touch. Allow arduino/avr109/wiring/avrisp/usbasp only. MCU names normalize328p/32u4/2560 to avrdude short codes. Unsupported Due sam-ba/ESP32 esptool not offered even if files exist. No loaded manifest means empty list; startup attempts background self-healing fetch. Valid reload replaces entire ETS contents.

**Failures/recovery.** Unknown environment→unknown_device; empty/no-valid manifest clears registry and returns error; check releases to refill. Latest DB release with absent/invalid manifest does not search older ones. Legacy atom BoardConfig remains separate; stringifying atom is not a general environment alias migration.

**Evidence.** [DeviceRegistry](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/device_registry.ex), [BoardConfig](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/board_config.ex); [registry tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/device_registry_test.exs), [legacy board tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/board_config_test.exs), [release manifest tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/release_manifest_integration_test.exs).

<a id="fw-003"></a>

### FW-003 — Restrict firmware choices to compatible app versions

**Story.** As an operator, I want incompatible release lines visible but blocked from UI installation.

**Preconditions.** Cached releases; app firmware_version_requirement nil or valid requirement string.

**Happy path.** Check compatibility; select newest published compatible release for update notification; UI validates selected release before download/upload.

**Acceptance criteria.** Nil requirement permits parseable semver; malformed/nil version rejects. Leading lowercasev accepted. Non-nil requirement uses Version.match? allow_pre:false. Newest compatible is first published-desc match, not semantic maximum. Incompatible UI start produces clear compatibility message; compatible selection proceeds.

**Failures/recovery.** Invalid requirement raises config error; no matching release→not_found. UploadManager/Uploader do not enforce compatibility for direct callers, so rewrite must place invariant deliberately. Firmware.update_available? uses unfiltered latest and is distinct from notification path.

**Evidence.** [Compatibility](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/compatibility.ex), [Firmware](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware.ex), [FirmwareLive](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/firmware_live.ex); [compatibility tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/compatibility_test.exs), [latest-compatible tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware_test.exs).

<a id="fw-004"></a>

### FW-004 — Download and reuse the local firmware cache

**Story.** As an operator, I want a selected firmware file downloaded once and reused for flashing.

**Preconditions.** Saved FirmwareFile with release preload; writable cache and network for missing file.

**Happy path.** Derive v{version}_{environment-or-board}.hex path; create cache root; stream selected download URL; upload cached file on future selection.

**Acceptance criteria.** Production root ~/.trenino/firmware_cache; otherwise app priv/firmware_cache. Existence is cache hit, independent of DB flags. Environment preferred over board_type. HTTP200 returns file record; no post-download DB path flag. UI skips download when File.exists? already true.

**Failures/recovery.** Missing row not_found; mkdir failure cache_dir_error; non200 deletes destination and returns download_failed/status; network error deletes and propagates. No HEX parsing/size/SHA validation, atomic rename, or cache consistency for simultaneous requests. Legacy cache-list helper only recognizes numeric-dot versions and six alphabetic/underscore board atoms; dynamic IDs with digits may not list though usable. Rewrite should distinguish existence from integrity.

**Evidence.** [FilePath](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/file_path.ex), [Downloader](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/downloader.ex), [FirmwareFile](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/firmware_file.ex); [download tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/downloader_test.exs), [file existence tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/firmware_file_test.exs), [context cache tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware_test.exs).

<a id="fw-005"></a>

### FW-005 — Flash a board before Trenino firmware is installed

**Story.** As a new hardware user, I want to select an ordinary serial port and install firmware without first having it identified as a Trenino controller.

**Preconditions.** Compatible selected release/file cached; known environment; physical port; avrdude available. Valid Trenino identity is not required.

**Happy path.** UI selects release/port/environment, ensures cache; manager reserves original serial port, records start, spawns nonlinked upload task; avrdude writes/verifies; manager reports completion; port rediscovery resumes.

**Acceptance criteria.** Global single upload; ID random16 lowercase hex characters; serial token separate random16 bytes Base64; uploading status blocks normal scans. Unknown/unidentified port can reserve. Current info includes task ref/pid/file/port/environment/token/start. Command arguments and bootloader handling follow [firmware reference](firmware.md#executable-resolution-and-exact-avrdude-command). Success means avrdude exit0, saves output/history, emits upload_completed duration, clears current, releases token; rescan scheduled500ms.

**Failures/recovery.** Concurrent→upload_in_progress; absent file→firmware_not_downloaded; bad environment/executable/file→specific errors. Direct manager does not validate file/environment equality or compatibility. No post-flash identity/version/config-restore test occurs before success. Bootloader port renamed during upload is not separately reserved. Operator can rescan/retry on rediscovery failure.

**Evidence.** [UploadManager](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/upload_manager.ex), [Uploader](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/uploader.ex), [Connection](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/connection.ex), [FirmwareLive](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/firmware_live.ex); [upload flow tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/upload_flow_test.exs), [token/lifecycle tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/serial/connection/device_connection_test.exs).

<a id="fw-006"></a>

### FW-006 — Enter a 1200-bps bootloader and follow a changed COM port

**Story.** As a Leonardo/Micro/Pro Micro user, I want upload to find the reset bootloader even when Windows assigns a different port.

**Preconditions.** Manifest requires1200bpsTouch true; serial access released; UART available.

**Happy path.** Snapshot sorted ports; open original at1200; wait100ms; close; poll every300ms up to5s; choose new port then avrdude.

**Acceptance criteria.** Single new port selected; multiple new ports lexicographic max; original still present fallback immediately; no available port until deadline→bootloader_port_not_found. Temporary UART stopped after operation. Non-touch boards skip entirely. UART start/open touch error warns and falls back to original instead of failing upload.

**Failures/recovery.** No USB identity matching; unrelated new port can win; COM10 versus COM9 order is string order. If bootloader not found, product message suggests manual double-reset and upload within8s. No live timing guarantee derived from mocks.

**Evidence.** [Uploader touch/poll](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/uploader.ex); [delayed three-poll Windows upload flow test](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/upload_flow_test.exs).

<a id="fw-007"></a>

### FW-007 — Recover automatically from common bootloader/port failures

**Story.** As a Nano/USB user, I want limited targeted retries for transient ports and old bootloader baud rates.

**Preconditions.** Initial avrdude attempt returned nonzero output matching retryable classifier.

**Happy path.** Port-not-found waits2s and repeats once; bootloader-not-responding with arduino programmer tries alternate57600/115200 excluding initial; success completes normally.

**Acceptance criteria.** No retry for permission/signature/verification/unknown errors. Alternative retries continue only while same bootloader error; first different error returns. Exhaustion returns original output. Port repeat does not enter alternate-baud fallback. Retry progress resets0 with informative message; total duration includes retries. Case-sensitive classifier first-match order is preserved.

**Failures/recovery.** All alternatives fail→bootloader_not_responding; missing-port repeat failure returns original port_not_found even if second reason differs. Non-arduino programmer has no alternate. User guidance points to cable/board/reset/permission/log checks. No unlimited retry loop.

**Evidence.** [Uploader](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/uploader.ex); [old-bootloader flow tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/upload_flow_test.exs), [baud/error classification tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/uploader_test.exs).

<a id="fw-008"></a>

### FW-008 — Observe progress, detailed failure, and upload history

**Story.** As an operator, I want progress and preserved diagnostic output for each installation attempt.

**Preconditions.** Subscribe firmware:uploads; manager operation accepted; saved history available.

**Happy path.** Receive started, per-operation progress, completed or failed; inspect recent records with selected environment, port, timestamps, duration, status/output.

**Acceptance criteria.** Started/progress/completed/failed tuple shapes in [firmware](firmware.md#upload-coordination-ownership-and-events). Runner merges stderr/stdout, accumulates full output, matches Reading/Writing/Verifying progress. Manager handles early2-/3-tuple errors; ordinary failure saves reason string/full output and sends Sentry firmware_upload_failed; task crash saves crash detail and Sentry firmware_upload_crashed. History defaults50, UI10; started_at/id descending. Duration history second-truncated wall clock can differ from event monotonic duration.

**Failures/recovery.** Split progress chunks can miss line; percentages reset between operations/retries; output buffer unbounded. No process-start reconciliation of history status started. History insertion failure after port reservation can crash before cleanup. Source/test scope does not establish crash-safe persistence across host restart.

**Evidence.** [AvrdudeRunner](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/avrdude_runner.ex), [UploadManager](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/upload_manager.ex), [UploadHistory](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/upload_history.ex); [history tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/upload_history_test.exs), [uploader pattern tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/uploader_test.exs), [context history tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware_test.exs).

<a id="fw-009"></a>

### FW-009 — Cancel or time out an upload and release serial ownership

**Story.** As an operator, I want a stalled/cancelled upload to stop its subprocess so I can retry or reconnect.

**Preconditions.** Current upload ID; manager has task/token tracking.

**Happy path.** Cancel matching upload or overall120s timeout fires; kill task/linked OS Port before demonitor flush; release serial token; mark history and clear current.

**Acceptance criteria.** Cancel emits upload_failed/cancelled with user-cancel text; missing/wrong ID→not_found. Overall timeout invokes cancellation helper then additionally emits upload_failed/timeout; current implementation leaves history cancelled and publishes two failures, which must be treated as a known mismatch in rewrite design. Stale task results/monitor/timeout ignored. Runner separate120s idle-data timeout closes Port and classifies Timeout output; manager overall clock is independent.

**Failures/recovery.** Token mismatch release error not elevated by manager normal completion paths; no automatic history reconciliation/retry. Cancellation does not imply device contents unchanged or safe firmware rollback. Tests prove mocked task termination and port release, not physical firmware recovery.

**Evidence.** [UploadManager](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/upload_manager.ex), [AvrdudeRunner](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/avrdude_runner.ex), [Connection](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/serial/connection.ex); [cancel/timeout tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/upload_manager_test.exs).

<a id="fw-010"></a>

### FW-010 — Receive useful updates only when connected hardware needs them

**Story.** As an operator, I want firmware notifications relevant to attached controllers and a way to dismiss or manually refresh them.

**Preconditions.** UpdateChecker running and subscribed to device_updates; cached/latest compatible release known after check; hardware reports version.

**Happy path.** Startup check after5s; periodic24h respecting1h minimum and persisted last check; choose latest compatible release; compare connected versions; emit available if older; dismiss when no device needs update or user requests it.

**Acceptance criteria.** Only connected status/nonnil version considered; equal/newer ignored; malformed nonnil version conservatively needs update; no devices means no notification. Topic firmware:update_notifications has checking true/false, available version, dismissed. One check at a time; no repeated available while notification_shown true. User dismissal retains version and resets flag, allowing later device event to show again. Manual check_now **forces through rate limiter**, unlike outdated comment. Direct page refresh invokes Downloader separately. Keep last100 automatic check records, including failures.

**Failures/recovery.** Network error retains previous latest version and records failure timestamp; automatic retries still rate-limited. Task DOWN resets flag without checking-false broadcast; linked-task crash behavior needs supervision review. Dismissal is not persistent suppression: get_update_status may still report available. Newest-compatible-by-publish and simple tuple version parser differ from general semver. Firmware wrapper handles noproc status/dismiss/trigger with no_update/ok.

**Evidence.** [UpdateChecker](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/update_checker.ex), [UpdateCheck](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/update_check.ex), [Firmware](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware.ex); [device-aware notification/schema tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/update_checker_test.exs), [compatibility tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/compatibility_test.exs).

<a id="fw-011"></a>

### FW-011 — Resolve the packaged uploader on supported platforms

**Story.** As a desktop user, I want flashing to use the packaged avrdude or a discoverable system installation.

**Preconditions.** Desktop/release/development paths configured; chosen platform executable present or system PATH entry.

**Happy path.** Resolve APP_PATH first, bundled app/development priv/bin next, PATH last; locate optional conf; execute argv directly with unchanged file path.

**Acceptance criteria.** Windows avrdude.exe, others avrdude. Optional -C when conf found; -c,-p,-P,-b,-D,-U flash:w:path:i,-v arguments exactly. Version utility runs-? and returns regex version or unknown. No shell interpolation. Windows drive-letter path unchanged based on bundled8.x assumption.

**Failures/recovery.** Missing executable→avrdude_not_found/user install guidance; bang helper raises. Missing config simply omits-C. File.exists? does not prove executable permissions or actual bundled version. Current tests tolerate missing installations, so passing tests alone is not packaging verification.

**Evidence.** [Avrdude](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/avrdude.ex), [Uploader](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/uploader.ex), [Runner](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/avrdude_runner.ex); [Avrdude tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/avrdude_test.exs), [path/argument-related uploader tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/uploader_test.exs).

## Cross-cutting rewrite acceptance boundaries

Preserve known user-facing paths and exact working byte contracts, but do not silently carry accidental gaps as requirements. In particular: stable config IDs, per-port raw streams, four normalization modes, virtual button identities, display-only deploys, cached manifest-driven flashing, cancellation that terminates subprocesses, delayed bootloader re-enumeration, and compatibility-aware notification are implemented capabilities. Stronger validation, safe session restart policies, generation-tagged configuration/discovery operations, real disconnect cache invalidation, checksum enforcement, release-specific registry selection, timeout/history consistency, and post-flash verification are **rewrite decisions prompted by identified gaps**, not already verified features.

The [historical hardware guide](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/docs/hardware-setup.md) includes incorrect wire/sensitivity/normalization/notch statements. Firmware-side sampling, EEPROM atomicity, real I2C initialization/error-code meaning, physical board capacity, and actual RetryCalibration behavior require firmware-source/device evidence beyond this host repository.
