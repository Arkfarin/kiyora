//! Mutations keep stable operation IDs and use the existing durable writer.
use super::{BridgeError, Track, auth::Operation, content::Lyrics, id, invalid, runtime};
use vault_core::{
    ApiError, ErrorCode, LocalQuery, LocalResponse, Mutation, VaultRequest, VaultResponse,
};
use vault_domain::Action;

#[derive(Debug, Clone)]
pub enum CommandState {
    Created,
    Sending,
    ServerAck,
    Reconciling,
    Applied,
    Rejected,
    Unknown,
    TelegramError,
}
#[derive(Debug, Clone)]
pub struct Command {
    pub operation_id: String,
    pub entity_id: String,
    pub state: CommandState,
    pub server_message_id: Option<String>,
    pub outcome: Option<String>,
}
impl From<vault_db::Command> for Command {
    fn from(c: vault_db::Command) -> Self {
        use vault_db::CommandStatus as S;
        Self {
            operation_id: c.intent.op_id.to_string(),
            entity_id: c.intent.entity_id.to_string(),
            state: match c.status {
                S::Created => CommandState::Created,
                S::Sending => CommandState::Sending,
                S::ServerAck => CommandState::ServerAck,
                S::Reconciling => CommandState::Reconciling,
                S::Applied => CommandState::Applied,
                S::RejectedByReducer => CommandState::Rejected,
                S::UnknownOnTimeout => CommandState::Unknown,
                S::TelegramError => CommandState::TelegramError,
            },
            server_message_id: c.server_message_id.map(|v| v.to_string()),
            outcome: c.outcome.map(|v| format!("{v:?}")),
        }
    }
}
pub(super) fn command(response: VaultResponse) -> Result<Command, BridgeError> {
    match response {
        VaultResponse::Command(c) => Ok((*c).into()),
        _ => Err(ApiError::new(ErrorCode::Internal).into()),
    }
}
pub async fn command_status(
    session_id: String,
    operation_id: String,
) -> Result<Option<Command>, BridgeError> {
    match runtime()
        .await?
        .backend
        .query(
            id(&session_id)?,
            LocalQuery::CommandStatus {
                op_id: id(&operation_id)?,
            },
        )
        .await?
    {
        LocalResponse::CommandStatus(c) => Ok(c.map(|c| (*c).into())),
        _ => Err(ApiError::new(ErrorCode::Internal).into()),
    }
}
#[derive(Debug, Clone)]
pub enum LibraryEdit {
    CreatePlaylist {
        title: String,
    },
    RenamePlaylist {
        title: String,
    },
    DeletePlaylist,
    AddTrack {
        track_id: String,
        entry_id: String,
        after_entry_id: Option<String>,
    },
    RemoveTrack {
        entry_id: String,
    },
    MoveTrack {
        entry_id: String,
        after_entry_id: Option<String>,
    },
    Favorite {
        set_name: String,
        value: bool,
    },
    DeleteTrack,
}
pub async fn edit(
    session_id: String,
    operation_id: String,
    entity_id: String,
    edit: LibraryEdit,
    operation: &Operation,
) -> Result<Command, BridgeError> {
    let action = match edit {
        LibraryEdit::CreatePlaylist { title } => Action::PlaylistCreate { title },
        LibraryEdit::RenamePlaylist { title } => Action::PlaylistRename { title },
        LibraryEdit::DeletePlaylist => Action::PlaylistDelete {},
        LibraryEdit::AddTrack {
            track_id,
            entry_id,
            after_entry_id,
        } => Action::PlaylistTrackAdd {
            track_id: id(&track_id)?,
            entry_id: id(&entry_id)?,
            after_entry_id: after_entry_id.as_deref().map(id).transpose()?,
        },
        LibraryEdit::RemoveTrack { entry_id } => Action::PlaylistTrackRemove {
            entry_id: id(&entry_id)?,
        },
        LibraryEdit::MoveTrack {
            entry_id,
            after_entry_id,
        } => Action::PlaylistEntryMove {
            entry_id: id(&entry_id)?,
            after_entry_id: after_entry_id.as_deref().map(id).transpose()?,
        },
        LibraryEdit::Favorite { set_name, value } => Action::FavoriteSet { set_name, value },
        LibraryEdit::DeleteTrack => Action::TrackDelete {},
    };
    command(
        runtime()
            .await?
            .backend
            .service_request(
                id(&session_id)?,
                VaultRequest::Mutate(Box::new(Mutation {
                    op_id: id(&operation_id)?,
                    entity_id: id(&entity_id)?,
                    action,
                })),
                &operation.token,
            )
            .await?,
    )
}
#[derive(Debug, Clone)]
pub struct MetadataEdit {
    pub expected_revision: Option<String>,
    pub title: Option<String>,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub album_artist: Option<String>,
    pub duration_ms: Option<u64>,
    pub year: Option<u32>,
    pub genre: Option<String>,
    pub track_number: Option<u32>,
    pub disc_number: Option<u32>,
    pub composer: Option<String>,
    pub comment: Option<String>,
    pub copyright: Option<String>,
    pub artwork: Option<Vec<u8>>,
    pub clear_artwork: bool,
    pub lyrics: Option<Lyrics>,
    pub clear_lyrics: bool,
}
impl MetadataEdit {
    pub(super) fn into_core(self) -> Result<vault_core::MediaEdit, BridgeError> {
        if (self.clear_artwork && self.artwork.is_some())
            || (self.clear_lyrics && self.lyrics.is_some())
        {
            return Err(invalid());
        }
        Ok(vault_core::MediaEdit {
            patch: vault_domain::MetadataPatch {
                expected_order: self
                    .expected_revision
                    .map(|v| v.parse().map_err(|_| invalid()))
                    .transpose()?,
                title: self.title,
                performer: self.artist,
                album: self.album,
                album_artist: self.album_artist,
                duration_ms: self.duration_ms,
                year: self.year,
                genre: self.genre,
                track_number: self.track_number,
                disc_number: self.disc_number,
                composer: self.composer,
                comment: self.comment,
                copyright: self.copyright,
                clear_artwork: self.clear_artwork,
                clear_lyrics: self.clear_lyrics,
                ..Default::default()
            },
            artwork: self.artwork,
            lyrics: self.lyrics.map(|d| vault_domain::LyricsDocument {
                version: 1,
                language: d.language,
                lines: d
                    .lines
                    .into_iter()
                    .map(|l| vault_domain::LyricLine {
                        text: l.text,
                        start_ms: l.start_ms,
                        end_ms: l.end_ms,
                    })
                    .collect(),
            }),
        })
    }
}
pub async fn edit_metadata(
    session_id: String,
    operation_id: String,
    track_id: String,
    edit: MetadataEdit,
    operation: &Operation,
) -> Result<Command, BridgeError> {
    command(
        runtime()
            .await?
            .backend
            .service_request(
                id(&session_id)?,
                VaultRequest::EditMetadata {
                    op_id: id(&operation_id)?,
                    track_id: id(&track_id)?,
                    edit: Box::new(edit.into_core()?),
                },
                &operation.token,
            )
            .await?,
    )
}
pub async fn edit_playlist(
    session_id: String,
    operation_id: String,
    playlist_id: String,
    title: String,
    artwork: Option<Vec<u8>>,
    clear_artwork: bool,
    expected_revision: String,
    operation: &Operation,
) -> Result<Command, BridgeError> {
    command(
        runtime()
            .await?
            .backend
            .service_request(
                id(&session_id)?,
                VaultRequest::EditPlaylist {
                    op_id: id(&operation_id)?,
                    playlist_id: id(&playlist_id)?,
                    edit: vault_core::PlaylistEdit {
                        title,
                        artwork,
                        clear_artwork,
                        expected_order: expected_revision.parse().map_err(|_| invalid())?,
                    },
                },
                &operation.token,
            )
            .await?,
    )
}
#[derive(Debug, Clone)]
pub struct PlaylistEntry {
    pub entry_id: String,
    pub position: u32,
    pub track: Track,
}
#[derive(Debug, Clone)]
pub struct PlaylistPage {
    pub id: String,
    pub title: String,
    pub revision: String,
    pub total: u64,
    pub offset: u32,
    pub items: Vec<PlaylistEntry>,
}
pub async fn playlist(
    session_id: String,
    playlist_id: String,
    query: String,
    offset: u32,
    limit: u32,
) -> Result<Option<PlaylistPage>, BridgeError> {
    if query.len() > 1024 || limit == 0 || limit > 500 {
        return Err(invalid());
    }
    match runtime()
        .await?
        .backend
        .query(
            id(&session_id)?,
            LocalQuery::PlaylistSearch {
                playlist_id: id(&playlist_id)?,
                query,
                offset,
                limit,
            },
        )
        .await?
    {
        LocalResponse::Playlist(p) => Ok(p.map(|p| PlaylistPage {
            id: p.playlist.playlist_id.to_string(),
            title: p.playlist.title,
            revision: p.playlist.updated_order.to_string(),
            total: p.total,
            offset: p.offset,
            items: p
                .items
                .into_iter()
                .map(|i| PlaylistEntry {
                    entry_id: i.entry.entry_id.to_string(),
                    position: i.position,
                    track: i.track.into(),
                })
                .collect(),
        })),
        _ => Err(ApiError::new(ErrorCode::Internal).into()),
    }
}
#[derive(Debug, Clone)]
pub struct TrackPage {
    pub total: u64,
    pub offset: u32,
    pub tracks: Vec<Track>,
}
pub async fn favorites(
    session_id: String,
    set_name: String,
    offset: u32,
    limit: u32,
) -> Result<TrackPage, BridgeError> {
    if limit == 0 || limit > 500 {
        return Err(invalid());
    }
    match runtime()
        .await?
        .backend
        .query(
            id(&session_id)?,
            LocalQuery::Favorites {
                set_name,
                offset,
                limit,
            },
        )
        .await?
    {
        LocalResponse::Favorites(p) => Ok(TrackPage {
            total: p.total,
            offset: p.offset,
            tracks: p.tracks.into_iter().map(Into::into).collect(),
        }),
        _ => Err(ApiError::new(ErrorCode::Internal).into()),
    }
}
