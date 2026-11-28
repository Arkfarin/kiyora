import 'dart:convert';
import 'dart:io';

class UiPreferences {
  const UiPreferences({
    this.theme = 'system',
    this.width = 1280,
    this.height = 720,
    this.maximized = false,
    this.searchHistory = const {},
  });

  final String theme;
  final int width;
  final int height;
  final bool maximized;
  final Map<String, List<String>> searchHistory;

  static List<String> normalizeHistory(Iterable<Object?> values) {
    final result = <String>[];
    final seen = <String>{};
    for (final value in values) {
      if (value is! String) continue;
      final query = value.trim();
      if (query.isEmpty || query.length > 128 || !seen.add(query.toLowerCase()))
        continue;
      result.add(query);
      if (result.length == 10) break;
    }
    return List.unmodifiable(result);
  }

  factory UiPreferences.fromJson(Map<String, dynamic> json) {
    final theme = json['theme'];
    final width = json['width'];
    final height = json['height'];
    final histories = <String, List<String>>{};
    final rawHistory = json['searchHistory'];
    if (rawHistory is Map<String, dynamic>) {
      for (final entry in rawHistory.entries.take(8)) {
        if (entry.key.isEmpty || entry.key.length > 128 || entry.value is! List)
          continue;
        final normalized = normalizeHistory(entry.value as List);
        if (normalized.isNotEmpty) histories[entry.key] = normalized;
      }
    }
    return UiPreferences(
      theme: ['system', 'light', 'dark'].contains(theme)
          ? theme as String
          : 'system',
      width: width is int && width >= 720 && width <= 7680 ? width : 1280,
      height: height is int && height >= 540 && height <= 4320 ? height : 720,
      maximized: json['maximized'] == true,
      searchHistory: Map.unmodifiable(histories),
    );
  }

  Map<String, Object> toJson() => {
    'theme': theme,
    'width': width,
    'height': height,
    'maximized': maximized,
    if (searchHistory.isNotEmpty) 'searchHistory': searchHistory,
  };
}

/// Presentation settings only. Telegram credentials and library state stay in Rust.
/// Writes are ordered and replace the file atomically on Linux and Android.
class UiPreferencesStore {
  UiPreferencesStore(this.file);
  final File file;
  UiPreferences value = const UiPreferences();
  Future<void> _pending = Future.value();

  Future<void> flush() => _pending;

  factory UiPreferencesStore.linux() {
    final env = Platform.environment;
    final isolated = env['KIYORA_DATA_DIR'];
    if (isolated != null && isolated.isNotEmpty) {
      return UiPreferencesStore(File('$isolated/ui-preferences.json'));
    }
    final configured = env['XDG_CONFIG_HOME'];
    final home = env['HOME'];
    final root = configured != null && configured.startsWith('/')
        ? configured
        : home != null
        ? '$home/.config'
        : null;
    if (root == null)
      throw const FileSystemException('Configuration directory unavailable');
    return UiPreferencesStore(File('$root/kiyora/ui-preferences.json'));
  }

  Future<void> load() async {
    try {
      if (await file.length() > 65536)
        throw const FormatException('Preferences file too large');
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>)
        throw const FormatException('Invalid preferences');
      value = UiPreferences.fromJson(decoded);
    } on FileSystemException catch (error) {
      if (error.osError?.errorCode != 2) rethrow;
    }
  }

  Future<void> setTheme(String theme) => _save(
    UiPreferences(
      theme: theme,
      width: value.width,
      height: value.height,
      maximized: value.maximized,
      searchHistory: value.searchHistory,
    ),
  );

  Future<void> setWindow(Map<String, dynamic> window) => _save(
    UiPreferences.fromJson({
      ...value.toJson(),
      ...window,
      'theme': value.theme,
    }),
  );

  Future<void> setSearchHistory(String profileId, Iterable<String> queries) {
    if (profileId.isEmpty || profileId.length > 128) return Future.value();
    final normalized = UiPreferences.normalizeHistory(queries);
    final histories = <String, List<String>>{
      if (normalized.isNotEmpty) profileId: normalized,
      for (final entry in value.searchHistory.entries)
        if (entry.key != profileId) entry.key: entry.value,
    };
    return _save(
      UiPreferences.fromJson({...value.toJson(), 'searchHistory': histories}),
    );
  }

  Future<void> _save(UiPreferences next) {
    value = next;
    // A failed write must not poison all future attempts. Each caller still
    // receives its own failure, so the UI can report it.
    return _pending = _pending
        .catchError((Object _) {})
        .then((_) => _write(next));
  }

  Future<void> _write(UiPreferences snapshot) async {
    await file.parent.create(recursive: true);
    final temporary = await file.parent.createTemp('.ui-preferences-');
    final staged = File('${temporary.path}/settings.json');
    try {
      await staged.writeAsString(jsonEncode(snapshot.toJson()), flush: true);
      await staged.rename(file.path);
    } finally {
      if (await staged.exists()) await staged.delete();
      await temporary.delete();
    }
  }
}
