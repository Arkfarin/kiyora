#!/usr/bin/env python3
"""Build a Flutter desktop bundle with the repository's pinned native sources.

No Tauri frontend, device execution, test command, signing or publication.
"""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--debug', action='store_true')
parser.add_argument('--deb', action='store_true', help='Create a Linux Debian installer')
args = parser.parse_args()
flutter_root = Path(__file__).resolve().parent.parent
rust_root = flutter_root.parent / 'src-tauri'
windows = os.name == 'nt'
platform = 'windows' if windows else 'linux'
if not windows and os.uname().machine != 'x86_64':
    raise SystemExit('Linux x86_64 host required')
flutter = shutil.which('flutter')
if not flutter:
    raise SystemExit('Add Flutter 3.50.0 to PATH')
prepare = (['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
            'scripts/prepare-windows-native.ps1'] if windows else
           ['bash', 'scripts/prepare-linux-native.sh'])
subprocess.run(prepare, cwd=rust_root, check=True)
subprocess.run([flutter, 'pub', 'get', '--enforce-lockfile'], cwd=flutter_root, check=True)
subprocess.run([flutter, 'build', platform, '--debug' if args.debug else '--release', '--no-pub'],
               cwd=flutter_root, check=True)
mode = 'debug' if args.debug else 'release'
bundle = (flutter_root / 'build/windows/x64/runner' / mode.capitalize() if windows else
          flutter_root / 'build/linux/x64' / mode / 'bundle')
native = rust_root / 'target/native/desktop'
for name in ('native', 'licenses'):
    destination = bundle / name
    if not windows and name == 'licenses':
        destination /= 'native'
    shutil.copytree(native / name, destination, dirs_exist_ok=True)
if not windows:
    shutil.copytree(rust_root / 'licenses', bundle / 'licenses', dirs_exist_ok=True)
    shutil.copy2(rust_root / 'vendor/souvlaki/LICENSE', bundle / 'licenses/souvlaki-LICENSE')
    shutil.copy2(rust_root / 'vendor/souvlaki/KIYORA-PATCH.md', bundle / 'licenses/souvlaki-PATCH.md')
for item in native.glob('*.json'):
    if item.name != 'tauri-bundle.json':
        shutil.copy2(item, bundle / item.name)
library = bundle / 'native' / ('tdjson.dll' if windows else 'libtdjson.so')
if not library.is_file():
    raise SystemExit('Native preparation did not produce TDLib')
output = flutter_root / 'build/packages'
output.mkdir(parents=True, exist_ok=True)
archive = shutil.make_archive(str(output / f'kiyora-flutter-{platform}-x64-{mode}'),
                              'zip' if windows else 'gztar', root_dir=bundle)
artifacts = [Path(archive)]
if args.deb:
    if windows:
        raise SystemExit('--deb requires Linux')
    if not shutil.which('dpkg-deb'):
        raise SystemExit('Install dpkg-deb to produce a Debian installer')
    stage = output / 'deb-stage'
    if stage.exists():
        shutil.rmtree(stage)
    shutil.copytree(bundle, stage / 'usr/lib/kiyora')
    (stage / 'usr/bin').mkdir(parents=True)
    (stage / 'usr/bin/kiyora').symlink_to('../lib/kiyora/kiyora')
    desktop = stage / 'usr/share/applications'
    desktop.mkdir(parents=True)
    (desktop / 'io.github.arkfarin.kiyora.desktop').write_text(
        '[Desktop Entry]\nType=Application\nName=KIYORA\nExec=kiyora\n'
        'Icon=io.github.arkfarin.kiyora\nTerminal=false\nCategories=AudioVideo;Audio;Music;\n'
        'StartupWMClass=io.github.arkfarin.kiyora\n', encoding='utf-8')
    icons = stage / 'usr/share/icons/hicolor/256x256/apps'
    icons.mkdir(parents=True)
    shutil.copy2(rust_root / 'icons/128x128@2x.png', icons / 'io.github.arkfarin.kiyora.png')
    control = stage / 'DEBIAN'
    control.mkdir()
    version_line = next(line for line in (flutter_root / 'pubspec.yaml').read_text().splitlines()
                        if line.startswith('version:'))
    version = version_line.split(':', 1)[1].strip().replace('+', '-')
    (control / 'control').write_text(
        f'Package: kiyora\nVersion: {version}\nArchitecture: amd64\n'
        'Maintainer: KIYORA contributors\nSection: sound\nPriority: optional\n'
        'Depends: libgtk-3-0t64, libasound2t64, libstdc++6, libsecret-1-0\n'
        'Description: Personal Telegram music library with a Flutter interface\n', encoding='utf-8')
    package = output / f'kiyora_{version}_amd64.deb'
    subprocess.run(['dpkg-deb', '--root-owner-group', '--build', str(stage), str(package)], check=True)
    artifacts.append(package)
with (output / 'SHA256SUMS').open('w') as sums:
    for artifact in artifacts:
        with artifact.open('rb') as source:
            digest = hashlib.file_digest(source, 'sha256').hexdigest()
        sums.write(f'{digest}  {artifact.name}\n')
print('\n'.join(str(artifact) for artifact in artifacts))
