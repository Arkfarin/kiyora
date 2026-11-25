#!/usr/bin/env python3
"""Exercise generated Dart -> Rust APIs in two isolated Linux processes.

No account credentials or TDLib login are needed. The second process verifies
that the first process's active profile and queue preferences survived exit.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    if not os.sys.platform.startswith('linux'):
        raise SystemExit('This acceptance runner targets Linux only')
    flutter = shutil.which('flutter')
    dbus = shutil.which('dbus-run-session')
    if not flutter or not dbus:
        raise SystemExit('Add Flutter to PATH and install dbus-run-session')
    root = Path(__file__).resolve().parent.parent
    rust = root.parent / 'rust'
    subprocess.run(['cargo', 'build', '--locked', '-p', 'kiyora-flutter-bridge'],
                   cwd=rust, check=True)
    metadata = json.loads(subprocess.check_output(
        ['cargo', 'metadata', '--no-deps', '--format-version=1'], cwd=rust))
    library = Path(metadata['target_directory']) / 'debug/libkiyora_flutter_bridge.so'
    with tempfile.TemporaryDirectory(prefix='kiyora-native-test-') as temporary:
        isolated = Path(temporary)
        (isolated / 'isolated-native-test').touch()
        (isolated / 'data').mkdir()
        environment = dict(os.environ, KIYORA_NATIVE_TEST_ROOT=temporary,
                           KIYORA_DATA_DIR=str(isolated / 'data'),
                           KIYORA_NATIVE_LIBRARY=str(library),
                           KIYORA_TDJSON=str(isolated / 'unused-tdjson.so'))
        # Missing TDLib is intentional: these lifecycle checks never log in.
        for phase in ('seed', 'restore'):
            print(f'Native bridge phase: {phase}', flush=True)
            environment['KIYORA_NATIVE_TEST_PHASE'] = phase
            subprocess.run([dbus, '--', flutter, 'test', '--no-pub',
                            'test_native/lifecycle_test.dart'],
                           cwd=root, env=environment, check=True, timeout=120)


if __name__ == '__main__':
    main()
