# Slot 1 — The Heading

**Status:** DESIGN. Ready for an implementation plan to be written against it.
**Archetype:** Press-your-luck (Can't Stop lineage)
**Cadence:** Recurring, player-initiated
**Priority:** First. Build this before any other minigame.

> This is the signature minigame — the Oregon Trail hunting analogue. It is
> built first because press-your-luck tuning is the one genuinely uncertain item
> on the slate, and because it is the hardest test of the module contract. If
> the contract is wrong, it shows here.

---

## Superseded by Batch B — read this first

This file was drafted before workfront progression landed. Three of its original
"already decided — do not revisit" items described a game that no longer exists.
They are corrected here rather than deleted, so that a future reader does not
restore them.

**1. "The 15 fixed spine cards form a dependency chain… the campaign has a hard
floor of roughly 15 turns whatever the pace."** No longer true. Fixed cards now
fire at **per-front progress thresholds** — a front with three cards fires them
at ⅓, ⅔ and completion — and progress comes from `_work_front()`. The spine is
six parallel fronts, not one chain.

**2. "Pace is not a decision — STEADY strictly dominates."** Fixed by Batch B.
`PACE_FACTOR` is `REST 0.0 / STEADY 1.0 / PUSHED 1.6`, applied to front progress,
and pushing now buys schedule at a real cost. The balance table in the original
draft is from P1 Task 6 and is superseded.

**3. "`work_pace` becomes the risk dial rather than a constant multiplier."**
This is the one live conflict with the parent spec (§4.1), and **the spec's
clause is not adopted.** Removing the multiplier would undo the measured Batch B
result. `work_pace` does both instead: it continues to multiply passive front
progress, *and* it sets this minigame's starting ground stress. Same dial, two
readings, nothing removed.

**The consequence is good news.** The original draft closed with *"Does progress
through the spine depend on footage? Do not design this slot without answering
that question."* Batch B answered it. Footage adds to `front_progress`, and
`front_progress` is what fires spine cards and what `miles_built` aggregates. A
foot driven in the minigame moves the campaign through the same path a passive
turn does. No new coupling is required, and `miles_built` already has the job
§4.1 wanted to give it.

---

## What the player does

Drill, load powder, blast, muck out — then decide. Each round the player picks
one of four actions, and this is the decision that keeps the slot from being a
"push again" button:

| Action | Footage | Stress | Stamina | Character |
|---|---|---|---|---|
| **Short round** | ×0.55 | +1 | 1 | Shallow pull, light powder. Cautious progress. |
| **Full round** | ×1.0 | +2 | 1 | The standard cycle. |
| **Deep round** | ×1.7 | +4 | 2 | Heavy powder, long pull. Overbreak risk. |
| **Set supports** | none | −3 | 1 | Timber or steel sets. Buys back safety, costs tempo. |

**Set supports is the load-bearing addition.** Without it, the only lever is
stop-or-continue and the optimal stopping round can be solved once and replayed
forever. With it, the player is trading tempo against risk under a stamina
ceiling, and the right answer moves depending on the survey, the crew, and how
far the target still is.

It is also the most historically exact element here: it is the Crane Ridge
decision, in miniature, every round.

## Risk model

A single accumulating value, **ground stress `S`**, rather than a round counter —
because supports must be able to reduce it.

```
p_bust = clamp(BUST_BASE + BUST_COEFF * S, 0.0, BUST_CAP)
BUST_BASE  = 0.02
BUST_COEFF = 0.025
BUST_CAP   = 0.55
```

Evaluated after the round is chosen, before its footage banks. `S` floors at 0.

**Q1 — curve shape: escalating, driven by stress.** Under uninterrupted Full
rounds `S = 2n`, so `p = 0.02 + 0.05n`: round 1 is 7%, round 4 is 22%, round 7 is
37%. Early rounds are nearly safe, the middle rounds are where the decision
lives, and the tail is punishing without being absurd.

**Q4 — round ceiling: stamina, with a hard backstop.** Stamina is the real
limiter (below). A hard cap of **12 rounds** exists only to bound session length
in arcade mode; ordinary play never reaches it.

**Q7 — stamina.** The shift's budget is `crew_wellbeing` at open, clamped to
3–10, supplied in config. Costs are in the table above. When stamina reaches
zero the shift **ends and banks normally** — this is not a bust. Running out of
crew must never be worse than not having played, or a depleted crew makes the
minigame a trap and the rational move is to stop opening it.

## Busting

**Q2 — partial loss, and the fraction is the hazard.** Which of the three
existing hazards occurred determines what it costs. This answers the original
draft's open question about bust text: the minigame **draws from the same three
hazard cards**, and severity is intrinsic to the hazard rather than invented.

| Hazard | Loses | Why |
|---|---|---|
| [h1_powder_blast](../../../../content/cards/h1_powder_blast.md) | the current round only | Premature detonation. The heading is damaged; the muck is out. |
| [h2_rockfall_in_the_heading](../../../../content/cards/h2_rockfall_in_the_heading.md) | half of banked footage | The heading is partly filled and must be cleared again. |
| [h3_cave_in](../../../../content/cards/h3_cave_in.md) | all banked footage; shift ends | The heading is closed. It has to be re-driven. |

Partial loss also flattens the expected-value curve, which is what stops a single
stopping round from dominating — see the bands below.

**On tone.** Bust prose is the hazard card's authored text, unchanged. No score
flourish, no "you lost" framing, no animation that reads as a fail state. The
Mitchell Shaft card is the standard this project already set for how it treats
injury, and this minigame does not get to lower it. A cave-in ends the shift
immediately and quietly.

**These hazards stay in the campaign deck.** The pace-risk roll and the
Heading's bust are different events at different scales — one is what happens
between turns, the other is what happens inside a shift — and the campaign roll
cannot be retired, because minigames are optional by invariant. A player who
skips every minigame must still face risk.

## The survey

**Q5 — Slot 2 (Probe the Face) changes decisions, not just numbers.** A good
survey does two things:

- **Lowers starting stress** `S₀`, which shifts the whole curve right.
- **Names the ground's likely hazard**, which tells the player whether a bust
  will be cheap or ruinous.

The second matters more than the first. Knowing the ground is prone to cave-in
rather than powder blast changes how deep to push and how often to spend a round
on supports — it changes play, where a flat probability tweak only changes
arithmetic. A player with no survey pushes blind and should feel it.

## Output and tiers

**Q6 — tiers are relative to the driving card's own historical anchor**, not to
absolute footage, so the same minigame serves cards with different targets.

```
strong :  footage >= target_feet
fair   :  footage >= 0.6 * target_feet
poor   :  below that
```

For [The 803-Foot Month](../../../../content/cards/11_the_803_foot_month.md),
`target_feet = 803` — the record September of 1926. Full-round footage scales to
`target_feet / 6`, so the record is reachable in six or seven clean rounds and
sits deep in the risky part of the curve. **A record month should feel like the
gamble it was.** Fair is reachable in four.

**Tier → choice mapping.** Tiers select among the driving card's authored
`EventChoice`s; they do not introduce new consequence text. The 803-Foot Month
card has two choices, so the mapping is many-to-one:

| Tier | Choice |
|---|---|
| strong | *Chase the record* |
| fair, poor | *Hold a sustainable pace* |

No content change is required for this card. If a future driving card wants
three distinct outcomes it must author a third choice — that is a historian
matter, not a minigame one.

**Result payload.** `footage_feet`, `tier`, `hazard_id` (empty when no bust),
`rounds_taken`, `stamina_spent`. `Journey` converts footage to front progress and
applies the hazard; the minigame writes nothing.

**Footage is additive.** Passive accrual continues exactly as it does now. The
Heading adds on top, paid for in crew stamina — a converter from crew wellbeing
into progress, which is what stops it being free mileage and what gives
`improve_camp` a second reason to exist. Skipping the minigame remains a complete
way to play.

## Verification bands

**Q8 — what `minigame_sim` must be able to detect.** Many seeded trials per
policy, asserting:

1. **No dominant stopping round.** The best three fixed stopping rounds must sit
   within **15%** of each other on expected banked footage. If one round is
   clearly correct, the press-your-luck decision is fake.
2. **Not a coin flip.** Under competent play each tier must appear at least
   **10%** of the time. A distribution that is nearly all `fair` means the
   decision does not matter.
3. **Supports must earn their place.** A policy that never sets supports must
   underperform an otherwise identical policy that does, by a margin outside
   noise. If they tie, the fourth action is decoration and the slot is a
   two-button game.
4. **Bust rate in band.** A "stop once fair is reached" policy should bust
   between **20% and 45%** of shifts. Below that there is no tension; above it,
   trying is worse than not.
5. **The survey must matter.** A surveyed shift must beat an unsurveyed one on
   expected footage, or Slot 2 has no reason to exist.

Plus the standing requirement: **campaign `sim_test` still completes with this
minigame skipped entirely.**

## Numbers are a starting point, not a result

Every constant above — `BUST_BASE`, `BUST_COEFF`, the stress costs, the footage
multipliers, the 0.6 fair threshold — is a first estimate chosen to put the
expected-value peak around round four with a near-flat top. They are meant to be
measured and moved by `minigame_sim`, and the bands above are the acceptance
test, not the constants.

**The bands are the specification. The constants are a guess.** If they cannot be
made to satisfy the bands, that is a design failure to report, not a band to
lower.

## Inherited rules this slot does not revisit

- Never reads or writes `GameState`. `MinigameConfig` in, `MinigameResult` out.
- Never gates progress. Passive accrual is always the fallback.
- Never adds a resource. Outputs map onto the existing five metrics.
- Failing never subtracts readiness. Poor play fails to *earn*.
- Result tiers select among a card's authored choices; prose stays in `content/`.
- Any historical liberty is recorded in the driving card's `assumption_note`.

## Still open, for the implementation plan rather than this design

- **The framework types do not exist yet.** There is no `MinigameConfig`,
  `MinigameResult`, or module contract anywhere in the tree. P2 builds them, and
  this slot is their first consumer — so the plan must define them before
  building this.
- **Arcade mode's default config**: which `target_feet` and `S₀` a title-screen
  launch uses, absent a driving card.
- **Stub first.** Per the standing rule, this ships as a stub — context plus a
  Resolve button returning a valid `MinigameResult` — before any of the above is
  implemented.
