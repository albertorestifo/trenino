//! Shared desktop control ingress: port-scoped resource fences do not block other ports.
use crate::{
    resource::ResourceArbiter,
    routing::InputEvent,
    train::{
        button_controller::{ButtonController, ButtonSample},
        lever_controller::{LeverController, LeverSample},
    },
};
use std::{collections::HashSet, sync::Mutex};

pub fn port_is_fenced(
    port: &str,
    suspended: &Mutex<HashSet<String>>,
    arbiter: Option<&ResourceArbiter>,
) -> Result<bool, String> {
    Ok(suspended
        .lock()
        .map_err(|_| "input admission poisoned")?
        .contains(port)
        || arbiter.is_some_and(|a| a.port_is_leased(port) || a.port_neutralization_failed(port)))
}
pub fn dispatch_control_input(
    lever: &LeverController,
    buttons: &ButtonController,
    port: &str,
    event: InputEvent,
    cache_only: bool,
) -> Result<(), String> {
    let lever_sample = LeverSample {
        port: port.into(),
        port_generation: event.port_generation,
        config_id: event.config_id,
        pin: event.pin,
        value: event.value,
    };
    let button_sample = ButtonSample {
        port: port.into(),
        port_generation: event.port_generation,
        config_id: event.config_id,
        pin: event.pin,
        value: event.value,
    };
    let lever_result = if cache_only {
        lever.try_observe(lever_sample)
    } else {
        lever.try_input(lever_sample)
    }
    .map_err(|e| format!("lever queue: {e:?}"));
    let button_result = if cache_only {
        buttons.try_observe(button_sample)
    } else {
        buttons.try_input(button_sample)
    }
    .map_err(|e| format!("button queue: {e:?}"));
    match (lever_result, button_result) {
        (Err(a), Err(b)) => Err(format!("{a}; {b}")),
        (Err(error), _) | (_, Err(error)) => Err(error),
        _ => Ok(()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::resource::ResourceConsumers;
    use std::sync::Arc;
    struct FailedSource;
    impl ResourceConsumers for FailedSource {
        fn suspend_actuation(&self, _: &str) -> Result<(), String> {
            Ok(())
        }
        fn cancel_calibration(&self, _: &str) -> Result<(), String> {
            Ok(())
        }
        fn source_lost(&self, _: &str, _: u64) -> Result<(), String> {
            Err("neutralization failed".into())
        }
        fn resume_after_fresh_sample(&self, _: &str) -> Result<(), String> {
            Ok(())
        }
    }
    #[test]
    fn source_failure_and_shared_fences_are_port_scoped() {
        let arbiter = ResourceArbiter::new(Arc::new(FailedSource));
        let suspended = Mutex::new(HashSet::new());
        assert!(arbiter.neutralize_source("COM1", 1).is_err());
        assert!(arbiter.is_suspended());
        assert!(port_is_fenced("COM1", &suspended, Some(&arbiter)).unwrap());
        assert!(!port_is_fenced("COM2", &suspended, Some(&arbiter)).unwrap());
        suspended.lock().unwrap().insert("COM3".into());
        assert!(port_is_fenced("COM3", &suspended, None).unwrap());
        assert!(!port_is_fenced("COM2", &suspended, None).unwrap());
    }
}
