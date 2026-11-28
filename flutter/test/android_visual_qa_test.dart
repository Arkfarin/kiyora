// Opt-in host-rendered visual QA, not an Android emulator/device test.
// From flutter/: KIYORA_VISUAL_QA=1 flutter test test/android_visual_qa_test.dart
// Optional KIYORA_QA_FONT=/path/to/regular.ttf (Cyrillic-capable).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kiyora/app/music_shell.dart';
import 'package:kiyora/core/bridge/generated/api.dart' as api;
import 'package:kiyora/core/bridge/generated/api/auth.dart' as auth;
import 'package:kiyora/core/bridge/generated/api/content.dart' as content;
import 'package:kiyora/core/bridge/generated/api/edits.dart' as edits;
import 'package:kiyora/core/bridge/generated/api/vault.dart' as vault;
import 'package:kiyora/core/bridge/generated/frb_generated.dart';
import 'package:kiyora/core/state/backend_controller.dart';
import 'package:kiyora/core/theme/kiyora_theme.dart';
import 'package:kiyora/features/player/player.dart';

import 'desktop_shell_test.dart' show EmptyLibrary;

const _session = api.Session(
  profileId: 'qa-profile',
  sessionId: 'qa-session',
  vaultId: 'qa-vault',
);

class _Fixture extends EmptyLibrary {
  final covers = <String, Uint8List>{};
  final tracks = [
    for (final (i, title, artist, album) in [
      (0, 'Ночной город', 'Север', 'Свет фонарей'),
      (1, 'Neon Skyline', 'Northbound', 'After Hours'),
      (2, 'Тихие улицы', 'Север', 'Свет фонарей'),
      (3, 'Neon Rain', 'Mira', 'City Lights'),
      (4, 'A Place Beyond the Horizon', 'Glass Ocean', 'Daybreak'),
      (5, 'Не отпускай', 'Маяк', 'Волны'),
      (6, 'Neon Echoes', 'Northbound', 'After Hours'),
      (7, 'Soft Landing', 'Mira', 'City Lights'),
      (8, 'Снова дома', 'Маяк', 'Волны'),
      (9, 'Distant Signals', 'Glass Ocean', 'Daybreak'),
    ])
      api.Track(
        id: 'fixture-$i',
        revision: '1',
        title: title,
        artist: artist,
        album: album,
        durationMs: BigInt.from(190000 + i * 10000),
        artworkDigest: i == 5 ? null : 'cover-$i',
      ),
  ];

  Future<void> makeCovers() async {
    const palette = [
      Color(0xff714762),
      Color(0xff274b73),
      Color(0xff4e705e),
      Color(0xff9e4350),
      Color(0xff887649),
    ];
    for (var i = 0; i < tracks.length; i++) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..color = palette[i % palette.length];
      canvas.drawRect(const Rect.fromLTWH(0, 0, 192, 192), paint);
      paint.color = const Color(0xff161a2b);
      canvas.drawRect(Rect.fromLTWH(0, 112 + i * 3, 192, 80), paint);
      paint.color = const Color(0xffffc3a0);
      canvas.drawCircle(Offset(52.0 + i * 8, 72), 36, paint);
      paint.color = const Color(0xffeed9d1).withValues(alpha: .65);
      canvas.drawRect(Rect.fromLTWH(16 + i * 3, 136, 72, 3), paint);
      canvas.drawRect(const Rect.fromLTWH(16, 146, 35, 2), paint);
      final picture = recorder.endRecording();
      final cover = await picture.toImage(192, 192);
      final bytes = await cover.toByteData(format: ui.ImageByteFormat.png);
      covers[tracks[i].id] = bytes!.buffer.asUint8List();
      cover.dispose();
      picture.dispose();
    }
  }

  @override
  Future<List<api.Track>> crateApiLibrary({
    required String sessionId,
    String? query,
    required int offset,
    required int limit,
  }) async => tracks
      .where(
        (t) => '${t.title} ${t.artist} ${t.album}'.toLowerCase().contains(
          (query ?? '').toLowerCase(),
        ),
      )
      .skip(offset)
      .take(limit)
      .toList();

  @override
  Future<List<content.Playlist>> crateApiContentPlaylists({
    required String sessionId,
    String? query,
    required int offset,
    required int limit,
  }) async =>
      const [
            content.Playlist(
              id: 'p1',
              title: 'Вечерняя прогулка',
              revision: '1',
            ),
            content.Playlist(id: 'p2', title: 'В дороге', revision: '1'),
            content.Playlist(id: 'p3', title: 'Focus mix', revision: '1'),
          ]
          .where(
            (p) => p.title.toLowerCase().contains((query ?? '').toLowerCase()),
          )
          .skip(offset)
          .take(limit)
          .toList();

  @override
  Future<List<content.Album>> crateApiContentAlbums({
    required String sessionId,
    required String query,
    required int offset,
    required int limit,
  }) async =>
      [
            for (final album in tracks.map((t) => t.album).toSet())
              content.Album(
                title: album,
                artist: tracks.firstWhere((t) => t.album == album).artist,
                trackCount: BigInt.from(
                  tracks.where((t) => t.album == album).length,
                ),
              ),
          ]
          .where((a) => a.title.toLowerCase().contains(query.toLowerCase()))
          .skip(offset)
          .take(limit)
          .toList();

  @override
  Future<List<content.Artist>> crateApiContentArtists({
    required String sessionId,
    required String query,
    required int offset,
    required int limit,
  }) async =>
      [
            for (final artist in tracks.map((t) => t.artist).toSet())
              content.Artist(
                name: artist,
                trackCount: BigInt.from(
                  tracks.where((t) => t.artist == artist).length,
                ),
              ),
          ]
          .where((a) => a.name.toLowerCase().contains(query.toLowerCase()))
          .skip(offset)
          .take(limit)
          .toList();

  @override
  Future<List<api.Track>> crateApiContentRecentlyPlayed({
    required String sessionId,
    required int limit,
  }) async => tracks.take(4).take(limit).toList();

  @override
  Future<edits.TrackPage> crateApiEditsFavorites({
    required String sessionId,
    required String setName,
    required int offset,
    required int limit,
  }) async => edits.TrackPage(
    total: BigInt.from(3),
    offset: offset,
    tracks: tracks.skip(2).take(3).skip(offset).take(limit).toList(),
  );

  @override
  Future<content.Artwork?> crateApiContentArtwork({
    required String sessionId,
    required String trackId,
    required auth.Operation operation,
  }) async => covers[trackId] == null
      ? null
      : content.Artwork(
          mimeType: 'image/png',
          digest: 'cover-$trackId',
          bytes: covers[trackId]!,
        );

  content.TrackDetail detail(api.Track t) => content.TrackDetail(
    id: t.id,
    revision: t.revision,
    sources: const [content.Source(id: 'source')],
    preferredSourceId: 'source',
    metadata: content.Metadata(
      title: t.title,
      artist: t.artist,
      album: t.album,
      albumArtist: t.artist,
      durationMs: t.durationMs,
      year: 2024,
      genre: 'Electronic',
      trackNumber: 1,
      discNumber: 1,
      bitrate: 320000,
      codec: 'mp3',
      composer: '',
      comment: '',
      copyright: '',
      artworkDigest: t.artworkDigest,
    ),
  );
}

void main() {
  testWidgets('render Android phone screens with explicit fixture data', (
    tester,
  ) async {
    final fixture = _Fixture();
    final boundary = GlobalKey();
    final out = Directory('../qa-results/android-ui');
    final font = File(
      Platform.environment['KIYORA_QA_FONT'] ??
          '/usr/share/fonts/noto/NotoSans-Regular.ttf',
    );
    final fontAvailable = font.existsSync();
    await tester.runAsync(() async {
      out.createSync(recursive: true);
      // flutter_test does not automatically install MaterialIcons; without
      // this the real controls render as missing-glyph squares.
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      if (fontAvailable) {
        final loader = FontLoader('QA Sans')
          ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
        if (Platform.environment['KIYORA_QA_FONT'] == null) {
          for (final weight in ['Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
            final variant = File('/usr/share/fonts/noto/NotoSans-$weight.ttf');
            if (variant.existsSync()) {
              loader.addFont(
                Future.value(ByteData.sublistView(variant.readAsBytesSync())),
              );
            }
          }
        }
        await loader.load();
      }
      await fixture.makeCovers();
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    RustLib.initMock(api: fixture);
    final backend = BackendController()
      ..session = _session
      ..starting = false
      ..profiles = const [
        api.Profile(id: 'qa-profile', label: 'Основной'),
        api.Profile(id: 'qa-other', label: 'Личный'),
      ]
      ..authorization = const auth.Authorization.ready()
      ..details = const vault.SessionDetails(
        session: _session,
        eventSequence: '0',
        apiConfigured: true,
        connection: 'ready',
        serviceRunning: true,
        repairRequired: false,
      )
      ..runtime = const vault.Status(
        session: _session,
        mode: vault.Mode.onlineReady,
      );
    final playing = fixture.tracks[0];
    backend.currentTrack.value = fixture.detail(playing);
    backend.queue.value = api.Queue(
      id: 'qa-queue',
      revision: BigInt.one,
      total: BigInt.from(fixture.tracks.length),
      position: BigInt.zero,
      currentTrackId: playing.id,
      shuffle: false,
      repeat: api.Repeat.off,
    );
    backend.playback.value = api.Playback.playing(
      trackId: playing.id,
      positionMs: BigInt.from(74000),
      durationMs: playing.durationMs,
    );
    addTearDown(() async {
      await backend.close();
      RustLib.dispose();
    });
    final baseTheme = kiyoraTheme(Brightness.dark);
    final theme = fontAvailable
        ? baseTheme.copyWith(
            textTheme: baseTheme.textTheme.apply(fontFamily: 'QA Sans'),
            primaryTextTheme: baseTheme.primaryTextTheme.apply(
              fontFamily: 'QA Sans',
            ),
          )
        : baseTheme;
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: MusicShell(
            backend: backend,
            themeMode: ThemeMode.dark,
            onThemeChanged: (_) {},
          ),
        ),
      ),
    );
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      // Real decoder work can outlive fake-async widget frames.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/$name.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    Finder tab(String name) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(name),
    );
    await capture('01-home');
    expect(find.text('Ваши плейлисты'), findsOneWidget);
    await tester.tap(tab('Поиск'));
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('mobile-global-search'));
    await tester.enterText(search, 'Neon');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.text('Neon Skyline'), findsOneWidget);
    expect(find.text('Тихие улицы'), findsNothing);
    await capture('02-search');
    await tester.tap(tab('Медиатека'));
    await tester.pumpAndSettle();
    expect(find.text('Ночной город'), findsWidgets);
    await capture('03-library');
    await tester.tap(find.byTooltip('Сменить профиль или выйти'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    expect(find.text('Основной'), findsOneWidget);
    await capture('04-settings');
    await tester.drag(find.byType(ListView).first, const Offset(0, -550));
    await tester.pumpAndSettle();
    expect(find.text('Хранилище и загрузки'), findsOneWidget);
    await capture('05-settings-storage');
    await tester.tap(
      find.descendant(
        of: find.byType(PlayerBar),
        matching: find.text(playing.title),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FullscreenPlayer), findsOneWidget);
    await capture('06-player');
    await tester.pumpWidget(const SizedBox.shrink());
    File('${out.path}/render-info.txt').writeAsStringSync(
      'Flutter host widget render; Android target override; 390x844 logical px, '
      '2x PNG capture, 24px simulated top/bottom safe areas; dark theme.\n'
      'Explicit mock profile, library, playback and synthetic covers; no device, '
      'emulator, Telegram or actual audio. Font: ${fontAvailable ? font.path : "test default (font unavailable)"}.\n'
      'Icons: bundled MaterialIcons font. Status/navigation safe areas are simulated, no OS system UI.\n',
    );
  }, skip: Platform.environment['KIYORA_VISUAL_QA'] != '1');
}
