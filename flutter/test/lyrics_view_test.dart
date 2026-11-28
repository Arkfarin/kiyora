import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kiyora/core/bridge/generated/api.dart' as api;
import 'package:kiyora/core/bridge/generated/api/auth.dart' as auth;
import 'package:kiyora/core/bridge/generated/api/content.dart' as content;
import 'package:kiyora/core/bridge/generated/frb_generated.dart';
import 'package:kiyora/core/state/backend_controller.dart';
import 'package:kiyora/core/theme/kiyora_theme.dart';
import 'package:kiyora/features/lyrics/lyrics_view.dart';

import 'backend_controller_test.dart' show TestApi;

class LyricsApi extends TestApi {
  final reads = <(String, Completer<content.Lyrics?>)>[];
  final seeks = <api.Transport>[];
  int embeddedReads = 0;
  @override
  Future<content.Lyrics?> crateApiContentEmbeddedLyrics({
    required String sessionId,
    required String trackId,
    required auth.Operation operation,
  }) async {
    embeddedReads++;
    return const content.Lyrics(
      lines: [content.LyricLine(text: 'Original embedded text')],
    );
  }

  @override
  Future<content.Lyrics?> crateApiContentLyrics({
    required String sessionId,
    required String trackId,
    required auth.Operation operation,
  }) {
    final reply = Completer<content.Lyrics?>();
    reads.add((trackId, reply));
    return reply.future;
  }

  @override
  Future<api.Playback> crateApiControl({
    required String sessionId,
    required api.Transport action,
  }) async {
    seeks.add(action);
    return playbackState;
  }
}

void main() {
  late LyricsApi native;
  late BackendController backend;
  setUp(() {
    native = LyricsApi();
    RustLib.initMock(api: native);
    backend = BackendController()..session = TestApi.session;
  });
  tearDown(() async {
    await backend.close();
    RustLib.dispose();
  });
  void play(String id) {
    native.playbackState = api.Playback.playing(
      trackId: id,
      positionMs: BigInt.zero,
      durationMs: BigInt.from(10000),
    );
    backend.playback.value = native.playbackState;
  }

  Widget page() => MaterialApp(
    theme: kiyoraTheme(Brightness.dark),
    home: Scaffold(body: LyricsView(backend: backend)),
  );
  content.Lyrics lyrics(String text, {bool timed = false}) => content.Lyrics(
    lines: [
      content.LyricLine(text: text, startMs: timed ? BigInt.from(1000) : null),
    ],
  );

  testWidgets(
    'library changes refresh lyrics without changing the playing track',
    (tester) async {
      play('one');
      await tester.pumpWidget(page());
      await tester.pump();
      native.reads.single.$2.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Для этой композиции пока нет текста'), findsOneWidget);
      backend.libraryRevision.value++;
      await tester.pump();
      expect(native.reads.length, 2);
      native.reads.last.$2.complete(lyrics('Now available'));
      await tester.pumpAndSettle();
      expect(find.text('Now available'), findsOneWidget);
      expect(find.text('Для этой композиции пока нет текста'), findsNothing);
      await tester.tap(find.text('Now available'));
      expect(native.seeks, isEmpty, reason: 'plain lyrics must not seek');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'late lyrics from a previous track cannot overwrite the current song',
    (tester) async {
      play('one');
      await tester.pumpWidget(page());
      await tester.pump();
      play('two');
      await tester.pump();
      native.reads.last.$2.complete(lyrics('Second', timed: true));
      await tester.pumpAndSettle();
      native.reads.first.$2.complete(lyrics('First'));
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('First'), findsNothing);
      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      expect(
        native.seeks.single,
        api.Transport.seek(milliseconds: BigInt.from(1000)),
      );
      backend.playback.value = const api.Playback.idle();
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsNothing);
      expect(
        find.text('Включите композицию, чтобы увидеть текст'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a failed read can be retried and a disposed panel ignores late replies',
    (tester) async {
      play('one');
      await tester.pumpWidget(page());
      await tester.pump();
      native.reads.single.$2.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Не удалось загрузить текст. Повторить'));
      await tester.pump();
      expect(native.reads.length, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      native.reads.last.$2.complete(lyrics('Late'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('embedded lyrics are read only after an explicit request', (
    tester,
  ) async {
    play('old-import');
    await tester.pumpWidget(page());
    await tester.pump();
    native.reads.single.$2.complete(null);
    await tester.pumpAndSettle();
    expect(native.embeddedReads, 0);
    await tester.tap(find.text('Проверить текст в аудиофайле'));
    await tester.pumpAndSettle();
    expect(native.embeddedReads, 1);
    expect(find.text('Original embedded text'), findsOneWidget);
    expect(find.text('Оригинальный текст из тегов аудиофайла'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
