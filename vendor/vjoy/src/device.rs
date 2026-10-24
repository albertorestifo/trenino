use crate::FourWayHat;
use crate::axis::Axis;
use crate::button::{Button, ButtonState};
use crate::error::{AppError, Error};
use crate::hat::{Hat, HatState};
use std::fmt::Display;
use std::slice::Iter;
use std::slice::IterMut;

#[derive(Debug, Clone, Default)]
/// Current state of an enabled vJoy device.
///
/// Range of IDs is 1..=16 for consistency with the .dll.
///
/// A device can be configured by the driver (vJoy install dir --> vJoyConf.exe).
///
/// The [buttons](Self::buttons) and [axes](Self::axes) iterators always correspond to the enabled buttons/axes for this device.
///
/// You can set buttons and axes directly via IDs, but the corresponding button/axis may not be enabled by the driver.
///
/// ## Examples
///
/// **To enable button 3 for device 6**:
///
/// ```no_run
/// # use vjoy::{VJoy, ButtonState, Error};
/// # let mut vjoy = VJoy::from_default_dll_location()?;
/// let mut device_6 = vjoy.get_device_state(6)?;
/// device_6.set_button(3, ButtonState::Pressed)?;
/// vjoy.update_device_state(&device_6)?;
/// # Ok::<(), Error>(())
/// ```
///
/// **To set all buttons for device 2**:
///
/// ```no_run
/// # use vjoy::{VJoy, ButtonState, Error};
/// # let mut vjoy = VJoy::from_default_dll_location()?;
/// let mut device_2 = vjoy.get_device_state(2)?;
/// for button in device_2.buttons_mut() {
///     button.set(ButtonState::Pressed);
/// }   
/// vjoy.update_device_state(&device_2)?;
/// # Ok::<(), Error>(())
/// ```
///  
/// **To reset all axes and all buttons for device 1**:
///
/// ```no_run
/// # use vjoy::{VJoy, ButtonState, Error};
/// # let mut vjoy = VJoy::from_default_dll_location()?;
/// let mut device_1 = vjoy.get_device_state(1)?;
/// device_1.reset_all();   
/// vjoy.update_device_state(&device_1)?;
/// # Ok::<(), Error>(())
/// ```
pub struct Device {
    pub(crate) id: u32,
    pub(crate) buttons: Vec<Button>,
    pub(crate) axes: Vec<Axis>,
    pub(crate) hats: Vec<Hat>,
}

impl Device {
    #[profiling::function]
    pub fn id(&self) -> u32 {
        self.id
    }

    #[profiling::function]
    pub fn buttons_mut(&mut self) -> IterMut<'_, Button> {
        self.buttons.iter_mut()
    }

    #[profiling::function]
    pub fn buttons(&self) -> Iter<'_, Button> {
        self.buttons.iter()
    }

    #[profiling::function]
    pub fn num_buttons(&self) -> usize {
        self.buttons.len()
    }

    #[profiling::function]
    pub fn axes_mut(&mut self) -> IterMut<'_, Axis> {
        self.axes.iter_mut()
    }

    #[profiling::function]
    pub fn axes(&self) -> Iter<'_, Axis> {
        self.axes.iter()
    }

    #[profiling::function]
    pub fn num_axes(&self) -> usize {
        self.axes.len()
    }

    #[profiling::function]
    pub fn hats_mut(&mut self) -> IterMut<'_, Hat> {
        self.hats.iter_mut()
    }

    #[profiling::function]
    pub fn hats(&self) -> Iter<'_, Hat> {
        self.hats.iter()
    }

    #[profiling::function]
    pub fn num_hats(&self) -> usize {
        self.hats.len()
    }

    #[profiling::function]
    pub fn hat_type(&self) -> HatState {
        let Some(hat) = self.hats.first() else {
            return HatState::Discrete(FourWayHat::Centered);
        };

        hat.state
    }

    #[profiling::function]
    pub fn set_button(&mut self, button_id: u8, state: ButtonState) -> Result<(), Error> {
        if button_id == 0 {
            return Err(Error::App(AppError::ButtonNotFound(self.id, button_id)));
        }

        let button = match self.buttons.get_mut((button_id - 1) as usize) {
            Some(button) => button,
            None => return Err(Error::App(AppError::ButtonNotFound(self.id, button_id))),
        };

        button.set(state);

        Ok(())
    }

    #[profiling::function]
    pub fn set_hat(&mut self, hat_id: u8, state: HatState) -> Result<(), Error> {
        if hat_id == 0 {
            return Err(Error::App(AppError::HatNotFound(self.id, hat_id)));
        }

        let hat = match self.hats.get_mut((hat_id - 1) as usize) {
            Some(hat) => hat,
            None => return Err(Error::App(AppError::HatNotFound(self.id, hat_id))),
        };

        hat.set(state);

        Ok(())
    }

    #[profiling::function]
    pub fn set_axis(&mut self, axis_id: u32, value: i32) -> Result<(), Error> {
        if axis_id == 0 {
            return Err(Error::App(AppError::AxisNotFound(self.id, axis_id)));
        }

        let axis = match self.axes.get_mut((axis_id - 1) as usize) {
            Some(axis) => axis,
            None => return Err(Error::App(AppError::AxisNotFound(self.id, axis_id))),
        };

        axis.set(value);

        Ok(())
    }

    #[profiling::function]
    pub fn reset_all(&mut self) -> Result<(), Error> {
        for button in &mut self.buttons {
            button.reset();
        }
        for axis in &mut self.axes {
            axis.reset();
        }
        for hat in &mut self.hats {
            hat.reset();
        }

        Ok(())
    }
}

impl Display for Device {
    #[profiling::function]
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_fmt(format_args!(
            "Device ID: {} | button count: {} | axes count: {} | hat count: {} | hat type: {:?}",
            self.id,
            self.buttons.len(),
            self.axes.len(),
            self.hats.len(),
            self.hat_type(),
        ))
    }
}
