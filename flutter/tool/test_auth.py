#!/usr/bin/env python3
"""Opt-in real TDLib initialization, with an isolated Secret Service and no login."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def main():
    if not sys.platform.startswith("linux"):
        raise SystemExit("This acceptance runner targets Linux only")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, help="Test extracted native release libraries without rebuilding")
    parser.add_argument("--isolated-child", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    for command in ("flutter", "cargo", "dbus-run-session", "gnome-keyring-daemon"):
        if not shutil.which(command):
            raise SystemExit(f"Required command missing: {command}")
    if args.isolated_child:
        isolated = Path(os.environ["KIYORA_NATIVE_TEST_ROOT"])
        if (not (isolated / "isolated-native-test").is_file()
                or os.environ.get("XDG_DATA_HOME") != str(isolated / "xdg-data")
                or os.environ.get("XDG_CONFIG_HOME") != str(isolated / "xdg-config")
                or os.environ.get("XDG_RUNTIME_DIR") != str(isolated / "runtime")):
            raise SystemExit("Isolation marker missing")
        # This process is already on a private bus with temporary XDG paths.
        # A synthetic password unlocks only this disposable test keyring.
        subprocess.run([
            "gnome-keyring-daemon", "--unlock", "--components=secrets",
            "--control-directory", str(isolated / "keyring-control"),
        ], input=b"kiyora-disposable-test-keyring", stdout=subprocess.DEVNULL,
            check=True, timeout=15)
        subprocess.run([
            "gnome-keyring-daemon", "--start", "--components=secrets",
            "--control-directory", str(isolated / "keyring-control"),
        ], stdout=subprocess.DEVNULL, check=True, timeout=15)
        for phase in ("seed", "unavailable", "restore"):
            print(f"Native authentication phase: {phase}", flush=True)
            env = dict(os.environ, KIYORA_NATIVE_TEST_PHASE=phase)
            if phase == "unavailable":
                # Simulate an unavailable provider for this process only. Keep
                # the private keyring alive so restore proves no data was lost.
                env["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path={isolated}/missing-bus"
            subprocess.run([
                "flutter", "test", "--no-pub", "test_native/auth_test.dart",
            ], cwd=root / "flutter", env=env, check=True, timeout=90)
        return
    tdjson = (args.bundle / "native/libtdjson.so" if args.bundle else
              Path(os.environ.get("KIYORA_TDJSON",
                  root / "rust/target/native/desktop/native/libtdjson.so"))).resolve()
    if not tdjson.is_file():
        raise SystemExit("Build pinned TDLib first or set KIYORA_TDJSON")
    if args.bundle:
        library = args.bundle.resolve() / "lib/libkiyora_flutter_bridge.so"
        if not library.is_file():
            raise SystemExit("Extracted bundle is missing the native bridge")
    else:
        subprocess.run([
            "cargo", "build", "--locked", "-p", "kiyora-flutter-bridge",
        ], cwd=root / "rust", check=True)
        metadata = json.loads(subprocess.check_output([
            "cargo", "metadata", "--no-deps", "--format-version=1",
        ], cwd=root / "rust"))
        library = Path(metadata["target_directory"]) / "debug/libkiyora_flutter_bridge.so"
    with tempfile.TemporaryDirectory(prefix="kiyora-auth-test-") as temporary:
        isolated = Path(temporary)
        (isolated / "isolated-native-test").touch()
        env = dict(os.environ, KIYORA_NATIVE_TEST_ROOT=temporary,
                   KIYORA_NATIVE_LIBRARY=str(library), KIYORA_TDJSON=str(tdjson))
        env.pop("KIYORA_NATIVE_RESOURCES", None)
        if args.bundle:
            # Exercise production resource lookup; do not bypass it with a TDLib override.
            env.pop("KIYORA_TDJSON", None)
            env["KIYORA_NATIVE_RESOURCES"] = str(args.bundle.resolve())
        for variable, name in [
            ("KIYORA_DATA_DIR", "data"), ("XDG_DATA_HOME", "xdg-data"),
            ("XDG_CONFIG_HOME", "xdg-config"), ("XDG_CACHE_HOME", "xdg-cache"),
            ("XDG_RUNTIME_DIR", "runtime"),
        ]:
            path = isolated / name
            path.mkdir(mode=0o700)
            env[variable] = str(path)
        env.pop("GNOME_KEYRING_CONTROL", None)
        # Tests must never display a password prompt on the user's desktop.
        env.pop("DISPLAY", None)
        env.pop("WAYLAND_DISPLAY", None)
        subprocess.run([
            "dbus-run-session", "--", sys.executable, str(Path(__file__).resolve()),
            "--isolated-child",
        ], env=env, check=True, timeout=290)


if __name__ == "__main__":
    main()
