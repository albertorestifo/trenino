use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ButtonMode {
    Simple,
    Momentary,
    Sequence,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum HardwareType {
    Momentary,
    Latching,
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SequenceCommand {
    pub endpoint: String,
    pub value: f64,
    #[serde(default)]
    pub delay_ms: u64,
    #[serde(default)]
    pub position: u32,
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ButtonBinding {
    pub element_id: i64,
    pub endpoint: Option<String>,
    pub on_value: f64,
    pub off_value: f64,
    pub mode: ButtonMode,
    pub hardware_type: HardwareType,
    #[serde(default)]
    pub on_sequence: Vec<SequenceCommand>,
    #[serde(default)]
    pub off_sequence: Vec<SequenceCommand>,
}
#[derive(Clone, Debug, Default, PartialEq)]
pub struct ButtonState {
    pub active: bool,
    pub last_sent_value: Option<f64>,
}
#[derive(Clone, Debug, PartialEq)]
pub enum ButtonAction {
    Set {
        endpoint: String,
        value: f64,
    },
    SetInteracting {
        endpoint: String,
        value: bool,
    },
    StartMomentaryRepeat {
        element_id: i64,
    },
    StartSequence {
        element_id: i64,
        commands: Vec<SequenceCommand>,
    },
    CancelActive {
        element_id: i64,
    },
}

pub fn transition(
    binding: &ButtonBinding,
    state: ButtonState,
    pressed: bool,
) -> (ButtonState, Vec<ButtonAction>) {
    if pressed {
        return press(binding, state);
    }
    release(binding, state)
}

fn press(binding: &ButtonBinding, mut state: ButtonState) -> (ButtonState, Vec<ButtonAction>) {
    let mut actions = Vec::new();
    match binding.mode {
        ButtonMode::Simple => {
            if state.last_sent_value != Some(binding.on_value) {
                if let Some(endpoint) = &binding.endpoint {
                    actions.push(ButtonAction::Set {
                        endpoint: endpoint.clone(),
                        value: binding.on_value,
                    });
                }
                state.last_sent_value = Some(binding.on_value);
            }
        }
        ButtonMode::Momentary => {
            if let Some(endpoint) = &binding.endpoint {
                actions.push(ButtonAction::SetInteracting {
                    endpoint: interacting_endpoint(endpoint),
                    value: true,
                });
                actions.push(ButtonAction::Set {
                    endpoint: endpoint.clone(),
                    value: binding.on_value,
                });
                actions.push(ButtonAction::StartMomentaryRepeat {
                    element_id: binding.element_id,
                });
                state.last_sent_value = Some(binding.on_value);
                state.active = true;
            }
        }
        ButtonMode::Sequence => {
            if !binding.on_sequence.is_empty() {
                actions.push(ButtonAction::StartSequence {
                    element_id: binding.element_id,
                    commands: ordered_sequence(&binding.on_sequence),
                });
                state.last_sent_value = Some(binding.on_value);
                state.active = true;
            }
        }
    }
    (state, actions)
}

fn release(binding: &ButtonBinding, mut state: ButtonState) -> (ButtonState, Vec<ButtonAction>) {
    let mut actions = Vec::new();
    match binding.mode {
        ButtonMode::Simple => {
            if state.last_sent_value != Some(binding.off_value) {
                if let Some(endpoint) = &binding.endpoint {
                    actions.push(ButtonAction::Set {
                        endpoint: endpoint.clone(),
                        value: binding.off_value,
                    });
                }
                state.last_sent_value = Some(binding.off_value);
            }
        }
        ButtonMode::Momentary => {
            if state.active {
                actions.push(ButtonAction::CancelActive {
                    element_id: binding.element_id,
                });
            }
            if let Some(endpoint) = &binding.endpoint {
                actions.push(ButtonAction::Set {
                    endpoint: endpoint.clone(),
                    value: binding.off_value,
                });
                actions.push(ButtonAction::SetInteracting {
                    endpoint: interacting_endpoint(endpoint),
                    value: false,
                });
                state.last_sent_value = Some(binding.off_value);
            }
            state.active = false;
        }
        ButtonMode::Sequence => {
            if state.active && binding.hardware_type == HardwareType::Momentary {
                actions.push(ButtonAction::CancelActive {
                    element_id: binding.element_id,
                });
                state.active = false;
            } else if binding.hardware_type == HardwareType::Latching
                && !binding.off_sequence.is_empty()
            {
                actions.push(ButtonAction::StartSequence {
                    element_id: binding.element_id,
                    commands: ordered_sequence(&binding.off_sequence),
                });
                state.active = true;
            }
            state.last_sent_value = Some(binding.off_value);
        }
    }
    (state, actions)
}

fn interacting_endpoint(endpoint: &str) -> String {
    if let Some(prefix) = endpoint.strip_suffix(".InputValue") {
        return format!("{prefix}.Interacting");
    }
    if let Some((prefix, _)) = endpoint.rsplit_once('.') {
        return format!("{prefix}.Interacting");
    }
    format!("{endpoint}.Interacting")
}

pub fn ordered_commands(mut commands: Vec<SequenceCommand>) -> Vec<String> {
    commands.sort_by_key(|command| command.position);
    commands
        .into_iter()
        .map(|command| command.endpoint)
        .collect()
}
pub fn ordered_sequence(commands: &[SequenceCommand]) -> Vec<SequenceCommand> {
    let mut ordered = commands.to_vec();
    ordered.sort_by_key(|command| command.position);
    ordered
}
#[derive(Clone, Debug, PartialEq)]
pub enum SequenceStep {
    Send(SequenceCommand),
    Wait(u64),
}

/// Return the same ordered effects as ButtonController: send each command, then delay before the next.
pub fn sequence_steps(commands: &[SequenceCommand]) -> Vec<SequenceStep> {
    let mut ordered = ordered_sequence(commands);
    let mut steps = Vec::with_capacity(ordered.len() * 2);
    for command in ordered.drain(..) {
        let delay = command.delay_ms;
        steps.push(SequenceStep::Send(command));
        if delay > 0 {
            steps.push(SequenceStep::Wait(delay));
        }
    }
    steps
}
