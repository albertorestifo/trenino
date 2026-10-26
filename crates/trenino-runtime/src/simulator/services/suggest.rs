//! Name-based control suggestion over the connected simulator client.
//!
//! Service wrapper for [`super::explorer::suggest_lever`] /
//! [`super::explorer::suggest_button`] (port of the
//! `docs/control_auto_suggestion.md` User Flow: with the simulator connected,
//! an element name resolves to the best-matching control and its endpoints).
//! Mirrors the connected-client + 12s deadline pattern of the
//! `resolve_lever_endpoints` IPC handler.

use std::sync::Arc;
use std::time::Duration;

use serde::Serialize;
use tokio::sync::watch;

use crate::simulator::client::SimulatorClient;
use crate::simulator::connection::SimulatorStatus;
use crate::simulator::connection_owner::StatusSnapshot;

use super::explorer::{self, SuggestError};

const SUGGEST_DEADLINE: Duration = Duration::from_secs(12);

#[derive(Clone, Debug, PartialEq)]
pub enum SuggestServiceError {
    /// No live simulator connection: the TSW external interface is required.
    NotConnected,
    /// The suggestion call exceeded its deadline.
    Deadline,
    /// The simulator answered with an error.
    Simulator(String),
}

impl std::fmt::Display for SuggestServiceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NotConnected => write!(
                f,
                "Simulator not connected. Ensure Train Sim World is running with External Interface enabled."
            ),
            Self::Deadline => write!(f, "Simulator suggestion timed out"),
            Self::Simulator(detail) => write!(f, "Simulator error: {detail}"),
        }
    }
}

impl std::error::Error for SuggestServiceError {}

/// Best-matching lever for an element name: the control path, its five
/// endpoints and the match confidence (rounded to 2 decimals).
#[derive(Clone, Debug, PartialEq, Serialize)]
pub struct LeverSuggestionView {
    pub control_path: String,
    pub min_endpoint: String,
    pub max_endpoint: String,
    pub value_endpoint: String,
    pub notch_count_endpoint: String,
    pub notch_index_endpoint: String,
    pub confidence: f64,
}

/// Best-matching button for an element name: the control path, its endpoint
/// and the match confidence (rounded to 2 decimals).
#[derive(Clone, Debug, PartialEq, Serialize)]
pub struct ButtonSuggestionView {
    pub control_path: String,
    pub endpoint: String,
    pub confidence: f64,
}

/// Suggestion service bound to the live simulator status channel: every call
/// uses the currently connected client or fails with [`SuggestServiceError::NotConnected`].
#[derive(Clone)]
pub struct SuggestService {
    status: watch::Receiver<StatusSnapshot>,
}

impl SuggestService {
    pub fn new(status: watch::Receiver<StatusSnapshot>) -> Self {
        Self { status }
    }

    fn client(&self) -> Result<Arc<SimulatorClient>, SuggestServiceError> {
        let snapshot = self.status.borrow();
        if snapshot.status == SimulatorStatus::Connected {
            snapshot.client.clone()
        } else {
            None
        }
        .ok_or(SuggestServiceError::NotConnected)
    }

    /// Best-matching lever for `element_name`, or `None` when no control
    /// clears the confidence gate.
    pub async fn suggest_lever(
        &self,
        element_name: &str,
    ) -> Result<Option<LeverSuggestionView>, SuggestServiceError> {
        let client = self.client()?;
        let suggestion = tokio::time::timeout(
            SUGGEST_DEADLINE,
            explorer::suggest_lever(&client, element_name),
        )
        .await
        .map_err(|_| SuggestServiceError::Deadline)?;
        let suggestion = match suggestion {
            Ok(suggestion) => suggestion,
            Err(SuggestError::NoMatch) => return Ok(None),
            Err(SuggestError::Simulator(error)) => {
                return Err(SuggestServiceError::Simulator(format!("{error:?}")))
            }
        };
        Ok(Some(LeverSuggestionView {
            control_path: suggestion.lever.name.clone(),
            min_endpoint: suggestion.lever.min_endpoint,
            max_endpoint: suggestion.lever.max_endpoint,
            value_endpoint: suggestion.lever.value_endpoint,
            notch_count_endpoint: suggestion.lever.notch_count_endpoint,
            notch_index_endpoint: suggestion.lever.notch_index_endpoint,
            confidence: (suggestion.confidence * 100.0).round() / 100.0,
        }))
    }

    /// Best-matching button for `element_name`, or `None` when no control
    /// clears the confidence gate.
    pub async fn suggest_button(
        &self,
        element_name: &str,
    ) -> Result<Option<ButtonSuggestionView>, SuggestServiceError> {
        let client = self.client()?;
        let suggestion = tokio::time::timeout(
            SUGGEST_DEADLINE,
            explorer::suggest_button(&client, element_name),
        )
        .await
        .map_err(|_| SuggestServiceError::Deadline)?;
        let suggestion = match suggestion {
            Ok(suggestion) => suggestion,
            Err(SuggestError::NoMatch) => return Ok(None),
            Err(SuggestError::Simulator(error)) => {
                return Err(SuggestServiceError::Simulator(format!("{error:?}")))
            }
        };
        Ok(Some(ButtonSuggestionView {
            control_path: suggestion.button.name.clone(),
            endpoint: suggestion.button.endpoint,
            confidence: (suggestion.confidence * 100.0).round() / 100.0,
        }))
    }
}
