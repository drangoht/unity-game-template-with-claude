# GDD -- __GAME_NAME__

> **How to fill this document in**: the **`/write-the-gdd`** skill -- it conducts the interview
> section by section, in the order the decisions are taken, and works through the complete example of
> a small game.

**Source of truth for the design.** Every gameplay decision is recorded here *immediately*, with what
justifies it. The code says *how*; this document says **why**.

> When a conclusion is refuted, **keep it and mark it as such** rather than rewriting it: the
> reasoning that led to the mistake is worth as much as the correction, and it is what stops the same
> detour being taken twice.

WARNING: **this file stays a table of contents: ~150 lines, ceiling.** The detail of a system goes
into `docs/gdd/<system>.md` (section 4). It is re-read by every agent before every task: whatever is
added here is paid for on every subsequent task, including those that have nothing to do with it.

## 1. Pitch

__PITCH__

One sentence saying **what the player does**, not what the setting is. If the main verb is not in it,
the pitch has not been found yet.

## 2. The game loop

<!--
Describe the cycle the player repeats, from launch to the end of a session. A loop that does not fit
in five lines is a loop that has not been understood yet.

    entering the session  ->  ...  ->  ...  ->  end  ->  what makes you want to start again
-->

## 3. Controls

| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| | | | |

WARNING: **an ability must announce its key in the game** (HUD, description, acquisition screen).
Invisible reads as non-existent.

WARNING: **AZERTY** keyboard: `Key.A` falls under the key marked Q. Avoid `A`, `Q`, `Z`, `W`, `M` for
global shortcuts.

## 4. Systems

<!-- WARNING: THIS SECTION IS AN INDEX, NOT CONTENT. One system = one docs/gdd/<system>.md file,
     one line here. It is the section that swells fastest (it reached 21 KB on a Snake), and
     everything written in it is re-read in full by every agent touching ANOTHER system.

     Each file says: what the system does, its values, and the measurement or observation that
     justifies them. The numeric values live in Assets/Scripts/Rules/, not here. -->

| System | File | In one sentence |
|---|---|---|
| <!-- Movement --> | <!-- [gdd/movement.md](gdd/movement.md) --> | <!-- what it does --> |

## 5. Progression and difficulty

<!--
Rules learned the hard way, to be respected unless there is a new reason:
- A difficulty step adds a NAMED RULE, not a multiplier. The player must be able to read it before
  starting and to understand why they lost.
- Before adding a constraint, check what it GIVES the player: a constraint that also hands out its
  own antidote hardens nothing.
- An optional lever is not a rule: a rule applies to every session.
- Never a wall of patience on a key encounter: more dangerous beats longer.
-->

## 6. What has been measured

<!--
Point to docs/TEST_REPORT.md, and record the CONCLUSION here, not the raw data.

WARNING: an isolated session settles nothing: the variance between two sessions can reach a factor
of 2.4 before the tested setting even acts. A balancing verdict is taken on a paired bench, on the
sign test.
-->

## 7. What has been discarded, and why

<!-- The most useful list in the document: it avoids reopening the same debate ten times. -->
