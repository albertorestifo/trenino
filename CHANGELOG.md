# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

### Changed

### Fixed

### Removed

## [0.7.4] - 2026-05-09

### Fixed

- **Windows firmware flashing: avrdude now found correctly** — `APP_PATH` is passed from the Tauri wrapper to the Elixir backend at startup, allowing the bundled avrdude to be located in the installation directory (root cause of all boards failing to flash on Windows, [#76](https://github.com/albertorestifo/trenino/issues/76))
- **Windows firmware flashing: removed fragile `-U` path workaround** — avrdude 8.x handles Windows drive-letter paths natively; the relative-path transformation that broke on cross-drive setups has been removed
- Serial connection: device discovery now runs in a background Task so the Connection GenServer stays responsive during the DTR settle delay and identity handshake
- Firmware upload: cancelled or timed-out uploads now correctly kill the avrdude process; previously, cancelling left avrdude running and released the serial port prematurely
- Protocol: replaced O(n²) binary concatenation in COBS encoding with an O(n) list accumulator
- Intermittent Connection GenServer test failures resolved (stale port state between tests)

## [0.7.3] - 2026-05-03

### Added

- Linux x86_64 AppImage installer in nightly builds and releases
- Better Stack error tracking via Sentry SDK, activated when `SENTRY_DSN` env var is set
- **Firmware version compatibility checks** — incompatible releases are now badged in the firmware page and the install/upload buttons are disabled with a clear explanation
- **Error reporting consent screen** — first-run screen at `/consent` lets users opt in or out of error reporting before using the app; redirects automatically until a preference is set
- **Settings page** with error reporting toggle and simulator connection configuration; accessible via the gear icon in the navigation bar
- Firmware devices with unsupported upload protocols in the manifest are now rejected at download time with a clear error (closes [#76](https://github.com/albertorestifo/trenino/issues/76))

### Changed

- Navigation bar: Simulator link replaced with a Settings gear icon
- Simulator URL and API key are now configured via the Settings page instead of environment-level config

### Fixed

- Windows firmware flashing: replaced fixed bootloader wait with a 5-second polling loop for COM port redetection, fixing timeouts on slower machines
- Firmware upload failures are now captured in Sentry with the full avrdude output for easier debugging
- Double URL-encoding of the port name in firmware install links
- Startup log demoted from `error` to `info` when no firmware manifest is available yet
- Nightly build pipeline
- Windows NSIS installer now bundles the Visual C++ Redistributable, eliminating "missing runtime" errors on fresh Windows installations
- Burrito Linux builds now download precompiled ERTS from Beam Machine, reducing CI build times and workarounds

### Removed

- All BLDC (brushless motor) functionality — the experimental code has been removed from the codebase

## [0.7.2] - 2026-03-09

### Added

- MCP tools for Lua script CRUD operations (create, read, update, delete scripts via AI)

### Changed

- Removed `detect_simulator_endpoint` MCP tool (redundant with existing detection tools)
- Clarified simulator API path format in MCP tool descriptions

### Fixed

- Fix LiveView crash when serial Connection GenServer is blocked by UART timeouts
- NavHook no longer blocks on mount; device/simulator state loads asynchronously via PubSub
- `list_devices` and `connected_devices` return empty list instead of crashing on GenServer timeout
- Fix commands parameter arriving as JSON string in sequence MCP tools
- Reload controller bindings after MCP tool updates to output bindings or button bindings
- Remove noisy `node-invalid` debug log from OutputController

## [0.7.1] - 2026-03-06

### Changed

- Info flash notifications auto-dismiss after 5 seconds
- Input selection list now shows lever name as primary text for easier identification

### Fixed

- Fix crash when opening the "Add Input" modal due to missing `bldc_enabled` assign
- Add missing `checking` attr declaration on `empty_releases` component in firmware page

## [0.7.0] - 2026-03-06

### Added

- **Lua scripting system for train automation**
  - New Script schema and database migration for storing Lua scripts per train
  - ScriptEngine providing sandboxed Lua execution environment with Trenino API
  - ScriptRunner GenServer for executing scripts with configurable triggers (manual, on_train_active, on_input_change)
  - Dedicated script editor LiveView page with syntax highlighting
  - Scripts section added to train edit page for managing train-specific automation
  - REST API endpoints for script management (`/api/scripts`)
  - Claude Skill for AI-assisted Lua script authoring (`.claude/skills/lua-scripting.md`)
- **Native MCP server for AI-powered train configuration**
  - Built-in MCP server at `/mcp/sse` for integration with Claude Desktop and Claude Code
  - 22 tools organized across 7 categories: Simulator, Trains, Elements, Devices, Detection, Output Bindings, Button Bindings, and Sequences
  - Element tools for managing train buttons and levers directly from AI conversation
  - **Interactive detection tools** — Claude can now prompt you to press a button or move a lever on your hardware, or interact with a control in Train Sim World, and automatically detect the input/endpoint via a UI modal overlay
  - MCP setup documentation (`docs/mcp-setup.md`) with configuration examples
  - See [MCP Setup Guide](docs/mcp-setup.md) for details
- **BLDC haptic lever UI hidden behind `enable_bldc_levers` feature flag** — the feature remains under development and is excluded from stable releases; enable with `config :trenino, enable_bldc_levers: true` in `config/dev.exs`
- **Resilient train detection with two-layer defense**
  - Primary detection using ObjectClass from CurrentDrivableActor
  - Fallback to ProviderName for trains with mismatched manifests
  - Improved reliability for detecting freight trains and custom train configurations
- **Arduino Nano new bootloader support** (nanoatmega328new)
  - Additional firmware variant for Arduino Nano boards with newer bootloader
  - Automatic device type detection from firmware filenames

### Changed

- REST API expanded with new endpoints for outputs (`/api/outputs`), scripts (`/api/scripts`), and trains (`/api/trains`)
- Script execution integrated with hardware input monitoring and train activation events
- MCP tool registry architecture supports dynamic tool registration and categorization

### Fixed

- Serial connection GenServer crashing when Bluetooth or unresponsive devices cause `:port_timed_out` exits during port open or device discovery, taking down all device tracking ([#46](https://github.com/albertorestifo/trenino/issues/46))
- Firmware flashing via avrdude is now more robust with automatic retry on transient failures
- Flaky CI tests for firmware uploader and upload history ordering
- Train detection failing for freight trains where locomotive and wagons have different class prefixes
- Notch validation incorrectly rejecting negative `sim_input` values (some levers like ThrottleAndBrake use -1.0 to 1.0 range)
- LeverAnalyzer using hardcoded 0.0-1.0 input range instead of reading actual lever range from simulator
- Simulator API requests failing for control paths with special characters (parentheses, spaces)
- Serial discovery settle delay increased to 3 seconds for Arduino Mega compatibility (stock stk500v2 bootloader resets the board via DTR toggle on port open and may take up to 3 seconds before accepting commands)

### Removed

## [0.6.1] - 2026-01-31

### Fixed

- Device type dropdown showing empty when firmware manifest download fails - now properly falls back to hardcoded device list

## [0.6.0] - 2026-01-31

### Added

- **Dynamic device registry from firmware manifests**
  - Device list now loaded from release.json manifest in firmware releases
  - New DeviceRegistry GenServer maintains ETS cache for fast device lookups
  - Firmware releases can include manifest_json field with device definitions
  - Automatic fallback to hardcoded devices if no manifest available
  - Device configurations merge dynamic manifest data with static hardware parameters

### Changed

- **Firmware release management improvements**
  - Firmware releases now support manifest_json field for device metadata
  - FirmwareFile schema adds environment field for PlatformIO environment names
  - Device detection from firmware filenames now uses registry lookup
  - Downloader automatically loads device registry when manifest is present

### Fixed

### Removed

## [0.5.0] - 2026-01-09

### Added

- **LED output bindings** - Bind hardware LEDs to simulator state
  - Create output bindings that control LEDs based on API values
  - Boolean operators: equals, not equals, greater than, less than, and/or combinations
  - LED automatically updates when simulator value changes
- **Editable names for hardware elements**
  - Name field when creating inputs, outputs, and matrices
  - Inline name editing directly in the configuration tables
  - Names are used in train configuration selectors for easier identification
- **Button sequence triggering**
  - New "Trigger Sequence" option in button configuration
  - Configure different sequences for button press (ON) and release (OFF)
  - Works with both momentary and latching button types
- **Button ON/OFF value auto-detection**
  - Automatically captures OFF value (resting state) and ON value (when control changes)
  - "Detect Again" button to re-detect after confirmation
  - Toggle between auto-detect and manual entry modes
- **API explorer for sequence commands**
  - Browse and select endpoints when configuring sequence commands
  - Auto-detection support for discovering InputValue endpoints

### Changed

- **Redesigned device configuration UI**
  - Inputs table now shows Pin, Name, Type, and Value columns
  - Value column combines raw and calibrated readings (e.g., "512/0.5")
  - Removed Settings column for cleaner appearance
  - Consistent table design across inputs, outputs, and matrices
- **Redesigned train elements UI**
  - Compact table layout replaces large card design
  - Separate tables for levers and buttons with status indicators
  - Sequences section with matching table design
- **Improved button configuration wizard**
  - "Trigger Sequence" as top-level option alongside Keystroke and API Call
  - Hardware type selection (Momentary/Latching) shown before mode selection
  - Both ON and OFF sequences are optional (at least one required)
- **Train identifier prefix matching**
  - Train identifiers now act as prefixes - "RVM_LIRREX_M9" matches "RVM_LIRREX_M9-A", "RVM_LIRREX_M9-B", etc.
- **Automatic lever direction detection** during notch mapping
  - No longer requires manual "Invert lever direction" toggle
  - Works for both standard and reversed notch layouts
- **Streamlined lever configuration wizard**
  - Non-linear navigation in edit mode - click any step to jump directly
  - Dependency tracking shows which steps need to be redone after changes
  - Removed unused "Test" step

### Fixed

- Device reconnection failing after cable disconnect/reconnect
- Sequence endpoint selector not preserving ID when confirming detected values
- "Use endpoint" button not working in API explorer for sequences
- Boolean output binding operators causing runtime errors
- Lever auto-detect incorrectly showing for sequence configuration
- New trains not being set as active until app restart

### Removed

- Arduino Nano (Old Bootloader) board option - only new bootloader/clones supported

## [0.4.0] - 2026-01-03

### Added

- **Keystroke simulation mode** for button bindings
  - Map hardware buttons to keyboard keystrokes instead of API endpoints
  - Hold mode: Key is held while button is pressed, released when button is released
  - Support for modifier combinations (Ctrl, Shift, Alt)
  - Interactive key capture UI for intuitive keystroke recording
- **Lever direction inversion** option
  - Toggle in Map Notches step to invert hardware-to-simulator mapping
  - Use when physical lever direction is opposite to simulator expectation
  - Visual indicator reflects inverted position for immediate feedback

### Changed

- Button configuration wizard now includes a type selection step for better workflow

### Fixed

- Train detection now correctly identifies freight trains where locomotive and wagons have different class prefixes (uses drivable actor's ObjectClass)
- API Explorer list not scrolling in lever setup wizard
- Control auto-detection failing due to incorrect API response format
- SQLite "Database busy" errors under heavy load (added performance optimizations)

## [0.3.1]

### Changed

- Unified lever configuration wizard
  - Single 6-step wizard replaces previous 4-modal flow
  - Step 1: Select calibrated hardware lever input
  - Step 2: Find simulator endpoint via API explorer with auto-detect
  - Step 3: Review calibration requirements
  - Step 4: Auto-calibrate using LeverAnalyzer (detects discrete/continuous/hybrid behavior)
  - Step 5: Map notch positions to hardware with visual wobble capture
  - Step 6: Test live position indicator and complete
- New horizontal bar visualization for lever notches
  - Gates displayed as dots, linear notches as segments
  - Small gaps between adjacent notches for visual distinction
  - Live position indicator showing current hardware value
- Simplified lever card UI with single Configure/Edit button

### Fixed

- Lever mapping using incorrect simulator InputValue range
- Lever recalibration failing with "element_id already taken" error
- Momentary button mode not working correctly
- Overlapping modals during configuration wizard

### Removed

- Old NotchMappingWizard component (replaced by unified wizard)
- Separate "Bind Input" and "Map Notches" buttons for levers
- Old input binding modal for levers

## [0.3.0]

### Added

- Button binding modes
  - **Simple mode**: Sends ON value when pressed, OFF value when released (default behavior)
  - **Momentary mode**: Repeats ON value at configurable interval while button is held (for horn, etc.)
  - **Sequence mode**: Executes a series of commands with configurable delays
- Hardware type configuration for buttons
  - **Momentary**: Spring-loaded buttons that return when released
  - **Latching**: Toggle switches that stay in position until pressed again
- Command sequences
  - Create reusable sequences of simulator commands per train
  - Each command specifies endpoint, value, and delay before next command
  - Test button to execute sequences directly from the sequence manager
  - Buttons in sequence mode can trigger different sequences for press and release (latching only)
- Button endpoint auto-detection
  - "Auto-detect" option in button configuration wizard
  - Automatically discovers InputValue endpoints from simulator
  - Monitors for value changes when you interact with controls in-game
  - Suggests ON/OFF values based on detected changes
- Matrix input support
  - New "Matrix" input type with row/column GPIO pin configuration
  - Live grid preview showing dimensions and virtual pin mapping
  - Matrix Test Wizard for verifying button wiring with real-time highlighting and progress tracking
- Lever endpoint auto-detection
  - Automatically detects standard lever endpoints when navigating the API explorer
  - One-click configuration of all lever fields (min, max, value, notch count, notch index)
- API explorer in button configuration modal
- Warning banner when simulator is disconnected on train edit page

### Changed

- Configuration wizard now opens automatically after adding a new element
- Input Type field moved to top of Add Input modal for better workflow
- Inputs and Outputs now displayed in separate sections in device configuration
- Apply to Device button moved to page header for easier access
- Flash messages now display correctly across all pages

### Fixed

- Button getting stuck in "scan" position
- "Map Notches" button showing circular error message
- Device configuration not being associated after leaving config page
- "Mixed key types" error when saving notches
- Matrix pin validation crash when typing in a single field
- List cards not clickable on entire surface
- "Set up" button not responding in element configuration
- Flash messages not visible (clipped by navbar)

## [0.2.0]

### Added

- Output configuration UI for LEDs and indicators
  - Add/delete outputs with pin number (0-255) and optional name
  - Test buttons to toggle outputs on/off when device is connected
  - Outputs are controlled via SetOutput commands (not stored on device)

### Fixed

- Allow pin 0 to be selected when configuring analog and button inputs (pin 0 is a valid Arduino pin)
- Fix firmware upload crash when avrdude is not installed (now shows proper error message)
- Fix firmware upload on Windows for Pro Micro/Leonardo boards (detect bootloader on new COM port after 1200bps touch)
- Fix slow device reconnection after firmware upload (was waiting 30s backoff, now reconnects immediately)
- Fix config_id being regenerated when applying saved configuration (now preserves the existing config_id)
- Fix slow page transitions when simulator is disconnected (connection retries are now async)
