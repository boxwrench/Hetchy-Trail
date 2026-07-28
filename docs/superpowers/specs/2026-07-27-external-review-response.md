# External Review — Response & Disposition

**Date:** 2026-07-27
**Reviewed at:** commit `7b9c136`, Godot 4.7.1
**Status:** All findings verified. Dispositions below are binding — nothing here
is dropped, and every deferred item names the milestone that owns it.

The reviewer's summary — *"a technically healthy pre-alpha, not yet a compelling
showcase game"* — is accurate and is the right frame for what follows.

## Verification

Every checkable claim was independently confirmed before acceptance.

| # | Finding | Verified | Disposition |
|---|---|---|---|
| 1 | `journey.gd:77` reads removed `GameState.year`; crashes on every game over | **Yes** | **P1.5 Task 1** |
| 2 | Harnesses never end a campaign with the real UI instantiated | **Yes** | **P1.5 Task 1** |
| 3 | `technical_design.md` stale — 11+ refs to `year`/`season`, "one turn = one season", "21 cards", `try_draw()` | **Yes, worse than stated** | **P1.5 Task 2** |
| 4 | Historical fact + assumption note shown *before* the player chooses | **Yes** | **P1.5 Task 3** |
| 5 | Validator does not reject unknown flags, unknown keys, misspelled effects, duplicate ids, out-of-range numbers | **Yes** | **P1.5 Task 4** |
| 6 | Pareto-dominated card choices (Red Mountain Bar) | **Yes** | **Batch B** — dominance probe |
| 7 | Pace has one correct answer; structural, not tuning | **Yes** — independently found pre-review | **Batch B** — workfronts |
| 8 | 20 of 26 source notes identical and generic | **Yes** | **M4** — historian pass |
| 9 | No framing layer (Raker Act, preservation, Indigenous history, public power, labor) | **Yes** | **M4** — framing content |
| 10 | `index.html` empty (0 bytes); no export preset | **Yes** | **M4** — export |
| 11 | No `LICENSE` committed | **Yes** | **M4** — org decision |
| 12 | No CI | **Yes** | **M4** — CI |

## One correction to the review's prescription

The review proposes as the minimum fix: *"let footage thresholds unlock
milestones and allow multiple crossed milestones to queue during a productive
phase."*

**Snapshot queueing was tested and does nothing.** Allowing two fixed cards per
turn *from one availability snapshot* moved `push while crew>=6` from 1/12 wins
to 0/12. The chain gates *availability*, not the one-per-turn rule — card 05 is
not available until card 04 resolves, so the snapshot never holds a second card
to queue.

**The load-bearing half is footage thresholds replacing flag-chain
dependencies.** Implementing snapshot queueing alone would look like progress
and deliver none. Recorded because a future agent reading the review without
this note would build the ineffective half.

### Update — Batch B Session 3: a different mechanism does work

The finding above is about **snapshot queueing** and still stands. It is not a
verdict on two cards per turn as such, and the distinction is exactly where the
mechanism lives:

- **Snapshot queueing** reads `_available_cards()` once, before anything
  resolves, and takes two. The second card's `required_flags` are not satisfied
  yet, so there is nothing to take. Ineffective, as measured.
- **Post-resolution chaining** resolves the first card, then *re-evaluates*
  availability on the same front. The flag now exists, so the next card is
  genuinely unlocked. This is what `EventManager.try_draw_followup()` does.

Under workfronts the second condition is reachable, because progress thresholds
and flag grants are separate gates: a fully worked front has met every
threshold and is waiting only on flags its own cards supply.

Measured effect: pushing strategies went from **0/12** to **5–6/12**, the first
time pace has converted into schedule. `smoke_test._check_card_chaining()`
guards the distinction directly — it asserts the snapshot offers exactly one
fixed card while chaining yields two.

## Accepted as the central direction: parallel construction fronts

The contradiction the reviewer identifies is real and is already in the code.
`GameState.SYSTEM_FLAGS` is documented as *"the city receives nothing until the
whole chain works as one system"* — the interconnected-system intent exists; the
implementation is a straight line of 15 dependency-chained cards.

It is also the fix for the pace problem found independently in
[slot 01](minigames/01-the-heading.md): with six fronts, allocating effort is a
genuine decision, pace and minigames get a *specific* front to affect, and
bottlenecks emerge from structure instead of tuning.

The groundwork exists — the six divisions are already `RouteSegment` resources
with completion flags and build-rate modifiers.

**Consequence for sequencing: P2 does not start with The Heading.** That
minigame's design depends on whether footage drives progression, which is the
same question workfronts answer. Building it first means designing it twice.

Per-division progress stays internal contract state. **It does not become six
new player resources** — the five-metric invariant holds, and the public
167-mile counter remains as aggregate completion.

## Sequencing

| Batch | Contents | Who |
|---|---|---|
| **P1.5** | Findings 1–5: end-screen fix + UI end test, technical design rewrite, reveal-after-choice, validator hardening | Worker, under review |
| **Batch B** | Workfront progression model; Pareto-dominance probe over card choices | Strong model, on paper first |
| **P2** | Minigame framework + The Heading, reshaped by Batch B | Both |
| **M4** | Findings 8–12: source traceability, framing layer, export, licence, CI | Mixed; some are the user's org call |

## Deferred items — owner and trigger

None of these are dropped. Each names what unblocks it.

- **Source traceability (8)** — the `historical_source_note` field exists and is
  enforced non-empty; the *content* is placeholder. This is precisely what the
  historian review pass produces. **Trigger:** historian returns their first
  edited batch. Each card needs document title, publication, archive identifier,
  and page.
- **Framing layer (9)** — Raker Act and the preservation fight, Indigenous
  history of the valley, public-versus-private power, downstream interests,
  labour. Does not all need event cards; a title-screen or timeline framing
  layer suffices. **Trigger:** M4 content pass. For a piece shipping under an
  agency's name, teaching how the system was built without acknowledging what it
  cost is a gap people will notice.
- **Export preset + `index.html` (10)** — currently a committed 0-byte file.
  **Trigger:** first build anyone outside the repo needs to run.
- **Licence (11)** — an SFPUC decision, not an engineering one. **Trigger:**
  before any public distribution or social posting.
- **CI (12)** — smoke, sim, layout, and import round-trip on push. **Trigger:**
  any time after P1.5; cheap and independent.
