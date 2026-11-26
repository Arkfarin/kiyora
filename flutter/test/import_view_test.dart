import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kiyora/core/bridge/generated/api/edits.dart' as edits;
import 'package:kiyora/core/bridge/generated/frb_generated.dart';
import 'package:kiyora/core/state/backend_controller.dart';
import 'package:kiyora/features/imports/import_selection.dart';
import 'package:kiyora/features/imports/import_view.dart';

import 'backend_controller_test.dart' show TestApi;
import 'import_editor_test.dart' show EditorApi;
import 'import_selection_test.dart' show MemoryDraftStore;

void main() {
  late EditorApi native;
  late BackendController backend;
  late ImportSelection selection;
  setUp(() {
    native = EditorApi();
    RustLib.initMock(api: native);
    backend = BackendController()..session = TestApi.session;
    selection = ImportSelection(backend, store: MemoryDraftStore());
  });
  tearDown(() async {
    selection.dispose();
    await backend.close();
    RustLib.dispose();
  });
  Widget page() => MaterialApp(
    home: Scaffold(
      body: ImportView(backend: backend, selection: selection),
    ),
  );
  Future<void> click(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'prepares selected file and restores edited fields after navigation',
    (tester) async {
      await selection.select(['/one.flac']);
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      await click(tester, find.byTooltip('Редактировать перед импортом'));
      expect(selection.files, isEmpty);
      final draft = selection.drafts.single;
      final title = find.byKey(ValueKey('import-${draft.id}-title'));
      await tester.ensureVisible(title);
      await tester.enterText(title, 'My edited song');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      await tester.ensureVisible(title);
      expect(
        tester.widget<TextFormField>(title).initialValue,
        'My edited song',
      );
      expect(native.committed, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('duplicate decision and server acknowledgement are not success', (
    tester,
  ) async {
    await selection.select(['/one.flac']);
    await selection.prepare(selection.files.single);
    native.duplicate = true;
    native.state = edits.CommandState.serverAck;
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await click(tester, find.text('Импортировать с изменениями'));
    expect(find.text('Импорт подтверждён'), findsNothing);
    expect(find.text('Импортировать дубликат'), findsOneWidget);
    await click(tester, find.text('Импортировать дубликат'));
    expect(find.text('Импорт подтверждён'), findsNothing);
    final draft = selection.drafts.single;
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(ValueKey('import-${draft.id}-title')),
          )
          .enabled,
      isFalse,
    );
    backend.commandResults.value = edits.Command(
      operationId: draft.id,
      entityId: draft.trackId,
      state: edits.CommandState.applied,
    );
    await tester.pumpAndSettle();
    expect(find.text('Импорт подтверждён'), findsOneWidget);
    await click(tester, find.text('Убрать из черновиков'));
    expect(selection.drafts, isEmpty);
    expect(native.discarded, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cancelled wait keeps retry request and displays the error', (
    tester,
  ) async {
    await selection.select(['/one.flac']);
    await selection.prepare(selection.files.single);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    native.pending = Completer<void>();
    native.failCommit = true;
    final submit = find.text('Импортировать с изменениями');
    await tester.ensureVisible(submit);
    await tester.pump();
    await tester.tap(submit);
    // The mocked native request deliberately remains pending.
    await tester.pump();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Отменить ожидание'),
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.text('Отменить ожидание'));
    await tester.pump();
    expect(native.operation.cancelled, isTrue);
    native.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('commit reply lost'), findsOneWidget);
    expect(selection.drafts.single.locked, isTrue);
    expect(find.text('Импорт подтверждён'), findsNothing);
    native.failCommit = false;
    await click(tester, find.text('Повторить отправку'));
    expect(native.committed[1], native.committed[0]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [400.0, 720.0, 1280.0]) {
    testWidgets('editor fields and attachment controls fit width $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 720);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await selection.select(['/one.flac']);
      await selection.prepare(selection.files.single);
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      await click(tester, find.text('Удалить обложку'));
      expect(selection.drafts.single.clearArtwork, isTrue);
      await click(tester, find.text('Исходная обложка'));
      expect(selection.drafts.single.clearArtwork, isFalse);
      await click(tester, find.text('Сохранить встроенный текст'));
      await tester.tap(find.text('Заменить текст').last);
      await tester.pumpAndSettle();
      expect(selection.drafts.single.replaceLyrics, isTrue);
      await tester.ensureVisible(find.byType(SwitchListTile));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
