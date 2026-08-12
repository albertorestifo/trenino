# Nightly and Release Virtual Joystick Packaging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and stage the virtual joystick sidecar in nightly and release Tauri packages.

**Architecture:** Both workflows gain matching target-matrix build jobs and pass target-specific artifacts into their existing Tauri matrix jobs. A static ExUnit contract prevents the two workflows from drifting.

**Tech Stack:** GitHub Actions, Rust/Cargo, Elixir/ExUnit.

## Global Constraints

- Support `windows_x86_64` and `linux_x86_64`.
- Preserve all existing workflow triggers, release publishing, matrices, caches, artifacts, and driver safety behavior.
- Do not install or mutate the vJoy driver on hosted runners.

---

### Task 1: Add RED workflow contract

**Files:**
- Create: `test/ci/virtual_joystick_workflow_test.exs`

- [ ] Assert nightly and release each define `build-virtual-joystick`, include it in `build-tauri.needs`, download `virtual-joystick-${{ matrix.target }}`, and stage `virtual_joystick-${{ matrix.tauri_target }}` with `.exe` only on Windows.
- [ ] Run the focused test and confirm it fails because the workflow wiring is absent.
- [ ] Commit as `test: require virtual joystick workflow artifacts`.

### Task 2: Implement matching workflow jobs

**Files:**
- Modify: `.github/workflows/nightly.yml`
- Modify: `.github/workflows/release.yml`

- [ ] Add matching virtual-joystick build matrices modeled on `build-keystroke`.
- [ ] Add dependency, download, staging, permissions, and cleanup wiring to both Tauri jobs.
- [ ] Run the focused test green.
- [ ] Run action-validator/actionlint, strict Credo, full tests, formatting, and diff checks.
- [ ] Commit as `ci: package virtual joystick in nightly releases`.

### Task 3: Hosted verification

- [ ] Push `master` without force.
- [ ] Manually dispatch Nightly Build and monitor every matrix job through installer upload.
- [ ] Confirm the release workflow validates without dispatching/publishing a release.
