## [0.7.1] Rustdoc patch
- Changed: Updated vJoy driver links in README

## [0.7.0] Update to vJoy 2.2.2.0
- Changed: Updated to vjoy-sys version 0.5.2 built against vJoy version 2.2.2.0

## [0.6.0] Windows 11 compatibility
- Changed: For compatibility reasons, the underlying vJoy version had to be changed. On Windows 11, only version [2.1.9.1](https://sourceforge.net/projects/vjoystick/files/Beta%202.x/2.1.9.1-160719/) is supported.
- Changed: This version only supports up to 8 axes per device.

## [0.5.0] Utility and struct derives
- Added: Missing (mutable) iterators to device states alongside the existing _cloned() function.
- Added: update_all_devices to VJoy to update all previously set device states.
- Added: Missing num_X functions for buttons, axes and hats to Device.
- Added: Missing Display impl for Hat & HatState.
- Added: [C-COMMON-TRAITS](https://rust-lang.github.io/api-guidelines/interoperability.html#types-eagerly-implement-common-traits-c-common-traits) derives to public structs.
- Removed: Unused Rayon dependency.

## [0.4.0] Profiling & performance update
- Added: Support for profile tracing via the [profiling](https://crates.io/crates/profiling) crate.
- Changed: Calls to update_device_state now update the driver's device state in one step via a JOYSTICK_POSITION pointer. ~40 times faster than setting each button/axis/hat individually.

## [0.3.1] Config search patch
- Added: vJoy devices can be searched by their configuration (num_buttons, num_axes, num_hats).

## [0.3.0] Updated vJoy version
- Added: Support for up to 4 continuous hat switches in the range of 0..360° with a 1/100° resolution.
- Changed: Max number of axis increased to 16
- Changed: Supported vJoy driver version updated to 2.2.2.1 from: https://github.com/njz3/vJoy/

## [0.2.0] Hat switch support
- Added: Support for up to four 4-way hat switches (e.g. a D-pad).

## [0.1.0] Initial release