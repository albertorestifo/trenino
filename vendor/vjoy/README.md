[<img alt="Crates.io" src="https://img.shields.io/crates/v/vjoy">](https://crates.io/crates/vjoy)
[<img alt="docs.rs" src="https://img.shields.io/docsrs/vjoy">](https://docs.rs/vjoy/latest/vjoy/)
<img alt="Crates.io" src="https://img.shields.io/crates/l/vjoy">

Safe and idiomatic wrapper for for [vjoy-sys](https://crates.io/crates/vjoy-sys).

## About vJoy
vJoy simulates up to 16 input devices with up to 128 buttons, 8 axes, and 4 hat switches (4-way or continuous).
The virtual devices can be used to 
1) Emulate gamepads/joysticks for older games that require a specific kind of input.
2) Combine multiple physical devices into one virtual.
3) Apply transformations from a physical device to a virtual device (e.g. 2-button to axis rebind, software filtering etc.).

The virtual devices appear to applications as regular input devices.

## Usage
The [vJoy driver](https://github.com/BrunnerInnovation/vJoy/releases/tag/v2.2.2.0) version 2.2.2.0 needs to be installed and is only available for Windows.

The vJoy shared library is loaded at runtime via libloading. See the integration tests for specifics.

## Example
```rust
use vjoy::{VJoy, ButtonState, Error, HatState, FourWayHat};

fn main() -> Result<(), Error>{
    let mut vjoy = VJoy::from_default_dll_location()?;
    let device_1 = vjoy.get_device_state_mut(1)?;

    device_1.set_button(1, ButtonState::Pressed)?;
    device_1.set_axis(1, i32::MAX)?;

    let hat_type = device_1.hat_type();
    let value = match hat_type{
        HatState::Discrete(_) => HatState::Discrete(FourWayHat::East),
        HatState::Continuous(_) => HatState::Continuous(90 * 100),
    };
    device_1.set_hat(1, value)?;

    vjoy.update_all_devices()?;

    Ok(())
}
```