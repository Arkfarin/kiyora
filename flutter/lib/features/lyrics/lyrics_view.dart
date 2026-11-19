import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../core/bridge/generated/api/auth.dart' as auth;
import '../../core/bridge/generated/api/content.dart' as content;
import '../../core/bridge/generated/api.dart' as api;
import '../../core/state/backend_controller.dart';
import '../player/player.dart';

class LyricsView extends StatefulWidget {
  const LyricsView({super.key, required this.backend, this.transport = false});
  final BackendController backend;
  final bool transport;
  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final _scroll = ItemScrollController();
  auth.Operation? _operation;
  content.Lyrics? _lyrics;
  Object? _error;
  String? _track;
  int _active = -1;
  int _generation = 0;
  bool _loading = false;
  bool _follow = true;
  List<(int, int)> _timings = [];
  @override
  void initState() {
    super.initState();
    widget.backend.playback.addListener(_tick);
    _tick();
  }

  @override
  void dispose() {
    _generation++;
    widget.backend.playback.removeListener(_tick);
    unawaited(_operation?.cancel());
    super.dispose();
  }

  void _tick() {
    final id = playbackTrackId(widget.backend.playback.value);
    if (id != _track) {
      _track = id;
      _load();
      return;
    }
    final lines = _lyrics?.lines;
    if (lines == null || lines.isEmpty) return;
    final position = playbackTime(widget.backend.playback.value).$1;
    // Parsed timed documents are ordered by the Rust parser; untimed lines
    // never receive synthetic timestamps or a seek action.
    var low = 0;
    var high = _timings.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (_timings[middle].$1 <= position) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    var next = low == 0 ? -1 : _timings[low - 1].$2;
    if (next >= 0 &&
        lines[next].endMs != null &&
        position >= lines[next].endMs!.toInt())
      next = -1;
    if (next == _active) return;
    setState(() => _active = next);
    _followActive();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    await _operation?.cancel();
    if (!mounted || generation != _generation) return;
    setState(() {
      _lyrics = null;
      _timings = [];
      _error = null;
      _active = -1;
      _loading = _track != null;
      _follow = true;
    });
    final track = _track;
    if (track == null) return;
    try {
      final operation = await auth.Operation.newInstance();
      if (!mounted || generation != _generation) {
        await operation.cancel();
        return;
      }
      _operation = operation;
      final lyrics = await content.lyrics(
        sessionId: widget.backend.sessionId,
        trackId: track,
        operation: operation,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _lyrics = lyrics;
        _timings =
            [
              for (var i = 0; i < (lyrics?.lines.length ?? 0); i++)
                if (lyrics!.lines[i].startMs != null)
                  (lyrics.lines[i].startMs!.toInt(), i),
            ]..sort((a, b) {
              final time = a.$1.compareTo(b.$1);
              return time == 0 ? a.$2.compareTo(b.$2) : time;
            });
      });
      _tick();
    } catch (e) {
      if (mounted && generation == _generation) setState(() => _error = e);
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  void _followActive() {
    if (!_follow || _active < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.isAttached || !_follow || _active < 0) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(index: _active, alignment: .3);
      } else {
        _scroll.scrollTo(
          index: _active,
          alignment: .3,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lyrics?.lines ?? [];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Текст песни',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (!_follow && _active >= 0)
                IconButton(
                  tooltip: 'К текущей строке',
                  icon: const Icon(Icons.my_location),
                  onPressed: () {
                    setState(() => _follow = true);
                    _followActive();
                  },
                ),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: _error != null
              ? Center(
                  child: TextButton(
                    onPressed: _load,
                    child: const Text('Не удалось загрузить текст. Повторить'),
                  ),
                )
              : lines.isEmpty
              ? Center(
                  child: Text(
                    _loading
                        ? 'Загружаем текст…'
                        : 'Для этой композиции пока нет текста',
                  ),
                )
              : NotificationListener<UserScrollNotification>(
                  onNotification: (notification) {
                    if (notification.direction != ScrollDirection.idle &&
                        _follow)
                      setState(() => _follow = false);
                    return false;
                  },
                  child: ScrollablePositionedList.builder(
                    itemScrollController: _scroll,
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
                    itemCount: lines.length,
                    itemBuilder: (context, i) => Semantics(
                      selected: i == _active,
                      child: InkWell(
                        onTap: lines[i].startMs == null
                            ? null
                            : () {
                                setState(() => _follow = true);
                                widget.backend.transport(
                                  api.Transport.seek(
                                    milliseconds: lines[i].startMs!,
                                  ),
                                );
                              },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: AnimatedDefaultTextStyle(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 160),
                            style: Theme.of(context).textTheme.headlineSmall!
                                .copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.4,
                                  color:
                                      i == _active || lines[i].startMs == null
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                            child: Text(lines[i].text),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        if (widget.transport) ...[
          PlaybackProgress(backend: widget.backend),
          TransportControls(backend: widget.backend),
        ],
      ],
    );
  }
}
