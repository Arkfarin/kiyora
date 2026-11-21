import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyora/app/music_shell.dart';
import 'package:kiyora/core/bridge/generated/api.dart' as api;
import 'package:kiyora/core/bridge/generated/api/content.dart' as content;
import 'package:kiyora/core/bridge/generated/api/edits.dart' as edits;
import 'package:kiyora/core/bridge/generated/api/jobs.dart' as jobs;
import 'package:kiyora/features/imports/import_view.dart';
import 'package:kiyora/core/bridge/generated/frb_generated.dart';
import 'package:kiyora/core/state/backend_controller.dart';
import 'package:kiyora/core/theme/kiyora_theme.dart';
import 'package:kiyora/features/player/player.dart';
import 'backend_controller_test.dart' show TestApi;

class EmptyLibrary extends TestApi {
  @override
  Future<List<jobs.Job>> crateApiJobsList({required String sessionId}) async =>
      [];
  @override
  Future<List<api.Track>> crateApiLibrary({
    required String sessionId,
    String? query,
    required int offset,
    required int limit,
  }) async => [];
  @override
  Future<List<content.Playlist>> crateApiContentPlaylists({
    required String sessionId,
    String? query,
    required int offset,
    required int limit,
  }) async => [];
  @override
  Future<List<content.Album>> crateApiContentAlbums({
    required String sessionId,
    required String query,
    required int offset,
    required int limit,
  }) async => [];
  @override
  Future<List<content.Artist>> crateApiContentArtists({
    required String sessionId,
    required String query,
    required int offset,
    required int limit,
  }) async => [];
  @override
  Future<List<api.Track>> crateApiContentRecentlyPlayed({
    required String sessionId,
    required int limit,
  }) async => [];
  @override
  Future<edits.TrackPage> crateApiEditsFavorites({
    required String sessionId,
    required String setName,
    required int offset,
    required int limit,
  }) async => edits.TrackPage(total: BigInt.zero, offset: offset, tracks: []);
}

void main() {
  testWidgets('import opens and refreshes without async setState', (
    tester,
  ) async {
    RustLib.initMock(api: EmptyLibrary());
    final backend = BackendController()..session = TestApi.session;
    addTearDown(() async {
      await backend.close();
      RustLib.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ImportView(backend: backend)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    backend.jobRevision.value++;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final width in [720.0, 900.0, 1280.0, 1440.0]) {
    testWidgets('Linux desktop navigation and player at width $width', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 720);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final native = EmptyLibrary();
      RustLib.initMock(api: native);
      final backend = BackendController()..session = TestApi.session;
      addTearDown(() async {
        await backend.close();
        RustLib.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: kiyoraTheme(Brightness.dark),
          home: MusicShell(
            backend: backend,
            themeMode: ThemeMode.dark,
            onThemeChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(TransportControls), findsOneWidget);
      expect(find.byTooltip('Очередь'), findsOneWidget);
      await tester.tap(find.byTooltip('Очередь'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Добавьте музыку в очередь'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.byTooltip('Закрыть панель'));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('Поиск'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(backend.session, TestApi.session);
      expect(native.initializations, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
