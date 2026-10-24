use super::{CatalogRelease, ReleaseInput, UpdateCheckRecord};
use trenino_core::EntityId;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RepositoryError {
    pub code: &'static str,
}
impl std::fmt::Display for RepositoryError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "firmware repository operation failed: {}", self.code)
    }
}
impl std::error::Error for RepositoryError {}

/// Injected storage boundary. Implementations must commit each catalog refresh as
/// one transaction and return only after commit. Check records must likewise be
/// durable before callers publish a notification. IDs are stable database row IDs.
pub trait FirmwareRepository: Send + Sync + 'static {
    fn upsert_catalog(
        &self,
        releases: &[ReleaseInput],
    ) -> Result<Vec<CatalogRelease>, RepositoryError>;
    fn list_releases(&self) -> Result<Vec<CatalogRelease>, RepositoryError>;
    fn get_release(&self, release_id: EntityId) -> Result<Option<CatalogRelease>, RepositoryError>;
    fn record_check(&self, record: &UpdateCheckRecord) -> Result<(), RepositoryError>;
    fn latest_check(&self) -> Result<Option<UpdateCheckRecord>, RepositoryError>;
    fn dismissed_notice(&self) -> Result<Option<String>, RepositoryError>;
    fn set_dismissed_notice(&self, version: Option<&str>) -> Result<(), RepositoryError>;
}
