# Slot 5 — Make the Case

> **Renamed 2026-07-28 from "The Bond Vote"**, and the file moved from
> `05-the-bond-vote.md`. The old name described the historical event rather than
> what the player does, and it collided with the real bond votes in the deck —
> the 1932 issue and the failed Coast Range vote that returns via `repeat_card`.
> Those references are history and were deliberately left alone; searching the
> docs for "bond vote" should now only find them.

**Status:** DESIGN for the structure. **The bloc set is withdrawn, not
provisional** — see below. No implementation plan until it is replaced.
**Archetype:** Faction negotiation (The King's Dilemma lineage)
**Cadence:** **Set piece — fires once**, on the bond card
**Priority:** Last. It is the largest and least like the others.

> **Revalidate before implementing.** Written during P2 planning, ahead of the
> README's "immediately before the implementation plan" rule.

---

## Correction: this is the 1932 bond, not 1928

The placeholder's header said 1928. It also said the slot fires on
[Sell the Bonds, Finish the Bore](../../../../content/cards/18_sell_the_bonds_finish_the_bore.md),
whose historical fact is the **1932** issue that restarted the suspended Coast
Range headings, with the Mitchell–Mocho connection following on January 5, 1934.

The card governs. **1932.** Corrected here rather than carried forward, because
a date error in a design doc becomes a date error on screen.

## The dependency question is closed

[chun92/card-framework](https://github.com/chun92/card-framework) is **not
adopted.** What this screen needs is five faction panels, a concession allocator
and a vote tally — none of which requires a drag-and-drop card table. Adopting it
would make this the project's first third-party dependency, with unverified Godot
4.7 compatibility, in exchange for UI work the project already does everywhere
else. Built from scratch.

## Structure

Two rounds of concession allocation, then commitment, then the vote.

1. **Round one — offers.** The player allocates concessions across the blocs.
   Each bloc reacts on a visible three-step scale: *cold / interested / eager*.
2. **Round two — revision.** Having seen the reactions, the player reallocates.
   Concessions are finite; taking one back to give elsewhere is the whole game.
3. **Commitment.** The offer is locked.
4. **The vote.** Blocs vote their true weight, which is now revealed.

**Concessions on the table:** construction jobs, ratepayer protections, district
improvements, conservation concessions, control of contracts.

## How hidden priorities are revealed

**Through reactions in round one, and nowhere else.** Each bloc has *visible
interests* — what it says it wants — and one *hidden priority* that actually
moves its vote. The three-step reaction to each offer is the only channel, and it
is purely informational: no dice, no rolls, no detection.

A player who reads round one well commits well in round two. A player who does
not is guessing, and will find out at the tally. That asymmetry is the game.

## Passing is not winning

**This is the point of the slot, not a garnish.** The player may authorise the
bond and still emerge overcommitted, publicly exposed, or beholden to an ugly
coalition.

**Concessions granted become campaign flags that come due later**, and their
effects run entirely through the existing five metrics — no sixth resource:

| Flag | Comes due as |
|---|---|
| `promised_camp_improvements` | Extra funds per phase for a fixed span |
| `promised_rate_relief` | An outreach-style support action is capped |
| `promised_contract_control` | A later card's better choice is locked out |
| `promised_district_water` | Readiness reduced at completion |

**There is precedent in the tree already.** `pumped_alternative_chosen` works
exactly this way — a flag granted by a choice that adds a per-phase surcharge for
the rest of the campaign. This slot is that pattern, five times over, chosen
under pressure.

**The bluff is against reality, not against the factions.** The player can promise
more than the project can deliver. The bill arrives later as funds they do not
have and support they cannot spend.

## Whether blocs bluff

**Yes, but only by overstating influence** — a bloc may claim it controls more
votes than it does. The player never makes a call-their-bluff roll. The true
weights are revealed at the tally, and a player who read the round-one reactions
carefully could have inferred the overstatement.

This keeps the rejected mechanic rejected. **No challenge/detection.** Coup's
claim–challenge–reveal rhythm depends on a human reading another human; against
NPCs it collapses into a fixed probability wearing a costume, which players decode
in two plays, or into an AI that peeks and cheats. Personality heuristics do not
solve this — they are heuristics over the same probability. Do not reintroduce it.

## Losing the vote

The card already models it: `repeat_card` returns it to the deck and the vote is
attempted again. On a retry the easy concessions are spent, so the second attempt
is a worse bargain — which is both a fair penalty and what a failed campaign
actually costs.

**Never a dead end.** Historically the 1932 bonds passed, and the tunnel cannot
complete without them.

## The five blocs — WITHDRAWN

> **Withdrawn 2026-07-28, and this is the blocking item for the slot.** An
> earlier draft asserted the blocs were "drawn from the actual fight, not
> invented." That could not be established, and two of the five fail outright.
> The list below is kept only so the failure is legible and nobody re-derives it.

| Bloc | Was said to want | Verdict |
|---|---|---|
| **Board of Supervisors** | Deliverability, credit | **Not a voter bloc.** It is the body that authorises the issue, not a constituency whose votes the player buys |
| **Ratepayers** | Rates held down | Plausible, unestablished as an organised bloc |
| **Organised labour** | Jobs, camp conditions | Participation is documented; the platform and any concessions are not |
| **Private power interests** | Limits on municipal power | The public-power conflict is real context; its centrality to *this* 1932 completion measure is not established |
| **Downstream irrigation districts** | Water rights protected | **Remove.** Modesto and Turlock were central to the Raker Act settlement, but they **were not San Francisco voters** and could not vote on a municipal bond |

The dropped-conservation reasoning is superseded along with the rest: by 1932 the
valley fight was indeed settled, but that argued *for* the irrigation districts,
which is the entry that fails hardest.

### Two routes, and the choice is the historian's

1. **Commission the archival work** that establishes each actor's 1932 position
   in its own language, and rebuild the bloc list from what it returns.
2. **Change the mechanic**: instead of bargaining with five institutions, the
   player assembles a case from documented public concerns. This needs no roster
   of counterparties and is the cheaper route if the archival work does not land.

**The design intent survives either way.** Passing the bond while overcommitting
yourself is the point of the slot, and obligations that come due later work
regardless of who the counterparty is. Everything below this section — the two
rounds, the bluff-against-reality, the obligations, the tone standard — is
unaffected by which route is taken. Recorded in
[FOLLOW-UPS.md](../../../FOLLOW-UPS.md).

## Tone

**The most politically charged content in the game, shipping from a public
agency.** These are real institutions with real modern successors.

The design must let the player see why each bloc wanted what it wanted —
**including the opposition** — rather than casting any as the villain. Private
power's position was sincerely held and is why the fight lasted decades; a
version where they are simply the obstacle is both worse history and worse
teaching.

The standard applies with more force here, not less.

## Session length

**Ten minutes is the ceiling, and it binds.** If the design exceeds it, **cut a
round rather than accelerating the writing** — the prose is what makes the blocs
legible as people rather than sliders, and compressing it to save time destroys
the thing the slot exists to do.

## Verification bands

Harder to simulate than the other four, and the third band is the one that
matters:

1. **No dominant opening.** No single round-one allocation may win across all
   hidden-priority permutations. If one exists, the negotiation is a lookup table.
2. **Pass rate in band.** Competent play passes the bond **55–80%** of the time.
   Higher and the set piece is ceremonial; lower and it blocks a campaign the
   history says succeeded.
3. **Overcommitment must bite.** A "promise everything" policy must pass the vote
   and then measurably degrade the campaign in full `sim_test` — later completion,
   lower final metrics, or a loss. **If promising everything is free, the whole
   slot is theatre**, and this band is the one that proves the design's central
   claim.

Plus the standing requirement: campaign `sim_test` still completes with this
minigame skipped entirely — the bond passes on the card's authored choice.

## Inherited rules this slot does not revisit

- Never reads or writes `GameState`. `MinigameConfig` in, `MinigameResult` out.
- Never gates progress.
- Never adds a resource. The obligation flags act through the existing five.
- Result tiers select among the card's authored choices.
- Any historical liberty is recorded in the card's `assumption_note`.
