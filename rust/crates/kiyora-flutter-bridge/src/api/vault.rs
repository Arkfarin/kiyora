//! Vault operations retain backend ownership checks, journals and online guards.
use super::{BridgeError, Session, auth::Operation, id, invalid, runtime};
use vault_core::{ApiError, ErrorCode, VaultRequest, VaultResponse};

#[derive(Debug, Clone)]
pub enum Mode {
    AuthRequired,
    Discovering,
    Syncing,
    OnlineReady,
    Reconnecting,
    DegradedReadonly,
}
#[derive(Debug, Clone)]
pub struct Status {
    pub session: Session,
    pub mode: Mode,
    pub cursor: Option<String>,
    pub generation: Option<u64>,
}
impl From<vault_core::Status> for Status {
    fn from(s: vault_core::Status) -> Self {
        use vault_sync::RuntimeMode as M;
        Self {
            session: s.context.into(),
            mode: match s.mode {
                M::AuthRequired => Mode::AuthRequired,
                M::Discovering => Mode::Discovering,
                M::Syncing => Mode::Syncing,
                M::OnlineReady => Mode::OnlineReady,
                M::Reconnecting => Mode::Reconnecting,
                M::DegradedReadonly => Mode::DegradedReadonly,
            },
            cursor: s.vault.as_ref().map(|v| v.cursor.clone()),
            generation: s.vault.map(|v| v.generation),
        }
    }
}
#[derive(Debug, Clone)]
pub struct Creation {
    pub vault_id: String,
    pub chat_id: Option<String>,
    pub stage: String,
}
#[derive(Debug, Clone)]
pub struct SessionDetails {
    pub session: Session,
    pub event_sequence: String,
    pub chat_id: Option<String>,
    pub api_configured: bool,
    pub connection: String,
    pub service_running: bool,
    pub repair_required: bool,
    pub creation: Option<Creation>,
}
pub async fn session_details(session_id: String) -> Result<SessionDetails, BridgeError> {
    let s = runtime()
        .await?
        .backend
        .session_info(id(&session_id)?)
        .await?;
    Ok(SessionDetails {
        session: s.context.into(),
        event_sequence: s.event_sequence,
        chat_id: s.chat_id.map(|v| v.to_string()),
        api_configured: s.api_configured,
        connection: s.telegram_connection,
        service_running: s.service_running,
        repair_required: s.repair_required,
        creation: s.creation.map(|c| Creation {
            vault_id: c.vault_id.to_string(),
            chat_id: c.chat_id.map(|v| v.to_string()),
            stage: c.stage,
        }),
    })
}
pub async fn status() -> Result<Status, BridgeError> {
    Ok(runtime().await?.backend.runtime_status().await?.into())
}
#[derive(Debug, Clone)]
pub struct Candidate {
    pub vault_id: String,
    pub chat_id: String,
    pub title: String,
}
pub async fn discover(
    session_id: String,
    operation: &Operation,
) -> Result<Vec<Candidate>, BridgeError> {
    Ok(runtime()
        .await?
        .backend
        .discover_vaults(id(&session_id)?, &operation.token)
        .await?
        .into_iter()
        .map(|c| Candidate {
            vault_id: c.init.vault_id.to_string(),
            chat_id: c.channel.chat_id.to_string(),
            title: c.channel.title,
        })
        .collect())
}
pub async fn attach(
    session_id: String,
    chat_id: String,
    operation: &Operation,
) -> Result<Status, BridgeError> {
    let chat = chat_id.parse().map_err(|_| invalid())?;
    Ok(runtime()
        .await?
        .backend
        .attach_vault(id(&session_id)?, chat, &operation.token)
        .await?
        .into())
}
pub async fn create(
    session_id: String,
    title: Option<String>,
    operation: &Operation,
) -> Result<Status, BridgeError> {
    Ok(runtime()
        .await?
        .backend
        .create_vault_named(id(&session_id)?, title, &operation.token)
        .await?
        .into())
}
pub async fn resume_creation(
    session_id: String,
    chat_id: String,
    operation: &Operation,
) -> Result<Status, BridgeError> {
    let chat = chat_id.parse().map_err(|_| invalid())?;
    Ok(runtime()
        .await?
        .backend
        .resume_vault_creation(id(&session_id)?, chat, &operation.token)
        .await?
        .into())
}
pub async fn synchronize(session_id: String, operation: &Operation) -> Result<(), BridgeError> {
    match runtime()
        .await?
        .backend
        .service_request(id(&session_id)?, VaultRequest::Sync, &operation.token)
        .await?
    {
        VaultResponse::Synced => Ok(()),
        _ => Err(ApiError::new(ErrorCode::Internal).into()),
    }
}
