//! Injectable resolution of the established Trenino data locations.
use std::path::PathBuf;
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ResolvedPaths {
    pub data_dir: PathBuf,
    pub database_path: PathBuf,
}
/// Resolve paths without touching the filesystem; useful for tests and startup validation.
pub fn resolve(platform: &str, env: &[(&str, &str)]) -> ResolvedPaths {
    let get = |key: &str| {
        env.iter()
            .find(|(k, _)| *k == key)
            .map(|(_, v)| *v)
            .filter(|v| !v.is_empty())
    };
    let home = get("HOME").unwrap_or("~");
    let data_dir = match platform {
        "windows" => PathBuf::from(
            get("APPDATA")
                .or_else(|| get("LOCALAPPDATA"))
                .unwrap_or("."),
        )
        .join("Trenino"),
        "macos" => PathBuf::from(home).join("Library/Application Support/Trenino"),
        _ => get("XDG_DATA_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from(home).join(".local/share"))
            .join("trenino"),
    };
    let database_path = get("DATABASE_PATH")
        .map(PathBuf::from)
        .unwrap_or_else(|| data_dir.join("trenino.db"));
    ResolvedPaths {
        data_dir,
        database_path,
    }
}
