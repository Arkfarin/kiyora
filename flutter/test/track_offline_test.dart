import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kiyora/core/bridge/generated/api.dart' as api;
import 'package:kiyora/core/bridge/generated/api/auth.dart' as auth;
import 'package:kiyora/core/bridge/generated/api/content.dart' as content;
import 'package:kiyora/core/bridge/generated/api/offline.dart' as offline;
import 'package:kiyora/core/bridge/generated/frb_generated.dart';
import 'package:kiyora/core/routing/navigation.dart';
import 'package:kiyora/core/state/backend_controller.dart';
import 'package:kiyora/features/library/track_actions.dart';
import 'package:kiyora/features/library/track_offline.dart';

import 'backend_controller_test.dart' show TestApi, TestOperation;

class _OfflineApi extends TestApi {
  int ids = 0;
  int downloads = 0;
  int cancels = 0;
  final operations = <TestOperation>[];
  final calls = <(String, String, String)>[];
  final pins = <bool>[];
  bool cached = false;
  bool pinned = false;
  bool hasSources = true;
  String? jobId;
  offline.Availability jobState = offline.Availability.downloading;
  int downloadedBytes = 0;
  Completer<content.TrackDetail?>? delayedDetail;
  Completer<void>? delayedStart;
  bool failStart = false;

  @override
  Future<String> crateApiNewOperationId() async => 'op-${++ids}';

  @override
  Future<auth.Operation> crateApiAuthOperationNew() async {
    final operation = TestOperation();
    operations.add(operation);
    return operation;
  }

  @override
  Future<content.TrackDetail?> crateApiContentTrack({
    required String sessionId,
    required String trackId,
  }) async => delayedDetail != null
      ? await delayedDetail!.future
      : content.TrackDetail(
          id: trackId,
          revision: '1',
          metadata: content.Metadata(
            title: 'Track',
            artist: 'Artist',
            album: '',
            albumArtist: '',
            durationMs: BigInt.zero,
            year: 0,
            genre: '',
            trackNumber: 0,
            discNumber: 0,
            bitrate: 0,
            codec: '',
            composer: '',
            comment: '',
            copyright: '',
          ),
          preferredSourceId: 'preferred',
          sources: hasSources
              ? const [
                  content.Source(id: 'other'),
                  content.Source(id: 'preferred'),
                ]
              : const [],
        );

  offline.Download result(String id, String trackId) => offline.Download(
    id: id,
    trackId: trackId,
    state: id == jobId
        ? jobState
        : cached
        ? offline.Availability.fullyCached
        : offline.Availability.remoteOnly,
    bytesDownloaded: BigInt.from(
      id == jobId
          ? downloadedBytes
          : cached
          ? 2048
          : 0,
    ),
    totalBytes: id == jobId || cached ? BigInt.from(2048) : null,
    // Simulate Rust retaining the original pin bit on completed jobs.
    pinned: id == jobId ? true : pinned,
  );

  @override
  Future<offline.Download> crateApiOfflineStatus({
    required String sessionId,
    required String downloadId,
    required String trackId,
    required String sourceId,
    required auth.Operation operation,
  }) async {
    calls.add((sessionId, trackId, sourceId));
    return result(downloadId, trackId);
  }

  @override
  Future<offline.Download> crateApiOfflineDownload({
    required String sessionId,
    required String downloadId,
    required String trackId,
    required String sourceId,
    required bool pinned,
    required auth.Operation operation,
  }) async {
    calls.add((sessionId, trackId, sourceId));
    expect(pinned, isTrue);
    downloads++;
    if (failStart) throw StateError('start failed');
    jobId = downloadId;
    jobState = offline.Availability.downloading;
    await delayedStart?.future;
    return result(downloadId, trackId);
  }

  @override
  Future<offline.Download> crateApiOfflineCancel({
    required String sessionId,
    required String downloadId,
    required auth.Operation operation,
  }) async {
    expect(sessionId, 'session');
    expect(downloadId, jobId);
    cancels++;
    return result(downloadId, 'track');
  }

  @override
  Future<void> crateApiOfflinePin({
    required String sessionId,
    required String trackId,
    required String sourceId,
    required bool pinned,
    required auth.Operation operation,
  }) async {
    calls.add((sessionId, trackId, sourceId));
    pins.add(pinned);
    this.pinned = pinned;
  }
}

Future<BackendController> _mount(
  WidgetTester tester,
  _OfflineApi native, {
  bool menu = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  RustLib.initMock(api: native);
  final backend = BackendController()..session = TestApi.session;
  final nav = MusicNavigation();
  addTearDown(() async {
    await backend.close();
    nav.dispose();
    RustLib.dispose();
  });
  final track = api.Track(
    id: 'track',
    revision: '1',
    title: 'Track',
    artist: 'Artist',
    album: '',
    durationMs: BigInt.zero,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => menu
                ? showTrackActions(context, backend, nav, track)
                : showTrackOffline(context, backend, track),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  return backend;
}

Future<void> _open(WidgetTester tester, {bool menu = false}) async {
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  if (menu) {
    await tester.tap(find.text('Офлайн-доступ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  testWidgets(
    'track action downloads preferred source, resumes progress on reopen, unpins live cache',
    (tester) async {
      final native = _OfflineApi();
      final backend = await _mount(tester, native, menu: true);
      await _open(tester, menu: true);
      expect(find.text('Не скачано'), findsOneWidget);
      await _tap(tester, 'Скачать');
      expect(find.text('Загрузка…'), findsOneWidget);
      expect(native.downloads, 1);
      expect(backend.busy, isFalse);
      native.downloadedBytes = 1024;
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('1.0 КБ / 2.0 КБ'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        .5,
      );
      await _tap(tester, 'Закрыть');
      await _open(tester, menu: true);
      expect(find.text('Загрузка…'), findsOneWidget);
      expect(native.downloads, 1);
      native.jobState = offline.Availability.fullyCached;
      native.cached = true;
      native.pinned = true;
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('Сохранено для офлайн-доступа'), findsOneWidget);
      await _tap(tester, 'Убрать из офлайн-доступа');
      expect(
        find.text('В кэше, может быть удалено автоматически'),
        findsOneWidget,
      );
      await _tap(tester, 'Сохранить для офлайн-доступа');
      expect(find.text('Сохранено для офлайн-доступа'), findsOneWidget);
      expect(native.pins, [false, true]);
      expect(
        native.calls.every((c) => c == ('session', 'track', 'preferred')),
        isTrue,
      );
      expect(native.operations.every((op) => op.cancelled), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancellation waits for backend confirmation and retry uses a new job ID',
    (tester) async {
      final native = _OfflineApi();
      await _mount(tester, native);
      await _open(tester);
      await _tap(tester, 'Скачать');
      final original = native.jobId;
      await _tap(tester, 'Отменить загрузку');
      expect(native.cancels, 1);
      expect(find.text('Отмена загрузки…'), findsOneWidget);
      native.jobState = offline.Availability.cancelled;
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('Загрузка отменена'), findsOneWidget);
      await _tap(tester, 'Продолжить загрузку');
      expect(native.downloads, 2);
      expect(native.jobId, isNot(original));
      expect(find.text('Загрузка…'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'no source disables downloading; stale profile cannot query cache',
    (tester) async {
      final native = _OfflineApi()..hasSources = false;
      final backend = await _mount(tester, native);
      await _open(tester);
      expect(
        find.text('Для этой композиции нет доступного источника аудио.'),
        findsOneWidget,
      );
      expect(find.text('Скачать'), findsNothing);
      await _tap(tester, 'Закрыть');
      native.delayedDetail = Completer<content.TrackDetail?>();
      await _open(tester);
      backend.session = const api.Session(
        profileId: 'other',
        sessionId: 'other-session',
      );
      backend.notifyListeners();
      native.delayedDetail!.complete(null);
      await tester.pump();
      expect(
        find.text('Активный профиль изменился. Откройте трек заново.'),
        findsOneWidget,
      );
      expect(native.calls, isEmpty);
      expect(native.downloads, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('failed start displays error and permits a fresh download', (
    tester,
  ) async {
    final native = _OfflineApi()..failStart = true;
    await _mount(tester, native);
    await _open(tester);
    await _tap(tester, 'Скачать');
    expect(find.textContaining('start failed'), findsOneWidget);
    native.failStart = false;
    await _tap(tester, 'Скачать');
    expect(native.downloads, 2);
    expect(find.text('Загрузка…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('closing during startup keeps one job and allows playback', (
    tester,
  ) async {
    final native = _OfflineApi()..delayedStart = Completer<void>();
    final backend = await _mount(tester, native);
    await _open(tester);
    await _tap(tester, 'Скачать');
    expect(native.downloads, 1);
    expect(backend.busy, isFalse);
    await _tap(tester, 'Закрыть');
    await backend.togglePlayback();
    expect(backend.busy, isFalse);
    await _open(tester);
    expect(native.downloads, 1);
    native.delayedStart!.complete();
    await tester.pump();
    expect(find.text('Загрузка…'), findsOneWidget);
    expect(native.downloads, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
