# Overrun Pressure — Implementation Plan

> **For agentic workers:** Steps use checkbox (`- [ ]`) syntax. Do steps **in
> order**. Never skip a verification step. Tick a box only after running its
> verification and seeing the expected output.

**Goal:** Make October 1934 a binding project milestone rather than a score.
Passing it begins escalating financial and political pressure that arrives at
the existing loss conditions on its own. 1940 stays the hard backstop.

**Design:** [overrun pressure spec](../specs/2026-07-28-overrun-pressure-design.md).

**Architecture:** All pressure lands in `GameState._advance_calendar()`, which
is already called both by `advance_turn()` and by `apply_choice()` for positive
`time_delta_seasons`. That is the whole point: a two-phase card delay is priced
exactly like two slow turns, through one code path that cannot drift.

**Tech Stack:** Godot 4.7, GDScript. No new dependencies.

## Global Constraints

- **Five metrics only.** Pressure is expressed through `funds` and
  `public_support`. **Never a sixth resource, and no new loss condition.**
- **All game logic lives in `autoload/` and `resources/`.**
- **Never edit prose or data in `content/`, `data/events/` or
  `data/segments/`.** If a test fails because of card content, STOP and report.
- **No new dependencies.**
- **A failing harness is never committed.**
- **Never `git add -A`.** Stage the explicit paths each step names.
- Godot is on `PATH` as `godot`, version `4.7.stable`.

## GDScript trap seen repeatedly in this project

Property access on an autoload is typed `Variant`, so `:=` cannot infer a type.
Put an explicit type on anything reading `GameState` or `EventManager`:

```gdscript
var overrun: int = GameState.overrun_years()
```

## Baseline (verified 2026-07-28)

```bash
godot --headless res://tools/smoke_test.tscn
```
`SMOKE PASS (347 checks)`

```bash
godot --headless res://tools/sim_test.tscn
```
`SIM PASS: system_complete, grade=matched_history` — 22 turns, phase 32

```bash
godot --headless res://tools/layout_test.tscn
```
`LAYOUT PASS (265 checks)`

- [x] **Step 0: Confirm all three.** If any fails, STOP and report.

**STOP and report — do not improvise — when:** a verification fails twice after
your best fix; a step's expected output does not match what you see; quoted
"replace this" code does not match the file exactly; a step needs a decision the
plan does not spell out.

---

## Task 1: The overrun model

- [x] **Step 1: Write the failing tests**

In `tools/smoke_test.gd`, add `_check_overrun_pressure()` to `_ready()`
immediately after `_check_phase_calendar()`, and add this at the end of the
file:

```gdscript
## October 1934 as a binding milestone: a grace period, then escalating funds
## and support pressure, with 1940 still the hard backstop.
func _check_overrun_pressure() -> void:
	GameState.new_game()
	check(GameState.overrun_years() == 0, "a fresh campaign is not overrunning")
	# On schedule, including the grace phases, costs nothing extra.
	GameState.phase = GameState.CALENDAR_PHASES
	check(GameState.overrun_years() == 0, "landing on the target phase is not an overrun")
	GameState.phase = GameState.CALENDAR_PHASES + GameState.OVERRUN_GRACE_PHASES
	check(GameState.overrun_years() == 0, "the grace phases are not an overrun")
	# Past the grace, pressure scales with years, not phases.
	GameState.phase = GameState.CALENDAR_PHASES + GameState.OVERRUN_GRACE_PHASES + 1
	check(GameState.overrun_years() >= 1, "pressure begins after the grace phases")
	var early: int = GameState.overrun_years()
	GameState.phase = GameState.CALENDAR_PHASES * 2
	check(GameState.overrun_years() > early, "pressure escalates the longer the overrun runs")
	# A turn while overrunning costs more funds than a turn on schedule.
	GameState.new_game()
	GameState.set_front(0)
	GameState.work_pace = GameState.Pace.STEADY
	var funds_before: int = GameState.funds
	GameState.advance_turn()
	var on_schedule_cost: int = funds_before - GameState.funds
	GameState.new_game()
	GameState.set_front(0)
	GameState.work_pace = GameState.Pace.STEADY
	GameState.phase = GameState.CALENDAR_PHASES + GameState.OVERRUN_GRACE_PHASES + 1
	funds_before = GameState.funds
	GameState.advance_turn()
	var overrun_cost: int = funds_before - GameState.funds
	check(overrun_cost > on_schedule_cost,
		"a phase spent overrunning costs more than one on schedule (%d vs %d)"
		% [overrun_cost, on_schedule_cost])
	# Support drains while overrunning. Run enough phases to cross an interval.
	GameState.new_game()
	GameState.phase = GameState.CALENDAR_PHASES + GameState.OVERRUN_GRACE_PHASES + 1
	var support_before: int = GameState.public_support
	for i in GameState.OVERRUN_SUPPORT_INTERVAL * 2:
		if GameState.game_over:
			break
		GameState.set_front(0)
		GameState.work_pace = GameState.Pace.STEADY
		GameState.advance_turn()
	check(GameState.public_support < support_before,
		"a sustained overrun costs public support")
	GameState.new_game()
	EventManager.reset()
```

- [x] **Step 2: Run it and confirm it fails**

```bash
godot --headless res://tools/smoke_test.tscn
```
Expected: `SMOKE FAIL`, or a parse error naming `overrun_years` /
`OVERRUN_GRACE_PHASES`.

- [x] **Step 3: Add the constants**

In `autoload/game_state.gd`, add immediately after this line:

```gdscript
const PUMPING_SURCHARGE := 1          # extra per-phase cost if pumps were chosen
```

the following:

```gdscript
## October 1934 is a binding milestone, not a cliff and not merely a score.
## Passing it begins pressure that arrives at the EXISTING loss conditions on
## its own -- no new loss condition, and no sixth resource.
##
## Grace first: canonical play lands on CALENDAR_PHASES exactly, so without a
## buffer any slippage at all would punish a correctly-paced run.
const OVERRUN_GRACE_PHASES := 2
## Extra funds of phase overhead per year past HISTORICAL_FINISH_YEAR. Linear
## and legible on purpose -- the player should be able to read the HUD and say
## "this is costing me two funds a phase".
const OVERRUN_FUNDS_PER_YEAR := 1
## While overrunning, public support slips by one every this many phases.
const OVERRUN_SUPPORT_INTERVAL := 3
```

- [x] **Step 4: Add `overrun_years()`**

In `autoload/game_state.gd`, add immediately above `func current_year() -> int:`

```gdscript
## Years past October 1934, after the grace phases. Zero while on schedule.
## The single source of overrun pressure: both the funds and support terms read
## it, and the HUD displays it, so there is one definition to reason about.
func overrun_years() -> int:
	if phase <= CALENDAR_PHASES + OVERRUN_GRACE_PHASES:
		return 0
	return maxi(0, current_year() - HISTORICAL_FINISH_YEAR)
```

- [x] **Step 5: Apply the pressure in the calendar**

In `autoload/game_state.gd`, replace:

```gdscript
func _advance_calendar() -> void:
	phase += 1
	var overhead := PHASE_OVERHEAD
	if has_flag(&"pumped_alternative_chosen"):
		overhead += PUMPING_SURCHARGE
	_set_funds(funds - overhead)
	turn_advanced.emit(current_year(), phase)
```

with:

```gdscript
func _advance_calendar() -> void:
	phase += 1
	var overhead := PHASE_OVERHEAD
	if has_flag(&"pumped_alternative_chosen"):
		overhead += PUMPING_SURCHARGE
	# Overrun pressure rides on the CALENDAR, not on turns. apply_choice() calls
	# this once per phase of card-inflicted delay, so a card that costs two
	# phases is priced exactly like two slow turns -- one code path, no drift.
	var overrun := overrun_years()
	overhead += overrun * OVERRUN_FUNDS_PER_YEAR
	_set_funds(funds - overhead)
	if overrun > 0 and phase % OVERRUN_SUPPORT_INTERVAL == 0:
		_set_support(public_support - 1)
	turn_advanced.emit(current_year(), phase)
```

Do **not** add an end-condition check here. `advance_turn()` and
`apply_choice()` both call `_check_end_conditions()` already, and both
`bond_crisis` (funds below zero) and `project_cancelled` (support at zero) will
pick this up unchanged.

- [x] **Step 6: Run the harness**

```bash
godot --headless res://tools/smoke_test.tscn
```
Expected: `SMOKE PASS`, check count above 347.

```bash
godot --headless res://tools/sim_test.tscn
```
Expected: `SIM PASS: system_complete, grade=matched_history`.

Canonical play finishes on phase 32 with a grace boundary of 34, so it should
be **completely unaffected**. If `sim_test` changes at all, STOP and report —
it means pressure is reaching a run that is on schedule.

```bash
godot --headless res://tools/layout_test.tscn
```
Expected: `LAYOUT PASS (265 checks)`.

- [x] **Step 7: Commit**

```bash
git add autoload/game_state.gd tools/smoke_test.gd
git commit -m "feat: October 1934 becomes a binding milestone, not a score

Passing the historical finish date begins escalating pressure -- one fund of
extra phase overhead per year overrun, plus public support slipping every third
phase -- after a two-phase grace so a correctly-paced run is not punished for
slight slippage.

The pressure lands in _advance_calendar(), which apply_choice() already calls
once per phase of card-inflicted delay. A card that costs two phases is
therefore priced exactly like two slow turns, through one code path.

No new loss condition and no sixth resource: bond_crisis and project_cancelled
absorb it, and 1940 remains the hard backstop.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 2: Show the pressure

An invisible penalty teaches nothing. This is a teaching game, so the player
must be able to see what falling behind costs.

- [x] **Step 1: Widen the HUD cost cue**

In `scenes/ui/hud.gd`, replace:

```gdscript
func _update_cost_cue() -> void:
	if GameState.has_flag(&"pumped_alternative_chosen"):
		cost_label.text = "Pumping: -%d funds every phase" % GameState.PUMPING_SURCHARGE
		cost_label.visible = true
	else:
		cost_label.visible = false
```

with:

```gdscript
## Ongoing drains, in one line. Both are per-phase costs the player cannot see
## in any single number, so surfacing them is what makes them a lesson rather
## than an unexplained decline.
func _update_cost_cue() -> void:
	var cues: Array[String] = []
	if GameState.has_flag(&"pumped_alternative_chosen"):
		cues.append("Pumping: -%d funds every phase" % GameState.PUMPING_SURCHARGE)
	var overrun: int = GameState.overrun_years()
	if overrun > 0:
		cues.append("Behind schedule %d year%s: -%d funds every phase, support slipping"
			% [overrun, "" if overrun == 1 else "s",
			overrun * GameState.OVERRUN_FUNDS_PER_YEAR])
	cost_label.text = "  ·  ".join(cues)
	cost_label.visible = not cues.is_empty()
```

- [x] **Step 2: Refresh the cue as the calendar moves**

The cue currently updates only on `_refresh()` and on a granted flag, so an
overrun that begins mid-campaign would never appear. In `scenes/ui/hud.gd`,
replace:

```gdscript
	GameState.turn_advanced.connect(func(y: int, _p: int): labels["date"].text = "Turn %d  ·  %d" % [GameState.turn, y])
```

with:

```gdscript
	GameState.turn_advanced.connect(func(y: int, _p: int):
		labels["date"].text = "Turn %d  ·  %d" % [GameState.turn, y]
		_update_cost_cue())
```

- [x] **Step 3: Verify**

```bash
godot --headless res://tools/smoke_test.tscn
```
`SMOKE PASS`

```bash
godot --headless res://tools/layout_test.tscn
```
`LAYOUT PASS` — the cue line is longer now. If it fails horizontally, STOP and
report; do not shorten the text without saying so.

- [x] **Step 4: Commit**

```bash
git add scenes/ui/hud.gd
git commit -m "feat: HUD shows what falling behind schedule costs

The overrun drain is a per-phase cost with no single number the player can
read, so it is surfaced beside the pumping surcharge and refreshed as the
calendar advances rather than only on a granted flag.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 3: Re-measure

- [x] **Step 1: Run the probe**

```bash
godot --headless res://tools/balance_probe.tscn
```
Expected: `BALANCE PROBE DONE` and ten `BALANCE` lines.

**Do not tune anything.** Copy all ten lines into your report verbatim. The
reviewer compares them against the spec's success criteria.

The prediction being tested: strategies that finish on time should be largely
unaffected, while slow ones (`historical / all rest` at 31.8 turns) and
badly-allocated ones (`bay first`, whose cost currently shows only in grade)
should start paying for it in wins. If **nothing** moves, the grace boundary is
too generous and the reviewer needs to know that, not a fix.

- [x] **Step 2: Report**

**STOP.** Report all ten BALANCE lines, the three harness outputs, and the two
commit hashes.

## Definition of done

- [x] All three suites green.
- [x] `sim_test` still `matched_history` and unchanged at 22 turns.
- [x] Ten `BALANCE` lines reported verbatim, untuned.
- [x] `data/events` and `data/segments` untouched.
