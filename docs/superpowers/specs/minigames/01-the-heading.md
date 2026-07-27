# Slot 1 — The Heading

**Status:** PLACEHOLDER. Not ready for implementation.
**Archetype:** Press-your-luck (Can't Stop lineage)
**Cadence:** Recurring, player-initiated
**Priority:** First. Build this before any other minigame.

> This is the signature minigame — the Oregon Trail hunting analogue. It is
> built first because press-your-luck tuning is the one genuinely uncertain item
> on the slate, and because it is the hardest test of the module contract. If
> the contract is wrong, it shows here.

## Already decided — do not revisit

- **The loop:** drill, load powder, blast, muck out. Each cycle yields footage
  and raises the chance of a bust — rockfall, squeezing ground, bad air, water
  inflow. The player banks or pushes for another round.
- **Availability:** optional and player-initiated, whenever the construction
  front is in a tunnel division (2, 3, 5). Passive accrual remains the fallback.
- **The limiter is crew wellbeing.** Each round costs crew stamina. This is the
  "ammunition" that stops the minigame being free mileage.
- **Primary output is miles.** Tunnel footage comes from the minigame rather
  than a pace multiplier, which is what gives `miles_built` a job it currently
  lacks. `work_pace` becomes the risk dial rather than a constant multiplier.
- **Secondary outputs:** crew (injuries), readiness (build quality per §5).
- **Arcade mode:** launchable from the title screen with a default config.

## Historical anchors

Already in the deck, and the design should reach for these rather than invent:

- [The 803-Foot Month](../../../../content/cards/11_the_803_foot_month.md) — the
  record September of 1926, following a 781-foot month earlier that year.
- [Crane Ridge Closes In](../../../../content/cards/16_crane_ridge_closes_in.md)
  — squeezing ground, timber support, gunite rings.
- [Twelve Faces, One Line](../../../../content/cards/06_twelve_faces_one_line.md)
  — multiple simultaneous headings.
- [Mitchell Shaft Memorial](../../../../content/cards/17_mitchell_shaft_memorial.md)
  — the documented anchor for real danger. **Bust outcomes must not trivialise
  injury or death.** Restraint, as the card already models.

## Bust outcomes come from the existing hazard deck

The three injury hazard cards are already written, already sourced, and already
carry the teaching layer — reuse them rather than inventing bust text:

- [h1_powder_blast](../../../../content/cards/h1_powder_blast.md) — a premature
  detonation before the heading is clear.
- [h2_rockfall_in_the_heading](../../../../content/cards/h2_rockfall_in_the_heading.md)
- [h3_cave_in](../../../../content/cards/h3_cave_in.md)

**These stay in the campaign deck as well.** The pace-risk roll and the Heading's
bust are different events at different scales — one is what happens between
turns, the other is what happens inside a shift — and the campaign one cannot be
retired, because minigames are optional by invariant. A player who skips every
minigame must still face risk. See Task 6 of
[P1](../../plans/2026-07-27-p1-foundations.md), which revived that roll.

The design question this raises, to be answered here: **does a Heading bust draw
from the same pool, or does the minigame get its own bust text keyed to which
hazard occurred?** Reusing the cards keeps the sourcing; separate text lets the
bust describe the specific round the player just gambled on.

## The structural problem this slot must solve

Measured with [balance_probe](../../../../tools/balance_probe.gd) after P1
Task 6, across 12 seeds per strategy:

| Strategy | Wins |
|---|---|
| all steady | 11/12 |
| rest when crew ≤ 3 | 11/12 |
| push first 4 turns | 3/12 |
| push while crew ≥ 6 | 1/12 |
| all pushed | 0/12 |

**Pace is not a decision — STEADY strictly dominates.** The cause is structural,
not a tuning error, and reducing the hazard rates does not fix it (tested:
PUSHED 0.30→0.15 moved `push while crew>=6` from 1/12 to 2/12).

The 15 fixed spine cards form a **dependency chain** — card 04 requires card
01's flag, 05 requires 04's, and so on to Pulgas. Only one link can fire per
turn, so the campaign has a hard floor of roughly 15 turns *whatever the pace*.
Mileage gates nothing. Pushing therefore buys no schedule at all while costing
crew, remediation spending, and hazard exposure, and the dominant failure across
every pushing strategy is `bond_crisis`.

**This slot is the fix.** §4.1 already specifies that tunnel footage comes from
The Heading rather than a pace multiplier, and that `work_pace` becomes the
minigame's risk dial. That is what finally gives `miles_built` a job and gives
pushing an upside — but only if the design here answers:

**Does progress through the spine depend on footage?** If the chain still
advances one card per turn regardless, The Heading will make miles *feel*
earned while changing nothing about pacing, and PUSHED will still be dominated.
Something must connect footage to spine progression — a milestone card that
requires a footage threshold, or a delay when footage falls short.

Do not design this slot without answering that question.

## Must be decided

Answer every one of these before writing the implementation plan.

1. **Bust curve shape.** Linear, escalating, or stepped? What is the
   per-round bust probability at round 1, and how does it climb?
2. **Partial or total loss on bust?** Does busting cost the whole shift's banked
   footage or a fraction? This changes push aggression more than any other
   single choice.
3. **What the player actually manipulates each round.** Number of drill holes?
   Powder load? Timber-or-advance? There must be a *decision* per round, not
   just a "push again" button — otherwise it is a slot machine.
4. **Round count ceiling.** Is there a hard cap per shift, or does the curve
   alone end it?
5. **How the survey result feeds in.** Slot 2 (Sound the Rock) is specified to
   de-risk this one. What exactly does a good survey change — starting bust
   probability, curve slope, or advance warning of a specific hazard?
6. **Tier thresholds.** What footage totals map to `poor` / `fair` / `strong`,
   and how do those map onto the driving card's authored choices?
7. **Crew stamina cost per round**, and what happens when it runs out mid-shift.
8. **Failure modes to test against:** a dominant strategy (one stopping point
   always correct) and a coin flip (no real decision). The `minigame_sim` band
   check must be able to detect both. Define the bands.

## Research feeding this slot

The press-your-luck research prompt is
[Appendix A of the parent spec](../2026-07-27-minigames-and-campaign-restructure-design.md#appendix-a--press-your-luck-research-prompt).
It covers the canonical designs, the tuning math, partial-vs-total loss, mining
game feel, and the real 1920s drill-blast-muck cycle. **Its findings should be
summarised into this file** before the design is written.

## Verification this slot must ship with

- `minigame_sim` runs many seeded trials and asserts the outcome distribution
  sits in band — specifically that no single stopping round dominates and that
  variance is not coin-flip.
- Campaign `sim_test` still completes with this minigame skipped entirely.
