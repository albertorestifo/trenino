use std::cmp::Ordering;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct FirmwareVersion {
    major: u64,
    minor: u64,
    patch: u64,
    pre: Vec<Identifier>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
enum Identifier {
    Numeric(u64),
    Text(String),
}

impl FirmwareVersion {
    pub fn parse(input: &str) -> Result<Self, RequirementError> {
        let value = input.strip_prefix('v').unwrap_or(input);
        let (value, build) = value
            .split_once('+')
            .map_or((value, None), |(head, tail)| (head, Some(tail)));
        if let Some(build) = build {
            if build.is_empty()
                || build.split('.').any(|id| {
                    id.is_empty() || !id.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-')
                })
            {
                return Err(RequirementError::InvalidVersion);
            }
        }
        let (core, prerelease) = value
            .split_once('-')
            .map_or((value, None), |(a, b)| (a, Some(b)));
        let parts: Vec<_> = core.split('.').collect();
        if parts.len() != 3 {
            return Err(RequirementError::InvalidVersion);
        }
        let [major, minor, patch] = [
            parse_number(parts[0])?,
            parse_number(parts[1])?,
            parse_number(parts[2])?,
        ];
        let mut pre = Vec::new();
        if let Some(prerelease) = prerelease {
            if prerelease.is_empty() {
                return Err(RequirementError::InvalidVersion);
            }
            for id in prerelease.split('.') {
                if id.is_empty() || !id.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-') {
                    return Err(RequirementError::InvalidVersion);
                }
                if id.bytes().all(|b| b.is_ascii_digit()) {
                    if id.len() > 1 && id.starts_with('0') {
                        return Err(RequirementError::InvalidVersion);
                    }
                    pre.push(Identifier::Numeric(
                        id.parse().map_err(|_| RequirementError::InvalidVersion)?,
                    ));
                } else {
                    pre.push(Identifier::Text(id.to_owned()));
                }
            }
        }
        Ok(Self {
            major,
            minor,
            patch,
            pre,
        })
    }
    pub fn is_prerelease(&self) -> bool {
        !self.pre.is_empty()
    }

    fn same_core(&self, other: &Self) -> bool {
        (self.major, self.minor, self.patch) == (other.major, other.minor, other.patch)
    }
}

fn parse_number(value: &str) -> Result<u64, RequirementError> {
    if value.is_empty()
        || (value.len() > 1 && value.starts_with('0'))
        || !value.bytes().all(|b| b.is_ascii_digit())
    {
        return Err(RequirementError::InvalidVersion);
    }
    value.parse().map_err(|_| RequirementError::InvalidVersion)
}

impl Ord for FirmwareVersion {
    fn cmp(&self, other: &Self) -> Ordering {
        (self.major, self.minor, self.patch)
            .cmp(&(other.major, other.minor, other.patch))
            .then_with(|| match (self.pre.is_empty(), other.pre.is_empty()) {
                (true, true) => Ordering::Equal,
                (true, false) => Ordering::Greater,
                (false, true) => Ordering::Less,
                (false, false) => self
                    .pre
                    .iter()
                    .zip(&other.pre)
                    .map(|(a, b)| match (a, b) {
                        (Identifier::Numeric(a), Identifier::Numeric(b)) => a.cmp(b),
                        (Identifier::Numeric(_), Identifier::Text(_)) => Ordering::Less,
                        (Identifier::Text(_), Identifier::Numeric(_)) => Ordering::Greater,
                        (Identifier::Text(a), Identifier::Text(b)) => a.cmp(b),
                    })
                    .find(|o| *o != Ordering::Equal)
                    .unwrap_or_else(|| self.pre.len().cmp(&other.pre.len())),
            })
    }
}
impl PartialOrd for FirmwareVersion {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

#[derive(Clone, Debug)]
struct Bound {
    op: Op,
    version: FirmwareVersion,
}
#[derive(Clone, Copy, Debug)]
enum Op {
    Eq,
    Gt,
    Ge,
    Lt,
    Le,
}

#[derive(Clone, Debug)]
pub struct FirmwareRequirement {
    alternatives: Vec<Vec<Bound>>,
    any: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RequirementError {
    InvalidVersion,
    InvalidRequirement,
    UnsupportedSyntax,
    RangeOverflow,
}
impl std::fmt::Display for RequirementError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(match self {
            Self::InvalidVersion => "invalid firmware version",
            Self::InvalidRequirement => "invalid firmware version requirement",
            Self::UnsupportedSyntax => "unsupported firmware requirement syntax",
            Self::RangeOverflow => "firmware requirement range exceeds supported version bounds",
        })
    }
}
impl std::error::Error for RequirementError {}

impl FirmwareRequirement {
    /// Parse the supported Elixir `Version.Requirement` grammar: exact versions,
    /// `and`/`or`, comparison operators and pessimistic `~>` ranges.
    pub fn parse(value: Option<&str>) -> Result<Self, RequirementError> {
        let Some(value) = value else {
            return Ok(Self {
                alternatives: Vec::new(),
                any: true,
            });
        };
        if value.trim().is_empty() {
            return Err(RequirementError::InvalidRequirement);
        }
        let mut alternatives = Vec::new();
        for alternative in value.split(" or ") {
            if alternative.trim().is_empty() {
                return Err(RequirementError::InvalidRequirement);
            }
            let mut bounds = Vec::new();
            for raw in alternative.split(" and ") {
                let part = raw.trim();
                if part.is_empty() || part.contains(',') {
                    return Err(RequirementError::UnsupportedSyntax);
                }
                let parsed_op = ["~>", ">=", "<=", "==", ">", "<"]
                    .iter()
                    .find_map(|op| part.strip_prefix(op).map(|v| (*op, v.trim())));
                let (op_text, version_text) = match parsed_op {
                    Some((op, version)) => (op, version),
                    None if !part.starts_with('=')
                        && !part.starts_with('!')
                        && !part.starts_with('(')
                        && !part.starts_with(')') =>
                    {
                        ("==", part)
                    }
                    None => return Err(RequirementError::UnsupportedSyntax),
                };
                let (version, supplied) = parse_requirement_version(version_text, op_text == "~>")?;
                if op_text == "~>" {
                    bounds.push(Bound {
                        op: Op::Ge,
                        version: version.clone(),
                    });
                    let upper = if supplied <= 2 {
                        let major = version
                            .major
                            .checked_add(1)
                            .ok_or(RequirementError::RangeOverflow)?;
                        FirmwareVersion {
                            major,
                            minor: 0,
                            patch: 0,
                            pre: vec![],
                        }
                    } else {
                        let minor = version
                            .minor
                            .checked_add(1)
                            .ok_or(RequirementError::RangeOverflow)?;
                        FirmwareVersion {
                            major: version.major,
                            minor,
                            patch: 0,
                            pre: vec![],
                        }
                    };
                    bounds.push(Bound {
                        op: Op::Lt,
                        version: upper,
                    });
                } else {
                    let op = match op_text {
                        "==" => Op::Eq,
                        ">" => Op::Gt,
                        ">=" => Op::Ge,
                        "<" => Op::Lt,
                        "<=" => Op::Le,
                        _ => unreachable!(),
                    };
                    bounds.push(Bound { op, version });
                }
            }
            if bounds.is_empty() {
                return Err(RequirementError::InvalidRequirement);
            }
            alternatives.push(bounds);
        }
        Ok(Self {
            alternatives,
            any: false,
        })
    }
    pub fn matches(&self, input: &str) -> bool {
        let Ok(version) = FirmwareVersion::parse(input) else {
            return false;
        };
        if self.any {
            return true;
        }
        self.alternatives.iter().any(|group| {
            let prerelease_is_admitted = !version.is_prerelease()
                || group.iter().any(|bound| bound.version.same_core(&version));
            prerelease_is_admitted
                && group.iter().all(|bound| {
                    let ord = version.cmp(&bound.version);
                    match bound.op {
                        Op::Eq => ord == Ordering::Equal,
                        Op::Gt => ord == Ordering::Greater,
                        Op::Ge => ord != Ordering::Less,
                        Op::Lt => ord == Ordering::Less,
                        Op::Le => ord != Ordering::Greater,
                    }
                })
        })
    }
}

fn parse_requirement_version(
    input: &str,
    allow_partial: bool,
) -> Result<(FirmwareVersion, usize), RequirementError> {
    if input.starts_with('v') {
        return Err(RequirementError::UnsupportedSyntax);
    }
    let value = input;
    let core = value.split(['-', '+']).next().unwrap_or(value);
    let count = core.split('.').count();
    if (allow_partial && !(2..=3).contains(&count)) || (!allow_partial && count != 3) {
        return Err(RequirementError::InvalidRequirement);
    }
    let complete = match count {
        2 if allow_partial => format!("{value}.0"),
        _ => value.to_owned(),
    };
    Ok((FirmwareVersion::parse(&complete)?, count))
}
