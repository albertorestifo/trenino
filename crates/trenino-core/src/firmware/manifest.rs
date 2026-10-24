use serde::{Deserialize, Deserializer, Serialize, Serializer};

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct FirmwareManifest {
    pub version: String,
    pub project: String,
    pub devices: Vec<ManifestDevice>,
    #[serde(default)]
    pub release_date: Option<String>,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ManifestDevice {
    pub environment: String,
    pub display_name: String,
    pub firmware_file: String,
    pub upload_config: UploadConfig,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct UploadConfig {
    pub protocol: Programmer,
    pub mcu: String,
    pub speed: u32,
    #[serde(default)]
    pub requires_1200bps_touch: bool,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Programmer {
    Arduino,
    Avr109,
    Wiring,
    Avrisp,
    Usbasp,
    Unsupported(String),
}
impl Programmer {
    pub fn as_str(&self) -> &str {
        match self {
            Self::Arduino => "arduino",
            Self::Avr109 => "avr109",
            Self::Wiring => "wiring",
            Self::Avrisp => "avrisp",
            Self::Usbasp => "usbasp",
            Self::Unsupported(value) => value,
        }
    }
    pub fn is_supported(&self) -> bool {
        !matches!(self, Self::Unsupported(_))
    }
}
impl Serialize for Programmer {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        serializer.serialize_str(self.as_str())
    }
}
impl<'de> Deserialize<'de> for Programmer {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let value = String::deserialize(deserializer)?;
        Ok(match value.as_str() {
            "arduino" => Self::Arduino,
            "avr109" => Self::Avr109,
            "wiring" => Self::Wiring,
            "avrisp" => Self::Avrisp,
            "usbasp" => Self::Usbasp,
            _ => Self::Unsupported(value),
        })
    }
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ManifestError {
    InvalidJson,
    InvalidShape,
    InvalidVersion,
    UnsafeComponent,
    InvalidUploadConfig,
}
impl FirmwareManifest {
    pub fn parse_json(json: &str) -> Result<Self, ManifestError> {
        let manifest: Self = serde_json::from_str(json).map_err(|_| ManifestError::InvalidJson)?;
        manifest.validate()?;
        Ok(manifest)
    }
    pub fn validate(&self) -> Result<(), ManifestError> {
        if self.project != "trenino" {
            return Err(ManifestError::InvalidShape);
        }
        let version = self.version.strip_prefix('v').unwrap_or(&self.version);
        if super::FirmwareVersion::parse(version).is_err() {
            return Err(ManifestError::InvalidVersion);
        }
        for d in &self.devices {
            if !safe_component(&d.environment)
                || !safe_filename(&d.firmware_file)
                || d.display_name.trim().is_empty()
            {
                return Err(ManifestError::UnsafeComponent);
            }
            if d.upload_config.mcu.trim().is_empty() || d.upload_config.speed == 0 {
                return Err(ManifestError::InvalidUploadConfig);
            }
        }
        Ok(())
    }
}
impl UploadConfig {
    pub fn normalized_mcu(&self) -> &str {
        match self.mcu.as_str() {
            "atmega328p" => "m328p",
            "atmega32u4" => "m32u4",
            "atmega2560" => "m2560",
            other => other,
        }
    }
}
pub fn safe_component(s: &str) -> bool {
    !s.is_empty()
        && s.len() <= 100
        && s.bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_' || b == b'.')
        && s != "."
        && s != ".."
}
pub fn safe_filename(s: &str) -> bool {
    safe_component(s) && s.contains('.')
}
