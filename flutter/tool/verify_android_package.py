#!/usr/bin/env python3
"""Verify native ABI coverage and 16 KiB ELF alignment in an APK or AAB."""
import argparse
import struct
import zipfile


MACHINES = {"arm64-v8a": 183, "x86_64": 62}
REQUIRED = {"libflutter.so", "libkiyora_flutter_bridge.so", "libtdjson.so"}


def verify_elf(data, abi, name):
    def require(condition, reason):
        if not condition:
            raise ValueError(f"{name}: {reason}")

    require(len(data) >= 64 and data[:6] == b"\x7fELF\x02\x01", "expected a 64-bit little-endian ELF")
    header = struct.unpack_from("<16sHHIQQQIHHHHHH", data)
    require(header[2] == MACHINES[abi], f"ELF does not match {abi}")
    phoff, entsize, count = header[5], header[9], header[10]
    require(entsize >= 56 and phoff + entsize * count <= len(data), "invalid program headers")
    loads = 0
    for index in range(count):
        kind, _, offset, vaddr, _, _, _, alignment = struct.unpack_from(
            "<IIQQQQQQ", data, phoff + entsize * index
        )
        if kind == 1:  # PT_LOAD
            loads += 1
            require(alignment >= 16384 and (offset - vaddr) % 16384 == 0,
                    "LOAD segment is incompatible with 16 KiB pages")
    require(loads > 0, "no LOAD segments")


def verify(path, abis):
    found = {abi: set() for abi in abis}
    with zipfile.ZipFile(path) as archive:
        for name in archive.namelist():
            parts = name.split("/")
            # APK: lib/ABI/name.so; AAB: base/lib/ABI/name.so.
            if len(parts) >= 3 and parts[-3] == "lib" and name.endswith(".so"):
                abi, library = parts[-2:]
                if abi not in found:
                    raise ValueError(f"Unexpected native ABI: {abi}")
                verify_elf(archive.read(name), abi, name)
                found[abi].add(library)
    for abi, libraries in found.items():
        if missing := REQUIRED - libraries:
            raise ValueError(f"{abi}: missing {', '.join(sorted(missing))}")
        print(f"{abi}: {len(libraries)} native libraries verified (16 KiB ELF alignment)")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package")
    parser.add_argument("--abis", default="arm64-v8a")
    args = parser.parse_args()
    abis = args.abis.split(",")
    if any(abi not in MACHINES for abi in abis) or len(set(abis)) != len(abis):
        parser.error("Expected unique arm64-v8a and/or x86_64 ABIs")
    try:
        verify(args.package, abis)
    except (OSError, ValueError, zipfile.BadZipFile, struct.error) as error:
        parser.exit(1, f"Android package verification failed: {error}\n")


if __name__ == "__main__":
    main()
