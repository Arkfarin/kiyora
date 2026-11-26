import 'dart:convert';
import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyora/core/bridge/generated/api.dart' as api;
import 'package:kiyora/core/bridge/generated/api/content.dart' as content;
import 'package:kiyora/core/bridge/generated/frb_generated.dart';

// Pure native content APIs: no backend initialization, profiles, D-Bus or network.
void main() {
  setUpAll(() async {
    final library = Platform.environment['KIYORA_NATIVE_LIBRARY'];
    if (library == null)
      fail('Set KIYORA_NATIVE_LIBRARY to the rebuilt bridge');
    await RustLib.init(externalLibrary: ExternalLibrary.open(library));
  });
  tearDownAll(RustLib.dispose);

  test('real bridge normalizes artwork and rejects damaged bytes', () async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
    );
    final cover = await content.prepareArtwork(bytes: png);
    expect(cover.mimeType, 'image/png');
    expect(cover.digest, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(cover.bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final again = await content.prepareArtwork(bytes: cover.bytes);
    expect(again.digest, cover.digest);
    for (final bytes in [
      Uint8List(0),
      Uint8List.fromList([1, 2, 3]),
      Uint8List(8 * 1024 * 1024 + 1),
    ]) {
      await expectLater(
        content.prepareArtwork(bytes: bytes),
        throwsA(
          isA<api.BridgeError>().having((e) => e.code, 'code', 'InvalidInput'),
        ),
      );
    }
  });

  test(
    'real bridge preserves subtitle timings and rejects malformed lyrics',
    () async {
      for (final input in [
        (format: 'lrc', text: '[00:01.00]First\n[00:02.50]Second'),
        (format: 'srt', text: '1\n00:00:01,000 --> 00:00:02,500\nFirst'),
        (format: 'vtt', text: 'WEBVTT\n\n00:00:01.000 --> 00:00:02.500\nFirst'),
      ]) {
        final lyrics = await content.parseLyrics(
          text: input.text,
          format: input.format,
        );
        expect(lyrics.lines.first.startMs, BigInt.from(1000));
        expect(lyrics.lines.first.text, 'First');
        if (input.format != 'lrc')
          expect(lyrics.lines.first.endMs, BigInt.from(2500));
      }
      final plain = await content.parseLyrics(
        text: 'One\nTwo',
        format: 'plain',
      );
      expect(plain.lines.map((line) => line.startMs), [null, null]);
      expect(plain.lines.map((line) => line.text), ['One', 'Two']);
      await expectLater(
        content.parseLyrics(text: '[00:99]Bad', format: 'lrc'),
        throwsA(
          isA<api.BridgeError>().having((e) => e.code, 'code', 'InvalidInput'),
        ),
      );
    },
  );
}
