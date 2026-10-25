use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use std::path::{Path, PathBuf};

/// Burrito keys its extracted release by version, which nightlies reuse.
/// Give each distinct backend payload its own extraction directory.
pub fn directory(backend: &Path, cache_root: &Path) -> std::io::Result<PathBuf> {
    let mut fingerprint = DefaultHasher::new();
    std::fs::read(backend)?.hash(&mut fingerprint);
    Ok(cache_root.join(format!("backend-{:016x}", fingerprint.finish())))
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
}
