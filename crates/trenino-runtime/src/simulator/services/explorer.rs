//! Endpoint exploration over the accepted simulator client.
//!
//! Port of `Trenino.Simulator.ControlDetector` (lib/trenino/simulator/control_detector.ex):
//! lists the controls under `CurrentDrivableActor`, classifies levers by the
//! `Function.GetNotchCount` endpoint and buttons by `Property.bDefaultToPressed`,
//! and suggests controls for an element name using the same confidence ladder
//! (exact 1.0, contained 0.85/0.75, word-match blend, Jaro fallback, > 0.3 gate).

use crate::simulator::client::{SimulatorClient, SimulatorError};
use serde_json::Value;

pub const ROOT_PATH: &str = "CurrentDrivableActor";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct LeverControl {
    pub name: String,
    pub min_endpoint: String,
    pub max_endpoint: String,
    pub value_endpoint: String,
    pub notch_count_endpoint: String,
    pub notch_index_endpoint: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ButtonControl {
    pub name: String,
    pub endpoint: String,
}

#[derive(Clone, Debug, PartialEq)]
pub struct LeverSuggestion {
    pub lever: LeverControl,
    pub confidence: f64,
}

#[derive(Clone, Debug, PartialEq)]
pub struct ButtonSuggestion {
    pub button: ButtonControl,
    pub confidence: f64,
}

#[derive(Clone, Debug, PartialEq)]
pub enum ExploreError {
    Simulator(SimulatorError),
}

#[derive(Clone, Debug, PartialEq)]
pub enum SuggestError {
    Simulator(SimulatorError),
    NoMatch,
}

impl From<SimulatorError> for ExploreError {
    fn from(error: SimulatorError) -> Self {
        Self::Simulator(error)
    }
}

impl From<SimulatorError> for SuggestError {
    fn from(error: SimulatorError) -> Self {
        Self::Simulator(error)
    }
}

impl From<ExploreError> for SuggestError {
    fn from(error: ExploreError) -> Self {
        match error {
            ExploreError::Simulator(simulator) => SuggestError::Simulator(simulator),
        }
    }
}

/// Lists the binary control names under `CurrentDrivableActor`, mirroring
/// `ControlDetector.list_controls/1` (non-binary nodes are dropped, a response
/// without "Nodes" yields an empty list).
pub async fn list_controls(client: &SimulatorClient) -> Result<Vec<String>, ExploreError> {
    let response = client.list(Some(ROOT_PATH)).await?;
    Ok(binary_nodes(&response))
}

/// Detects lever controls by checking each control's endpoints for
/// `Function.GetNotchCount` (mirrors `ControlDetector.detect_levers/2`).
pub async fn detect_levers(client: &SimulatorClient) -> Result<Vec<LeverControl>, ExploreError> {
    let controls = list_controls(client).await?;
    let mut levers = Vec::new();
    for name in controls {
        let path = format!("{ROOT_PATH}/{name}");
        let Ok(response) = client.list(Some(&path)).await else {
            continue;
        };
        let endpoints = binary_nodes(&response);
        if endpoints
            .iter()
            .any(|endpoint| endpoint.contains("Function.GetNotchCount"))
        {
            levers.push(LeverControl {
                name: name.clone(),
                min_endpoint: format!("{path}.Function.GetMinimumInputValue"),
                max_endpoint: format!("{path}.Function.GetMaximumInputValue"),
                value_endpoint: format!("{path}.InputValue"),
                notch_count_endpoint: format!("{path}.Function.GetNotchCount"),
                notch_index_endpoint: format!("{path}.Function.GetCurrentNotchIndex"),
            });
        }
    }
    Ok(levers)
}

/// Detects button controls by checking each control's endpoints for
/// `Property.bDefaultToPressed` (mirrors `ControlDetector.detect_buttons/2`).
pub async fn detect_buttons(client: &SimulatorClient) -> Result<Vec<ButtonControl>, ExploreError> {
    let controls = list_controls(client).await?;
    let mut buttons = Vec::new();
    for name in controls {
        let path = format!("{ROOT_PATH}/{name}");
        let Ok(response) = client.list(Some(&path)).await else {
            continue;
        };
        let endpoints = binary_nodes(&response);
        if endpoints
            .iter()
            .any(|endpoint| endpoint.contains("Property.bDefaultToPressed"))
        {
            buttons.push(ButtonControl {
                name: name.clone(),
                endpoint: format!("{path}.InputValue"),
            });
        }
    }
    Ok(buttons)
}

/// Suggests the best matching lever for `element_name` (mirrors
/// `ControlDetector.suggest_lever/1`): best confidence wins, and only a
/// confidence strictly above 0.3 is a match.
pub async fn suggest_lever(
    client: &SimulatorClient,
    element_name: &str,
) -> Result<LeverSuggestion, SuggestError> {
    let levers = detect_levers(client).await?;
    let best = best_match(
        element_name,
        levers.iter().map(|lever| (lever.name.as_str(), lever)),
    );
    match best {
        Some((lever, confidence)) if confidence > 0.3 => Ok(LeverSuggestion {
            lever: lever.clone(),
            confidence,
        }),
        _ => Err(SuggestError::NoMatch),
    }
}

/// Suggests the best matching button for `element_name` (mirrors
/// `ControlDetector.suggest_button/1`).
pub async fn suggest_button(
    client: &SimulatorClient,
    element_name: &str,
) -> Result<ButtonSuggestion, SuggestError> {
    let buttons = detect_buttons(client).await?;
    let best = best_match(
        element_name,
        buttons.iter().map(|button| (button.name.as_str(), button)),
    );
    match best {
        Some((button, confidence)) if confidence > 0.3 => Ok(ButtonSuggestion {
            button: button.clone(),
            confidence,
        }),
        _ => Err(SuggestError::NoMatch),
    }
}

/// Best match by confidence; ties keep the first candidate like Elixir's
/// `Enum.max_by/2`.
fn best_match<'a, T>(
    element_name: &str,
    candidates: impl Iterator<Item = (&'a str, &'a T)>,
) -> Option<(&'a T, f64)> {
    let mut best: Option<(&'a T, f64)> = None;
    for (name, candidate) in candidates {
        let confidence = confidence(element_name, name);
        if best.is_none() || confidence > best.as_ref().unwrap().1 {
            best = Some((candidate, confidence));
        }
    }
    best
}

/// Confidence ladder ported from `ControlDetector.calculate_confidence/2`.
pub fn confidence(element_name: &str, control_name: &str) -> f64 {
    let element = element_name.to_lowercase();
    let control = control_name.to_lowercase();
    if element == control {
        return 1.0;
    }
    if control.contains(&element) {
        return 0.85;
    }
    if element.contains(&control) {
        return 0.75;
    }
    let element_words = split_into_words(&element);
    let control_words = split_into_words(&control);
    let word_matches = element_words
        .iter()
        .filter(|word| control_words.contains(word))
        .count();
    if word_matches > 0 {
        let base = (0.5 + word_matches as f64 * 0.2).min(0.9);
        let jaro = jaro_distance(&element, &control);
        (base + jaro) / 2.0
    } else {
        jaro_distance(&element, &control)
    }
}

/// Word splitting ported from `ControlDetector.split_into_words/1`: split on
/// whitespace/`_`/`-`/`(`/`)`, then split camelCase between ASCII lowercase and
/// uppercase, lowercasing every piece.
pub fn split_into_words(value: &str) -> Vec<String> {
    value
        .split(|c: char| c.is_whitespace() || matches!(c, '_' | '-' | '(' | ')'))
        .flat_map(split_camel_case)
        .filter(|word| !word.is_empty())
        .map(|word| word.to_lowercase())
        .collect()
}

fn split_camel_case(word: &str) -> Vec<String> {
    let mut spaced = String::with_capacity(word.len() + 4);
    let mut previous_lower = false;
    for c in word.chars() {
        if c.is_ascii_uppercase() && previous_lower {
            spaced.push(' ');
        }
        previous_lower = c.is_ascii_lowercase();
        spaced.push(c);
    }
    spaced.split(' ').map(str::to_owned).collect()
}

/// Jaro distance matching `String.jaro_distance/2` (verified against Elixir
/// golden values: "dwayne"/"duane" = 0.8222, "hardware"/"wizardry" = 0.6667,
/// "throttle"/"throttlelever" = 0.8718).
pub fn jaro_distance(left: &str, right: &str) -> f64 {
    let left: Vec<char> = left.chars().collect();
    let right: Vec<char> = right.chars().collect();
    match (left.is_empty(), right.is_empty()) {
        (true, true) => return 1.0,
        (true, false) | (false, true) => return 0.0,
        (false, false) => {}
    }
    if left == right {
        return 1.0;
    }
    let window = (left.len().max(right.len()) / 2).saturating_sub(1);
    let mut left_matched = vec![false; left.len()];
    let mut right_matched = vec![false; right.len()];
    let mut matches = 0usize;
    for (i, left_char) in left.iter().enumerate() {
        let start = i.saturating_sub(window);
        let end = (i + window + 1).min(right.len());
        for j in start..end {
            if !right_matched[j] && right[j] == *left_char {
                left_matched[i] = true;
                right_matched[j] = true;
                matches += 1;
                break;
            }
        }
    }
    if matches == 0 {
        return 0.0;
    }
    let mut transpositions = 0usize;
    let mut k = 0usize;
    for (i, matched) in left_matched.iter().enumerate() {
        if !matched {
            continue;
        }
        while !right_matched[k] {
            k += 1;
        }
        if left[i] != right[k] {
            transpositions += 1;
        }
        k += 1;
    }
    let matches = matches as f64;
    let transpositions = transpositions as f64 / 2.0;
    (matches / left.len() as f64
        + matches / right.len() as f64
        + (matches - transpositions) / matches)
        / 3.0
}

fn binary_nodes(response: &Value) -> Vec<String> {
    response
        .get("Nodes")
        .and_then(Value::as_array)
        .map(|nodes| {
            nodes
                .iter()
                .filter_map(Value::as_str)
                .map(str::to_owned)
                .collect()
        })
        .unwrap_or_default()
}
