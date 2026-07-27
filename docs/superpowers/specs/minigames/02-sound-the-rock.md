# Slot 2 — Sound the Rock

**Status:** PLACEHOLDER. Not ready for implementation.
**Archetype:** Minesweeper
**Cadence:** Recurring; precedes a Heading run
**Priority:** After slot 1, because it feeds slot 1.

## Already decided — do not revisit

- **The fiction is exact, not a reskin.** Before driving a heading, crews
  drilled probe holes ahead of the face to find fault zones, water-bearing
  seams, and bad ground. Probing a grid and deducing hazards from partial
  information *is* minesweeper.
- **It de-risks [The Heading](01-the-heading.md).** A good survey makes the
  press-your-luck round meaningfully safer. Two easy minigames combining into
  one interesting decision beats two isolated toys.
- **Secondary output is readiness** (build quality per §5).
- **Untimed.** This is the deduction slot; time pressure belongs to slot 3.

## Non-negotiable implementation requirement

**Boards must be guaranteed solvable without guessing.** Naive hazard placement
produces positions where the player must guess, which feels arbitrary and reads
as a broken game. Required: first-click safety, plus a solver check at
generation that regenerates any board requiring a guess.

This is not an optimisation to add later. A guessing board on a showcase piece
is the single most likely thing to make a first-time player quit.

## Must be decided

1. **Grid size and hazard density**, and whether they scale by division —
   Coast Range harder than the foothills?
2. **What the numbers mean in-fiction.** Minesweeper's adjacency count needs a
   drilling-logic reading. "Water in N of the adjacent probe holes"?
3. **Partial completion.** Is the survey all-or-nothing, or does clearing 70% of
   the grid give a proportional benefit? Proportional is likely better — it
   avoids a frustrating cliff — but it must be chosen deliberately.
4. **Hitting a hazard.** What happens? It must not be a crew injury; that is
   slot 1's currency, and punishing a survey discourages surveying. Most likely
   it simply ends the survey at whatever benefit was earned.
5. **Exactly what the result hands to slot 1** — starting bust probability,
   curve slope, or advance warning of a specific hazard. Slot 1 question 5 is
   the same question; answer both together.
6. **Tier thresholds** for `poor` / `fair` / `strong`.

## Shared vocabulary with the hazard deck

What a probe hole *finds* should read like the hazards it is looking for —
[h2_rockfall_in_the_heading](../../../../content/cards/h2_rockfall_in_the_heading.md)
and [h3_cave_in](../../../../content/cards/h3_cave_in.md) are already written and
sourced. A survey that spots bad ground and a Heading that hits it unprepared
should describe the same geology in the same voice.

## Historical grounding to confirm with the historian

- Actual probe-drilling practice on the Coast Range and Mountain tunnels: how
  far ahead crews probed, what they were looking for, what they did on finding
  it.
- Whether "sounding" is the right period term for this work, or whether it
  should be named for the actual practice. The current slot name is a
  placeholder and may be historically wrong.
