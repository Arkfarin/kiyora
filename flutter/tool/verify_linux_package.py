#!/usr/bin/env python3
"""Verify a Linux tar package and run its native libraries from a path with spaces."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--window-smoke", action="store_true", help="Also launch/close on Umbriel Wayland and XWayland")
    args = parser.parse_args()
    archive = args.archive.resolve()
    root = Path(__file__).resolve().parents[2]
    checksums = dict(line.split(maxsplit=1)[::-1]
                     for line in (archive.parent / "SHA256SUMS").read_text().splitlines())
    if checksums.get(archive.name) != digest(archive):
        raise SystemExit("Package digest does not match SHA256SUMS")
    with tempfile.TemporaryDirectory(prefix="kiyora extracted package ") as temporary:
        bundle = Path(temporary) / "application with spaces"
        bundle.mkdir()
        with tarfile.open(archive) as source:
            source.extractall(bundle, filter="data")
        required = ["kiyora", "lib/libkiyora_flutter_bridge.so", "lib/libapp.so",
                    "lib/libflutter_linux_gtk.so", "data/icudtl.dat", "native/libtdjson.so",
                    "licenses/native/TDLib.txt", "licenses/native/OpenSSL.txt",
                    "licenses/native/zlib.txt", "licenses/libopus-COPYING",
                    "licenses/opusic-sys-LICENSE", "licenses/opus-rs-LICENSE-MIT",
                    "licenses/opus-rs-LICENSE-APACHE", "licenses/souvlaki-LICENSE",
                    "licenses/souvlaki-PATCH.md", "data/flutter_assets/NOTICES.Z"]
        for name in required:
            if not (bundle / name).is_file() or not (bundle / name).stat().st_size:
                raise SystemExit(f"Packaged file missing or empty: {name}")
        if not os.access(bundle / "kiyora", os.X_OK):
            raise SystemExit("Packaged executable lost its execute permission")
        manifest = json.loads((bundle / "native/manifest.json").read_text())
        pin = json.loads((root / "rust/scripts/native-sources.json").read_text())["tdlib"]
        if (manifest["platform"], manifest["tdlib_version"], manifest["tdlib_revision"]) != (
                "linux-x86_64", pin["version"], pin["revision"]):
            raise SystemExit("Packaged TDLib identity differs from the reviewed pin")
        if manifest["sha256"] != digest(bundle / "native/libtdjson.so"):
            raise SystemExit("Packaged TDLib digest mismatch")
        for path in [bundle / "kiyora", *sorted((bundle / "lib").glob("*.so")),
                     bundle / "native/libtdjson.so"]:
            linkage = subprocess.check_output(["ldd", str(path)], text=True,
                                              stderr=subprocess.STDOUT)
            if "not found" in linkage:
                raise SystemExit(f"Unresolved dependency in {path.name}:\n{linkage}")
        print("Archive checksum, payload, licenses and host dependencies passed.", flush=True)
        subprocess.run([sys.executable, str(root / "flutter/tool/test_auth.py"),
                        "--bundle", str(bundle)], cwd=temporary, check=True, timeout=310)
        if args.window_smoke:
            subprocess.run([sys.executable, str(root / "flutter/tool/smoke_linux_window.py"),
                            str(bundle)], cwd=temporary, check=True, timeout=100)
    print("Extracted package verification passed; temporary installation removed.")


if __name__ == "__main__":
    main()
