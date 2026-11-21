> Historical notes: superseded for the current Linux-first task by
> [Linux migration](FLUTTER_LINUX_MIGRATION.md),
> [testing](FLUTTER_LINUX_TESTING.md), [release](FLUTTER_LINUX_RELEASE.md),
> and [UI acceptance](FLUTTER_LINUX_UI_ACCEPTANCE.md).
> Earlier no-testing and concurrent-platform plans below are no longer current.

# Flutter UI acceptance — not yet implemented

The explicit reference is Spotify composition and behavior, with KIYORA identity.
Current brand accent from `src/styles/app.css` is #ff2448 (hover #ff4260,
active #dd1639). Do not use Spotify green, brand assets or proprietary fonts.

Desktop requires top navigation/search, resizable left library, independent
central content, optional Now Playing/Queue/Lyrics rail and persistent player.
Android requires Home/Search/Your Library, mini-player above navigation,
fullscreen transport/artwork, interactive dismissal, contextual bottom sheets.
Both require real backend content, playlist/album/artist detail, paginated search,
queue revisions, offline indicators, import review and synchronized lyrics.

No Flutter screens, screenshots or visual comparisons have been completed.
No pixel-perfect or runtime parity claim is made. Design-skill generic dashboard
rules do not override the user's Spotify layout and existing KIYORA palette.

Pending: every requested screen, player gestures, queue reorder, contextual
management, loading/empty/error/retry states, themes, accessibility, localization,
performance and visual fidelity. No fixture data is supplied for production.
Tests and interactive visual acceptance are not run, per the user's instruction.
