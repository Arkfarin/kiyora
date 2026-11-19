import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/bridge/generated/api.dart' as api;
import '../../core/state/backend_controller.dart';
import '../../core/widgets/artwork.dart';

String musicTime(int milliseconds) {
  final seconds = math.max(0, milliseconds ~/ 1000);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class PlaybackProgress extends StatefulWidget {
  const PlaybackProgress({
    super.key,
    required this.backend,
    this.compact = false,
  });
  final BackendController backend;
  final bool compact;
  @override
  State<PlaybackProgress> createState() => _PlaybackProgressState();
}

class _PlaybackProgressState extends State<PlaybackProgress> {
  double? _drag;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: widget.backend.playback,
    builder: (context, state, _) {
      final (position, duration) = playbackTime(state);
      final value = (_drag ?? position.toDouble()).clamp(
        0.0,
        math.max(1, duration).toDouble(),
      );
      if (widget.compact)
        return LinearProgressIndicator(
          minHeight: 2,
          value: duration == 0 ? 0 : (position / duration).clamp(0, 1),
        );
      return Row(
        children: [
          SizedBox(
            width: 45,
            child: Text(
              musicTime(value.toInt()),
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              max: math.max(1, duration).toDouble(),
              semanticFormatterCallback: (v) => musicTime(v.toInt()),
              onChanged: duration == 0
                  ? null
                  : (v) => setState(() => _drag = v),
              onChangeEnd: (v) {
                setState(() => _drag = null);
                widget.backend.transport(
                  api.Transport.seek(milliseconds: BigInt.from(v.round())),
                );
              },
            ),
          ),
          SizedBox(
            width: 45,
            child: Text(
              musicTime(duration),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      );
    },
  );
}

class TransportControls extends StatelessWidget {
  const TransportControls({
    super.key,
    required this.backend,
    this.large = false,
  });
  final BackendController backend;
  final bool large;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([backend.playback, backend.queue, backend]),
    builder: (context, _) {
      final q = backend.queue.value;
      final state = backend.playback.value;
      final enabled = q != null && q.total > BigInt.zero && !backend.busy;
      final accent = Theme.of(context).colorScheme.primary;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: q?.shuffle == true
                ? 'Выключить перемешивание'
                : 'Перемешать',
            isSelected: q?.shuffle == true,
            color: q?.shuffle == true ? accent : null,
            onPressed: !enabled
                ? null
                : () => backend.editQueue(
                    api.QueueEdit.shuffle(enabled: !q!.shuffle),
                  ),
            icon: const Icon(Icons.shuffle),
          ),
          IconButton(
            tooltip: 'Предыдущая композиция',
            iconSize: large ? 36 : 24,
            onPressed: !enabled
                ? null
                : () => backend.transport(const api.Transport.previous()),
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          const SizedBox(width: 8),
          SizedBox.square(
            dimension: large ? 64 : 40,
            child: IconButton.filled(
              tooltip: state is api.Playback_Playing
                  ? 'Пауза'
                  : 'Воспроизвести',
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onSurface,
                foregroundColor: Theme.of(context).colorScheme.surface,
              ),
              onPressed: !enabled
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      backend.togglePlayback();
                    },
              iconSize: large ? 38 : 24,
              icon: state is api.Playback_Buffering
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      state is api.Playback_Playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Следующая композиция',
            iconSize: large ? 36 : 24,
            onPressed: !enabled
                ? null
                : () => backend.transport(const api.Transport.next()),
            icon: const Icon(Icons.skip_next_rounded),
          ),
          IconButton(
            tooltip: switch (q?.repeat) {
              api.Repeat.off => 'Включить повтор очереди',
              api.Repeat.all => 'Повторять композицию',
              _ => 'Выключить повтор',
            },
            color: q?.repeat != null && q?.repeat != api.Repeat.off
                ? accent
                : null,
            onPressed: !enabled
                ? null
                : () => backend.editQueue(
                    api.QueueEdit.repeat(
                      mode: switch (q!.repeat) {
                        api.Repeat.off => api.Repeat.all,
                        api.Repeat.all => api.Repeat.one,
                        api.Repeat.one => api.Repeat.off,
                      },
                    ),
                  ),
            icon: Icon(
              q?.repeat == api.Repeat.one ? Icons.repeat_one : Icons.repeat,
            ),
          ),
        ],
      );
    },
  );
}

class PlayerBar extends StatelessWidget {
  const PlayerBar({
    super.key,
    required this.backend,
    required this.mobile,
    required this.openPlayer,
    required this.openQueue,
    required this.openLyrics,
  });
  final BackendController backend;
  final bool mobile;
  final VoidCallback openPlayer, openQueue, openLyrics;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: backend.currentTrack,
    builder: (context, track, _) {
      if (mobile && playbackTrackId(backend.playback.value) == null)
        return const SizedBox.shrink();
      final identity = Row(
        children: [
          MusicArtwork(
            sessionId: backend.sessionId,
            trackId: track?.id,
            digest: track?.metadata.artworkDigest,
            size: mobile ? 40 : 54,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track?.metadata.title ?? 'Выберите композицию',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (track != null)
                  Text(
                    track.metadata.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      );
      if (mobile)
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: openPlayer,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 6, bottom: 6),
                    child: Row(
                      children: [
                        Expanded(child: identity),
                        ValueListenableBuilder(
                          valueListenable: backend.playback,
                          builder: (context, state, _) => IconButton(
                            tooltip: state is api.Playback_Playing
                                ? 'Пауза'
                                : 'Воспроизвести',
                            onPressed: backend.togglePlayback,
                            icon: Icon(
                              state is api.Playback_Playing
                                  ? Icons.pause
                                  : Icons.play_arrow,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                PlaybackProgress(backend: backend, compact: true),
              ],
            ),
          ),
        );
      return SizedBox(
        height: 92,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: InkWell(onTap: openPlayer, child: identity),
              ),
              Expanded(
                flex: 5,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TransportControls(backend: backend),
                      PlaybackProgress(backend: backend),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Текст песни',
                      onPressed: openLyrics,
                      icon: const Icon(Icons.lyrics_outlined),
                    ),
                    IconButton(
                      tooltip: 'Очередь',
                      onPressed: openQueue,
                      icon: const Icon(Icons.queue_music),
                    ),
                    IconButton(
                      tooltip: 'Сейчас играет',
                      onPressed: openPlayer,
                      icon: const Icon(Icons.open_in_full, size: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class FullscreenPlayer extends StatefulWidget {
  const FullscreenPlayer({
    super.key,
    required this.backend,
    required this.openQueue,
    required this.openLyrics,
  });
  final BackendController backend;
  final VoidCallback openQueue, openLyrics;
  @override
  State<FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<FullscreenPlayer> {
  double _drag = 0;
  bool _dragging = false;
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedContainer(
      duration: _dragging || reduced
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, _drag, 0),
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => ValueListenableBuilder(
              valueListenable: widget.backend.currentTrack,
              builder: (context, track, _) {
                final size = math.min(
                  constraints.maxWidth - 48,
                  math.max(180.0, constraints.maxHeight * .42),
                );
                return CustomScrollView(
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragUpdate: (d) => setState(() {
                                _dragging = true;
                                _drag = math.max(0, _drag + d.delta.dy);
                              }),
                              onVerticalDragEnd: (d) {
                                if (_drag > 140 ||
                                    (d.primaryVelocity ?? 0) > 700) {
                                  Navigator.of(context).pop();
                                } else {
                                  setState(() {
                                    _dragging = false;
                                    _drag = 0;
                                  });
                                }
                              },
                              onVerticalDragCancel: () => setState(() {
                                _dragging = false;
                                _drag = 0;
                              }),
                              child: SizedBox(
                                height: 64,
                                child: Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Свернуть плеер',
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down,
                                      ),
                                    ),
                                    const Expanded(
                                      child: Text(
                                        'Сейчас играет',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Очередь',
                                      onPressed: widget.openQueue,
                                      icon: const Icon(Icons.queue_music),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onHorizontalDragEnd: (d) {
                                if ((d.primaryVelocity ?? 0).abs() > 250)
                                  widget.backend.transport(
                                    d.primaryVelocity! < 0
                                        ? const api.Transport.next()
                                        : const api.Transport.previous(),
                                  );
                              },
                              child: MusicArtwork(
                                sessionId: widget.backend.sessionId,
                                trackId: track?.id,
                                digest: track?.metadata.artworkDigest,
                                size: size,
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(height: 28),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                track?.metadata.title ?? 'Выберите композицию',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                track?.metadata.artist ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(height: 20),
                            PlaybackProgress(backend: widget.backend),
                            const SizedBox(height: 12),
                            TransportControls(
                              backend: widget.backend,
                              large: true,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton.icon(
                                  onPressed: widget.openLyrics,
                                  icon: const Icon(Icons.lyrics_outlined),
                                  label: const Text('Текст песни'),
                                ),
                                IconButton(
                                  tooltip: 'Очередь',
                                  onPressed: widget.openQueue,
                                  icon: const Icon(Icons.queue_music),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
