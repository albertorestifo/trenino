# Firmware catalogue, compatibility, download, and flashing

Implemented host behavior at commit `188f35e4108733358730e92ebd98f1912af5173a`, reviewed on 2026-10-25. This is firmware **management** in the Trenino app, not a review of microcontroller firmware source. Tests and source were read; no network release check, serial touch, or flash was executed. Related: [serial protocol and connection ownership](serial-protocol.md), [hardware model](hardware.md), [FW user stories](hardware-user-stories.md#firmware-stories).

## User workflow and module boundaries

[FirmwareLive](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/firmware_live.ex) presents cached releases newest-published first, hides older releases until expanded, opens an upload modal for a selected release, lets the user choose a serial port and manifest device environment, downloads the matching file when absent, and starts upload. A `?port=` parameter auto-opens the modal on the first listed release if releases exist. Port enumeration includes eligible serial ports before valid Trenino firmware discovery; installation therefore does not require a currently identified board. Changing a selection to an empty string does not clear its existing assign. The page shows the ten latest history entries and current upload; domain history default limit is 50.

The page's `start_upload` sequence is: `Compatibility.compatible?(selected_release)` → find file with exact `file.environment == selected_environment` → ensure local cache file exists or download → `Firmware.start_upload(port, environment, file.id)`. It blocks an incompatible selection with “This firmware is not compatible with this version of the app”; absent environment file gives “No firmware available for this device”; other failures display inspected reason. Compatibility is checked here, not inside UploadManager/Uploader, so programmatic callers must enforce their own policy. The modal's latest selection is based on published ordering and need not be latest compatible release.

[Trenino.Firmware](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware.ex) is the database façade and delegates catalogue downloads to Downloader, uploads to UploadManager, and automatic notifications to UpdateChecker. [DeviceRegistry](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/device_registry.ex) provides active manifest device/upload parameters. [Uploader](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/uploader.ex) resolves avrdude and device parameters, touches bootloaders, retries, and translates output. [AvrdudeRunner](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/avrdude_runner.ex) alone spawns the executable. Serial.Connection owns exclusive host port access; app TaskSupervisor owns nonlinked upload tasks.

## Data contracts

| Schema / table | Fields, defaults, validation |
|---|---|
| [FirmwareRelease](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/firmware_release.ex), `firmware_releases` | version and tag_name required strings; unique tag_name; optional release_url, release_notes, published_at UTC seconds, manifest_json; has_many firmware_files. No semver validation on insert; malformed stored versions can exist. |
| [FirmwareFile](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/firmware_file.ex), `firmware_files` | firmware_release_id, board_type string, download_url required; optional environment string, file_size integer, checksum_sha256 string; release FK and unique `(firmware_release_id,board_type)`. `board_type` is not an enum anymore; nonempty arbitrary strings can persist. environment is preferred for path/active selection. No checksum-format, size, URL, environment/board consistency, or extension validation. |
| [UploadHistory](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/upload_history.ex), `firmware_upload_history` | upload_id, port, board_type, status required; optional firmware_file_id FK, error_message, avrdude_output, duration_ms, started_at/completed_at. Status enum started/completed/failed/cancelled. board_type stores the selected environment string. No upload ID uniqueness/state-transition guard in schema changeset. |
| [UpdateCheck](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/update_check.ex), `firmware_update_checks` | checked_at required UTC seconds; found_updates boolean default false; optional latest_version,error_message. Persists automatic check rate-limit/debug history. |

All entities also have UTC inserted_at/updated_at. Release/file/history get functions return not_found on absent records; optional preload arguments default empty. Release upsert matches atom-keyed tag_name; found row is updated, absent row inserted. Lists and latest release order by **published_at descending**, not semantic version. latest_compatible scans that order for the first matching release, not maximum version. History orders started_at descending then id descending to break same-second ties; default limit50, optional preload.

History start helper forces started status and current UTC truncated to a second. Complete helper forces completed, saves optional avrdude_output, sets completion time and computes elapsed wall-clock milliseconds from rounded timestamps. Failed stores supplied error_message/output and completion/duration; cancelled sets cancelled and completion/duration without adding error message. No started_at gives duration nil. Live success event duration comes from monotonic uploader timing and can differ from history's coarse wall-clock duration.

Evidence: [release schema tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/firmware_release_test.exs), [file schema/cache tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/firmware_file_test.exs), [history tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/upload_history_test.exs), [Firmware context tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware_test.exs). Some legacy test names refer to “enum” or removed BoardConfig APIs; assertions/source show current string representation and retained delegates.

## Release fetch and manifest validation

[Downloader.check_for_updates/0](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/downloader.ex) calls Req GET on `https://api.github.com/repos/albertorestifo/trenino_firmware/releases`, with `accept: application/vnd.github.v3+json`, `user-agent: trenino/1.0`, and optional `authorization: token {github_token}` from app config. This is a source-recorded endpoint, not a live lookup performed in this review. No explicit pagination, draft/prerelease filtering, request timeout, or release count limit is set by this module; HTTP-client defaults apply.

Status200 yields body iteration. Other HTTP status returns `{:error, {:github_api_error, status}}`; transport errors propagate. For each release:

1. Find exact asset name `release.json`; if absent, skip entire release (no legacy filename fallback).
2. GET its browser_download_url. Status200 body may be decoded map or JSON binary; binary is Jason-decoded. Invalid JSON, nonmap, non200, network failure, or failed structural checks skip the release with logs rather than aborting all other releases.
3. Validate top-level keys `version`, `project`, `devices`; devices must be list. Every device must be a map containing `environment`, `displayName`, `firmwareFile`, `uploadConfig`; uploadConfig must be map with `protocol`, `mcu`, `speed`. Presence is checked, not comprehensive types/content/version/project identity. Empty device list passes Downloader structural validation (Registry later rejects it). One invalid device invalidates the whole manifest at Downloader validation.
4. Derive release version by stripping one lowercase leading `v` from **GitHub tag**, not manifest version. Store tag, html_url, release body, ISO8601 published_at (invalid/missing → nil), encoded manifest_json.
5. For each manifest device, find release asset with exact firmwareFile name. Matched assets become FirmwareFiles with board_type=environment, environment=environment, download_url, file_size. Missing referenced asset warns/skips file; unrelated assets are ignored. A valid manifest can produce a saved release with zero matching files.
6. Upsert release, then upsert each file by release/board_type, then reload DeviceRegistry using this manifest. Individual file upsert results and registry reload result are not checked before returning the release. Existing unreferenced file rows are not deleted. Only successful release upserts are returned in the final `{:ok, releases}` list.

The returned list contains successfully **created or updated** releases, despite “new releases” naming/comments. A repeat check can return a nonempty list with no genuinely new version. There is no transaction spanning release, files, and registry, no local checksum calculation, and no fetching or use of asset SHA256. Existing checksum field is stored metadata only.

Registry is reloaded once per successfully stored release in response iteration order. There is no “select newest compatible manifest after all releases” step. If API returns newest-to-oldest, the final active registry can reflect the oldest processed manifest; this is a source-derived integration limitation. Registry can also include a device whose referenced asset was missing, and a saved file may exist for an unsupported programmer filtered out of Registry. File catalogue and available flash-device choices therefore need reconciliation by caller.

Evidence: [Downloader tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/downloader_test.exs) mock HTTP and cover multiple releases, re-fetch updates, manifest-only asset selection, missing assets, 403/network errors, missing publish date, successful cache download, failed cache/network download, missing/invalid JSON/structure/devices, and custom manifest filenames. Their old fallback comments are superseded by assertions that invalid/no-manifest releases are skipped. [Manifest integration tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/release_manifest_integration_test.exs) use saved real-format v2.2.1 fixtures, not a current remote fetch.

## Dynamic device registry and legacy board definitions

DeviceRegistry is a GenServer owning public named ETS set `:firmware_device_registry`, read_concurrency enabled. Reads use ETS directly, with no unavailable-table recovery. Keys are **environment strings**, not legacy atom board types. Lookup returns `{:ok, config}` / `{:error, :unknown_device}`. All/list/select-options sort display_name; options are `{display_name, environment}`.

Registry config shape: environment, display_name, firmware_file, mcu, programmer, baud_rate, use_1200bps_touch. Parsed manifest uses uploadConfig.protocol/programmer, mcu normalization, speed/baud, requires1200bpsTouch or false. Normalization maps atmega328p→m328p, atmega32u4→m32u4, atmega2560→m2560; other binary names pass through. Supported programmer allowlist is exactly `arduino`, `avr109`, `wiring`, `avrisp`, `usbasp`. Devices using `sam-ba` (Due) or `esptool` (ESP32) are skipped, even if files exist in catalogue. Registry direct reload is more permissive than Downloader structural validation: entries missing required top-level device keys are skipped individually; unsupported protocols skipped. Unexpected malformed MCU/shape can still raise because this path is not a full schema validator.

Nonempty valid parsed devices clear ETS then insert all. Empty manifest clears registry and returns `:no_devices`; no valid entries clears and returns `:no_valid_devices`. “Fallback devices” means **empty registry**, not a hardcoded rescue list. At init, it reads only `Firmware.get_latest_release` and attempts Jason decode of its manifest_json; it does not search older releases if latest lacks valid JSON, and does not filter by firmware compatibility. If no usable manifest/valid devices, init schedules background Downloader.check_for_updates in a Task; exceptions are logged. This self-heal is separate from UpdateChecker rate limiting.

Filename detector accepts regex `trenino-([^.]+)(?:\.firmware)?\.hex$`, then confirms extracted environment exists in ETS. It is suffix-anchored, not start-anchored, and does not match arbitrary manifest filename or `.bin`. It is only a helper; Downloader matches manifest firmwareFile exactly instead. For example `trenino-nanoatmega328new.firmware.hex` works with that environment; actual manifest file `trenino-arduino-nano.firmware.hex` need not be inferable by detector.

[BoardConfig](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/board_config.ex) still supplies legacy atom board APIs and exact `tws-io-*` filenames, delegated by Firmware. **Uploader uses DeviceRegistry instead**, and does not use this table as fallback:

| Legacy atom | Name | MCU / programmer / baud | Touch | Legacy hex_filename |
|---|---|---|---|---|
| uno | Arduino Uno | m328p / arduino /115200 | false | tws-io-arduino-uno.hex |
| nano | Arduino Nano | m328p / arduino /115200 | false | tws-io-arduino-nano.hex |
| leonardo | Arduino Leonardo | m32u4 / avr109 /57600 | true | tws-io-arduino-leonardo.hex |
| micro | Arduino Micro | m32u4 / avr109 /57600 | true | tws-io-arduino-micro.hex |
| mega2560 | Arduino Mega 2560 | m2560 / wiring /115200 | false | tws-io-arduino-mega-2560.hex |
| sparkfun_pro_micro | SparkFun Pro Micro | m32u4 / avr109 /57600 | true | tws-io-sparkfun-pro-micro.hex |

Legacy get_config returns unknown_board; bang version raises. detect_board_type matches exact legacy filename; select options sort names. `Uploader.upload` accepts an atom only by Atom.to_string, **not** by mapping nano→nanoatmega328 or mega2560→megaatmega2560; an atom succeeds only if its string exists as a manifest environment. Tests accepting legacy inputs only assert error-tuple shape, not successful alias translation.

Evidence: [DeviceRegistry tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/device_registry_test.exs), [legacy BoardConfig tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/board_config_test.exs), [Uploader tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/uploader_test.exs). Historical fixtures contain Nano environments `nanoatmega328`, `nanoatmega328new`, and legacy `nano`; they are not interchangeable identifiers.

## Compatibility and update notification rules

[Compatibility](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/compatibility.ex) reads `:firmware_version_requirement`; current [config](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/config/config.exs) sets nil. Nil allows any parseable semantic version, including parseable prereleases because no range match is performed. Non-nil binary parses Version.Requirement and applies Version.match? with `allow_pre: false`; invalid/missing version rejects, a leading lowercase `v` is stripped. Invalid requirement strings raise Version.InvalidRequirementError, nonbinary nonnil config raises ArgumentError. These are configuration errors, not recoverable UI validation. Newest compatible release scans by publish time.

`Firmware.compare_versions` uses Version.compare after stripping one `v`; malformed versions may raise. `Firmware.update_available?` compares against newest **unfiltered** release, whereas UpdateChecker intentionally uses latest compatible release. Neither check automatically flashes or modifies saved hardware configurations.

[UpdateChecker](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/update_checker.ex) maintains last_check_at, latest_version, checking flag, notification_shown flag, auto_check. Defaults: auto_check=true, startup_delay=5,000 ms, check_interval=24h, min_check_interval=1h. Options override intervals; app `:firmware_check_interval_ms` overrides default check interval; initial_version optional nil. With auto_check enabled it restores most recent check timestamp from DB, schedules startup check and periodic timer. A periodic message schedules next periodic interval even when skipped. With auto_check=false, no DB restore/timers, but manual checking still works.

No overlapping check runs: checking=true skips another. Automatic checks respect elapsed minimum interval across restarts. `check_now` passes force=true and **bypasses minimum interval**, contrary to its public comment; direct FirmwareLive check_updates calls Downloader synchronously and bypasses this entire process/history rate limiter as well. Async task emits checking true then on ordinary result false. Failure still records checked_at and limits subsequent automatic retries; previous latest_version is retained on error. A task DOWN handler resets checking=false but does not emit checking-false or history; Task.async is linked, so abnormal crashes also need supervision consideration.

Success records newest compatible version; `found_updates` is returned-release-list nonempty (not true semantic novelty). No compatible version records false/nil and error_message `No compatible releases found`. Error stores `GitHub API error: {status}` or inspected reason. It keeps only last100 checks by checked_at. On success or device-update event it decides whether any status-connected device with nonnil firmware version is older than latest. Parsing strips leading v, requires exactly three decimal components, compares integer tuples. Any unparseable nonnil version conservatively needs update. This parser differs from full Version semver: prerelease/build metadata parse as invalid and thus “needs update.”

Topic `firmware:update_notifications` events:

| Event | Trigger |
|---|---|
| `{:firmware_update_checking, true/false}` | Start and ordinary finish of async check. |
| `{:firmware_update_available, version}` | At least one older connected device and notification_shown false. |
| `:firmware_update_dismissed` | User dismisses or no connected device needs update while notification shown. |

Dismiss retains latest_version and merely sets notification_shown=false. Therefore get_update_status can still return update_available after dismissal if a device needs it, and any later device_updates event can show it again (not only a new device). No devices, nil device versions, equal/newer versions yield no update. Firmware context catches only noproc exits for status/dismiss/trigger (status fallback no_update, others ok); subscribe is PubSub subscription and does not require checker process even though delegate docs suggest not_running.

Evidence: [compatibility tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/compatibility_test.exs), [update checker tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/update_checker_test.exs), [compatible-release context tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware_test.exs). Update tests verify device-aware notification/show/dismiss/re-show; their helper-based version tests mirror private logic rather than executing it. A no-device dismissal test cannot establish that dismissal hides get_update_status for an older connected device.

## Local cache and download semantics

[FilePath](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/file_path.ex) derives paths rather than storing paths in DB. If app `:env == :prod`, cache root is `~/.trenino/firmware_cache`; otherwise Application.app_dir `priv/firmware_cache`. File name is `v{release.version}_{environment || board_type}.hex`, converting atom identifiers to strings. No sanitization or atomic temporary-file naming exists here. A file struct must have firmware_release preloaded as actual FirmwareRelease for one-argument path construction.

`downloaded?` means File.exists? at that path, **not** valid HEX, expected size, checksum, readable regular file, or compatible board. `ensure_cache_dir` wraps mkdir_p failure as `{:cache_dir_error, reason}`. Downloader streams Req body directly into File.stream!(destination) with decode_body:false; 200 succeeds and returns file record without updating metadata/checksum. Non200 removes destination and returns `{:download_failed,status}`; network failure removes destination and returns error. Existing cache content can be overwritten, and no caller-level checksum verification or transactional rename is performed.

`FilePath.list_downloaded` enumerates `.hex` names matching `^v([0-9.]+)_([a-z_]+)\.hex$`, converts identifier to atom, and retains only legacy BoardConfig.board_types. Consequently dynamic identifiers with digits (`nanoatmega328new`, `megaatmega2560`), prerelease versions, and arbitrary new environments can be downloaded/uploaded but not listed by this legacy helper. It returns [] on directory listing failure. The function uses String.to_atom for matching filenames; not an unrestricted remote registry path, but distinct from safer existing-atom parsing.

## Upload coordination, ownership, and events

[UploadManager](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/upload_manager.ex) allows exactly one current upload globally. Another start returns `:upload_in_progress`. Start loads FirmwareFile with release; requires FilePath.downloaded? or `:firmware_not_downloaded`; requests serial exclusive upload access (which can also return upload_in_progress); generates upload ID from eight random bytes encoded lowercase hex; creates started history; starts Task.Supervisor.async_nolink to run Uploader; schedules overall120,000 ms timeout; stores upload info and broadcasts started. It does not validate requested environment against file.environment/board_type, selected release compatibility, or port nonempty at this domain boundary.

Current upload shape: upload_id, port, environment, firmware_file_id, task_ref, task_pid, release_token, started_at monotonic milliseconds. Serial access token is separate from upload ID. Connection closes its UART and marks port uploading so normal discovery will not reopen it. A matching release token deletes tracking and schedules rescan500 ms later; wrong token returns invalid_token. The reservation is for the original port name: if a bootloader enumerates under another port, that newly named port is not separately reserved by this API.

Topic `firmware:uploads`:

| Event | Payload and outcome |
|---|---|
| `{:upload_started, upload_id, port, environment}` | Manager accepted and spawned work. |
| `{:upload_progress, upload_id, percent, message}` | Callback forwards runner/retry progress; not necessarily monotonic/global percentage. |
| `{:upload_completed, upload_id, duration_ms}` | Success: release serial token, complete history with full output, clear current. |
| `{:upload_failed, upload_id, reason, message}` | Failure: release token, fail history with reason string/full output, report Sentry, clear current. Early two-element errors are expanded with nil output. |
| same event, reason `:crash` | Monitored task DOWN: release token, history `Task crashed: {inspect(reason)}`, Sentry firmware_upload_crashed, message “Upload task crashed unexpectedly.” |
| same event, reason `:cancelled` | Explicit cancel kills task (therefore linked OS Port), demonitor flush, releases token, marks history cancelled, emits “Upload cancelled by user.” |

Cancel requires current matching upload_id else not_found. It kills before demonitoring to avoid a surviving subprocess. Stale task results/DOWN/timeout for noncurrent ID/ref are ignored. Timer references are not stored/cancelled; stale timeout is ignored after completion. Overall timeout calls **the same cancellation helper**, causing a cancelled event/history, then emits additional failed event with `:timeout`. Thus listeners see cancelled then timeout, while history remains cancelled rather than failed. This discrepancy is implemented, not a proposed requirement. Sentry error capture occurs on ordinary failure/crash, not explicit cancellation path.

History insert is pattern-matched as success after acquiring the serial token; unexpected DB failure can crash the manager before its normal cleanup path. No startup reconciliation scans started history rows or automatically recovers ownership after manager restart in this module. These are source-derived recovery limitations to address explicitly in the rewrite.

Evidence: [UploadManager tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/upload_manager_test.exs) use fake avrdude runner to prove task death on cancel/timeout and release original port; they inject timeout to avoid a two-minute wait. They do not physically prove bootloader recovery or cover every history/status edge. [Upload flow tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/upload_flow_test.exs) mock execution and UART, proving success shape, nonretryable errors, old-Nano alternate baud, and Windows delayed COM re-enumeration.

## Executable resolution and exact avrdude command

[Avrdude](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/avrdude.ex) resolves executable in priority order: `{APP_PATH}/avrdude.exe` on Windows (`avrdude` otherwise); application `priv/bin`; dev priv/bin; System.find_executable PATH. Existence is checked, not version/executable permissions. Failure `:avrdude_not_found`; bang function raises. conf_path checks APP_PATH/avrdude.conf, bundled/dev priv/bin/avrdude.conf, else not_found. version invokes `-?`, redirects stderr, ignores exit status, extracts regex `avrdude version (\S+)`, else `"unknown"`.

Uploader builds an argv list (no shell command), optionally prepending `-C {conf_path}`, then:

```text
-c {programmer} -p {mcu} -P {upload_port} -b {baud_rate} -D -U flash:w:{hex_file_path}:i -v
```

`-D` disables auto erase; Intel HEX format is explicitly `:i`. Windows drive-letter paths pass through unchanged; bundled avrdude8.x behavior is assumed in source comment. Uploader verifies only File.exists? for the hex path, despite wording “readable.” Avrdude resolution precedes registry lookup, which precedes file check; missing executable can mask unknown-device/missing-file errors.

## Bootloader touch, subprocess progress, and retries

If use_1200bps_touch false, upload uses original port. If true: capture sorted ports before; start UART; open original port at1200; wait100 ms; close; poll available ports until five-second monotonic deadline at300 ms intervals. One new port wins; multiple new ports choose lexicographically largest string via Enum.max (not numeric COM ordering); if no new port but original still present, immediately use original; if none at deadline, bootloader_port_not_found. UART start/open failures merely warn and fall back to original port. Temporary UART is stopped after handling. No USB serial-number matching or board VID/PID association is used.

Runner opens Erlang Port `:spawn_executable` with binary/exit_status/stderr_to_stdout and argv. It accumulates all stdout/stderr until exit0→ok or nonzero→error. Each receive gap of120,000 ms closes Port and appends `[Timeout: avrdude did not respond within 2 minutes]`; any new chunk restarts this idle timeout, while UploadManager's separate overall timer remains120s. Full output accumulation is unbounded. Progress regex is `(Reading|Writing|Verifying)\s+\|.*?\|\s+(\d+)%`; reading message “Reading device...”, writing “Writing flash (N%)”, verifying “Verifying (N%)”. Parsing is per incoming chunk split by newline, with no carry-over buffer, so a split progress line may be missed. Percentage is per operation and retries can reset to0.

Retry policy after initial attempt:

| Classified failure | Behavior |
|---|---|
| port_not_found | Report0 “Port not found, retrying...”, wait2,000 ms, one repeat with same port/config. If repeat fails with any type, return original port_not_found and original output. Does not fall through to alternate-baud logic. |
| bootloader_not_responding | Only programmer `arduino` has alternatives `[57600,115200]`, excluding already-tried rate; report0 “Retrying at {baud} baud...”. Continue alternatives only for same bootloader error; other retry error returns immediately. Exhaustion returns first output. Other programmers have no alternate. |
| all other failures | Return immediately, no retry. |

On success duration includes preparation/touch/retries and is monotonic nonnegative; output is successful attempt's output, not all failed attempts. Initial failed output is separately logged. [Uploader tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/uploader_test.exs) cover pattern classification, messages, accepted call types, unchanged paths, alternate rates; some regex tests test copied regex rather than running Runner. [Avrdude tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/firmware/avrdude_test.exs) tolerate installed/missing executables, so their pass alone does not prove bundled binary availability.

## Error classification and user recovery contract

Classifier uses ordered, **case-sensitive** substring patterns. First match wins:

| Pattern(s), all required when multiple | Reason | User guidance |
|---|---|---|
| permission denied | permission_denied | Linux dialout, macOS serial access, Windows administrator access. |
| can't open device; or cannot open port | port_not_found | Check device USB, data-capable cable, connected-device listing; one automatic retry. |
| programmer is not responding; not in sync; stk500 + not responding; initialization failed; butterfly + AVR910 | bootloader_not_responding | Pro Micro/Leonardo/Micro double-tap reset then upload within8s; otherwise correct board/power/USB/cable; automatic arduino alternate baud. |
| device signature | wrong_board_type | Select physical board type correctly. Broad pattern can classify output containing signature even if another issue exists. |
| verification error | verification_failed | Firmware written but verification failed; USB/power/hardware checks, retry. |
| Timeout | timeout | Device stopped responding; check USB/board and retry. |
| none | unknown_error | Inspect log. |

Early reasons include hex_file_not_found (download first), avrdude_not_found (install/bundle avrdude), unknown_device (refresh releases/select recognized environment), bootloader_port_not_found (manual reset/retry/cable). Other atoms get generic unexpected-error text. Uploader returns two- or three-element errors depending on early failure; manager normalizes. The error guidance strings are current product copy, not independently validated platform recommendations.

## Rewrite boundaries and unverified behavior

The [setup guide](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/docs/hardware-setup.md) describes one-click flashing and seven named board variants. Active catalogue support is manifest/protocol-driven, legacy six-board helpers remain, and no boards are available without a loaded manifest. Checksums are a schema capability but not enforced; compatibility is UI/checker policy, not a universal upload guard. No post-flash identity/version verification, configuration restoration, EEPROM migration, automatic rollback, or firmware health check is in this host upload pipeline. Completion means avrdude exit0, not a successfully rediscovered/configured physical controller. The serial layer schedules rediscovery after token release; firmware identity is learned later through its ordinary handshake.

Source-derived limitations listed above should be decided deliberately during rewrite. None of the mocked tests establishes actual board electrical support, bootloader timing on every OS, power-loss recovery, or MCU-side protocol/storage behavior.
