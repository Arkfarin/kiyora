import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kiyora/core/bridge/generated/api.dart' as api;
import 'package:kiyora/core/bridge/generated/frb_generated.dart';
import 'package:kiyora/core/routing/navigation.dart';
import 'package:kiyora/core/state/backend_controller.dart';
import 'package:kiyora/core/theme/kiyora_theme.dart';
import 'package:kiyora/features/library/library_view.dart';

import 'backend_controller_test.dart' show TestApi;
import 'desktop_shell_test.dart' show EmptyLibrary;

class _FilteredApi extends EmptyLibrary {
  final requests = <(String?, bool, api.TrackSort, int, int)>[];
  final tracks = [
    for (var i = 0; i < 85; i++)
      api.Track(
        id: '$i',
        revision: '1',
        title: 'Song ${(84 - i).toString().padLeft(2, '0')}',
        artist: 'Artist',
        album: 'Album',
        durationMs: BigInt.from(180000),
      ),
  ];
  bool hasDownloads = true;

  @override
  Future<List<api.Track>> crateApiLibrary({
    required String sessionId,
    String? query,
    required int offset,
    required int limit,
  }) async => tracks.skip(offset).take(limit).toList();

  @override
  Future<List<api.Track>> crateApiLibraryFiltered({
    required String sessionId,
    String? query,
    required bool downloadedOnly,
    required api.TrackSort sort,
    required int offset,
    required int limit,
  }) async {
    expect(sessionId, 'session');
    requests.add((query, downloadedOnly, sort, offset, limit));
    final selected = tracks
        .where(
          (t) =>
              (!downloadedOnly || (hasDownloads && t.id != '0')) &&
              t.title.contains(query ?? ''),
        )
        .toList();
    if (sort == api.TrackSort.title) {
      selected.sort((a, b) => a.title.compareTo(b.title));
    }
    return selected.skip(offset).take(limit).toList();
  }
}

void main() {
  testWidgets(
    'downloaded filter and sort send backend parameters before paging',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final native = _FilteredApi();
      RustLib.initMock(api: native);
      final backend = BackendController()..session = TestApi.session;
      final nav = MusicNavigation();
      final bucket = PageStorageBucket();
      addTearDown(() async {
        await backend.close();
        nav.dispose();
        RustLib.dispose();
      });
      Widget app({LibraryFilter filter = LibraryFilter.tracks}) => MaterialApp(
        theme: kiyoraTheme(Brightness.dark),
        home: Scaffold(
          body: PageStorage(
            bucket: bucket,
            child: LibraryView(
              backend: backend,
              navigation: nav,
              location: const MusicLocation(Destination.library),
              mobile: true,
              initialFilter: filter,
            ),
          ),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(native.requests, isEmpty); // Existing order keeps legacy endpoint.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Скачанные'));
      await tester.pumpAndSettle();
      expect(native.requests.last, ('', true, api.TrackSort.existing, 0, 80));
      expect(find.text('Song 83'), findsOneWidget);
      expect(find.text('Song 84'), findsNothing);
      await tester.tap(find.byTooltip('Сортировка'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<api.TrackSort>, 'По названию'),
      );
      await tester.pumpAndSettle();
      expect(native.requests.last, ('', true, api.TrackSort.title, 0, 80));
      expect(find.text('Song 00'), findsOneWidget);
      final more = find.text('Показать ещё');
      final scroll = find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        more,
        500,
        scrollable: scroll,
        maxScrolls: 30,
      );
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(native.requests.last, ('', true, api.TrackSort.title, 80, 80));
      await tester.scrollUntilVisible(
        find.text('Song 83'),
        250,
        scrollable: scroll,
        maxScrolls: 5,
      );
      expect(find.text('Song 83'), findsOneWidget);
      tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Song 01');
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(native.requests.last, (
        'Song 01',
        true,
        api.TrackSort.title,
        0,
        80,
      ));
      expect(find.text('Song 01'), findsWidgets);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      native.hasDownloads = false;
      backend.libraryRevision.value++;
      await tester.pumpAndSettle();
      expect(find.text('Нет скачанных композиций'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(app(filter: LibraryFilter.downloaded));
      await tester.pumpAndSettle();
      expect(native.requests.last, ('', true, api.TrackSort.title, 0, 80));
      await tester.tap(find.text('Все композиции'));
      await tester.pumpAndSettle();
      expect(native.requests.last, ('', false, api.TrackSort.title, 0, 80));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
