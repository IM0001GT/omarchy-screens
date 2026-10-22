"""Read a small Wayland clipboard offer outside the shell, with a total deadline."""
import json
import os
import selectors
import signal
import subprocess
import sys
import time


def read_text(command, limit, timeout=1.0):
    deadline = time.monotonic() + timeout
    with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL) as proc:
        try:
            data = bytearray()
            with selectors.DefaultSelector() as selector:
                selector.register(proc.stdout, selectors.EVENT_READ)
                while True:
                    remaining = deadline - time.monotonic()
                    if remaining <= 0 or not selector.select(remaining):
                        return ""
                    chunk = os.read(proc.stdout.fileno(), min(4096, limit + 1 - len(data)))
                    if not chunk:
                        return data.decode("utf-8", errors="replace")
                    data.extend(chunk)
                    if len(data) > limit:
                        return ""
        finally:
            if proc.poll() is None:
                proc.kill()
            proc.wait()


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(1))
    try:
        limit = int(sys.argv[1])
    except (IndexError, ValueError):
        sys.exit(1)
    if not 0 < limit <= 1024:
        sys.exit(1)
    which = sys.argv[2] if len(sys.argv) > 2 else ""
    if which not in ("clipboard", "primary"):
        sys.exit(1)
    command = ["wl-paste", "--no-newline", "--type", "text"]
    if which == "primary":
        command.append("--primary")
    try:
        print(json.dumps(read_text(command, limit)))
    except OSError:
        print('""')
