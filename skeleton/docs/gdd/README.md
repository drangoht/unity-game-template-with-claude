# docs/gdd/ -- one system, one file

`docs/GDD.md` section 4 is an **index**: one line per system, pointing here. The detail lives in one
file per system (`movement.md`, `score.md`, `difficulty.md`, ...).

Why this split: the GDD is re-read before every design or implementation task, by the main session
**and** by every delegated agent. A monolithic GDD makes whoever touches one system pay for the
detail of all of them -- measured at 21 KB for section 4 alone on a Snake, that is ~5,400 tokens
reloaded at every task.

What a system file contains:

- **What it does**, in one sentence -- the same one as in the index.
- **Its values**, and above all the measurement or observation that justifies them. The numbers
  themselves live in `Assets/Scripts/Rules/`: here we write *why* they are what they are.
- **What was tried and discarded** for this system, with the reason.

Ceiling: ~150 lines. Beyond that, the system is hiding two.
