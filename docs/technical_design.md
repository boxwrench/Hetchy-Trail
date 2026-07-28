# Hetchy Trail — Technical Design (v2)

> **Agents: this document describes the system as built.** If it contradicts
> the code, the code is right and this file is a bug — report it rather than
> changing code to match. Last reconciled against the tree: 2026-07-27,
> P1.5 Task 2.

A 2D historical resource-management journey for Godot 4.7: build the 167-mile
Hetch Hetchy aqueduct from the Sierra Nevada to San Francisco (1914–1934),
balancing five metrics — Funds/Bonds, Public Support, Water Readiness, Crew
Wellbeing, and Time/Phase.

Hetchy Trail is a **teaching game**. Gameplay may deviate from the historical
record for the sake of play, but every deviation is recorded: each encounter
card carries the historical fact behind it, a source note, and an assumption
note. The historical grounding comes from
`docs/Hetchy Trail Historical Game Mapping.pdf` (the "mapping brief"), built
from SFPUC historical materials.

Tone target: readable, modest, warm. Every system below serves the five meters
and the mile counter. Nothing else is simulated.

> **v2 changes** (from the mapping brief): Water Balance became Water
> Readiness with a campaign-flag completion rule; the turn became one construction phase;
> the event system gained fixed historical cards alongside weighted draws; the
> map became six sections that light up rather than a marker that crawls west.

---

## I. Architecture Pillars

1. **GameState singleton (autoload).** The single source of truth:
   [game_state.gd](../autoload/game_state.gd). It holds the five metrics, the
   calendar, the construction front, and the campaign flags. It only does math
   and emits signals; it never touches UI.
2. **Custom Resources for data.** Events and route segments are `.tres` files
   extending [event_card.gd](../resources/event_card.gd),
   [event_choice.gd](../resources/event_choice.gd), and
   [route_segment.gd](../resources/route_segment.gd). Narrative and history are
   authored in the Inspector, not the scene tree.
3. **Signal-driven UI.** The HUD and Map connect to GameState signals
   (`funds_changed`, `flag_granted`, …) and never mutate state directly.

Both autoloads are registered in [project.godot](../project.godot).

---

## II. Historical Structure

Per the mapping brief, the game plays as **the construction of an
interconnected system**, not a literal wagon journey. Construction did not
occur in geographical order: the Bay Crossing pipeline carried local Spring
Valley water in 1925 while the Sierra divisions were incomplete. The player's
objective is to connect all independently built sections into one continuous
gravity system, historically achieved on October 24, 1934.

The 0–167 mile alignment is **game-design stationing** (rounded component
lengths), not survey stations. `miles_built` represents the overall
construction front and paces card availability; the completion flags — not the
mile counter — decide when the system works.

### The six divisions (`data/segments/*.tres`)

| Phase | Miles | Historical geography | Years | Build modifier |
|---|---|---|---|---|
| 1. High Sierra Access and Dam | 0–12 | Hetch Hetchy Valley to Early Intake | 1914–1923 | 0.8, winter-sensitive |
| 2. Mountain Tunnel and Moccasin | 12–33 | Early Intake to Priest and Moccasin | 1917–1925 | 0.7, winter-sensitive |
| 3. Western Foothills | 33–49 | Moccasin to Oakdale Portal | 1925–1929 | 0.8, winter-sensitive |
| 4. San Joaquin Valley | 49–97 | Oakdale Portal to Tesla Portal | 1931–1932 | 1.6 |
| 5. Coast Range | 97–126 | Tesla Portal to Alameda Creek and Irvington | 1927–1934 | 0.45 |
| 6. Bay and Peninsula | 126–167 | Irvington, Bay Crossing, Pulgas, Crystal Springs | 1922–1934 | 1.2 |

Each segment carries a `completion_flag`; the map lights the segment when the
flag is granted.

---

## III. The Five Metrics

All five are owned by GameState. Scales follow the brief's five-point impact
model: card deltas run roughly −3…+3 (1 minor, 2 substantial, 3 severe).

| Metric | Field | Scale | Meaning | Modified by |
|---|---|---|---|---|
| Funds/Bonds | `funds` | int, starts 30, no cap | Cash, bond authority, contracts, land, equipment | `PHASE_OVERHEAD` charged every phase, bond/outreach/camp actions, card effects. `issue_bond` is capped at `MAX_BOND_ISSUES` (2) at `BOND_FUNDS_GAIN` (20). `outreach` and `improve_camp` escalate via `action_cost()`. |
| Public Support | `public_support` | 0–10, starts 6 | Voter confidence and willingness to approve bonds | Bond and outreach actions, card effects |
| Water Readiness | `water_readiness` | 0 → ~30 target | **System readiness and future capacity — not delivered water.** Completed structures raise it; nothing is delivered until the system is connected. | Card effects only |
| Crew Wellbeing | `crew_wellbeing` | 0–10, starts 7 | Safety, fatigue, housing, morale, retention | Work pace drift, camp action, card effects |
| Time/Phase | `turn` / `phase` | 1914 onward | One turn = one construction phase. `GameState.turn` counts player decisions against `TURNS_TOTAL` (24). `GameState.phase` counts calendar time. `current_year()` derives the year from `phase` and `CALENDAR_PHASES` (30). Seasons are narrative framing in card prose only; the game does not simulate weather. | `advance_turn()` and card `time_delta_seasons` |

Progress (`miles_built`, 0–167) is the sixth owned value but not a player
meter: it moves only inside `_build_miles()` (pace × segment modifier × crew
factor; Sierra divisions build at `NO_RAILROAD_FACTOR` until `railroad_operational` — division-scoped, not calendar-scoped).

### The water model and the completion rule

Water Readiness accumulates from completed structures. Delivered Hetch Hetchy
water requires **all** of these campaign flags, each granted by a fixed
historical card:

```
dam_complete, mountain_tunnel_complete, foothill_tunnel_complete,
san_joaquin_pipeline_complete, coast_range_tunnel_complete,
alameda_siphon_complete, bay_crossing_complete, pulgas_connected
```

This makes the final Pulgas encounter mechanically meaningful: every structure
may be complete, but the city receives nothing until the chain functions as
one system. The urgency the old draining water-clock provided now lives where
it historically lived: funds pressure, `PHASE_OVERHEAD`, and Depression-era
funding events.

### Campaign flags

Flags are a `Dictionary` set on GameState (`grant_flag`, `has_flag`,
`flag_granted` signal). Beyond the eight system flags above, the deck uses:

`high_sierra_access_complete`, `railroad_operational`,
`construction_power_available`, `moccasin_power_available`,
`foothill_camps_established`, `row_acquired`, `row_expansion_secured`,
`coast_range_committed`, `gravity_tunnel_chosen` /
`pumped_alternative_chosen`, `mitchell_memorial_observed`,
`hetch_hetchy_water_delivered` (the win flag).

The brief's "permanent Expansion Capacity +2" is deliberately **not** a sixth
resource: it is the `row_expansion_secured` flag, acknowledged in the end
summary.

---

## IV. The Core Loop

One turn = one construction phase, starting 1914. `GameState.turn` counts player
decisions against `TURNS_TOTAL` (24). `GameState.phase` counts calendar time.
`current_year()` derives the year from `phase` and `CALENDAR_PHASES` (30). The
win screen grades the finish against 1934 (`completion_grade()`: ahead of /
matched / behind history). Hard loss only at 1940 — a warm grade beats a harsh
clock in a teaching game.

Each turn, Journey runs four phases:

1. **DECIDE** — the player sets a work pace (Rest / Steady / Pushed) and may
   take one action: issue a bond (capped at `MAX_BOND_ISSUES` = 2, +20 funds, -1 support),
   community outreach, or improve the camps (costs escalate via `action_cost()`).
2. **RESOLVE** — `GameState.advance_turn()`: miles build, crew drifts with
   pace, `PHASE_OVERHEAD` charged every phase (plus a surcharge if the pumped Coast
   Range alternative was chosen), the calendar advances.
3. **EVENT** — `EventManager.try_draw_queue() -> Array[EventCard]`. Returns 0–2
   cards, hazard first. The pace-risk roll runs **every** turn. Fixed cards due
   this turn fire in order; otherwise a weighted random draw may occur. The player
   picks a choice; `resolve_choice()` applies it through `GameState.apply_choice()`.
4. **CHECK** — end conditions, then the next turn.

Card time effects: positive `time_delta_seasons` advances the calendar with
payroll but no construction; negative deltas bank immediate bonus mileage
(schedule gained).

**Win:** `hetch_hetchy_water_delivered` (granted only by the Pulgas card,
which requires the other seven system flags).
**Losses:** funds below zero (bond crisis), support at zero (project
cancelled), crew at zero (work halts), or the year passing 1940 (the city
moves on). Each maps to exactly one meter.

---

## V. The Event System

### Two draw modes

- **Fixed cards** are the campaign spine — 15 of the 26 cards. As soon as a
  fixed card's mile and flag conditions are met, it fires automatically (one
  card per turn), in filename order. The brief is explicit that Mitchell Shaft
  must be a fixed historical event, never a random draw or a preventable
  player failure; the same mechanism guarantees every division-completion
  card appears.
- **Weighted cards** are texture: railroad, excursions, Sierra snows, Red
  Mountain Bar, the San Joaquin river crossing, Crane Ridge. Each turn without
  a due fixed card, there is an `event_chance` (0.6) roll for one weighted
  draw among available, undrawn cards.

Every card fires once, except when a resolved choice sets `repeat_card` — used
by the failed Coast Range bond vote, which returns to the deck because the
tunnel cannot complete without it (deadlock-proof by construction: every flag
a fixed card requires is granted by another fixed card).

### The teaching layer

Every card carries `historical_fact` (shown to the player as "What really
happened"), `historical_source_note`, and `assumption_note` — the running
register of where gameplay deviates from the record. Current deliberate
deviations, all noted on the cards themselves:

- The Bay Crossing (1925) and Pulgas Tunnel (1922–24) predate the mile-order
  the game presents; card years and text preserve the real chronology.
- "Sierra Snows" is gameplay-derived (no single documented incident) so the
  railroad decision has a visible consequence; the underlying condition is
  historical.
- Multi-card deferred bonuses from the brief are consolidated into immediate
  deltas or flags.
- All resource values are balancing numbers, not historical measurements
  (brief, section 5).
- The 1934 completion scene must depict the temporary ceremonial structure,
  not the permanent Pulgas Water Temple (completed 1938).

Card art resolves by filename convention — `assets/art/cards/<event_id>.png`,
falling back to `<event_id>.placeholder.png` — via `EventCard.art_path()` and
`load_art()`. Stored texture properties are removed, so art and card text never
collide in the same file. SFPUC archival originals live in
`assets/art/archival/` and must be listed in `CREDITS.md` there.

### Chronological milestones

The brief's year-by-year table (section 6: 1914 roads begin … October 28, 1934
celebration) is reserved for loading screens and the end-of-game summary — it
is presentation data, not a system.

---

## VI. System Components

### GameState — the single source of truth
- **[Node Type]** Autoload `Node` — [autoload/game_state.gd](../autoload/game_state.gd).
- **[Script Purpose]** Owns the five metrics, miles, calendar, and flags.
  Public surface: `advance_turn()`, `take_action(action)`,
  `apply_choice(choice)`, `grant_flag/has_flag`, `is_system_connected()`,
  `current_segment()`, `completion_grade()`, `new_game()`.
- **[Core Variables]** `funds`, `public_support`, `water_readiness`,
  `crew_wellbeing`, `miles_built`, `turn`, `phase`, `work_pace`, `flags`,
  `segments`. All balance numbers are named tuning constants at the top of the
  file.
- **[Key Interactions]** Loads `data/segments/`; emits one signal per metric
  plus `flag_granted`, `turn_advanced`, `game_ended`.

### EventManager — the deck of history
- **[Node Type]** Autoload `Node` — [autoload/event_manager.gd](../autoload/event_manager.gd).
- **[Script Purpose]** Loads `data/events/` (filename order = fixed-card
  firing order), fires due fixed cards, performs weighted draws, and applies
  resolved choices through GameState.
- **[Core Variables]** `deck`, `drawn_ids`, `event_chance`.
- **[Key Interactions]** `try_draw_queue()` called by Journey each EVENT phase;
  emits `event_drawn(card)`; `resolve_choice(card, index)` applies the pick
  and re-arms `repeat_card` choices.

### EventCard / EventChoice — narrative as data
- **[Node Type]** `Resource` scripts; 26 cards: 15 fixed spine, 6 texture, 5 hazards.
  Authored as Markdown in `content/cards/`; `import_cards.gd` generates the `.tres`.
- **[Script Purpose]** One historical encounter with 1–3 choices and the full
  teaching layer. Choices carry the five deltas, granted flags, and
  `repeat_card`. `EventCard.is_available(miles, flags)` implements mile gating,
  expiry, and flag requirements.
- **[Key Interactions]** Read only by EventManager; effects can only touch the
  five metrics and flags — a structural guard against scope creep.

### RouteSegment — the 167 miles as data
- **[Node Type]** `Resource` script; six `.tres` instances in `data/segments/`.
- **[Core Variables]** `segment_name`, `phase_id`, `start_mile`, `end_mile`,
  `year_start/end`, `build_rate_modifier`, `winter_sensitive`,
  `completion_flag`, `blurb`.
- **[Key Interactions]** GameState uses the modifier and winter flag for build
  math; Map draws and lights segments.

### Scenes

HUD, DecisionPanel, EventPanel and Journey exist. The route map, title screen and
end screen do not.

- **Main** (`scenes/main/`) — root `Node`, swaps title / journey / end
  screens; listens to `game_ended`; new game = `GameState.new_game()` +
  `EventManager.reset()`.
- **Journey** (`scenes/journey/`) — `Node2D` turn conductor running
  DECIDE → RESOLVE → EVENT → CHECK; the only caller of `advance_turn()` and
  `try_draw_queue()`.
- **Map** (`scenes/map/`) — `Node2D` drawing the six divisions as a route
  line; each segment lights when its `completion_flag` is granted (listens to
  `flag_granted`), with a subtle front marker driven by `miles_changed`. The
  full line "flows" on `is_system_connected()`.
- **HUD** (`scenes/ui/hud.tscn`) — `CanvasLayer` with five readouts (readiness
  displayed as `n / 30` with a "not yet delivered" treatment until
  connection), year, and miles.
- **DecisionPanel** (`scenes/ui/`) — pace selector + three action buttons;
  emits `decisions_confirmed(pace, action)`; disables unaffordable actions by
  reading GameState.
- **EventPanel** (`scenes/ui/`) — letterpress-style card: title, card art (resolved
  by convention via `load_art()`), description, choice buttons, and the expandable
  "What really happened" section (`historical_fact` + notes).

---

## VII. Repository Layout

```
Hetchy-Trail/
├── project.godot                  # autoloads registered; Godot extends on save
├── README.md
├── .gitignore                     # ignores .godot/ editor cache
├── autoload/
│   ├── game_state.gd              # five metrics, calendar, flags, build math
│   └── event_manager.gd           # fixed + weighted card draws
├── resources/
│   ├── event_card.gd              # class_name EventCard
│   ├── event_choice.gd            # class_name EventChoice
│   └── route_segment.gd           # class_name RouteSegment
├── data/
│   ├── events/                    # 26 encounter cards (15 fixed spine, 6 texture, 5 hazards)
│   └── segments/                  # the six divisions, 01–06
├── scenes/
│   ├── main/  journey/  map/  ui/ # to be built in the editor (Section VI)
├── assets/
│   ├── art/
│   │   └── archival/CREDITS.md    # SFPUC images + mandatory credit rows
│   ├── audio/
│   └── fonts/
└── docs/
    ├── technical_design.md        # this document
    └── Hetchy Trail Historical Game Mapping.pdf   # the research brief
```

## VIII. Assumptions and Open Items

- **Assumption:** Godot 4.7 keeps 4.x autoload, typed-array, and custom
  `Resource` semantics (stable core APIs).
- **Assumption:** the hand-written `.tres` files match Godot's text-resource
  serialization (notably `Array[StringName]([...])` and
  `Array[ExtResource(...)]([...])` for typed arrays). No Godot binary was
  available to validate; verify on first editor open — if the editor reports
  parse errors, the fix is a single mechanical find/replace across the deck,
  and re-saving any file in the Inspector normalizes it.
- Balance constants (build rates, start values, `event_chance`, action costs)
  are first-pass numbers chosen so a steady game lands near 1934; expect to
  tune after the first playable loop.
- Next build steps, in order: Journey scene with placeholder UI → HUD →
  EventPanel with the teaching layer → Map → Main/menu/end screens.
