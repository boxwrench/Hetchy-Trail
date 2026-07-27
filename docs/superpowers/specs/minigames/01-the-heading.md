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
