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

/// Mirrors `Trenino.Train.Identifier.common_prefix/1` (identifier.ex:51-62):
/// the longest common prefix compared per grapheme (like `String.graphemes/1`),
/// with trailing non-alphanumeric characters stripped. A single string is
/// returned unchanged; an empty list yields `""`.
pub fn common_prefix(strings: &[String]) -> String {
    let Some(first) = strings.first() else {
        return String::new();
    };
    if strings.len() == 1 {
        // identifier.ex returns a lone string as-is, without stripping.
        return (*first).clone();
    }
    let mut shared: Vec<&str> = graphemes(first.as_str());
    for string in &strings[1..] {
        let other = graphemes(string.as_str());
        let common = shared
            .iter()
            .zip(other.iter())
            .take_while(|(a, b)| a == b)
            .count();
        shared.truncate(common);
        if shared.is_empty() {
            break;
        }
    }
    strip_trailing_non_alphanumeric(&shared.concat())
}

/// Mirrors `Trenino.Train.Identifier.extract_train_name/1` (identifier.ex:87-96;
/// the module doctests are the oracle): strips an optional `_C` suffix, drops
/// the `RVM` and route-code parts, then tries DB+BR, company+model and
/// single-part patterns before the letters-and-digits fallback.
pub fn extract_train_name(identifier: &str) -> String {
    let trimmed = identifier.strip_suffix("_C").unwrap_or(identifier);
    let parts: Vec<&str> = trimmed.split('_').collect();
    let rest = match parts.first() {
        Some(&"RVM") => &parts[1..],
        _ => &parts[..],
    };
    // Skip the route code only when at least one part remains after it
    // (extract_name_from_parts/1's `rest != []` guard).
    let parts = match rest.split_first() {
        Some((_, tail)) if !tail.is_empty() => tail,
        _ => return String::new(),
    };
    let candidate = find_train_name_pattern(parts);
    if candidate.is_empty() {
        fallback_name(parts)
    } else {
        candidate
    }
}

fn find_train_name_pattern(parts: &[&str]) -> String {
    let db_br = find_db_br_pattern(parts);
    if !db_br.is_empty() {
        return db_br;
    }
    let company_model = find_company_model_pattern(parts);
    if !company_model.is_empty() {
        return company_model;
    }
    find_single_part_pattern(parts)
}

/// `^Class\d+$` case-insensitive becomes `Class <number>` (original case kept,
/// like the Elixir capture replacement); `^[A-Z]\d{1,2}(-[A-Z])?$`
/// case-insensitive becomes the letter+digits model (the `-X` suffix drops).
fn find_single_part_pattern(parts: &[&str]) -> String {
    for part in parts {
        if let Some(number) = match_class_number(part) {
            return format!("{} {}", &part[..part.len() - number.len()], number);
        }
        if let Some(model) = match_model_number(part) {
            return model;
        }
    }
    String::new()
}

fn match_class_number(part: &str) -> Option<&str> {
    let rest = strip_prefix_ignore_ascii_case(part, "class")?;
    (!rest.is_empty() && rest.bytes().all(|b| b.is_ascii_digit())).then_some(rest)
}

fn match_model_number(part: &str) -> Option<String> {
    let bytes = part.as_bytes();
    if bytes.is_empty() || !bytes[0].is_ascii_alphabetic() {
        return None;
    }
    let mut index = 1;
    while index < bytes.len() && bytes[index].is_ascii_digit() {
        index += 1;
    }
    let digits = index - 1;
    if digits == 0 || digits > 2 {
        return None;
    }
    if index == bytes.len() {
        return Some(part[..index].to_owned());
    }
    // Optional single `-X` suffix; the returned model drops it (Elixir `\\1`).
    if bytes[index] == b'-' && bytes.len() == index + 2 && bytes[index + 1].is_ascii_alphabetic() {
        return Some(part[..index].to_owned());
    }
    None
}

fn find_db_br_pattern(parts: &[&str]) -> String {
    for pair in parts.windows(2) {
        if pair[0].eq_ignore_ascii_case("DB") {
            if let Some(number) = match_br_number(pair[1]) {
                return format!("DB BR {number}");
            }
        }
    }
    String::new()
}

fn match_br_number(part: &str) -> Option<&str> {
    let rest = strip_prefix_ignore_ascii_case(part, "br")?;
    (!rest.is_empty() && rest.bytes().all(|b| b.is_ascii_digit())).then_some(rest)
}

const COMPANIES: [&str; 10] = [
    "BNSF", "UP", "NS", "CSX", "DB", "SNCF", "LIRR", "MBTA", "NJT", "AMTK",
];

fn find_company_model_pattern(parts: &[&str]) -> String {
    for pair in parts.windows(2) {
        if COMPANIES.contains(&pair[0])
            && pair[1]
                .as_bytes()
                .first()
                .is_some_and(|b| b.is_ascii_alphanumeric())
        {
            return format!("{} {}", pair[0], pair[1]);
        }
    }
    String::new()
}

/// First part of 2-10 ASCII alphanumerics containing both a digit and a letter.
fn fallback_name(parts: &[&str]) -> String {
    parts
        .iter()
        .find(|part| {
            (2..=10).contains(&part.len())
                && part.bytes().all(|b| b.is_ascii_alphanumeric())
                && part.bytes().any(|b| b.is_ascii_digit())
                && part.bytes().any(|b| b.is_ascii_alphabetic())
        })
        .map(|part| (*part).to_owned())
        .unwrap_or_default()
}

/// ASCII case-insensitive `str::strip_prefix`.
fn strip_prefix_ignore_ascii_case<'a>(string: &'a str, prefix: &str) -> Option<&'a str> {
    if string
        .get(..prefix.len())
        .is_some_and(|head| head.eq_ignore_ascii_case(prefix))
    {
        string.get(prefix.len()..)
    } else {
        None
    }
}

fn graphemes(string: &str) -> Vec<&str> {
    unicode_segmentation::UnicodeSegmentation::graphemes(string, true).collect()
}

fn strip_trailing_non_alphanumeric(string: &str) -> String {
    string
        .trim_end_matches(|c: char| !c.is_ascii_alphanumeric())
        .to_owned()
}
