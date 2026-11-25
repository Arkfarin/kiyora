# Optional live-account and device acceptance

Live account and physical-device checks are opt-in and are separate from
account-free CI. Emulator/native results and outstanding live checks are recorded
in [Linux testing notes](../../docs/FLUTTER_LINUX_TESTING.md).
Use dedicated Telegram accounts, a disposable private test vault and a test
recipient. Do not reuse personal session files. Use generated tone fixtures from
`spec/test-vectors/audio`, and record build revision, platform, app/TDLib versions,
test case and expected/actual result. Keep phone numbers, codes, API hash, session
paths and raw TDLib logs out of artifacts.

## Desktop account setup

Build an installer using [Linux release notes](../../docs/FLUTTER_LINUX_RELEASE.md), verify it and install it on
the target OS. Build the diagnostic CLI with `cargo build --locked -p vault-core
--bin kiyora-cli`. From `rust`, an isolated Linux CLI acceptance directory can
be selected as follows (PowerShell uses the equivalent `$env:` variables):

```sh
export KIYORA_DATA_DIR="$(mktemp -d -t kiyora-e2e-XXXXXX)"
export KIYORA_TDJSON="$PWD/target/native/desktop/native/libtdjson.so"
cli="$PWD/target/debug/kiyora-cli"
"$cli" profiles create e2e
"$cli" profiles list --json
"$cli" profiles switch <profile-uuid>
```

Provide `KIYORA_API_ID` and `KIYORA_API_HASH` through a private environment/secret
provider, then run `"$cli" auth login`. Values must not be embedded in command
history or source files. An unavailable keyring must produce a structured error;
do not substitute plaintext storage. Check wrong/expired code and wrong 2FA
password, cancel the attempt, then complete login. Exit and reopen the CLI and
verify `auth status --json` without another login. Test `kiyora-cli auth qr`
using the dedicated acceptance steps below.

Run `vault discover`, `status --json` and `diagnose`. Use `vault create` only when
intentionally creating a new test vault. For renamed/archive recovery, JSON,
request counts and cancellation, follow [Vault discovery E2E](vault-discovery.md#manual-live-e2e).
Capture only
redacted application results. Create a second isolated directory/profile on a
second device, log in to the same **test account**, discover and attach the test
vault. Wait for `online_ready` on both clients before mutations.

## QR authorization acceptance

These are **manual, opt-in, real-account checks**. ABI mocks prove local control
flow and persistence behavior, not Telegram server acceptance or phone scanning.
Use a test account already logged into Telegram on Android. Do not record the QR,
its link, API hash, codes or password in evidence screenshots or logs.

With the pinned native library and API credentials configured as above:

```sh
kiyora-cli profiles create test
kiyora-cli profiles switch <uuid>
kiyora-cli auth qr
kiyora-cli auth status --json
kiyora-cli vault discover
```

1. In Kitty, Konsole or Alacritty, leave the first QR unscanned until TDLib rotates
   it. Only the newest QR should remain visible. Resize the window: the code must
   fit with its white border, or disappear with an enlarge-window instruction.
2. Android: Telegram → Settings → Devices → Link Desktop Device. Scan and confirm.
   With 2FA enabled, enter a wrong password once, then the correct password in the
   hidden CLI prompt. Success must include account name, user ID and profile.
   Repeat with a test account without 2FA to verify direct confirmation → Ready.
3. Run `auth status --json` in a new process: expect `READY`. Run `auth qr` again:
   expect “already authorized,” no new QR. `vault discover` must use this session.
4. Start an unfinished login in another disposable profile. Ctrl+C at QR and 2FA,
   then resume; also test `/cancel`. Verify the terminal echo/mode is restored and
   the saved profile/TDLib files remain. Do not use SIGKILL as a graceful-close test.
5. While waiting for QR, disconnect/reconnect the network: the old QR disappears;
   scanning resumes when TDLib supplies a fresh link. Cancel during the outage.
6. Run a second `auth qr` against the same active profile: expect `ProfileBusy`.
   Stop the first cleanly, then verify the second can open the same profile.
7. In a disposable phone-login profile, run `auth login`, enter `/qr` at the code
   prompt and complete QR login. Check `/resend` still reports Telegram's offered
   delivery/delay and suggests QR when no alternative delivery exists.
8. Repeat QR display/rotation/cancel with `TERM=dumb` and a dark terminal background.
   Old output is scrolled away and marked invalid; fallback cannot erase scrollback.
   Redirected stdout must refuse QR output without printing the token/link.

Record OS, terminal, TDLib version, whether 2FA was enabled, and the outcome of
these checks without secrets. Windows terminal behavior and real Android scanning
remain separate platform acceptance; a Linux mock or compilation pass does not
verify them. See [CLI troubleshooting](cli-auth.md#troubleshooting).

## Account data and recovery

| Test | Actions | Required result |
| --- | --- | --- |
| Import formats | `media import` each audio fixture; inspect `library list` and Telegram | Title/duration/source correct, Telegram audio metadata present, playback decodes |
| Duplicate file | Import the same bytes under a second filename | Exact duplicate is reported; no second audio upload |
| Incoming audio | `media import-incoming <chat> <message>` for a test audio with cover | Server copy has a new message ID; audio isn't downloaded/reuploaded, cover is fetched separately |
| Protected content | Repeat from a protected test chat | Explicit refusal, no bypass upload |
| Sharing | `library share <track> <source> <recipient> --op-id <uuid>` twice | Recipient receives one copy; journal has final ID only after ACK |
| Ambiguous sharing | Disconnect after send; inspect `get_share_status` through `serve` | `unknown` is retained unless final ACK was observed; replay doesn't send again |
| Offline | Disconnect network; query library/playlists and play a fully cached track | Reads/playback work; cloud writes, shares and new remote downloads fail |
| Reconnect | Restore network after a second device changed a playlist | Reconciliation completes before mutations; both projections converge |
| Concurrent edits | Rename/delete a playlist while the other client changes its entries | Deterministic convergence; deleted playlist stays deleted |
| Snapshot | `snapshot create`, then `snapshot verify`; cold attach a third profile | Both copies are read back and verified; complete state restored |
| Corrupt A | In the disposable vault only, remove/corrupt one snapshot copy | B restores full state; repair publishes a new verified generation |
| Interrupted snapshot | Stop the process before commit, restart | Uncommitted copy doesn't become active; history remains recoverable |
| GC | `gc plan`, inspect exact digest, `gc execute <plan> <digest>` in the test vault only | Live audio/artwork and current snapshot copies retained |
| Interrupted GC | Stop after one deletion batch, restart and inspect/resume | Persisted plan resumes conservatively; no blind new deletion plan |
| Second coordinator | Transfer coordinator while old GC is interrupted | Old plan refuses further destructive work after revalidation |
| Long-absent client | Keep a disconnected profile, delete playlist, snapshot/GC, reconnect it | Tombstone survives; deleted UUID doesn't return |
| Local damage | With app closed, damage a copy of the disposable SQLite DB, run `repair` | Original main/WAL/SHM are quarantined; verified snapshot+tail restore state |
| Lost ACK | Drop transport during import/mutation; restart and resume same `op_id` | Confirmed server result is discovered; no blind resend |
| Profile switch | Switch while import/download/playback is active | Old work is canceled/fenced and can't affect the new profile |
| Logout | Log out then restart | Session revoked, no stale writer; local reads obey selected profile |

Fault timing and the three-year-old checkpoint case are deterministic in the
simulator tests; real network toggles alone cannot force an exact ACK boundary.
Use the simulator regression as evidence of that boundary and label manual
network acceptance separately. Do not claim a live case ran if timing was not
observed. Full-backup export/restore and deliberate disk-full tests must use a
separate test filesystem, not the user's home volume.

## Desktop audio and failure checks

On installed Linux and Windows apps, repeat local/remote playback, seek, queue,
pause/resume, missing remote audio, track/playlist deletion and close-while-playing.
Disconnect Bluetooth, switch the default output, suspend/resume Windows, and
restart the test user's PipeWire output on Linux. Verify position preservation,
structured errors and recovery without blocking library reads or leaking audio
workers. Capture measured memory/request counts for a large FLAC and rapid seek.
Decoder tests do not prove these hardware behaviors. Final readiness must mark
each unexecuted physical/account check `UNVERIFIED` with its reason.

An account-free Linux check exercises the real output/mixer/decoder using an
isolated ALSA null device. It injects the device-error notification, verifies a
structured failure and lease release, then starts a new track and checks output
reopening. It neither plays audible sound nor changes the user's default output:

```sh
audio_config=$(mktemp)
cat > "$audio_config" <<'ALSA'
pcm.!default { type null }
ctl.!default { type hw card 0 }
ALSA
ALSA_CONFIG_PATH="$audio_config" cargo test --locked -p vault-media --lib \
  output_device_failure_releases_media_and_next_play_reopens -- --ignored
rm "$audio_config"
```

Actual route removal is still a physical-device acceptance test. After a hard
output failure, the next explicit Play reopens the output; automatic migration
and position restoration are not promised. Also verify that a cancelled download
returns promptly while Telegram imposes a long FloodWait, and that an oversized
local import is rejected before staging/upload (2000 MiB basic, 4000 MiB Premium
for the pinned TDLib transport). Downloading or server-copying existing large
messages is a distinct operation.
