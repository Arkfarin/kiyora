import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyora/core/bridge/generated/api.dart' as api;
import 'package:kiyora/core/bridge/generated/api/vault.dart' as vault;
import 'package:kiyora/core/bridge/generated/frb_generated.dart';
import 'package:kiyora/core/state/backend_controller.dart';

// Deliberately isolated controller tests. These do not claim native playback or
// Telegram acceptance; the Rust lifecycle tests exercise the real Backend.
class Feed implements api.EventFeed {
  final _next = Completer<api.Notification?>();
  bool closed = false;
  @override
  Future<api.Notification?> next() => _next.future;
  @override
  Future<void> close() async {
    closed = true;
    if (!_next.isCompleted) _next.complete(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestApi extends RustLibApi {
  static const session = api.Session(
    profileId: 'profile',
    sessionId: 'session',
  );
  int initializations = 0;
  int shutdowns = 0;
  final feeds = <Feed>[];
  Completer<api.Session?>? startup;
  Object? startupError;
  Object? shutdownError;
  Object? switchError;
  @override
  Future<api.Session?> crateApiInitialize({
    String? resources,
    BigInt? windowHandle,
  }) async {
    initializations++;
    if (startupError case final Object e) throw e;
    return startup == null ? session : await startup!.future;
  }

  @override
  Future<List<api.Profile>> crateApiProfiles() async => [
    const api.Profile(id: 'profile', label: 'Test'),
  ];
  @override
  Future<api.EventFeed> crateApiSubscribe() async {
    final feed = Feed();
    feeds.add(feed);
    return feed;
  }

  @override
  Future<vault.SessionDetails> crateApiVaultSessionDetails({
    required String sessionId,
  }) async => const vault.SessionDetails(
    session: session,
    eventSequence: '0',
    apiConfigured: false,
    connection: 'not_started',
    serviceRunning: false,
    repairRequired: false,
  );
  @override
  Future<api.Playback> crateApiPlayback({required String sessionId}) async =>
      const api.Playback.idle();
  @override
  Future<api.QueuePage> crateApiQueue({
    required String sessionId,
    required int offset,
    required int limit,
  }) async => api.QueuePage(
    queue: api.Queue(
      id: 'queue',
      revision: BigInt.zero,
      total: BigInt.zero,
      shuffle: false,
      repeat: api.Repeat.off,
    ),
    offset: 0,
    trackIds: [],
  );
  @override
  Future<api.Session> crateApiSwitchProfile({required String profileId}) async {
    if (switchError case final Object e) throw e;
    return session;
  }

  @override
  Future<void> crateApiShutdown() async {
    shutdowns++;
    if (shutdownError case final Object e) throw e;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late TestApi native;
  late BackendController controller;
  setUp(() {
    native = TestApi();
    RustLib.initMock(api: native);
    controller = BackendController();
  });
  tearDown(() async {
    native.shutdownError = null;
    await controller.close();
    RustLib.dispose();
  });

  test(
    'repeated and concurrent starts attach one backend and one feed',
    () async {
      await Future.wait([controller.start(), controller.start()]);
      await controller.start();
      expect(native.initializations, 1);
      expect(native.feeds, hasLength(1));
    },
  );
  test('startup errors reach the application and allow retry', () async {
    native.startupError = StateError('startup failed');
    await expectLater(controller.start(), throwsStateError);
    expect(controller.starting, isFalse);
    native.startupError = null;
    await controller.start();
    expect(controller.session, TestApi.session);
  });
  test(
    'failed profile switch restores the existing session subscription',
    () async {
      await controller.start();
      native.switchError = StateError('profile busy');
      await controller.chooseProfile('locked-profile');
      expect(controller.error, isStateError);
      expect(controller.session, TestApi.session);
      expect(native.feeds, hasLength(2));
      expect(native.feeds.first.closed, isTrue);
      expect(native.feeds.last.closed, isFalse);
    },
  );
  test(
    'exit racing initialization waits and shuts down the initialized runtime',
    () async {
      native.startup = Completer();
      final start = controller.start();
      final close = controller.close();
      native.startup!.complete(TestApi.session);
      await Future.wait([start, close]);
      expect(native.shutdowns, 1);
      expect(native.feeds, isEmpty);
      expect(controller.session, isNull);
    },
  );
  test('failed exit allows another exit attempt', () async {
    await controller.start();
    native.shutdownError = StateError('shutdown failed');
    await expectLater(controller.close(), throwsStateError);
    native.shutdownError = null;
    await controller.close();
    expect(native.shutdowns, 2);
  });
}
