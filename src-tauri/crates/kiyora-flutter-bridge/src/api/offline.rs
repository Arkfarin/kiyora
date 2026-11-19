use super::{BridgeError, auth::Operation, id, runtime};
use vault_core::{ApiError, ErrorCode, VaultRequest, VaultResponse};

#[derive(Debug, Clone)]
pub enum Availability {
    Unavailable,
    RemoteOnly,
    Downloading,
    PartiallyCached,
    FullyCached,
    FailedRetryable,
    FailedPermanent,
    Cancelled,
}
#[derive(Debug, Clone)]
pub struct Download {
    pub id: String,
    pub track_id: String,
    pub state: Availability,
    pub bytes_downloaded: u64,
    pub total_bytes: Option<u64>,
    pub pinned: bool,
}
impl From<vault_core::DownloadInfo> for Download {
    fn from(d: vault_core::DownloadInfo) -> Self {
        use vault_core::DownloadState as S;
        Self {
            id: d.download_id.to_string(),
            track_id: d.track_id.to_string(),
            state: match d.state {
                S::Unavailable => Availability::Unavailable,
                S::RemoteOnly => Availability::RemoteOnly,
                S::Downloading => Availability::Downloading,
                S::PartiallyCached => Availability::PartiallyCached,
                S::FullyCached => Availability::FullyCached,
                S::FailedRetryable => Availability::FailedRetryable,
                S::FailedPermanent => Availability::FailedPermanent,
                S::Cancelled => Availability::Cancelled,
            },
            bytes_downloaded: d.bytes_downloaded,
            total_bytes: d.total_bytes,
            pinned: d.pinned,
        }
    }
}
async fn download_request(
    session: String,
    request: VaultRequest,
    operation: &Operation,
) -> Result<Download, BridgeError> {
    match runtime()
        .await?
        .backend
        .service_request(id(&session)?, request, &operation.token)
        .await?
    {
        VaultResponse::Download(d) => Ok(d.into()),
        _ => Err(ApiError::new(ErrorCode::Internal).into()),
    }
}
pub async fn download(
    session_id: String,
    download_id: String,
    track_id: String,
    source_id: String,
    pinned: bool,
    operation: &Operation,
) -> Result<Download, BridgeError> {
    download_request(
        session_id,
        VaultRequest::DownloadForOffline {
            download_id: id(&download_id)?,
            track_id: id(&track_id)?,
            source_id: id(&source_id)?,
            pinned,
        },
        operation,
    )
    .await
}
pub async fn status(
    session_id: String,
    download_id: String,
    track_id: String,
    source_id: String,
    operation: &Operation,
) -> Result<Download, BridgeError> {
    download_request(
        session_id,
        VaultRequest::GetDownloadStatus {
            download_id: id(&download_id)?,
            track_id: id(&track_id)?,
            source_id: id(&source_id)?,
        },
        operation,
    )
    .await
}
pub async fn cancel(
    session_id: String,
    download_id: String,
    operation: &Operation,
) -> Result<Download, BridgeError> {
    download_request(
        session_id,
        VaultRequest::CancelDownload {
            download_id: id(&download_id)?,
        },
        operation,
    )
    .await
}
pub async fn pin(
    session_id: String,
    track_id: String,
    source_id: String,
    pinned: bool,
    operation: &Operation,
) -> Result<(), BridgeError> {
    match runtime()
        .await?
        .backend
        .service_request(
            id(&session_id)?,
            VaultRequest::PinCachedMedia {
                track_id: id(&track_id)?,
                source_id: id(&source_id)?,
                pinned,
            },
            &operation.token,
        )
        .await?
    {
        VaultResponse::CachePinned => Ok(()),
        _ => Err(ApiError::new(ErrorCode::Internal).into()),
    }
}
#[derive(Debug, Clone)]
pub struct Cache {
    pub entries: u64,
    pub pinned_entries: u64,
    pub partial_entries: u64,
    pub partial_bytes: u64,
    pub reserved_bytes: u64,
    pub used_bytes: u64,
    pub quota_bytes: u64,
}
impl From<vault_media::CacheStats> for Cache {
    fn from(c: vault_media::CacheStats) -> Self {
        Self {
            entries: c.entries as u64,
            pinned_entries: c.pinned_entries as u64,
            partial_entries: c.partial_entries as u64,
            partial_bytes: c.partial_bytes,
            reserved_bytes: c.reserved_bytes,
            used_bytes: c.used_bytes,
            quota_bytes: c.quota_bytes,
        }
    }
}
/// None reads stats; Some changes the quota through the backend cache manager.
pub async fn cache(
    session_id: String,
    quota_bytes: Option<u64>,
    operation: &Operation,
) -> Result<Cache, BridgeError> {
    let request = quota_bytes.map_or(VaultRequest::GetCacheStats, |bytes| {
        VaultRequest::SetCacheQuota { bytes }
    });
    match runtime()
        .await?
        .backend
        .service_request(id(&session_id)?, request, &operation.token)
        .await?
    {
        VaultResponse::CacheStats(c) => Ok(c.into()),
        _ => Err(ApiError::new(ErrorCode::Internal).into()),
    }
}
/// Removes only unpinned data; active leases remain protected by Rust.
pub async fn clear_unpinned(session_id: String, operation: &Operation) -> Result<u64, BridgeError> {
    match runtime()
        .await?
        .backend
        .service_request(
            id(&session_id)?,
            VaultRequest::ClearLocalCache,
            &operation.token,
        )
        .await?
    {
        VaultResponse::CacheCleared { bytes_removed } => Ok(bytes_removed),
        _ => Err(ApiError::new(ErrorCode::Internal).into()),
    }
}
