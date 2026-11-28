use super::{BridgeError, auth::Operation, id, invalid, runtime};
use vault_core::{ApiError, ErrorCode, LocalQuery, LocalResponse};

pub async fn catalog_tracks(
    session_id: String,
    album: Option<String>,
    artist: String,
    offset: u32,
    limit: u32,
) -> Result<Vec<super::Track>, BridgeError> {
    page(&artist, limit)?;
    if album.as_ref().is_some_and(|v| v.len() > 1024) {
        return Err(invalid());
    }
    Ok(runtime()
        .await?
        .backend
        .local_reader(id(&session_id)?)
        .await?
        .catalog_tracks(album, artist, offset, limit)
        .await
        .map_err(ApiError::from)?
        .into_iter()
        .map(Into::into)
        .collect())
}

pub async fn play_playlist(
    session_id: String,
    playlist_id: String,
    position: u32,
) -> Result<super::Queue, BridgeError> {
    Ok(runtime()
        .await?
        .backend
        .queue_playlist(id(&session_id)?, id(&playlist_id)?, position, true)
        .await?
        .into())
}

/// Device-local, real completed listens; no generated recommendations.
pub async fn recently_played(
    session_id: String,
    limit: u32,
) -> Result<Vec<super::Track>, BridgeError> {
    page("", limit)?;
    let runtime = runtime().await?;
    let reader = runtime.backend.local_reader(id(&session_id)?).await?;
    let history = reader.listening_history().await.map_err(ApiError::from)?;
    let mut tracks = Vec::new();
    for entry in history {
        if let Some(track) = reader.track(entry.track_id).await.map_err(ApiError::from)? {
            tracks.push(track.into());
            if tracks.len() >= limit as usize {
                break;
            }
        }
    }
    Ok(tracks)
}

#[derive(Debug, Clone)]
pub struct Artwork {
    pub mime_type: String,
    pub digest: String,
    pub bytes: Vec<u8>,
}
impl From<vault_core::ArtworkData> for Artwork {
    fn from(a: vault_core::ArtworkData) -> Self {
        Self {
            mime_type: a.mime_type,
            digest: a.sha256,
            bytes: a.bytes,
        }
    }
}
pub async fn artwork(
    session_id: String,
    track_id: String,
    operation: &Operation,
) -> Result<Option<Artwork>, BridgeError> {
    Ok(runtime()
        .await?
        .backend
        .artwork(id(&session_id)?, id(&track_id)?, &operation.token)
        .await?
        .map(Into::into))
}
pub async fn playlist_artwork(
    session_id: String,
    playlist_id: String,
    operation: &Operation,
) -> Result<Option<Artwork>, BridgeError> {
    Ok(runtime()
        .await?
        .backend
        .playlist_artwork(id(&session_id)?, id(&playlist_id)?, &operation.token)
        .await?
        .map(Into::into))
}
#[derive(Debug, Clone)]
pub struct LyricLine {
    pub start_ms: Option<u64>,
    pub end_ms: Option<u64>,
    pub text: String,
}
#[derive(Debug, Clone)]
pub struct Lyrics {
    pub language: Option<String>,
    pub lines: Vec<LyricLine>,
}
impl From<vault_domain::LyricsDocument> for Lyrics {
    fn from(d: vault_domain::LyricsDocument) -> Self {
        Self {
            language: d.language,
            lines: d
                .lines
                .into_iter()
                .map(|l| LyricLine {
                    start_ms: l.start_ms,
                    end_ms: l.end_ms,
                    text: l.text,
                })
                .collect(),
        }
    }
}
/// Explicitly inspect the original audio's tags without changing library metadata.
pub async fn embedded_lyrics(
    session_id: String,
    track_id: String,
    operation: &Operation,
) -> Result<Option<Lyrics>, BridgeError> {
    Ok(runtime()
        .await?
        .backend
        .embedded_lyrics(id(&session_id)?, id(&track_id)?, &operation.token)
        .await?
        .map(Into::into))
}

pub async fn lyrics(
    session_id: String,
    track_id: String,
    operation: &Operation,
) -> Result<Option<Lyrics>, BridgeError> {
    Ok(runtime()
        .await?
        .backend
        .lyrics(id(&session_id)?, id(&track_id)?, &operation.token)
        .await?
        .map(Into::into))
}
/// Validate and normalize a local cover before freezing an import request.
/// This uses the same bounded decoder as metadata commits, without uploading.
///
/// # Errors
/// Returns InvalidInput for corrupt, unsupported or oversized artwork.
pub fn prepare_artwork(bytes: Vec<u8>) -> Result<Artwork, BridgeError> {
    let artwork = vault_media::artwork(&bytes, None).map_err(ApiError::from)?;
    Ok(Artwork {
        mime_type: artwork.mime_type,
        digest: artwork.sha256,
        bytes: artwork.bytes,
    })
}

/// Existing parser retains LRC/SRT/WebVTT timestamps and leaves plain text untimed.
pub fn parse_lyrics(text: String, format: String) -> Result<Lyrics, BridgeError> {
    Ok(vault_media::parse_lyrics(&text, &format)
        .map_err(ApiError::from)?
        .into())
}
#[derive(Debug, Clone)]
pub struct Album {
    pub title: String,
    pub artist: String,
    pub track_count: u64,
}
#[derive(Debug, Clone)]
pub struct Artist {
    pub name: String,
    pub track_count: u64,
}
fn page(query: &str, limit: u32) -> Result<(), BridgeError> {
    if query.len() > 1024 || limit == 0 || limit > 500 {
        return Err(invalid());
    }
    Ok(())
}
pub async fn albums(
    session_id: String,
    query: String,
    offset: u32,
    limit: u32,
) -> Result<Vec<Album>, BridgeError> {
    page(&query, limit)?;
    match runtime()
        .await?
        .backend
        .query(
            id(&session_id)?,
            LocalQuery::Albums {
                query,
                offset,
                limit,
            },
        )
        .await?
    {
        LocalResponse::Albums(items) => Ok(items
            .into_iter()
            .map(|a| Album {
                title: a.title,
                artist: a.artist,
                track_count: a.track_count,
            })
            .collect()),
        _ => Err(ApiError::new(ErrorCode::Internal).into()),
    }
}
pub async fn artists(
    session_id: String,
    query: String,
    offset: u32,
    limit: u32,
) -> Result<Vec<Artist>, BridgeError> {
    page(&query, limit)?;
    match runtime()
        .await?
        .backend
        .query(
            id(&session_id)?,
            LocalQuery::Artists {
                query,
                offset,
                limit,
            },
        )
        .await?
    {
        LocalResponse::Artists(items) => Ok(items
            .into_iter()
            .map(|a| Artist {
                name: a.name,
                track_count: a.track_count,
            })
            .collect()),
        _ => Err(ApiError::new(ErrorCode::Internal).into()),
    }
}
#[derive(Debug, Clone)]
pub struct Playlist {
    pub id: String,
    pub title: String,
    pub revision: String,
    pub artwork_digest: Option<String>,
}
pub async fn playlists(
    session_id: String,
    query: Option<String>,
    offset: u32,
    limit: u32,
) -> Result<Vec<Playlist>, BridgeError> {
    page(query.as_deref().unwrap_or_default(), limit)?;
    Ok(runtime()
        .await?
        .backend
        .local_reader(id(&session_id)?)
        .await?
        .playlists(query, offset, limit)
        .await
        .map_err(ApiError::from)?
        .into_iter()
        .map(|p| Playlist {
            id: p.playlist_id.to_string(),
            title: p.title,
            revision: p.updated_order.to_string(),
            artwork_digest: p.artwork.map(|a| a.sha256),
        })
        .collect())
}

#[derive(Debug, Clone)]
pub struct Metadata {
    pub title: String,
    pub artist: String,
    pub album: String,
    pub album_artist: String,
    pub duration_ms: u64,
    pub year: u32,
    pub genre: String,
    pub track_number: u32,
    pub disc_number: u32,
    pub bitrate: u32,
    pub codec: String,
    pub composer: String,
    pub comment: String,
    pub copyright: String,
    pub artwork_digest: Option<String>,
    pub lyrics_digest: Option<String>,
}
impl From<vault_domain::Metadata> for Metadata {
    fn from(m: vault_domain::Metadata) -> Self {
        Self {
            title: m.title,
            artist: m.performer,
            album: m.album,
            album_artist: m.album_artist,
            duration_ms: m.duration_ms,
            year: m.year,
            genre: m.genre,
            track_number: m.track_number,
            disc_number: m.disc_number,
            bitrate: m.bitrate,
            codec: m.codec,
            composer: m.composer,
            comment: m.comment,
            copyright: m.copyright,
            artwork_digest: m.artwork.map(|a| a.sha256),
            lyrics_digest: m.lyrics.map(|l| l.sha256),
        }
    }
}
#[derive(Debug, Clone)]
pub struct Source {
    pub id: String,
    pub digest: Option<String>,
    pub size_bytes: Option<u64>,
}
#[derive(Debug, Clone)]
pub struct TrackDetail {
    pub id: String,
    pub revision: String,
    pub metadata: Metadata,
    pub preferred_source_id: Option<String>,
    pub sources: Vec<Source>,
}
pub async fn track(
    session_id: String,
    track_id: String,
) -> Result<Option<TrackDetail>, BridgeError> {
    Ok(runtime()
        .await?
        .backend
        .local_reader(id(&session_id)?)
        .await?
        .track(id(&track_id)?)
        .await
        .map_err(ApiError::from)?
        .map(|t| TrackDetail {
            id: t.track_id.to_string(),
            revision: t.updated_order.to_string(),
            metadata: t.metadata.into(),
            preferred_source_id: t.preferred_source_id.map(|v| v.to_string()),
            sources: t
                .sources
                .into_values()
                .map(|s| Source {
                    id: s.source_id.to_string(),
                    digest: s.sha256,
                    size_bytes: s.size_bytes,
                })
                .collect(),
        }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn artwork_preflight_rejects_corrupt_and_oversized_input_without_a_session() {
        for bytes in [
            Vec::new(),
            b"not an image".to_vec(),
            vec![0; 8 * 1024 * 1024 + 1],
        ] {
            assert_eq!(prepare_artwork(bytes).unwrap_err().code, "InvalidInput");
        }
    }
}
