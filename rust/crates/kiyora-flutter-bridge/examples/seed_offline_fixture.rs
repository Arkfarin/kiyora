//! Test-only offline library for the Dart/FRB playback acceptance runner.
//! Refuses to write outside a runner-created disposable directory.
use std::{error::Error, path::PathBuf};
use uuid::Uuid;
use vault_core::Backend;
use vault_db::{Binding, Database};
use vault_domain::{Action, ChatId, Event, MessageId, Metadata, Source, UserId};
use vault_protocol::{Record, VaultInit};
use vault_security::ProfileStore;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let root = PathBuf::from(std::env::var("KIYORA_NATIVE_TEST_ROOT")?).canonicalize()?;
    let data = PathBuf::from(std::env::var("KIYORA_DATA_DIR")?).canonicalize()?;
    if data != root.join("data") || !root.join("isolated-native-test").is_file() {
        return Err("run only through flutter/tool/test_playback.py".into());
    }
    let store = ProfileStore::at(&data)?;
    if !store.list()?.is_empty() {
        return Err("fixture requires an empty disposable profile store".into());
    }
    let backend = Backend::new(store, root.join("unused-tdjson.so"));
    let profile = backend.create_profile("Offline playback fixture".into())?;
    backend.switch_profile(profile.profile_id).await?;
    backend.shutdown().await?;
    let binding = Binding {
        vault_id: Uuid::new_v4(),
        owner_id: UserId::new(42)?,
        chat_id: ChatId::new(-100)?,
    };
    let directory = data.join("profiles").join(profile.profile_id.to_string());
    let config_path = directory.join("backend.json");
    let mut config: serde_json::Value = serde_json::from_slice(&std::fs::read(&config_path)?)?;
    config["binding"] = serde_json::to_value(binding)?;
    std::fs::write(config_path, serde_json::to_vec(&config)?)?;
    let mut database = Database::open(directory.join("vault.sqlite"), binding)?;
    database.apply_record(
        MessageId::new(1)?,
        &Record::Init(VaultInit {
            vault_id: binding.vault_id,
            owner_telegram_user_id: binding.owner_id,
            created_by: "native playback test".into(),
            created_at_utc: "2026-11-21T00:00:00Z".into(),
        }),
    )?;
    let audio = vault_media::inspect(&root.join("tone.wav"))?;
    let cache = vault_media::CacheManager::open(directory.join("cache"), 10_000_000)?;
    for (index, title) in ["Alpha", "Beta", "Unavailable"].into_iter().enumerate() {
        let track_id = Uuid::new_v4();
        let source_id = Uuid::new_v4();
        let source = Source {
            source_id,
            chat_id: binding.chat_id,
            message_id: MessageId::new(10 + i64::try_from(index)?)?,
            sha256: Some(audio.sha256.clone()),
            size_bytes: Some(audio.size_bytes),
        };
        database.apply_record(
            MessageId::new(20 + i64::try_from(index)?)?,
            &Record::Event(Box::new(Event {
                vault_id: binding.vault_id,
                op_id: Uuid::new_v4(),
                device_id: "native-playback-test".into(),
                base_generation: 0,
                entity_id: track_id,
                action: Action::TrackRegister {
                    metadata: Metadata {
                        title: title.into(),
                        performer: "KIYORA test fixture".into(),
                        album: "Offline acceptance".into(),
                        ..audio.metadata.clone()
                    },
                    source,
                },
            })),
        )?;
        if title != "Unavailable" {
            cache.insert(
                format!("{track_id}:{source_id}"),
                &audio.path,
                &audio.sha256,
                true,
            )?;
        }
    }
    database.validate()?;
    database.checkpoint()?;
    println!("seeded three offline fixture tracks, two cached");
    Ok(())
}
