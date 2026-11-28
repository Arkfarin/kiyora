#!/usr/bin/env python3
import struct
import tempfile
import unittest
import zipfile
from pathlib import Path

from verify_android_package import REQUIRED, verify, verify_elf


def elf(machine=183, alignment=16384):
    ident = b"\x7fELF\x02\x01" + bytes(10)
    header = struct.pack("<16sHHIQQQIHHHHHH", ident, 3, machine, 1,
                         0, 64, 0, 0, 64, 56, 1, 0, 0, 0)
    segment = struct.pack("<IIQQQQQQ", 1, 5, 0, 0, 0, 120, 120, alignment)
    return header + segment


class PackageTests(unittest.TestCase):
    def test_rejects_4k_and_wrong_machine(self):
        verify_elf(elf(), "arm64-v8a", "test.so")
        with self.assertRaisesRegex(ValueError, "16 KiB"):
            verify_elf(elf(alignment=4096), "arm64-v8a", "test.so")
        with self.assertRaisesRegex(ValueError, "does not match"):
            verify_elf(elf(machine=62), "arm64-v8a", "test.so")

    def test_checks_every_requested_abi(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "app.aab"
            with zipfile.ZipFile(path, "w") as archive:
                for library in REQUIRED:
                    archive.writestr(f"base/lib/arm64-v8a/{library}", elf())
            verify(path, ["arm64-v8a"])
            with self.assertRaisesRegex(ValueError, "x86_64: missing"):
                verify(path, ["arm64-v8a", "x86_64"])


if __name__ == "__main__":
    unittest.main()
