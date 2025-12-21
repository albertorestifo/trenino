# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Matrix input configuration UI
  - New "Matrix" input type option in add input modal
  - Configure row and column GPIO pins using comma-separated values
  - Live grid preview showing matrix dimensions and virtual pin mapping
  - Validation for pin range (0-127), duplicates, and overlap between rows/columns
- Matrix button test wizard
  - Visual grid showing all matrix button positions
  - Real-time button highlighting when pressed (purple)
  - Persistent green state with checkmark for tested buttons (pressed at least once)
  - Progress bar showing tested button count and percentage
  - Reset button to clear tested state
  - Allows verifying matrix wiring by testing all button connections

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
