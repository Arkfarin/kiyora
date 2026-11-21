import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyora/core/bridge/generated/api.dart' as api;
import 'package:kiyora/core/bridge/generated/api/auth.dart' as auth;
import 'package:kiyora/core/bridge/generated/api/vault.dart' as vault;
import 'package:kiyora/core/bridge/generated/frb_generated.dart';
import 'package:kiyora/core/state/backend_controller.dart';

// Run only through tool/test_native.py: real Rust, isolated data and D-Bus,
// no Telegram credentials, network login, or personal profile access.
void main() {
  test('native bridge lifecycle and durable queue preferences', () async {
    final environment = Platform.environment;
    final data = environment['KIYORA_DATA_DIR'];
    final marker = environment['KIYORA_NATIVE_TEST_ROOT'];
    if (data == null ||
        marker == null ||
        data != '$marker/data' ||
        !File('$marker/isolated-native-test').existsSync()) {
      fail('Use python3 tool/test_native.py to isolate native state');
    }
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(
        environment['KIYORA_NATIVE_LIBRARY']!,
      ),
    );
    final controller = BackendController();
    addTearDown(() async {
      await controller.close();
      RustLib.dispose();
    });
    await controller.start();
    if (environment['KIYORA_NATIVE_TEST_PHASE'] == 'restore') {
      expect(
        controller.profiles.map((p) => p.label),
        unorderedEquals(['Native first', 'Native second']),
      );
      final second = controller.profiles.singleWhere(
        (p) => p.label == 'Native second',
      );
      expect(controller.session?.profileId, second.id);
      expect(controller.queue.value?.repeat, api.Repeat.all);
      expect(controller.queue.value?.shuffle, isTrue);
      expect(controller.runtime?.mode, vault.Mode.authRequired);
      return;
    }
    expect(controller.profiles, isEmpty);
    expect(controller.session, isNull);
    await controller.createProfile('Native first');
    expect(controller.error, isNull);
    final first = controller.session!;
    expect(controller.runtime?.mode, vault.Mode.authRequired);
    expect(controller.playback.value, const api.Playback.idle());
    final attached = await Future.wait([api.initialize(), api.initialize()]);
    expect(attached.map((s) => s?.sessionId), everyElement(first.sessionId));

    await controller.createProfile('Native second');
    expect(controller.error, isNull);
    final second = controller.session!;
    expect(second.profileId, isNot(first.profileId));
    await expectLater(
      api.playback(sessionId: first.sessionId),
      throwsA(isA<api.BridgeError>().having((e) => e.code, 'code', 'Conflict')),
    );
    final feed = await api.subscribe();
    addTearDown(feed.close);
    final originalQueue = controller.queue.value!;
    await controller.editQueue(
      const api.QueueEdit.repeat(mode: api.Repeat.all),
    );
    expect(controller.error, isNull);
    final notice = await feed.next().timeout(const Duration(seconds: 5));
    expect(notice?.session?.sessionId, second.sessionId);
    expect(notice?.change, isA<api.Change_Queue>());
    expect((notice!.change as api.Change_Queue).state.repeat, api.Repeat.all);
    await expectLater(
      api.editQueue(
        sessionId: second.sessionId,
        queueId: originalQueue.id,
        revision: originalQueue.revision,
        edit: const api.QueueEdit.shuffle(enabled: true),
      ),
      throwsA(isA<api.BridgeError>().having((e) => e.code, 'code', 'Conflict')),
    );
    await controller.editQueue(const api.QueueEdit.shuffle(enabled: true));
    expect(controller.error, isNull);
    await controller.refresh();
    expect(controller.error, isNull);
    expect(controller.queue.value?.shuffle, isTrue);
    expect(controller.queue.value?.repeat, api.Repeat.all);

    final operation = await auth.Operation.newInstance();
    await operation.cancel();
    await operation.cancel();
    final closingFeed = await api.subscribe();
    final pending = closingFeed.next();
    await closingFeed.close();
    expect(await pending.timeout(const Duration(seconds: 5)), isNull);
    final shutdownFeed = await api.subscribe();
    final shutdownPending = shutdownFeed.next();
    await controller.close();
    expect(await shutdownPending.timeout(const Duration(seconds: 5)), isNull);
    await expectLater(
      api.profiles(),
      throwsA(isA<api.BridgeError>().having((e) => e.code, 'code', 'Closed')),
    );

    final reopened = await api.initialize();
    expect(reopened?.profileId, second.profileId);
    expect(reopened?.sessionId, isNot(second.sessionId));
    expect((await api.profiles()).length, 2);
    final restored = await api.queue(
      sessionId: reopened!.sessionId,
      offset: 0,
      limit: 1,
    );
    expect(restored.queue.shuffle, isTrue);
    expect(restored.queue.repeat, api.Repeat.all);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
