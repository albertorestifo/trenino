# Desktop, settings, updates, distribution, and operational behavior

Baseline `188f35e4108733358730e92ebd98f1912af5173a`, 2026-10-25. Source analysis of repository behavior; external releases, installed drivers, live error reporting and installer behavior were not exercised during documentation. See [architecture](architecture.md), [data model](data-model.md), [virtual joystick](virtual-joystick.md), [UI](user-interface.md), and [platform user stories](platform-user-stories.md).

## Desktop startup and exit

Tauri is a native launcher around the same Phoenix/LiveView app served to a browser. There is no separate desktop implementation of business features. The launcher creates a centered, undecorated, fixed 400×300 splash using the bundled HTML as a data URL, then launches `trenino_backend` with **`--no-halt`** and environment:

| Variable | Value/purpose |
|---|---|
| PORT | 4000, fixed by launcher |
| MIX_ENV | prod |
| BURRITO | 1; production release behavior and migration startup |
| APP_PATH | launcher executable's containing directory, for native helper lookup |
| TRENINO_DISTRIBUTION | tauri-updater when compiled with desktop-updater; otherwise direct |

The sidecar event stream is consumed so it remains active; its termination sets an atomic backend-exited flag. The child handle is retained for exit cleanup. A thread polls `GET http://localhost:4000/api/health` up to 120 attempts, sleeping 500 ms after failed attempts. Any successful HTTP status is accepted. The code comment calls this two minutes, but the nominal sleep budget is **60 seconds**, plus HTTP request duration; readiness GET has no explicit per-request timeout, so this is not a strict total deadline.

Splash status uses attempt count, not reported migration progress: attempts below 10 show “Starting server…”, below 30 “Running database migrations…”, later “Almost ready…”. Successful readiness opens a 1200×800 main window with minimum 800×600 at localhost:4000, then closes splash. Failure changes splash text, waits three seconds, exits 1. The launcher does not automatically restart a backend that later exits, or verify that an existing service on port 4000 belongs to this launch.

Health attempts an existence query against `firmware_releases` (an empty table is valid). A successful query returns 200 `{"status":"ok"}`. Ecto query error reports migrations_pending; DB connection error reports database_unavailable; another rescued error reports unknown, all with HTTP 503. This known-table check does not independently prove every expected migration version has applied, and does not require simulator connectivity. See [HTTP contract](api-and-mcp.md).

On normal app ExitRequested, POST `/api/shutdown` with a two-second timeout. Success waits 500 ms. Failure falls back to killing the retained sidecar child. It does not wait for confirmed process exit after an ordinary successful shutdown. The backend endpoint returns JSON, then schedules `System.stop(0)` after 100 ms. Updater shutdown has a stronger contract below.

Evidence: [launcher](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/src-tauri/src/lib.rs), [health/shutdown](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/controllers/health_controller.ex), [splash](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/src-tauri/splash.html), [health tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/controllers/health_controller_test.exs).

## Preferences, simulator settings and consent

Application preferences are strings in `app_settings`, keyed by name. `Settings` exposes typed behavior; reads are from the database rather than an in-memory cache.

| Key | Default and interpretation |
|---|---|
| error_reporting | absent: not opted in; enabled/disabled persisted as strings |
| simulator_url | http://localhost:31270 when absent |
| simulator_api_key | stored override, otherwise read game key from disk |

`error_reporting_set?` checks for any existing raw value, whereas `error_reporting?` only accepts the known enabled atom. Unknown values are ignored as consent and can suppress the first-run prompt because a raw row exists. Atom conversion uses existing atoms, avoiding arbitrary atom creation. Writes use a key upsert; `key` and `value` must be nonblank. The context itself only requires a binary URL/key; it does not validate URL syntax or network connectivity. UI behavior and reconnect action are documented in [UI](user-interface.md).

Automatic key lookup runs only on Windows when there is no saved override. It reads `%USERPROFILE%/Documents/My Games/TrainSimWorld7/Saved/Config/CommAPIKey.txt`, then TSW6's analogous file. It trims content; it does not verify that the key is nonempty or works. Missing newer file allows fallback; another read error stops immediately rather than trying TSW6. Errors: `not_windows`, `userprofile_not_set`, `file_not_found`, `read_error`. No file write occurs. The explicit-profile helper can be tested on any OS. Saved API keys are ordinary database strings.

First-use consent blocks the default LiveView session until enabled or disabled is saved. HTTP APIs, MCP, health and shutdown have their own routes and do not pass through that gate. Declining still grants normal app access. When `SENTRY_DSN` exists, runtime config enables Sentry and an error-level logger handler with source/line/request metadata. `Settings.sentry_before_send` drops events unless consent is enabled; enabling does not turn on Sentry without a DSN. There is no automatic collection of all game/hardware telemetry described in this code.

Evidence: [settings context](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/settings.ex), [setting schema](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/settings/setting.ex), [file discovery](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/settings/simulator.ex), [runtime config](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/config/runtime.exs), [settings tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/settings_test.exs), [key lookup tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/settings/simulator_test.exs).

## Files, persistence and runtime environment

Production database defaults to `trenino.db` inside the platform data directory:

| OS | Directory |
|---|---|
| Windows | APPDATA/Trenino, then LOCALAPPDATA/Trenino, then ./Trenino |
| macOS | HOME/Library/Application Support/Trenino |
| Linux/other Unix | XDG_DATA_HOME/trenino when nonempty, otherwise HOME/.local/share/trenino |

Directory creation raises on failure. `DATABASE_PATH` overrides the production database filename; the standalone `Paths.database_path()` utility still derives its default path independently. Dev/test use repository-local `trenino_dev.db`/`trenino_test.db`. Production SQLite enables WAL, pool size 5 by default, 5,000 ms busy timeout, cache_size -64000, normal synchronous, and memory temp storage.

Other production variables: `POOL_SIZE`; `SECRET_KEY_BASE` (otherwise SHA-256 hex of database path, stable across restarts); `PHX_HOST` (localhost URL host); `PORT` (4000); `DNS_CLUSTER_QUERY`; `PHX_SERVER`; `BURRITO`; `SENTRY_DSN`; `TRENINO_DISTRIBUTION`. The HTTP listener binds 127.0.0.1 in runtime production config regardless of PHX_HOST, uses HTTP, `check_origin=false`, server=true. The desktop threat boundary is a single-owner loopback service. There is no user-account/login system in the routes. Tauri config enables global Tauri, sets CSP null, grants main-window core/opener plus backend-sidecar spawn, and creates windows in Rust rather than config.

At startup, the supervision tree runs migrations only when RELEASE_NAME or BURRITO is set. `Release.migrate` and `rollback(repo, version)` also support release execution without Mix. Several migrations are irreversible; see [data model](data-model.md). No general in-app backup/import/export feature is implemented. Installer retention of app data is distinct from an explicit backup workflow.

Evidence: [paths](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/paths.ex), [runtime](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/config/runtime.exs), [application](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/application.ex), [release helpers](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/release.ex), [Tauri configuration](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/src-tauri/tauri.conf.json), [capabilities](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/src-tauri/capabilities/default.json).

## Stable native updater

This feature exists only with Rust `desktop-updater`, which enables updater and dialog plugins and a Help → Check for Updates menu. The backend's older update-notice service is disabled when `TRENINO_DISTRIBUTION=tauri-updater`, avoiding two update systems. The base config contains the public key and stable feed URL; that alone does not compile the updater feature into every build.

The menu handler has an atomic busy guard. If the backend is already known to have exited, reject and ask for restart. Otherwise check with a 120-second updater timeout. No update shows a latest-stable dialog. An available version asks the user to install or defer and tells them to stop simulator control and finish flashing. This is user guidance; the updater does not inspect UploadManager or acquire a controller interlock.

The sequencing contract is **confirmation → download/signature verification → backend shutdown confirmation → install → restart**. Cancellation does none of those operations. Download/signature failure preserves the running backend. Shutdown POST has a five-second request timeout, then polls the sidecar termination flag every 100 ms up to 150 times. If no exit within 15 seconds, cancel installation. Installer failure is returned as failure. Error dialog explains retry/reopen; busy flag is cleared. A shutdown that succeeded but installation failed can leave the backend stopped until restart.

Feed is GitHub latest release asset `latest.json`; Windows install mode passive; updater artifacts enabled through a separate build overlay. Minisign verification authenticates update payloads; it is separate from Windows publisher/Authenticode trust. The first updater-enabled release still requires manual install by older clients. Nightly builds omit this stable update mechanism.

Evidence: [updater](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/src-tauri/src/updater.rs), [sequencing and unit tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/src-tauri/src/update_flow.rs), [artifact overlay](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/src-tauri/tauri.updater.conf.json), [release workflow](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/.github/workflows/release.yml).

## Legacy application-version notices

Direct/browser distributions run `AppVersion.UpdateChecker` unless disabled by config. Startup check after five seconds; periodic checks every 24 hours, configurable via `app_version_check_interval_ms`; manual trigger allowed. Concurrent requests are suppressed while checking. GitHub `/repos/albertorestifo/trenino/releases/latest` is queried with API accept and `trenino/<version>` user-agent headers. Strip optional leading v, compare Elixir semver to Application.spec version. 404 becomes no_releases; other non-200 status becomes github_api_error. Invalid version/tag data has no explicit defensive parse result handling.

State is memory-only: checking, latest_version, update_available. On success emit checking=false, and update_available when newer. On error clear checking but retain any previous notification. Dismiss clears current version/flag and broadcasts dismissal; it does not permanently suppress the version. Topic `app_version:update_notifications` has checking, available and dismissal messages. This offers a releases-page link; it does not install downloaded software. Public wrappers handle missing GenServer with benign defaults.

Evidence: [version context](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/app_version.ex), [checker](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/app_version/update_checker.ex), [nav integration](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/nav_hook.ex).

## Keyboard sidecar

Button bindings can invoke `Keyboard.key_down`, `key_up`, `tap`; each launches a short-lived Rust CLI with action and one key-combination argument, waits for exit, and treats exit zero as success. Resolution: APP_PATH executable, application priv/bin, then local tauri/keystroke release/debug build. File existence determines availability; it is not a permission/device readiness probe. Nonzero exits log output and return command_failed. The helper uses Enigo; input goes to the currently focused OS application.

Combination tokens split on `+`, compare case-insensitively without trimming. Modifiers CTRL/CONTROL, SHIFT, ALT, META/WIN/SUPER are pressed in input order, then main key; release reverses this. Last nonmodifier token wins. Supported names: F1–F12, SPACE, ENTER/RETURN, TAB, ESCAPE/ESC, BACKSPACE, DELETE/DEL, INSERT/INS, HOME, END, PAGEUP/PGUP, PAGEDOWN/PGDN, arrow aliases, NUMPAD0–9, and single characters lowered to Unicode. Unknown names warn then use their first lowered character. Modifier-only combinations have no main key. Individual Enigo operation errors are ignored; successful process exit is not proof the OS injected every event. CLI initialization failure panics.

Evidence: [Elixir keyboard adapter](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/keyboard.ex), [Rust key parser and dispatch](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/keystroke/src/main.rs), [button feature](train-profiles-and-controls.md).

## Install, uninstall and shared vJoy state

Windows NSIS `.exe` is the installer that runs custom lifecycle hooks; MSI does not run those hooks. NSIS uses 64-bit registry view and Sysnative PowerShell so its 32-bit process can inspect native driver state. If VC++ runtime's registry Installed value is not 1, execute bundled x64 redistributable `/install /quiet /norestart`, log exit, and delete setup payload. Unlike vJoy failure handling, VC++ installer nonzero status is logged without an explicit abort branch.

vJoy is pinned to 2.2.2.0. Existing exact-version uninstall metadata is insufficient by itself: inspect running `vjoy` system driver, file version/signature and successful vJoyConfig API probe. Healthy shared installations are retained. Stale exact-version installations are retained with a warning. A driver service with no matching supported metadata is also retained unless prior Trenino driver ownership permits its upgrade. Missing/owned upgrade paths verify bundled installer Authenticode before silent install; nonzero install aborts. Record HKLM `Software\Trenino\VJoyInstalledByTrenino=1` only on success; delete default device 1 from a newly installed driver so mode starts off. The vJoy setup executable is removed after installation; helpers remain resources.

Uninstall removes device 1 only if HKCU ownership marker exists **and** normalized capability output exactly matches the fixed Trenino descriptor. Clear marker only if deletion succeeds. Shared driver removal additionally requires HKLM ownership, exact installed version, a healthy API probe with all 16 devices explicitly missing, and interactive user confirmation defaulting to No. Silent uninstall always retains the potentially shared driver. Unverified enumeration, another device, absent ownership, or unknown version retains it. Ownership cleanup is separate from the user's SQLite preferences.

Evidence: [NSIS lifecycle hooks](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/src-tauri/windows/installer-hooks.nsh), [installer tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/ci/installer_hooks_test.exs), [third-party notice](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/tauri/src-tauri/resources/THIRD_PARTY_NOTICES.md), [distribution guide](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/docs/windows-distribution.md).

## Build and release feature inventory

| Entry point | Behavior and important limits |
|---|---|
| mix setup | Fetch deps, create/migrate DB, run empty seed scaffold, install/build assets |
| mix test | Create/migrate test DB then ExUnit; hardware adapters guarded in support code |
| mix precommit | Compile warnings-as-errors, unlock unused deps, format, strict Credo, tests; this alias can modify files |
| mix keystroke [--debug] | Cargo build native key helper; prints detected binary path |
| mix virtual_joystick [--debug] | Cargo build feeder helper |
| mix version X.Y.Z [--dry-run] | Strip leading v, validate numeric triplet, update five version files, optionally Cargo.lock |
| scripts/update-version.sh | Similar five-file version update via Perl; lock update failure is ignored |
| scripts/build-desktop.sh | Deploy assets, Burrito backend, stage platform sidecars/resources, cargo tauri build |
| scripts/build-macos.sh | Apple Silicon local app build via mise; downloads avrdude, builds key helper; not a release matrix job |

Mix application version/Tauri package/config/npm package/splash are 0.8.0 in the reviewed source; this is not a claim about the latest published release. Helper crates have independent versions. Mix supports standard release plus Burrito targets macos_arm64/windows_x86_64/linux_x86_64. Build-desktop's backend selection takes the first matching Burrito output, so a dirty output directory can select an unintended target. Its Windows checksum downloader pins avrdude 8.1; Windows staging separately verifies vJoy installer, SDK and license hashes. PowerShell resource staging also verifies BRUNNER signer and uses 7zip for SDK and innoextract for installer. Failed downloads never overwrite a verified destination. Non-Windows/macOS avrdude acquisition paths do not all use the same checksum mechanism.

Release workflow starts on a created release or a manual version input (prerelease events skip version verification). It checks Mix, Tauri config and Cargo package versions against the requested version, builds Windows x64 and Linux x64, stages prerequisites, creates signed stable updater artifacts/feed, and publishes releases. It does not itself run the full Elixir test suite; ordinary CI provides that check. Nightly runs daily at 00:00 UTC or manually, skips unchanged SHA, produces clearly named Windows NSIS/MSI and Linux AppImage artifacts retained seven days, and caches SHA only after success; it does not publish a stable updater feed. Standard CI tests Elixir, enforces Windows-only joystick bundle placement, builds/inspects Windows package without mutating driver state, and tests stable updater integration. MacOS is locally buildable but not in current stable/nightly prebuilt matrix.

Signing setup is an explicit maintainer script: protect key directory ACL, generate/reuse encrypted key, ensure public key matches embedded key, sign a public fixture, verify cryptographic possession through the Rust Minisign verifier, then upload two GitHub secrets. It rejects public-file mismatch and a stale public file masking a different private key; regression script uses throwaway material. Documentation review did not execute signing setup or change secrets.

Repository automation also includes Claude PR review/mention actions, weekly docs maintenance, Dependabot update configuration and analysis, CODEOWNERS, and local assistant skills. These support development; they are not user features of the running app. Historical specs/plans are catalogued as references in the coverage index; feature statements here come from current implementation.

Evidence: [Mix project](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/mix.exs), [Mix tasks](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/mix/tasks/version.ex), [desktop build](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/scripts/build-desktop.sh), [resource staging](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/scripts/stage-vjoy-resources.ps1), [signing setup](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/scripts/setup-updater-signing.ps1), [signature verifier](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/scripts/updater-signature-verifier/src/main.rs), [CI](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/.github/workflows/ci.yml), [nightly](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/.github/workflows/nightly.yml), [release](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/.github/workflows/release.yml).
