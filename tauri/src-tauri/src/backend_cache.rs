use std::collections::hash_map::DefaultHasher;
use std::ffi::OsString;
use std::hash::{Hash, Hasher};
use std::path::{Path, PathBuf};
use tauri::Manager;

/// Burrito keys its extracted release by version, which nightlies reuse.
/// Give each distinct backend payload its own extraction directory.
pub fn directory(backend: &Path, cache_root: &Path) -> std::io::Result<PathBuf> {
    let mut fingerprint = DefaultHasher::new();
    std::fs::read(backend)?.hash(&mut fingerprint);
    Ok(cache_root.join(format!("backend-{:016x}", fingerprint.finish())))
}

/// Root directory for backend payload caches.
///
/// On Windows, Tauri's `app_cache_dir()` resolves LocalAppData through the
/// Known Folder API (`SHGetKnownFolderPath`), which always returns the real
/// profile path. The Burrito backend cannot boot ERTS from non-ASCII paths,
/// so users with e.g. Cyrillic profile names relocate app data by overriding
/// the APPDATA/LOCALAPPDATA environment variables (typically via a launcher
/// script). Honor those overrides here, matching how the Elixir backend
/// (`Trenino.Paths`, `runtime.exs`) and the Burrito wrapper itself resolve
/// their directories, and fall back to the Tauri path when they are unset.
///
/// LOCALAPPDATA is checked first: in a standard Windows session the variable
/// is always set and identical to the Known Folder result, so users without
/// overrides keep exactly the v0.8.0 cache location. APPDATA is only a
/// fallback for sessions where LOCALAPPDATA is unset entirely.
pub fn cache_root(app: &tauri::AppHandle) -> tauri::Result<PathBuf> {
    if cfg!(windows) {
        let identifier = app.config().identifier.clone();
        for var in ["LOCALAPPDATA", "APPDATA"] {
            if let Some(dir) = env_override(std::env::var_os(var), &identifier) {
                return Ok(dir);
            }
        }
    }
    app.path().app_cache_dir()
}

fn env_override(value: Option<OsString>, identifier: &str) -> Option<PathBuf> {
    value
        .filter(|dir| !dir.is_empty())
        .map(|dir| Path::new(&dir).join(identifier))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn replacing_a_same_version_backend_uses_a_fresh_cache() {
        let root = std::env::temp_dir().join(format!("trenino-cache-test-{}", std::process::id()));
        std::fs::create_dir_all(&root).unwrap();
        let backend = root.join("trenino_backend.exe");
        std::fs::write(&backend, b"first 0.8.0 nightly").unwrap();
        let first = directory(&backend, &root).unwrap();
        assert_eq!(first, directory(&backend, &root).unwrap());
        std::fs::write(&backend, b"next 0.8.0 nightly").unwrap();
        assert_ne!(first, directory(&backend, &root).unwrap());
        std::fs::remove_file(backend).unwrap();
        std::fs::remove_dir(root).unwrap();
    }

    #[test]
    fn env_override_joins_the_app_identifier() {
        let dir = env_override(
            Some(OsString::from(r"C:\AppDataOverride")),
            "dev.restifo.tws-io",
        )
        .unwrap();
        assert_eq!(
            dir,
            Path::new(r"C:\AppDataOverride").join("dev.restifo.tws-io")
        );
    }

    #[test]
    fn env_override_ignores_missing_or_empty_values() {
        assert_eq!(env_override(None, "dev.restifo.tws-io"), None);
        assert_eq!(
            env_override(Some(OsString::new()), "dev.restifo.tws-io"),
            None
        );
    }
}
