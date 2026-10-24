use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TrainProfile {
    pub id: i64,
    pub name: String,
    #[serde(default)]
    pub identifiers: Vec<String>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum IdentifierMatch {
    NotFound,
    Unique(i64),
    Ambiguous(Vec<i64>),
}

/// Any stored prefix matches; a train contributes only once even when multiple identifiers match.
pub fn match_identifier(profiles: &[TrainProfile], detected: &str) -> IdentifierMatch {
    let mut matched: Vec<i64> = profiles
        .iter()
        .filter(|profile| {
            profile
                .identifiers
                .iter()
                .any(|prefix| detected.starts_with(prefix))
        })
        .map(|profile| profile.id)
        .collect();
    matched.sort_unstable();
    matched.dedup();
    match matched.as_slice() {
        [] => IdentifierMatch::NotFound,
        [id] => IdentifierMatch::Unique(*id),
        _ => IdentifierMatch::Ambiguous(matched),
    }
}

pub fn normalize_object_class(value: &str) -> String {
    let value = value.strip_suffix("_C").unwrap_or(value);
    value
        .trim_end_matches(|c: char| !c.is_ascii_alphanumeric())
        .to_owned()
}
