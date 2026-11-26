import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiyora/core/bridge/generated/api/auth.dart' as auth;
import 'package:kiyora/core/bridge/generated/api/content.dart' as content;
import 'package:kiyora/core/bridge/generated/api/edits.dart' as edits;
import 'package:kiyora/core/bridge/generated/api/imports.dart' as imports;
import 'package:kiyora/core/bridge/generated/api/jobs.dart' as jobs;
import 'package:kiyora/core/bridge/generated/frb_generated.dart';
import 'package:kiyora/core/state/backend_controller.dart';
import 'package:kiyora/features/imports/import_draft.dart';
import 'package:kiyora/features/imports/import_draft_store.dart';
import 'package:kiyora/features/imports/import_selection.dart';

import 'backend_controller_test.dart' show TestApi;
import 'import_selection_test.dart' show ImportApi;

class EditorApi extends ImportApi {
  final staged = <String, imports.Preview>{};
  final committed = <String>[];
  int parses = 0;
  int discarded = 0;
  bool failCommit = false;
  bool failPreview = false;
  bool failParse = false;
  bool duplicate = false;
  Completer<void>? pending;
  edits.CommandState state = edits.CommandState.applied;
  edits.Command? receipt;

  @override
  Future<imports.Preview> crateApiImportsPreview({
    required String sessionId,
    required String previewId,
    required String path,
    required auth.Operation operation,
  }) async {
    final value = staged.putIfAbsent(
      previewId,
      () => imports.Preview(
        id: previewId,
        filename: path.split('/').last,
        metadata: content.Metadata(
          title: 'Original',
          artist: 'Artist',
          album: '',
          albumArtist: '',
          durationMs: BigInt.from(10000),
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
        digest: 'digest',
        sizeBytes: BigInt.from(1234),
        warnings: [],
      ),
    );
    if (failPreview) throw StateError('preview reply lost');
    return value;
  }

  @override
  Future<List<imports.Preview>> crateApiImportsPreviews({
    required String sessionId,
    required auth.Operation operation,
  }) async => staged.values.toList();
  @override
  Future<edits.Command?> crateApiEditsCommandStatus({
    required String sessionId,
    required String operationId,
  }) async => receipt;
  @override
  Future<void> crateApiImportsDiscard({
    required String sessionId,
    required String previewId,
    required auth.Operation operation,
  }) async {
    discarded++;
    staged.remove(previewId);
  }

  @override
  Future<content.Lyrics> crateApiContentParseLyrics({
    required String text,
    required String format,
  }) async {
    parses++;
    if (failParse) throw const FormatException('invalid lyrics');
    return content.Lyrics(
      language: 'ru',
      lines: [
        content.LyricLine(
          startMs: BigInt.from(1000),
          endMs: BigInt.from(2000),
          text: text,
        ),
      ],
    );
  }

  @override
  Future<imports.ImportResult> crateApiImportsCommit({
    required String sessionId,
    required String previewId,
    required String trackId,
    required String sourceId,
    edits.MetadataEdit? edit,
    required bool writeTags,
    required bool allowDuplicate,
    required auth.Operation operation,
  }) async {
    committed.add(
      jsonEncode({
        'preview': previewId,
        'track': trackId,
        'source': sourceId,
        'payload': PreparedRequest(edit!, writeTags).toJson(),
        'allowDuplicate': allowDuplicate,
      }),
    );
    await pending?.future;
    if (failCommit) throw StateError('commit reply lost');
    if (duplicate && !allowDuplicate) {
      return imports.ImportResult.review(
        review: jobs.ImportReview(
          title: edit.title!,
          artist: '',
          album: '',
          digest: '',
          sizeBytes: BigInt.one,
          duplicateTrackIds: ['existing'],
          possibleDuplicateTrackIds: [],
        ),
      );
    }
    receipt = edits.Command(
      operationId: previewId,
      entityId: trackId,
      state: state,
    );
    return imports.ImportResult.command(command: receipt!);
  }
}

class FailingStore extends ImportDraftStore {
  FailingStore(super.file);
  bool fail = false;
  @override
  Future<void> write(List<Map<String, Object?>> drafts) => fail
      ? Future.error(const FileSystemException('disk full'))
      : super.write(drafts);
}

void main() {
  late Directory temporary;
  late FailingStore store;
  late EditorApi native;
  late BackendController backend;
  late ImportSelection selection;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('kiyora-editor-test-');
    store = FailingStore(File('${temporary.path}/drafts.json'));
    native = EditorApi();
    RustLib.initMock(api: native);
    backend = BackendController()..session = TestApi.session;
    selection = ImportSelection(backend, store: store);
  });
  tearDown(() async {
    await selection.saveDrafts();
    selection.dispose();
    await backend.close();
    RustLib.dispose();
    await temporary.delete(recursive: true);
  });
  Future<ImportDraft> prepare() async {
    await selection.select(['/one.flac', '/two.flac']);
    await selection.prepare(selection.files.first);
    return selection.drafts.single;
  }

  test(
    'prepared files never enter raw batches, even after preview reply loss',
    () async {
      native.failPreview = true;
      final draft = await prepare();
      expect(draft.preview, isNull);
      await selection.send();
      expect(native.calls.single.$3.single.path, '/two.flac');
      native.failPreview = false;
      await selection.retryPreview(draft);
      expect(native.staged.keys, [draft.id]);
    },
  );

  test('lost reply and restart retain exact IDs, artwork, parsed lyrics and payload', () async {
    final draft = await prepare();
    selection.update(draft, (d) {
      d.fields['title'] = 'Edited';
      d.artwork = Uint8List.fromList([1, 2, 3]);
      d.replaceLyrics = true;
      d.lyricsText = '[00:01]Text';
      d.writeTags = true;
    });
    native.failCommit = true;
    await selection.submit(draft);
    expect(draft.locked, isTrue);
    expect(draft.applied, isFalse);
    selection.update(draft, (d) => d.fields['title'] = 'Changed');
    await selection.discard(draft);
    expect(native.discarded, 0);
    selection.dispose();
    selection = ImportSelection(backend, store: store);
    await selection.restore();
    final restored = selection.drafts.single;
    expect(restored.fields['title'], 'Edited');
    native.failCommit = false;
    await selection.submit(restored);
    expect(native.committed[1], native.committed[0]);
    expect(native.parses, 1);
    expect(restored.applied, isTrue);
  });

  test(
    'unsubmitted draft restores edits and reuses staged file after restart',
    () async {
      final draft = await prepare();
      selection.update(draft, (d) => d.fields['album'] = 'New album');
      await selection.saveDrafts();
      selection.dispose();
      selection = ImportSelection(backend, store: store);
      await selection.restore();
      expect(selection.drafts.single.preview, isNotNull);
      expect(selection.drafts.single.fields['album'], 'New album');
      expect(selection.drafts.single.locked, isFalse);
      await selection.select(['/one.flac', '/three.flac']);
      expect(selection.files.map((f) => f.path), ['/three.flac']);
    },
  );

  test(
    'lost duplicate confirmation cannot discard an uncertain import',
    () async {
      final draft = await prepare();
      native.duplicate = true;
      await selection.submit(draft);
      expect(draft.review, isNotNull);
      native.failCommit = true;
      await selection.submit(draft, confirmDuplicate: true);
      expect(draft.review, isNull);
      expect(draft.allowDuplicate, isTrue);
      await selection.discard(draft);
      expect(native.discarded, 0);
      selection.dispose();
      selection = ImportSelection(backend, store: store);
      await selection.restore();
      native.failCommit = false;
      await selection.submit(selection.drafts.single);
      expect(native.committed[2], native.committed[1]);
      expect(selection.drafts.single.applied, isTrue);
    },
  );

  test(
    'attachment selection validates lyrics and fences concurrent submission',
    () async {
      final draft = await prepare();
      final selected = Completer<Uint8List?>();
      final loading = selection.loadArtwork(draft, () => selected.future);
      await selection.submit(draft);
      expect(native.committed, isEmpty);
      selected.complete(Uint8List.fromList([1, 2, 3]));
      await loading;
      expect(draft.artwork, [1, 2, 3]);
      await selection.loadLyrics(
        draft,
        () async => (text: 'New lyrics', format: 'plain'),
      );
      expect(draft.lyricsText, 'New lyrics');
      expect(draft.lyricsFormat, 'plain');
      native.failParse = true;
      await selection.loadLyrics(
        draft,
        () async => (text: 'Broken', format: 'lrc'),
      );
      expect(draft.lyricsText, 'New lyrics');
      expect(draft.locked, isFalse);
      await selection.loadArtwork(draft, () async => null);
      expect(draft.artwork, [1, 2, 3]);
    },
  );

  test('duplicate confirmation only changes allowDuplicate', () async {
    final draft = await prepare();
    native.duplicate = true;
    await selection.submit(draft);
    expect(draft.applied, isFalse);
    expect(draft.review!.duplicateTrackIds, ['existing']);
    await selection.submit(draft, confirmDuplicate: true);
    final first = jsonDecode(native.committed[0]) as Map;
    final second = jsonDecode(native.committed[1]) as Map;
    expect(second.remove('allowDuplicate'), isTrue);
    expect(first.remove('allowDuplicate'), isFalse);
    expect(second, first);
    expect(draft.applied, isTrue);
  });

  test(
    'non-applied backend command remains locked and is not success',
    () async {
      final draft = await prepare();
      native.state = edits.CommandState.serverAck;
      await selection.submit(draft);
      expect(draft.applied, isFalse);
      expect(selection.drafts, [draft]);
      backend.commandResults.value = edits.Command(
        operationId: draft.id,
        entityId: draft.trackId,
        state: edits.CommandState.applied,
      );
      expect(draft.applied, isTrue);
    },
  );

  test(
    'failed durable write prevents native commit and is retryable',
    () async {
      final draft = await prepare();
      store.fail = true;
      await selection.submit(draft);
      expect(native.committed, isEmpty);
      expect(selection.saveError, isNotNull);
      store.fail = false;
      await selection.submit(draft);
      expect(native.committed, hasLength(1));
    },
  );

  test('invalid metadata and lyric parsing keep draft editable', () async {
    final draft = await prepare();
    selection.update(draft, (d) => d.fields['year'] = '-1');
    await selection.submit(draft);
    expect(draft.locked, isFalse);
    selection.update(draft, (d) {
      d.fields['year'] = '2026';
      d.replaceLyrics = true;
    });
    native.failParse = true;
    await selection.submit(draft);
    expect(draft.locked, isFalse);
    expect(native.committed, isEmpty);
  });

  test(
    'cancellation of an in-flight request retains a frozen recovery draft',
    () async {
      final draft = await prepare();
      native.pending = Completer<void>();
      native.failCommit = true;
      final pending = selection.submit(draft);
      while (native.committed.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      await backend.cancel();
      expect(native.operation.cancelled, isTrue);
      native.pending!.complete();
      await pending;
      expect(draft.locked, isTrue);
      expect(draft.applied, isFalse);
      expect(await store.read(), hasLength(1));
    },
  );

  test(
    'discard awaits backend, removes draft and never resubmits it as raw',
    () async {
      final draft = await prepare();
      await selection.discard(draft);
      expect(native.discarded, 1);
      expect(selection.drafts, isEmpty);
      expect(await store.read(), isEmpty);
      expect(selection.files.single.path, '/two.flac');
    },
  );

  test(
    'backend-only previews are locked instead of inventing a request',
    () async {
      final draft = await prepare();
      await store.write([]);
      selection.dispose();
      selection = ImportSelection(backend, store: store);
      await selection.restore();
      expect(selection.drafts.single.id, draft.id);
      expect(selection.drafts.single.recoveredWithoutRequest, isTrue);
      selection.update(
        selection.drafts.single,
        (d) => d.fields['title'] = 'Unsafe',
      );
      expect(selection.drafts.single.fields['title'], 'Original');
    },
  );

  test('corrupt recovery file fails closed without overwriting it', () async {
    await store.file.writeAsString('{invalid');
    await selection.restore();
    expect(backend.error, isNotNull);
    await selection.select(['/one.flac']);
    expect(selection.files, isEmpty);
    expect(await store.file.readAsString(), '{invalid');
    await store.write([]);
  });
}
