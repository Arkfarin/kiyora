# KIYORA Flutter migration — in progress

## Architecture and current source audit

The existing client is React → Tauri commands → `vault_core::Backend`.
The target is Flutter presentation → Dart repositories → generated FRB v2 →
`kiyora-flutter-bridge` → the same Backend. No Dart audio engine or queue.

- `vault-core`: profile/session lifecycle, authorization orchestration, queries,
  mutation guards, jobs, imports, playback queue, reliable event bus.
- `vault-security`: profile leases and OS secrets. Desktop data root is
  `ProjectDirs("io.github", "arkfarin", "kiyora")`, with `KIYORA_DATA_DIR` override.
- `vault-telegram`: pinned TDLib adapter and native library resolution.
- `vault-domain` / `vault-protocol`: reducer and event/storage contracts.
- `vault-db`: SQLite projection, migrations, paginated readers.
- `vault-sync` / `vault-snapshot`: reconciliation, recovery, snapshots and GC.
- `vault-media`: Rust PCM/audio output and `PlaybackPlatform` abstraction.
- `kiyora-desktop-media`: shared MPRIS/SMTC implementation with a UI host trait.
  Tauri now supplies window access through a thin wrapper. Flutter bridge installs
  this same implementation; Windows initialization needs the runner HWND.
- `tauri-plugin-kiyora-native`: Android secrets/documents/media service still needs
  rehosting. Desktop transport now delegates to the shared crate.
- `src-tauri/src/lib.rs`: existing Tauri wiring, event forwarding and shutdown;
  retained until functional parity is established.

Historical backend evidence is in BACKEND_READINESS.md. It is not evidence that
Flutter works. Existing CI packages Tauri, not Flutter.

## Implemented source boundary

`src-tauri/crates/kiyora-flutter-bridge` has no Tauri dependency. FRB is pinned to
2.13.0 on both sides. Public DTOs cover profiles, session IDs, authorization,
playback, revision-fenced queue edits, paginated library/search and event notices.
Additional typed APIs expose Vault discovery/create/attach/resume/sync, session
recovery details, artwork/playlist artwork, lyrics/parser, albums, artists and
playlist listings. Long requests accept the same explicit Operation token.
`api/edits.rs` adds playlist create/rename/delete/cover/entry edits, favorites,
track deletion and metadata editing with CAS revisions and durable operation IDs.
Command results retain Applied/Rejected/Unknown and the server message ID.
Paginated playlist details preserve entry IDs and absolute positions.
`api/jobs.rs` adds bulk imports, backup exports, database repair/recovery and
job list/status/cancel/resume/forget. File results distinguish confirmed commands,
duplicate review and errors; a finished job alone is not proof of imported audio.
Import review/edit-before-upload and full metadata read DTOs remain pending.
Errors preserve the sanitized backend message, code and retry metadata.
Authorization inputs avoid Debug and enter the backend's Zeroizing types.

A process-wide async RwLock owns one Backend. Initialization/shutdown are
exclusive; calls keep a read lease so shutdown cannot race an in-flight command.
Repeated attachment returns the current context without rebuilding playback.
An opaque EventFeed wraps the bounded reliable subscription; loss is surfaced
explicitly. Closing the feed or shutting down wakes pending receivers.
Playback/queue/job/runtime/library/playlist/command/warning events have dedicated
DTOs. Auth events invalidate the latest status to avoid replaying old QR secrets.
Other events still invalidate views. `projection_marker` uses the real backend
snapshot/context/watermark while keeping the full collection out of Dart.
Dart still needs subscribe-before-snapshot, visible-page reload and stale-session
filtering; the Rust endpoint alone does not complete event recovery.
An opaque Operation allows explicit cancellation of authentication.

## Data compatibility

Desktop initialization delegates to the same ProfileStore and native resolver.
No protocol, schema, profile, session, key, music or cache files are migrated or
deleted. The old client must be closed before acquiring the same profile lease.
Android initialization intentionally returns NativeUnavailable until the existing
secure storage and media adapters are connected. Falling back to desktop key
storage on Android would be unsafe. No APK update compatibility is claimed.
Retain the existing Android application ID and signing identity; inspect the
actual old app-private paths before implementing the new runner.

## Generation and build work

The initial `flutter/pubspec.yaml` and `flutter_rust_bridge.yaml` describe the
binding boundary. Run `bash flutter/tool/generate.sh` with Flutter on PATH.
This is a generation command, not a test command. Generated code and native
platform runners have not yet been produced; the application is not runnable.
Do not treat the manifest as a finished Flutter project.

Windows: shared SMTC adapter extracted; runner HWND/raise wiring, DLL/TDLib
bundling and MSI/MSIX pending. Linux: shared MPRIS adapter installed in bridge;
runner/raise wiring, native .so/TDLib bundle and packages pending.
Android: runner, Kotlin service/secrets/document adapters, Rust ABI builds and
APK/AAB packaging pending. Reuse pinned native sources and license preparation
from `src-tauri/docs/packaging.md`, but do not run its Tauri installers as Flutter.

## Remaining implementation, preserving the full request

1. Finish SDK/codegen setup, generate bindings, lock dependencies and create
   Android/Linux/Windows runners. Connect real Flutter repositories and lifecycle.
2. Complete typed APIs for import review/edited upload, metadata detail reads,
   download/cache management, history and advanced maintenance; connect existing
   Vault, playlists, metadata, artwork, lyrics, favorites, jobs/export/recovery APIs
   to the Flutter repositories and screens.
3. Finish desktop window wiring and rehost Android secrets, document picker,
   media service, focus, route changes and lifecycle without adding another player.
4. Flutter desktop composition: top navigation, resizable library/context panels,
   independent content scroll and bottom player. Mobile: three destinations,
   mini-player and interactive fullscreen player. Preserve every management flow.
5. Home/search/library/detail pages, queue reorder, synced lyrics, gestures,
   context menus, native pickers, import review/progress/retry/cancel, settings.
6. Theme/localization/accessibility/reduced motion, bounded lists and progress
   updates isolated from the rest of the widget tree.
7. Reproducible per-platform native packaging, licenses, signing integration,
   CI artifacts and installer compatibility. No publishing without permission.
8. Update acceptance evidence honestly. User explicitly requested no testing:
   do not run tests, device/browser checks or simulated acceptance automatically.

## Build evidence and active tools (2026-11-11)

`cargo build --locked --manifest-path src-tauri/Cargo.toml -p kiyora-flutter-bridge`
produced the Linux native library with shared desktop media, Vault/auth/content
APIs. This is source compilation/linking, not a test or runtime result. FFI exports
still require generation. No tests or application/device sessions were run.
Cargo.lock adds FRB and the shared media crate, preserving existing versions.

FRB generator 2.13.0 installed at `$HOME/.cargo/bin/flutter_rust_bridge_codegen`.
Generation could not proceed without Flutter/Dart even with formatting disabled.
The initial git clone terminated with HTTP/2 disconnect/early EOF (session 5368).
Official source archive download is now active in exec session 18543, destination
`/tmp/kiyora-flutter-stable.tar.gz`. Poll this handle before retrying. After download,
provision a proper SDK (including git metadata as Flutter requires), pin its actual
revision/version, then generate bindings and platform runners. The archive source
is the Flutter repository's stable branch; it is not yet a reproducible SDK pin.

Latest increment also compiled the playlist/metadata mutation, durable-job and
projection-marker adapters on Linux. SDK archive session 18543 remains active;
no generated Dart, Flutter runner or UI has been added yet. No tests were run.
