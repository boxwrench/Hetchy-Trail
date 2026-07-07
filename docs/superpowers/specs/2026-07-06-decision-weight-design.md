# Hetchy Trail — Decision Weight & Feedback: Design Spec

**Date:** 2026-07-06
**Status:** Approved design → ready for implementation plan
**Branch context:** `feat/playable-core` (post Task 7; lands *before* Task 8 of
[the playable-core plan](../../plans/2026-07-05-playable-core.md)).

## Problem

The game is playable end-to-end (Milestone M1), but a human playthrough after
the layout fix reported: **the loop plays but the decisions feel weightless.**

Diagnosis, grounded in the code:

1. **Pace is a near-dominant strategy.** `PUSHED` (4.0 mi) beats `STEADY`
   (2.5 mi) by +60% for only −1 crew/season, and crew is trivially refilled
   (`improve_camp`: +2 crew for −1 fund). "Push always, top up crew" is just
   correct — and the sim harness plays exactly that reflex and wins.
2. **The three per-turn actions form a closed top-up loop.** Each converts ~1
   unit of one meter into ~2 of another, all cheap and always available, with
   plenty of turns. The per-turn action is "refill whichever meter is lowest" —
   bookkeeping, not a dilemma.
3. **Consequences are realized silently.** Meters tick by 1–2 on a 0–10 scale
   and the front moves ~2.5 mi against 167; nothing crosses a threshold most
   turns, so no turn *feels* like it mattered. Critically, every `EventChoice`
   already authors an `outcome_text` (the narrative consequence) and the game
   **never shows it** — [EventPanel](../../../scenes/ui/event_panel.gd) hides the
   card the instant you click. The richest emotional-weight and feedback source
   already written is invisible.

The event-card choices themselves *do* carry real weight (five-delta model,
flags, ongoing costs like the pumped-line winter surcharge) — but that weight is
never surfaced, so it is not felt.

## Goals

- Make the recurring pace/action decision tense: no single pace is always right.
- Make consequences **visible and felt** — before the choice (stakes) and after
  it (narrative outcome + actual metric change).
- Carry emotional weight through **historical narrative**, real or plausible,
  keeping the historic sense while giving texture to choices.

## Non-goals / constraints (invariants — violating one is a failure)

- **Five metrics only** (funds, public_support, water_readiness, crew_wellbeing,
  time) plus miles + flags. No sixth resource.
- **All game logic stays in `autoload/` and `resources/`.** Scenes only display
  and call GameState/EventManager methods; display panels never mutate state.
- **Never edit authored historical cards in `data/`** to pass a test. New hazard
  content is authored fresh, following the existing card template.
- **Every historical deviation stays recorded** in a card's `assumption_note`.
- **Mini-games are out of scope** — a separate follow-on design (see below).

## Design

### §1 — Pace-risk mechanic

Each season, after the build resolves, there is **one risk roll**, tilted by the
chosen pace **and** by current board state:

| Pace | Hazard pool | Base chance | Amplified when… |
|------|-------------|-------------|-----------------|
| `PUSHED` | Injury (crew −1/−2, sometimes funds −1) | elevated | crew already low → pushing a tired crew is dangerous |
| `STEADY` | either, low | low | the balanced hedge |
| `REST` | Impatience (support −1, funds −1) | elevated | support already low → the Board's patience is thin |

This breaks the dominant strategy: pushing a *fresh* crew is usually fine;
pushing a *weary* one gets someone hurt. Resting with high support is tolerable;
resting when the Board is already restless bleeds support and funds. The right
pace depends on the current board, not a fixed optimum.

**"Too slow" keys off pace only** (`REST` this season), not schedule position —
simpler, symmetric with `PUSHED`, easy to telegraph. Schedule-pressure is a
possible later amplifier, explicitly deferred.

**Implementation shape (logic in autoloads/resources):**
- New tuning knobs in `EventManager` (analogous to `event_chance`), e.g.
  `INJURY_CHANCE_PUSHED`, `IMPATIENCE_CHANCE_REST`, a low `STEADY` baseline, and
  a low-meter amplification factor. Exact values are set in the balance pass.
- The roll happens in the EventManager draw path. **Turn order is preserved:**
  the fixed historical spine still fires first (unchanged); only when no fixed
  card is due does the pace-risk roll choose between a hazard, the existing
  weighted texture card, or nothing. **Still at most one event per turn.**

### §2 — Feedback layer (pure presentation)

Three surfaces, all reading GameState fields/signals the autoloads already emit.
Files touched: `scenes/ui/event_panel.gd`, `scenes/ui/decision_panel.gd`,
`scenes/ui/hud.gd`. No new game logic, no new resource.

1. **The consequence beat (centerpiece).** On an event choice, the card no
   longer vanishes silently: it reveals the authored `outcome_text` **plus the
   actual metric changes** (e.g. `Funds −2  Crew −1  ▸ banked a season`), then
   the player dismisses it. Hazards use the same beat, so an injury reads like an
   event, not a dice tick.
2. **DecisionPanel risk telegraph.** Each pace option shows a live read from
   current state — *"Rest — the Board is restless; support at risk"*,
   *"Push — crew is weary; injury very likely."* The stakes are visible before
   committing (the "indicator to change strategy, and the cost if you don't").
   The panel does **not** compute risk itself: it calls a read-only EventManager
   query (e.g. `risk_preview(pace) -> {kind, level}`) so the risk model stays in
   the autoload and the scene only renders the label.
3. **HUD warning + ongoing-cost cues.** A metric trending toward its loss
   condition (funds→bond crisis, support→cancelled, crew→work halts) shows a
   warning state instead of a bare number. Persistent drains are surfaced — e.g.
   the pumped-line `−1 funds each winter` is shown, not hidden.

### §3 — Hazard content & narrative

A small, repeatable pool authored as EventCards (so each carries the teaching
layer). Historical/plausible texture, honest about liberties.

- **Injury pool (~3 cards):** drawn from real Hetch Hetchy danger — a premature
  powder blast, a rockfall in a heading, gas in the deep Coast Range bore.
  Effect: crew −1/−2, sometimes funds −1. The existing
  [Mitchell Shaft memorial](../../../data/events/17_mitchell_shaft_memorial.tres)
  is the documented anchor these plausible incidents echo (handled with the same
  restraint — no sensationalism).
- **Impatience pool (~2 cards):** the Board questions another idle season;
  ratepayers grumble at the delay. Effect: support −1, funds −1.

**Model touch (the one resource-model addition):** `EventCard` gains a field
`hazard_kind: StringName` (`&""` = normal card; `&"injury"` / `&"impatience"` =
hazard). Hazards are excluded from the normal texture draw, fired only by the
pace-risk roll, and are **not consumed** (injuries recur), unlike spine/texture
cards. Every hazard fills `historical_fact` + `assumption_note`.

### §4 — Testing & harness

- **smoke_test:** bump the sanctioned deck-count (21 → 26); add checks that each
  hazard has a `hazard_kind`, an `outcome_text`, and touches only the five
  metrics.
- **sim_test:** stays deterministic (seeded). `STEADY`'s hazard rate is low, so
  the canonical run must still finish ≤1940 (winnability guard holds). Add an
  assertion that **at least one hazard fires** across the run, so the mechanic
  can't silently break.
- **layout_test:** extend to assert the new **consequence beat** (outcome_text +
  deltas) renders on-screen — same bug class as the DecisionPanel off-screen fix.
- **Balance (existing plan Task 10):** absorbs the new tuning knobs — injury /
  impatience base chances and their low-meter amplification — alongside the
  existing pace/funds knobs.

## Sequencing

This work lands **before** Task 8 (route map), because it reshapes the core loop
the map decorates. Existing Tasks 8–10 then follow, with Task 10 tuning hazards
too. The implementation plan produced from this spec defines the task breakdown.

## Deferred follow-ons (own designs, not part of this spec)

- **Mini-games on event cards** (Oregon-Trail-style), placeholders acceptable.
  Not crucial to core play. Chosen architecture direction: a mini-game's outcome
  *selects among the card's already-authored EventChoices* (skill replaces the
  button click), so no sixth resource and all consequence data stays in the card.
  The interesting hook is **earning resources back from a poor choice** — a
  redemption beat.
- **Art assets** stay on the user's track (AI pipeline + SFPUC archive). Specs
  live in [docs/art_assets.md](../../art_assets.md); the palette/tone can be
  applied to programmer-drawn UI later without imported images.
