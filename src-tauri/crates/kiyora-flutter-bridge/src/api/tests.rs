use super::*;
use std::time::Duration;
use tokio::time::timeout;
use vault_security::ProfileStore;

// One process-global lifecycle test: never point the bridge at a personal data
// directory or require Telegram credentials/native TDLib for these assertions.
#[tokio::test]
async fn lifecycle_cancels_before_draining_calls_and_preserves_profiles() {
    let directory = tempfile::tempdir().unwrap();
    let backend = Arc::new(Backend::new(
        ProfileStore::at(directory.path()).unwrap(),
        directory.path().join("not-loaded-tdjson.so"),
    ));
    *RUNTIME.write().await = Some(Runtime {
        backend: backend.clone(),
        closed: CancellationToken::new(),
    });
    let profile = create_profile("Linux test".into()).await.unwrap();
    let first = switch_profile(profile.id.clone()).await.unwrap();
    let restored = initialize(None, None).await.unwrap().unwrap();
    assert_eq!(first.session_id, restored.session_id);
    let feed = Arc::new(subscribe().await.unwrap());
    let waiting_feed = feed.clone();
    let waiter = tokio::spawn(async move { waiting_feed.next().await });

    // A long operation holds exactly this guard in the generated API. Shutdown
    // must signal cancellation without first obtaining an exclusive guard.
    let in_flight = runtime().await.unwrap();
    let attached = timeout(Duration::from_secs(2), initialize(None, None))
        .await
        .expect("reattachment must not wait for API readers")
        .unwrap()
        .unwrap();
    assert_eq!(attached.session_id, first.session_id);
    let stopping = tokio::spawn(shutdown());
    timeout(Duration::from_secs(2), in_flight.closed.cancelled())
        .await
        .expect("shutdown blocked before cancelling in-flight work");
    assert!(
        timeout(Duration::from_secs(2), waiter)
            .await
            .unwrap()
            .unwrap()
            .is_none()
    );
    drop(in_flight);
    timeout(Duration::from_secs(2), stopping)
        .await
        .unwrap()
        .unwrap()
        .unwrap();
    assert!(backend.context().await.is_none());
    assert!(matches!(profiles().await, Err(e) if e.code == "Closed"));
    shutdown().await.unwrap();

    // The session lease must be released, while the same durable profile and
    // active-profile marker remain restorable by a newly constructed backend.
    let reopened = Backend::new(
        ProfileStore::at(directory.path()).unwrap(),
        directory.path().join("not-loaded-tdjson.so"),
    );
    let restored = reopened.restore_active_profile().await.unwrap().unwrap();
    assert_eq!(restored.context.profile_id.to_string(), profile.id);
    assert_ne!(restored.context.session_id.to_string(), first.session_id);
    reopened.shutdown().await.unwrap();
}

#[tokio::test]
async fn closing_an_event_feed_wakes_a_pending_receive() {
    let bus = vault_core::EventBus::default();
    let feed = Arc::new(EventFeed {
        subscription: Mutex::new(bus.subscribe_reliable()),
        closed: CancellationToken::new(),
        runtime_closed: CancellationToken::new(),
    });
    let pending = feed.clone();
    let waiter = tokio::spawn(async move { pending.next().await });
    feed.close();
    assert!(
        timeout(Duration::from_secs(2), waiter)
            .await
            .unwrap()
            .unwrap()
            .is_none()
    );
}
