import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiyora/features/imports/import_draft_store.dart';

void main() {
  late Directory root;
  setUp(
    () async => root = await Directory.systemTemp.createTemp('kiyora-drafts-'),
  );
  tearDown(() async => root.delete(recursive: true));

  test('new session reads the previous session final queued save', () async {
    final file = File('${root.path}/drafts.json');
    final oldSession = ImportDraftStore(file);
    final newSession = ImportDraftStore(file);
    await oldSession.write([
      {'title': 'old'},
    ]);
    final pending = oldSession.write([
      {'title': 'latest'},
    ]);
    expect(await newSession.read(), [
      {'title': 'latest'},
    ]);
    await pending;
  });

  test(
    'stores for one profile serialize saves and snapshot mutable fields',
    () async {
      final file = File('${root.path}/drafts.json');
      final first = ImportDraftStore(file), second = ImportDraftStore(file);
      final fields = {'title': 'captured'};
      final a = first.write([
        {'fields': fields},
      ]);
      fields['title'] = 'later mutation';
      await a;
      expect((await second.read()).single['fields'], {'title': 'captured'});
      final writes = [
        for (var i = 0; i < 20; i++)
          (i.isEven ? first : second).write([
            {'n': i},
          ]),
      ];
      await Future.wait(writes);
      expect(await first.read(), [
        {'n': 19},
      ]);
      expect(await File('${file.path}.tmp').exists(), isFalse);
    },
  );

  test(
    'a failed write neither destroys the prior file nor poisons retries',
    () async {
      final file = File('${root.path}/drafts.json');
      final first = ImportDraftStore(file);
      await first.write([
        {'title': 'preserved'},
      ]);
      final blocker = Directory('${file.path}.tmp');
      await blocker.create();
      await expectLater(first.write([]), throwsA(isA<FileSystemException>()));
      final second = ImportDraftStore(file);
      expect(await second.read(), [
        {'title': 'preserved'},
      ]);
      await blocker.delete();
      await second.write([
        {'title': 'retried'},
      ]);
      expect(await first.read(), [
        {'title': 'retried'},
      ]);
    },
  );
}
