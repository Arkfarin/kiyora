#!/usr/bin/env python3
"""Gradle's Rust/NDK build step. TDLib is prepared by package_android.sh."""
import argparse
import os
from pathlib import Path
import platform
import shutil
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--abis', default='arm64-v8a')
args = parser.parse_args()
root = Path(__file__).resolve().parents[2] / 'rust'
ndk_value = os.environ.get('ANDROID_NDK_HOME') or os.environ.get('NDK_HOME')
if not ndk_value:
    sdk = os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT')
    properties = root.parent / 'flutter/android/local.properties'
    if not sdk and properties.is_file():
        sdk = next((line.split('=', 1)[1] for line in properties.read_text().splitlines()
                    if line.startswith('sdk.dir=')), None)
    if not sdk:
        raise SystemExit('Set ANDROID_HOME or ANDROID_NDK_HOME for Android NDK 28.2.13676358')
    ndk_value = str(Path(sdk) / 'ndk/28.2.13676358')
ndk = Path(ndk_value).resolve()
host = {'Linux': 'linux-x86_64', 'Darwin': 'darwin-x86_64'}.get(platform.system())
if not host:
    raise SystemExit('Use Linux or macOS to cross-compile the Android native bundle')
bin_dir = ndk / 'toolchains/llvm/prebuilt' / host / 'bin'
targets = {'arm64-v8a': 'aarch64-linux-android', 'x86_64': 'x86_64-linux-android'}
for abi in args.abis.split(','):
    if abi not in targets:
        raise SystemExit(f'Unsupported Android ABI: {abi}')
    if not (root / 'target/native/android-jni' / abi / 'libtdjson.so').is_file():
        raise SystemExit(f'Prepare TDLib first: KIYORA_ANDROID_ABI={abi} bash rust/scripts/prepare-android-native.sh')
    triple = targets[abi]
    key = triple.replace('-', '_')
    compiler = bin_dir / f'{triple}26-clang'
    if not compiler.is_file():
        raise SystemExit('The NDK compiler is missing')
    env = dict(os.environ)
    env.update({
        f'CC_{key}': str(compiler), f'CXX_{key}': str(bin_dir / f'{triple}26-clang++'),
        f'AR_{key}': str(bin_dir / 'llvm-ar'),
        f'CARGO_TARGET_{key.upper()}_LINKER': str(compiler),
        f'CARGO_TARGET_{key.upper()}_RUSTFLAGS': '-C link-arg=-Wl,-z,max-page-size=16384',
        'ANDROID_NDK_HOME': str(ndk), 'ANDROID_PLATFORM': 'android-26',
        'CARGO_TARGET_DIR': str(root / 'target/flutter-android'),
        'CARGO_BUILD_JOBS': os.environ.get('CARGO_BUILD_JOBS', '2'),
    })
    subprocess.run(['cargo', 'build', '--locked', '--release', '--target', triple,
                    '-p', 'kiyora-flutter-bridge'], cwd=root, env=env, check=True)
    destination = root / 'target/native/flutter-jni' / abi
    destination.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / 'target/flutter-android' / triple / 'release/libkiyora_flutter_bridge.so',
                 destination / 'libkiyora_flutter_bridge.so')
