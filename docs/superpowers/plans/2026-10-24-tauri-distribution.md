# Standard Tauri distribution implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Track steps with checkboxes.

**Goal:** Replace custom Store packaging with official Tauri stable-release updates.
**Architecture:** A stable-only Cargo feature enables native updater/menu/dialog code. GitHub Actions signs updater artifacts and generates latest.json through tauri-action. Nightlies and ordinary development builds remain unsigned and do not enable the updater.
**Tech Stack:** Rust, Tauri 2 updater/dialog plugins, GitHub Actions, existing Elixir backend.
**Spec:** docs/superpowers/specs/2026-10-24-tauri-distribution-design.md

## Global constraints
- No purchases, Authenticode claims, Store changes, merge, or release publication.
- Preserve vJoyInstall.dll packaging fixes.
- Never print or commit private signing material.

## Review focus
- Cancellation must not stop the backend or install anything.
- Download/signature failures must leave the backend running.
- Shutdown failures must prevent installation.
- Nightlies must not advertise stable update capability.
- Failed installation after shutdown needs actionable restart guidance.

## Task 1: Remove MSIX and configure release signing
- [ ] Remove MSIX scripts, Store feature/tests and workflow steps; preserve dependency fixes.
- [ ] Generate protected updater key outside repo, configure Actions secret, commit public key.
- [ ] Configure release-only updater artifacts, stable feature and latest.json generation; delete unused Store repository variables.
- [ ] Verify configuration and key round-trip signatures without publishing a release.

## Task 2: Native updater and lifecycle
- [ ] Write failing pure Rust lifecycle tests for cancellation, download failure, shutdown failure, successful ordering, install failure.
- [ ] Implement lifecycle using official updater download and install, native confirmation and serialized operations.
- [ ] Add a native check menu; stable-only feature disables duplicate backend app notifications.
- [ ] Require verified graceful backend exit before installation; never force-kill for an update.
- [ ] Compile/test actual Rust integration and run existing focused tests.

## Task 3: Review and GitHub handoff
- [ ] Update distribution docs, run CI checks and fresh code review.
- [ ] Update existing draft PR, push changes and inspect CI; do not merge/publish.
- [ ] Report any unverified real Windows upgrade test explicitly.
