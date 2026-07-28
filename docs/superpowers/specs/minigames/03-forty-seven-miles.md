# Slot 3 — Forty-Seven Miles

**Status:** DESIGN. Ready for an implementation plan to be written against it.
**Archetype:** Pipe Dream / Pipe Mania
**Cadence:** Recurring
**Priority:** After slot 1.

> **Revalidate before implementing.** This design was written during P2 planning,
> ahead of the README's "immediately before the implementation plan" rule, so the
> framework contract could be designed against all five consumers at once. Slot 1
> went stale against Batch B while sitting as a placeholder; check this one
> against the tree before building it.

---

## Why this slot exists

It covers **divisions 4 and 6** — the San Joaquin valley pipeline and the bay
crossing. Neither has tunnelling, so without this slot half the map reverts to
clicking End Season. That is the structural reason, and it constrains everything
below: this must be a real reason to work those fronts, not a diversion.

## The core, which is not the design work

Rotating tile grid, flow tick, connection check. Pipe Dream is the most-cloned
puzzle on the slate and the mechanic is well-trodden. **Placed pipe is
overwritable**, chosen for forgiveness — friction is the enemy on a showcase
piece.

The design work is entirely in the right-of-way mechanic and the terrain split.

## Room for four pipes — the answer is yes

**Question 2 in the placeholder asked whether "room for four pipes" becomes a
mechanic rather than flavour. It does, and it is the spine of this slot.**

The city bought a right-of-way about 100 feet wide — room for as many as four
parallel San Joaquin pipelines — when only Pipeline No. 1 was to be built. It is
the clearest instance of infrastructure foresight in the whole project, and a
Pipe Dream clone that ignores it would be a generic puzzle wearing a Hetch Hetchy
skin.

**The mechanic.** Any pipe tile the player has placed can also be **staked** —
one extra input, one extra tick of the clock — widening the right-of-way along
that length. Staking yields no pipe and no progress toward the outlet. It costs
the one thing the player cannot spare, which is time, plus funds.

That is the historical decision reproduced exactly: *spend now, against the
clock, on capacity nobody needs yet.* Every second staking corridor is a second
the water advances toward an unconnected end.

**And it is what earns the top tier** (see Tiers). The teaching point is the win
condition, not a bonus attached to one.

## Grid and timer

**The timer derives from the grid, never hand-set per level** — otherwise
difficulty drifts every time a grid changes.

```
min_path_len     = shortest legal source→outlet run on the generated board
start_delay_tick = ceil(min_path_len * 1.6)
flow_rate        = 1 tile advanced per 2 ticks
```

The player gets roughly 1.6 placements of head start per required tile. A perfect
minimal run finishes with slack; that slack is the corridor budget. Grid sizes:
**9 × 7** for division 4, **7 × 7** for division 6.

## Terrain: the two divisions must not play identically

| | Division 4 — San Joaquin valley | Division 6 — Bay crossing |
|---|---|---|
| Grid | 9 × 7 | 7 × 7 |
| Character | Open, long runs, few obstacles | Cramped, forced routing |
| Obstacles | Sparse; the river crossing | Slough edges block cells outright |
| Soft ground | Rare | Common |
| Corridor | Plentiful — **this is the right-of-way division** | Scarce; little slack to spare |

**Soft ground** is the shared complication: a cell that pipe can cross only if
piles are driven first — one extra input, like staking, but **mandatory rather
than optional**. It is the mechanic reading of pipe laid on timber piles in a wet
trench, and of a pipeline bedded in bay mud roughly 75 feet below the water.

Same engine, two generator profiles and two tile palettes. No second codebase.

The effect is that division 4 asks *how much future do you buy?* and division 6
asks *can you get there at all?* — which is a fair account of the difference
between the two.

## Failure

**Water reaching an unconnected end stops the run there. It is never a loss.**

Partial credit is proportional to how far the water actually travelled through
connected pipe. No readiness penalty, no crew cost. Consistent with the standing
rule: poor play fails to *earn*.

The fiction is honest rather than a concession — water reaching an open end is a
real event with a real response, and the driving card's prose can carry it.

## Tiers

| Tier | Condition |
|---|---|
| `strong` | Water reaches the outlet **and** corridor coverage ≥ 60% |
| `fair` | Water reaches the outlet |
| `poor` | It does not |

Corridor coverage is the fraction of the completed run that was staked.

**Efficiency is deliberately not a second channel.** The placeholder asked
whether pipe-used-versus-minimum should feed readiness separately. It should not:
two efficiency metrics is one too many, they would compete for the same player
attention, and corridor coverage carries far more meaning. Dropped on purpose.

**Outputs.** Miles (front progress from the run completed), funds (staking costs
money), readiness (corridor coverage). Matches the outputs the placeholder fixed.

**Result payload.** `completion` (0.0–1.0), `corridor_coverage` (0.0–1.0),
`tier`, `funds_spent`, `piles_driven`. `Journey` converts completion to front
progress and applies the rest; the minigame writes nothing.

## Verification bands

`minigame_sim` must assert:

1. **Every generated board is winnable.** A perfect-play solver reaches the outlet
   before the water does, with margin, on 100% of boards per profile. Pass/fail.
2. **All three tiers occur** under a competent policy, each at least 10%.
3. **Corridor must be a real decision.** A policy that never stakes must reach
   `fair` reliably and `strong` never. A policy that always stakes must fail to
   reach the outlet often enough to matter. **If either policy dominates, the
   central tension of this slot is fake** and the timer or stake cost is wrong.
4. **The two divisions must play differently.** Tier distributions for profile 4
   and profile 6 must be distinguishable. If they are not, the terrain split is
   cosmetic and question 3 has not actually been answered.

Plus the standing requirement: campaign `sim_test` still completes with this
minigame skipped entirely.

## Numbers are a starting point

`1.6`, the 2-tick flow rate, the 60% corridor threshold and both grid sizes are
first estimates chosen to leave a perfect minimal run with roughly a third of its
time free for staking. **The bands are the specification; these are a guess.** If
they cannot meet the bands, that is a result to report rather than a band to
lower.

## Historical anchors

- [Forty-Seven Miles of Steel](../../../../content/cards/13_forty_seven_miles_of_steel.md)
- [Leave Room for Four Pipes](../../../../content/cards/12_room_for_four_pipes.md)
  — the staking mechanic above
- [Under the San Joaquin](../../../../content/cards/14_under_the_san_joaquin.md)
  — soft ground and piles
- [Across Sunol Valley](../../../../content/cards/19_across_sunol_valley.md)

## Note for the historian review already in flight

[Leave Room for Four Pipes](../../../../content/cards/12_room_for_four_pipes.md)
is also a candidate in the
[schedule-for-resilience review](../2026-07-28-historian-review-schedule-trades.md),
where the proposal is that acquiring the wider corridor costs a season. **The two
are consistent and mutually reinforcing** — the card would price foresight in
campaign time, this slot prices it in seconds against the flow. If the historian
rejects the card proposal as unsupported, this mechanic is unaffected: it depicts
the acquisition that demonstrably happened, not a delay it may or may not have
caused.

## Inherited rules this slot does not revisit

- Never reads or writes `GameState`. `MinigameConfig` in, `MinigameResult` out.
- Never gates progress. Passive accrual is always the fallback.
- Never adds a resource.
- Failing never subtracts readiness.
- Result tiers select among the driving card's authored choices.
- Any historical liberty is recorded in the driving card's `assumption_note`.
