import 'dart:async';

import 'package:flutter/foundation.dart';

import '../bridge/generated/api/auth.dart' as auth;
import '../bridge/generated/api/content.dart' as content;
import '../bridge/generated/api/edits.dart' as edits;
import '../bridge/generated/api.dart' as api;
import '../bridge/generated/api/vault.dart' as vault;

/// Process-owned projection of Rust state. Widgets only attach listeners.
class BackendController extends ChangeNotifier {
  api.Session? session;
  List<api.Profile> profiles = [];
  auth.Authorization? authorization;
  vault.SessionDetails? details;
  vault.Status? runtime;
  bool starting = true;
  bool busy = false;
  Object? error;
  final playback = ValueNotifier<api.Playback>(const api.Playback.idle());
  final queue = ValueNotifier<api.Queue?>(null);
  final currentTrack = ValueNotifier<content.TrackDetail?>(null);
  final libraryRevision = ValueNotifier<int>(0);
  final jobRevision = ValueNotifier<int>(0);
  final commandResults = ValueNotifier<edits.Command?>(null);
  api.EventFeed? _feed;
  auth.Operation? _operation;
  int _epoch = 0;
  bool _closing = false;
  Future<void>? _starting;
  Future<void>? _switching;
  Future<void>? _closeFuture;
  bool _started = false;
  Timer? _refreshTimer;

  String get sessionId {
    final id = session?.sessionId;
    if (id == null) throw StateError('Choose a profile first');
    return id;
  }

  bool get hasLibrary => session?.vaultId != null;

  Future<void> start({String? resources, BigInt? windowHandle}) {
    if (_closing) return Future.error(StateError('KIYORA is closing'));
    if (_started) return Future.value();
    return _starting ??= _start(
      resources,
      windowHandle,
    ).whenComplete(() => _starting = null);
  }

  Future<void> _start(String? resources, BigInt? windowHandle) async {
    starting = true;
    error = null;
    notifyListeners();
    try {
      session = await api.initialize(
        resources: resources,
        windowHandle: windowHandle,
      );
      if (_closing) return;
      profiles = await api.profiles();
      if (_closing) return;
      await _attach();
      _started = true;
    } catch (e) {
      error = e;
      rethrow;
    } finally {
      starting = false;
      notifyListeners();
    }
  }

  Future<void> chooseProfile(String id) =>
      _switching ??= _chooseProfile(id).whenComplete(() => _switching = null);

  Future<void> _chooseProfile(String id) async {
    await action(() async {
      await _detach();
      try {
        final next = await api.switchProfile(profileId: id);
        _clearSession();
        session = next;
      } finally {
        // Backend validates the target before releasing the previous profile.
        // A rejected switch must restore subscriptions to that live session.
        await _attach();
      }
    });
  }

  Future<void> createProfile(String label) async {
    await action(() async {
      final profile = await api.createProfile(label: label.trim());
      profiles = await api.profiles();
      await _detach();
      try {
        final next = await api.switchProfile(profileId: profile.id);
        _clearSession();
        session = next;
      } finally {
        await _attach();
      }
    });
  }

  void _clearSession() {
    authorization = null;
    details = null;
    runtime = null;
    playback.value = const api.Playback.idle();
    queue.value = null;
    currentTrack.value = null;
    commandResults.value = null;
    notifyListeners();
  }

  Future<void> _detach() async {
    _epoch++;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    final operation = _operation;
    _operation = null;
    await operation?.cancel();
    final feed = _feed;
    _feed = null;
    await feed?.close();
  }

  Future<void> _attach() async {
    if (_closing || session == null) return;
    final epoch = _epoch;
    // Subscribe before the snapshot so no transition can fall between them.
    final feed = await api.subscribe();
    if (epoch != _epoch || _closing) {
      await feed.close();
      return;
    }
    _feed = feed;
    try {
      final watermark = await _snapshot(epoch);
      if (epoch == _epoch) unawaited(_consume(feed, epoch, watermark));
    } catch (_) {
      await feed.close();
      if (identical(_feed, feed)) _feed = null;
      rethrow;
    }
  }

  Future<BigInt> _snapshot(int epoch) async {
    final id = sessionId;
    final info = await vault.sessionDetails(sessionId: id);
    if (epoch != _epoch) return BigInt.zero;
    details = info;
    session = info.session;
    BigInt watermark = BigInt.parse(info.eventSequence);
    if (info.session.vaultId != null) {
      final marker = await api.projectionMarker(sessionId: id);
      if (epoch != _epoch) return BigInt.zero;
      watermark = BigInt.parse(marker.sequence);
      session = marker.session;
    }
    final state = await api.playback(sessionId: id);
    final queued = await api.queue(sessionId: id, offset: 0, limit: 1);
    if (epoch != _epoch) return BigInt.zero;
    playback.value = state;
    queue.value = queued.queue;
    // An unconnected profile is valid and must still show onboarding.
    if (info.connection != 'not_started') {
      try {
        final latest = await auth.status(sessionId: id);
        if (epoch == _epoch) authorization = latest;
      } on api.BridgeError catch (e) {
        if (e.code != 'NotConnected' && e.code != 'AuthRequired') rethrow;
      }
    }
    if (epoch != _epoch) return BigInt.zero;
    libraryRevision.value++;
    jobRevision.value++;
    notifyListeners();
    unawaited(_loadCurrentTrack(epoch));
    return watermark;
  }

  Future<void> _consume(api.EventFeed feed, int epoch, BigInt watermark) async {
    try {
      while (!_closing && epoch == _epoch) {
        final event = await feed.next();
        if (epoch != _epoch || _closing) return;
        if (event == null) break;
        if (event.change is api.Change_Resync) {
          // Replace the damaged feed before taking a fresh snapshot.
          await feed.close();
          await _attach();
          return;
        }
        if (event.session?.sessionId != session?.sessionId) continue;
        final sequence = BigInt.tryParse(event.sequence ?? '');
        if (sequence != null && sequence <= watermark) continue;
        if (sequence != null) watermark = sequence;
        switch (event.change) {
          case api.Change_Playback(:final state):
            final oldTrack = playbackTrackId(playback.value);
            playback.value = state;
            if (oldTrack != playbackTrackId(state))
              unawaited(_loadCurrentTrack(epoch));
          case api.Change_Queue(:final state):
            queue.value = state;
          case api.Change_Runtime(:final state):
            runtime = state;
            session = state.session;
            notifyListeners();
          case api.Change_AuthChanged():
            final latest = await auth.status(sessionId: sessionId);
            if (epoch == _epoch) {
              authorization = latest;
              notifyListeners();
            }
          case api.Change_Job():
            jobRevision.value++;
          case api.Change_Command(:final result):
            commandResults.value = result;
          case api.Change_Warning(:final error):
            this.error = error;
            notifyListeners();
          case api.Change_Library() || api.Change_Playlist():
            _refreshTimer ??= Timer(const Duration(milliseconds: 120), () {
              _refreshTimer = null;
              if (epoch == _epoch) libraryRevision.value++;
            });
          case api.Change_Sync():
            notifyListeners();
          case api.Change_Refresh():
            watermark = await _snapshot(epoch);
          case api.Change_Resync():
            break;
        }
      }
    } catch (e) {
      if (epoch == _epoch && !_closing) {
        error = e;
        notifyListeners();
      }
    } finally {
      await feed.close();
      if (identical(_feed, feed)) _feed = null;
    }
    // Five attempts, then retain the error and expose explicit refresh/retry.
    var delay = 1;
    for (
      var attempt = 0;
      attempt < 5 && !_closing && epoch == _epoch;
      attempt++
    ) {
      await Future<void>.delayed(Duration(seconds: delay));
      if (_closing || epoch != _epoch) return;
      try {
        await _attach();
        return;
      } catch (e) {
        if (_closing || epoch != _epoch) return;
        error = e;
        notifyListeners();
        delay = (delay * 2).clamp(1, 30);
      }
    }
  }

  Future<void> _loadCurrentTrack(int epoch) async {
    final trackId = playbackTrackId(playback.value);
    currentTrack.value = null;
    if (trackId == null || session == null) return;
    try {
      final track = await content.track(sessionId: sessionId, trackId: trackId);
      if (epoch == _epoch && playbackTrackId(playback.value) == trackId)
        currentTrack.value = track;
    } catch (e) {
      if (epoch == _epoch) {
        error = e;
        notifyListeners();
      }
    }
  }

  /// User commands aren't automatically replayed after timeout.
  Future<void> action(Future<void> Function() command) async {
    if (busy || _closing) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await command();
    } catch (e) {
      error = e;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> operate(Future<void> Function(auth.Operation) command) =>
      action(() async {
        final operation = await auth.Operation.newInstance();
        _operation = operation;
        try {
          await command(operation);
        } finally {
          if (identical(_operation, operation)) _operation = null;
          await operation.cancel();
        }
      });

  Future<void> cancel() async => _operation?.cancel();
  void clearError() {
    error = null;
    notifyListeners();
  }

  Future<void> refresh() => action(() async {
    if (_feed == null) {
      await _attach();
    } else {
      await _snapshot(_epoch);
    }
  });
  Future<void> transport(api.Transport command) => action(() async {
    final epoch = _epoch;
    final state = await api.control(sessionId: sessionId, action: command);
    if (epoch == _epoch) playback.value = state;
  });
  Future<void> togglePlayback() => transport(
    playback.value is api.Playback_Playing
        ? const api.Transport.pause()
        : const api.Transport.resume(),
  );
  Future<void> play(List<String> tracks, int index) => action(() async {
    final epoch = _epoch;
    final state = await api.play(
      sessionId: sessionId,
      trackIds: tracks,
      position: index,
    );
    if (epoch == _epoch) queue.value = state;
  });
  Future<void> editQueue(api.QueueEdit edit) => action(() async {
    final q = queue.value;
    if (q == null) return;
    final epoch = _epoch;
    try {
      final state = await api.editQueue(
        sessionId: sessionId,
        queueId: q.id,
        revision: q.revision,
        edit: edit,
      );
      if (epoch == _epoch) queue.value = state;
    } catch (_) {
      final fresh = await api.queue(sessionId: sessionId, offset: 0, limit: 1);
      if (epoch == _epoch) queue.value = fresh.queue;
      rethrow; // A conflict is shown; never silently apply to a different order.
    }
  });
  Future<void> connect(int apiId, String apiHash) => action(() async {
    authorization = await auth.connect(
      sessionId: sessionId,
      apiId: apiId,
      apiHash: apiHash,
    );
    await _snapshot(_epoch);
  });
  Future<void> login(auth.Login input) => operate((operation) async {
    authorization = await auth.authenticate(
      sessionId: sessionId,
      input: input,
      operation: operation,
    );
    await _snapshot(_epoch);
  });
  Future<void> reconnect() => action(() async {
    authorization = await auth.reconnect(sessionId: sessionId);
    await _snapshot(_epoch);
  });
  Future<void> synchronize() => operate((operation) async {
    await vault.synchronize(sessionId: sessionId, operation: operation);
    await _snapshot(_epoch);
  });
  Future<void> close() =>
      _closeFuture ??= _close().whenComplete(() => _closeFuture = null);

  Future<void> _close() async {
    _closing = true;
    try {
      await _detach();
      // If exit races startup, let initialization settle before shutting down
      // the runtime it created. An initialization error is already displayed.
      try {
        await _starting;
      } catch (e) {
        error = e;
      }
      await api.shutdown();
      _started = false;
      session = null;
      _clearSession();
    } catch (e) {
      _closing = false;
      error = e;
      notifyListeners();
      rethrow;
    }
  }
}

String? playbackTrackId(api.Playback state) => switch (state) {
  api.Playback_Playing(:final trackId) ||
  api.Playback_Paused(:final trackId) ||
  api.Playback_Buffering(:final trackId) ||
  api.Playback_Ended(:final trackId) => trackId,
  api.Playback_Failed(:final trackId) => trackId,
  _ => null,
};

(int, int) playbackTime(api.Playback state) => switch (state) {
  api.Playback_Playing(:final positionMs, :final durationMs) ||
  api.Playback_Paused(:final positionMs, :final durationMs) ||
  api.Playback_Buffering(
    :final positionMs,
    :final durationMs,
  ) => (positionMs.toInt(), durationMs.toInt()),
  _ => (0, 0),
};
