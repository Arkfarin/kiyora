# Flutter Linux verification

Target: Linux x86_64. Windows and Android implementation and acceptance are
explicitly deferred. This document records current checks, not release approval.

## Environment and commands

2026-11-21: CachyOS Linux x86_64, locally installed Flutter SDK 3.50.0,
flutter_rust_bridge 2.13.0. Add the SDK's `bin` directory to `PATH`.

From `flutter/`:

```sh
flutter test --no-pub
flutter analyze --no-pub
```

From `rust/`:

```sh
cargo test --locked -p kiyora-flutter-bridge
```

Real Dart → generated FRB → Rust, from the repository root:

```sh
python3 flutter/tool/test_native.py
```

This runner builds the locked Rust bridge, creates a temporary data directory,
uses a private `dbus-run-session`, and runs separate seed and restore processes.
It requires `flutter`, `cargo` and `dbus-run-session` on PATH. It deliberately
points TDLib at a nonexistent file: no authentication or network operations run.
The temporary profiles are removed by the runner after the checks.

## Current automated evidence

- Flutter unit/widget suite: 26 tests passed (2026-11-24).
- Controller tests use an explicitly isolated mock FRB API. They cover duplicate
  startup, failed startup/retry, failed profile switch, exit/start races, failed
  shutdown/retry, snapshot/runtime restoration, buffered playback events during
  refresh, stale event rejection, manual retry versus automatic reconnect,
  repeated event overflow, five-attempt retry limit, and preservation of an
  active operation during event resynchronization.
- Paging tests reach all 10,000 synthetic rows with at most 640 resident rows,
  reverse paging, generation fencing and retry. This is not a rendered large
  library performance measurement.
- Widget tests exercise initial Home/import rendering and desktop navigation and
  player layout at 720, 900, 1280 and 1440 logical pixels. They use test data,
  not a Telegram account.
- Whole-project `flutter analyze --no-pub` passes with no issues. Material UI
  is pinned to 1.11.1; the deprecated Material imports, reorder callback and
  profile radio callbacks have been migrated. Widget regressions cover actual
  drag gestures in both queue directions and keyboard profile selection with
  the busy guard. The Linux debug bundle was rebuilt successfully afterward.

- Native integration: both seed and process-restart restore passed. Real FRB
  calls verified single initialization, profile creation/switching, stale-session
  rejection, queue revision conflicts, queue events, refresh, cancellation-token
  calls, pending receive wakeup on close/shutdown, closed-runtime errors, and
  durable active-profile/Shuffle/Repeat restoration. There are no mock API calls
  in this suite. It does not start the audio device or connect Telegram.
- Rust bridge: 2 tests passed (feed cancellation and lifecycle/profile durability).

- Debug Linux bundle build passed. `ldd` resolved executable and Rust library
  dependencies. First-frame window and normal close (exit 0) passed on Umbriel
  native Wayland and X11 via XWayland with disposable data and working directory
  `/tmp`. See [release notes](FLUTTER_LINUX_RELEASE.md) for limits and bus teardown
  diagnostics. These were automated compositor-level smoke checks, not manual
  visual acceptance or an installed release.

## Acceptance still required

Actual Telegram authentication/Vault sync, audible playback,
queue mutations during playback, real data upgrade, offline/reconnect, MPRIS/media
keys, broader Wayland/X11 window behavior, clean installation and packaged launch need
separate evidence. Unit/widget tests do not prove these scenarios.

## Bundled application credentials and initial TDLib connection

On 2026-11-24, `python3 flutter/tool/test_build_config.py` passed: missing release
configuration, explicitly missing debug configuration, malformed JSON, invalid
credentials and public Unix permissions fail without disclosing configuration
contents. Unconfigured debug builds remain possible for offline development.
The supplied private configuration was confirmed present in the native library
and absent from tracked/new source files, including generated Dart.

Two onboarding widget regressions verify that users see no application credential
fields, that duplicate clicks are fenced, that phone and QR steps remain reachable,
and that an unconfigured build presents an error without asking users for API keys.
The Linux debug bundle and Rust bridge tests also passed.

`python3 flutter/tool/test_auth.py` passed against real TDLib on CachyOS. It checks
the real Dart → FRB → Rust `connect` call up to `PhoneRequired`, disconnects, then
checks reconnection using the profile's saved credentials. It requires Flutter,
Cargo, pinned TDLib, `dbus-run-session` and `gnome-keyring-daemon`. All profiles,
keyring data, config/cache/runtime directories and D-Bus connections are isolated;
the test never supplies a phone number, code, password or QR account approval.
TDLib may access the network. Reaching phone entry does not prove successful
account authentication or Telegram's acceptance of the application credentials.

The runner also passed three independent process phases: first connection,
restart with an unavailable Secret Service bus, and restart with the service
restored. The unavailable phase returns `SecureStorageUnavailable` without
discarding the saved profile or application configuration. The final process
restores the same active profile and reaches phone entry using its saved secrets.

GNOME Keyring is a provider used by this test harness, not a runtime dependency
of KIYORA. The application uses the Secret Service API. KWallet's Secret Service
provider is compatible with that interface; a live KWallet-specific acceptance
run has not yet been completed. No user secret-service selection was changed.

## Extracted release package

On 2026-11-24 the release tar built by `tool/package_desktop.py` passed
`tool/verify_linux_package.py ARCHIVE --window-smoke`. This checks archive and
TDLib hashes, required payload/licenses and host dependency resolution, then
uses the actual extracted release bridge and TDLib for all three authentication
process phases above. No native rebuild occurs during package verification.
The separate release executable showed its first-frame window and closed
normally on Umbriel Wayland and XWayland. The package ran outside the repository
from a path containing spaces. See the release document for artifact identity,
commands, glibc observations and unverified installation/compatibility limits.

## Native offline playback and MPRIS regression

`python3 flutter/tool/test_playback.py` passed on CachyOS with PipeWire 1.6.11's
PulseAudio server. It requires `pactl`, `parec`, `playerctl`, `dbus-run-session`,
Flutter and Cargo. It creates a private D-Bus, disposable library and dedicated
null sink, never changes the default output and removes its sink afterward.

Real generated FRB calls exercise cached playback/progress, Pause/Resume, paused
seek, MPRIS metadata/Play/Pause/Next/Previous, rapid toggles, reorder, removing the
current track, recovery after an unavailable source, refresh and shutdown. The
monitor captured 458,752 PCM samples, including 28,602 nontrivial signal samples
in the recorded passing run. This establishes decoded PCM output to the virtual
sink, not listening through physical speakers. Telegram is never contacted.

This test reproduced a >10-second stall in souvlaki's D-Bus detach behind queued
status updates. The local dependency patch is documented in
`rust/vendor/souvlaki/KIYORA-PATCH.md`. With the bounded dispatcher and
prioritized shutdown the scenario passed in about two seconds.

## Import editor increment (2026-11-26)

At the first editor UI checkpoint, `CI=true flutter test --no-pub` passed all
51 tests and `CI=true flutter analyze --no-pub` reported no issues. The import
subset passed 22 tests, including exact retry payloads, restart restoration,
failed saves, invalid lyrics, navigation, duplicate confirmation reply loss and
widget interactions at 400/720/1280 content widths.

`cargo test --locked -p vault-core --test service
preview_original_upload_and_logical_edit_roundtrip_through_snapshot` also
passed (1 test). This uses real Rust service/storage/media code with a test
Telegram transport. It does not prove an actual Telegram upload or file-picker
interaction. The historical platform checks above were not rerun by this step.

### Import recovery and attachment validation checkpoint

The final Flutter unit/widget suite passed **55 tests**; analysis reported no
issues. A targeted rerun also checks that artwork validation, like lyric parsing,
is not repeated for a frozen retry request. Recovery-store tests cover reads
waiting for another session's last save, serialized writes across instances,
immutable queued snapshots and recovery after a failed write.

`cargo test --locked --workspace` passed **228 tests**, with **2 ignored**:
the explicitly configured audio-output test and opt-in real TDLib startup test.
The new bridge unit test rejects corrupt and oversized artwork without a session.
The modified handwritten Rust file passes rustfmt. Workspace-wide formatting
remains non-clean in pre-existing query/reader code; FRB's generated formatting
also differs from Rust 2024 import ordering. Those files were not reformatted
as unrelated work.

The FRB bindings were regenerated with `flutter/tool/generate.sh` using 2.13.0.
Two **real native content tests** passed against the rebuilt bridge, without
backend initialization, D-Bus or Telegram. They check PNG normalization and
idempotence, typed errors for corrupt/oversized images, LRC/SRT/WebVTT timestamps,
plain lines and invalid lyrics. Reproduce from `flutter/` after rebuilding:

```sh
CI=true KIYORA_NATIVE_LIBRARY="$(realpath ../rust/target/debug/libkiyora_flutter_bridge.so)" \
  flutter test --no-pub test_native/import_content_test.dart
```

`CI=true flutter build linux --debug --no-pub` passed with the updated native
API. No release was published. Real Telegram/Vault import, native picker use,
MPRIS/media keys and manual release/UI acceptance were not tested by these checks.

`CI=true PATH=... python3 flutter/tool/test_native.py` also passed both isolated
process phases (`seed`, `restore`) against the rebuilt generated bridge. The
private D-Bus was available in this run. This confirms the existing lifecycle,
profile and queue-preference recovery checks after the API regeneration; TDLib
was deliberately unavailable, so this is not authentication or MPRIS evidence.
