//! Train-scoped runtime: detection/activation and lever/button/sequence/
//! output/display controllers over the shared resolver and resource arbiter.
pub mod button_controller;
pub mod detection;
pub mod display_controller;
pub mod lever_controller;
pub mod output_controller;
pub mod script;
pub mod sequence;
pub mod service;
