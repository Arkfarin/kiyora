> Historical notes: superseded for the current Linux-first task by
> [Linux migration](FLUTTER_LINUX_MIGRATION.md),
> [testing](FLUTTER_LINUX_TESTING.md), [release](FLUTTER_LINUX_RELEASE.md),
> and [UI acceptance](FLUTTER_LINUX_UI_ACCEPTANCE.md).
> Earlier no-testing and concurrent-platform plans below are no longer current.

# Flutter release readiness — NOT READY

The Rust adapter and shared desktop media library compile on Linux. Binding
configuration exists; Dart bindings and UI are still absent. Flutter is
not yet the primary frontend. React/Tauri remains the working client.

| Requirement | Current evidence |
| --- | --- |
| Direct FRB | Version-pinned crate/config; generated bindings pending |
| Rust backend retained | Calls delegate to existing Backend; no replacement engine |
| Authentication/playback/queue | Adapter source exists; runtime unverified |
| Vault/lyrics/artwork/catalog | Typed adapter calls exist; runtime/UI pending |
| Playlist mutations/metadata | Typed revision-aware adapter compiles; UI/runtime pending |
| Import/export/recovery | Durable job adapter compiles; import-review editor and UI pending |
| Windows/Linux/Android builds | No Flutter build artifacts |
| Native TDLib/dependencies/licenses | Existing Tauri preparation only |
| Signing/update compatibility | Not established for Flutter |
| Desktop media | Shared MPRIS/SMTC extracted; Linux bridge compiled; window wiring/runtime pending |
| Android service | Existing Tauri adapter; Flutter rehosting pending |
| Data compatibility | Same desktop storage constructor; upgrade not exercised |
| Tests/devices/visual acceptance | Not run by explicit user request |

No installation, audible output, Telegram login, Bluetooth, notification,
background playback, screen rendering, packaging or release claim is justified.
No releases published, installers replaced or private signing material created.

Next: finish SDK/code generation and vertical integration, complete all requested
features, platform adapters and packaging. Account/device verification remains
unperformed under the no-testing instruction; do not silently turn historical
Tauri results into Flutter acceptance evidence.

Linux source build completed with `cargo build --locked -p kiyora-flutter-bridge`
(from `src-tauri`). This library has no generated FFI entrypoints yet and is not
an installable Flutter artifact. No test commands were run.
