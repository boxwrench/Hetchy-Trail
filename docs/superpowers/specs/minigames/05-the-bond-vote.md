# Slot 5 — The Bond Vote

**Status:** PLACEHOLDER. Not ready for implementation.
**Archetype:** The King's Dilemma (faction negotiation)
**Cadence:** **Set piece — fires once**, at the 1928 bond
**Priority:** Last. It is the largest and least like the others.

## Already decided — do not revisit

- **It fires once**, on
  [Sell the Bonds, Finish the Bore](../../../../content/cards/18_sell_the_bonds_finish_the_bore.md).
  Not recurring. At ten minutes a session, three or four firings would consume
  most of a 24-phase campaign.
- **Two rounds of concession allocation**, then commitment, then returns.
- **Five blocs with visible interests and hidden priorities.**
- **Concessions on the table:** construction jobs, ratepayer protections,
  district improvements, conservation concessions, control of contracts.
- **Passing is not winning.** The player may authorise the bond and still emerge
  overcommitted, publicly exposed, or beholden to an ugly coalition. Obligations
  are granted as campaign flags and come due in later phases. **This is the
  mechanic that gives the set piece teeth — it is the point of the slot, not a
  garnish.**
- **The bluff is against reality, not against the factions.** The player can
  promise more than they can deliver; the bill arrives later as funds they do
  not have and support they cannot spend.

## Explicitly rejected — do not reintroduce

**No challenge/detection mechanic.** Coup's claim-challenge-reveal rhythm
depends on a human reading another human. Against NPCs it collapses into either
a fixed challenge probability — a dice roll wearing a costume, which players
decode in two plays — or an AI that peeks at hidden state and cheats.
Personality heuristics (Conservative / Aggressive / Deceptive / Analytical) do
not solve this; they are heuristics over the same probability.

## Must be decided

1. **Which five blocs**, chosen with historian input from: the Board of
   Supervisors, ratepayers, organised labour, the conservation opposition, the
   downstream irrigation districts, and the private power interests. The last is
   the strongest candidate — its conflict with the Raker Act's public-power
   requirement shaped the project for decades and is the part of this history
   most SFPUC staff will recognise.
2. **How hidden priorities are revealed.** Entirely hidden until the vote is
   opaque and unsatisfying; fully visible is not a game. Partial signalling
   through the negotiation rounds is the likely answer, but the exact channel
   needs designing.
3. **How overcommitment is represented** — which flags, coming due when, costing
   what. This is the highest-value question in the slot and deserves the most
   care.
4. **What losing the vote does.** The historical bond passed. A failed vote must
   not dead-end the campaign; most likely it retries at a worse price, which the
   existing card already models via `repeat_card`.
5. **Whether NPC blocs bluff.** Permitted only if it does not resurrect the
   rejected detection mechanic — i.e. a bloc may overstate its influence, but
   the player never makes a call-their-bluff roll.
6. **Session length ceiling.** Ten minutes is the working target. If the design
   exceeds it, cut a round rather than accelerating the writing.

## Dependency question

[chun92/card-framework](https://github.com/chun92/card-framework) (MIT, Godot 4)
is a **candidate, not a commitment**. What this screen needs is five faction
panels, a concession allocator, and a vote tally — none of which requires a
drag-and-drop card table. It would also be the project's first third-party
dependency, with unverified Godot 4.7 compatibility.

Evaluate it against a from-scratch UI when this slot is designed. If adopted,
verify the `LICENSE` file directly and add a credits row.

## Tone requirement

This is the most politically charged content in the game, and it ships from a
public agency. The blocs are real institutions with real modern successors. The
design must let the player see why each bloc wanted what it wanted — including
the opposition — rather than casting any of them as the villain. The teaching
layer standard applies with more force here, not less.
