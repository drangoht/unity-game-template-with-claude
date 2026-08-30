# Unity pitfalls -- index

**The most valuable content in the repo.** Each entry matches a defect actually encountered, which
**produced neither a compilation error, nor an exception, nor a warning** -- only a game that
misbehaves. That is the category of bug that takes hours to find and thirty seconds to fix.

> **This file is an index: open only the domain concerned.** It was split up because it grows
> endlessly -- reading it in full before every task cost more than the task itself. Open two or three
> relevant domains, never all twelve.

Entries marked **[inherited]** come from previous projects (Chimera Protocol, Smily Volley): they
have not been re-verified here, but each of them cost at least one regression.

## Where to look

| File | Open it when touching... | Keywords |
|---|---|---|
| [`pitfalls/assets-import.md`](pitfalls/assets-import.md) | adding or regenerating an asset | `.meta`, GUID, `Art/` vs `Resources/`, `AssetDatabase.Refresh` |
| [`pitfalls/urp-rendering.md`](pitfalls/urp-rendering.md) | rendering, camera, lighting, materials | `QualitySettings`, 2D Renderer, `Light2D`, black sprite |
| [`pitfalls/fonts-text.md`](pitfalls/fonts-text.md) | font, displayed text, symbols | glyph fallback, `cmap`, arrows lost in WebGL, SIL OFL |
| [`pitfalls/input.md`](pitfalls/input.md) | controls, keyboard, gamepad | AZERTY / QWERTY, `InputSystemUIInputModule`, first key lost |
| [`pitfalls/ui.md`](pitfalls/ui.md) | HUD, menus, modals, navigation | canvas sorting order, focus trap, affordance |
| [`pitfalls/build.md`](pitfalls/build.md) | `build.ps1`, versioning, build stamp | misleading exit code, editor open, regenerated scene |
| [`pitfalls/build-web.md`](pitfalls/build-web.md) | WebGL target, game page | stripping, browser cache, `html5` channel, `Data/` folder |
| [`pitfalls/touch-mobile.md`](pitfalls/touch-mobile.md) | touch port, `index.html` | `maxTouchPoints`, `dvh`, `devicePixelRatio`, no `Touchscreen` on desktop |
| [`pitfalls/tests-automation.md`](pitfalls/tests-automation.md) | headless tests, `drive_game.py`, screenshots | focus, Unity splash, capture window |
| [`pitfalls/powershell.md`](pitfalls/powershell.md) | writing or changing a `.ps1` script | `$?` after a native exe, `$ErrorActionPreference`, `-DryRun` |
| [`pitfalls/audio.md`](pitfalls/audio.md) | music, sound effects, mixing | silent lookup table, user gesture required, proving sound comes out |
| [`pitfalls/itch-publishing.md`](pitfalls/itch-publishing.md) | store page, devlog, itch.io | Redactor, Selectize, page cache, cross-origin iframe |

## Adding a pitfall

In the file of its domain, **in the commit that discovered it**. Strict admission rule:

> An entry describes a defect that raises **no** error. Neither compilation, nor exception, nor
> warning -- only wrong behaviour. An ordinary good practice has no place here.

Each entry says **what happens**, **why it does not show**, and **what works**. The observed symptom
is worth more than the abstract rule.

WARNING: **a domain file that goes past ~150 lines gets split** (`build.md` -> `build.md` +
`build-versioning.md`), and this table follows it. Otherwise we are back to the monolith we have just
taken apart.
