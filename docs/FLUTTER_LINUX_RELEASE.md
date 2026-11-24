# Linux build and release status

No stable release or validated installer is available from this checkpoint.
The verified artifact is a **debug development bundle**, not a release package.

## Reproduced build

### Private Telegram application configuration

Flutter onboarding uses the application's bundled Telegram configuration. Users
enter only their account authentication details (phone/QR, code, optional 2FA).
The Flutter bridge accepts no application ID/hash and exposes no getter for them.
Existing profiles reconnect using their original OS-protected configuration.

Before building, provision a private JSON file outside the checkout, containing
`api_id` (positive integer) and `api_hash` (32 hexadecimal characters). Set
`KIYORA_TELEGRAM_CONFIG` to its absolute path, or use
`$XDG_CONFIG_HOME/kiyora-build/telegram.json` (default
`$HOME/.config/kiyora-build/telegram.json`). On Unix the file must have mode `0600`.
Supply CI configuration through a secret file, never command-line credential
values, Dart defines, source files, or Flutter assets.

Cargo embeds validated bytes in the native library. Changes to the file trigger
recompilation. An invalid, insecure or explicitly missing file fails the build
without printing its contents. Release builds require configuration; debug builds
without a file support offline development and show a configuration error when
login is requested. The private file is not required on end-user devices.

The binary necessarily contains recoverable application credentials. Keeping
them out of Git, Dart and logs prevents accidental disclosure, but does not make
a distributed desktop application's credentials secret from its recipient.
Treat the native binaries and build caches accordingly. Session/database keys
continue to use the existing OS-backed secret storage.

Linux needs an available, unlocked Secret Service provider, such as KDE's
KWallet/KSecretD or GNOME Keyring. KIYORA does not select or replace the user's
provider. KDE documents its Secret Service backend in the
[KWallet README](https://github.com/KDE/kwallet/blob/master/README.md).

### Development bundle

Host: CachyOS x86_64; Flutter 3.50.0; FRB 2.13.0; repository Cargo.lock and
Flutter pubspec.lock. Flutter, Rust/Cargo, CMake, Ninja, a C++ toolchain, pkg-config,
GTK3, ALSA and D-Bus development libraries are required.

```sh
cd flutter
flutter pub get --enforce-lockfile
flutter build linux --debug --no-pub
```

Result: `flutter/build/linux/x64/debug/bundle/kiyora`. Keep its `lib/` and `data/`
directories together. CMake builds `kiyora-flutter-bridge` from the Rust workspace
and installs it into `bundle/lib/`; the executable has `$ORIGIN/lib` RPATH.
`ldd` resolved all executable and Rust bridge dependencies on this host.

The debug bundle was launched with working directory `/tmp`, using temporary
`KIYORA_DATA_DIR`, through native Wayland and X11 via XWayland on the Umbriel
compositor. Both produced a 1280×720 first-frame window and exited with code 0
on an ordinary compositor close request. No pre-close runtime errors were logged.
Private D-Bus helper processes logged disconnection messages when their test bus
was torn down after application exit. This was not a clean installation test,
visual acceptance, or a test of native Xorg/KDE/GNOME.

## TDLib and packaging path still to validate

Plain `flutter build linux` does not bundle TDLib. Onboarding/profile-only tests
do not need it and do not prove Telegram connectivity. The native resolver accepts
an explicit `KIYORA_TDJSON` path, then searches bundle resources and paths relative
to the executable. It does not search the working directory.

The existing Linux packaging entry point is:

```sh
python3 flutter/tool/package_desktop.py
```

On Linux it prepares pinned native sources, builds a release bundle, adds TDLib
and license files, and creates a tar archive with SHA256SUMS under
`flutter/build/packages/`. An optional `--deb` path also exists. Neither output
has been built/installed/validated in this checkpoint. Do not infer a supported
Debian baseline from its hard-coded dependency list, or compatibility with older
glibc from a CachyOS build.

Before distribution: verify the release artifact's TDLib lifecycle, all shared
libraries and glibc requirements, executable permissions, launcher/icon, license
payload, extraction/installation into paths containing spaces, launch outside the
repository, normal shutdown/reopen and removal without deleting profiles.
Use one validated distribution format first. No automatic release publication.

## Diagnostics and uninstall

Record the actual binary path, OS/compositor, build mode, `ldd` failures, error
message and whether a separate temporary profile reproduces the failure. Keep
Telegram API secrets and session files out of diagnostic reports.

Removing a development bundle must only remove that bundle. Do not remove the
existing application data root or keyring entries to reinstall or troubleshoot.
No uninstaller or migration script has been verified here.
