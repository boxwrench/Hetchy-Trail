# Hetchy Trail — Roadmap

**Start here.** This file is the entry point for any human or AI agent working
on this repository. Read it fully before changing anything.

## What this project is

A Godot 4.7 teaching game: build the 167-mile Hetch Hetchy aqueduct
(1914–1934) balancing five metrics. Architecture, data model, and all game
logic are complete and documented in
[technical_design.md](technical_design.md). What remains is the toolchain
harness, the scenes, and balance.

## How to work here (any agent, any skill level)

1. Read [technical_design.md](technical_design.md) sections I–V, then the
   **Global Constraints** in the current plan.
2. Open the current plan: [plans/2026-07-05-playable-core.md](plans/2026-07-05-playable-core.md).
3. Find the first unchecked `- [ ]` step. Do steps **in order**. Never skip a
   verification step.
4. After each task: run the verification harness (smoke + sim), confirm exit
   code 0, commit with the given message, tick the checkboxes in the plan file.
5. **Stop conditions — report to the user instead of improvising:** a
   verification fails twice in a row after your best fix; a step requires a
   design decision the plan doesn't cover; you are tempted to add a mechanic,
   resource, or dependency. When blocked on a bug, debug the root cause
   (reproduce → isolate → fix); never delete data or weaken a check to make
   the harness pass.

## Milestones

| # | Milestone | Deliverable | Verified by | Status |
|---|-----------|-------------|-------------|--------|
| M0 | Toolchain & harness | Godot installed, project imports, smoke test + full-campaign simulation run headless | `smoke_test` and `sim_test` exit 0 | Tasks 1–3 |
| M1 | First playable loop | HUD, DecisionPanel, EventPanel, Journey conductor; play a season with the mouse | Harness + manual playthrough of ~10 turns | Tasks 4–7 |
| M2 | The lighting map | Six divisions drawn, lighting up as completion flags land | Harness + visual check | Task 8 |
| M3 | Framing screens | Title screen, end screen with grade vs. October 1934, replay | Harness + manual win/loss | Task 9 |
| M4 | Balance & teaching pass | Sim finishes 1934±2 on canonical play; teaching layer readable on every card | `sim_test` prints finish year in range | Task 10 |
| M5 | Content & polish | SFPUC archival photos (credits mandatory), art, audio, export | Future plan — do not start without the user | Not planned yet |

## Invariants that outlive any plan

- Five metrics, one mile counter, campaign flags. **Never a sixth resource.**
- All game logic lives in `autoload/` + `resources/`; scenes only display and
  call GameState methods.
- Every historical deviation is recorded in a card's `assumption_note`.
- Archival images require a row in `assets/art/archival/CREDITS.md`.
- A failing harness never gets committed.

Completed work log: architecture + full data model + both singletons + 21
event cards + 6 segments (July 2026, see git history).
