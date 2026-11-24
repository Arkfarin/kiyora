import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyora/core/bridge/generated/api.dart' as api;
import 'package:kiyora/core/bridge/generated/api/auth.dart' as auth;
import 'package:kiyora/core/bridge/generated/frb_generated.dart';
import 'package:kiyora/core/state/backend_controller.dart';

// Real TDLib and Secret Service, with no phone number, QR token or account login.
// Run only using tool/test_auth.py, which isolates all persistent state.
void main() {
  test(
    'native authentication survives restart and unavailable keyring',
    () async {
      final env = Platform.environment;
      final root = env['KIYORA_NATIVE_TEST_ROOT'];
      if (root == null ||
          env['KIYORA_DATA_DIR'] != '$root/data' ||
          env['XDG_DATA_HOME'] != '$root/xdg-data' ||
          !File('$root/isolated-native-test').existsSync()) {
        fail(
          'Use python3 tool/test_auth.py to isolate data and Secret Service',
        );
      }
      await RustLib.init(
        externalLibrary: ExternalLibrary.open(env['KIYORA_NATIVE_LIBRARY']!),
      );
      final backend = BackendController();
      addTearDown(() async {
        await backend.close();
        RustLib.dispose();
      });
      await backend.start();
      final phase = env['KIYORA_NATIVE_TEST_PHASE'];
      final profileMarker = File('$root/profile-id');
      if (phase == 'seed') {
        expect(backend.profiles, isEmpty);
        await backend.createProfile('Disposable authentication check');
        expect(backend.error, isNull);
        profileMarker.writeAsStringSync(backend.session!.profileId);
      } else {
        expect(['unavailable', 'restore'], contains(phase));
        expect(backend.profiles, hasLength(1));
        expect(backend.session?.profileId, profileMarker.readAsStringSync());
        expect(backend.details?.apiConfigured, isTrue);
      }
      await backend.connect();
      if (phase == 'unavailable') {
        expect(
          backend.error,
          isA<api.BridgeError>().having(
            (error) => error.code,
            'code',
            'SecureStorageUnavailable',
          ),
        );
        expect(backend.profiles, hasLength(1));
        expect(backend.details?.apiConfigured, isTrue);
        return;
      }
      expect(backend.error, isNull);
      expect(backend.authorization, isA<auth.Authorization_PhoneRequired>());
      expect(backend.details?.apiConfigured, isTrue);
      await auth.disconnect(sessionId: backend.sessionId);
      // The same entry point now follows the existing profile's keyring path.
      await backend.connect();
      expect(backend.error, isNull);
      expect(backend.authorization, isA<auth.Authorization_PhoneRequired>());
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
