import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiyora/core/state/ui_preferences.dart';

void main() {
  late Directory temporary;
  late File file;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('kiyora-ui-settings-');
    file = File('${temporary.path}/config/ui-preferences.json');
  });
  tearDown(() async => temporary.delete(recursive: true));

  test('missing settings preserve startup defaults without writing', () async {
    final store = UiPreferencesStore(file);
    await store.load();
    expect(store.value.theme, 'system');
    expect(store.value.width, 1280);
    expect(await file.exists(), isFalse);
  });

  test('rapid theme and window changes survive a new store instance', () async {
    final store = UiPreferencesStore(file);
    final writes = [
      store.setTheme('dark'),
      store.setTheme('light'),
      store.setWindow({'width': 980, 'height': 650, 'maximized': true}),
      store.setTheme('dark'),
    ];
    await Future.wait(writes);
    final reopened = UiPreferencesStore(file);
    await reopened.load();
    expect(reopened.value.toJson(), {
      'theme': 'dark',
      'width': 980,
      'height': 650,
      'maximized': true,
    });
    expect(await file.parent.list().length, 1);
  });

  test(
    'failed write preserves the old file and allows a later retry',
    () async {
      final store = UiPreferencesStore(file);
      await store.setTheme('dark');
      final previous = await file.readAsString();
      // A directory at the destination deterministically rejects replacement,
      // even when tests run as root. Keep the original bytes outside it.
      final saved = await file.rename('${file.path}.saved');
      await Directory(file.path).create();
      await expectLater(
        store.setTheme('light'),
        throwsA(isA<FileSystemException>()),
      );
      expect(await saved.readAsString(), previous);
      await Directory(file.path).delete();
      await saved.rename(file.path);
      await store.setTheme('system');
      final reopened = UiPreferencesStore(file);
      await reopened.load();
      expect(reopened.value.theme, 'system');
      expect(await file.parent.list().length, 1);
    },
  );

  test(
    'corrupt and oversized settings are reported without deleting them',
    () async {
      await file.parent.create(recursive: true);
      for (final bytes in ['{broken', 'x' * 65537]) {
        await file.writeAsString(bytes);
        final store = UiPreferencesStore(file);
        await expectLater(store.load(), throwsFormatException);
        expect(store.value.theme, 'system');
        expect(await file.readAsString(), bytes);
      }
    },
  );

  test('unusable dimensions and unknown theme safely fall back', () async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'width': -10,
        'height': 999999,
        'theme': 'future-mode',
        'maximized': 'yes',
      }),
    );
    final store = UiPreferencesStore(file);
    await store.load();
    expect(store.value.toJson(), const UiPreferences().toJson());
  });
}
