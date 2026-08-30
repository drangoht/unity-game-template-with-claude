---
name: write-the-gdd
description: Build docs/GDD.md of __GAME_NAME__ step by step, by interviewing the game's author -- one section at a time, in order, with the commands to run in between and a complete worked example on a Snake. To be invoked at the start of a project when the GDD is still the skeleton full of gaps, and every time you are about to implement a system whose GDD section has stayed empty.
---

# Writing the GDD -- __GAME_NAME__

`docs/GDD.md` is the **source of truth for the design**: the code says *how*, the GDD says **why**.
This skill says how to fill it in without turning it into a novel of intentions that nobody re-reads.

> **A GDD is not written in one block before starting.** Written in full on day one, it describes a
> game that does not exist yet and becomes wrong at the first prototype. Three sections are written
> **before the first line of code**; the other four are written at the moment the decision is taken,
> and not after.

## What gets written when

| When | Sections | Why at that moment |
|---|---|---|
| **Before coding** | 1 pitch - 2 loop - 3 controls | Without the verb, the loop and the keys, there is nothing to implement |
| **At each system built** | 4 systems - 5 progression | A value is justified when it is chosen, never from memory |
| **Continuously** | 6 measured - 7 discarded | Section 7 is the one that avoids reopening the same debate ten times |

## The order of the commands

```
1.  /write-the-gdd               <- here: interview, sections 1 to 3 filled in and committed
2.  ask the game-designer to detail <the first system>             -> 4
3.  ask the developer to implement <that system> + its tests
4.  /verify-in-game              <- what the prototype disproves comes back into 4 and 7
5.  /project-map                 <- update the map, same commit
    (repeat 2->5 per system; 5 as soon as there is a second difficulty step)
6.  /publish-itch                <- 0.1.0, then 6 fills up with real play sessions
```

WARNING: step 4 is not optional. **A GDD written before the prototype is a hypothesis**, and part of
what is in it at that stage is wrong -- which is normal, provided you come back and amend it. A GDD
that the running game has never corrected has never been of use.

## How to conduct the interview

For Claude, when this skill is invoked:

1. **Read `docs/GDD.md` first.** Never rewrite what is already filled in; spot the first section
   still in `<!-- -->` comment form and start there.
2. **One question at a time**, through `AskUserQuestion`, with **two or three ready-written answers**
   plus the free option. A blank page does not produce design; a choice between three concrete
   phrasings does. That is where the work is: proposing, not interrogating.
3. **Write into `docs/GDD.md` as soon as a section is validated**, and commit. A validated section
   that stays in the conversation is lost at the end of the session.
4. **Never invent a number.** A value that has not been tried is written `<!-- to be measured -->` or
   with its provenance ("taken from *Blobby Volley*", "by eye, to be confirmed"). A number written
   with no source will be quoted six months later as if it had been measured.
5. **Reformulate what the author says, more briefly.** The GDD is re-read by agents: what does not
   fit in five lines will not be read there.

---

# The seven steps, worked through on a Snake

The following example builds the complete GDD of a small snake game. It is not there to be copied:
it shows **the level of precision expected** at each section.

## Step 1 -- The pitch (section 1)

**One sentence saying what the player *does*.** If the main verb is not in it, the pitch has not been
found yet -- and if the pitch has not been found, nothing that follows can be.

Question to ask: *"In one sentence, what does the player do, and what stands in their way?"*

| Not a pitch | A pitch |
|---|---|
| "A retro pixel-art snake game." | "You steer a snake that grows with every bite, until its own body leaves no way through." |
| Describes the setting and the style; no player verb | Verb: steer. Obstacle: yourself |

**The test**: does the sentence contain what **opposes** the player? "You eat apples" is not a game.
"Every apple eaten reduces the space where you can still turn" is one.

## Step 2 -- The game loop (section 2)

The cycle the player repeats, from launch to game over, **in five lines**. A loop that does not fit
in them is a loop that has not been understood yet.

```
spawn at the centre, three segments  ->  aim the head, the snake moves on its own
   ->  reach the apple: +1 segment, +1 point, a new apple appears elsewhere
   ->  the free space shrinks with every bite
   ->  the head touches the body (or a wall): death, score shown
   ->  immediate restart: "I should have gone round the right"
```

WARNING: **the last arrow is the most important one, and it is the one people forget.** "What makes
you want to start again" is not a *Replay* button: here it is the fact that death is always
attributable to a precise turn, never to randomness. If that line will not fill in, the problem is
in the game, not in the document.

## Step 3 -- The controls (section 3)

The skeleton's table is filled in **completely**, including the columns that will stay empty: a cell
that owns its emptiness ("-- no gamepad in 0.1") is worth more than a deleted column that nobody
knows was decided or forgotten.

| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Turn (4 directions) | Arrow keys or **WASD** | D-pad | Swipe in the direction |
| Pause | Escape | Start | Button at the top right |
| Restart after death | Space | A | Touch anywhere |

WARNING: **AZERTY.** `Key` and `KeyCode` designate a **position on a QWERTY keyboard**. The Z, Q, S,
D keys of a French keyboard are therefore declared `Key.W`, `Key.A`, `Key.S`, `Key.D` -- writing
`Key.Z` for the key marked Z actually aims at the W. No error is raised: the game simply responds to
the wrong key.

WARNING: **invisible reads as non-existent.** The instant U-turn is forbidden (the snake would bite
its own neck) -- so the refusal must **be seen**, otherwise the player concludes the game missed
their press. Any rule that cancels a player input must announce itself on screen.

## Step 4 -- The systems (section 4)

One level-3 heading per system. For each one: **what it does, its values, and what justifies them**.
The numeric values live in `Assets/Scripts/Rules/` -- the GDD carries the *why*, the code carries the
number, and the two quote each other.

This is where you delegate, one system at a time:

```
ask the game-designer to specify the snake's movement
ask the developer to implement Rules/Tempo.cs and its tests
/verify-in-game
```

Worked example:

### The time step

The snake advances **one cell per tick**, 8 ticks/second (`Rules/Tempo.cs`). Input does not aim the
head immediately: it **queues** the direction, applied at the next tick.

*Why a queue rather than direct aiming*: at 8 ticks/s, two turns typed less than 125 ms apart
overlapped, and the second erased the first -- the player saw the snake ignore a turn they had
definitely typed. The queue holds **two at most**; beyond that you are no longer playing, you are
typing ahead.

### The apple

Appears on a cell drawn uniformly **among the free cells**, and not "at random on the grid, then
redraw while it is occupied": on an almost full grid, the second method freezes the game for an
indeterminate time without raising the slightest error.

## Step 5 -- Progression and difficulty (section 5)

**A difficulty step adds a named rule, not a multiplier.** The player must be able to read it before
starting, and to understand afterwards why they lost.

| What one spontaneously writes | What holds up |
|---|---|
| "Speed increases by 8% per apple" | **Walls**: beyond 10 apples, the edges stop teleporting and kill |
| Neither readable, nor nameable, nor foreseeable | One sentence, read before starting, that changes how you play |

Also check that a constraint **does not hand out its own antidote**: "the grid shrinks, but a golden
apple reopens it" hardens nothing -- it moves the game towards the race for the golden apple.

## Step 6 -- What has been measured (section 6)

Point to `docs/TEST_REPORT.md` for the raw data; **record the conclusion here**.

> **Tick at 8/s rather than 10/s.** 20 paired sessions on fixed seeds, same player. The median score
> does not move -- the player adapts -- but **17 deaths out of 20 at 10/s happen within the 300 ms
> following a turn**, against 6 out of 20 at 8/s. It was not the difficulty going up, it was the
> input window becoming shorter than the reaction time. Kept: 8/s.

WARNING: **an isolated session settles nothing**: the variance between two sessions can reach a
factor of 2.4 before the tested setting even acts. A verdict is taken on a paired bench, on the sign
test -- does the effect go the same way on every pair? -- not on the median delta.

## Step 7 -- What has been discarded, and why (section 7)

The most useful section of the document, and the only one nobody thinks to write.

> **Temporary bonuses (slow motion, wall-phasing, magnet).** Discarded. Tried in 0.2: they move the
> decision from "which way to go" to "reach the bonus", and death stops being attributable to a turn
> -- which the pillar in section 2 forbids.
>
> **Second local snake.** Postponed, not discarded: it needs keyboard sharing and a game-over
> condition that do not exist. To be reopened after 1.0.

WARNING: **when a conclusion is refuted, keep it and mark it as such** rather than rewriting it. The
reasoning that led to the mistake is worth as much as the correction: it is what stops the same
detour being taken twice.

---

## The five defects that keep coming back

1. **The GDD written in full before the prototype.** It describes a game that does not exist; nobody
   corrects it afterwards, and it ends up lying with authority. Three sections, then code.
2. **A pitch with no verb.** "An atmospheric space roguelite" allows *nothing* to be implemented.
3. **Numbers with no provenance.** Indistinguishable from a measurement after three months.
4. **The "discarded" section left empty.** The same debate reopens at every session, with the same
   arguments and the same conclusion.
5. **A GDD up to date with the design, but not with what disproved it.** The document now records
   only the successes: it has become a brochure, not a working tool.

## Afterwards

- `/project-map` -- where what the GDD describes lives, to be updated in the same commit.
- `/verify-in-game` -- the only thing that can prove the GDD wrong.
- `docs/pitfalls/<domain>.md` -- to be read before coding the system you have just specified
  (index: `docs/PITFALLS_UNITY.md`).
