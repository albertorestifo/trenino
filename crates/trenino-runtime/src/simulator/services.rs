//! Simulator-side detection, exploration and calibration services.
//!
//! Ports of the Elixir simulator services that drive the accepted
//! [`SimulatorClient`](super::client::SimulatorClient): endpoint exploration
//! (`Trenino.Simulator.ControlDetector`), the control detection session
//! (`Trenino.Simulator.ControlDetectionSession`), lever analysis
//! (`Trenino.Simulator.LeverAnalyzer`), train detection
//! (`Trenino.Train.Detection`), and the lever/notch calibration sessions
//! (`Trenino.Train.Calibration.LeverSession`/`NotchMappingSession`).

pub mod calibration;
pub mod clock;
pub mod control_detection;
pub mod explorer;
pub mod lever_analysis;
pub mod session;
pub mod train_detection;
