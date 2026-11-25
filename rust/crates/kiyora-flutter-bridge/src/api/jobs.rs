//! Durable imports and backups remain owned by Rust after the initiating widget leaves.
use super::{BridgeError, edits::Command, id, runtime};
use vault_core::{JobRequest, JobResult};

#[derive(Debug, Clone)]
pub enum JobState {
    Running,
    Succeeded,
    Failed,
    Cancelled,
    Interrupted,
}
#[derive(Debug, Clone)]
pub struct ImportReview {
    pub title: String,
    pub artist: String,
    pub album: String,
    pub digest: Option<String>,
    pub size_bytes: u64,
    pub duplicate_track_ids: Vec<String>,
    pub possible_duplicate_track_ids: Vec<String>,
}
#[derive(Debug, Clone)]
pub struct FileResult {
    pub operation_id: String,
    pub command: Option<Command>,
    pub review: Option<ImportReview>,
    pub error: Option<BridgeError>,
}
#[derive(Debug, Clone)]
pub struct Job {
    pub id: String,
    pub state: JobState,
    pub completed: u64,
    pub total: u64,
    pub error: Option<BridgeError>,
    pub files: Vec<FileResult>,
    pub command: Option<Command>,
}
impl From<vault_core::JobInfo> for Job {
    fn from(j: vault_core::JobInfo) -> Self {
        use vault_core::JobState as S;
        let mut command = None;
        let mut files = Vec::new();
        if let Some(result) = j.result {
            match *result {
                JobResult::Bulk(items) => {
                    files = items
                        .into_iter()
                        .map(|item| {
                            let (command, review, error) = match item.result {
                                Ok(vault_core::VaultResponse::Command(c)) => {
                                    (Some((*c).into()), None, None)
                                }
                                Ok(vault_core::VaultResponse::ImportReview {
                                    metadata,
                                    sha256,
                                    size_bytes,
                                    duplicate_track_ids,
                                    possible_duplicate_track_ids,
                                }) => (
                                    None,
                                    Some(ImportReview {
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
                                    }),
                                    None,
                                ),
                                Ok(_) => (
                                    None,
                                    None,
                                    Some(
                                        vault_core::ApiError::new(vault_core::ErrorCode::Internal)
                                            .into(),
                                    ),
                                ),
                                Err(e) => (None, None, Some(e.into())),
                            };
                            FileResult {
                                operation_id: item.op_id.to_string(),
                                command,
                                review,
                                error,
                            }
                        })
                        .collect();
                }
                JobResult::Vault(vault_core::VaultResponse::Command(c)) => {
                    command = Some((*c).into())
                }
                _ => {}
            }
        }
        Self {
            id: j.job_id.to_string(),
            state: match j.state {
                S::Running => JobState::Running,
                S::Succeeded => JobState::Succeeded,
                S::Failed => JobState::Failed,
                S::Cancelled => JobState::Cancelled,
                S::Interrupted => JobState::Interrupted,
            },
            completed: j.completed as u64,
            total: j.total as u64,
            error: j.error.map(Into::into),
            files,
            command,
        }
    }
}
#[derive(Debug, Clone)]
pub struct ImportFile {
    pub path: String,
    pub track_id: String,
    pub source_id: String,
    pub operation_id: String,
    pub allow_duplicate: bool,
}
/// Backend validates batch bounds explicitly; no selected files are silently dropped.
pub async fn import_files(
    session_id: String,
    job_id: String,
    files: Vec<ImportFile>,
) -> Result<Job, BridgeError> {
    let files = files
        .into_iter()
        .map(|f| {
            Ok(vault_core::ImportFile {
                path: f.path,
                track_id: id(&f.track_id)?,
                source_id: id(&f.source_id)?,
                op_id: id(&f.operation_id)?,
                allow_duplicate: f.allow_duplicate,
            })
        })
        .collect::<Result<Vec<_>, BridgeError>>()?;
    Ok(runtime()
        .await?
        .backend
        .start_job(
            id(&session_id)?,
            id(&job_id)?,
            JobRequest::BulkImport { files },
            false,
        )
        .await?
        .into())
}
#[derive(Debug, Clone)]
pub enum BackupKind {
    Metadata,
    Full,
}
pub async fn export_backup(
    session_id: String,
    job_id: String,
    path: String,
    kind: BackupKind,
) -> Result<Job, BridgeError> {
    let kind = match kind {
        BackupKind::Metadata => vault_snapshot::backup::BackupKind::Metadata,
        BackupKind::Full => vault_snapshot::backup::BackupKind::Full,
    };
    Ok(runtime()
        .await?
        .backend
        .start_job(
            id(&session_id)?,
            id(&job_id)?,
            JobRequest::ExportBackup { path, kind },
            false,
        )
        .await?
        .into())
}
pub async fn list(session_id: String) -> Result<Vec<Job>, BridgeError> {
    Ok(runtime()
        .await?
        .backend
        .list_jobs(id(&session_id)?)
        .await?
        .into_iter()
        .map(Into::into)
        .collect())
}
pub async fn status(session_id: String, job_id: String) -> Result<Job, BridgeError> {
    Ok(runtime()
        .await?
        .backend
        .job_status(id(&session_id)?, id(&job_id)?)
        .await?
        .into())
}
/// Cancellation requests do not manufacture a terminal state; the worker confirms it.
pub async fn cancel(session_id: String, job_id: String) -> Result<Job, BridgeError> {
    Ok(runtime()
        .await?
        .backend
        .cancel_job(id(&session_id)?, id(&job_id)?)
        .await?
        .into())
}
pub async fn resume(session_id: String, job_id: String) -> Result<Job, BridgeError> {
    Ok(runtime()
        .await?
        .backend
        .resume_job(id(&session_id)?, id(&job_id)?)
        .await?
        .into())
}
pub async fn forget(session_id: String, job_id: String) -> Result<(), BridgeError> {
    Ok(runtime()
        .await?
        .backend
        .forget_job(id(&session_id)?, id(&job_id)?)
        .await?)
}
pub async fn repair_database(session_id: String, job_id: String) -> Result<Job, BridgeError> {
    Ok(runtime()
        .await?
        .backend
        .start_job(
            id(&session_id)?,
            id(&job_id)?,
            JobRequest::RepairDatabase,
            false,
        )
        .await?
        .into())
}
pub async fn recover_database(
    session_id: String,
    job_id: String,
    path: String,
) -> Result<Job, BridgeError> {
    Ok(runtime()
        .await?
        .backend
        .start_job(
            id(&session_id)?,
            id(&job_id)?,
            JobRequest::RecoverDatabaseFromBackup { path },
            false,
        )
        .await?
        .into())
}
