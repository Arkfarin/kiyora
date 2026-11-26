# KIYORA Linux migration

Status on 2026-11-21: implemented Flutter client under stabilization; **not a
stable release**. Linux x86_64 is the sole active target. Earlier cross-platform
plans in the historical migration notes are superseded by this scope.

## Architecture

```text
Flutter widgets / MusicNavigation
  -> BackendController, bounded PagedQuery, typed feature API calls
  -> generated flutter_rust_bridge 2.13.0 bindings
  -> kiyora-flutter-bridge (native library)
  -> vault-core::Backend
     -> vault-telegram / TDLib
     -> vault-sync, vault-snapshot, vault-db / SQLite
     -> vault-domain, vault-protocol, vault-security
     -> vault-media / Rust playback and queue
     -> kiyora-desktop-media / Linux MPRIS
```

`flutter/lib/main.dart` owns application startup and shutdown. The process-owned
controller is passed to widgets; navigation does not construct a second backend.
ChangeNotifier describes coarse state; ValueNotifiers isolate playback, queue,
current-track and collection invalidations. Rust remains authoritative for
queue revisions, playback, jobs and durable mutations. Dart holds UI history and
projections, not another audio engine or Telegram client.

The native boundary is `rust/crates/kiyora-flutter-bridge/src/api/`:
`mod.rs` covers lifecycle/profiles/playback/queue/events; `auth`, `vault`,
`content`, `edits`, `imports`, `jobs`, and `offline` expose typed DTOs and errors.
Generated files are committed. `flutter/tool/generate.sh` pins FRB generator
2.13.0 and cargo-expand 1.0.127; reproducible regeneration still needs an explicit
verification run. Source configuration alone is not generation evidence.

## Lifecycle and event recovery

A Rust lifecycle mutex serializes initialize/shutdown. API calls retain runtime
read guards. Shutdown signals cancellation and shuts down the Backend before
waiting for those guards, so jobs can finish cancellation instead of deadlocking.
The active profile is restored by the existing ProfileStore.

Flutter subscribes before reading session/projection state. A refresh or overflow
replaces the feed and advances an epoch, fencing old responses and delayed retry
loops. The new subscription buffers events while snapshot reads complete. Events
at or before the snapshot watermark and events from another session are ignored.
Runtime mode is explicitly reloaded with the snapshot. Event recovery does not
cancel an active user operation. Failed reattachment uses five bounded retries;
manual refresh can supersede them. Mutating commands are not automatically replayed.

This is a projection of several typed reads, not a newly invented transactional
backend snapshot. Real account/event-load acceptance remains necessary. The
regression and native test evidence is in [testing](FLUTTER_LINUX_TESTING.md).

## Existing data and compatibility

Desktop initialization uses the same `ProfileStore` and native resolution as the
previous client. `KIYORA_DATA_DIR` explicitly selects a data root; without it the
existing platform data-location constructor is used. OS-protected secrets stay in
the existing keyring. This increment changes no schema, storage protocol, profile
IDs, Telegram sessions or cache layout. It does not delete or migrate user files.

Close other clients before opening the same profile. Flutter is the sole UI in
this repository. An existing-profile upgrade, offline cache compatibility
and interrupted-sync recovery must still be tested on backed-up representative
data before migration is accepted. Native tests only create disposable profiles.

## Linux host and current risks

The GTK runner sets the application ID, title, 1280×720 initial size and 720×540
minimum. A host channel handles window raise requests from the Rust media adapter.
CMake builds and installs the Rust library alongside Flutter's libraries. Native
file selection uses `file_selector`. MPRIS uses the shared Rust implementation;
no second player is introduced.

Current risks and next gates:

1. Real Telegram/Vault/import/playback and migration acceptance are unverified.
2. Core features exist in source but need scenario-by-scenario runtime checks.
3. Whole-project analysis now passes on Flutter 3.50.0 / Material UI 1.11.1;
   future SDK changes still require widget and native regression checks.
4. Desktop import drop handling, settings/window persistence, notifications and
   complete keyboard/accessibility behavior need implementation/coverage audits.
5. Actual large-library rendering/performance is not established by paging tests.
6. A release tar now passes extraction, native setup/recovery and Wayland/XWayland
   window smoke checks on CachyOS. Distribution baselines, clean installation,
   bridge-generation reproducibility and Linux-only CI remain open. No workflow
   currently exists.

Do not start Windows or Android work as a continuation of these gates.

## Import editor ownership

`ImportView` and `ImportEditor` use the session-owned `ImportSelection`. Rust owns
staged audio, prepared-import fingerprints, upload journals and command receipts.
The existing `ImportDraftStore` persists only the form and exact retry request,
scoped to profile and Vault. The UI invokes preview/list/discard/commit/resume and
command-status APIs; it does not create another backend staging store. Recovery
runs when opening Import and can be retried explicitly. A failed durable save
prevents submission. Ordinary unprepared file selections remain session-local.

Artwork preflight now exposes `content.prepareArtwork`, a thin local call to
`vault_media::artwork`. It validates/normalizes both newly selected covers and
unsubmitted restored drafts before freezing a request, without uploading or
changing the storage protocol. Frozen retries bypass preflight and retain the
original bytes. Recovery-file writes are serialized by path across store
instances so a rapidly reopened profile waits for the preceding session's save.
