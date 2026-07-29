# Slot 4 — Keep the Line Open

**Status:** **BLOCKED — do not write an implementation plan against this.**
**Archetype:** Haulage / loading puzzle — **the lane-dodger was dropped**
**Cadence:** Recurring
**Priority:** Last of the four recurring slots.

> **Blocked 2026-07-28.** This file said "DESIGN. Ready for an implementation
> plan to be written against it." It is not. The decision it is built on — near
> camps have wagon-road fallback, far camps do not — is **contradicted by our own
> deck**, and the parent spec records that as binding. The archetype survives;
> the tension does not. **This slot needs a new source of tension before an
> implementation plan is written.** Marked at the top because a strong model
> reading only the header would otherwise proceed.

> **Revalidate before implementing.** Written during P2 planning, ahead of the
> README's "immediately before the implementation plan" rule, so the framework
> contract could be designed against all five consumers at once.

---

## The archetype changed

The placeholder's first question was whether the lane-dodger survived at all, and
it does not. It was the least historically motivated thing on the slate, it read
as arcade filler bolted onto a serious subject, and the placeholder's own note
observed that it was mostly an art and audio problem — meaning most of the effort
would have bought presentation rather than meaning.

**Replaced with a loading puzzle**, which is closer to what the railroad actually
solved and sits in the same deliberative register as the other three slots.

**The known cost of this choice, recorded so it is not rediscovered as a
surprise:** all four recurring slots are now deliberation. There is no
hands-on, reflex moment anywhere in the game. If playtesting shows the slate
needs one, this is the slot that was going to provide it, and reopening that is a
legitimate reason to revisit — not a reason to add a fifth minigame.

The name still fits: the line stays open when the camps are supplied.

## What the player does

A supply run up the Hetch Hetchy Railroad to the camps before winter closes the
line. **There is less haulage than the camps need.** The player decides what goes
up and who goes short.

**The constraint is haulage, not capacity.** A ton delivered to the farthest camp
costs far more than a ton to the nearest, because it has to be dragged the whole
way up the grade:

```
haulage_used = Σ (load_tons × camp_distance)
haulage_used <= haulage_budget
```

One number, simply stated, and not remotely trivial to optimise. It is also the
railroad's actual problem — grades and tonnage were the whole reason the line
existed — so the mechanic carries the meaning without needing narration.

**The decision it created — and this is the part that failed.** Near camps are
cheap, so a naive player fills them first. But near camps can fall back on wagon
roads, and the far camps cannot: for them the train is the only supply there is.
Spending the budget where it is cheapest is exactly the wrong answer.

> **Contradicted by our own deck. Do not build this.**
> [02_hetch_hetchy_railroad.md](../../../../content/cards/02_hetch_hetchy_railroad.md)
> has the railroad running in winter *"when mountain roads could be blocked by
> snow"* — the roads fail in the season this minigame is about, and they fail
> everywhere, not selectively at the near camps.
> [09_six_camps_in_the_foothills.md](../../../../content/cards/09_six_camps_in_the_foothills.md)
> has city crews installing roads *to the camps*, which cuts the other way again.
> Neither supports a camp-by-camp fallback hierarchy, and inventing one would put
> a fabricated logistical claim in front of the audience most able to check it.
>
> **What survives:** the haulage constraint itself (load × distance), the six
> camps, crew wellbeing as the output, and the `railroad_operational` payoff
> below. **What does not:** the reason a player should ever prefer a far camp.
> Without it, filling nearest-first is simply correct and the slot is arithmetic
> — which verification band 2 already knows how to detect.
>
> **Candidate replacements, none chosen.** Differing need urgency per camp;
> perishability or spoilage over the run; a camp that is mid-drive on a heading
> and stops if it goes short; winter closing the upper line earlier than the
> lower. Each needs a historical basis before it is designed, not after.

## What `railroad_operational` does

This is the flag's payoff, which the placeholder asked for. It stops being a
build-rate multiplier and becomes the difference between two games:

| | Haulage budget | Reach |
|---|---|---|
| **Railroad running** | Full | Every camp, with real choices about who gets a full load |
| **Wagon teams only** | ~35% | The farthest camps are effectively unreachable |

The slot is playable either way — it must be, since minigames never gate
progress — but without the railroad it is a triage exercise rather than an
allocation one. That is the right feeling, and it is what the railroad card is
about.

## Cargo and camp needs

Use what the card already documents: **cement, equipment and supplies**. Each
camp has a need profile across the three, and partial supply gives partial
benefit — no cliffs.

> **Corrected 2026-07-28.** This read *food, timber, powder, coal*. **Coal is
> actively wrong** — the surviving locomotive documentation describes a fuel-oil
> tank — and **timber is a poor generic cargo**, because the project ran its own
> sawmills and made lumber on site rather than hauling it up. Both would have
> reached the art brief as commissioned assets before anyone checked them.
> **Workers were removed from the cargo set on review, and that reversed an
> earlier note in this file.** The railroad did carry crews, so the fact was
> right — but a *scored* cargo class makes people a tonnage the player optimises
> against cement and equipment, and invites the sentence "you delivered enough
> workers." This project does not put people on that side of the ledger. The
> crews remain in the prose and in the fiction of the line; they are not a load
> to be graded. Camp shortfall is still the failure this slot is about, and it
> is expressed through **crew wellbeing** in the outputs below, which is the
> right place for it.

Six camps, matching
[Six Camps in the Foothills](../../../../content/cards/09_six_camps_in_the_foothills.md).
Distances are fixed per board, generated within a profile rather than authored.

## Outputs

**Primary: crew wellbeing.** Supplied camps hold their workers; short camps lose
them. This is the direct line from this slot to the campaign.

**Secondary: a `camps_provisioned` flag** rather than a time payout. The
placeholder listed time as an output, and this design deliberately does not grant
it — the overrun-pressure measurement showed the campaign's time economy is
delicate, and handing out phases from an optional minigame is exactly the sort of
change that would need re-measuring the whole balance pass to justify.

Instead the flag is read by
[Sierra Snows](../../../../content/cards/08_sierra_snows.md), which is already
written and sourced. A well-provisioned line meets the winter differently. The
consequence stays in `content/`, where the historian can edit it, and no new time
is created.

## Tiers

Need met, **weighted by distance** so the far camps count for more:

| Tier | Weighted need met |
|---|---|
| `strong` | ≥ 90% |
| `fair` | ≥ 65% |
| `poor` | below 65% |

The weighting is the whole design in one line. Without it, "fill the nearest
camps" scores as well as thinking, and the slot is arithmetic.

**Result payload.** `weighted_need_met` (0.0–1.0), `tier`, `camps_full`,
`camps_short`, `haulage_used`. `Journey` applies crew wellbeing and grants
`camps_provisioned` at `fair` or better; the minigame writes nothing.

## Tone

Nobody is hurt in this slot — camps go short, and the consequence is workers
leaving rather than workers injured. That makes restraint easier here than in
slots 1 and 2, and it should be used: a short camp is a hard winter, not a
disaster, and the prose should not reach for one.

## Verification bands

`minigame_sim` must assert:

1. **`strong` is always achievable.** A solver reaches ≥90% weighted need on every
   generated board with the railroad running. Pass/fail — an unwinnable board is
   a broken board.
2. **Nearest-first must fail.** A policy that fills camps in distance order must
   not reach `strong` reliably. **If it does, the distance weighting is
   decorative and the slot is arithmetic.**
3. **All three tiers occur** under a competent policy, each at least 10%.
4. **The railroad must matter.** Tier distributions with and without
   `railroad_operational` must be clearly distinguishable.

Plus the standing requirement: campaign `sim_test` still completes with this
minigame skipped entirely.

## Numbers are a starting point

The 35% wagon budget, the six camps, the four goods and both tier thresholds are
first estimates. **The bands are the specification.**

## Historical anchors

- [Build the Railroad](../../../../content/cards/02_hetch_hetchy_railroad.md)
- [Sierra Snows](../../../../content/cards/08_sierra_snows.md) — reads
  `camps_provisioned`
- [Six Camps in the Foothills](../../../../content/cards/09_six_camps_in_the_foothills.md)

## For the historian

- **Answered, negatively:** the near/far supply asymmetry does not hold. Nothing
  reviewed supports a camp-by-camp wagon-road fallback, and two cards cut against
  it. This is why the slot is blocked; see above.
- **Partly answered:** cement, equipment and supplies come from card 02 itself.
  Workers are documented on the card too but are deliberately not a scored cargo
  class — see the correction above. Still open is whether the remaining three are
  a *useful* set for a puzzle: a set that is documented but undifferentiated in
  need makes a weak allocation board, and dropping to three makes that thinner,
  not thicker. If a fourth is wanted, it has to be found in the record rather
  than by putting people back on the manifest.
- **Now the live question:** what did a camp actually run short of, and what
  happened when it did? A documented consequence of going short is what this slot
  needs to replace the fallback asymmetry. Recorded in
  [FOLLOW-UPS.md](../../../FOLLOW-UPS.md).

## Inherited rules this slot does not revisit

- Never reads or writes `GameState`. `MinigameConfig` in, `MinigameResult` out.
- Never gates progress.
- Never adds a resource.
- Failing never subtracts readiness.
- Any historical liberty is recorded in the driving card's `assumption_note`.
