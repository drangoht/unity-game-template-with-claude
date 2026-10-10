# Publishing runbook -- __GAME_NAME__

Short version: the **`/publish-itch`** skill. End to end, devlog included: the **`release-manager`**
agent. This document is the detail, to be read when something falls outside the ordinary.

## What is published, and where

| itch channel | What it carries | How the player gets it |
|---|---|---|
| `html5` | `Build/Web` | The page serves the current build -- always up to date |
| `windows` | `Build/Windows` | Auto-update through the itch app, or download |

WARNING: **the channel name decides whether the file is playable in the browser.** `html5`, `html` or
`web` are recognised as such; any other name produces an archive to download, which installs
perfectly and **does not play**. Nothing reports it.

## Prerequisites, to do ONCE

1. **Create the page** at `https://__ITCH_USER__.itch.io/__GAME_SLUG__`.
2. **`Kind of project` = HTML** for a web game (as long as the project is "Downloadable", the web
   build gets downloaded instead of played), and tick on the file
   **"This file will be played in the browser"**.
3. **Butler authenticated**: install the itch.io app (it supplies and updates `butler.exe` in its
   `broth` folder, which the script detects on its own). If "not authorized", run
   `"<butler.exe>" login` once.
4. Check the three settings that are **in no file of the repo**: the **Mobile friendly** checkbox,
   the **Classification** tab (including the player count), the declared **orientation**.

## The procedure

```
1. Choose the semver           x.y.Z patch - x.Y.0 content - X.0.0 overhaul
2. Commit EVERYTHING           otherwise the stamp carries a "+" and designates no commit
3. Close the Unity editor      otherwise the command-line build fails
4. & "tools/release_itch.ps1" -Version X.Y.Z -DryRun
5. & "tools/release_itch.ps1" -Version X.Y.Z
6. Check                       launch the published game, read the stamp at the bottom right
7. Update the docs             README, CLAUDE.md, docs/ITCH_STORE_PAGE.md if visible
8. Devlog                      docs/DEVLOG.md, then pasted on itch -- TICK "Published"
```

From the root, **without `-ExecutionPolicy Bypass`**: that flag is refused by the automatic
classifier and makes the call fail.

## What the script does, and why each step exists

1. **Sets `bundleVersion`** in `ProjectSettings.asset`. It is what `Application.version` reads, hence
   the stamp shown in game. Leaving it behind would make the build announce itself under an old
   number.
2. **Builds** (regenerated scene included), and requires an **explicit success phrase** in the log: a
   zero exit code does not tell "built" apart from "nothing to do".
3. **Checks the stamp produced BY the build.** WARNING: a release has already shipped the binary of
   the **previous** version without a single error being raised. Neither the date (incremental build:
   an identical file is not rewritten) nor the Windows metadata (which describes the **engine**) makes
   it possible to notice. Only the embedded version settles it. **Do not bypass this check.**
4. **Prepares a clean distribution folder**, without the Burst symbols Unity itself names
   "DoNotShip". Butler diffs file by file: we push a folder, not an archive.
5. **`butler push`** with `--userversion`.
6. **Commit + push** of the version number (and of the manifest, for the Windows target only -- a web
   player is always up to date, and pushing a manifest for them would announce to Windows players an
   update that does not exist).

## Diagnosis

| Symptom | Cause |
|---|---|
| "Unity.exe ... is not recognized" | Unity path never supplied: `& "tools/configure.ps1" -UnityPath "..."` |
| "another Unity instance is running" | The editor is open. Do not kill it: wait. |
| Build "fails" but no log written | Unity launched with `&` instead of `Start-Process -Wait` |
| "The build carries version X" | Stale build: `-SkipBuild` on a folder that was not rebuilt |
| Stamp suffixed with `+` | The tree was modified at build time -- commit first |
| Stamp `dev` | git unavailable during the build |
| "not authorized" (butler) | `"<butler.exe>" login`, once |
| The web build downloads instead of playing | Badly named channel, or `Kind of project` other than HTML |
| "git push failed" while all is well | A `$?` tested after a native exe. Only `$LASTEXITCODE` is authoritative. |

## After the release

- The `butler status` table may show the old version while the build is "processing" -- that is
  normal.
- WARNING: `Assets/Scenes/Game.unity` comes out modified (every `fileID` renumbered): discard it,
  **unless `SceneBuilder.cs` has changed**.
