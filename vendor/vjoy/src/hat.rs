use std::fmt::Display;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Default)]
#[repr(i32)]
pub enum FourWayHat {
    #[default]
    Centered = -1,
    North = 0,
    East = 1,
    South = 2,
    West = 3,
}

/// Common state for either a 4-way hat or a continuous 360° hat switch
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum HatState {
    Discrete(FourWayHat),
    Continuous(u32),
}

impl Display for HatState {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            HatState::Discrete(v) => f.write_str(&format!("Hat state discrete: {v:?}")),
            HatState::Continuous(v) => f.write_str(&format!("Hat state continuous: {v:?}")),
        }
    }
}

impl Default for HatState {
    fn default() -> Self {
        Self::Discrete(FourWayHat::default())
    }
}

impl HatState {
    #[profiling::function]
    fn reset(&mut self) {
        *self = match self {
            HatState::Discrete(_) => HatState::Discrete(FourWayHat::Centered),
            HatState::Continuous(_) => HatState::Continuous(u32::MAX),
        };
    }
}

/// Current state of an enabled device hat switch.
///
/// A vJoy hat switch is either a 4-way discrete switch or a continuous switch. Continuous switches feature a range of 360° with a 1/100° resolution.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct Hat {
    pub(crate) id: u8,
    pub(crate) state: HatState,
}

impl Display for Hat {
    #[profiling::function]
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_fmt(format_args!("Hat ID: {} | state: {}", self.id, self.state))
    }
}

impl Hat {
    #[profiling::function]
    pub fn get(&self) -> HatState {
        self.state
    }

    #[profiling::function]
    pub fn set(&mut self, state: HatState) {
        self.state = state;
    }

    #[profiling::function]
    pub fn reset(&mut self) {
        self.state.reset();
    }
}
