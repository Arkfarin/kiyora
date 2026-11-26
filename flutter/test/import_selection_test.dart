import 'dart:async';
import 'dart:io';

import 'package:kiyora/features/imports/import_draft_store.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kiyora/core/bridge/generated/api/jobs.dart' as jobs;
import 'package:kiyora/core/bridge/generated/frb_generated.dart';
import 'package:kiyora/core/state/backend_controller.dart';
import 'package:kiyora/features/imports/import_selection.dart';
import 'package:kiyora/features/imports/import_view.dart';

import 'backend_controller_test.dart' show TestApi;

class MemoryDraftStore extends ImportDraftStore {
  MemoryDraftStore() : super(File('/unused-test-store'));
  List<Map<String, dynamic>> data = [];
  @override
  Future<List<Map<String, dynamic>>> read() async => data;
  @override
  Future<void> write(List<Map<String, Object?>> drafts) async {
    data = drafts.map((d) => Map<String, dynamic>.from(d)).toList();
  }
}

class ImportApi extends TestApi {
  int nextId = 0;
  final calls = <(String, String, List<jobs.ImportFile>)>[];
  Completer<void>? firstBatch;
  bool fail = false;
  @override
  Future<String> crateApiNewOperationId() async => 'id-${nextId++}';
  @override
  Future<List<jobs.Job>> crateApiJobsList({required String sessionId}) async =>
      [];
  @override
  Future<jobs.Job> crateApiJobsImportFiles({
    required String sessionId,
    required String jobId,
    required List<jobs.ImportFile> files,
  }) async {
    calls.add((sessionId, jobId, files));
    if (calls.length == 1) await firstBatch?.future;
    if (fail) throw StateError('reply lost');
    return jobs.Job(
      id: jobId,
      state: jobs.JobState.running,
      completed: BigInt.zero,
      total: BigInt.from(files.length),
      files: [],
    );
  }
}

void main() {
  late ImportApi native;
  late BackendController backend;
  late ImportSelection selection;
  setUp(() {
    native = ImportApi();
    RustLib.initMock(api: native);
    backend = BackendController()..session = TestApi.session;
    selection = ImportSelection(backend, store: MemoryDraftStore());
  });
  tearDown(() async {
    selection.dispose();
    await backend.close();
    RustLib.dispose();
  });

  testWidgets(
    'navigation retains selection and submits every batch after leaving import',
    (tester) async {
      await selection.select(List.generate(1001, (i) => '/music/$i.flac'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImportView(backend: backend, selection: selection),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Выбрано файлов: 1001'), findsOneWidget);
      native.firstBatch = Completer<void>();
      final sending = selection.send();
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      native.firstBatch!.complete();
      await sending;
      expect(native.calls.map((call) => call.$3.length), [1000, 1]);
      expect(
        native.calls.expand((call) => call.$3).map((file) => file.path).toSet(),
        hasLength(1001),
      );
      expect(selection.files, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  test('uncertain response retains exact batch identity on retry', () async {
    await selection.select(['/music/one.flac']);
    native.fail = true;
    await selection.send();
    expect(selection.retrying, isTrue);
    selection.clear();
    expect(selection.files, hasLength(1));
    native.fail = false;
    await selection.send();
    expect(native.calls[1].$2, native.calls[0].$2);
    expect(native.calls[1].$3, native.calls[0].$3);
    expect(selection.files, isEmpty);
  });

  test('rapid submission starts only one job', () async {
    await selection.select(['/music/one.flac']);
    await Future.wait([selection.send(), selection.send()]);
    expect(native.calls, hasLength(1));
  });
}
