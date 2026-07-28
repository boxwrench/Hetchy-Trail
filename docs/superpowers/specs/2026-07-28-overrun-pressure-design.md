# Overrun Pressure: Design Spec

**Date:** 2026-07-28
**Status:** Approved, parameters settled → ready for implementation.
**Plan:** [overrun pressure implementation](../plans/2026-07-28-overrun-pressure.md).
**Amends:** the [workfront progression spec](2026-07-27-workfront-progression-design.md),
whose success criteria assumed a scarcity that does not exist in the build.

## Problem: time is not scarce, so pace cannot carry risk

The workfront design's central claim is *"six divisions × four turns each = 24.
There is no slack. That is where pace finally earns its risk."* Measurement
after Batch B says the opposite, and the code has been saying it all along:

- `TURNS_TOTAL` is documented as *"a session-length design target, not a rule."*
- `turns_remaining()` is documented as *"a pacing signal, not a loss condition."*
- The only real deadline is `FINAL_DEADLINE_YEAR` (1940). Canonical play
  finishes in 1934 — **six years of margin.**
- `unfinished` appears in exactly one strategy (all-rest, 4 of 12 seeds).

So a turn costs `PHASE_OVERHEAD`: **one fund.** Measured against that, pushing
pays roughly 9–11 extra funds in crew upkeep to save about 3 turns, worth 3
funds. Pushing is not mistuned by a knob's width; it is underwater by about 3×,
because the thing it buys is nearly worthless.

This is why every attempt to tune it traded one success criterion against
another. `FRONT_BASE_PROGRESS` is a global difficulty dial — and it is floored
at ≈0.421 by the requirement that turn one fires a card, so it can only ever
make the game *easier*. There is no setting at which the best strategy wins
8–11 of 12 *and* pushing wins 5 of 12.

**Worse, extra turns are mildly *good*.** Each one is another action
opportunity — another bond, camp or outreach — against a cost of one fund and a
small hazard roll. Any purely economic tuning would manufacture difficulty
without touching that incentive.

### The measurement

Ten strategies, 12 seeds each, at `FRONT_BASE_PROGRESS` 0.45 with two-card
chaining. Grade columns are ahead / matched / behind.

| allocation / pace | wins | grade a/m/b | turns |
|---|---|---|---|
| historical / steady | 12/12 | 11 / 1 / 0 | 21.2 |
| critical path / steady | 12/12 | 11 / 1 / 0 | 21.2 |
| balanced / steady | 12/12 | 12 / 0 / 0 | 21.0 |
| bay first / steady | 12/12 | **2 / 10 / 0** | 22.0 |
| historical / push | 6/12 | 5 / 1 / 0 | 19.3 |
| balanced / push | 8/12 | 7 / 1 / 0 | 19.1 |
| bay first / push | 3/12 | 3 / 0 / 0 | 20.2 |

**Every steady policy wins every seed.** Careful play cannot lose, because
losing requires running out of a resource and taking your time costs almost
nothing.

**But allocation is already legible in the grade.** Bay-first costs nine
ahead-of-history finishes and zero wins. The decision the design exists to
create is real and measurable — the old win-rate-only criterion simply could
not see it.

## Decision: 1934 begins consequences; 1940 remains the loss

October 1934 becomes a **binding project milestone, not a cliff and not merely a
score.** Passing it does not end the campaign. It begins escalating financial
and political pressure, which — left unaddressed — arrives at the existing 1940
loss conditions on its own.

This is the historically honest reading. The 1934 date mattered enormously and
missing it would have been materially worse, but the project would not have
evaporated at midnight. Modelling it as mounting cost rather than sudden death
teaches *why* the schedule mattered instead of asserting that it did.

### Attach the pressure to phases, not turns

The year already derives from `phase`, and **card-inflicted delays advance
phases without granting a turn.** Pressure attached to phases therefore prices
delay-inducing card choices in the same currency as slow play: "Delay the bond
vote" and dawdling become the same kind of mistake.

This is the property that makes the change worth more than its size. Pace,
front allocation, and card choice all begin feeding one meter, and every future
minigame inherits a reason to matter without needing its own bespoke stake.

### What it does not change

- **Five metrics.** Pressure is expressed through `funds` and `public_support`,
  which already exist. **No sixth resource.**
- **No new loss condition.** `bond_crisis` and `project_cancelled` absorb it;
  `FINAL_DEADLINE_YEAR` stays the backstop.
- **`completion_grade()` is preserved exactly** — ahead / matched / behind
  remains the scoring layer, now with teeth behind it.
- The card deck, the teaching layer, and the historian's workflow.

## Settled parameters

**Grace: two phases.** Pressure begins only after
`CALENDAR_PHASES + OVERRUN_GRACE_PHASES`. Canonical play lands on phase 32, so
it carries three phases of headroom before anything bites. A run that slips
slightly is not punished for it; a run that slips persistently is. This is the
kinder of the two options, chosen because the ROADMAP's stated audience plays
once, briefly.

**Curve: flat per year.** One extra fund of phase overhead for each year past
1934, plus one point of public support every `OVERRUN_SUPPORT_INTERVAL` phases
while overrunning. Both terms are linear and legible — a player can read the
HUD and say "this is costing me two funds a phase," which is the teaching point.
Anything steeper compounds fast against a campaign income ceiling of 66 funds
and would read as arbitrary punishment.

Concretely:

```gdscript
const OVERRUN_GRACE_PHASES := 2
const OVERRUN_FUNDS_PER_YEAR := 1
const OVERRUN_SUPPORT_INTERVAL := 3
```

### Why this lands in `_advance_calendar()` and nowhere else

`_advance_calendar()` is already called from **two** places: `advance_turn()`,
and `apply_choice()` for every positive `time_delta_seasons`. Putting the
pressure there means a card that costs two phases of delay is priced exactly
like two slow turns, with no second code path and no way for the two to drift
apart. The phase-attachment property the design depends on is not something
this change has to build — it is something the existing calendar already
guarantees.

The pressure must also be **visible**. An invisible penalty teaches nothing, so
the HUD surfaces it in the pattern the pumping surcharge already uses.

## Consequence for the success criteria

The workfront spec's criterion 1 — *best strategy wins 8–11 of 12* — was a proxy
for "pace and allocation are real decisions." It should be **re-scored on the
grade distribution as well as the win rate**, because the evidence above shows
the decisions landing in grade while survival stays flat. Criterion 1 is not
being relaxed: with time made scarce, slow and badly-allocated play should begin
losing outright, and the win-rate band becomes reachable rather than
unreachable-by-construction.

This is the honest sequence: the criterion was not failing because the workfront
model failed. It was failing because the resource the model allocates — turns —
had no value.

## Cost, honestly

Small in code, large in consequence. `GameState._advance_calendar()` gains an
overrun term; the HUD gains a cue for it, in the pattern the pumping surcharge
already uses; `balance_probe` re-measures. No card or segment data changes.

**The alternative, rejected:** tune funds, camps and bonds until the numbers
land. That manufactures difficulty without giving pace anything to buy, and it
would have to be re-tuned again the moment any minigame changes campaign length.
