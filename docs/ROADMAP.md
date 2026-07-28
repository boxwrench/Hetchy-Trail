# Hetchy Trail — Roadmap

**Start here.** This file is the entry point for any human or AI agent working
on this repository. Read it fully before changing anything.

## What this project is

A Godot 4.7 teaching game: build the 167-mile Hetch Hetchy aqueduct
(1914–1934) balancing five metrics.

It is a **showcase piece** — distributed internally among SFPUC staff, possibly
posted to agency social media. Expected play counts are low. Its job is to
demonstrate a concept and inspire creativity in the department. Three
consequences govern design decisions:

1. **The first three minutes are the product.** Most people play once, briefly,
   or watch a clip.
2. **The minigame is the artifact.** Nobody shares a screenshot of a resource
   dropdown.
3. **Accuracy still governs.** An agency historian reviews the content; the
   teaching layer is non-negotiable.

Architecture and data model are documented in
[technical_design.md](technical_design.md).

## Current state (2026-07-27)

Built and committed: both autoload singletons, the full data model, 26 event
cards (15 fixed spine + 6 texture + 5 hazards), 6 route segments, the pace-risk
mechanic with its telegraph, HUD, DecisionPanel, EventPanel, the Journey
conductor, and the smoke/sim/layout harness. The game is playable end to end.

Not built: the route map, title and end screens, minigames, balance pass.

> **Ledger note.** The checkboxes in the two completed plan files
> ([playable-core](plans/2026-07-05-playable-core.md),
> [decision-weight](superpowers/plans/2026-07-06-decision-weight.md)) were never
> ticked as the work landed, so they read as untouched. Their work is done; git
> history is the record. **Going forward the checkbox ledger is mandatory** —
> worker/reviewer mode (below) depends on it being truthful.

## Active design

[**Minigames & Campaign Restructure**](superpowers/specs/2026-07-27-minigames-and-campaign-restructure-design.md)
— the approved design now in force. It supersedes the remaining milestones of
the playable-core plan, because it reshapes the loop those milestones decorate.

It fixes five defects: empty turns, an unbounded bond/outreach loop that
disarms four of five loss conditions, two metrics that do no work, `.tres`
being unauthorable by a historian, and art coupled to card data.

[**Follow-ups**](FOLLOW-UPS.md) — real but unscheduled items, with the reasoning
kept so a future session need not re-derive it. Four are for the historian and
go out as one packet; the rest are content opportunities and project hygiene.

## How to work here

### Worker/reviewer mode

Implementation runs as **a worker model executing a batch, then a reviewer model
checking it.** Plans are written for this: every step is explicit, every
verification is a command with an expected result, and no step requires a design
judgment call.

[Overrun Pressure](superpowers/plans/2026-07-28-overrun-pressure.md) is
implemented and committed — October 1934 now costs funds and public support
once passed. Design:
[overrun pressure spec](superpowers/specs/2026-07-28-overrun-pressure-design.md).

**It is correct, verified, unreachable, and frozen. Do not tune any `OVERRUN_*`
constant.** The mechanism fires, escalates and drains support exactly as
designed — `smoke_test` proves it. Nothing a rational player does gets near it.

The [Late-Viability Probe](superpowers/plans/2026-07-28-late-viability-probe.md)
settled this and is complete; its ledger holds the full measurement. In short:

- Pressure cannot begin before **phase 35**. Two gates, not one: the grace
  phases, and `current_year()`, which does not return 1935 until phase 34. So
  lowering `OVERRUN_GRACE_PHASES` to zero would change nothing.
- No strategy reaches **phase 32**. Probe output pre-pressure (`406c989`) and
  post-pressure (`d9e5745`) is byte-identical on identical seeds.
- A conservative choice policy — protect the metrics, ignore time — was added to
  test the one archetype that might run late. It finishes **earlier**: phase
  27.9 average against canonical's 30.9.

**The reason is in the content, not the constants.** Of 15 multi-choice cards,
the resource-safest option is also the fastest on 7, time-neutral on 3, and
genuinely costs schedule on only 5. Delay and resource loss are correlated
rather than traded, so the cautious player who pays in schedule — the archetype
overrun pressure exists to price — does not exist in the current deck.

Headroom is not the constraint: always choosing the slowest option would add 30
seasons. The deck can produce a long campaign. It cannot produce one as the
consequence of playing well.

**Open decision, and it is a content decision:** whether more than 5 of 15 cards
should offer *protect the metrics, pay in seasons*. That means `time_delta_seasons`
in `data/events/`, which is historian territory and off-limits to a worker. Until
it is made, there is no current plan and overrun pressure stays as it is.

[Batch B — Workfront Progression](superpowers/plans/2026-07-27-batch-b-workfronts.md)
is implemented and committed, meeting three of its four success criteria; the
best-strategy band still fails and its ledger records why.
([P1 — Foundations](superpowers/plans/2026-07-27-p1-foundations.md) and
[P1.5 — Review Fixes](superpowers/plans/2026-07-27-p1.5-review-fixes.md) are
both complete.)

**If you are the worker:**

1. Open the current plan. Find the first unchecked `- [ ]` step.
2. Do steps **in order**. Never skip a verification step.
3. Run the verification exactly as written. Confirm the stated exit code or
   output before moving on.
4. At the end of a batch, commit with the message given in the plan and tick the
   checkboxes for what you completed. **Tick only what you actually verified.**
5. Stop at the batch boundary and report. Do not begin the next batch.

**Stop immediately and report instead of improvising when:**

- A verification fails twice in a row after your best fix.
- A step requires a design decision the plan does not cover.
- You are tempted to add a mechanic, resource, or dependency.
- A step's expected output does not match what you see, even if it looks close.

Never delete data or weaken a check to make the harness pass. When blocked on a
bug, debug the root cause — reproduce, isolate, fix.

**If you are the reviewer:** verify against the plan's stated verification, not
against the worker's summary. Re-run the harness yourself. Check that ticked
boxes correspond to work that actually landed.

### Minigames are stub-first — never hand a placeholder to a worker

A weak worker can implement a fully-specified module reliably. It cannot design
one. So every minigame ships first as a **stub**: a screen with the card's
context and a Resolve button, returning a valid result. The game stays complete
and playable throughout, and stubs are replaced one at a time.

The five slots live in
[specs/minigames/](superpowers/specs/minigames/). Each is a **placeholder** —
a list of open design questions — until a strong model fills it in.

**A placeholder is not an instruction.** Handed one, a worker will invent
answers to its open questions. The order is always: strong model writes the slot
design → strong model writes the implementation plan → worker executes it under
review.

### Verification harness

```bash
godot --headless res://tools/smoke_test.tscn
```

```bash
godot --headless res://tools/sim_test.tscn
```

Both must exit 0. A failing harness is never committed.

```bash
godot --headless res://tools/balance_probe.tscn
```

Measurement, not a test — always exits 0. Plays six pace strategies across 12
seeds and reports win rate, grade, and failure modes. Use it when tuning, and to
check whether a change actually made pace a decision.

### Documentation is load-bearing here

Worker agents read docs as instruction, so a stale document actively causes
deleted concepts to be restored. `technical_design.md` drifted a whole release
behind during P1 and had to be rewritten in P1.5.

**When a task removes or renames a concept, grep the docs for it in the same
task.** The code-level greps in these plans exist for that reason; extend them
to `docs/` whenever a field, method, or system disappears.

## Milestones

| # | Milestone | Deliverable | Verified by | Status |
|---|-----------|-------------|-------------|--------|
| M0 | Toolchain & harness | Project imports; smoke + sim run headless | `smoke_test`, `sim_test` exit 0 | **Done** |
| M1 | First playable loop | HUD, DecisionPanel, EventPanel, Journey | Harness + manual playthrough | **Done** |
| M1.5 | Decision weight | Pace-risk, hazard deck, risk telegraph, HUD warnings | Harness + sim hazard probes | **Done** |
| P1 | Foundations | 24-turn restructure, economy fix, content pipeline, art decoupling | Harness + exploit probe + historian can edit a card | **Done** |
| P1.5 | Review fixes | End-screen crash + UI end test, design-doc rewrite, reveal-after-choice, validator hardening | Harness + four broken cards rejected by name | **Done** |
| B | Progression model | Parallel workfronts on paper; Pareto-dominance probe over card choices | A model that makes pace a decision | **Built** — 3 of 4 criteria met; pace now buys schedule |
| B.1 | Overrun pressure | 1934 becomes a binding milestone; pressure escalates to the existing loss conditions | `balance_probe` — slow and badly-allocated play must start losing | **Built, measured, frozen** — verified by `smoke_test`; unreachable because no card choice trades schedule for safety. Blocked on a content decision, not a tuning pass |
| P2 | Minigame framework + The Heading | Module contract, arcade mode, press-your-luck tuning | Harness + `minigame_sim` band check | After B |
| P3 | The remaining four | Minesweeper, Pipe Dream, lane-dodge, Bond Vote set piece | Harness + per-minigame sim | After P2 |
| M2 | The lighting map | Six divisions drawn, lighting as flags land | Harness + visual check | Folded into B — the map is the workfront UI |
| M3 | Framing screens | Title (with arcade entry), end screen, replay | Harness + manual win/loss | Folded into P2 |
| M4 | Content, framing & release | Source traceability, framing layer, archival photos, audio, export preset, licence, CI | Harness + historian sign-off | Last |

**Why B exists and why it sits before P2.** An external review
([response](superpowers/specs/2026-07-27-external-review-response.md)) confirmed
what the balance probe already showed: pace has one correct answer, because the
15 fixed spine cards form a dependency chain that floors the campaign near 15
turns at any pace. Mileage gates nothing. The fix is parallel construction
fronts — which is also what the project's own historical brief asked for, and
what `SYSTEM_FLAGS` already claims the game is about. The Heading's design
depends on whether footage drives progression, so building it before B means
designing it twice.

**P1 first, deliberately.** It depends on no minigame design and it unblocks the
two tracks that run in parallel with everything else: historian review of
content, and art production. Neither should wait on gameplay work.

## Invariants that outlive any plan

- Five metrics, one mile counter, campaign flags. **Never a sixth resource.**
- All game logic lives in `autoload/` + `resources/`; scenes only display and
  call GameState methods.
- **Minigames never gate progress.** A player who skips every one must still be
  able to finish the campaign.
- Minigames never read or write `GameState` — config in, result out.
- Every historical deviation is recorded in a card's `assumption_note`.
- Archival images require a row in `assets/art/archival/CREDITS.md`.
- **No GPL dependencies.** MIT/Apache/BSD with a credits row, or nothing.
- A failing harness never gets committed.
