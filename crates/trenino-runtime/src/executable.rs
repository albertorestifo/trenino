//! Three-tier executable discovery for the keystroke sidecar and avrdude,
//! porting `Trenino.Keyboard.executable_path/0`
//! (lib/trenino/keyboard.ex:86-163) and `Trenino.Firmware.Avrdude.executable_path/0`
//! (lib/trenino/firmware/avrdude.ex:20-34):
//!
//! 1. **Trusted configured path** — an absolute path to an existing file.
//!    Relative or missing candidates are rejected here (fail-closed rule
//!    from the packaging constraints).
//! 2. **App-resource path** — the Tauri `APP_PATH` bundle directory, probed
//!    for the platform binary name (Elixir `tauri_sidecar_executable/0`).
//! 3. **Development candidates** — only in debug builds
//!    (`cfg!(debug_assertions)`): the bundled `priv/bin` location and the
//!    repo-relative `tauri/keystroke/target/{release,debug}` build outputs
//!    (Elixir `bundled_executable/0` + `dev_executable/0`). Release builds
//!    never probe development or PATH locations. In development avrdude falls back to a PATH
//!    search (`System.find_executable/1`); PATH hits are absolute by
//!    construction.
//!
//! All base directories are injectable so tests exercise the ladder without
//! touching the real filesystem layout.

use std::path::{Path, PathBuf};

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ExecutableError {
    /// A configured candidate was relative or missing: never silently
    /// resolved (fail-closed rule from the packaging constraints).
    Untrusted(PathBuf),
    /// No tier produced a usable executable.
    NotFound,
}

impl std::fmt::Display for ExecutableError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Untrusted(path) => write!(
                f,
                "executable path is not a trusted absolute file: {}",
                path.display()
            ),
            Self::NotFound => f.write_str("executable not found"),
        }
    }
}

impl std::error::Error for ExecutableError {}

/// Injectable probe configuration: one binary plus the base directories of
/// each tier.
#[derive(Clone, Debug, Default)]
pub struct ExecutableProbe {
    /// Tier 0: configured trusted location (settings-style absolute path).
    pub configured: Option<PathBuf>,
    /// Tier 1: app-resource directory probed for the platform binary name
    /// (Elixir `System.get_env("APP_PATH")` sidecar location).
    pub app_resource_dir: Option<PathBuf>,
    /// Tier 2 (dev only): bundled `priv/bin`-style directories.
    pub bundled_dirs: Vec<PathBuf>,
    /// Tier 2 (dev only): repo-relative build-output directories.
    pub dev_dirs: Vec<PathBuf>,
    /// Tier 3: search the process PATH like `System.find_executable/1`.
    pub search_path: bool,
    /// Platform binary name (`keystroke` / `keystroke.exe`, ...).
    binary_name: String,
}

fn platform_binary(base: &str) -> String {
    if cfg!(windows) {
        format!("{base}.exe")
    } else {
        base.to_string()
    }
}

fn trusted_absolute_file(path: &Path) -> Option<PathBuf> {
    if path.is_absolute() && path.is_file() {
        Some(path.to_path_buf())
    } else {
        None
    }
}

impl ExecutableProbe {
    /// Probe for the bundled keystroke sidecar, mirroring
    /// `Trenino.Keyboard.executable_path/0`'s three tiers. Development
    /// candidates (`priv/bin`, `tauri/keystroke/target/*`) are only probed in
    /// debug builds; the app-resource tier reads `APP_PATH` when set.
    pub fn keystroke() -> Self {
        let cwd = std::env::current_dir().ok();
        Self {
            configured: None,
            app_resource_dir: std::env::var_os("APP_PATH").map(PathBuf::from),
            bundled_dirs: cwd
                .as_ref()
                .map(|c| vec![c.join("priv").join("bin")])
                .unwrap_or_default(),
            dev_dirs: cwd
                .map(|c| {
                    vec![
                        c.join("tauri")
                            .join("keystroke")
                            .join("target")
                            .join("release"),
                        c.join("tauri")
                            .join("keystroke")
                            .join("target")
                            .join("debug"),
                    ]
                })
                .unwrap_or_default(),
            search_path: false,
            binary_name: platform_binary("keystroke"),
        }
    }

    /// Probe for avrdude, mirroring `Trenino.Firmware.Avrdude.executable_path/0`:
    /// the same sidecar/bundled tiers plus a final PATH search.
    pub fn avrdude() -> Self {
        let cwd = std::env::current_dir().ok();
        Self {
            configured: None,
            app_resource_dir: std::env::var_os("APP_PATH").map(PathBuf::from),
            bundled_dirs: cwd
                .as_ref()
                .map(|c| vec![c.join("priv").join("bin")])
                .unwrap_or_default(),
            dev_dirs: Vec::new(),
            search_path: true,
            binary_name: platform_binary("avrdude"),
        }
    }

    /// Resolve the executable through the tier ladder. Every accepted result
    /// is an absolute path to an existing file.
    pub fn resolve(&self) -> Result<PathBuf, ExecutableError> {
        self.resolve_with_development(cfg!(debug_assertions))
    }

    fn resolve_with_development(&self, development: bool) -> Result<PathBuf, ExecutableError> {
        if let Some(configured) = &self.configured {
            match trusted_absolute_file(configured) {
                Some(path) => return Ok(path),
                // A configured-but-bad path is reported, not skipped: the
                // caller asked for this exact executable.
                None => return Err(ExecutableError::Untrusted(configured.clone())),
            }
        }
        if let Some(path) = self
            .app_resource_dir
            .as_ref()
            .map(|dir| dir.join(&self.binary_name))
            .and_then(|p| trusted_absolute_file(&p))
        {
            return Ok(path);
        }
        // Development candidates are repo-relative by nature; release builds
        // keep the fail-closed rule and never probe them.
        if development {
            for dir in self.bundled_dirs.iter().chain(self.dev_dirs.iter()) {
                if let Some(path) = trusted_absolute_file(&dir.join(&self.binary_name)) {
                    return Ok(path);
                }
            }
        }
        if development && self.search_path {
            if let Some(path) = self.search_path_for(&self.binary_name) {
                return Ok(path);
            }
        }
        Err(ExecutableError::NotFound)
    }

    /// `System.find_executable/1`: first PATH entry holding the binary as a
    /// regular file. Results are absolute by construction.
    fn search_path_for(&self, binary: &str) -> Option<PathBuf> {
        let path = std::env::var_os("PATH")?;
        std::env::split_paths(&path)
            .map(|dir| dir.join(binary))
            .find(|candidate| candidate.is_absolute() && candidate.is_file())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn write_exec(dir: &Path, name: &str) -> PathBuf {
        let path = dir.join(name);
        std::fs::write(&path, b"#!/bin/sh\n").unwrap();
        path
    }

    fn probe(binary: &str) -> ExecutableProbe {
        ExecutableProbe {
            binary_name: binary.into(),
            ..ExecutableProbe::keystroke()
        }
    }

    #[test]
    fn tier0_configured_absolute_path_wins() {
        let dir = tempfile::tempdir().unwrap();
        let exe = write_exec(dir.path(), "keystroke");
        let dev = tempfile::tempdir().unwrap();
        write_exec(dev.path(), "keystroke");
        let config = probe("keystroke");
        let ladder = ExecutableProbe {
            configured: Some(exe.clone()),
            bundled_dirs: vec![dev.path().to_path_buf()],
            ..config
        };
        assert_eq!(ladder.resolve().unwrap(), exe);
    }

    #[test]
    fn tier0_relative_or_missing_configured_path_is_untrusted() {
        let relative = probe("keystroke");
        let relative = ExecutableProbe {
            configured: Some(PathBuf::from("keystroke")),
            ..relative
        };
        assert_eq!(
            relative.resolve(),
            Err(ExecutableError::Untrusted(PathBuf::from("keystroke")))
        );

        let missing = ExecutableProbe {
            configured: Some(PathBuf::from("/nonexistent/keystroke-xyz")),
            ..probe("keystroke")
        };
        assert_eq!(
            missing.resolve(),
            Err(ExecutableError::Untrusted(PathBuf::from(
                "/nonexistent/keystroke-xyz"
            )))
        );
    }

    #[test]
    fn tier1_app_resource_dir_is_probed_next() {
        let resource = tempfile::tempdir().unwrap();
        let exe = write_exec(resource.path(), "keystroke");
        let ladder = ExecutableProbe {
            app_resource_dir: Some(resource.path().to_path_buf()),
            ..probe("keystroke")
        };
        assert_eq!(ladder.resolve().unwrap(), exe);
    }

    #[test]
    fn tier2_dev_candidates_probe_in_ladder_order() {
        let first = tempfile::tempdir().unwrap();
        let second = tempfile::tempdir().unwrap();
        let exe = write_exec(second.path(), "keystroke");
        let ladder = ExecutableProbe {
            bundled_dirs: vec![first.path().to_path_buf()],
            dev_dirs: vec![second.path().to_path_buf()],
            ..probe("keystroke")
        };
        assert_eq!(ladder.resolve().unwrap(), exe);
    }

    #[test]
    fn nothing_found_reports_not_found() {
        let empty = tempfile::tempdir().unwrap();
        let ladder = ExecutableProbe {
            app_resource_dir: Some(empty.path().to_path_buf()),
            bundled_dirs: vec![empty.path().to_path_buf()],
            ..probe("keystroke")
        };
        assert_eq!(ladder.resolve(), Err(ExecutableError::NotFound));
    }
    #[test]
    fn release_resolution_never_falls_back_to_development_or_path() {
        let dir = tempfile::tempdir().unwrap();
        write_exec(dir.path(), "avrdude");
        let ladder = ExecutableProbe {
            search_path: true,
            app_resource_dir: None,
            bundled_dirs: vec![dir.path().to_path_buf()],
            dev_dirs: Vec::new(),
            ..probe("avrdude")
        };
        assert_eq!(
            ladder.resolve_with_development(false),
            Err(ExecutableError::NotFound)
        );
        assert!(ladder.resolve_with_development(true).is_ok());
    }
}
