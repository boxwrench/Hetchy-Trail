# Hetchy Trail — Minigames & Campaign Restructure: Design Spec

**Date:** 2026-07-27
**Status:** Draft for user review → decomposes into three implementation plans
**Branch context:** `feat/playable-core` (post decision-weight work; supersedes
the deferred "mini-games on event cards" follow-on noted in
[the decision-weight spec](2026-07-06-decision-weight-design.md#deferred-follow-ons)).

## Context: what this game is for

Hetchy Trail is a **showcase piece**, distributed internally among SFPUC staff
and possibly posted to agency social media. Expected play counts are low. Its
job is to demonstrate a concept and inspire creativity in the department — so a
short, striking, shareable experience beats a long, complete one.

Three consequences drive every decision below:

1. **The first three minutes are the product.** Turn 60 is irrelevant; most
   people will play once, briefly, or watch a clip.
2. **The minigame is the artifact.** Nobody shares a screenshot of a resource
   dropdown. The minigame is what reads as a game in a social post.
3. **Accuracy still governs.** The existing teaching-layer discipline
   (`historical_fact`, `historical_source_note`, `assumption_note`) is
   non-negotiable — an agency historian will review the content.

## Problem

The game is architecturally sound and playable end to end, but five specific
defects block "fun," historian review, and parallel art work.

1. **More than half of all turns are empty.** A campaign runs ~70 turns
   (1914→1934, four seasons/year). Content is 15 fixed spine cards, 6 one-shot
   texture cards, and 5 repeatable hazards. Once the texture cards are consumed
   (~turn 20), a `STEADY` season can only be interrupted by a 10% hazard roll
   ([event_manager.gd:25](../../../autoload/event_manager.gd#L25)). The back half
   of the campaign is ~30 consecutive turns of "End season."

2. **The economy has an unbounded loop that disarms four of five loss
   conditions.** Alternating `issue_bond` (+3 funds, −1 support) and `outreach`
   (−1 funds, +2 support) nets **+2 funds and +1 support every two turns**,
   against a winter payroll of only −1/year
   ([game_state.gd:50](../../../autoload/game_state.gd#L50)). Funds grow without
   bound, support and crew pin at their caps, and `_crew_factor()` sits at its
   1.2 maximum. `bond_crisis`, `project_cancelled`, and `work_halted` become
   unreachable; `city_moves_on` reduces to arithmetic. The game becomes
   deterministic and unloseable. `sim_test` does not catch this because
   [sim_test.gd:33](../../../tools/sim_test.gd#L33) plays a conservative
   heuristic, not an exploitative one.

3. **Two metrics do no work.** `water_readiness` is written and displayed but
   read by no rule. `miles_built` only gates card availability; the win
   condition is the eight `SYSTEM_FLAGS`, all granted by fixed cards that fire
   on schedule. The player's most visible feedback signal is disconnected from
   what they are trying to achieve.

4. **`.tres` is unauthorable by a non-technical historian.** Cards require
   `SubResource` blocks, `ExtResource("2")` id references,
   `Array[StringName]([&"flag"])` syntax, and a hand-maintained `load_steps`
   header. A single typo produces a card that `_load_deck()` silently skips.

5. **Art is coupled to card data.** `archival_photo: Texture2D` is a hand-set
   property inside the same file the historian edits, so art work and content
   review collide on the same lines.

## Goals

- Every turn has something in it.
- The player earns progress rather than watching it accrue.
- One low-friction, repeatable, genuinely addictive minigame, in the Oregon
  Trail hunting mould — optional, player-initiated, repeatable, resource-limited,
  and feeding a core metric.
- Content is editable by a historian with no engine knowledge, and validated
  loudly rather than failing silently.
- Art can proceed in parallel with gameplay work, on the same cards, without
  file conflicts.

## Non-goals & invariants (violating one is a failure)

Inherited from [ROADMAP.md](../../ROADMAP.md) and the decision-weight spec:

- **Five metrics only** (funds, public_support, water_readiness, crew_wellbeing,
  time) plus miles + flags. **Never a sixth resource.**
- **All game logic stays in `autoload/` and `resources/`.** Scenes display and
  call methods; they never mutate state directly.
- **Every historical deviation is recorded** in a card's `assumption_note`.
- **Archival images require a row** in
  [assets/art/archival/CREDITS.md](../../../assets/art/archival/CREDITS.md).
- **A failing harness is never committed.**

New for this spec:

- **A player who skips every minigame must still be able to finish the
  campaign.** Minigames are never a gate.
- **No GPL dependencies.** This ships from a government agency; MIT/Apache/BSD
  with an attribution row, or nothing. Licenses are verified from the repo's
  `LICENSE` file at implementation time, not from its description.

## Design

### §1 — Campaign restructure: 70 turns → 24

One turn becomes a **construction phase** rather than a calendar season: six
divisions × four phases = 24 turns. A full playthrough runs 20–30 minutes; a
demo runs five. This eliminates the empty-turn problem structurally rather than
padding it with content.

**Seasons become narrative framing.** Cards may invoke winter, snow, or heat for
drama, and temporal continuity of weather is deliberately loose. This is a
deviation from the record and is recorded as such: every affected card gains a
line in its `assumption_note` to the effect of *"Season is narrative framing;
the campaign advances by construction phase, not calendar quarter."*

Consequences for existing code:

- `_advance_calendar()` ([game_state.gd:229](../../../autoload/game_state.gd#L229))
  advances a phase counter and derives a display year, rather than cycling four
  seasons.
- Winter payroll becomes a **per-phase** overhead so the pumped-line surcharge
  (`PUMPING_SURCHARGE`) keeps its teeth.
- `SNOWBOUND_FACTOR` / `RAILROAD_WINTER_FACTOR` become **division-scoped**
  pressure in the High Sierra rather than calendar-scoped, preserving the
  mechanic that makes the railroad worth building.
- `winter_only` on `EventCard` is replaced by division scoping. The field is
  removed rather than left dangling.
- `completion_grade()` still grades against October 1934.

### §2 — Economy fix

The bond/outreach loop is closed by removing `issue_bond` as a repeatable
per-turn action. Bond authorization becomes the **Make the Case set piece** (§4.5),
which fires once. All other funds come from minigame payouts (§4) and card
choices — there is no longer any repeatable action that generates funds.

`outreach` and `improve_camp` remain, but with **escalating cost** — each use
raises the price of the next, so topping up a meter is a real decision rather
than bookkeeping. This is the same fix the decision-weight spec applied to pace,
extended to the remaining actions.

`sim_test` gains an **exploit probe**: a run that greedily plays the
highest-value action every turn must not produce unbounded funds. This is the
regression guard that would have caught the original defect.

### §3 — The minigame module contract

Every minigame is a self-contained module that **never reads or writes
`GameState`**:

```
MinigameConfig  (in)  →  [ minigame scene ]  →  MinigameResult (out)
```

- `MinigameConfig` carries `minigame_id`, the `event_id` that opened it, a
  `params` dictionary of module-specific inputs (rock hardness, crew stamina,
  target footage, grid size, time limit), and a `seed`.
- `MinigameResult` carries **`score` and `tier`** (`&"poor"` / `&"fair"` /
  `&"strong"`). **Nothing else.**
- `Journey` applies the result; the minigame does not.

> **Corrected 2026-07-28, and this one had teeth.** The result bullet used to end
> "and typed outputs (footage, injuries, funds)". Both halves were wrong.
>
> **Typed outputs break the contract.** The tier selects among the driving card's
> *already authored* choices, so every consequence number is in `content/` where
> the historian owns it. A result that carries its own footage, funds or flags is
> a second, invisible source of consequence data. This same error was live in
> [01-the-heading.md](minigames/01-the-heading.md) as a five-field payload and
> was corrected there; P2 was built to the two-field contract.
>
> **"Injuries" should never have been on that list.** Nothing in this project
> scores harm to people. The deck carries a memorial card for the twelve men lost
> at Mitchell Shaft and states that it is a fixed historical event, not a player
> failure. A minigame that returns an injury count makes people an output
> variable. Hazards cost footage, funds and time — never bodies.

**Result tiers map to authored EventChoices.** Per the architecture call already
made in the decision-weight spec, a minigame's outcome *selects among a card's
existing choices* — skill replaces the button click. All consequence data stays
authored in the card, where the historian can read and edit it, and no sixth
resource appears.

> **Corrected 2026-07-28.** This said `EventCard` gains an optional
> `minigame_id` and a tier→choice-index mapping. **It does not, and should not.**
> That field can only be populated from `content/cards/*.md` front matter through
> `tools/import_cards.gd`, which means editing authored content and the importer
> for a framework change. As built in P2, the binding lives in
> `resources/minigame_registry.gd`, keyed by `event_id` — so the framework can
> land, and be reverted, without touching `content/` at all. Migrating onto the
> card later is easy if the historian wants it; the reverse is not.

Three things fall out of this contract:

- **Arcade mode is nearly free.** The title screen can launch any minigame with
  a default config and discard the result.
- **Minigames are headless-testable** the same way `sim_test` tests the
  campaign — 10,000 simulated Heading rounds can tune the risk curve without
  opening the editor.
- **Swapping a minigame is cheap** — delete a folder, change one registry line.
  Nothing else in the game knows what it was.

### §4 — The five minigames

Four recurring, each owning a stretch of the route so no single one carries 24
turns; plus one set piece. Each is a well-trodden classic with a small
implementation, and each is historically grounded rather than reskinned.

| # | Minigame | Classic DNA | Where | Feeds | Cadence |
|---|---|---|---|---|---|
| 1 | **The Heading** | Risk-managed allocation † | Tunnel divisions 2, 3, 5 | Miles, crew | Recurring |
| 2 | **Probe the Face** | Minesweeper | Precedes a Heading run | De-risks #1, readiness | Recurring |
| 3 | **Forty-Seven Miles** | Pipe Dream / Pipe Mania | Valley + bay divisions 4, 6 | Miles, funds | Recurring |
| 4 | **Keep the Line Open** | Loading / allocation puzzle | High Sierra division 1 | Crew | Recurring |
| 5 | **Make the Case** | The King's Dilemma | Card 18, once | Funds, support, obligations | Set piece |

> † **Slot 1's DNA was "Press-your-luck (Can't Stop)" and that claim is
> withdrawn**, on measurement rather than taste. Set supports makes stress relief
> always cheaper than stopping, so the optimal player banks voluntarily **0.0%**
> of the time; removing supports restores it to 45.2%. Band 3 ("supports must
> earn their place") and band 1's intent cannot both hold with these four
> actions. Supports were kept — they are the Crane Ridge decision in miniature
> and the most historically exact element in the slot — and the genre label was
> given up instead. Full measurement table in
> [01-the-heading.md](minigames/01-the-heading.md).

> **Amended 2026-07-28**, after external research review. Slot 2 was
> *Sound the Rock*; slot 4 was a Frogger-style lane-dodge. Both changed for
> reasons recorded in §4.2 and §4.4. The slot file
> [02-sound-the-rock.md](minigames/02-sound-the-rock.md) keeps its old filename
> until implementation, so the path still resolves.

The slate spans four distinct mental modes — greed/risk, deduction, spatial
planning under time pressure, and allocation. For a showcase where the player
might be an engineer, a comms lead, or someone's kid, a player who bounces off
one will find another.

**The slate no longer contains a reflex mode**, and that is a known cost of the
slot 4 change rather than an oversight. All four recurring minigames are now
deliberative. If playtesting shows the slate needs a hands-on moment, slot 4 is
where it was going to come from, and reopening that is legitimate — but it is a
reason to revisit slot 4, not to add a sixth minigame.

#### §4.1 — The Heading (signature)

Drill, load powder, blast, muck out. Each cycle yields footage and raises the
chance of a bust. Bank the footage or push one more round.

> **Corrected 2026-07-28.** This paragraph used to list the busts as "rockfall,
> squeezing ground, bad air, water inflow". Two of those are invented — there is
> no bad-air or water-inflow hazard card. The bust draws from the **three hazard
> cards already in the deck**: [h1_powder_blast](../../../content/cards/h1_powder_blast.md),
> [h2_rockfall_in_the_heading](../../../content/cards/h2_rockfall_in_the_heading.md),
> and [h3_cave_in](../../../content/cards/h3_cave_in.md). Severity is intrinsic
> to which one occurred, so no severity is invented either.

- **Availability: player-initiated, optional**, whenever the front is in a
  tunnel division. Passive accrual remains as the fallback, so skipping it never
  blocks the campaign — but the Heading yields meaningfully more footage, so
  players want to open it.
- **Crew wellbeing is the ammunition.** Each round costs crew stamina, so
  grinding it has a real price.
- **It gives `miles_built` a job.** Tunnel footage from the minigame adds to
  front progress, so the mile counter becomes something the player actively
  fights for rather than only a readout.

  > **Corrected 2026-07-28.** This bullet used to say footage comes from the
  > minigame *rather than* accruing from a pace multiplier, and that `work_pace`
  > becomes the risk dial *rather than* a multiplier. **Both halves are
  > withdrawn.** `PACE_FACTOR` is live in `autoload/game_state.gd` at
  > REST 0.0 / STEADY 1.0 / PUSHED 1.6 and is applied to front progress every
  > turn; removing it would undo a measured Batch B balance result.
  > `work_pace` does **both** jobs — it keeps multiplying passive front progress
  > **and** it sets the Heading's starting ground stress `S₀`. One dial, two
  > readings, nothing removed. This was a live contradiction with
  > [01-the-heading.md](minigames/01-the-heading.md), which refused the clause;
  > the slot doc was right and this file is now aligned to it.
- Historically anchored in the record already in the deck: the competing
  headings, the 803-foot September of 1926
  ([11_the_803_foot_month.tres](../../../data/events/11_the_803_foot_month.tres)),
  and Crane Ridge's squeezing ground.

**Tuning is the risk.** Press-your-luck lives or dies on whether the stopping
decision is genuinely hard. The two failure modes named here were a dominant
strategy (one stopping point always correct) and a coin flip (no real decision).

> **A third failure mode, found 2026-07-28, which passes both of those tests.**
> The stopping decision may never be *taken* at all. Measured by exact backward
> induction: at the specified starting stamina the optimal policy banks
> voluntarily **0.0%** of the time, because it reaches the target on its last
> usable stamina and so never occupies a state where stopping is correct. No
> single stopping round dominates, and the tier spread is not a coin flip — both
> original tests pass on a slot with no stopping decision in it. Test for this
> directly. Full numbers in [01-the-heading.md](minigames/01-the-heading.md).
This is the one item on the slate requiring design research before
implementation; the research prompt is captured in
[appendix A](#appendix-a--press-your-luck-research-prompt).

#### §4.2 — Probe the Face

Minesweeper, as geological probing. Before driving a heading, crews drilled
probe holes ahead of the face to find fault zones, water-bearing seams, and bad
ground — probe a grid, deduce hazards from partial information, flag them.

> **Renamed 2026-07-28.** This slot was *Sound the Rock*. In period mining usage
> "sounding" means testing roof or rock for loose material, usually by striking
> or barring it — not drilling ahead of a face. Keeping the name would have put
> a terminology error in front of the audience most likely to notice it.
>
> **A second correction, which is a claim boundary rather than a name.** That
> crews at the represented heading drilled a *regular grid* of forward probe
> holes is **not established** by any Hetch Hetchy record reviewed. Difficult
> geology, groundwater, gas and swelling ground are documented
> ([SOURCES.md](../../SOURCES.md), SFPUC 2005 history p. 39); the specific
> forward-probe method, spacing and distance are not. Present this slot as a
> schematic of investigating ground ahead of a heading, not as a recreation of a
> documented shift, and do not invent a feet-ahead figure. See
> [FOLLOW-UPS.md](../../FOLLOW-UPS.md).

Chaining it into the Heading makes both better: survey well and the
press-your-luck round is meaningfully safer. Two easy minigames combining into
one interesting decision beats two isolated toys.

**Implementation gotcha that must be in the plan: boards must be guaranteed
solvable.** Naive mine placement produces positions requiring a guess, which
feels arbitrary and reads as broken. First-click safety plus a solver check at
generation, regenerating when a board would require guessing.

#### §4.3 — Forty-Seven Miles

Pipe Dream: connect the line before the water arrives. Covers divisions 4 and 6,
which have no tunnelling and would otherwise revert to clicking End Season.
Grounded in the existing deck — the 47 miles of steel across the San Joaquin,
the Alameda siphon, and
[12_room_for_four_pipes.tres](../../../data/events/12_room_for_four_pipes.tres).

**Gotchas for the plan:** the flow timer is tuned to grid size, and placed pipe
is overwritable (chosen for forgiveness, since friction is the enemy here).

#### §4.4 — Keep the Line Open

A supply run up the Hetch Hetchy Railroad, in the High Sierra. There is less
haulage than the camps need, and the player decides what goes up and who goes
short. Feeds crew wellbeing, and gives division 1 and the `railroad_operational`
flag something to do.

> **Archetype changed 2026-07-28.** This was a Frogger-style lane-dodge. The
> spec itself called it the least-settled item and explicitly swappable, and it
> was swapped: it was the least historically motivated thing on the slate, it
> read as arcade filler on a serious subject, and the spec's own note that it was
> "mostly an art and audio problem" meant most of the effort bought presentation
> rather than meaning. The module contract (§3) made this the one-folder change
> it was advertised to be.
>
> **Time is no longer an output.** The overrun-pressure measurement showed the
> campaign's time economy is delicate; handing out phases from an optional
> minigame would require re-measuring the whole balance pass to justify.

**The premise is not settled and must not be built on as written.** The natural
design — near camps have wagon-road fallback, far camps have only the railroad,
so spending the haulage budget where it is cheapest is the wrong answer — is
**contradicted by our own deck**.
[02_hetch_hetchy_railroad.md](../../../content/cards/02_hetch_hetchy_railroad.md)
has the railroad running in winter "when mountain roads could be blocked by
snow," and
[09_six_camps_in_the_foothills.md](../../../content/cards/09_six_camps_in_the_foothills.md)
has city crews installing roads to the camps. Neither supports a camp-by-camp
fallback hierarchy.

**This slot needs a new source of tension before an implementation plan is
written against it.** Recorded in [FOLLOW-UPS.md](../../FOLLOW-UPS.md).

**Cargo, when it is rebuilt.** Use what the card already documents — cement,
equipment, workers and supplies. An earlier draft used food, timber, powder and
coal; coal is actively wrong, since the surviving locomotive documentation
describes a fuel-oil tank, and the project ran its own sawmills, which makes
imported timber a poor generic cargo.

#### §4.5 — Make the Case (set piece)

Fires **once**, at the **1932** bond — which is already
[18_sell_the_bonds_finish_the_bore.tres](../../../data/events/18_sell_the_bonds_finish_the_bore.tres).

> **Corrected 2026-07-28.** This section said 1928. The card is the **3 May 1932
> issue, $6.5 million, to complete the last five miles of the Coast Range
> Tunnel** — confirmed in the SFPUC 2005 history, p. 42, which lists all seven
> Hetch Hetchy bond issues. There *was* a $24 million issue in 1928, so the old
> date was a real bond, just not this card's. A date error in a design doc
> becomes a date error on screen.

Structure, taken from The King's Dilemma: blocs enter with visible interests and
hidden priorities. Over **two rounds** the player allocates limited concessions
— construction jobs, ratepayer protections, district improvements, conservation
concessions, control of contracts — then everyone commits and the returns come
in.

> **The bloc model is unsupported and must not be built as written.** This
> section previously asserted that "the blocs are drawn from the actual fight,
> not invented." External research could not establish that structure for this
> vote, and two of the named candidates fail outright:
>
> - **Downstream irrigation districts — remove.** Modesto and Turlock were
>   central to downstream water rights and the Raker Act settlement, but **they
>   were not San Francisco voters** and could not vote on a municipal bond.
> - **Board of Supervisors — not a voter bloc.** It is the governing body that
>   authorises the issue, not a constituency whose votes the player buys.
> - **Private power interests** — the long-running public-power conflict is real
>   context, but its centrality to *this* 1932 completion measure is not
>   established.
> - **Organised labour** — participation is documented; the platform and any
>   concessions are not.
>
> Two defensible routes, to be settled with the historian before implementation:
> either commission the archival work that establishes each actor's 1932
> position in its own language, or change the mechanic from bargaining with five
> institutions to assembling a case from documented public concerns. Recorded in
> [FOLLOW-UPS.md](../../FOLLOW-UPS.md).
>
> **The design intent survives either way.** Passing the bond while
> overcommitting yourself is the point of the slot, and obligations that come due
> later work regardless of who the counterparty is.

**Two deliberate departures from the reference material:**

- **No challenge/detection mechanic.** Coup's claim-challenge-reveal rhythm
  depends on a human reading another human. Against NPCs it collapses into
  either a fixed challenge probability — a dice roll wearing a costume, which
  players decode in two plays — or an AI that peeks at hidden state and cheats.
  Personality heuristics do not solve this; they are heuristics over the same
  probability.
- **The bluff is against reality, not against the factions.** The player can
  promise more than they can deliver, and the bill arrives later in the campaign
  as funds they do not have and support they cannot spend. This works in
  single-player, is more historically honest, and preserves the intended drama.

**Passing is not the same as winning.** The player may authorize the bond and
still emerge overcommitted, publicly exposed, or beholden to an ugly coalition.
Those obligations are granted as campaign flags and come due in later phases.
This is the mechanic that gives the set piece teeth.

**Dependency note:** [chun92/card-framework](https://github.com/chun92/card-framework)
(MIT, Godot 4) is a candidate for the UI but is **not designed around**. What
this screen needs is five faction panels, a concession allocator, and a vote
tally — none of which requires a drag-and-drop card table. It would also be the
project's first third-party dependency, with unverified Godot 4.7
compatibility. Evaluate during implementation; do not commit now.

### §5 — Water readiness as build quality  ✅ DECIDED

`water_readiness` becomes the score for *how well* the aqueduct was built, fed
by minigame performance. It is the only metric the player is trying to
**maximize** — every other one is a constraint they are avoiding failing, or a
schedule they are racing. A showcase piece needs something to be good at, and
the design currently has nothing.

**The mechanic, in three parts:**

1. **Completing a division grants a readiness floor.** You built it; it works.
   This happens whether or not the player touched a minigame.
2. **Minigame performance adds on top of that floor.** Strong play raises
   readiness; poor play simply does not raise it. **Failing a minigame never
   subtracts** — otherwise skipping would beat trying, which inverts the point.
3. **The ending reads two axes** — completion date against October 1934, and
   readiness against `READINESS_TARGET`.

`completion_grade()` currently returns a single ahead/matched/behind value.
Crossed with three readiness bands it becomes a nine-cell ending matrix, and the
off-diagonal cells are the interesting ones: *fast but fragile*, *late but built
to last*. That is a better conversation for staff who know this system than a
binary finish.

The invariant holds: a player who skips every minigame still finishes and still
earns a legitimate ending — "the system works" rather than "built to last."

**Balance trap to watch in P3:** if the division floor is set too low, skipping
minigames reads as punished rather than merely unrewarded. The floor must be
generous enough that skipping is a valid, unglamorous way to play.

It is also the historically honest measure. Hetch Hetchy's reputation does not
rest on finishing in 1934; it rests on still delivering water by gravity ninety
years later. A game that grades only the date measures the wrong achievement.

### §5a — Stub-first minigame delivery

**The constraint this solves:** implementation is executed by a weak worker
model under review. A weak model can implement a fully-specified module
reliably; it cannot design one. But specifying all five minigames now would be
speculative — four would be rewritten once The Heading teaches us what the
contract actually needs.

**Therefore: every minigame ships as a stub first.** A stub is a screen that
presents the card's context and a single Resolve button, and returns a valid
`MinigameResult` with `tier = &"fair"`. Play is identical to today's button
click. The five stubs are near-identical, so a weak worker can produce them
mechanically from one worked example.

This gives four properties worth having:

- **The game is complete and playable at every point.** There is never a broken
  or half-wired minigame slot.
- **The contract gets exercised five times before any real minigame is built**,
  so contract defects surface early and cheaply.
- **Art and content can target real slots** immediately, in parallel.
- **Design happens just-in-time.** Each stub is replaced by a real minigame one
  at a time, in any order, and any one can be dropped without disturbing the
  others.

**Process for replacing a stub:** a strong model writes a short per-minigame
design spec in `docs/superpowers/specs/minigames/`, then an implementation plan
in the same explicit style as P1, then the weak worker executes it under review.
Placeholder specs for all five live there already, each recording what is
already decided and what a designer must still decide.

**The Heading goes first** because it is the hardest case — press-your-luck
tuning is the one genuinely uncertain item on the slate. If the contract is
going to be wrong, that is where it shows.

### §6 — Historian-editable content pipeline

Card content moves out of `.tres` into a format with **no engine syntax in it** —
one row per card, all prose and plain values, editable in a spreadsheet or text
editor. A build step generates the `.tres` resources.

Requirements:

- **Fails loudly.** An unknown flag, a missing choice, a bad tier mapping, or a
  malformed row halts the import with a message naming the file and row. The
  current silent-skip behaviour in `_load_deck()` is the defect being fixed.
- **Round-trips.** Existing authored cards export to the new format without
  content loss, so no historical text is retyped.
- **Validated in the harness.** `smoke_test` asserts every card has non-empty
  `historical_fact` and `assumption_note`, and that every referenced flag exists
  in `SYSTEM_FLAGS` or a known set.

The historian's review loop becomes: edit the sheet, run one command, play.

### §7 — Art decoupling

`archival_photo` is removed as a hand-set property. Card art resolves **by
convention** from `event_id`:

```
assets/art/cards/<event_id>.png        → archival or final art
assets/art/cards/<event_id>.placeholder.png → generated stand-in
```

Missing art falls back to a neutral placeholder rather than an empty panel.

This makes art and content fully parallel: images are added by dropping files in
a folder, touching nothing the historian is editing. The art direction, palette,
duotone treatment, and generation recipe in
[docs/art_assets.md](../../art_assets.md) are unchanged and remain correct —
only the wiring changes.

The CREDITS discipline is unchanged and extends to a new `CREDITS.md` for code
and audio dependencies alongside the archival one.

### §8 — Testing

- **`smoke_test`:** card-count check updated; new assertions for the content
  pipeline (§6) and for every minigame module conforming to the result contract.
- **`sim_test`:** the canonical run still finishes ≤1940 with all minigames
  skipped — the "minigames are never a gate" guard. Plus the **exploit probe**
  (§2) asserting a greedy action policy cannot produce unbounded funds.
- **New `minigame_sim`:** runs each minigame headless across many seeded trials
  and asserts the outcome distribution sits in band — specifically that The
  Heading has no dominant stopping point and is not a coin flip. This is the
  guard for the one genuinely uncertain design item.
- **`layout_test`:** extended to the minigame screens and the arcade-mode entry.

## Sequencing

This is too large for one implementation plan. It decomposes into three, in
dependency order:

| Plan | Scope | Why first / why here |
|---|---|---|
| **P1 — Foundations** | §1 restructure, §2 economy fix, §6 content pipeline, §7 art decoupling | Unblocks the historian and the art track immediately, and none of it depends on minigame design. Ships value before any minigame exists. |
| **P2 — Minigame framework + The Heading** | §3 contract, §4.1, arcade mode, `minigame_sim` | Proves the contract on the hardest case. If the press-your-luck tuning does not land, that is discovered here, cheaply, before four more are built. |
| **P3 — The remaining four** | §4.2, §4.3, §4.4, §4.5, §5 | Each is independent once the contract holds; can be built in any order or dropped without disturbing the others. |

P1 delivers the two things the user asked to run in parallel — historian review
and art production — before any minigame work begins.

## Open decisions

1. **Press-your-luck tuning parameters (§4.1)** are set by the research in
   appendix A plus the `minigame_sim` band-check. Not blocking P1 or the
   framework half of P2.
2. **Per-minigame design** is deliberately deferred under §5a. Each stub's
   replacement spec is written just before its implementation plan, not now.

**Resolved:** §5 (water readiness as build quality) — confirmed 2026-07-27.

## Appendix A — Press-your-luck research prompt

Captured here so the tuning research is reproducible and its results land in the
same place as the design.

> I'm designing a press-your-luck minigame for a historical game about building
> the Hetch Hetchy aqueduct (1914–1934). The player runs a drill-and-blast
> tunnel heading: each cycle they drill, load powder, blast, and muck out,
> gaining footage. Each cycle raises the chance of a bust (rockfall, squeezing
> ground, bad air, water inflow). The player chooses when to bank their footage
> and end the shift.
>
> Give me:
>
> 1. **Press-your-luck design references.** The canonical designs and what each
>    solved. Cover at minimum Can't Stop, Deep Sea Adventure, Incan
>    Gold/Diamant, Quacks of Quedlinburg, and the Balatro/Slay the Spire "one
>    more round" loop. For each: what is the bust condition, what is the bank
>    decision, and what specifically makes the player want one more turn instead
>    of stopping?
> 2. **The tuning math.** How do these games shape the risk curve so the optimal
>    stopping point is non-obvious? Is risk linear, escalating, or stepped? How
>    is expected value arranged so stopping early feels bad and pushing far
>    feels earned rather than arbitrary? Good bust-probability range per round?
>    How do you avoid a dominant strategy and avoid pure coin-flip randomness?
> 3. **Partial loss vs total loss.** Games where busting costs some of your
>    gains rather than all. What does that change about how aggressively players
>    push, and when is each better?
> 4. **Mining and tunnelling games.** Motherload, SteamWorld Dig, Dome Keeper,
>    anything older. What makes digging satisfying moment to moment? What
>    feedback (sound, shake, reveal, accumulation) is essential vs decorative?
> 5. **Historical accuracy.** The actual drill-blast-muck cycle in 1920s
>    hard-rock tunnelling — round length, crew roles, timbering decisions, real
>    hazards — and which are dramatic enough to be a bust condition.
>
> For each reference, note its license if open source, and flag anything GPL.

## Appendix B — Reference & dependency register

| Item | Use | License | Status |
|---|---|---|---|
| Can't Stop (Sackson, 1980) | Design reference for §4.1 | n/a — mechanics are not copyrightable | Read, do not copy |
| The King's Dilemma | Design reference for §4.5 | n/a — mechanics | Read, do not copy |
| [8tp/Coup](https://github.com/8tp/Coup) | Referenced for bot architecture; **challenge mechanic rejected** (§4.5) | MIT (verify `LICENSE` before use) | Not adopted |
| [chun92/card-framework](https://github.com/chun92/card-framework) | Candidate UI addon for §4.5 | MIT (verify; Godot 4.7 compat unverified) | Deferred — evaluate at implementation |
| Kenney.nl / freesound | Audio (drill, blast, muck cart) | CC0 | Candidate |
| SIL OFL faces | Typography per [art_assets.md](../../art_assets.md) | OFL | Candidate |

**Rule:** game mechanics are not copyrightable and may be borrowed freely with
no attribution obligation. Code and assets carry licenses; MIT/Apache/BSD with a
credits row, or nothing. **No GPL** — it would obligate licensing the whole game
GPL, which is not a conversation worth having over a minigame.
