# Slot 4 — Keep the Line Open

**Status:** PLACEHOLDER. Not ready for implementation.
**Archetype:** Frogger / lane-dodge
**Cadence:** Recurring
**Priority:** Last of the four recurring slots.

> **This is the least-settled slot and is explicitly swappable.** It is in the
> slate because division 1 would otherwise have nothing, not because the
> archetype is load-bearing. The module contract makes replacing it a
> one-folder change. If a better fit for the High Sierra emerges during slots
> 1–3, swap it without ceremony.

## Already decided — do not revisit

- **It covers division 1** (High Sierra) and gives the `railroad_operational`
  flag something to do beyond a build-rate multiplier.
- **Outputs:** crew wellbeing, time.
- **It is the reflex slot.** The other three are deliberation; this one is
  hands.

## Historical anchors

- [Build the Railroad](../../../../content/cards/02_hetch_hetchy_railroad.md) —
  the Hetch Hetchy Railroad itself.
- [Sierra Snows](../../../../content/cards/08_sierra_snows.md) — snowbound
  camps and clearing the line.
- [Six Camps in the Foothills](../../../../content/cards/09_six_camps_in_the_foothills.md)
  — the camps this supply run exists to feed.

## Must be decided

1. **Whether the archetype survives at all.** Answer this first. A lane-dodger
   is the least historically motivated thing on the slate, and "dodge obstacles
   on a train" risks reading as arcade filler bolted onto a serious subject.
   Alternatives worth weighing before committing:
   - A **loading puzzle** — limited car capacity against camp needs. Deliberate
     rather than reflexive, and closer to what the railroad actually solved.
   - A **timing/rhythm run** — one-button, very low friction, high "one more
     go" pull.
   - Keeping the lane-dodger, but framed as clearing the line rather than
     dodging on it.
2. **If it stays:** what is being dodged, and does it survive the tone test?
   Rockslides and drifts, yes. Anything that trivialises a rail worker being
   hurt, no — see the Mitchell Shaft restraint standard.
3. **Its relationship to `railroad_operational`.** Is the slot unavailable
   before the railroad exists, or does it play differently (wagon teams, harder)?
4. **Tier thresholds** and the crew/time payout curve.

## Note on effort

This slot is mostly an art and audio problem rather than a code problem. The
lane-dodger implementation is trivial; what makes it feel like Hetchy Trail
rather than a generic arcade game is entirely presentation. Budget accordingly —
and treat that as further reason to consider swapping it for something whose
mechanic carries more of the meaning on its own.
