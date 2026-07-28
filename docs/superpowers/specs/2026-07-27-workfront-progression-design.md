# Workfront Progression: Design Spec

**Date:** 2026-07-27
**Status:** Approved design → ready for implementation plan
**Supersedes:** the linear card-spine progression built in P1.
**Answers:** the open question in
[slot 01](minigames/01-the-heading.md) — *does spine progression depend on
footage?* **Yes. That is the whole change.**

## Problem

Measured with [balance_probe](../../../tools/balance_probe.gd) across 12 seeds
per strategy: all-steady wins 11/12; every pushing strategy wins 0–3/12.
**Pace has one correct answer.**

The cause is structural. The 15 fixed spine cards form a dependency chain —
card 04 requires 01's flag, 05 requires 04's — so only one link can fire per
turn and the campaign has a hard floor near 15 turns *at any pace*. Mileage
gates nothing, so pushing buys no schedule while costing crew, hazards and
remediation spending. Two fixes were tested and rejected: allowing two spine
cards per turn (no effect — the chain gates availability, not the one-per-turn
rule) and reducing hazard rates (moved one strategy from 1/12 to 2/12).

Three further consequences fall out of the same root cause:

- `miles_built` is decorative — it gates card availability but not the win.
- The route map has no mechanical purpose; it can only ever be decoration.
- The game is linear, about a famously non-linear project. The project's own
  historical brief asks for *"an interconnected system, not a wagon moving
  west"*, and `GameState.SYSTEM_FLAGS` is already documented as *"the city
  receives nothing until the whole chain works as one system"*. The intent
  exists; the implementation contradicts it.

## The change

**Each turn the player chooses one of six workfronts to work, plus a pace.**
That front advances; the others sit.

One front per turn, not split allocation — a cleaner decision, far easier to
tune, and enough to make the choice real. Splitting is a possible later
refinement, explicitly deferred.

### Why the turn budget already fits

`TURNS_TOTAL` is 24. Six divisions × four turns each = 24. This is not a number
invented for this design — it is what `game_state.gd` has documented the phase
structure to mean since before P1. The budget was always describing this game.

With six fronts each needing roughly four turns out of 24, **there is no
slack.** Finishing a front in three turns instead of four buys a turn
elsewhere. That is where pace finally earns its risk.

### The prerequisite graph

Taken from the flags the existing cards already grant and require. **No new
gates are invented, and no card data changes.**

| Front | Miles | Opens when | Its cards | Ends with |
|---|---|---|---|---|
| 1. High Sierra & Dam | 0–12 | immediately | 01, 04, 05 | `dam_complete` |
| 2. Mountain Tunnel & Moccasin | 12–33 | `construction_power_available` (front 1, card 04) | 06, 07 | `mountain_tunnel_complete` |
| 3. Western Foothills | 33–49 | `moccasin_power_available` (front 2, card 07) | 09, 11 | `foothill_tunnel_complete` |
| 4. San Joaquin Valley | 49–97 | immediately | 12, 13 | `san_joaquin_pipeline_complete` |
| 5. Coast Range | 97–126 | immediately | 15, 17, 18 | `coast_range_tunnel_complete` |
| 6. Bay & Peninsula | 126–167 | immediately | 19, 20, 21 | `pulgas_connected` |

Critical path 1→2→3 is roughly 12 turns. Fronts 4, 5 and 6 need roughly 12
between them. The budget is 24. It is exactly tight, which is the point.

**Fronts 4, 5 and 6 are deliberately ungated.** Historically they began in 1931,
1927 and 1922 — but they were gated by money and political priority, not
permission. Modelling that as funds and turn pressure rather than a lock teaches
*why* the historical order made sense, instead of asserting it. A player who
opens the San Joaquin in 1915 will discover what it costs.

**Front 6 is the interesting one.** The Bay Crossing carried Spring Valley water
from 1925 while the Sierra divisions were unfinished — already noted in
[technical_design.md](../../technical_design.md) under Historical Structure, and
currently explained away in assumption notes as something the game cannot
represent. Here it becomes the sharpest decision on the board: available from
turn one, contributes nothing toward Hetch Hetchy water on its own, and competes
for the same scarce turns as the critical path.

### Progress and cards

Each `RouteSegment` gains internal progress, `0.0 → 1.0`. Working a front
advances it by the existing rate maths — pace × `build_rate_modifier` ×
`_crew_factor()`, with `NO_RAILROAD_FACTOR` still applying to the three mountain
divisions until the railroad runs.

**A front's cards fire at progress thresholds within that front**, in filename
order, replacing the global mile-and-flag chain. A front with three cards fires
them at roughly ⅓, ⅔ and completion; a front with two at ½ and completion. The
final card grants the front's `completion_flag`, exactly as it does today.

`miles_built` becomes the **sum of front progress weighted by segment length** —
an honest aggregate of what has been built, and the first time it means
anything.

### What does not change

- **Five metrics.** Front progress is internal contract state, like flags. It is
  not a player resource and is not displayed as one.
- **The win condition** — all eight `SYSTEM_FLAGS`.
- **All five loss conditions.**
- **The card deck, the teaching layer, the Markdown pipeline, the historian's
  workflow.** Cards are re-anchored, not rewritten. Their `required_flags`
  already encode the graph above.
- **The minigame contract** from §3 of the
  [minigames spec](2026-07-27-minigames-and-campaign-restructure-design.md).

## What this unblocks

- **Pace becomes a decision.** Accelerating a front on the critical path is
  worth real risk; accelerating front 6 usually is not.
- **The map becomes the interface.** M2 stops being decoration and becomes the
  screen the game is played on — six fronts, their state, and which are open.
- **The Heading gets its answer.** Footage advances *the front being worked*.
  Slot 01's blocking question is resolved.
- **Every minigame gets a home.** The Heading on fronts 2, 3, 5; Pipe Dream on
  4 and 6; the railroad run on front 1.

## Success criteria

Measured by `balance_probe`, extended with front-allocation strategies:

1. **No strategy wins every time, and no reasonable strategy almost always
   loses.** Concretely: the best strategy wins 8–11 of 12 and pushing-based
   strategies win at least 5 of 12.
2. **`sim_test` still completes** at `matched_history` on canonical play.
3. **Skipping is still viable** — a player who never pushes can finish.
4. **Front 6 is a genuine dilemma:** working it early must be survivable but
   measurably costly, not strictly wrong.

If (1) does not hold after tuning, the design has failed and we say so rather
than lowering the bar.

## Cost, honestly

A campaign-layer rewrite: `GameState` gains per-front progress and a
"work this front" action; `advance_turn` works one front instead of a global
counter; `EventManager` triggers on front progress instead of miles and the flag
chain; all 15 fixed cards are re-anchored. Roughly P1-sized — four or five
worker tasks, batched larger than P1's were.

**The alternative, rejected:** bolt footage thresholds onto the existing chain.
Cheaper, fixes the dominance problem, and leaves a linear game about a
non-linear project with a map that stays wallpaper.

## Deliberately deferred

- **Splitting effort across two fronts per turn.** Start with one.
- **Per-front crew or funds.** Would be a sixth resource. Never.
- **Historical year gating on fronts 4–6.** Modelled as cost, not permission.
