import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyora/core/bridge/generated/api.dart' as api;
import 'package:kiyora/core/bridge/generated/api/auth.dart' as auth;
import 'package:kiyora/core/bridge/generated/api/vault.dart' as vault;
import 'package:kiyora/core/bridge/generated/frb_generated.dart';
import 'package:kiyora/core/state/backend_controller.dart';

// Deliberately isolated controller tests. These do not claim native playback or
// Telegram acceptance; the Rust lifecycle tests exercise the real Backend.
class Feed implements api.EventFeed {
  final _events = <api.Notification>[];
  Completer<api.Notification?>? _pending;
  bool closed = false;
  void emit(api.Notification event) {
    if (closed) throw StateError('feed closed');
    final pending = _pending;
    if (pending == null) {
      _events.add(event);
    } else {
      _pending = null;
      pending.complete(event);
    }
  }

  @override
  Future<api.Notification?> next() {
    if (closed) return Future.value(null);
    if (_events.isNotEmpty) return Future.value(_events.removeAt(0));
    return (_pending = Completer<api.Notification?>()).future;
  }

  @override
  Future<void> close() async {
    closed = true;
    _pending?.complete(null);
    _pending = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestOperation implements auth.Operation {
  bool cancelled = false;
  @override
  Future<void> cancel() async {
    cancelled = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestApi extends RustLibApi {
  final operation = TestOperation();
  @override
  Future<auth.Operation> crateApiAuthOperationNew() async => operation;
  static const session = api.Session(
    profileId: 'profile',
    sessionId: 'session',
  );
  int initializations = 0;
  int shutdowns = 0;
  int subscriptions = 0;
  int failedSubscriptions = 0;
  api.Notification? onSubscribe;
  final feeds = <Feed>[];
  Completer<api.Session?>? startup;
  Object? startupError;
  Object? shutdownError;
  Object? switchError;
  var runtimeMode = vault.Mode.authRequired;
  Completer<api.Playback>? playbackRead;
  api.Playback playbackState = const api.Playback.idle();
  String sequence = '0';
  @override
  Future<vault.Status> crateApiVaultStatus() async =>
      vault.Status(session: session, mode: runtimeMode);
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
    subscriptions++;
    if (failedSubscriptions > 0) {
      failedSubscriptions--;
      throw StateError('subscription unavailable');
    }
    final feed = Feed();
    feeds.add(feed);
    if (onSubscribe case final api.Notification event) {
      onSubscribe = null;
      feed.emit(event);
    }
    return feed;
  }

  @override
  Future<vault.SessionDetails> crateApiVaultSessionDetails({
    required String sessionId,
  }) async => vault.SessionDetails(
    session: session,
    eventSequence: sequence,
    apiConfigured: false,
    connection: 'not_started',
    serviceRunning: false,
    repairRequired: false,
  );
  @override
  Future<api.Playback> crateApiPlayback({required String sessionId}) async =>
      playbackRead == null ? playbackState : await playbackRead!.future;
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
  test('snapshot restores runtime mode after missed status events', () async {
    await controller.start();
    expect(controller.runtime?.mode, vault.Mode.authRequired);
    native.runtimeMode = vault.Mode.degradedReadonly;
    await controller.refresh();
    expect(controller.runtime?.mode, vault.Mode.degradedReadonly);
  });

  testWidgets('manual refresh supersedes a pending automatic reconnect', (
    tester,
  ) async {
    await controller.start();
    await native.feeds.single.close();
    await tester.pump();
    await controller.refresh();
    expect(native.feeds.where((feed) => !feed.closed), hasLength(1));
    await tester.pump(const Duration(seconds: 2));
    expect(native.feeds.where((feed) => !feed.closed), hasLength(1));
  });

  testWidgets('refresh buffers events until the snapshot is applied', (
    tester,
  ) async {
    await controller.start();
    native.playbackRead = Completer();
    final refresh = controller.refresh();
    await tester.pump();
    const latest = api.Playback.failed(code: 'AudioDeviceUnavailable');
    native.feeds.last.emit(
      const api.Notification(
        session: TestApi.session,
        sequence: '2',
        change: api.Change.playback(state: latest),
      ),
    );
    await tester.pump();
    native.playbackRead!.complete(const api.Playback.idle());
    await refresh;
    await tester.pump();
    expect(controller.playback.value, latest);
  });

  testWidgets('resync replaces the feed and rejects pre-snapshot events', (
    tester,
  ) async {
    await controller.start();
    native.sequence = '10';
    native.runtimeMode = vault.Mode.reconnecting;
    native.feeds.single.emit(
      const api.Notification(change: api.Change.resync(missedEvents: '3')),
    );
    await tester.pump();
    expect(native.feeds, hasLength(2));
    expect(native.feeds.first.closed, isTrue);
    expect(controller.runtime?.mode, vault.Mode.reconnecting);
    native.feeds.last.emit(
      const api.Notification(
        session: TestApi.session,
        sequence: '9',
        change: api.Change.playback(state: api.Playback.failed(code: 'old')),
      ),
    );
    await tester.pump();
    expect(controller.playback.value, const api.Playback.idle());
    native.feeds.last.emit(
      const api.Notification(
        session: TestApi.session,
        sequence: '11',
        change: api.Change.playback(state: api.Playback.failed(code: 'new')),
      ),
    );
    await tester.pump();
    expect(controller.playback.value, const api.Playback.failed(code: 'new'));
  });

  testWidgets('failed resync retries and restores one live feed', (
    tester,
  ) async {
    await controller.start();
    native.failedSubscriptions = 1;
    native.feeds.single.emit(
      const api.Notification(change: api.Change.resync(missedEvents: '1')),
    );
    await tester.pump();
    expect(controller.error, isStateError);
    expect(native.subscriptions, 2);
    await tester.pump(const Duration(seconds: 1));
    expect(native.subscriptions, 3);
    expect(native.feeds.where((feed) => !feed.closed), hasLength(1));
  });

  testWidgets(
    'reconnect stops after five retries and manual retry still works',
    (tester) async {
      await controller.start();
      native.failedSubscriptions = 6;
      await controller.refresh();
      for (final seconds in [1, 2, 4, 8, 16]) {
        await tester.pump(Duration(seconds: seconds));
      }
      expect(native.subscriptions, 7);
      await tester.pump(const Duration(minutes: 1));
      expect(native.subscriptions, 7);
      expect(controller.error, isStateError);
      await controller.refresh();
      expect(native.feeds.where((feed) => !feed.closed), hasLength(1));
      expect(controller.error, isNull);
    },
  );

  testWidgets(
    'another overflow during reattachment starts a fresh subscription',
    (tester) async {
      await controller.start();
      native.onSubscribe = const api.Notification(
        change: api.Change.resync(missedEvents: '2'),
      );
      await controller.refresh();
      await tester.pump();
      expect(native.subscriptions, 3);
      expect(native.feeds.where((feed) => !feed.closed), hasLength(1));
    },
  );
  testWidgets('event resync does not cancel an active user operation', (
    tester,
  ) async {
    await controller.start();
    final completed = Completer<void>();
    final operation = controller.operate((_) => completed.future);
    await tester.pump();
    native.feeds.single.emit(
      const api.Notification(change: api.Change.resync(missedEvents: '1')),
    );
    await tester.pump();
    expect(native.feeds, hasLength(2));
    expect(native.operation.cancelled, isFalse);
    completed.complete();
    await operation;
    expect(native.operation.cancelled, isTrue);
  });
}
