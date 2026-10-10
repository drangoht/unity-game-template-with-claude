# unity-game-template

Starter template for a 2D Unity game aimed at itch.io, **driven by Claude Code**.

It does not contain a game engine: it contains **what you redo every time** -- the command-line
build chain, itch.io publishing with its safeguards, the in-game verification tooling, and a team of
Claude Code agents already schooled in the pitfalls. All of it distilled from two published
projects, **Chimera Protocol** and **Smily Volley**.

> **The real content of this repo is `docs/pitfalls/`.** Each entry matches a defect that raised
> **neither a compilation error, nor an exception, nor a warning** -- only a game that misbehaves.
> That is the category of bug that costs hours and is never rediscovered with pleasure.

---

## Creating a game

From the template folder:

```powershell
& "tools/new-game.ps1"
```

The script asks for what it is missing -- game name, **where to keep the projects**, itch username
-- and detects Unity on its own. Everything can also be given in one line, and that is the form to
use from an agent or a CI, where `Read-Host` cannot answer:

```powershell
& "tools/new-game.ps1" `
    -Name "My Game" `
    -Destination "D:\Games" `
    -Pitch "The classic Snake game" `
    -ItchUser Drangoht `
    -UnityPath "C:\Program Files\Unity\Hub\Editor\6000.5.6f1" `
    -Build
```

That command creates `D:\Games\my-game`, with the C# namespace `MyGame`, the itch page
`drangoht.itch.io/my-game`, the Unity version `6000.5.6f1` read from the editor path -- then goes on
to the first build without asking anything, and leaves the terminal in `D:\Games\my-game`.

What happens:

1. `skeleton/` is copied to `<games folder>\my-game`;
2. the `__XXX__` tokens are replaced in the **text** files, and the folders that carry them are
   renamed;
3. the script checks that **no token survives** -- a forgotten token compiles (it is a valid
   identifier) and only shows up much later, in the form of a path that does not exist;
4. Unity's path is written into the project's `tools/local.settings.json` (out of git);
5. `git init` + first commit;
6. the first build is offered -- it is what imports the project (~20 min);
7. **the terminal is placed in the game folder**: everything that follows (`tools/build.ps1`, the
   tests, Claude Code) happens there, and not in the template.

### The switches

Only one is mandatory: `-Name`. All the rest is derived, remembered from one run to the next, or
asked for.

| Switch | Value | Default | What it changes |
|---|---|---|---|
| `-Name` | Display name, spaces and accents allowed | **asked for** | Editor menu, window title, docs, itch page. Also sets `-Slug` and `-Namespace` |
| `-Slug` | Lowercase, digits, hyphens | derived from the name (`My Game` -> `my-game`) | Name of the created folder **and** identifier of the itch page. Rejected if it contains a capital, a space or an accent |
| `-Namespace` | PascalCase C# identifier | derived from the slug (`my-game` -> `MyGame`) | Namespace of all the code, executable name, name of the `Assets/WebGLTemplates/` folder |
| `-Destination` | **Parent** folder, created if missing | remembered, otherwise asked for | Where to keep the game. The project lands in `<Destination>\<slug>`; the script stops if that folder already exists |
| `-ItchUser` | itch.io username | remembered, otherwise asked for | The publishing URL `<user>.itch.io/<slug>`, used by `tools/release_itch.ps1` |
| `-Company` | Publisher name | the value of `-ItchUser` | `PlayerSettings.companyName`, hence the save path (`%APPDATA%\..\<Company>\<game>`). Changing it later **misplaces the existing saves** |
| `-Pitch` | One sentence | `A game.` | The `<meta description>` of the web page, and the tagline of the project's `README.md`, `CLAUDE.md`, GDD and itch page |
| `-Controls` | One sentence | `Arrow keys to move, Space to act.` | The note shown under the loading bar of the web build -- what the player reads while waiting |
| `-UnityPath` | The `Unity.exe`, its `Editor` folder, or the version folder | detected in Unity Hub (2nd drive included), otherwise asked for | The editor used for the builds. Copied into the project's `tools/local.settings.json`, which will never ask for it again |
| `-UnityVersion` | e.g. `6000.5.6f1` | read from the path of the editor found | What `ProjectSettings/ProjectVersion.txt` gets. WARNING: forcing it to a version different from the installed editor makes the Hub offer a migration at the first opening |
| `-Build` | *switch* | absent: offered interactively, ignored otherwise | Chains the first build straight away (~20 min). Without it **and** without an interactive terminal, the project stays unimported |
| `-NoGit` | *switch* | absent: `git init` + first commit | Leaves the folder without a repo. Useful for a throwaway trial of the template |
| `-NoRemember` | *switch* | absent: the answers are remembered | Writes nothing to `local.settings.json`. For a throwaway trial: otherwise its `-Destination` and `-ItchUser` become the defaults of every following game |
| `-NoCd` | *switch* | absent: the session is placed in the created project | Stays where you are. WARNING: without it, a `tools/build.ps1` typed afterwards does target the game -- that is the point; with it, remember the `cd`. No effect if the script runs in a separate process (`powershell -File`), which dies with its location |

The three reusable answers -- `-Destination`, `-ItchUser`, `-UnityPath` -- are written to
`local.settings.json` at the root of the template (not versioned): for the next game, `-Name` is
enough.

```powershell
& "tools/new-game.ps1" -Name "My Second Game" -Build
```

And to exercise the template without leaving anything behind:

```powershell
& "tools/new-game.ps1" -Name "Template Test" -Destination "$env:TEMP" -ItchUser trial -NoGit -NoCd -NoRemember
```

### Nothing machine-specific in the repo

This template knows neither your games layout, nor where Unity is installed.

- **Where to keep the project** is asked for on first use (`-Destination`), then remembered in
  `local.settings.json`, at the root of the template and **not versioned**.
- **Unity** is looked for in the Unity Hub installations, including the *secondary install path*
  (the other drive). If it stays undiscoverable, the script asks for it, and all the generated
  project's tools then know where it is. A hard-coded editor path always produces the same symptom
  on the next machine: `Unity.exe : The term 'Unity.exe' is not recognized as the name of a cmdlet`.
- **The itch username** follows the same route: asked for once, remembered.

### The first build does the import -- not Unity Hub

The produced folder contains `Assets/`, `Packages/` and `ProjectSettings/ProjectVersion.txt`. The
**first `tools/build.ps1` imports the project in batchmode** and generates the rest (`Library/`, the
complete `ProjectSettings/`): reckon on about twenty minutes, without opening Unity Hub or the
editor.

---

## What you get

```
my-game/
├── CLAUDE.md               Project memory -- loaded at every session, to be kept SHORT
├── TEAM-GUIDE.md           Who does what, in what order
├── README.md               The project seen from the outside
├── version.json            Manifest read by the "new version" banner
├── .claude/
│   ├── settings.json       Permissions + the two hooks
│   ├── agents/             9 agents
│   ├── skills/             /project-map · /write-the-gdd · /verify-in-game · /publish-itch
│   └── hooks/              guard.ps1 · run-rules-tests.ps1
├── .github/workflows/      CI: the Rules/ tests on a Linux runner, without Unity
├── Assets/
│   ├── Editor/             BuildTools · RenderPipelineSetup · SceneBuilder
│   ├── Scripts/Rules/      PURE testable logic
│   ├── Settings/           Ready-made URP assets (pipeline, 2D renderer) -- no mouse settings
│   └── WebGLTemplates/     Host page: framing, touch, audio, cache buster
├── .gitattributes          LF everywhere + Unity YAML merge + LFS rules for the big assets
├── Packages/manifest.json  URP + Input System + uGUI
├── ProjectSettings/        Unity version, and Burst off on the Windows side -- see its README
├── docs/                   GDD (contents + gdd/) · pitfalls/ (12 domains + index) · RELEASE
│                           DEVLOG · TEST_REPORT · ITCH_STORE_PAGE
├── tests/                  xUnit on Rules/ -- no engine required
└── tools/
    ├── build.ps1           Build (Windows/web), launch, capture -- THE entry point
    ├── configure.ps1       Say where Unity and Python are; diagnose the environment
    ├── environment.ps1     Resolution + memorisation of the tool paths
    └── release_itch.ps1 · serve_web.py · drive_game.py
```

---

## The four stances

### 1. The scene is an artefact, not a source

`Assets/Scenes/Game.unity` is **regenerated by `SceneBuilder.Build()`** at every build. You add an
object to the game by writing code, not by clicking in the editor.

That is the choice that makes all the rest possible: an agent can change a value, run the build again
in batchmode and **look at the result**. A `.unity` file edited with the mouse closes that door.

WARNING: corollary -- the scene comes out modified after every build (every `fileID` renumbered).
Discard it with `git checkout --`, unless `SceneBuilder.cs` has changed.
`BuildTools.HasLocalChanges` already excludes it from the tree cleanliness check -- without which
every build would declare itself "dirty".

### 2. Every numeric rule lives outside the engine

`Assets/Scripts/Rules/` contains **static classes with no `using UnityEngine` at all**, compiled **by
path** into the test assembly. Consequence: `dotnet test` runs in a few seconds, with no Unity
installed -- hence in CI on a Linux runner, and **automatically after every edit** through a
`PostToolUse` hook that wakes Claude up if a test breaks.

A file in `Rules/` that wrote `using UnityEngine` breaks the test compilation. That is intended: the
error arrives at the right moment, before the dependency settles in.

### 3. The binary carries its identity

Every build writes `build_stamp.json` and a `v<version>-<sha>` stamp displayed at the bottom of the
screen. It is not there for the player, but for the **bug report** -- and for the publishing script,
which refuses to push a build whose stamp does not carry the requested version.

Why that safeguard exists: **a release has already shipped the binary of the previous version without
a single error being raised.** Neither a file's date (Unity builds incrementally: an identical file
is not rewritten) nor the Windows metadata (which describes the **engine**, not the game) makes it
possible to notice. Only the embedded version settles it.

The stamp is set **by the build**, never by the publishing script: written only at publish time, it
would then stay in place and every later local build would show the SHA of the last release. *A
freshness safeguard that lies is worse than no safeguard, since people trust it.*

### 4. A change is observed, not reasoned about

`tools/drive_game.py` launches the Windows build, gives it focus with a **real click** (the only way
from a non-interactive shell), injects real keys with their scan code, and captures the window. The
`/verify-in-game` skill makes it the reference procedure.

"It compiles" proves nothing about a game: a positional key mapping, scenery rendered black for lack
of a global light, a menu that does not react -- none of these defects shows up at compile time, and
all of them are visible in thirty seconds on a screenshot.

---

## The agent team

9 agents, 4 skills, 2 hooks -- detail in the generated project's `TEAM-GUIDE.md`.

| Agent | Role |
|---|---|
| `developer` | Code, architecture, build, tests |
| `game-designer` | Design, balancing, scope |
| `game-tester` | Plays the game and documents what is wrong |
| `release-manager` | Publishes end to end + writes the devlog |
| `art-director` · `artist` · `musician` · `story-teller` · `marketing` | Production and shop window |

**The hooks do the work you forget to do:**
- `guard.ps1` (PreToolUse) refuses `git push --force`, `git reset --hard`, `git clean -f`, and any
  recursive deletion aimed outside the project. It inspects the **whole line** (chained commands
  included) where the `deny` rules only match by prefix -- and it **excludes the text of commit
  messages**, without which a message that *quotes* a dangerous command would block the commit.
- `run-rules-tests.ps1` (PostToolUse, asynchronous) replays the tests as soon as a file in `Rules/`
  or `tests/` is edited, and **wakes Claude up** if something breaks.

Both hooks derive the project root from their own location: nothing to substitute.

---

## Maintaining the template

This repo is only worth something if it ages well. Two rules:

1. **When a project teaches something generalisable, push it back here** -- a pitfall in
   `docs/pitfalls/<domain>.md`, an instruction in the relevant agent, a safeguard in a script. It is
   cheaper than rediscovering it on the next project.
2. **When a project proves the template wrong, fix it here too.** A stale instruction passed on to
   every new project is worse than a missing one: it is wrong, and it has the authority of the
   reference file.

The tokens recognised by `new-game.ps1`:

| Token | Example | Where it is used |
|---|---|---|
| `__GAME_NAME__` | `Smily Volley` | editor menu, window title, docs |
| `__GAME_SLUG__` | `smily-volley` | itch slug, folder name |
| `__NAMESPACE__` | `SmilyVolley` | C# namespace, exe name, WebGLTemplates folder |
| `__ITCH_USER__` | `my-username` | URL of the itch page |
| `__COMPANY__` | `my-username` | `PlayerSettings.companyName`, save path |
| `__PITCH__` | ... | page description, GDD |
| `__CONTROLS__` | ... | note shown during the web loading |
| `__UNITY_VERSION__` | `6000.5.6f1` | `ProjectVersion.txt`, docs -- derived from the editor found |
| `__DATE__` | `2026-08-26` | creation date in `CLAUDE.md` |

WARNING: **`__BUILD_ID__`, in `index.html`, is NOT a template token**: it is replaced by
`BuildTools.StampWebCacheBuster` at every build. The scaffolder only replaces the tokens in the table
above, never everything that looks like `__X__` -- that is deliberate.

WARNING: the substitution only touches the **known text extensions**. Rewriting a binary in UTF-8
corrupts it without reporting anything.

---

## Prerequisites

- **Unity 6** installed through Unity Hub, anywhere on the disk: it is detected, and can be supplied
  with `-UnityPath` otherwise.
- **.NET 8 SDK** for `dotnet test`.
- **Python 3** for `serve_web.py` and `drive_game.py` (+ `pillow` for the screenshots).
- **The itch.io app**, which supplies and updates `butler.exe` on its own.

`tools/configure.ps1`, in a generated project, says which one is missing and where the others are.
