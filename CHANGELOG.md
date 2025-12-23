# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
  - Buttons in sequence mode can trigger different sequences for press and release (latching only)
  - Sequence manager UI in train edit page for creating and editing sequences
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
- Debug logging for configuration commands sent to device

### Fixed

- Button getting stuck in "scan" position
- "Map Notches" button showing circular error message
- Device configuration not being associated after leaving config page
- "Mixed key types" error when saving notches
- Matrix pin validation crash when typing in a single field
- Improved error messages for matrix input constraints

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
