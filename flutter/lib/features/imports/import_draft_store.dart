import 'dart:convert';
import 'dart:io';

/// A UI recovery file, scoped to both profile and Vault. No audio or backend
/// job state is copied here. A failed write must prevent the first submission.
class ImportDraftStore {
  ImportDraftStore(this.file);
  final File file;
  Future<void> _writes = Future.value();

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
    if (!await file.exists()) return [];
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (json['version'] != 1)
      throw const FormatException('Неизвестный формат черновиков импорта');
    return (json['drafts'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> write(List<Map<String, Object?>> drafts) {
    // Snapshot synchronously; subsequent edits cannot alter a queued save.
    final bytes = jsonEncode({'version': 1, 'drafts': drafts});
    final next = _writes.then((_) async {
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(bytes, flush: true);
      await temporary.rename(file.path);
    });
    // A failed save must be retryable, but the caller still observes the error.
    _writes = next.catchError((Object _) {});
    return next;
  }
}
