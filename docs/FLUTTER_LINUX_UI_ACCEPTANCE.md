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
| Import | Native picker, bulk send, prepared-file metadata/artwork/lyrics editor, duplicate confirmation, recovery drafts and durable job progress/actions |
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

## Prepared import editor (2026-11-26)

The import page now opens the existing Rust preview API per selected file. Its
form edits metadata, replaces/removes/restores artwork, imports UTF-8
LRC/SRT/WebVTT/plain lyrics through the Rust parser, and optionally writes tags
to the staged copy. Ordinary bulk submission remains available for the remaining
files. Prepared files are excluded from that batch.

Drafts belong to the session and are restored from the existing UI recovery file
plus Rust previews/command receipts. The first commit freezes its IDs, edit bytes,
parsed lyric lines and write-tags setting. Duplicate confirmation changes only
`allowDuplicate`; a lost confirmation reply removes the stale review actions.
Only an Applied receipt is displayed as confirmed. Cancellation stops waiting;
it does not promise to undo an upload already accepted by the backend.

Widget checks exercise preparation, navigation, duplicate confirmation,
ServerAck versus Applied, cancellation/retry and attachment controls at 400,
720 and 1280 logical pixels of content width. These use mocked bridge responses.
Real file-picker interaction, Telegram upload and manual visual acceptance remain
unverified. A backend-only preview without its local request is deliberately
read-only and can only resume an existing journal; the UI does not invent IDs.
