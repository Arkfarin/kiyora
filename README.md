<div align="center">

# KIYORA

**Your music. Your library. Your control.**

A personal music player and library built around Telegram-backed storage.

![Status](https://img.shields.io/badge/STATUS-UNDER_ACTIVE_DEVELOPMENT-e5484d?style=for-the-badge)
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Rust](https://img.shields.io/badge/Rust-000000?style=for-the-badge&logo=rust&logoColor=white)

</div>

---

## 🚧 UNDER ACTIVE DEVELOPMENT

> [!WARNING]
> **KIYORA IS NOT READY FOR GENERAL USE.**
>
> Kiyora is an unfinished project undergoing active development. Features, interfaces, and internal APIs are subject to change. Some functionality may be incomplete, unstable, or unavailable.
>
> **There is no stable release yet.** Please do not rely on the current code as your only way to access important music or data.

## About Kiyora

**Kiyora** is a personal music library and player designed to bring your music collection, playback, and organization into one application, using Telegram as the storage foundation.

The goal is a clean, responsive listening experience backed by a native Rust engine — with control over your library, playlists, metadata, and locally cached music.

Kiyora is being built with **Flutter** for the interface and **Rust** for core functionality.

## What Kiyora Is Working Toward

- **Telegram-backed music vault** — manage a personal music collection through Telegram-based storage.
- **Built-in music player** — play, pause, seek, shuffle, repeat, and manage the playback queue.
- **Organized library** — browse and search tracks, albums, artists, and playlists.
- **Music management** — import audio, edit metadata and artwork, and manage playlists.
- **Lyrics** — view track lyrics, including timed lyrics where available.
- **Offline listening** — use locally cached audio when it is available.
- **Library recovery and sync** — reconnect to an existing vault and keep the local library in sync.

> These are project goals and development areas, **not a checklist of finished or verified features**.

## Technology

| Layer | Technology |
| --- | --- |
| User interface | [Flutter](https://flutter.dev/) / Dart |
| Core engine | [Rust](https://www.rust-lang.org/) |
| Flutter ↔ Rust communication | [flutter_rust_bridge](https://cjycode.com/flutter_rust_bridge/) |
| Telegram integration | [TDLib](https://core.telegram.org/tdlib) |
| Local library data | SQLite |

The design keeps the user interface separate from the Rust engine responsible for library operations, synchronization, and playback.

## Platform Roadmap

| Platform | Current priority |
| --- | --- |
| 🐧 Linux | **Primary development focus** |
| 🤖 Android | Planned after the Linux experience is stabilized |
| 🪟 Windows | Planned after the Linux experience is stabilized |

Platform support and release timing are not guaranteed. A working source tree does not necessarily mean that an installable, tested build is available.

## Building from Source

Kiyora is currently a development project, not a finished application with a supported installation process.

The Flutter application is located in [`flutter/`](flutter/). Native integration, generated bindings, and platform-specific dependencies may be required to build and run it.

For technical context, see the [Flutter migration notes](docs/FLUTTER_MIGRATION.md) and the [Flutter release-readiness notes](docs/FLUTTER_RELEASE_READINESS.md). These documents may lag behind ongoing development.

**No stable binaries or one-command setup are promised at this stage.**

## Project Status

The immediate priority is building a stable, usable **Linux application** before expanding platform support. The interface, native integration, reliability, and packaging are all subject to continued development.

If you are following the project, expect frequent changes and occasional breakage while the architecture and user experience are refined.

---

<div align="center">

**KIYORA — Made for your music. Still in the making.**

[Source Code](https://github.com/Arkfarin/kiyora) · [Issues](https://github.com/Arkfarin/kiyora/issues)

</div>
