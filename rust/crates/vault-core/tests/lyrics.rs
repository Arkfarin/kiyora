//! Offline recovery is opt-in and must not resurrect logically removed lyrics.
#![allow(clippy::unwrap_used)]
use tokio_util::sync::CancellationToken;
use uuid::Uuid;
use vault_core::{Backend, ErrorCode};
use vault_db::{Binding, Database};
use vault_domain::{Action, ChatId, Event, MessageId, Source, UserId};
use vault_protocol::{Record, VaultInit};
use vault_security::ProfileStore;

#[tokio::test]
async fn embedded_lyrics_recovery_reads_cached_audio_without_mutating_the_library() {
    let root = tempfile::tempdir().unwrap();
    let data = root.path().join("data");
    let backend = Backend::new(
        ProfileStore::at(&data).unwrap(),
        root.path().join("no-tdjson"),
    );
    let profile = backend.create_profile("Lyrics test".into()).unwrap();
    backend.switch_profile(profile.profile_id).await.unwrap();
    backend.shutdown().await.unwrap();
    let binding = Binding {
        vault_id: Uuid::new_v4(),
        owner_id: UserId::new(42).unwrap(),
        chat_id: ChatId::new(-100).unwrap(),
    };
    let directory = data.join("profiles").join(profile.profile_id.to_string());
    let config_path = directory.join("backend.json");
    let mut config: serde_json::Value =
        serde_json::from_slice(&std::fs::read(&config_path).unwrap()).unwrap();
    config["binding"] = serde_json::to_value(binding).unwrap();
    std::fs::write(config_path, serde_json::to_vec(&config).unwrap()).unwrap();
    let path = root.path().join("lyrics.mp3");
    std::fs::copy("../../spec/test-vectors/audio/tone.mp3", &path).unwrap();
    let lyrics = vault_media::parse_lyrics("Старая строка\nAnother line", "plain").unwrap();
    let metadata = vault_media::inspect(&path).unwrap().metadata;
    vault_media::write_tags(&path, &metadata, None, Some(&lyrics)).unwrap();
    let audio = vault_media::inspect(&path).unwrap();
    let track_id = Uuid::new_v4();
    let source_id = Uuid::new_v4();
    let mut database = Database::open(directory.join("vault.sqlite"), binding).unwrap();
    database
        .apply_record(
            MessageId::new(1).unwrap(),
            &Record::Init(VaultInit {
                vault_id: binding.vault_id,
                owner_telegram_user_id: binding.owner_id,
                created_by: "test".into(),
                created_at_utc: "2026-11-27T00:00:00Z".into(),
            }),
        )
        .unwrap();
    database
        .apply_record(
            MessageId::new(20).unwrap(),
            &Record::Event(Box::new(Event {
                vault_id: binding.vault_id,
                op_id: Uuid::new_v4(),
                device_id: "test".into(),
                base_generation: 0,
                entity_id: track_id,
                action: Action::TrackRegister {
                    metadata: audio.metadata.clone(),
                    source: Source {
                        source_id,
                        chat_id: binding.chat_id,
                        message_id: MessageId::new(10).unwrap(),
                        sha256: Some(audio.sha256.clone()),
                        size_bytes: Some(audio.size_bytes),
                    },
                },
            })),
        )
        .unwrap();
    database.checkpoint().unwrap();
    drop(database);
    let cache = vault_media::CacheManager::open(directory.join("cache"), 10_000_000).unwrap();
    cache
        .insert(
            format!("{track_id}:{source_id}"),
            &path,
            &audio.sha256,
            false,
        )
        .unwrap();
    drop(cache);
    let session = backend
        .switch_profile(profile.profile_id)
        .await
        .unwrap()
        .context
        .session_id;
    let token = CancellationToken::new();
    let before = backend
        .local_reader(session)
        .await
        .unwrap()
        .state()
        .await
        .unwrap();
    assert!(
        backend
            .lyrics(session, track_id, &token)
            .await
            .unwrap()
            .is_none()
    );
    assert_eq!(
        backend
            .embedded_lyrics(session, track_id, &token)
            .await
            .unwrap(),
        Some(lyrics)
    );
    assert!(
        backend
            .lyrics(session, track_id, &token)
            .await
            .unwrap()
            .is_none()
    );
    let after = backend
        .local_reader(session)
        .await
        .unwrap()
        .state()
        .await
        .unwrap();
    assert_eq!(
        before, after,
        "reading audio must not change metadata or sync state"
    );
    token.cancel();
    assert_eq!(
        backend
            .embedded_lyrics(session, track_id, &token)
            .await
            .unwrap_err()
            .code,
        ErrorCode::Cancelled
    );
    backend.shutdown().await.unwrap();
}
