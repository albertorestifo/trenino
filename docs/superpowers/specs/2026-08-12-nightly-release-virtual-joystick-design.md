# Nightly and Release Virtual Joystick Packaging

## Goal

Ensure both nightly and release workflows build and stage every Tauri sidecar required by their Windows and Linux configurations, including `virtual_joystick`.

## Design

Add a `build-virtual-joystick` matrix job to both workflows. It mirrors the existing `build-keystroke` job across `windows_x86_64` and `linux_x86_64`, builds `tauri/virtual_joystick`, and uploads a target-specific artifact with the platform's native executable suffix.

Each `build-tauri` job will depend on this new job, download its artifact, rename it to Tauri's target-triple sidecar filename, set Unix execute permissions, and remove its staging directory alongside the existing keystroke and avrdude staging directories.

The Windows Tauri override also packages the vJoy installer, configuration utility, interface DLL, and license. Both workflows will call a shared PowerShell staging script that downloads the pinned vJoy 2.2.2.0 inputs, verifies all three SHA-256 hashes and the installer signer, then extracts the two required runtime files with pinned `innoextract` 1.9 and the runner's 7-Zip. This keeps nightly, release, and regular CI aligned without installing the driver.

Nightly and release retain their existing triggers, matrices, signing/release behavior, caches, and artifacts. No driver installation occurs in CI.

## Verification

A static ExUnit regression test will require both workflows to contain the build job, dependency edge, artifact download, platform-specific staging names, and verified vJoy resource staging. Workflow validators, strict Credo, the full suite, and a manually dispatched nightly run will provide syntax, repository, and hosted-runner verification. The release workflow will not be dispatched because doing so would publish a release; its equivalent graph will be statically validated.
