//! Deliberately small DTO boundary; IDs retain the backend's session fencing.
pub mod auth;
pub mod content;
pub mod edits;
pub mod imports;
pub mod jobs;
pub mod offline;
#[cfg(test)]
mod tests;
pub mod vault;
use std::{path::PathBuf, sync::Arc};
use tokio::sync::{Mutex, RwLock, RwLockReadGuard};
use tokio_util::sync::CancellationToken;
use uuid::Uuid;
use vault_core::{ApiError, Backend, ErrorCode};

static RUNTIME: RwLock<Option<Runtime>> = RwLock::const_new(None);
// Lifecycle calls are serialized independently of in-flight API readers. Exit
// must reach Backend::shutdown (which cancels jobs) before waiting for readers.
static LIFECYCLE: Mutex<()> = Mutex::const_new(());
struct Runtime {
    backend: Arc<Backend>,
    closed: CancellationToken,
}

#[derive(Debug, Clone, thiserror::Error)]
#[error("{message}")]
#[flutter_rust_bridge::frb(dart_code = "@override String toString() => message;")]
pub struct BridgeError {
    pub code: String,
    pub message: String,
    pub retryable: bool,
    pub retry_after_seconds: Option<u64>,
}
impl From<ApiError> for BridgeError {
    fn from(e: ApiError) -> Self {
        Self {
            code: format!("{:?}", e.code),
            message: e.message,
            retryable: e.retryable,
            retry_after_seconds: e.retry_after_seconds,
        }
    }
}
fn invalid() -> BridgeError {
    ApiError::new(ErrorCode::InvalidInput).into()
}
fn id(value: &str) -> Result<Uuid, BridgeError> {
    Uuid::parse_str(value).map_err(|_| invalid())
}
async fn runtime() -> Result<RwLockReadGuard<'static, Runtime>, BridgeError> {
    let state = RwLockReadGuard::try_map(RUNTIME.read().await, Option::as_ref)
        .map_err(|_| BridgeError::from(ApiError::new(ErrorCode::Closed)))?;
    if state.closed.is_cancelled() {
        return Err(ApiError::new(ErrorCode::Closed).into());
    }
    Ok(state)
}

#[derive(Debug, Clone)]
pub struct Session {
    pub profile_id: String,
    pub session_id: String,
    pub vault_id: Option<String>,
}
impl From<vault_core::Context> for Session {
    fn from(c: vault_core::Context) -> Self {
        Self {
            profile_id: c.profile_id.to_string(),
            session_id: c.session_id.to_string(),
            vault_id: c.vault_id.map(|v| v.to_string()),
        }
    }
}
#[derive(Debug, Clone)]
pub struct Profile {
    pub id: String,
    pub label: String,
}

/// Desktop initialization uses the exact same ProfileStore and OS keyring as
/// Tauri. Android must install its native storage/media adapters first.
pub async fn initialize(
    resources: Option<String>,
    window_handle: Option<u64>,
) -> Result<Option<Session>, BridgeError> {
    let _lifecycle = LIFECYCLE.lock().await;
    {
        let slot = RUNTIME.read().await;
        if let Some(state) = slot.as_ref() {
            return restore_session(state).await;
        }
    }
    let mut slot = RUNTIME.write().await;
    if slot.is_none() {
        {
            let backend = tokio::task::spawn_blocking(move || {
                vault_core::initialize_diagnostics();
                #[cfg(target_os = "android")]
                let backend = {
                    let _ = (resources, window_handle);
                    kiyora_android_runtime::backend()?
                };
                #[cfg(not(target_os = "android"))]
                let backend = Backend::default_backend_with_resources(
                    resources.map(PathBuf::from).as_deref(),
                )?;
                #[cfg(any(target_os = "linux", target_os = "windows"))]
                let backend = backend.with_playback_platform(Arc::new(
                    kiyora_desktop_media::DesktopMedia::new(Arc::new(crate::desktop::Host::new(
                        window_handle,
                    )?)),
                ));
                Ok::<_, ApiError>(backend)
            })
            .await
            .map_err(|_| ApiError::new(ErrorCode::Internal))??;
            *slot = Some(Runtime {
                backend: Arc::new(backend),
                closed: CancellationToken::new(),
            });
        }
    }
    let state = slot
        .as_ref()
        .ok_or_else(|| ApiError::new(ErrorCode::Closed))?;
    restore_session(state).await
}

async fn restore_session(state: &Runtime) -> Result<Option<Session>, BridgeError> {
    if state.closed.is_cancelled() {
        return Err(ApiError::new(ErrorCode::Closed).into());
    }
    // Repeated Flutter attachment never recreates the engine or profile session.
    if let Some(context) = state.backend.context().await {
        return Ok(Some(context.into()));
    }
    Ok(state
        .backend
        .restore_active_profile()
        .await?
        .map(|s| s.context.into()))
}

/// Only the application owner calls this, never a widget's dispose callback.
pub async fn shutdown() -> Result<(), BridgeError> {
    let _lifecycle = LIFECYCLE.lock().await;
    {
        let slot = RUNTIME.read().await;
        if let Some(state) = slot.as_ref() {
            // Reject new commands and wake event feeds immediately. Taking a
            // write lock here would wait for jobs that only shutdown can cancel.
            state.closed.cancel();
            state.backend.shutdown().await?;
        }
    }
    *RUNTIME.write().await = None;
    Ok(())
}
pub async fn profiles() -> Result<Vec<Profile>, BridgeError> {
    Ok(runtime()
        .await?
        .backend
        .profiles()?
        .into_iter()
        .map(|p| Profile {
            id: p.profile_id.to_string(),
            label: p.label,
        })
        .collect())
}
pub async fn create_profile(label: String) -> Result<Profile, BridgeError> {
    let p = runtime().await?.backend.create_profile(label)?;
    Ok(Profile {
        id: p.profile_id.to_string(),
        label: p.label,
    })
}
pub async fn switch_profile(profile_id: String) -> Result<Session, BridgeError> {
    Ok(runtime()
        .await?
        .backend
        .switch_profile(id(&profile_id)?)
        .await?
        .context
        .into())
}

#[derive(Debug, Clone)]
pub enum Transport {
    Pause,
    Resume,
    Stop,
    Next,
    Previous,
    Seek { milliseconds: u64 },
}
#[derive(Debug, Clone)]
pub enum Playback {
    Idle,
    Ended {
        track_id: String,
    },
    Buffering {
        track_id: String,
        position_ms: u64,
        duration_ms: u64,
    },
    Playing {
        track_id: String,
        position_ms: u64,
        duration_ms: u64,
    },
    Paused {
        track_id: String,
        position_ms: u64,
        duration_ms: u64,
    },
    Failed {
        track_id: Option<String>,
        code: String,
    },
}
impl From<vault_media::PlaybackState> for Playback {
    fn from(s: vault_media::PlaybackState) -> Self {
        use vault_media::PlaybackState as P;
        match s {
            P::Idle => Self::Idle,
            P::Ended { track_id, .. } => Self::Ended {
                track_id: track_id.to_string(),
            },
            P::Buffering {
                track_id,
                position_ms,
                duration_ms,
            } => Self::Buffering {
                track_id: track_id.to_string(),
                position_ms,
                duration_ms,
            },
            P::Playing {
                track_id,
                position_ms,
                duration_ms,
            } => Self::Playing {
                track_id: track_id.to_string(),
                position_ms,
                duration_ms,
            },
            P::Paused {
                track_id,
                position_ms,
                duration_ms,
            } => Self::Paused {
                track_id: track_id.to_string(),
                position_ms,
                duration_ms,
            },
            P::Failed { track_id, code } => Self::Failed {
                track_id: track_id.map(|v| v.to_string()),
                code,
            },
        }
    }
}
pub async fn playback(session_id: String) -> Result<Playback, BridgeError> {
    Ok(runtime()
        .await?
        .backend
        .playback_state(id(&session_id)?)
        .await?
        .into())
}
pub async fn control(session_id: String, action: Transport) -> Result<Playback, BridgeError> {
    use vault_core::PlaybackAction as A;
    let action = match action {
        Transport::Pause => A::Pause,
        Transport::Resume => A::Resume,
        Transport::Stop => A::Stop,
        Transport::Next => A::Next,
        Transport::Previous => A::Previous,
        Transport::Seek { milliseconds } => A::Seek(milliseconds),
    };
    Ok(runtime()
        .await?
        .backend
        .control_playback(id(&session_id)?, action)
        .await?
        .into())
}

#[derive(Debug, Clone)]
pub enum Repeat {
    Off,
    All,
    One,
}
#[derive(Debug, Clone)]
pub struct Queue {
    pub id: String,
    pub revision: u64,
    pub total: u64,
    pub position: Option<u64>,
    pub current_track_id: Option<String>,
    pub shuffle: bool,
    pub repeat: Repeat,
}
impl From<vault_core::QueueInfo> for Queue {
    fn from(q: vault_core::QueueInfo) -> Self {
        Self {
            id: q.queue_id.to_string(),
            revision: q.revision,
            total: q.total as u64,
            position: q.position.map(|v| v as u64),
            current_track_id: q.current_track_id.map(|v| v.to_string()),
            shuffle: q.shuffle,
            repeat: match q.repeat {
                vault_core::RepeatMode::Off => Repeat::Off,
                vault_core::RepeatMode::Queue => Repeat::All,
                vault_core::RepeatMode::Track => Repeat::One,
            },
        }
    }
}
#[derive(Debug, Clone)]
pub struct QueuePage {
    pub queue: Queue,
    pub offset: u32,
    pub track_ids: Vec<String>,
}
pub async fn queue(session_id: String, offset: u32, limit: u32) -> Result<QueuePage, BridgeError> {
    let page = runtime()
        .await?
        .backend
        .playback_queue(id(&session_id)?, offset, limit)
        .await?;
    Ok(QueuePage {
        queue: page.info.into(),
        offset: page.offset,
        track_ids: page.track_ids.into_iter().map(|v| v.to_string()).collect(),
    })
}
pub async fn play(
    session_id: String,
    track_ids: Vec<String>,
    position: u32,
) -> Result<Queue, BridgeError> {
    let ids = track_ids
        .iter()
        .map(|s| id(s))
        .collect::<Result<Vec<_>, _>>()?;
    Ok(runtime()
        .await?
        .backend
        .set_queue(id(&session_id)?, ids, position, true)
        .await?
        .into())
}
#[derive(Debug, Clone)]
pub enum QueueEdit {
    Append { track_ids: Vec<String>, next: bool },
    Remove { index: u32 },
    Move { from: u32, to: u32 },
    Jump { index: u32 },
    Shuffle { enabled: bool },
    Repeat { mode: Repeat },
}
pub async fn edit_queue(
    session_id: String,
    queue_id: String,
    revision: u64,
    edit: QueueEdit,
) -> Result<Queue, BridgeError> {
    use vault_core::QueueAction as A;
    let action = match edit {
        QueueEdit::Append { track_ids, next } => A::Append {
            track_ids: track_ids
                .iter()
                .map(|s| id(s))
                .collect::<Result<Vec<_>, _>>()?,
            next,
        },
        QueueEdit::Remove { index } => A::Remove {
            index: index as usize,
        },
        QueueEdit::Move { from, to } => A::Move {
            from: from as usize,
            to: to as usize,
        },
        QueueEdit::Jump { index } => A::Jump {
            index: index as usize,
        },
        QueueEdit::Shuffle { enabled } => A::Shuffle { enabled },
        QueueEdit::Repeat { mode } => A::Repeat {
            mode: match mode {
                Repeat::Off => vault_core::RepeatMode::Off,
                Repeat::All => vault_core::RepeatMode::Queue,
                Repeat::One => vault_core::RepeatMode::Track,
            },
        },
    };
    Ok(runtime()
        .await?
        .backend
        .edit_queue(id(&session_id)?, id(&queue_id)?, revision, action)
        .await?
        .into())
}

/// Pulling from a bounded backend subscription preserves explicit loss signals.
/// Close cancels a pending receive; shutdown also wakes every reader.
#[flutter_rust_bridge::frb(opaque)]
pub struct EventFeed {
    subscription: Mutex<vault_core::EventSubscription>,
    closed: CancellationToken,
    runtime_closed: CancellationToken,
}
#[derive(Debug, Clone)]
pub enum Change {
    Playback { state: Playback },
    Queue { state: Queue },
    Job { state: jobs::Job },
    Runtime { state: vault::Status },
    AuthChanged,
    Sync { running: bool },
    Library { cursor: String },
    Playlist { playlist_id: String },
    Command { result: edits::Command },
    Warning { error: BridgeError },
    Refresh,
    Resync { missed_events: String },
}
#[derive(Debug, Clone)]
pub struct Notification {
    pub session: Option<Session>,
    pub sequence: Option<String>,
    pub change: Change,
}
pub async fn subscribe() -> Result<EventFeed, BridgeError> {
    let state = runtime().await?;
    Ok(EventFeed {
        subscription: Mutex::new(state.backend.events().subscribe_reliable()),
        closed: CancellationToken::new(),
        runtime_closed: state.closed.clone(),
    })
}
impl EventFeed {
    pub async fn next(&self) -> Option<Notification> {
        tokio::select! {
            _ = self.closed.cancelled() => None,
            _ = self.runtime_closed.cancelled() => None,
            item = async { self.subscription.lock().await.recv().await } => {
                item.map(|item| match item {
                    vault_core::EventDelivery::ResyncRequired(lost) => Notification {
                        session: None, sequence: lost.after_sequence,
                        change: Change::Resync { missed_events: lost.missed_events },
                    },
                    vault_core::EventDelivery::Event(event) => Notification {
                        session: Some(event.context.into()), sequence: Some(event.sequence),
                        change: match event.data {
                            vault_core::EventData::Playback(p) => Change::Playback { state: p.into() },
                            vault_core::EventData::Queue(q) => Change::Queue { state: q.into() },
                            vault_core::EventData::Job(j) => Change::Job { state: j.into() },
                            vault_core::EventData::Runtime(s) => Change::Runtime { state: s.into() },
                            vault_core::EventData::Auth(_) => Change::AuthChanged,
                            vault_core::EventData::Sync { running } => Change::Sync { running },
                            vault_core::EventData::Library { cursor } => Change::Library { cursor },
                            vault_core::EventData::Playlist { playlist_id } => Change::Playlist { playlist_id: playlist_id.to_string() },
                            vault_core::EventData::Command(c) => Change::Command { result: (*c).into() },
                            vault_core::EventData::Warning(e) => Change::Warning { error: e.into() },
                            _ => Change::Refresh,
                        },
                    },
                })
            }
        }
    }
    pub fn close(&self) {
        self.closed.cancel();
    }
}

#[derive(Debug, Clone)]
pub struct Track {
    pub id: String,
    pub revision: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub duration_ms: u64,
    pub artwork_digest: Option<String>,
}
/// Offset is forwarded to SQLite; there is no 500-track frontend cutoff.
pub async fn library(
    session_id: String,
    query: Option<String>,
    offset: u32,
    limit: u32,
) -> Result<Vec<Track>, BridgeError> {
    if limit == 0 || limit > 500 || query.as_ref().is_some_and(|q| q.len() > 1024) {
        return Err(invalid());
    }
    let state = runtime().await?;
    let tracks = state
        .backend
        .local_reader(id(&session_id)?)
        .await?
        .library(query, offset, limit)
        .await
        .map_err(ApiError::from)?;
    Ok(tracks.into_iter().map(Into::into).collect())
}

/// The Flutter window owner consumes this request and raises its native window.
/// The media callback itself never calls Flutter from the audio thread.
pub fn take_window_raise_request() -> bool {
    #[cfg(any(target_os = "linux", target_os = "windows"))]
    {
        crate::desktop::take_raise()
    }
    #[cfg(not(any(target_os = "linux", target_os = "windows")))]
    {
        false
    }
}

impl From<vault_domain::Track> for Track {
    fn from(t: vault_domain::Track) -> Self {
        Self {
            id: t.track_id.to_string(),
            revision: t.updated_order.to_string(),
            title: t.metadata.title,
            artist: t.metadata.performer,
            album: t.metadata.album,
            duration_ms: t.metadata.duration_ms,
            artwork_digest: t.metadata.artwork.map(|a| a.sha256),
        }
    }
}
/// Allocate once for a user action and retain this ID through uncertain retries.
pub fn new_operation_id() -> String {
    Uuid::new_v4().to_string()
}

#[derive(Debug, Clone)]
pub struct ProjectionMarker {
    pub session: Session,
    pub sequence: String,
    pub cursor: String,
    pub track_count: u64,
    pub playlist_count: u64,
}
/// Subscribe first, then capture the backend snapshot watermark. The UI discards
/// its cached pages, reloads visible pages and processes newer invalidations.
/// Never transfer the entire music collection to Dart just to recover a stream.
pub async fn projection_marker(session_id: String) -> Result<ProjectionMarker, BridgeError> {
    let snapshot = runtime()
        .await?
        .backend
        .state_snapshot(id(&session_id)?)
        .await?;
    Ok(ProjectionMarker {
        session: snapshot.context.into(),
        sequence: snapshot.event_sequence,
        cursor: snapshot.cursor,
        track_count: snapshot.state.tracks.len() as u64,
        playlist_count: snapshot.state.playlists.len() as u64,
    })
}
