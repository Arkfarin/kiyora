import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kiyora/core/bridge/generated/api.dart' as api;
import 'package:kiyora/core/bridge/generated/api/content.dart' as content;
import 'package:kiyora/core/bridge/generated/frb_generated.dart';
import 'package:kiyora/core/state/backend_controller.dart';
import 'package:kiyora/features/queue/queue_view.dart';
import 'package:kiyora/features/player/player.dart';
import 'package:kiyora/features/settings/settings_view.dart';

import 'backend_controller_test.dart' show TestApi;

final testQueue = api.Queue(
  id: 'queue',
  revision: BigInt.one,
  total: BigInt.from(3),
  shuffle: false,
  repeat: api.Repeat.off,
);

class QueueApi extends TestApi {
  @override
  Future<api.QueuePage> crateApiQueue({
    required String sessionId,
    required int offset,
    required int limit,
  }) async => api.QueuePage(
    queue: testQueue,
    offset: offset,
    trackIds: ['first', 'second', 'third'].skip(offset).take(limit).toList(),
  );
  @override
  Future<content.TrackDetail?> crateApiContentTrack({
    required String sessionId,
    required String trackId,
  }) async => null;
}

class RecordingController extends BackendController {
  final moves = <api.QueueEdit>[];
  final transports = <api.Transport>[];
  final selectedProfiles = <String>[];
  @override
  Future<void> editQueue(api.QueueEdit edit) async {
    moves.add(edit);
  }

  @override
  Future<void> transport(api.Transport command) async {
    transports.add(command);
  }

  @override
  Future<void> chooseProfile(String id) async {
    selectedProfiles.add(id);
    session = api.Session(profileId: id, sessionId: 'session');
    notifyListeners();
  }
}

void main() {
  late RecordingController backend;
  setUp(() {
    RustLib.initMock(api: QueueApi());
    backend = RecordingController()..session = TestApi.session;
    backend.queue.value = testQueue;
  });
  tearDown(() async {
    await backend.close();
    RustLib.dispose();
  });

  api.Playback playing(String id) => api.Playback.playing(
    trackId: id,
    positionMs: BigInt.from(1000),
    durationMs: BigInt.from(10000),
  );

  testWidgets('seek is discarded after track changes during drag', (
    tester,
  ) async {
    backend.playback.value = playing('first');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlaybackProgress(backend: backend)),
      ),
    );
    final slider = find.byType(Slider);
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await gesture.moveBy(const Offset(50, 0));
    await tester.pump();
    backend.playback.value = playing('second');
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(backend.transports, isEmpty);
    expect(tester.widget<Slider>(slider).value, 1000);
    await tester.tap(slider);
    await tester.pumpAndSettle();
    expect(backend.transports, hasLength(1));
    expect(backend.transports.single, isA<api.Transport_Seek>());
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('busy state disables seek and mini player pause', (tester) async {
    backend.playback.value = playing('first');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PlaybackProgress(backend: backend),
              PlayerBar(
                backend: backend,
                mobile: true,
                openPlayer: () {},
                openQueue: () {},
                openLyrics: () {},
              ),
            ],
          ),
        ),
      ),
    );
    final slider = find.byType(Slider);
    final pause = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Пауза',
    );
    expect(tester.widget<IconButton>(pause).onPressed, isNotNull);
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await gesture.moveBy(const Offset(50, 0));
    await tester.pump();
    backend.busy = true;
    backend.clearError();
    await tester.pump();
    expect(tester.widget<Slider>(slider).onChanged, isNull);
    expect(tester.widget<IconButton>(pause).onPressed, isNull);
    backend.busy = false;
    backend.clearError();
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(backend.transports, isEmpty);
    await tester.tap(pause);
    await tester.pumpAndSettle();
    expect(backend.transports, [const api.Transport.pause()]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final (from, to) in [(0, 2), (2, 0)]) {
    testWidgets('desktop drag sends queue move $from to $to', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: QueueView(backend: backend)),
        ),
      );
      await tester.pumpAndSettle();
      final handles = find.byType(ReorderableDragStartListener);
      final destination = to > from
          ? Offset(
              tester.getCenter(handles.at(to)).dx,
              tester.getBottomLeft(find.byType(ReorderableListView)).dy - 24,
            )
          : tester.getCenter(handles.at(to)) - const Offset(0, 30);
      final gesture = await tester.startGesture(
        tester.getCenter(handles.at(from)),
      );
      await gesture.moveBy(Offset(0, to > from ? 24 : -24));
      await tester.pump();
      await gesture.moveTo(destination);
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(backend.moves, [api.QueueEdit.move(from: from, to: to)]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'profile radio group supports keyboard selection and busy guard',
    (tester) async {
      backend.profiles = const [
        api.Profile(id: 'profile', label: 'First profile'),
        api.Profile(id: 'second', label: 'Second profile'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsView(
              backend: backend,
              themeMode: ThemeMode.system,
              onThemeChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(backend.selectedProfiles, ['second']);
      backend.busy = true;
      backend.clearError(); // Notify the screen of the in-flight command.
      await tester.pumpAndSettle();
      await tester.tap(find.text('First profile'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(backend.selectedProfiles, ['second']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
