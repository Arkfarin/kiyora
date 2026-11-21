# KIYORA Linux dispatch fix

Vendored from the crates.io souvlaki 0.8.3 source, retaining its MIT license and
all platform implementations. Only `src/platform/mpris/dbus/controls.rs` differs
from upstream. Cargo selects this copy through `[patch.crates-io]`.

The upstream D-Bus worker waits up to one second after each internal update.
Rapid Play/Pause queues updates, and `MediaControls::detach` joins that worker
behind the backlog. Because KIYORA owns it on the audio-control worker, removing
the current queue item or shutdown could freeze playback for over ten seconds.

The patch bounds bus polling to 10 ms and prioritizes detach via an atomic stop
flag instead of draining obsolete playback changes before processing Kill.
It does not replace the audio engine or change another platform adapter.

Regression: `python3 flutter/tool/test_playback.py`. Before the patch, step 9
(removing the current track after rapid toggles) timed out at ten seconds and
shutdown took several more seconds. After the patch, the complete real
Dart/FRB/SQLite/cache/ALSA/MPRIS scenario completes in about two seconds, with PCM
verified at an isolated PulseAudio-compatible sink. Physical media keys and
hardware audio are not covered by this virtual-sink test.
