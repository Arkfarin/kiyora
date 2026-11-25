#!/usr/bin/env python3
"""Real FRB/SQLite/cache/decoder/ALSA/MPRIS smoke on an isolated virtual sink.

Requires a running PulseAudio-compatible server (including PipeWire). The test
never changes the default sink or uses a Telegram account. It captures only its
own generated tone, not a microphone or another application's audio.
"""
import array
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import wave


def main():
    required = ('flutter', 'cargo', 'pactl', 'parec', 'playerctl', 'dbus-run-session')
    missing = [name for name in required if not shutil.which(name)]
    if not os.sys.platform.startswith('linux') or missing:
        raise SystemExit(f'Linux and these tools are required: {missing or required}')
    root = Path(__file__).resolve().parent.parent
    rust = root.parent / 'rust'
    subprocess.run(['cargo', 'build', '--locked', '-p', 'kiyora-flutter-bridge',
                    '--lib', '--example', 'seed_offline_fixture'], cwd=rust, check=True)
    metadata = json.loads(subprocess.check_output(
        ['cargo', 'metadata', '--no-deps', '--format-version=1'], cwd=rust))
    target = Path(metadata['target_directory']) / 'debug'
    with tempfile.TemporaryDirectory(prefix='kiyora-playback-test-') as temporary:
        isolated = Path(temporary)
        (isolated / 'isolated-native-test').touch()
        (isolated / 'data').mkdir()
        samples = array.array('h', (int(2000 * math.sin(2 * math.pi * 440 * i / 48000))
                                    for i in range(48000 * 12)))
        with wave.open(str(isolated / 'tone.wav'), 'wb') as audio:
            audio.setparams((1, 2, 48000, 0, 'NONE', 'not compressed'))
            audio.writeframes(samples.tobytes())
        sink = f'kiyora_test_{os.getpid()}'
        config = isolated / 'alsa.conf'
        config.write_text(f'pcm.!default {{ type pulse device "{sink}" }}\n')
        environment = dict(os.environ, KIYORA_NATIVE_TEST_ROOT=temporary,
                           KIYORA_DATA_DIR=str(isolated / 'data'),
                           KIYORA_NATIVE_LIBRARY=str(target / 'libkiyora_flutter_bridge.so'),
                           KIYORA_TDJSON=str(isolated / 'unused-tdjson.so'),
                           KIYORA_AUDIO_TEST_SINK=sink, ALSA_CONFIG_PATH=str(config),
                           PULSE_SINK=sink)
        subprocess.run([str(target / 'examples/seed_offline_fixture')], env=environment, check=True)
        module = subprocess.check_output(['pactl', 'load-module', 'module-null-sink',
            f'sink_name={sink}', 'rate=48000', 'channels=2'], text=True).strip()
        try:
            with (isolated / 'capture.pcm').open('wb') as capture:
                recorder = subprocess.Popen(['parec', f'--device={sink}.monitor',
                    '--raw', '--rate=48000', '--channels=2', '--format=s16le'], stdout=capture)
                try:
                    result = subprocess.run(['dbus-run-session', '--', 'flutter', 'test', '--no-pub',
                        'test_native/playback_test.dart'], cwd=root, env=environment,
                        check=False, timeout=120)
                finally:
                    recorder.terminate()
                    recorder.wait(timeout=5)
            received = array.array('h')
            received.frombytes((isolated / 'capture.pcm').read_bytes())
            active = sum(abs(sample) > 100 for sample in received)
            print(f'Captured {len(received)} PCM samples; {active} contain the test signal')
            result.check_returncode()
            if active < 4800:
                raise SystemExit(f'No sustained PCM signal reached the test sink: {active} samples')
        finally:
            subprocess.run(['pactl', 'unload-module', module], check=True)


if __name__ == '__main__':
    main()
