"""Serves the web build locally, WITHOUT browser cache.

Why this tool rather than `python -m http.server`
-------------------------------------------------
Unity's WebGL output files always carry the same name from one build to the next
(`web.wasm.unityweb`, `web.data.unityweb`). Python's built-in server sends no `Cache-Control`: the
browser then applies its own freshness heuristic and serves what it has in memory. After a rebuild,
it can therefore pair the `.data` of one build with the `.wasm` of another.

The symptom is not "stale version". It is, at startup:

    Loading failed: RuntimeError: memory access out of bounds
      at wasm://wasm/0b2ac7ce:wasm-function[97296]:0x1712ca9
      ... three hundred lines of offsets, not a single method name ...

An hour has already been lost looking for that in the game code. The build does set a cache buster
(`BuildTools.StampWebCacheBuster`), but it lives in `index.html` -- and if the host page itself
comes out of the cache, the cache buster still points at the old build's files. An invalidation
mechanism carried by a cacheable resource cancels itself out: it needs a non-cacheable root, and
only a real HTTP header gets that. HTML `http-equiv` tags are not enough, Chrome ignores them for
the main document.

Usage
-----
    py tools/serve_web.py                  # http://localhost:8080
    py tools/serve_web.py --port 9000
    py tools/serve_web.py --dir Build/Web

WARNING: if the game stays broken while this server is running, the browser cache is already
polluted by a previous session: changing the port gives a fresh origin, hence a clean cache.
"""

from __future__ import annotations

import argparse
import functools
import http.server
import pathlib


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    """Serves files forbidding any cache, and announcing the types Unity needs."""

    def end_headers(self) -> None:
        # WARNING: `no-store` TARGETED, not global. Applied to everything, the `.data` (often tens
        # of MB) is re-downloaded at every launch and the game takes a minute to start. Yet the
        # defect only ever concerns the host page and the engine files -- the ones whose name does
        # not change from one build to the next. The rest can be cached without risk.
        if self._must_not_be_cached():
            # `no-store` and not `no-cache`: the latter allows storage and merely requires a
            # revalidation, which the browser may skip (back button, tab restore). Here we want it
            # to keep nothing.
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
            self.send_header("Pragma", "no-cache")
            self.send_header("Expires", "0")

        super().end_headers()

    def _must_not_be_cached(self) -> bool:
        path = self.path.split("?", 1)[0].rstrip("/")

        # The host page: it is the one carrying the build id that invalidates everything else.
        # Cached, it keeps pointing at the old build's files -- the cache buster then exists, it is
        # correct, and it never applies.
        if path in ("", "/index.html"):
            return True

        # The four engine files, whose names are identical from one build to the next.
        return path.startswith("/Build/")

    def guess_type(self, path):
        # Unity produces `.unityweb` files that Python's server does not know about. The type
        # matters little here (the JS decompression fallback is active), but an explicit type stops
        # a browser from trying to interpret them.
        if str(path).endswith(".unityweb"):
            return "application/octet-stream"
        if str(path).endswith(".wasm"):
            return "application/wasm"
        return super().guess_type(path)

    def log_message(self, fmt: str, *args) -> None:
        # Per-request logging drowns the output: a web build makes hundreds of requests.
        # We keep only the errors.
        status = args[1] if len(args) > 1 else ""
        if str(status).startswith(("4", "5")):
            super().log_message(fmt, *args)


def main() -> int:
    parser = argparse.ArgumentParser(description="Serves the web build without browser cache.")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--dir", default="Build/Web")
    args = parser.parse_args()

    root = pathlib.Path(args.dir).resolve()
    if not (root / "index.html").exists():
        print(f"!! {root} does not contain index.html - has the web build been made?")
        return 1

    handler = functools.partial(NoCacheHandler, directory=str(root))

    # `allow_reuse_address`: without it, restarting the server right after stopping it fails during
    # the TIME_WAIT delay -- which pushes people to change ports and muddies the diagnosis.
    http.server.ThreadingHTTPServer.allow_reuse_address = True

    # WARNING x2: MULTI-THREADING IS MANDATORY, and it is not an optimisation.
    # `socketserver.TCPServer` handles ONE request at a time. The browser keeps its connections
    # open and a game preloading its StreamingAssets in parallel then blocks its own requests: the
    # preload never completes, the game stays on its loading bar -- which even seems to go
    # backwards. No error, neither browser side nor server side.
    with http.server.ThreadingHTTPServer(("", args.port), handler) as httpd:
        print(f"__GAME_NAME__ (web): http://localhost:{args.port}/")
        print(f"  folder   : {root}")
        print( "  cache    : disabled (Cache-Control: no-store)")
        print( "  touch    : add ?touch to force finger controls")
        print( "  Ctrl+C to stop.")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nStopped.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
