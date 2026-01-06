# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

### Changed

- **Automatic lever direction detection** during notch mapping
  - System now auto-detects if hardware lever direction is opposite to simulator expectation
  - No longer requires manual "Invert lever direction" toggle in the Map Notches step
  - Works correctly for both standard layouts (low→low, high→high) and reversed layouts (M9-A style where Emergency is at high input)
- **Streamlined lever configuration wizard**
  - Removed unused "Test" step - wizard closes after saving notch mappings
  - Removed confusing live position indicator from notch mapping visualization (numerical values are still shown)

### Fixed

- New trains not being set as active until app restart
- Notches with sim_input_min=0 failing to match due to integer/float type mismatch from SQLite
- Lever inversion not working correctly for reversed notch layouts (now auto-detected)

### Removed

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
