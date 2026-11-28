import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../bridge/generated/api/auth.dart' as auth;
import '../bridge/generated/api/content.dart' as content;

class MusicArtwork extends StatefulWidget {
  const MusicArtwork({
    super.key,
    required this.sessionId,
    required this.trackId,
    this.digest,
    this.size = 48,
    this.round = false,
    this.paletteBrightness,
    this.onColorScheme,
  });
  final String sessionId;
  final String? trackId;
  final String? digest;
  final double size;
  final bool round;
  final Brightness? paletteBrightness;
  final ValueChanged<ColorScheme>? onColorScheme;
  @override
  State<MusicArtwork> createState() => _MusicArtworkState();
}

class _MusicArtworkState extends State<MusicArtwork> {
  auth.Operation? _operation;
  Future<content.Artwork?>? _image;
  int _generation = 0;
  int _paletteGeneration = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MusicArtwork old) {
    super.didUpdateWidget(old);
    if (old.sessionId != widget.sessionId ||
        old.trackId != widget.trackId ||
        old.digest != widget.digest)
      _load();
    else if (old.paletteBrightness != widget.paletteBrightness ||
        (old.onColorScheme == null && widget.onColorScheme != null)) {
      _extractPalette();
    }
  }

  void _load() {
    final generation = ++_generation;
    unawaited(_operation?.cancel());
    _operation = null;
    final session = widget.sessionId;
    final track = widget.trackId;
    _image = track == null || widget.digest == null
        ? null
        : () async {
            final operation = await auth.Operation.newInstance();
            if (!mounted || generation != _generation) {
              await operation.cancel();
              return null;
            }
            _operation = operation;
            return content.artwork(
              sessionId: session,
              trackId: track,
              operation: operation,
            );
          }();
    _extractPalette();
  }

  void _extractPalette() {
    final paletteGeneration = ++_paletteGeneration;
    final image = _image;
    final brightness = widget.paletteBrightness;
    if (image == null || brightness == null || widget.onColorScheme == null) {
      return;
    }
    unawaited(() async {
      try {
        final artwork = await image;
        if (artwork == null ||
            !mounted ||
            paletteGeneration != _paletteGeneration)
          return;
        final scheme = await ColorScheme.fromImageProvider(
          provider: MemoryImage(artwork.bytes),
          brightness: brightness,
        );
        if (mounted && paletteGeneration == _paletteGeneration) {
          widget.onColorScheme?.call(scheme);
        }
      } catch (_) {
        // An unavailable cover is already handled by the fallback widget.
      }
    }());
  }

  @override
  void dispose() {
    _generation++;
    _paletteGeneration++;
    unawaited(_operation?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(widget.round ? widget.size : 4),
      child: FutureBuilder<content.Artwork?>(
        key: ValueKey(_generation),
        future: _image,
        builder: (context, snapshot) {
          final artwork = snapshot.data;
          if (artwork != null)
            return Image.memory(
              artwork.bytes,
              fit: BoxFit.cover,
              cacheWidth: (widget.size * MediaQuery.devicePixelRatioOf(context))
                  .ceil()
                  .clamp(64, 1200),
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => _fallback(context),
            );
          return _fallback(context);
        },
      ),
    ),
  );
  Widget _fallback(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Icon(
      widget.round ? Icons.person_outline : Icons.music_note_rounded,
      size: widget.size * .38,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
