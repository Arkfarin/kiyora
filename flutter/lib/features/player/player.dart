import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../core/bridge/generated/api.dart' as api;
import '../../core/bridge/generated/api/content.dart' as content;
import '../../core/bridge/generated/api/edits.dart' as edits;
import '../../core/routing/navigation.dart';
import '../../core/state/backend_controller.dart';
import '../../core/widgets/artwork.dart';
import '../library/track_actions.dart';

String musicTime(int milliseconds) {
  final seconds = math.max(0, milliseconds ~/ 1000);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class PlaybackProgress extends StatefulWidget {
  const PlaybackProgress({
    super.key,
    required this.backend,
    this.compact = false,
    this.showRemaining = false,
  });
  final BackendController backend;
  final bool compact;
  final bool showRemaining;
  @override
  State<PlaybackProgress> createState() => _PlaybackProgressState();
}

class _PlaybackProgressState extends State<PlaybackProgress> {
  double? _drag;
  String? _dragTrack;
  bool _gestureInvalid = false;

  @override
  void initState() {
    super.initState();
    _listen(widget.backend);
  }

  void _listen(BackendController backend) {
    backend.playback.addListener(_invalidateGesture);
    backend.addListener(_invalidateGesture);
  }

  void _unlisten(BackendController backend) {
    backend.playback.removeListener(_invalidateGesture);
    backend.removeListener(_invalidateGesture);
  }

  void _invalidateGesture() {
    if (!_gestureInvalid &&
        _dragTrack != null &&
        (widget.backend.busy ||
            playbackTrackId(widget.backend.playback.value) != _dragTrack ||
            playbackTime(widget.backend.playback.value).$2 <= 0)) {
      setState(() {
        _gestureInvalid = true;
        _drag = null;
      });
    }
  }

  @override
  void didUpdateWidget(covariant PlaybackProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backend != widget.backend) {
      _unlisten(oldWidget.backend);
      _drag = null;
      _dragTrack = null;
      _gestureInvalid = true;
      _listen(widget.backend);
    }
  }

  @override
  void dispose() {
    _unlisten(widget.backend);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.backend.playback, widget.backend]),
    builder: (context, _) {
      final state = widget.backend.playback.value;
      final track = playbackTrackId(state);
      final (position, duration) = playbackTime(state);
      final enabled = track != null && duration > 0 && !widget.backend.busy;
      final value = (_drag ?? position.toDouble()).clamp(
        0.0,
        math.max(1, duration).toDouble(),
      );
      if (widget.compact)
        return LinearProgressIndicator(
          minHeight: 2,
          value: duration == 0 ? 0 : (position / duration).clamp(0, 1),
        );
      final slider = Slider(
        value: value,
        max: math.max(1, duration).toDouble(),
        semanticFormatterCallback: (v) => musicTime(v.toInt()),
        onChangeStart: !enabled
            ? null
            : (_) {
                _dragTrack = track;
                _gestureInvalid = false;
              },
        onChanged: !enabled
            ? null
            : (v) {
                if (!_gestureInvalid && _dragTrack == track) {
                  setState(() => _drag = v);
                }
              },
        onChangeEnd: !enabled
            ? null
            : (v) {
                final current = widget.backend.playback.value;
                final valid =
                    !_gestureInvalid &&
                    _dragTrack != null &&
                    _dragTrack == playbackTrackId(current) &&
                    !widget.backend.busy &&
                    playbackTime(current).$2 > 0;
                setState(() {
                  _drag = null;
                  _dragTrack = null;
                  _gestureInvalid = false;
                });
                if (valid) {
                  widget.backend.transport(
                    api.Transport.seek(
                      milliseconds: BigInt.from(
                        v.round().clamp(0, playbackTime(current).$2),
                      ),
                    ),
                  );
                }
              },
      );
      final elapsed = Text(
        musicTime(value.toInt()),
        textAlign: TextAlign.end,
        style: Theme.of(context).textTheme.labelSmall,
      );
      final total = Text(
        widget.showRemaining
            ? '-${musicTime(duration - value.toInt())}'
            : musicTime(duration),
        style: Theme.of(context).textTheme.labelSmall,
        semanticsLabel: widget.showRemaining
            ? 'Осталось ${musicTime(duration - value.toInt())}'
            : null,
      );
      if (widget.showRemaining) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            slider,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [elapsed, total],
              ),
            ),
          ],
        );
      }
      return Row(
        children: [
          SizedBox(width: 45, child: elapsed),
          Expanded(child: slider),
          SizedBox(width: 45, child: total),
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
      final controls = <Widget>[
        IconButton(
          tooltip: q?.shuffle == true
              ? 'Выключить перемешивание'
              : 'Перемешать',
          isSelected: q?.shuffle == true,
          color: q?.shuffle == true ? accent : null,
          onPressed: !enabled
              ? null
              : () => backend.editQueue(
                  api.QueueEdit.shuffle(enabled: !q.shuffle),
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
        SizedBox.square(
          dimension: large ? 64 : 40,
          child: IconButton.filled(
            tooltip: playbackWantsAudio(state) ? 'Пауза' : 'Воспроизвести',
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
            icon: _PlaybackIcon(state: state, size: large ? 34 : 24),
          ),
        ),
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
                    mode: switch (q.repeat) {
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
      ];
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < (large ? 264 : 240)) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: controls.sublist(1, 4),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [controls.first, controls.last],
                ),
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: controls,
          );
        },
      );
    },
  );
}

class _PlaybackIcon extends StatelessWidget {
  const _PlaybackIcon({required this.state, this.size = 24});
  final api.Playback state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      playbackWantsAudio(state)
          ? Icons.pause_rounded
          : Icons.play_arrow_rounded,
      size: size,
    );
    if (state is! api.Playback_Buffering) return icon;
    return SizedBox.square(
      dimension: size + 6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: IconTheme.of(context).color,
            ),
          ),
          Icon(Icons.pause_rounded, size: size * .72),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: mobile
        ? Listenable.merge([backend.currentTrack, backend.playback])
        : backend.currentTrack,
    builder: (context, _) {
      final track = backend.currentTrack.value;
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
                  track?.metadata.title ??
                      (mobile ? 'Загрузка композиции…' : 'Выберите композицию'),
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
                        ListenableBuilder(
                          listenable: Listenable.merge([
                            backend.playback,
                            backend.queue,
                            backend,
                          ]),
                          builder: (context, _) => IconButton(
                            tooltip: playbackWantsAudio(backend.playback.value)
                                ? 'Пауза'
                                : 'Воспроизвести',
                            onPressed:
                                backend.busy ||
                                    (backend.queue.value?.total ??
                                            BigInt.zero) ==
                                        BigInt.zero
                                ? null
                                : backend.togglePlayback,
                            icon: _PlaybackIcon(state: backend.playback.value),
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
                      SizedBox(
                        height: 28,
                        child: PlaybackProgress(backend: backend),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 144,
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
    required this.navigation,
  });
  final BackendController backend;
  final VoidCallback openQueue, openLyrics;
  final MusicNavigation navigation;
  @override
  State<FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<FullscreenPlayer> {
  double _drag = 0;
  bool _dragging = false;
  ColorScheme? _palette;
  (String, String?, Brightness)? _paletteKey;

  BackendController get b => widget.backend;

  api.Track _summary(content.TrackDetail detail) => api.Track(
    id: detail.id,
    revision: detail.revision,
    title: detail.metadata.title,
    artist: detail.metadata.artist,
    album: detail.metadata.album,
    durationMs: detail.metadata.durationMs,
    artworkDigest: detail.metadata.artworkDigest,
  );

  Future<void> _openTrackActions(content.TrackDetail detail) async {
    final before = widget.navigation.current;
    await showTrackActions(context, b, widget.navigation, _summary(detail));
    if (mounted &&
        widget.navigation.current != before &&
        ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _favorite(content.TrackDetail detail) => b.operate((op) async {
    b.commandResults.value = await edits.edit(
      sessionId: b.sessionId,
      operationId: await api.newOperationId(),
      entityId: detail.id,
      edit: const edits.LibraryEdit.favorite(setName: 'liked', value: true),
      operation: op,
    );
  });

  Widget _header() => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onVerticalDragUpdate: (details) => setState(() {
      _dragging = true;
      _drag = math.max(0, _drag + details.delta.dy);
    }),
    onVerticalDragEnd: (details) {
      if (_drag > 140 || (details.primaryVelocity ?? 0) > 700) {
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
      height: 56,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Свернуть плеер',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
          ),
          const Expanded(
            child: Text('Сейчас играет', textAlign: TextAlign.center),
          ),
          ListenableBuilder(
            listenable: Listenable.merge([b, b.currentTrack]),
            builder: (context, _) {
              final track = b.currentTrack.value;
              return IconButton(
                tooltip: 'Действия с композицией',
                onPressed: track == null || b.busy
                    ? null
                    : () => _openTrackActions(track),
                icon: const Icon(Icons.more_horiz),
              );
            },
          ),
        ],
      ),
    ),
  );

  Widget _artwork(
    content.TrackDetail? track,
    double size,
    Brightness brightness,
  ) {
    final identity = (
      track?.id ?? '',
      track?.metadata.artworkDigest,
      brightness,
    );
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (!b.busy &&
            (b.queue.value?.total ?? BigInt.zero) > BigInt.zero &&
            velocity.abs() > 250) {
          b.transport(
            velocity < 0
                ? const api.Transport.next()
                : const api.Transport.previous(),
          );
        }
      },
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: MusicArtwork(
            sessionId: b.sessionId,
            trackId: track?.id,
            digest: track?.metadata.artworkDigest,
            size: size,
            paletteBrightness: brightness,
            onColorScheme: (scheme) {
              final current = b.currentTrack.value;
              if (!mounted ||
                  current?.id != identity.$1 ||
                  current?.metadata.artworkDigest != identity.$2) {
                return;
              }
              setState(() {
                _paletteKey = identity;
                _palette = scheme;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _controls(BuildContext context, content.TrackDetail? track) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track?.metadata.title ?? 'Загрузка композиции…',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track?.metadata.artist ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            ListenableBuilder(
              listenable: b,
              builder: (context, _) => IconButton(
                tooltip: 'Добавить в любимые',
                onPressed: track == null || b.busy
                    ? null
                    : () => _favorite(track),
                icon: const Icon(Icons.favorite_border, size: 28),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder(
          valueListenable: b.playback,
          builder: (context, state, _) {
            final status = switch (state) {
              api.Playback_Buffering() => 'Буферизация…',
              api.Playback_Failed() => 'Не удалось воспроизвести композицию',
              _ => null,
            };
            return status == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(status, style: theme.textTheme.labelMedium),
                  );
          },
        ),
        PlaybackProgress(backend: b, showRemaining: true),
        const SizedBox(height: 12),
        TransportControls(backend: b, large: true),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: widget.openLyrics,
              icon: const Icon(Icons.lyrics_outlined),
              label: const Text('Текст песни'),
            ),
            TextButton.icon(
              onPressed: widget.openQueue,
              icon: const Icon(Icons.queue_music),
              label: const Text('Очередь'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final baseTheme = Theme.of(context);
    return AnimatedContainer(
      duration: _dragging || reduced
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, _drag, 0),
      child: ValueListenableBuilder(
        valueListenable: b.currentTrack,
        builder: (context, track, _) {
          final key = (
            track?.id ?? '',
            track?.metadata.artworkDigest,
            baseTheme.brightness,
          );
          final scheme = _paletteKey == key ? _palette : null;
          return AnimatedTheme(
            data: scheme == null
                ? baseTheme
                : baseTheme.copyWith(
                    colorScheme: scheme,
                    scaffoldBackgroundColor: scheme.surface,
                    iconTheme: IconThemeData(color: scheme.onSurface),
                  ),
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 240),
            child: Scaffold(
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    final wide = width >= 720 || (width >= 600 && height < 500);
                    final available = math.max(80.0, width - 32);
                    final size = wide
                        ? math.min(
                            available * .44,
                            math.max(160.0, height - 104),
                          )
                        : math.min(
                            math.min(available, 440.0),
                            math.max(160.0, height * .44),
                          );
                    return SingleChildScrollView(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: wide ? 1040 : 520,
                            minHeight: height,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _header(),
                                if (wide)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      _artwork(
                                        track,
                                        size,
                                        baseTheme.brightness,
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        child: _controls(context, track),
                                      ),
                                    ],
                                  )
                                else ...[
                                  const SizedBox(height: 12),
                                  _artwork(track, size, baseTheme.brightness),
                                  const SizedBox(height: 24),
                                  _controls(context, track),
                                ],
                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
