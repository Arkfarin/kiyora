import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyora/core/bridge/generated/api.dart' as api;
import 'package:kiyora/core/bridge/generated/frb_generated.dart';
import 'package:kiyora/core/state/backend_controller.dart';

void main() {
  test('offline playback and Linux media controls use the real Rust engine', () async {
    final environment = Platform.environment;
    final root = environment['KIYORA_NATIVE_TEST_ROOT'];
    if (root == null ||
        environment['KIYORA_DATA_DIR'] != '$root/data' ||
        !File('$root/isolated-native-test').existsSync() ||
        environment['KIYORA_AUDIO_TEST_SINK'] == null) {
      fail('Use python3 tool/test_playback.py to isolate data and audio');
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
    expect(controller.hasLibrary, isTrue);
    final session = controller.sessionId;
    final tracks = await api.library_(sessionId: session, offset: 0, limit: 20);
    expect(tracks.length, 3);
    final alpha = tracks.singleWhere((t) => t.title == 'Alpha').id;
    final beta = tracks.singleWhere((t) => t.title == 'Beta').id;
    final missing = tracks.singleWhere((t) => t.title == 'Unavailable').id;
    final feed = await api.subscribe();
    addTearDown(feed.close);
    var waitNumber = 0;
    Future<api.Playback> until(bool Function(api.Playback) condition) async {
      final step = ++waitNumber;
      print('Waiting for playback step $step');
      api.Playback? last;
      return (() async {
        while (true) {
          final event = await feed.next();
          if (event == null) throw StateError('playback feed closed');
          if (event.change case api.Change_Playback(:final state)) {
            last = state;
            if (state is api.Playback_Failed) fail('Playback failed: $state');
            if (condition(state)) return state;
          }
        }
      })().timeout(
        const Duration(seconds: 10),
        onTimeout: () async {
          throw StateError(
            'playback wait $step timed out; last event: $last; snapshot: ${await api.playback(sessionId: session)}',
          );
        },
      );
    }

    bool playing(api.Playback p, String id) =>
        p is api.Playback_Playing && p.trackId == id;
    Future<void> media(List<String> arguments) async {
      final result = await Process.run('playerctl', [
        '--player=kiyora',
        ...arguments,
      ]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
    }

    await controller.play([alpha, beta], 0);
    expect(controller.error, isNull);
    await until((p) => playing(p, alpha) && playbackTime(p).$1 >= 200);
    await controller.transport(const api.Transport.pause());
    expect(controller.error, isNull);
    await until((p) => p is api.Playback_Paused && p.trackId == alpha);
    await controller.transport(
      api.Transport.seek(milliseconds: BigInt.from(2000)),
    );
    expect(controller.error, isNull);
    await until((p) => p is api.Playback_Paused && playbackTime(p).$1 >= 1900);
    await controller.transport(const api.Transport.resume());
    expect(controller.error, isNull);
    await until((p) => playing(p, alpha) && playbackTime(p).$1 >= 2100);

    final metadata = await Process.run('playerctl', [
      '--player=kiyora',
      'metadata',
      'xesam:title',
    ]);
    expect(metadata.exitCode, 0, reason: metadata.stderr.toString());
    expect(metadata.stdout.toString().trim(), 'Alpha');
    await media(['pause']);
    await until((p) => p is api.Playback_Paused && p.trackId == alpha);
    await media(['play']);
    await until((p) => playing(p, alpha));
    await media(['next']);
    await until((p) => playing(p, beta));
    await media(['previous']);
    await until((p) => playing(p, alpha));

    for (var i = 0; i < 5; i++) {
      await controller.transport(const api.Transport.pause());
      expect(controller.error, isNull);
      await controller.transport(const api.Transport.resume());
      expect(controller.error, isNull);
    }
    await controller.editQueue(const api.QueueEdit.move(from: 1, to: 0));
    expect(controller.error, isNull);
    final queue = await api.queue(sessionId: session, offset: 0, limit: 20);
    expect(queue.trackIds, [beta, alpha]);
    expect(queue.queue.currentTrackId, alpha);
    await controller.editQueue(const api.QueueEdit.remove(index: 1));
    expect(controller.error, isNull);
    await until((p) => playing(p, beta));

    await controller.play([missing], 0);
    expect(controller.error, isA<api.BridgeError>());
    await controller.play([alpha], 0);
    expect(controller.error, isNull);
    await until((p) => playing(p, alpha) && playbackTime(p).$1 >= 200);
    await controller.refresh();
    expect(controller.error, isNull);
    expect(playbackTrackId(controller.playback.value), alpha);
    // Decoder position measures frames queued to the OS, not necessarily
    // frames already emitted by PipeWire/PulseAudio. Leave the last track
    // playing long enough for the isolated monitor to receive real samples.
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(await api.playback(sessionId: session), isA<api.Playback_Playing>());
    await controller.close();
    final players = await Process.run('playerctl', ['--list-all']);
    expect(players.stdout.toString(), isNot(contains('kiyora')));
  }, timeout: const Timeout(Duration(seconds: 90)));
}
