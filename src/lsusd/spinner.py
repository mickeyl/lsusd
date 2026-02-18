"""Terminal spinner for long-running discovery."""

import sys
import threading
import time

FRAMES = "\u280b\u2819\u2839\u2838\u283c\u2834\u2826\u2827\u2807\u280f"


class Spinner:
    def __init__(self, message="Scanning USB devices"):
        self._message = message
        self._stop = threading.Event()
        self._thread = None

    def __enter__(self):
        if sys.stderr.isatty():
            self._thread = threading.Thread(target=self._spin, daemon=True)
            self._thread.start()
        return self

    def __exit__(self, *_):
        self._stop.set()
        if self._thread:
            self._thread.join()
            sys.stderr.write("\r\033[K")
            sys.stderr.flush()

    def _spin(self):
        start = time.monotonic()
        i = 0
        while not self._stop.wait(0.08):
            elapsed = time.monotonic() - start
            frame = FRAMES[i % len(FRAMES)]
            sys.stderr.write(f"\r{frame} {self._message}\u2026 ({elapsed:.1f}s)")
            sys.stderr.flush()
            i += 1
