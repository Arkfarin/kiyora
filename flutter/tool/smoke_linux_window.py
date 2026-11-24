#!/usr/bin/env python3
"""First-frame and normal-close checks on the Umbriel Wayland compositor."""
import argparse
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    args = parser.parse_args()
    executable = args.bundle.resolve() / "kiyora"
    with tempfile.TemporaryDirectory(prefix="kiyora-window-smoke-") as temporary:
        for mode in ("wayland", "x11"):
            data = Path(temporary) / mode
            data.mkdir(mode=0o700)
            env = dict(os.environ, GDK_BACKEND=mode, KIYORA_DATA_DIR=str(data))
            for name in ("KIYORA_NATIVE_LIBRARY", "KIYORA_TDJSON"):
                env.pop(name, None)
            stream = subprocess.Popen(["umbriel", "subscribe", "windows"],
                                      stdout=subprocess.PIPE, text=True)
            selector = selectors.DefaultSelector()
            selector.register(stream.stdout, selectors.EVENT_READ)
            with tempfile.TemporaryFile() as log:
                process = subprocess.Popen(["dbus-run-session", "--", str(executable)],
                                           env=env, cwd=temporary, stdout=log, stderr=log,
                                           start_new_session=True)
                try:
                    deadline = time.monotonic() + 20
                    window = None
                    while time.monotonic() < deadline and process.poll() is None:
                        if not selector.select(0.2):
                            continue
                        line = stream.stdout.readline()
                        if not line:
                            raise RuntimeError("Compositor event stream ended")
                        event = json.loads(line)
                        for candidate in event.get("data", []):
                            if candidate.get("app_id", "").lower() != "io.github.arkfarin.kiyora":
                                continue
                            pid = candidate.get("pid", 0)
                            if pid <= 0:
                                continue
                            try:
                                owned = os.getpgid(pid) == process.pid
                            except ProcessLookupError:
                                continue
                            if owned and candidate.get("visible"):
                                window = candidate
                                break
                        if window:
                            break
                    if not window:
                        raise RuntimeError(f"{mode}: no visible first-frame window")
                    if bool(window["xwayland"]) != (mode == "x11"):
                        raise RuntimeError(f"{mode}: wrong display backend")
                    if window["w"] < 720 or window["h"] < 540:
                        raise RuntimeError(f"{mode}: window below supported minimum size")
                    subprocess.run(["umbriel", "msg", "window-close", str(window["id"])],
                                   check=True, stdout=subprocess.DEVNULL)
                    code = process.wait(timeout=20)
                    if code != 0:
                        raise RuntimeError(f"{mode}: normal window close exited with {code}")
                    print(f"{mode}: visible {window['w']}x{window['h']} first frame; normal close exited 0.",
                          flush=True)
                except Exception:
                    # Logs are from this disposable app and its private D-Bus only.
                    log.seek(0)
                    print(log.read().decode(errors="replace")[-8000:])
                    raise
                finally:
                    if process.poll() is None:
                        os.killpg(process.pid, signal.SIGTERM)
                        process.wait(timeout=5)
                    selector.close()
                    stream.terminate()
                    stream.wait(timeout=5)


if __name__ == "__main__":
    main()
