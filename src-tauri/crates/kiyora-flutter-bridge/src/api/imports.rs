//! Preview files are owned by the existing backend staging journal.
use super::{
    BridgeError,
    auth::Operation,
    content::{Artwork, Lyrics, Metadata},
    edits::{Command, MetadataEdit},
    id,
    jobs::ImportReview,
    runtime,
};
use vault_core::{ApiError, ErrorCode, VaultRequest, VaultResponse};

#[derive(Debug, Clone)]
pub struct Preview {
    pub id: String,
    pub filename: String,
    pub metadata: Metadata,
    pub digest: String,
    pub size_bytes: u64,
    pub artwork: Option<Artwork>,
    pub lyrics: Option<Lyrics>,
    pub warnings: Vec<String>,
}
impl From<vault_core::ImportPreview> for Preview {
    fn from(p: vault_core::ImportPreview) -> Self {
        Self {
            id: p.preview_id.to_string(),
            filename: p.filename,
            metadata: p.metadata.into(),
            digest: p.sha256,
            size_bytes: p.size_bytes,
            artwork: p.artwork.map(Into::into),
            lyrics: p.lyrics.map(Into::into),
            warnings: p.warnings,
        }
    }
}
pub async fn preview(
    session_id: String,
    preview_id: String,
    path: String,
    operation: &Operation,
) -> Result<Preview, BridgeError> {
    match runtime()
        .await?
        .backend
        .service_request(
            id(&session_id)?,
            VaultRequest::PreviewImport {
                path,
                preview_id: id(&preview_id)?,
            },
            &operation.token,
        )
        .await?
    {
        VaultResponse::ImportPreview(p) => Ok((*p).into()),
        _ => Err(ApiError::new(ErrorCode::Internal).into()),
    }
}
pub async fn previews(
    session_id: String,
    operation: &Operation,
) -> Result<Vec<Preview>, BridgeError> {
    match runtime()
        .await?
        .backend
        .service_request(
            id(&session_id)?,
            VaultRequest::ListImportPreviews,
            &operation.token,
        )
        .await?
    {
        VaultResponse::ImportPreviews(items) => Ok(items.into_iter().map(Into::into).collect()),
        _ => Err(ApiError::new(ErrorCode::Internal).into()),
    }
}
pub async fn discard(
    session_id: String,
    preview_id: String,
    operation: &Operation,
) -> Result<(), BridgeError> {
    match runtime()
        .await?
        .backend
        .service_request(
            id(&session_id)?,
            VaultRequest::DiscardImportPreview {
                preview_id: id(&preview_id)?,
            },
            &operation.token,
        )
        .await?
    {
        VaultResponse::PreviewDiscarded => Ok(()),
        _ => Err(ApiError::new(ErrorCode::Internal).into()),
    }
}
#[derive(Debug, Clone)]
pub enum ImportResult {
    Command { command: Command },
    Review { review: ImportReview },
}
impl TryFrom<VaultResponse> for ImportResult {
    type Error = BridgeError;
    fn try_from(r: VaultResponse) -> Result<Self, Self::Error> {
        match r {
            VaultResponse::Command(c) => Ok(Self::Command {
                command: (*c).into(),
            }),
            VaultResponse::ImportReview {
                metadata,
                sha256,
                size_bytes,
                duplicate_track_ids,
                possible_duplicate_track_ids,
            } => Ok(Self::Review {
                review: ImportReview {
                    title: metadata.title,
                    artist: metadata.performer,
                    album: metadata.album,
                    digest: sha256,
                    size_bytes,
                    duplicate_track_ids: duplicate_track_ids
                        .into_iter()
                        .map(|v| v.to_string())
                        .collect(),
                    possible_duplicate_track_ids: possible_duplicate_track_ids
                        .into_iter()
                        .map(|v| v.to_string())
                        .collect(),
                },
            }),
            _ => Err(ApiError::new(ErrorCode::Internal).into()),
        }
    }
}
/// Retain preview/track/source IDs on retry; edit=None sends original metadata.
pub async fn commit(
    session_id: String,
    preview_id: String,
    track_id: String,
    source_id: String,
    edit: Option<MetadataEdit>,
    write_tags: bool,
    allow_duplicate: bool,
    operation: &Operation,
) -> Result<ImportResult, BridgeError> {
    runtime()
        .await?
        .backend
        .service_request(
            id(&session_id)?,
            VaultRequest::ImportPrepared {
                preview_id: id(&preview_id)?,
                track_id: id(&track_id)?,
                source_id: id(&source_id)?,
                edit: edit.map(|e| e.into_core().map(Box::new)).transpose()?,
                write_tags,
                allow_duplicate,
            },
            &operation.token,
        )
        .await?
        .try_into()
}
pub async fn resume(
    session_id: String,
    operation_id: String,
    operation: &Operation,
) -> Result<ImportResult, BridgeError> {
    runtime()
        .await?
        .backend
        .service_request(
            id(&session_id)?,
            VaultRequest::ResumeImport {
                op_id: id(&operation_id)?,
            },
            &operation.token,
        )
        .await?
        .try_into()
}
