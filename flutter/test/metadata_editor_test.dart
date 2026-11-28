import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kiyora/core/bridge/generated/api.dart' as api;
import 'package:kiyora/core/bridge/generated/api/auth.dart' as auth;
import 'package:kiyora/core/bridge/generated/api/content.dart' as content;
import 'package:kiyora/core/bridge/generated/api/edits.dart' as edits;
import 'package:kiyora/core/bridge/generated/frb_generated.dart';
import 'package:kiyora/core/routing/navigation.dart';
import 'package:kiyora/core/state/backend_controller.dart';
import 'package:kiyora/features/library/track_actions.dart';

import 'backend_controller_test.dart' show TestApi;

class _MetadataApi extends TestApi {
  int attempts = 0;
  final revisions = <String>[];

  @override
  Future<String> crateApiNewOperationId() async => 'op-${++attempts}';

  @override
  Future<edits.Command> crateApiEditsEditMetadata({
    required String sessionId,
    required String operationId,
    required String trackId,
    required edits.MetadataEdit edit,
    required auth.Operation operation,
  }) async {
    revisions.add(edit.expectedRevision!);
    return edits.Command(
      operationId: operationId,
      entityId: trackId,
      state: revisions.length == 1
          ? edits.CommandState.rejected
          : edits.CommandState.applied,
    );
  }

  @override
  Future<content.TrackDetail?> crateApiContentTrack({
    required String sessionId,
    required String trackId,
  }) async => content.TrackDetail(
    id: trackId,
    revision: 'rev-2',
    metadata: content.Metadata(
      title: 'Remote title',
      artist: 'Remote artist',
      album: 'Remote album',
      albumArtist: '',
      durationMs: BigInt.zero,
      year: 0,
      genre: '',
      trackNumber: 0,
      discNumber: 0,
      bitrate: 0,
      codec: 'flac',
      composer: '',
      comment: '',
      copyright: '',
    ),
    sources: [],
  );
}

void main() {
  testWidgets('rejected edit can reload current revision and be saved again', (
    tester,
  ) async {
    final native = _MetadataApi();
    RustLib.initMock(api: native);
    final backend = BackendController()..session = TestApi.session;
    final navigation = MusicNavigation();
    addTearDown(() async {
      await backend.close();
      navigation.dispose();
      RustLib.dispose();
    });
    final track = api.Track(
      id: 'track-id',
      revision: 'rev-1',
      title: 'Original',
      artist: 'Original artist',
      album: 'Original album',
      durationMs: BigInt.zero,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTrackActions(
                context,
                backend,
                navigation,
                track,
                anchor: const Offset(100, 100),
              ),
              child: const Text('Actions'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Редактировать данные'));
    await tester.pumpAndSettle();

    final title = find.byType(TextField).first;
    await tester.enterText(title, 'Edited title');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Загрузить актуальные данные'), findsOneWidget);
    expect(tester.widget<TextField>(title).enabled, isFalse);
    expect(native.revisions, ['rev-1']);

    await tester.tap(find.text('Загрузить актуальные данные'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(title).controller?.text, 'Remote title');
    expect(tester.widget<TextField>(title).enabled, isTrue);
    await tester.enterText(title, 'Edited again');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(native.revisions, ['rev-1', 'rev-2']);
    expect(find.text('Изменения сохранены'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
