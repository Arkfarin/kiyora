#!/usr/bin/env python3
"""Exercise the actual Cargo build script with disposable, synthetic credentials."""
import json
import os
from pathlib import Path
import subprocess
import tempfile


def main():
    root = Path(__file__).resolve().parents[2]
    subprocess.run([
        "cargo", "build", "--locked", "--manifest-path",
        str(root / "rust/Cargo.toml"), "-p", "kiyora-flutter-bridge",
    ], check=True)
    target = Path(os.environ.get("CARGO_TARGET_DIR", root / "rust/target"))
    script = max(
        (target / "debug/build").glob("kiyora-flutter-bridge-*/build-script-build"),
        key=lambda p: p.stat().st_mtime,
    ).resolve()
    with tempfile.TemporaryDirectory(prefix="kiyora-build-config-") as temporary:
        work = Path(temporary)
        config = work / "telegram.json"
        output = work / "out"
        output.mkdir()
        env = {**os.environ, "HOME": str(work), "XDG_CONFIG_HOME": str(work),
               "OUT_DIR": str(output), "PROFILE": "release"}
        env.pop("KIYORA_TELEGRAM_CONFIG", None)

        def run(success):
            result = subprocess.run([str(script)], env=env, capture_output=True)
            assert (result.returncode == 0) == success, "Unexpected build-script result"
            # Never include captured output in an assertion: it may contain secrets
            # if the redaction contract regresses.
            assert b"sensitive-test-marker" not in result.stdout + result.stderr

        run(False)  # Release must not silently ship an unconfigured login.
        env["PROFILE"] = "debug"
        run(True)
        assert (output / "telegram.bin").read_bytes() == b""
        env["KIYORA_TELEGRAM_CONFIG"] = str(config)
        run(False)  # Explicit missing file is an error even in debug.
        config.write_text('{"api_hash":"sensitive-test-marker", malformed}')
        config.chmod(0o600)
        run(False)
        config.write_text(json.dumps({"api_id": 1, "api_hash": "sensitive-test-marker"}))
        run(False)
        config.write_text(json.dumps({"api_id": 1, "api_hash": "a" * 32}))
        if os.name == "posix":
            config.chmod(0o644)
            run(False)
            config.chmod(0o600)
        env["PROFILE"] = "release"
        run(True)
        assert (output / "telegram.bin").read_bytes() == (1).to_bytes(4, "little") + b"a" * 32
        if os.name == "posix":
            assert (output / "telegram.bin").stat().st_mode & 0o077 == 0
    print("Build configuration: missing/invalid/private-file/redaction checks passed.")


if __name__ == "__main__":
    main()
