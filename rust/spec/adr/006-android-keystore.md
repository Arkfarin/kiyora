# ADR 006: Android Keystore and the private native bridge

Status: accepted.

## Decision

`Backend::with_secrets` receives a thread-safe `SecretStore`; the desktop default
retains OS keyring storage. The Flutter Android host injects `AndroidSecrets` from
`kiyora-android-runtime`. Secret operations run on blocking
Rust workers. The session lock remains held while keys/configuration are persisted,
so a profile switch cannot interleave with native session startup.

The Android adapter uses AndroidKeyStore AES-256-GCM keys, one alias per profile
and secret purpose. Only canonical non-nil profile UUIDs with `tdlib-key` or
`api-hash` suffixes and 32-byte values are accepted. Each ciphertext record has a
version byte, fresh provider-generated 96-bit nonce, ciphertext and 128-bit tag.
AAD binds the record to its version, profile UUID and purpose. Keystore keys are
not exported. Hardware backing depends on the Android device; it is not claimed
by the application or by emulator tests.

Ciphertext lives in the app's `noBackupFilesDir`, separately from the per-profile
TDLib/SQLite/cache tree, which also lives under `noBackupFilesDir`. Automatic
Android backup therefore cannot transplant a session without its Keystore keys.
Explicit portable backups continue to contain only the approved library/media
data. No plaintext fallback or implicit key reset exists.

Writes use Android `AtomicFile`, then read back and authenticate the result before
acknowledging success. An existing record must decrypt before replacement. Missing
Keystore keys, invalidated keys, corrupt ciphertext, unsupported versions, oversized
records and filesystem failures return a structured secure-storage error. Rust
also checks read-back persistence before allowing TDLib to create its database.
The framework-owned base directory is canonicalized before appending our private
directory names, allowing Android's `/data/user/0` alias. Our own directories,
records and AtomicFile sibling paths still reject symlinks.

## Bridge boundary

The application installs the JNI adapter before Flutter starts. The Rust runtime
calls `FlutterNativeBridge`; the OS adapters live in the Flutter Android source
tree. Secrets are not exposed through the Dart feature API.

Native operations are serialized on one executor with a 16-request queue. Rust
waits at most 15 seconds. Timeout is an error; an already queued atomic write may
still finish. A retry authenticates/read-backs the durable state. No command logs
arguments, returned secrets, or exception text. Owned Rust buffers and native
byte arrays are wiped after use; temporary JSON/JNI/JVM copies cannot be guaranteed
to disappear immediately and are not described as zero-copy secure memory.

## Verification scope

The existing OS adapters were moved unchanged into the Flutter source tree.
This relocation does not establish Android runtime acceptance. Keystore,
process lifecycle and physical-device behavior require separate verification.
The Android CLI without the native provider fails closed.
