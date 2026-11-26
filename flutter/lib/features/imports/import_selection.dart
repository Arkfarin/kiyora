import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/bridge/generated/api.dart' as api;
import '../../core/bridge/generated/api/jobs.dart' as jobs;
import '../../core/bridge/generated/api/content.dart' as content;
import '../../core/bridge/generated/api/edits.dart' as edits;
import '../../core/bridge/generated/api/imports.dart' as imports;
import 'import_draft.dart';
import 'import_draft_store.dart';
import '../../core/state/backend_controller.dart';

/// Unsubmitted UI selection belongs to the session, not the current route.
/// Accepted jobs and their progress remain authoritative in Rust.
class ImportSelection extends ChangeNotifier {
  ImportSelection(this.backend, {ImportDraftStore? store})
    : sessionId = backend.sessionId,
      store =
          store ??
          ImportDraftStore.forProfile(
            backend.session!.profileId,
            backend.session!.vaultId,
          ) {
    backend.commandResults.addListener(_commandChanged);
  }
  final ImportDraftStore store;
  final List<ImportDraft> _drafts = [];
  List<ImportDraft> get drafts => List.unmodifiable(_drafts);
  bool _loaded = false;
  bool restored = false;
  Object? saveError;
  Timer? _saveTimer;
  bool get _active => !_disposed && backend.session?.sessionId == sessionId;

  Future<void> _load() async {
    if (_loaded) return;
    final saved = await store.read();
    final loaded = saved.map(ImportDraft.fromJson).toList();
    if (!_active) return;
    _drafts.addAll(loaded);
    _loaded = true;
  }

  Future<void> _save() async {
    _saveTimer?.cancel();
    try {
      await store.write(_drafts.map((d) => d.toJson()).toList());
      saveError = null;
    } catch (e) {
      saveError = e;
      rethrow;
    } finally {
      if (_active) notifyListeners();
    }
  }

  void _commandChanged() {
    final command = backend.commandResults.value;
    if (!_active || command == null) return;
    for (final draft in _drafts) {
      if (draft.id == command.operationId && draft.locked) {
        draft.command = command;
        notifyListeners();
      }
    }
  }

  Future<void> restore() => backend.operate((operation) async {
    await _load();
    if (!_active) return;
    final previews = await imports.previews(
      sessionId: sessionId,
      operation: operation,
    );
    if (!_active) return;
    for (final preview in previews) {
      var matches = _drafts.where((d) => d.id == preview.id);
      if (matches.isEmpty) {
        // An older UI may have submitted this preview. Without its frozen
        // request we must never invent new IDs or send different metadata.
        _drafts.add(
          ImportDraft(
            id: preview.id,
            trackId: '',
            sourceId: '',
            path: '',
            filename: preview.filename,
          )..recoveredWithoutRequest = true,
        );
        matches = _drafts.where((d) => d.id == preview.id);
      }
      matches.first.attach(preview);
    }
    for (final draft in _drafts.where((d) => d.locked)) {
      draft.command = await edits.commandStatus(
        sessionId: sessionId,
        operationId: draft.id,
      );
      if (!_active) return;
    }
    restored = true;
    await _save();
  });

  Future<void> prepare(jobs.ImportFile file) =>
      backend.operate((operation) async {
        await _load();
        if (!_active || retrying || !_files.contains(file)) return;
        final draft = ImportDraft.fromFile(file);
        _drafts.add(draft);
        _files.removeWhere(
          (candidate) => candidate.path == file.path,
        ); // Reserved before any await: never enter a raw batch.
        notifyListeners();
        await _save();
        if (!_active) return;
        draft.attach(
          await imports.preview(
            sessionId: sessionId,
            previewId: draft.id,
            path: draft.path,
            operation: operation,
          ),
        );
        if (_active) await _save();
      });

  Future<void> retryPreview(ImportDraft draft) =>
      backend.operate((operation) async {
        if (!_active || draft.locked || !_drafts.contains(draft)) return;
        await _save();
        draft.attach(
          await imports.preview(
            sessionId: sessionId,
            previewId: draft.id,
            path: draft.path,
            operation: operation,
          ),
        );
        if (_active) await _save();
      });

  void update(ImportDraft draft, void Function(ImportDraft) change) {
    if (!_active || backend.busy || draft.locked || !_drafts.contains(draft))
      return;
    change(draft);
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), () async {
      try {
        await _save();
      } catch (_) {
        /* Shown inline; submission retries saving. */
      }
    });
  }

  Future<void> saveDrafts() => backend.action(() async {
    await _load();
    if (_active) await _save();
  });

  Future<void> submit(
    ImportDraft draft, {
    bool confirmDuplicate = false,
  }) => backend.operate((operation) async {
    if (!_active || !_drafts.contains(draft) || draft.applied) return;
    if (draft.recoveredWithoutRequest) {
      final result = await imports.resume(
        sessionId: sessionId,
        operationId: draft.id,
        operation: operation,
      );
      if (_active) _result(draft, result);
      return;
    }
    if (draft.request == null) {
      if (draft.preview == null) throw StateError('Сначала подготовьте файл');
      final f = Map<String, String>.of(draft.fields);
      if ((f['title'] ?? '').trim().isEmpty)
        throw const FormatException('Укажите название');
      for (final value in f.values) {
        if (utf8.encode(value).length > 4096 || value.contains('\u0000')) {
          throw const FormatException(
            'Слишком длинное поле или недопустимый символ',
          );
        }
      }
      int number(String key) {
        final value = int.tryParse(f[key] ?? '');
        if (value == null || value < 0 || value > 4294967295) {
          throw const FormatException(
            'Год и номера должны быть целыми числами от 0 до 4294967295',
          );
        }
        return value;
      }

      final year = number('year'),
          track = number('trackNumber'),
          disc = number('discNumber');
      final lyrics = draft.replaceLyrics && !draft.clearLyrics
          ? await content.parseLyrics(
              text: draft.lyricsText,
              format: draft.lyricsFormat,
            )
          : null;
      if (!_active) return;
      final edit = edits.MetadataEdit(
        title: f['title'],
        artist: f['artist'],
        album: f['album'],
        albumArtist: f['albumArtist'],
        year: year,
        genre: f['genre'],
        trackNumber: track,
        discNumber: disc,
        composer: f['composer'],
        comment: f['comment'],
        copyright: f['copyright'],
        artwork: draft.artwork,
        clearArtwork: draft.clearArtwork,
        lyrics: lyrics,
        clearLyrics: draft.clearLyrics,
      );
      // Round trip makes deep immutable copies of bytes and parsed lyric lines.
      draft.request = PreparedRequest.fromJson(
        jsonDecode(jsonEncode(PreparedRequest(edit, draft.writeTags).toJson()))
            as Map<String, dynamic>,
      );
    }
    if (confirmDuplicate) {
      if (draft.review == null)
        throw StateError('Дубликат ещё не подтверждён backend');
      draft.allowDuplicate =
          true; // Only this flag is excluded from the fingerprint.
    }
    await _save(); // Fail closed: no native commit without a durable exact request.
    if (!_active) return;
    final request = draft.request!;
    final result = await imports.commit(
      sessionId: sessionId,
      previewId: draft.id,
      trackId: draft.trackId,
      sourceId: draft.sourceId,
      edit: request.edit,
      writeTags: request.writeTags,
      allowDuplicate: draft.allowDuplicate,
      operation: operation,
    );
    if (_active) _result(draft, result);
  });

  void _result(ImportDraft draft, imports.ImportResult result) {
    switch (result) {
      case imports.ImportResult_Review(:final review):
        draft.review = review;
        draft.command = null;
      case imports.ImportResult_Command(:final command):
        draft.command = command;
        draft.review = null;
        if (command.state == edits.CommandState.applied)
          backend.libraryRevision.value++;
    }
    notifyListeners();
  }

  Future<void> discard(ImportDraft draft) => backend.operate((operation) async {
    if (!_active || !_drafts.contains(draft)) return;
    if (draft.locked && !draft.applied && draft.review == null) {
      throw StateError(
        'Результат отправки не подтверждён. Сначала проверьте состояние.',
      );
    }
    await imports.discard(
      sessionId: sessionId,
      previewId: draft.id,
      operation: operation,
    );
    if (!_active) return;
    final index = _drafts.indexOf(draft);
    _drafts.remove(draft);
    try {
      await _save();
    } catch (_) {
      _drafts.insert(index, draft);
      notifyListeners();
      rethrow;
    }
  });
  final BackendController backend;
  final String sessionId;
  List<jobs.ImportFile> _files = [];
  String? _jobId;
  bool _disposed = false;
  List<jobs.ImportFile> get files => List.unmodifiable(_files);
  bool get retrying => _jobId != null;

  Future<void> select(List<String> paths) => backend.action(() async {
    await _load();
    if (!_active || _files.isNotEmpty) return;
    final files = <jobs.ImportFile>[];
    for (final path in paths) {
      if (_drafts.any((draft) => draft.path == path && !draft.applied))
        continue;
      files.add(
        jobs.ImportFile(
          path: path,
          trackId: await api.newOperationId(),
          sourceId: await api.newOperationId(),
          operationId: await api.newOperationId(),
          allowDuplicate: false,
        ),
      );
      if (!_active) return;
    }
    _files = files;
    notifyListeners();
  });

  void clear() {
    if (!_active || backend.busy || retrying) return;
    _files = [];
    notifyListeners();
  }

  Future<void> send() => backend.action(() async {
    while (_active && _files.isNotEmpty) {
      final batch = _files.take(1000).toList();
      _jobId ??= await api.newOperationId();
      if (!_active) return;
      // Keep the same job and file IDs after an uncertain response. Navigation
      // does not abandon later batches or accidentally submit a second job.
      await jobs.importFiles(
        sessionId: sessionId,
        jobId: _jobId!,
        files: batch,
      );
      if (!_active) return;
      _files = _files.sublist(batch.length);
      _jobId = null;
      notifyListeners();
      backend.jobRevision.value++;
    }
  });

  @override
  void dispose() {
    backend.commandResults.removeListener(_commandChanged);
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      unawaited(_save().catchError((Object _) {}));
    }
    _disposed = true;
    super.dispose();
  }
}
