# CLAUDE.md -- working ON the template

WARNING: **this repo is not a game.** It is the template that games are instantiated from. The code
under `skeleton/` is never compiled here: it carries `__XXX__` tokens that are only resolved at
instantiation time. So do not "fix" a `__NAMESPACE__` that looks like an error.

What it does and how it is used: **`README.md`**.

## What lives where

```
README.md              The manual (it is THE document of this repo)
tools/new-game.ps1     The scaffolder: asks, copies, substitutes, renames, git init, first build
local.settings.json    Remembered answers (games folder, Unity, itch username) -- NOT versioned
skeleton/              Everything that gets copied into a new project
modules/<name>/        Optional extras copied over the skeleton on request (`-Discord`)
```

The scaffolder has **no default taken from this machine**: neither a destination folder, nor a path
to Unity. What is missing is asked for, then remembered in `local.settings.json`. The detection
functions live in `skeleton/tools/environment.ps1`, which `new-game.ps1` dot-sources -- a single
implementation, not two that drift apart.

## Modifying the skeleton

1. **Edit inside `skeleton/`**, never in a generated project hoping it will come back.
2. **Use the tokens from the README's table** -- no hard-coded game name, no absolute path.
   The path of an external tool (Unity, Python) **must** go through `tools/environment.ps1`:
   `Get-UnityPathOrDie`, `Resolve-PythonCommand`. A hard-coded path works on the machine where it
   was written and nowhere else -- the symptom for the next person: "Unity.exe : The term
   'Unity.exe' is not recognized as the name of a cmdlet".
3. Anything that is not a known text extension (`$extensions` in `new-game.ps1`) is **not**
   substituted: add the extension if a new type of file carries a token.
4. **Exercise the instantiation** before committing:
   ```powershell
   & "tools/new-game.ps1" -Name "Template Test" -Destination "$env:TEMP" -ItchUser trial -NoGit -NoCd -NoRemember
   ```
   The script reports surviving tokens itself. No argument is asked for interactively here: this is
   the form to use from an agent or a CI, where `Read-Host` cannot answer. `-NoCd` keeps the session
   in the template -- without it, it ends up in the trial folder, which we delete just afterwards,
   and the shell is left with a cwd that no longer exists. Delete the trial folder afterwards.

## Context cost is a design criterion

Everything the skeleton makes people re-read **at every task** -- `CLAUDE.md`, the GDD,
`/project-map`, the pitfalls -- is paid for as many times as there are tasks, and once more by
**every delegated agent**, which starts cold. Measured on a real project issued from the template (a
Snake, a day and a half of use): GDD 33 KB, pitfalls 26 KB, map 12 KB -- a `developer` sub-agent
swallowed about 20,000 tokens before its first action.

Hence two rules, to be enforced in the skeleton as here:

1. **A document re-read at every task has a ceiling** (`CLAUDE.md` 80 lines; GDD and map 150; a
   pitfalls or system file 150). Once reached, we **split** and leave an **index**: one line per
   entry, with enough to choose what to open. The gain is structural, not cosmetic -- the pitfalls
   monolith was worth 4,700 tokens, one domain is worth 800.
2. **Adding to the skeleton a document that everyone re-reads is adding a recurring cost.** Put it
   behind an index, or in a skill invoked on demand.

## Adding a pitfall to `docs/pitfalls/<domain>.md`

It is the most valuable content in the repo, and it has a strict admission rule:

> **An entry describes a defect that raises NO error.** Neither compilation, nor exception, nor
> warning -- only wrong behaviour. An ordinary good practice has no place there.

Each entry says: **what happens**, **why it does not show**, and **what works**. The observed symptom
is worth more than an abstract rule -- "the game dies on a three-hundred-line
`RuntimeError: memory access out of bounds`" is recognisable, "mind the cache" is not.

Mark **[inherited]** whatever comes from an earlier project and has not been re-verified since.

The entry goes into the file of its domain; `docs/PITFALLS_UNITY.md` is now only an index, to be kept
up to date. No domain goes past ~150 lines: beyond that, it splits in turn.

## Evolving an agent

If an agent systematically takes a wrong decision, **enrich its `.md`** rather than correcting it at
every session. An agent declares a **closed** `tools:` list: if it does not declare a tool there, it
*cannot* call it, whatever instruction is written elsewhere. *A capability documented without being
wired up does not exist.*

## Origin

Distilled from two published projects: **Chimera Protocol** (survivor roguelite, ~800 tests, a team
of 9 agents) and **Smily Volley** (web game, scene built in code, touch port). When one of the two
learns something generalisable, push it back here; when one of the two proves the template wrong, fix
it here.
