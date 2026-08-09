# Standardized Burrito Runner Prerequisites

## Goal

Make every GitHub Actions job that builds a Burrito release install and verify the same pinned runner prerequisites before packaging begins.

## Current Problem

The Windows package job in `.github/workflows/ci.yml` builds the application successfully until Burrito's preflight check, then fails because `zig` and `xz` are not both available on `PATH`. The nightly and release workflows already install Zig independently, but none of the three workflows owns a complete, shared prerequisite contract. This duplication allowed CI to drift.

## Design

Create a repository-local composite action at `.github/actions/setup-burrito/action.yml`. It will be the single entry point for Burrito runner setup in CI, nightly, and release workflows.

The action will:

- install the repository's pinned Zig version, `0.15.2`, through `mlugg/setup-zig@v2`;
- install `xz` explicitly when running on Windows;
- verify that `zig` and `xz` both resolve from `PATH` and can execute;
- fail before dependency compilation or release assembly with a direct diagnostic if either prerequisite is unavailable.

Linux behavior remains minimal: the shared action installs Zig and verifies the runner-provided `xz`. The existing Linux-specific Burrito workaround remains in the calling workflows.

Each Burrito-producing job will invoke the local action after checkout and language setup but before dependency resolution and `mix release` or `scripts/build-desktop.sh`. Existing build matrices, secrets, caching, artifact handling, Tauri packaging, and vJoy validation remain unchanged.

## Drift Prevention

Add a lightweight repository test that parses the three workflow files as text and asserts that every supported Burrito workflow calls `./.github/actions/setup-burrito`. The same test will assert that obsolete standalone `mlugg/setup-zig` steps are absent from those workflow files, ensuring the pinned version stays owned by the composite action.

The test is intentionally static: it verifies repository wiring quickly on any development platform. The real Windows GitHub Actions job remains the end-to-end proof that Chocolatey installation, `PATH` propagation, Burrito packaging, Tauri packaging, and artifact inspection work together.

## Error Handling

Installation failures stop the job immediately. Verification prints the resolved Zig and xz versions, giving logs enough information to distinguish package installation, `PATH`, and version problems. No fallback download or silent continuation is allowed.

## Verification

Implementation is complete when:

1. The new static workflow test fails before the workflow migration and passes afterward.
2. Existing local tests and workflow syntax validation pass.
3. CI, nightly, and release each reference the shared action for Burrito setup.
4. A GitHub-hosted Windows CI run completes the Burrito and Tauri packaging job, including packaged-resource inspection and artifact upload.
5. No open pull requests remain.

## Scope

This change standardizes only Burrito tool prerequisites. It does not refactor build scripts, alter release targets, change dependency versions, or install the vJoy driver on hosted runners.
