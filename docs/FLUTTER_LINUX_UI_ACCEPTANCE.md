# Linux UI acceptance — incomplete

The requested reference is Spotify Desktop's navigation/library/content/context
panel/bottom-player composition, retaining KIYORA's own branding and red accent
(`#ff2448`). No Spotify logos or proprietary assets are needed.

## Source inventory, not runtime acceptance

| Area | Current implementation |
| --- | --- |
| Shell/navigation | `MusicShell`, `MusicNavigation`; Home/Search/Library/detail/Settings/Import destinations and back/forward history |
| Library/details | Paged Rust queries for tracks, albums, artists, playlists and favorites; track actions delegate to typed mutations |
| Player | Playback controls and queue modes call Rust; separate playback/current-track notifiers |
| Context panels | Queue, lyrics and current-track views |
| Queue | Rust queue IDs/revisions, reorder and mutation calls |
| Lyrics | Typed lyrics reads/parser output, timed-line display and seek controls |
| Import | Native picker, review/send and durable job progress/actions |
| Onboarding/settings | Profile/auth/Vault controls, cache and maintenance API calls |

These source paths are under `flutter/lib/features/`. Source presence does not
prove feature completeness, successful Telegram mutations or Spotify-level UX.

## Verified scope on 2026-11-21

Widget tests passed for initial Home/import rendering and shell/player navigation
at widths 720, 900, 1280 and 1440. Test fixtures are isolated from production.
The actual debug runner reached a first-frame window on Wayland and XWayland and
closed normally. No screenshot comparison or populated-library visual acceptance
was performed in this checkpoint.

## Open acceptance

Verify actual account data across all pages, keyboard/focus order, tooltips and
context menus, independent scrolling, sidebar resizing, long labels, scaled text,
loading/empty/error/retry states, track/playlist editing, bulk import and desktop
file drop, timed/plain lyrics, queue reorder, theme/state persistence and window
restoration. Measure scrolling/rebuilds on a rendered 10,000-track library.

The paging unit test proves reachability and a bounded item window, not frame
rate. The existing narrow-width shell tests are not complete accessibility or
layout coverage. Theme colors in source are not evidence of visual quality.
