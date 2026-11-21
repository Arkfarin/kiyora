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

From `src-tauri/`:

```sh
cargo test --locked -p kiyora-flutter-bridge
```

## Current automated evidence

- Flutter suite: 20 tests passed before the final additional operation-cancellation
  regression; controller suite subsequently passed all 13 tests.
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
- Targeted Dart analysis of the controller and its regression tests passed
  with no issues. Whole-project Flutter analysis reports 17 pre-existing
  informational deprecations (Material imports, reorder and radio callbacks),
  so its default exit status is currently nonzero.

## Acceptance still required

Native FRB execution, actual Telegram authentication/Vault sync, audible playback,
queue mutations during playback, real data upgrade, offline/reconnect, MPRIS/media
keys, Wayland/X11 window behavior, clean installation and packaged launch need
separate evidence. Unit/widget tests do not prove these scenarios.

The historical `FLUTTER_MIGRATION.md` and `FLUTTER_RELEASE_READINESS.md` describe
an earlier source-only stage and contain stale no-testing and cross-platform
plans. The current Linux-first task requires testing. Do not treat those older
statements as current acceptance evidence or instructions to skip verification.
