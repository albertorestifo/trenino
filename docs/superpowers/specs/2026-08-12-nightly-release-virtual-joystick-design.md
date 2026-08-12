# Nightly and Release Virtual Joystick Packaging

## Goal

Ensure both nightly and release workflows build and stage every Tauri sidecar required by their Windows and Linux configurations, including `virtual_joystick`.

## Design

Add a `build-virtual-joystick` matrix job to both workflows. It mirrors the existing `build-keystroke` job across `windows_x86_64` and `linux_x86_64`, builds `tauri/virtual_joystick`, and uploads a target-specific artifact with the platform's native executable suffix.

Each `build-tauri` job will depend on this new job, download its artifact, rename it to Tauri's target-triple sidecar filename, set Unix execute permissions, and remove its staging directory alongside the existing keystroke and avrdude staging directories.

Nightly and release retain their existing triggers, matrices, signing/release behavior, caches, and artifacts. No driver installation occurs in CI.

## Verification

A static ExUnit regression test will require both workflows to contain the build job, dependency edge, artifact download, and platform-specific staging names. Workflow validators, strict Credo, the full suite, and a manually dispatched nightly run will provide syntax, repository, and hosted-runner verification. The release workflow will not be dispatched because doing so would publish a release; its equivalent graph will be statically validated.
