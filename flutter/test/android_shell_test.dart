import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kiyora/app/music_shell.dart';
import 'package:kiyora/core/bridge/generated/api.dart' as api;
import 'package:kiyora/core/bridge/generated/api/content.dart' as content;
import 'package:kiyora/core/bridge/generated/frb_generated.dart';
import 'package:kiyora/core/state/backend_controller.dart';
import 'package:kiyora/core/theme/kiyora_theme.dart';

import 'backend_controller_test.dart' show TestApi;
import 'desktop_shell_test.dart' show EmptyLibrary;

class _SearchApi extends EmptyLibrary {
  _SearchApi({this.populated = false, this.trackCount = 1});
  final bool populated;
  final int trackCount;
  final searches = <(String, String)>[];
  final plays = <(List<String>, int)>[];
  final track = api.Track(
    id: 'track-one',
    revision: '1',
    title: 'Track One',
    artist: 'Artist',
    album: 'Album',
    durationMs: BigInt.from(180000),
  );

  @override
  Future<List<api.Track>> crateApiLibrary({
    required String sessionId,
    String? query,
    required int offset,
    required int limit,
  }) async {
    searches.add(('tracks', query ?? ''));
    if (!populated) return [];
    if (trackCount > 1) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return [
          track,
          for (var i = 1; i < trackCount; i++)
            api.Track(
              id: 'track-$i',
              revision: '1',
              title: 'Track $i',
              artist: 'Artist',
              album: 'Album',
              durationMs: BigInt.from(180000),
            ),
        ]
        .where(
          (t) => t.title.toLowerCase().contains((query ?? '').toLowerCase()),
        )
        .skip(offset)
        .take(limit)
        .toList();
  }

  @override
  Future<List<content.Playlist>> crateApiContentPlaylists({
    required String sessionId,
    String? query,
    required int offset,
    required int limit,
  }) async => populated
      ? [
          const content.Playlist(
            id: 'playlist',
            title: 'A playlist',
            revision: '1',
          ),
        ]
      : [];

  @override
  Future<api.Queue> crateApiPlay({
    required String sessionId,
    required List<String> trackIds,
    required int position,
  }) async {
    plays.add((trackIds, position));
    return api.Queue(
      id: 'queue',
      revision: BigInt.one,
      total: BigInt.from(trackIds.length),
      position: BigInt.from(position),
      currentTrackId: trackIds[position],
      shuffle: false,
      repeat: api.Repeat.off,
    );
  }

  @override
  Future<List<content.Album>> crateApiContentAlbums({
    required String sessionId,
    required String query,
    required int offset,
    required int limit,
  }) async {
    searches.add(('albums', query));
    return [];
  }
}

Future<_SearchApi> _mount(
  WidgetTester tester,
  Size size, {
  bool populated = false,
  int trackCount = 1,
}) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final native = _SearchApi(populated: populated, trackCount: trackCount);
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
  return native;
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets('Android home and search play actual library track IDs', (
    tester,
  ) async {
    final native = await _mount(tester, const Size(320, 740), populated: true);
    final title = find.text('Track One');
    await tester.ensureVisible(title);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Действия с композицией'), findsOneWidget);
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(native.plays.length, 1);
    expect(native.plays.single.$1, ['track-one']);
    expect(native.plays.single.$2, 0);
    await tester.tap(_tab('Поиск'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('mobile-global-search')),
      'Track',
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 250));
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(native.plays.length, 2);
    expect(native.plays.last.$1, ['track-one']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Android search is debounced and preserved across tabs', (
    tester,
  ) async {
    final native = await _mount(tester, const Size(390, 844));
    final search = find.byKey(const ValueKey('mobile-global-search'));
    await tester.tap(_tab('Поиск'));
    await tester.pumpAndSettle();
    expect(search, findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(search, 'Kiyora');
    await tester.pump(const Duration(milliseconds: 100));
    expect(native.searches, isNot(contains(('tracks', 'Kiyora'))));
    await tester.pumpAndSettle(const Duration(milliseconds: 250));
    expect(native.searches, contains(('tracks', 'Kiyora')));

    final albums = find.widgetWithText(ChoiceChip, 'Альбомы');
    await tester.ensureVisible(albums);
    await tester.tap(albums);
    await tester.pumpAndSettle();
    expect(native.searches, contains(('albums', 'Kiyora')));
    await tester.tap(_tab('Медиатека'));
    await tester.pumpAndSettle();
    expect(search, findsNothing);
    await tester.tap(_tab('Поиск'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(search).controller!.text, 'Kiyora');
    expect(tester.widget<TextField>(search).focusNode!.hasFocus, isFalse);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Альбомы'))
          .selected,
      isTrue,
    );
    await tester.tap(find.byTooltip('Очистить поиск'));
    await tester.pumpAndSettle();
    expect(native.searches.last, ('albums', ''));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Android library keeps its filter and detail tab selection', (
    tester,
  ) async {
    await _mount(tester, const Size(360, 740));
    await tester.tap(_tab('Медиатека'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Плейлисты'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Любимое'));
    await tester.pumpAndSettle();
    expect(find.text('Любимые композиции'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Плейлисты'))
          .selected,
      isTrue,
    );
    await tester.tap(_tab('Главная'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Любимое'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Android tablets use touch navigation even at desktop widths', (
    tester,
  ) async {
    await _mount(tester, const Size(1280, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('Свернуть медиатеку'), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Поиск'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mobile-global-search')), findsOneWidget);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsNothing);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const ValueKey('mobile-global-search')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Android search restores scroll on tab return and resets on query change',
    (tester) async {
      await _mount(
        tester,
        const Size(390, 844),
        populated: true,
        trackCount: 40,
      );
      final search = find.byKey(const ValueKey('mobile-global-search'));
      final list = find.byType(CustomScrollView);
      double offset() =>
          tester.widget<CustomScrollView>(list).controller!.offset;
      await tester.tap(_tab('Поиск'));
      await tester.pumpAndSettle();
      await tester.enterText(search, 'Track');
      await tester.pumpAndSettle(const Duration(milliseconds: 250));
      await tester.drag(list, const Offset(0, -700));
      await tester.pumpAndSettle();
      final previousOffset = offset();
      expect(previousOffset, greaterThan(300));

      await tester.tap(_tab('Медиатека'));
      await tester.pumpAndSettle();
      await tester.tap(_tab('Поиск'));
      await tester.pumpAndSettle();
      expect(offset(), closeTo(previousOffset, 1));

      await tester.enterText(search, 'One');
      await tester.pumpAndSettle(const Duration(milliseconds: 250));
      expect(offset(), 0);
      expect(find.text('Track One'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Android home show all tracks clears unrelated library filters', (
    tester,
  ) async {
    await _mount(tester, const Size(390, 844), populated: true);
    await tester.tap(_tab('Медиатека'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Плейлисты'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'different');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));
    await tester.tap(_tab('Главная'));
    await tester.pumpAndSettle();
    final showAll = find.text('Показать всё');
    await tester.ensureVisible(showAll);
    await tester.tap(showAll);
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Композиции'))
          .selected,
      isTrue,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.text('Track One'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
