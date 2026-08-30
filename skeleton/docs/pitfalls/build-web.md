# Pitfalls -- Web build (WebGL)


**WARNING: WebGL is the only platform whose default stripping is the most aggressive one.**
[inherited] The Input System resolves its control layouts **through reflection**: at the high level,
the game starts normally and **stops responding to the keyboard**. Set `ManagedStrippingLevel.Low`.

**WARNING: the browser cache mixes two builds.** [inherited] The WebGL output files always carry the
same name from one build to the next. The browser can therefore pair the `.data` of one build with
the `.wasm` of another. The symptom is **not** "stale version", it is:

```
Loading failed: RuntimeError: memory access out of bounds
  at wasm://wasm/0b2ac7ce:wasm-function[97296]:0x1712ca9
  ... three hundred lines of offsets, not a single method name ...
```

An hour was lost looking for that **in the game code**. The counter-measure is twofold:
1. a build id injected into the page's URLs (`BuildTools.StampWebCacheBuster`);
2. WARNING: **the host page itself must never be cached** -- it is the only one carrying that id.
   Cached, it keeps pointing at the old build's files: *an invalidation mechanism carried by a
   cacheable resource cancels itself out.* `http-equiv` tags are not enough (Chrome ignores them for
   the main document): real HTTP headers are needed, hence `tools/serve_web.py`.

**WARNING: a single-threaded local server blocks the game's startup.** [inherited]
`socketserver.TCPServer` handles one request at a time; the browser keeps its connections open and a
game preloading its `StreamingAssets` in parallel blocks its own requests. The game stays on its
loading bar -- which even seems to go backwards -- **with no error at all**, neither browser side nor
server side.

**WARNING: the itch channel name decides whether the file is PLAYABLE in the browser.** [inherited]
`html5` (or `html`, or `web`) is recognised as such; any other name produces an archive to download,
which installs perfectly and does not play. Nothing reports it. Prerequisite on the itch side, to do
once: *Kind of project* = **HTML**, and the file ticked "played in the browser".

**WARNING: the mobile `devicePixelRatio` is the most profitable performance setting.** [inherited] A
recent phone announces 3: Unity then renders **nine times** more pixels than the logical panel shows,
on a GPU ten times weaker than a desktop card. The frame rate collapses without any error saying so.
Force `config.devicePixelRatio = 1` on mobile.

**WARNING: the version manifest belongs to the downloadable target only.** [inherited] A web player
is always up to date (the page serves the current build). Pushing the manifest from a web release
would announce to every Windows player an update that does not exist.

**WARNING: Unity drops a `Data/` folder (Burst code) at the ROOT of the project** during a WebGL
build, outside any build folder. An artefact -- ignored by git.
