# Minigame design slots

One file per minigame slot. Each starts as a **placeholder** and is filled in by
a strong model immediately before that minigame's implementation plan is
written — never earlier. See
[§5a of the parent spec](../2026-07-27-minigames-and-campaign-restructure-design.md#5a--stub-first-minigame-delivery)
for why.

## Status

| Slot | File | Stub shipped | Design written | Implemented |
|---|---|---|---|---|
| The Heading | [01-the-heading.md](01-the-heading.md) | — | **Yes — buildable** | — |
| Probe the Face | [02-sound-the-rock.md](02-sound-the-rock.md) | — | **Yes — buildable** within its claim boundary; renamed, filename kept so links resolve | — |
| Forty-Seven Miles | [03-forty-seven-miles.md](03-forty-seven-miles.md) | — | **Yes — buildable** | — |
| Keep the Line Open | [04-keep-the-line-open.md](04-keep-the-line-open.md) | — | **BLOCKED** — archetype changed to a loading puzzle, but its premise is contradicted by the deck and it needs a new source of tension | — |
| Make the Case | [05-make-the-case.md](05-make-the-case.md) | — | **BLOCKED** — structure is sound, the bloc set is withdrawn | — |

**"Design written" is not "ready to build."** Slots 4 and 5 have complete designs
that are blocked on a historical question, and their files say so at the top.
Read the status column, not the file count.

## How to fill one in

**Do not hand a placeholder to the worker model.** A placeholder is a list of
open questions; a worker will invent answers to them. The order is always:

1. A strong model answers every question in the "Must be decided" section and
   rewrites the file as a real design spec.
2. A strong model writes an implementation plan in
   `docs/superpowers/plans/`, in the same explicit style as
   [P1](../../plans/2026-07-27-p1-foundations.md) — exact code, exact
   verification commands, exact expected output.
3. The worker executes the plan in reviewed batches.

## Rules every minigame inherits

From the parent spec and [ROADMAP.md](../../../ROADMAP.md). These are not
open questions — do not revisit them in a slot design.

- **Never reads or writes `GameState`.** `MinigameConfig` in, `MinigameResult`
  out. `Journey` applies the result.
- **Never gates progress.** A player who skips it must still be able to finish
  the campaign. Passive accrual is always the fallback.
- **Never adds a resource.** Outputs map onto the existing five metrics.
- **Result tiers select among a card's authored `EventChoice`s** — consequence
  prose stays in `content/cards/`, where the historian can edit it.
- **Failing never subtracts readiness.** Poor play fails to *earn*; it does not
  punish. Otherwise skipping beats trying.
- **No new dependencies without a licence row.** Never GPL.
- **Historically grounded.** Any liberty taken is recorded in the driving card's
  `assumption_note`.
