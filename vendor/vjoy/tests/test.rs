#[cfg(test)]

mod tests {
    // The process by which devices are acquired from the C API is not compatible with Rust's test harness and only works within the same test.
    // The tests can be monitored via the vJoyMonitor and vJoyList executables bundled with vJoy.
    use vjoy::{ButtonState, FourWayHat, HatState, VJoy};

    #[test]
    fn test() {
        let mut vjoy = VJoy::from_default_dll_location().unwrap();
        let mut device_1 = vjoy.get_device_state(1).unwrap();

        let (hat_set, hat_reset) = match device_1.hat_type() {
            HatState::Discrete(_) => (
                HatState::Discrete(FourWayHat::East),
                HatState::Discrete(FourWayHat::Centered),
            ),
            HatState::Continuous(_) => (
                HatState::Continuous(90 * 100),
                HatState::Continuous(u32::MAX),
            ),
        };

        // Simple test for 1 device
        println!("Setting button 1 of device 1");
        device_1.set_button(1, ButtonState::Pressed).unwrap();
        vjoy.update_device_state(&device_1).unwrap();
        std::thread::sleep(std::time::Duration::from_millis(100));

        println!("Resetting button 1 of device 1");
        device_1.set_button(1, ButtonState::Released).unwrap();
        vjoy.update_device_state(&device_1).unwrap();
        std::thread::sleep(std::time::Duration::from_millis(100));

        println!("Setting hat 1 of device 1");
        device_1.set_hat(1, hat_set).unwrap();
        vjoy.update_device_state(&device_1).unwrap();
        std::thread::sleep(std::time::Duration::from_millis(100));

        println!("Resetting hat 1 of device 1");
        device_1.set_hat(1, hat_reset).unwrap();
        vjoy.update_device_state(&device_1).unwrap();
        std::thread::sleep(std::time::Duration::from_millis(100));

        println!("Setting axis 1 of device 1 to i32::MAX");
        device_1.set_axis(1, i32::MAX).unwrap();
        vjoy.update_device_state(&device_1).unwrap();
        std::thread::sleep(std::time::Duration::from_millis(100));

        println!("Setting axis 1 of device 1 to i32::MIN");
        device_1.set_axis(1, i32::MIN).unwrap();
        vjoy.update_device_state(&device_1).unwrap();
        std::thread::sleep(std::time::Duration::from_millis(100));
        // Simple test for 1 device

        // Simple test for 1 ref mut device
        println!("Setting button 1 of device 1");
        let device_1_mut = vjoy.get_device_state_mut(1).unwrap();
        device_1_mut.set_button(1, ButtonState::Pressed).unwrap();

        println!("Resetting button 1 of device 1");
        device_1_mut.set_button(1, ButtonState::Released).unwrap();

        println!("Setting hat 1 of device 1");
        device_1_mut.set_hat(1, hat_set).unwrap();
        vjoy.update_all_devices().unwrap();
        std::thread::sleep(std::time::Duration::from_millis(100));

        let device_1_mut = vjoy.get_device_state_mut(1).unwrap();
        println!("Resetting hat 1 of device 1");
        device_1_mut.set_hat(1, hat_reset).unwrap();

        println!("Setting axis 1 of device 1 to i32::MAX");
        device_1_mut.set_axis(1, i32::MAX).unwrap();

        println!("Setting axis 1 of device 1 to i32::MIN");
        device_1_mut.set_axis(1, i32::MIN).unwrap();
        vjoy.update_all_devices().unwrap();
        // Simple test for 1 ref mut device

        // Test all buttons/axes/hats for 1 device
        println!("Setting all buttons for device 1");
        for button in device_1.buttons_mut() {
            button.set(ButtonState::Pressed);
        }
        println!("Setting all hats for device 1");
        for hat in device_1.hats_mut() {
            hat.set(hat_set);
        }
        println!("Setting all axes to MAX");
        for axis in device_1.axes_mut() {
            axis.set(i32::MAX);
        }
        std::thread::sleep(std::time::Duration::from_millis(100));
        vjoy.update_device_state(&device_1).unwrap();

        println!("Resetting all buttons");
        for button in device_1.buttons_mut() {
            button.set(ButtonState::Released);
        }
        println!("Resetting all hats for device 1");
        for hat in device_1.hats_mut() {
            hat.set(hat_reset);
        }
        println!("Setting all axes to MIN");
        for axis in device_1.axes_mut() {
            axis.set(i32::MIN);
        }
        std::thread::sleep(std::time::Duration::from_millis(100));
        vjoy.update_device_state(&device_1).unwrap();
        // Test all buttons/axes/hats for 1 device

        // Test all buttons/axes/hats for all devices
        println!("Test all buttons/axes for all devices");
        for device in &mut vjoy.devices_cloned() {
            for button in device.buttons_mut() {
                button.set(ButtonState::Pressed);
            }
            for hat in device_1.hats_mut() {
                hat.set(hat_set);
            }
            for axis in device.axes_mut() {
                axis.set(i32::MAX);
            }
            std::thread::sleep(std::time::Duration::from_millis(100));
            vjoy.update_device_state(&device).unwrap();

            for button in device.buttons_mut() {
                button.set(ButtonState::Released);
            }
            for hat in device_1.hats_mut() {
                hat.set(hat_reset);
            }
            for axis in device.axes_mut() {
                axis.set(i32::MIN);
            }
            std::thread::sleep(std::time::Duration::from_millis(100));
            vjoy.update_device_state(&device).unwrap();
        }
        // Test all buttons/axes/hats for all devices

        // Rapid test all buttons/axes/hats for all devices
        println!("Rapid test all buttons/axes for all devices");
        for _ in 0..1000 {
            for device in &mut vjoy.devices_cloned() {
                for button in device.buttons_mut() {
                    button.set(ButtonState::Pressed);
                }
                for hat in device_1.hats_mut() {
                    hat.set(hat_set);
                }
                for axis in device.axes_mut() {
                    axis.set(i32::MAX);
                }
                vjoy.update_device_state(&device).unwrap();

                for button in device.buttons_mut() {
                    button.set(ButtonState::Released);
                }
                for hat in device_1.hats_mut() {
                    hat.set(hat_reset);
                }
                for axis in device.axes_mut() {
                    axis.set(i32::MIN);
                }
                vjoy.update_device_state(&device).unwrap();
            }
        }
        // Rapid test all buttons/axes/hats for all devices
    }
}
