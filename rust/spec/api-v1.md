# Kiyora backend API v1

The JSON application boundary is defined by `vault-core/src/ipc.rs`. Its request,
response/error and event schemas live in `spec/schema/`. Regenerate them with
`cargo run -p vault-core --example generate-api-schema`; `scripts/check-backend.sh`
verifies the checked-in schemas. The CLI exposes this boundary through `serve`.
See [the API reference](../docs/api.md) for envelopes and operation semantics.

Flutter uses the typed native API in `kiyora-flutter-bridge/src/api/` and generated
Dart bindings in `flutter/lib/core/bridge/generated/` (relative to the repository).
Regenerate the bridge with `flutter/tool/generate.sh` from the repository root.
Rust owns profiles, synchronization, durable mutations, playback and the queue.

Session-scoped calls carry the current session ID. Profile switching invalidates
old IDs. Consumers discard events from old sessions and recover a dropped feed
through a fresh subscription and state refresh. Mutations with uncertain outcomes
retain their operation ID; they must not be blindly replayed with a new ID.
Telegram IDs stay decimal strings at JSON boundaries to preserve precision.

`EDIT_NOT_SENT` is a definite preflight rejection before remote publication.
A generic conflict, network error, timeout or missing response does not establish
that an edit was not sent. Unknown outcomes retain the exact original payload.

The CLI shares the same services and persistent storage. Interactive playback
controls belong to the process that owns the audio engine; a second CLI process
cannot control that engine. See [CLI authentication](../docs/cli-auth.md) and
[acceptance scenarios](../docs/e2e.md).
