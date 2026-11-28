# Android build and verification

KIYORA (`io.github.arkfarin.kiyora`) is in active development. The Android runner
uses the same Rust library, SQLite projection, Flutter bridge and Telegram storage
protocol as Linux. Minimum SDK is 26 (Android 8.0). ARM64 is the default build;
x86_64 is available for compatible emulators. A host test is not a device test.

## Linux build environment

Use Flutter 3.50.0, Rust with the targets below, JDK 17 or 21, Python 3.12+,
CMake, a C/C++ toolchain, make, perl, gperf, curl and Android SDK command-line
tools. Set `JAVA_HOME` to a supported installed JDK and put Flutter on `PATH`.
From the repository root:

```sh
export JAVA_HOME=/path/to/jdk-21
export PATH=/path/to/flutter/bin:$JAVA_HOME/bin:$PATH
source rust/scripts/android-env.sh
sdkmanager --licenses
sdkmanager --install 'platform-tools' 'platforms;android-36' \
  'build-tools;36.0.0' 'ndk;28.2.13676358' 'cmake;3.22.1'
rustup target add aarch64-linux-android x86_64-linux-android
bash rust/scripts/check-android-env.sh
```

`ANDROID_HOME` defaults to `$HOME/Android/Sdk`, `NDK_HOME` to its r28c directory.
The scripts download pinned TDLib, OpenSSL and zlib sources, compile native
libraries, and validate ELF load segment alignment. The initial native build is
CPU and memory intensive; `KIYORA_BUILD_JOBS` and `CARGO_BUILD_JOBS` default to 2.

The native bridge is compiled in release mode even for a Flutter debug APK, so
it requires an existing private Telegram application configuration. Set
`KIYORA_TELEGRAM_CONFIG` to its path, or use the default
`$HOME/.config/kiyora-build/telegram.json`. It contains `api_id` and `api_hash`;
use mode 600 and keep the file and any personal account credentials out of Git.

## Build, install and launch

Locally installable debug APK (ARM64):

```sh
bash flutter/tool/package_android.sh --debug
adb devices -l
adb install -r flutter/build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n io.github.arkfarin.kiyora/.MainActivity
```

For an x86_64 emulator:

```sh
KIYORA_ANDROID_ABIS=x86_64 bash flutter/tool/package_android.sh --debug
```

For a release APK and AAB with both ABIs:

```sh
KIYORA_ANDROID_ABIS=arm64-v8a,x86_64 bash flutter/tool/package_android.sh
```

Release signing uses the pre-existing private configuration at
`$HOME/.local/share/kiyora/android-signing/keystore.properties`, or the path in
`KIYORA_ANDROID_SIGNING_PROPERTIES`. The file provides `storeFile` (relative to
the properties directory), `storePassword`, `keyAlias`, `keyPassword`, and
optionally `storeType`. Do not commit it or the keystore. Without this file,
release output is unsigned and must not be treated as an installable release.
Use `--apk-only` for release APK without bundle. Expected output paths:

- `flutter/build/app/outputs/flutter-apk/app-debug.apk`
- `flutter/build/app/outputs/flutter-apk/app-release.apk`
- `flutter/build/app/outputs/bundle/release/app-release.aab`

The package script verifies expected native libraries, supported ABI, 16 KiB ELF
alignment, APK ZIP alignment and the signature when configured. These checks
do not substitute for installing on a 16 KiB-page Android device.

## Repeatable automated verification

From the repository root:

```sh
(cd flutter && flutter analyze --no-pub && flutter test --no-pub)
(cd rust && cargo test --workspace --locked)
python3 -m unittest discover -s flutter/tool -p test_android_package.py
python3 flutter/tool/test_native.py
```

Host-rendered mobile screenshots (synthetic test data, never production content):

```sh
cd flutter
KIYORA_VISUAL_QA=1 flutter test test/android_visual_qa_test.dart
```

The PNG files are written to `qa-results/android-ui/` at the repository root.
They show Flutter's mobile layout at a phone viewport, not an Android system UI.

### Verification on 2026-11-28

Host: CachyOS x86_64, Flutter 3.50.0, JDK 21, Gradle 9.5.0, Android SDK 36,
NDK 28.2.13676358 (API 26 native target).

- Flutter analyzer: no issues. Normal Flutter suite: 99 passed; the opt-in
  visual test is skipped unless enabled. Separate visual QA rendered and
  inspected Home, Search, Library, Settings, Storage and Fullscreen Player.
- Rust workspace tests (`--locked --offline`): 237 passed, 2 ignored, 0 failed.
- Android `cargo check` and actual Rust release linking passed for both ARM64
  and x86_64. `llvm-readelf` confirmed the corresponding architectures, 16 KiB
  LOAD segments and only Android system-library dependencies. ARM64 TDLib with
  pinned OpenSSL/zlib also built and passed the ELF alignment checks. These
  native checks are not APK checks.
- AAPT2 successfully compiled Android resource XML.
- Real Linux FRB lifecycle smoke: seed and restore passed. Real Linux offline
  decoder and MPRIS playback smoke: passed, 162,656 PCM samples above threshold
  reached an isolated PulseAudio-compatible sink. The test now allows the final
  audio buffer to drain before shutdown; no user's audio or data was used.

The actual device and package acceptance steps below remain mandatory; neither
the host visual renders nor the Rust cross-check proves Android startup.

### Verification on 2026-11-29

ARM64 and x86_64 debug APKs were built and verified independently, then an
ARM64+x86_64 AAB was produced and checked. An isolated Android 15 x86_64
emulator installed and launched the real application, created a disposable
profile, restored it after force-stop and displayed the native Telegram login
entry. Automated Flutter/Rust/FRB regression checks also passed.

See [Android emulator QA — 29 November 2026](ANDROID_EMULATOR_QA_2026-11-29.md)
for exact commands, screenshots, pass/fail evidence and remaining limitations.
The emulator used 4 KiB kernel pages; a 16 KiB-page device test remains open.
Release signing properties were absent, so the build artifacts available for
direct installation are debug APKs.

## Device acceptance checklist

Before a release, verify on Android 8+ and a modern Android version; include a
16 KiB-page device/emulator if available and a real POCO/Xiaomi device.

| Scenario | Acceptance |
| --- | --- |
| Install and update | Correct application ID, launch, signed update, no lost library |
| Authentication | Phone/QR and 2FA, existing vault recovery, profile switch/logout |
| Playback | Audible local and remote media, rapid next/previous, seek, shuffle/repeat |
| Background | Screen lock, recent apps swipe, notification, MediaSession and Bluetooth controls |
| Audio interruptions | Call, temporary focus loss/gain, headset unplug, volume keys |
| Offline | Cached audio, offline library, cancellation, pin/unpin, network transitions |
| Import | SAF multi-select, metadata and artwork, cancellation, denied or revoked access |
| Lifecycle | Rotation, theme persistence, process death/reopen, queue restoration |
| Accessibility | TalkBack, larger text, small phone, tablet and gesture navigation |
| Performance | Large libraries, frame timing, memory and battery during prolonged playback |

Android's foreground service restrictions and vendor battery policies can differ.
Do not infer POCO/Xiaomi background reliability from host tests. Record device,
Android version, ABI, page size, build commit and observed result for each check.

## Current limitations

The existing Rust engine restores persisted queue/repeat/shuffle state, but does
not promise automatic playback after process death or restoration of the exact
last seek position. The full-download-before-play preference is not implemented;
offline download/pinning is available separately. An Android notification/service
cannot be accepted from a host-only Rust test. Live account authentication,
sync between platforms, long-duration audio, and device battery/performance
measurements remain separate acceptance requirements.
