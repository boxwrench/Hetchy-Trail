# Slot 2 — Probe the Face

*(The filename stays `02-sound-the-rock.md` until implementation so existing
links resolve. The slot ID stays `02`.)*

**Status:** DESIGN. Ready for an implementation plan, within the claim boundary
below.
**Archetype:** Minesweeper
**Cadence:** Recurring; precedes a Heading run
**Priority:** After slot 1, because it feeds slot 1.

> **Revalidate before implementing.** This design was written during P2 planning,
> ahead of the README's "immediately before the implementation plan" rule, so the
> framework contract could be designed against all five consumers at once. Slot 1
> went stale against Batch B while sitting as a placeholder; check this one
> against the tree before building it.

---

## The name was wrong, and has been changed

**Settled 2026-07-28; the parent spec now carries the new name.** *Sounding* is a
real practice — tapping the back of a heading with a bar and listening for loose
rock — but it is not what this minigame depicts. This is **probe drilling ahead
of the face**: boring exploratory holes into unexcavated ground to find what is
coming.

Those are two different jobs, and naming the second after the first is the kind
of error an agency historian catches immediately. Renamed to **Probe the Face**;
*Drill Ahead* and *Ahead of the Face* were the alternatives. Only the display
name changed.

## The claim boundary — read this before drawing or writing anything

A second correction, and a more important one than the name. That crews at the
heading this slot represents drilled a **regular grid of forward probe holes** is
**not established** by any Hetch Hetchy record reviewed. What *is* documented is
the ground itself: difficult geology, groundwater, gas and swelling in the Coast
Range ([SOURCES.md](../../../SOURCES.md), `[SFPUC-2005]` p. 39).

So this slot is **a schematic of investigating ground ahead of a heading, not a
recreation of a documented shift.** Concretely, that means:

- **Do not invent a feet-ahead figure.** No "probing 20 feet ahead" in prose, UI,
  or art.
- **Do not present the grid as a survey record.** It is a game board standing in
  for an idea, and nothing on screen should imply a reproduced document.
- **The driving card's `assumption_note` carries the liberty**, as every other
  deviation in this project does.

The minesweeper fit is still good — probing and deducing from partial information
genuinely is the archetype. It is the *specificity* that is unsupported, not the
premise. Recorded in [FOLLOW-UPS.md](../../../FOLLOW-UPS.md).

## What the player does

A grid of unexcavated ground ahead of the heading. The player drills **probe
holes**; each returns a reading of the ground immediately around it. From those
readings they deduce where the bad ground lies and flag it, without drilling into
it.

**What the numbers mean in-fiction.** A probe hole's reading is *the number of
adjacent blocks where the core comes up fractured or water-bearing* — eight
neighbours, same as minesweeper's adjacency count, but stated as what the drill
brought back rather than as an abstract number. A `0` reading means the hole came
up dry and solid all round, which is why it opens up its neighbours.

This is the exact reason the archetype was chosen: probing a grid and deducing
hazards from partial information *is* minesweeper. No reskinning is required, and
none should be invented.

**Untimed.** This is the deduction slot. Time pressure belongs to slot 3.

## Boards must be solvable without guessing

Restated from the placeholder because it is the single most important
implementation requirement in this slot, not an optimisation:

- **First probe is always safe.**
- **A solver runs at generation.** Any board that reaches a position requiring a
  guess is discarded and regenerated.

A guessing board on a showcase piece is the most likely thing to make a
first-time player quit. It is also what makes the hazard rule below *fair*: if no
board can force a guess, then drilling into bad ground is always a misread, and
ending the survey there is the player's own result rather than the game's whim.

## Grid and density

**Scales by division**, keyed to what the ground actually was:

| Division | Grid | Bad ground | Density |
|---|---|---|---|
| 3 — Foothill Tunnel | 6 × 6 | 5 | 14% |
| 2 — Mountain Tunnel | 7 × 7 | 8 | 16% |
| 5 — Coast Range Tunnel | 8 × 8 | 13 | 20% |

Coast Range is hardest, and the record supports it without any invention:
methane, swelling ground at Crane Ridge, and 28.5 miles of it.

## Hitting bad ground

**The survey ends. Benefit earned so far is kept. No crew injury.**

Injury is slot 1's currency. Charging it here would punish surveying, and the
whole point of this slot is to make surveying attractive enough that a player
does it before pushing a heading.

## Partial completion is proportional

**Deliberately, not by default.** Survey quality is the fraction of safe cells
revealed when the survey ends — whether the player stopped voluntarily or hit bad
ground.

All-or-nothing scoring combined with an ending-on-hazard rule would mean one
misread click wipes ten minutes of correct deduction. That is the frustration
cliff the placeholder warned about, and proportional scoring is what avoids it.

## What this hands to The Heading

**Slot 1 question 5 and slot 2 question 5 are the same question. This is the
single answer to both.** Two channels, deliberately split:

**Quality sets the number.** Survey quality reduces The Heading's starting ground
stress `S₀`.

**Tier sets the information.** Whether the player learns *which* hazard the ground
is prone to — and that only unlocks at `fair` or better.

| Result | `S₀` | Hazard named? |
|---|---|---|
| Not surveyed | 4 | No |
| `poor` | 3 | No |
| `fair` | 2 | **Yes** |
| `strong` | 0 | **Yes** |

The split is the design. A lower `S₀` only shifts arithmetic; knowing the ground
is prone to a cave-in rather than a powder blast changes how deep a player pushes
and how often they stop to set supports, because under slot 1's rules those two
hazards cost wildly different amounts. **Information changes play. Probability
changes sums.**

It also gives the tiers a shape worth chasing: the jump from `poor` to `fair` is
where the survey starts being *worth* running, and `strong` is the difference
between safety and knowing.

## Tiers

| Tier | Safe cells revealed |
|---|---|
| `strong` | ≥ 90% |
| `fair` | ≥ 60% |
| `poor` | below 60% |

**Secondary output: readiness.** A `strong` survey grants +1 water readiness —
ground understood before it was cut is build quality, per §5. `fair` and `poor`
grant none. Consistent with the standing rule, a bad survey never *subtracts*
readiness; it fails to earn it.

**Result payload.** `quality` (0.0–1.0), `tier`, `hazard_hint` (a hazard id, or
empty below `fair`), `cells_revealed`. `Journey` carries the hint and `S₀` into
the next Heading run on that front; the minigame writes nothing.

## Shared vocabulary with the hazard deck

What a probe hole finds must read like the hazards it is looking for.
[h2_rockfall_in_the_heading](../../../../content/cards/h2_rockfall_in_the_heading.md)
and [h3_cave_in](../../../../content/cards/h3_cave_in.md) are already written and
sourced. A survey that spots bad ground and a Heading that hits it unprepared
should describe the same geology in the same voice — so the `hazard_hint` is one
of the three hazard ids, and the survey's own prose is drawn from the same
vocabulary rather than newly invented.

## Verification bands

`minigame_sim` must assert:

1. **No board requires a guess.** Generate 1,000 boards per division profile; the
   solver must clear every one by deduction alone. This is pass/fail, not a band.
2. **First probe is never bad ground.** Across all generated boards.
3. **All three tiers occur.** Under a competent solver policy each tier appears at
   least 10% of the time. If `strong` is automatic, the density is too low; if it
   never happens, too high.
4. **The survey must pay.** A surveyed Heading run must beat an unsurveyed one on
   expected footage by a margin outside noise. Shared with slot 1's band 5 — if it
   fails, one of the two slots is mistuned and both are suspect.

Plus the standing requirement: campaign `sim_test` still completes with this
minigame skipped entirely.

## Historical grounding to confirm with the historian

- The name, per the section at the top of this file.
- Actual probe-drilling practice on the Coast Range and Mountain tunnels: how far
  ahead crews probed, what they were looking for, what they did on finding it.
- Whether the per-division difficulty ordering above matches the ground crews
  actually met.

## Inherited rules this slot does not revisit

- Never reads or writes `GameState`. `MinigameConfig` in, `MinigameResult` out.
- Never gates progress. A player who never surveys can still finish.
- Never adds a resource.
- Failing never subtracts readiness.
- Any historical liberty is recorded in the driving card's `assumption_note`.
