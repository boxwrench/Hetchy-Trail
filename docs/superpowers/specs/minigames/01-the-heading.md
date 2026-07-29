# Slot 1 — The Heading

**Status:** **BUILT** 2026-07-28 — `scenes/minigames/the_heading/`, all five
bands passing under `minigame_sim`. **The constants below are superseded in three
places — read "Measured findings" before changing any of them.**
**Archetype:** Risk-managed allocation under a stamina ceiling.
~~Press-your-luck (Can't Stop lineage)~~ — **claim withdrawn 2026-07-28**, on
measurement. See finding 4.
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
| **Short round** | ×0.80 | +1 | 1 | Shallow pull, light powder. Cautious progress. |
| **Full round** | ×1.00 | +2 | 1 | The standard cycle. |
| **Deep round** | ×2.20 | +9 | 2 | Heavy powder, long pull. Overbreak risk. |
| **Set supports** | none | −3 | 1 | Timber or steel sets. Buys back safety, costs tempo. |

> **Superseded values.** This table previously read ×0.55 / ×1.0 / ×1.7 with Deep
> at +4 stress. Those were the pre-study guess. The values above are the accepted
> tuning study's, and Deep's +9 has since been re-measured and confirmed — see
> "Measured findings".

**Set supports is the load-bearing addition.** Without it, the only lever is
stop-or-continue and the optimal stopping round can be solved once and replayed
forever. With it, the player is trading tempo against risk under a stamina
ceiling, and the right answer moves depending on the survey, the crew, and how
far the target still is.

> **This paragraph is right about what supports prevent and was blind to what
> they cause.** They do stop the slot being a solved stopping problem — by
> removing the stopping decision altogether. Stress relief always beats stopping,
> so Bank is never chosen. Measured in finding 4; the archetype claim was
> withdrawn rather than the action removed.

It is also the most historically exact element here: it is the Crane Ridge
decision, in miniature, every round.

## Risk model

A single accumulating value, **ground stress `S`**, rather than a round counter —
because supports must be able to reduce it.

```
p_bust = clamp(BUST_BASE + BUST_COEFF * S, 0.0, BUST_CAP)
BUST_BASE  = 0.02
BUST_COEFF = 0.0175
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

**Q7 — stamina.** The shift's budget is `clampi(crew_wellbeing + 1, 3, 10)`,
supplied in config — **offset by one**, so a fresh crew at `START_CREW` 7 opens
at the tuned 8. See finding 5 for why. Costs are in the table above. When stamina
reaches zero the shift **ends and banks normally** — this is not a bust. Running
out of crew must never be worse than not having played, or a depleted crew makes
the minigame a trap and the rational move is to stop opening it.

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

**Result payload.** `score` and `tier`. Nothing else. The five-field payload this
file previously specified — `footage_feet`, `hazard_id`, `rounds_taken`,
`stamina_spent` — contradicts the module contract and must not be built.
`Journey` converts the score to front progress; the minigame writes nothing.

**Credit caps at `target_feet`.** Footage above the target earns no further
campaign credit, so drilling past `strong` is pure risk with no upside. This was
an open question and is now decided.

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
   **This band currently passes formally and fails in intent** — the measured
   spread is ~8.9%, but the optimal policy never voluntarily banks at all, so the
   band is satisfied by a game with no stopping decision in it. Reading a pass
   here as "the slot works" would be wrong. See "Measured findings".
2. **Not a coin flip.** Under competent play each tier must appear at least
   **10%** of the time. A distribution that is nearly all `fair` means the
   decision does not matter.
3. **Supports must earn their place.** A policy that never sets supports must
   underperform an otherwise identical policy that does, by a margin outside
   noise. If they tie, the fourth action is decoration and the slot is a
   two-button game.
   **Passes at 1.80 uses per shift — and this band is in direct tension with
   band 1's intent.** They cannot both be satisfied by these four actions; see
   finding 4. Band 3 was kept and band 1's intent was given up.
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

## Measured findings — 2026-07-28

Established by exact finite-horizon backward induction plus 20 000 sampled shifts
per geology, cross-checked against an independent implementation. A browser
prototype of this slot exists outside the tree and carries these tests inside it.

**1. Credit caps at `target_feet`.** Decided; recorded above.

**2. Deep round stays at +9 stress.** A prototype lowered it to +7 arguing Deep
was "strictly dominated". It is not: under optimal play Deep is already chosen
about **0.96 times per shift** at +9. The argument compared two pure lines (three
Deeps against six Fulls) and optimal play mixes. Do not lower it without
re-measuring.

**3. All four actions earn their place.** Per shift under optimal play, in
jointed rock: Short 1.03, Full 3.05, Deep 0.96, Supports 1.80. Band 3 holds.

**4. Nobody ever voluntarily banks, and this is the open problem.** At the
specified starting stamina of 8, voluntary Bank is **0.0%** in all three
geologies; ~91% of shifts end because stamina ran out. The optimal line reaches
the target on its last usable stamina, so the state where banking is correct is
never reached while stamina remains.

| Starting stamina | Voluntary Bank |
|---|---:|
| 8 | 0.0% |
| 9 | 0.0% |
| 10 | 21.4% |

**The cause is Set supports, and the claim is now withdrawn rather than fixed.**
Bank only wins when the marginal value of drilling turns negative. Stress relief
resets that, so it never turns negative — "reduce the risk" is always cheaper
than "stop taking the risk," and Bank is strictly dominated. Measured, jointed
rock, 8 000 shifts under exact backward induction:

| Set supports | used per shift | voluntary Bank |
|---|---:|---:|
| −3 stress + brace (as specified) | 1.80 | **0.0%** |
| −3 stress, capped at one per shift | 0.93 | 0.0% |
| costs 2 stamina instead of 1 | 0.92 | 2.4% |
| brace only, no stress relief | 0.00 | 45.2% |
| removed entirely | — | 45.2% |

**Band 3 and band 1's intent cannot both be satisfied by these four actions.**
Anything that makes supports worth taking kills the stopping decision; anything
that restores the stopping decision makes supports not worth taking. Reducing
relief to 0 or 1 does not compromise — the action is simply never chosen, giving
results identical to deleting it.

Two other levers were tested and are dead ends. **The strong bonus is
irrelevant**: sweeping it from 1.00 down to 0.05 changes nothing, because Bank
is dominated at every state, not just at target. **Overflow credit above target
is irrelevant**: the policy never has the spare stamina to overshoot with.

**The ruling: keep supports, drop the genre claim.** Supports are the most
historically exact element here — the Crane Ridge decision in miniature, every
round. Deleting the timber decision from a game about tunnelling in order to
earn a genre label from a board game trades the thing that teaches for the thing
that categorises. The slot is a risk-managed allocation puzzle and is a good
one: all four actions earn their place, every tier clears 10%, and geology moves
wipeouts from 4.2% to 15.2%.

**If a future reader wants the press-your-luck back**, the honest version is
removing supports entirely — 45.2% voluntary banking, tiers 31.6 / 13.6 / 54.8,
three actions. That is a real trade, not a tuning pass. One middle path remains
untested: supports as a single strong once-per-shift brace against *every*
hazard rather than a stress reducer.

**5. Stamina mapping, pace → S₀, and the arcade default — all three decided
2026-07-28.** These were the last open inputs; P3 needs concrete numbers.

**Stamina is offset by +1 from crew wellbeing:**

```
stamina = clampi(GameState.crew_wellbeing + 1, 3, 10)
```

`START_CREW` is 7, so a fresh crew opens the slot at the tuned **8** rather than
at an untuned 7. Rest and camp gains push toward 10, which is where voluntary
banking appears — so a rested crew plays a slightly different shift, and that is
a feature rather than an accident. This touches no card data. The alternatives
were re-tuning everything to 7, or raising `START_CREW` to 8 — the latter looks
smallest but is campaign economy and would move `sim_test`'s `matched_history`
grade and the Batch B balance.

Stamina 7 was measured and all bands still hold (poor 27.2 / fair 17.3 /
strong 55.5), so a worn crew degrades gracefully rather than breaking the slot.

**`work_pace` sets raw S₀, and the survey subtracts 2:**

| `Pace` | raw S₀ | applied, surveyed | strong % at stamina 8 |
|---|---:|---:|---:|
| `REST` | 1 | 0 | 67.6% |
| `STEADY` | 3 | 1 | 66.2% ← reference config |
| `PUSHED` | 8 | 6 | 48.1% |

Measured across applied S₀ 0–8: every band holds throughout, and strong moves
monotonically from 67.6% to 39.2%. **PUSHED is not strictly wrong** — it makes
the heading materially harder while buying 1.6× passive front progress, which is
a real trade.

**REST and STEADY are close on S₀ and that is deliberate.** `PACE_FACTOR` for
REST is 0.0, so resting already forfeits all passive progress; it does not also
need a large minigame bonus. The differentiation lives in the pace's other
effect.

**Arcade default** (no driving card): `target_feet` 803, raw S₀ 4 with the survey
applied (applied 2), stamina 8, geology drawn at random. That measures poor 23.0
/ fair 14.5 / strong 62.5 with 8.8% wipeouts — winnable, not a formality, and
about six to eight rounds.

**6. Tier spread at the specified constants** (jointed rock, optimal play): poor
21.2%, fair 13.1%, strong 65.6%, with 8.1% of shifts wiped out by ground runs.
Band 2 holds. Geology matters: wipeouts run 4.2% in sound granite and 15.2% in
wet ground, so band 5 holds too.

## Inherited rules this slot does not revisit

- Never reads or writes `GameState`. `MinigameConfig` in, `MinigameResult` out.
- Never gates progress. Passive accrual is always the fallback.
- Never adds a resource. Outputs map onto the existing five metrics.
- Failing never subtracts readiness. Poor play fails to *earn*.
- Result tiers select among a card's authored choices; prose stays in `content/`.
- Any historical liberty is recorded in the driving card's `assumption_note`.

## Still open, for the implementation plan rather than this design

- ~~The framework types do not exist yet~~ — **built and verified.**
  `MinigameConfig`, `MinigameResult` and `MinigameRegistry` are in `resources/`;
  `minigame_check` validates the wiring.
- ~~Arcade mode's default config~~ — **decided, see finding 5.**
- ~~The stamina mapping~~ — **decided, see finding 5.**
- ~~Stub first~~ — **superseded.** The stub shipped first and the real module
  followed. The stub is kept as the fallback for slots 2–5.

**Still genuinely open:**

- **The arcade entry point.** The default config is decided (finding 5) but
  `scenes/main/` holds only a `.gitkeep` and `run/main_scene` is `journey.tscn`,
  so there is no title screen for it to live on. Needs a Main scene, not more
  minigame work.
- **The survey.** Slot 2 is blocked on historian question H6. Until it exists no
  survey relief is applied, so an unsurveyed STEADY shift opens at S₀ **3**, not
  the **1** every table in this file quotes — those are the *surveyed* figures.
  The module already accepts `s0` and `surveyed` from config, so slot 2 will
  change a number rather than the module.
- **Band 4 has little headroom.** The stop-at-fair hazard rate measures 42.3%
  against a 45% ceiling. If anything moves the risk curve, this is the band that
  breaks first.
