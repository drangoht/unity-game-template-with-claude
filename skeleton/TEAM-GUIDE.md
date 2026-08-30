# Guide -- the agent team of __GAME_NAME__

How the project's agents and skills are organised, and when to invoke which.

## First: delegating has a price

An agent **starts cold**. It knows nothing of the current session: it re-reads `CLAUDE.md`, the GDD,
the map, the pitfalls -- in the order of **8,000 tokens before its first action**, often the same
documents you have just read yourself.

**Delegate when the task is in its speciality *and* big enough to amortise that**: designing or
balancing a system, a full test pass, a release, an asset production run. **Do it yourself**: a
ten-line fix, a question, a read, a rename, a unit test to replay.

And when you do delegate: **write in the instruction what you already know** -- the files concerned,
the decision taken, the pitfall identified, the exact error message. An agent given its starting
point does not rediscover it.

WARNING: the full chain below ("How a work item unfolds") is for a **work item**. Running it for a
value tweak costs five cold starts for three changed lines.

## The 9 agents (`.claude/agents/`)

| Agent | When to invoke it | Model |
|---|---|---|
| **`developer`** | Code, architecture, build, tests | opus |
| **`game-designer`** | Design, balancing, tuning values, scope | opus |
| **`game-tester`** | After any major implementation -- plays and documents | sonnet |
| **`release-manager`** | Publish a version end to end + write the devlog | sonnet |
| **`art-director`** | Visual identity, consistency, art briefs | sonnet |
| **`artist`** | Sprites, VFX, icons -- through the Python generators | sonnet |
| **`musician`** | Music, SFX, mixing, audio pipeline | sonnet |
| **`story-teller`** | In-game text, names, descriptions, localisation | sonnet |
| **`marketing`** | itch page, pitch, screenshot briefs | sonnet |

## The 4 skills (`.claude/skills/`)

- **`/project-map`** -- index of the code: where such a system, screen, piece of data or tool lives,
  plus the wiring checklists. **To be invoked before any exploration** rather than Glob/Grep from a
  cold start.
- **`/verify-in-game`** -- build, launch, inject real input, capture. To be invoked every time you
  are about to write "that should work".
- **`/write-the-gdd`** -- fill in `docs/GDD.md` section by section, by interview, in the order the
  decisions are really taken. To be invoked at the start, and as soon as a section has stayed empty
  while you are about to code the system it should describe.
- **`/publish-itch`** -- the publishing procedure, short version.

## How a work item unfolds

```
observation (played session or measurement)
   -> game-designer  : diagnosis + proposed rule, recorded in the GDD
   -> developer      : implementation + tests (pure logic in Assets/Scripts/Rules/)
   -> measurement    : the bench, if the subject can be quantified
   -> game-tester    : what measurement cannot say -- the feel
   -> release-manager: publication + devlog
```

**The order matters.** The shortcut "implement then measure afterwards" costs several round trips: on
a previous project, a difficulty step was published without ever having been played, and the tester
felt nothing.

## The three rules learned the hard way

1. **An isolated session settles nothing.** The variance between two sessions can reach a factor of
   2.4 before the tested setting even acts. A balancing verdict is taken on a **paired bench**, on
   the sign test.
2. **The bench does not say what is *felt*.** It measures the pressure the content exerts, not the
   experience. The two have already contradicted each other -- the tester was right.
3. **When a fix does not move the metric, suspect the instrument.** Continuing to adjust the dose is
   the most expensive way to be wrong.

## Documentation -- what answers what

| Question | Document |
|---|---|
| Current phase, conventions | `CLAUDE.md` (loaded automatically) |
| *Why* the game is tuned this way | `docs/GDD.md` (contents) -> `docs/gdd/<system>.md` -- to fill it in: `/write-the-gdd` |
| *Where* something is | `/project-map` skill |
| Which pitfalls are lurking | `docs/pitfalls/<domain>.md` (index: `docs/PITFALLS_UNITY.md`) |
| What has been tested | `docs/TEST_REPORT.md` |
| What actually shipped | `docs/DEVLOG.md` |
| Publishing | `docs/RELEASE.md` + `/publish-itch` |

## Evolving an agent

If an agent systematically takes a wrong decision on some point, **enrich its `.md` file** -- that is
the mechanism provided to capitalise on experience, and it is cheaper than correcting it at every
session. The `.claude/` files are versioned just like the code.

WARNING: **an agent describing a stale state of the project is worse than no agent at all**: it gives
wrong instructions with authority. When a phase ends, re-read the agents it concerns.

## The local LLM (optional)

If a `local-llm` MCP server is registered (LM Studio), it makes it possible to query a file **too big
to be read**: it reads the file **at its end** and returns only the answer. Measured on a previous
project: **83,000 tokens read locally -> 675 returned**.

WARNING: three safeguards, learned by measurement:
1. **It is slow** (~6-7 min for 290 KB): fire the call **before** what you were going to do.
2. **A `max_tokens` set too low truncates the answer without raising an error.** Aim for 1500-2500.
3. **Good on prose, to be avoided on numbers and on code to be edited.** If a deterministic tool
   exists, it wins. And to locate something, `Grep` is instantaneous and exact.

WARNING: an agent declares a **closed** `tools:` list: if it does not declare the MCP tool there, it
*cannot* call it, whatever instruction is written elsewhere. *A capability documented without being
wired up does not exist.*
