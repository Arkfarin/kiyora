import 'dart:convert';
import 'dart:io';

/// A UI recovery file, scoped to both profile and Vault. No audio or backend
/// job state is copied here. A failed write must prevent the first submission.
class ImportDraftStore {
  ImportDraftStore(this.file);
  final File file;
  // Session teardown can flush a draft while a new session opens this store.
  // Share the queue by path so neither instance reads stale data or races the
  // other's temporary-file rename. Entries disappear once the queue drains.
  static final Map<String, Future<void>> _pending = {};
  String get _key => file.absolute.path;

  factory ImportDraftStore.forProfile(String profile, String? vault) {
    final env = Platform.environment;
    final root =
        env['KIYORA_DATA_DIR'] ??
        '${env['XDG_STATE_HOME'] ?? '${env['HOME']}/.local/state'}/kiyora';
    String key(String value) =>
        base64Url.encode(utf8.encode(value)).replaceAll('=', '');
    return ImportDraftStore(
      File(
        '$root/flutter-import-drafts/${key(profile)}-${key(vault ?? '')}.json',
      ),
    );
  }

  Future<List<Map<String, dynamic>>> read() async {
    await _pending[_key];
    if (!await file.exists()) return [];
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (json['version'] != 1)
      throw const FormatException('Неизвестный формат черновиков импорта');
    return (json['drafts'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> write(List<Map<String, Object?>> drafts) {
    // Snapshot synchronously; subsequent edits cannot alter a queued save.
    final bytes = jsonEncode({'version': 1, 'drafts': drafts});
    final key = _key;
    final next = (_pending[key] ?? Future<void>.value()).then((_) async {
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(bytes, flush: true);
      await temporary.rename(file.path);
    });
    // A failed save must be retryable, but the caller still observes the error.
    final settled = next.catchError((Object _) {});
    _pending[key] = settled;
    settled.then((_) {
      if (identical(_pending[key], settled)) _pending.remove(key);
    });
    return next;
  }
}
