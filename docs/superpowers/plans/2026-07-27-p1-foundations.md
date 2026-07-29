# P1 Foundations Implementation Plan

> **For agentic workers:** Steps use checkbox (`- [ ]`) syntax for tracking. Do
> steps **in order**. Never skip a verification step. Tick a box only after you
> have run its verification and seen the expected output.

**Goal:** Compress the campaign from ~73 turns to 24 construction phases, close
the unbounded funds loop, move card content into a format an SFPUC historian can
edit without engine knowledge, and decouple card art from card data.

**Architecture:** All rule changes stay inside `autoload/game_state.gd` and
`resources/`. Card prose moves to Markdown files in `content/cards/`, with two
headless Godot tools converting between Markdown and the `.tres` resources the
game loads. Card art resolves by `event_id` filename convention instead of an
embedded `Texture2D` property.

**Tech Stack:** Godot 4.7, GDScript. No new dependencies. Verification is the
existing headless harness (`smoke_test`, `sim_test`).

## Global Constraints

Copied from [the design spec](../specs/2026-07-27-minigames-and-campaign-restructure-design.md)
and [ROADMAP.md](../../ROADMAP.md). Every task's requirements implicitly include
these.

- **Five metrics only** — funds, public_support, water_readiness,
  crew_wellbeing, time — plus miles and flags. **Never a sixth resource.**
- **All game logic lives in `autoload/` and `resources/`.** Scenes only display
  and call methods; they never mutate state.
- **Never edit authored historical prose in `data/` or `content/` to make a test
  pass.** If a test fails because of card content, STOP and report.
- **Every historical deviation is recorded** in a card's `assumption_note`.
- **No new dependencies.** No GPL code under any circumstances.
- **A failing harness is never committed.**
- Godot is on `PATH` as `godot`. Verified version: `4.7.stable.official`.

## Baseline (verified 2026-07-27, commit `3a266ab`)

Before you change anything, these are the known-good outputs:

```bash
godot --headless res://tools/smoke_test.tscn
```
Prints `SMOKE PASS (207 checks)`.

```bash
godot --headless res://tools/sim_test.tscn
```
Prints `SIM RESULT: system_complete | Summer 1935 | mile 167 | ... | 73 turns | 5 hazards`
then `SIM PASS: system_complete, grade=behind_history`.

- [x] **Step 0: Confirm the baseline before starting Task 1.** Run both commands
  above. If either does not print PASS, STOP and report — do not begin work on a
  red harness.

## Batching & review protocol

**Each task is one batch.** At the end of a task: commit, tick that task's
boxes, then **STOP and report**. Do not start the next task. A reviewer checks
the batch before you continue.

**STOP immediately and report — do not improvise — when:**

- A verification fails twice in a row after your best fix.
- A step's expected output does not match what you see, even if it looks close.
- A step requires a decision this plan does not spell out.
- You are tempted to add a mechanic, resource, or dependency.
- You are tempted to edit historical prose to make a test pass.

Never delete data or weaken a check to make the harness pass.

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `autoload/game_state.gd` | Modify | Phase calendar, turn counter, bounded economy. All rule changes land here. |
| `autoload/event_manager.gd` | Modify | Drop the winter-gating argument from availability calls. |
| `resources/event_card.gd` | Modify | Remove `winter_only` and `archival_photo`; add `art_path()`. |
| `resources/route_segment.gd` | Modify | Re-document `winter_sensitive` as railroad dependence. |
| `scenes/ui/hud.gd` | Modify | Display phase/24 instead of season. |
| `scenes/ui/decision_panel.gd` | Modify | Bond affordability reflects the issue cap. |
| `scenes/ui/event_panel.gd` | Modify | Load card art by convention. |
| `tools/export_cards.gd` + `.tscn` | Create | One-shot `.tres` → Markdown migration. |
| `tools/import_cards.gd` + `.tscn` | Create | Markdown → `.tres`, the historian's build step. |
| `tools/smoke_test.gd` | Modify | New assertions for every change below. |
| `tools/sim_test.gd` | Modify | Phase-aware output, plus the funds exploit probe. |
| `content/cards/*.md` | Create | Historian-editable card source, one file per card. |
| `content/README.md` | Create | Editing instructions written for a non-programmer. |

---

### Task 1: Phase calendar — 24 turns replaces 73 seasons

**Files:**
- Modify: `autoload/game_state.gd`
- Modify: `autoload/event_manager.gd:79`, `:86`, `:143`, `:149`
- Modify: `resources/event_card.gd:37`, `:47-53`
- Modify: `resources/route_segment.gd:19-21`
- Modify: `scenes/ui/hud.gd`
- Modify: `tools/smoke_test.gd`, `tools/sim_test.gd`

**Interfaces:**
- Produces: `GameState.phase: int` (0-based counter), `GameState.PHASES_TOTAL := 24`,
  `GameState.current_year() -> int`, `GameState.phases_remaining() -> int`.
  `GameState.season` and `GameState.Season` are **removed**.
- Produces: `EventCard.is_available(miles: float, flags: Dictionary) -> bool`
  (the `is_winter: bool` parameter is removed).

- [x] **Step 1: Add the failing assertions to the smoke test**

In `tools/smoke_test.gd`, add this function and register it in `_ready()`.

Add the call as the first line of `_ready()`, before `_check_segments()`:

```gdscript
	_check_phase_calendar()
```

Add the function at the end of the file:

```gdscript
func _check_phase_calendar() -> void:
	GameState.new_game()
	check(GameState.PHASES_TOTAL == 24, "campaign is 24 phases")
	check(GameState.phase == 0, "new game starts at phase 0")
	check(GameState.current_year() == 1914, "phase 0 is 1914")
	check(GameState.phases_remaining() == 24, "24 phases remain at start")
	for i in 24:
		GameState.work_pace = GameState.Pace.STEADY
		GameState.advance_turn()
	check(GameState.phase == 24, "24 advances reach phase 24 (got %d)" % GameState.phase)
	check(GameState.current_year() == 1934,
		"phase 24 lands on 1934 (got %d)" % GameState.current_year())
	# The three mountain divisions must stay railroad-dependent; renaming the
	# export would silently drop this from the .tres files. Verified against
	# data/segments: high_sierra, mountain_tunnel and western_foothills are true;
	# san_joaquin_valley, coast_range and bay_and_peninsula are false.
	var dependent := 0
	for s in GameState.segments:
		if s.winter_sensitive:
			dependent += 1
	check(dependent == 3, "exactly 3 railroad-dependent segments (got %d)" % dependent)
	GameState.new_game()
	EventManager.reset()
```

- [x] **Step 2: Run the smoke test and confirm it fails**

```bash
godot --headless res://tools/smoke_test.tscn
```

Expected: `SMOKE FAIL`, with errors naming `PHASES_TOTAL` / `current_year`.
A parse error mentioning `Invalid access to constant 'PHASES_TOTAL'` is also
correct at this point.

- [x] **Step 3: Replace the calendar constants in `autoload/game_state.gd`**

Replace the `enum Season { WINTER, SPRING, SUMMER, FALL }` line with nothing —
delete it. Keep `enum Pace { REST, STEADY, PUSHED }`.

Replace these constants:

```gdscript
const TOTAL_MILES := 167.0
const START_YEAR := 1914
const HISTORICAL_FINISH_YEAR := 1934  # first water reached Pulgas October 24, 1934
const FINAL_DEADLINE_YEAR := 1940     # hard loss: the city turns elsewhere
```

with:

```gdscript
const TOTAL_MILES := 167.0
const START_YEAR := 1914
const HISTORICAL_FINISH_YEAR := 1934  # first water reached Pulgas October 24, 1934
const FINAL_DEADLINE_YEAR := 1940     # hard loss: the city turns elsewhere

## One turn is one construction phase, not a calendar season: six divisions,
## four phases each. Seasons survive only as narrative framing inside card
## prose -- the campaign does not simulate weather. Each affected card records
## this in its assumption_note.
const PHASES_TOTAL := 24
const YEARS_SPAN := HISTORICAL_FINISH_YEAR - START_YEAR   # 20 years over 24 phases
```

Replace the mileage and winter block:

```gdscript
const MILES_PER_SEASON := {
	Pace.REST: 0.0,
	Pace.STEADY: 2.5,
	Pace.PUSHED: 4.0,
}
const PUSHED_CREW_DRIFT := -1         # crew change per pushed season
const REST_CREW_DRIFT := 1            # crew change per rest season
const WINTER_PAYROLL := 1             # funds spent every winter turn
const PUMPING_SURCHARGE := 1          # extra winter cost if pumps were chosen
const SNOWBOUND_FACTOR := 0.3         # winter rate in Sierra segments, no railroad
const RAILROAD_WINTER_FACTOR := 0.8   # winter rate in Sierra segments with railroad
```

with:

```gdscript
## TUNING KNOB. Task 1 Step 8 adjusts STEADY only; PUSHED is always
## STEADY * 1.6, rounded to one decimal.
const MILES_PER_PHASE := {
	Pace.REST: 0.0,
	Pace.STEADY: 7.0,
	Pace.PUSHED: 11.2,
}
const PUSHED_CREW_DRIFT := -1         # crew change per pushed phase
const REST_CREW_DRIFT := 1            # crew change per rest phase
const PHASE_OVERHEAD := 1             # funds spent every phase
const PUMPING_SURCHARGE := 1          # extra per-phase cost if pumps were chosen
## Sierra divisions build at this fraction until the railroad is operational.
## Division-scoped, not calendar-scoped -- it is what makes the railroad worth
## building now that the game no longer tracks winter.
const NO_RAILROAD_FACTOR := 0.4
```

- [x] **Step 4: Replace the state variables**

Replace:

```gdscript
var year: int = START_YEAR
var season: int = Season.SPRING
```

with:

```gdscript
var phase: int = 0
```

Then delete every remaining reference to `year` as a stored variable. In
`new_game()`, replace:

```gdscript
	year = START_YEAR
	season = Season.SPRING
```

with:

```gdscript
	phase = 0
```

- [x] **Step 5: Replace the calendar, build, and end-condition internals**

Replace `_advance_calendar()`:

```gdscript
func _advance_calendar() -> void:
	season = (season + 1) % 4
	if season == Season.WINTER:
		year += 1
		var payroll := WINTER_PAYROLL
		if has_flag(&"pumped_alternative_chosen"):
			payroll += PUMPING_SURCHARGE
		_set_funds(funds - payroll)
	turn_advanced.emit(year, season)
```

with:

```gdscript
func _advance_calendar() -> void:
	phase += 1
	var overhead := PHASE_OVERHEAD
	if has_flag(&"pumped_alternative_chosen"):
		overhead += PUMPING_SURCHARGE
	_set_funds(funds - overhead)
	turn_advanced.emit(current_year(), phase)
```

Replace `_build_miles()`:

```gdscript
func _build_miles(season_count: int) -> void:
	var segment := current_segment()
	if segment == null:
		return
	var rate: float = MILES_PER_SEASON[work_pace] * segment.build_rate_modifier
	rate *= _crew_factor()
	if season == Season.WINTER and segment.winter_sensitive:
		rate *= RAILROAD_WINTER_FACTOR if has_flag(&"railroad_operational") else SNOWBOUND_FACTOR
	miles_built = minf(miles_built + rate * season_count, TOTAL_MILES)
	miles_changed.emit(miles_built)
```

with:

```gdscript
func _build_miles(phase_count: int) -> void:
	var segment := current_segment()
	if segment == null:
		return
	var rate: float = MILES_PER_PHASE[work_pace] * segment.build_rate_modifier
	rate *= _crew_factor()
	if segment.winter_sensitive and not has_flag(&"railroad_operational"):
		rate *= NO_RAILROAD_FACTOR
	miles_built = minf(miles_built + rate * phase_count, TOTAL_MILES)
	miles_changed.emit(miles_built)
```

In `_check_end_conditions()`, replace:

```gdscript
		elif year > FINAL_DEADLINE_YEAR:
```

with:

```gdscript
		elif current_year() > FINAL_DEADLINE_YEAR:
```

In `_emit_all()`, replace:

```gdscript
	turn_advanced.emit(year, season)
```

with:

```gdscript
	turn_advanced.emit(current_year(), phase)
```

- [x] **Step 6: Add the public phase accessors**

Add these two functions immediately above `completion_grade()`:

```gdscript
## Display year derived from the phase counter: 24 phases span 1914-1934.
## Overrunning the campaign keeps advancing the year toward FINAL_DEADLINE_YEAR.
func current_year() -> int:
	return START_YEAR + int(floor(float(phase) * float(YEARS_SPAN) / float(PHASES_TOTAL)))


## Phases left before the historical finish. Negative once the player overruns.
func phases_remaining() -> int:
	return PHASES_TOTAL - phase
```

Replace `completion_grade()`:

```gdscript
func completion_grade() -> String:
	if year < HISTORICAL_FINISH_YEAR:
		return "ahead_of_history"
	if year == HISTORICAL_FINISH_YEAR:
		return "matched_history"
	return "behind_history"
```

with:

```gdscript
func completion_grade() -> String:
	var y := current_year()
	if y < HISTORICAL_FINISH_YEAR:
		return "ahead_of_history"
	if y == HISTORICAL_FINISH_YEAR:
		return "matched_history"
	return "behind_history"
```

Finally, in `apply_choice()`, replace the comment and loop:

```gdscript
		# Positive time deltas are lost seasons: the calendar advances with winter
		# payroll but no construction. Negative deltas are schedule gains, banked
		# as immediate bonus mileage at the steady rate.
```

with:

```gdscript
		# Positive time deltas are lost phases: the calendar advances with
		# overhead but no construction. Negative deltas are schedule gains,
		# banked as immediate bonus mileage at the steady rate.
```

- [x] **Step 7: Remove winter gating from cards, segments, and EventManager**

In `resources/event_card.gd`, delete this line:

```gdscript
@export var winter_only: bool = false
```

and replace `is_available()`:

```gdscript
func is_available(miles: float, is_winter: bool, flags: Dictionary) -> bool:
	if miles < float(mile_start):
		return false
	if not is_fixed and miles > float(mile_end):
		return false
	if winter_only and not is_winter:
		return false
	for flag in required_flags:
		if not flags.has(flag):
			return false
	for flag in blocked_by_flags:
		if flags.has(flag):
			return false
	return true
```

with:

```gdscript
func is_available(miles: float, flags: Dictionary) -> bool:
	if miles < float(mile_start):
		return false
	if not is_fixed and miles > float(mile_end):
		return false
	for flag in required_flags:
		if not flags.has(flag):
			return false
	for flag in blocked_by_flags:
		if flags.has(flag):
			return false
	return true
```

In `resources/route_segment.gd`, replace the doc comment above
`winter_sensitive`:

```gdscript
## Sierra segments lose most of their winter build rate unless the
## Hetch Hetchy Railroad is operational.
@export var winter_sensitive: bool = false
```

with:

```gdscript
## Sierra divisions build at NO_RAILROAD_FACTOR until the Hetch Hetchy Railroad
## is operational. Named for the seasonal model this game no longer simulates;
## the property now means "railroad-dependent". DEFERRED CLEANUP: renaming this
## export would silently drop the value from the six segment .tres files, so the
## name stays until a migration is written.
@export var winter_sensitive: bool = false
```

In `autoload/event_manager.gd`, delete both `var is_winter := ...` lines (in
`_available_cards()` and `_hazard_pool()`) and change both
`card.is_available(GameState.miles_built, is_winter, GameState.flags)` calls to:

```gdscript
		if card.is_available(GameState.miles_built, GameState.flags):
```

- [x] **Step 8: Update the HUD and the harness, then tune**

In `scenes/ui/hud.gd` there are exactly four edits.

**8a.** Delete line 5 entirely:

```gdscript
const SEASONS := ["Winter", "Spring", "Summer", "Fall"]
```

**8b.** Replace line 37:

```gdscript
	GameState.turn_advanced.connect(func(y: int, s: int): labels["date"].text = "%s %d" % [SEASONS[s], y])
```

with:

```gdscript
	GameState.turn_advanced.connect(func(y: int, p: int): labels["date"].text = "Phase %d of %d  ·  %d" % [p, GameState.PHASES_TOTAL, y])
```

**8c.** Replace line 46, inside `_refresh()`:

```gdscript
	labels["date"].text = "%s %d" % [SEASONS[GameState.season], GameState.year]
```

with:

```gdscript
	labels["date"].text = "Phase %d of %d  ·  %d" % [GameState.phase, GameState.PHASES_TOTAL, GameState.current_year()]
```

**8d.** Replace line 78, inside `_update_cost_cue()`:

```gdscript
		cost_label.text = "Pumping: -1 funds every winter"
```

with:

```gdscript
		cost_label.text = "Pumping: -%d funds every phase" % GameState.PUMPING_SURCHARGE
```

Then in `scenes/ui/event_panel.gd`, replace lines 103–106 inside
`_deltas_text()`:

```gdscript
	if choice.time_delta_seasons > 0:
		parts.append("lost %d season(s)" % choice.time_delta_seasons)
	elif choice.time_delta_seasons < 0:
		parts.append("banked %d season(s)" % -choice.time_delta_seasons)
```

with:

```gdscript
	if choice.time_delta_seasons > 0:
		parts.append("lost %d phase(s)" % choice.time_delta_seasons)
	elif choice.time_delta_seasons < 0:
		parts.append("banked %d phase(s)" % -choice.time_delta_seasons)
```

> The `time_delta_seasons` property keeps its name. Renaming an `@export` would
> silently drop the value from all 26 card `.tres` files. Same reasoning as
> `winter_sensitive`; both renames are deferred to a migration.

In `tools/sim_test.gd`, delete the line:

```gdscript
const SEASONS := ["Winter", "Spring", "Summer", "Fall"]
```

Replace `MAX_TURNS := 160` with `MAX_TURNS := 40`. Replace the two lines that
capture and print the year:

```gdscript
	var final_year := GameState.year
```
becomes
```gdscript
	var final_year := GameState.current_year()
```

and the `print("SIM RESULT: ...")` call becomes:

```gdscript
	print("SIM RESULT: %s | phase %d | %d | mile %.0f | readiness %d | funds %d | support %d | crew %d | %d turns | %d hazards"
		% [final_result, GameState.phase, final_year, GameState.miles_built,
		GameState.water_readiness, GameState.funds, GameState.public_support,
		GameState.crew_wellbeing, turns, hazards_seen])
```

Also replace `PROBE_TURNS := 25` with `PROBE_TURNS := 12`.

**Do not run the sim yet.** Step 9 must land first or it will fail. Go to
Step 9.

- [x] **Step 9: Rebalance the funds economy for 24 phases**

> **Why this step exists.** Compressing 73 turns to 24 cut the number of
> income opportunities by two thirds while leaving costs untouched. Measured
> against the actual deck: canonical card choices cost **−34 funds** across a
> campaign, phase overhead costs **−24**, and starting funds are **+25** — a
> net of **−33** before any action is taken. The old campaign only balanced
> because `issue_bond` was unlimited and there were 73 turns to grind it; the
> game was floating on the very exploit P1 exists to close.
>
> The fix is historically better than what it replaces. There were **two**
> major Hetch Hetchy bond measures, not twenty — the 1910 issue and the 1928
> issue. So: two bonds, each large, instead of an unlimited supply of small
> ones.

In `autoload/game_state.gd`, replace:

```gdscript
const START_FUNDS := 25
```

with:

```gdscript
const START_FUNDS := 30
```

Replace:

```gdscript
const BOND_MIN_SUPPORT := 4           # support needed to issue a bond
const BOND_FUNDS_GAIN := 3
const BOND_SUPPORT_COST := 1
```

with:

```gdscript
const BOND_MIN_SUPPORT := 4           # support needed to issue a bond
## A campaign authorizes two major bond measures, echoing the 1910 and 1928
## issues -- large and rare, not an unlimited supply of small ones. This is
## what funds a 24-phase campaign against -34 funds of canonical card costs
## and -24 of phase overhead.
const BOND_FUNDS_GAIN := 20
const BOND_SUPPORT_COST := 1
const MAX_BOND_ISSUES := 2
```

Add to the state variables, immediately after `var flags: Dictionary = {}`:

```gdscript
var bonds_issued: int = 0
```

In `new_game()`, immediately after `flags = {}`, add:

```gdscript
	bonds_issued = 0
```

In `take_action()`, replace the `&"issue_bond":` branch:

```gdscript
		&"issue_bond":
			if public_support < BOND_MIN_SUPPORT:
				return false
			_set_funds(funds + BOND_FUNDS_GAIN)
			_set_support(public_support - BOND_SUPPORT_COST)
```

with:

```gdscript
		&"issue_bond":
			if public_support < BOND_MIN_SUPPORT:
				return false
			if bonds_issued >= MAX_BOND_ISSUES:
				return false
			bonds_issued += 1
			_set_funds(funds + BOND_FUNDS_GAIN)
			_set_support(public_support - BOND_SUPPORT_COST)
```

- [x] **Step 10: Run the sim and tune mileage**

```bash
godot --headless res://tools/sim_test.tscn
```

**First check the result word, then the turn count.**

If `SIM RESULT` begins with `bond_crisis`, `project_cancelled`, `work_halted`
or `city_moves_on`, the campaign is not winnable — **STOP and report the full
line.** Do not attempt to fix it by changing constants; the mileage knob cannot
fix a funds problem, and no other constant is yours to change.

If it begins with `system_complete`, read the `turns` number:

- If `turns` is between **20 and 28 inclusive**, and the run prints
  `SIM PASS`, tuning is done. Go to Step 11.
- If `turns` is **below 20**: lower `MILES_PER_PHASE[Pace.STEADY]` by `0.5`, set
  `Pace.PUSHED` to that new value times `1.6` rounded to one decimal, re-run.
- If `turns` is **above 28**: raise `MILES_PER_PHASE[Pace.STEADY]` by `0.5`, set
  `Pace.PUSHED` to that new value times `1.6` rounded to one decimal, re-run.
- **Maximum 4 adjustments.** If it is still outside 20–28 after the fourth,
  **STOP and report** the last three `SIM RESULT` lines. Do not adjust any
  other constant.

**One more case to watch.** If `SIM RESULT` says `system_complete`, `turns` is
inside 20–28, and the run *still* prints `SIM FAIL`, look at the `SIM PROBE`
line. If either `push->injury` or `rest->impatience` is `0`, **STOP and report
both the SIM RESULT and SIM PROBE lines.** That is a known risk of compressing
the campaign — the fixed card spine now fires on most turns and suppresses the
hazard roll — and it is a design question, not something to fix by changing
constants.

- [x] **Step 11: Run the full harness**

```bash
godot --headless res://tools/smoke_test.tscn
```
Expected: `SMOKE PASS`. The check count will differ from 207 — that is expected;
only PASS/FAIL matters.

```bash
godot --headless res://tools/sim_test.tscn
```
Expected: `SIM PASS`, with `turns` between 20 and 28.

If either fails, STOP and report.

- [x] **Step 12: Commit and stop for review**

```bash
git add -A
git commit -m "feat: 24-phase campaign replaces the 73-turn seasonal calendar

One turn is now one construction phase. Seasons survive only as narrative
framing in card prose; the game no longer simulates weather. Sierra build
penalty becomes division-scoped railroad dependence, preserving the reason to
build the railroad.

Removes GameState.season/Season and EventCard.winter_only. Adds phase,
PHASES_TOTAL, current_year(), phases_remaining().

Rebalances funds for the compressed campaign: two large bond measures echoing
the 1910 and 1928 issues replace an unlimited supply of small ones. Measured
canonical card cost is -34 against -24 phase overhead, so the old economy only
balanced by grinding the unbounded bond loop across 73 turns.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

**STOP. Report the final SIM RESULT line and wait for review.**

---

### Task 1b: Split the turn counter from the calendar

**The defect Task 1 exposed.** `phase` is doing two incompatible jobs: counting
the player's turns *and* counting calendar time. Card delays advance the
calendar without granting a turn, so canonical play used **20 turns but 30
phases**, and the year formula — calibrated to 24 — landed on **1939**, one year
from the `city_moves_on` loss at 1940.

The asymmetry causing it is deliberate and correct: in `apply_choice()`, a
positive `time_delta_seasons` advances the calendar (a lost phase), while a
negative one grants bonus mileage rather than rewinding the clock. You cannot
un-spend 1926. Measured across the deck, canonical choices carry **+13 phases of
delay** against **−15 of schedule gain**, and only the +13 touches the calendar.

**The consequence worth fixing:** every playthrough grades `behind_history`, so
`completion_grade()` is decoration. After this task the clock is driven purely
by delays — careful play finishes *ahead* of history, reckless play behind and
can genuinely lose to 1940.

**Files:**
- Modify: `autoload/game_state.gd`
- Modify: `scenes/ui/hud.gd`
- Modify: `tools/smoke_test.gd`

**Interfaces:**
- Produces: `GameState.turn: int` (player decisions taken),
  `GameState.TURNS_TOTAL := 24`, `GameState.CALENDAR_PHASES`,
  `GameState.turns_remaining() -> int`.
- `GameState.phases_remaining()` and `GameState.PHASES_TOTAL` are **removed**.
  `GameState.phase` survives, now meaning calendar time only.

- [x] **Step 1: Update the smoke assertions**

In `tools/smoke_test.gd`, inside `_check_phase_calendar()`, replace these four
lines:

```gdscript
	check(GameState.PHASES_TOTAL == 24, "campaign is 24 phases")
	check(GameState.phase == 0, "new game starts at phase 0")
	check(GameState.current_year() == 1914, "phase 0 is 1914")
	check(GameState.phases_remaining() == 24, "24 phases remain at start")
```

with:

```gdscript
	check(GameState.TURNS_TOTAL == 24, "the turn budget is 24")
	check(GameState.phase == 0, "new game starts at phase 0")
	check(GameState.turn == 0, "new game starts at turn 0")
	check(GameState.current_year() == 1914, "phase 0 is 1914")
	check(GameState.turns_remaining() == 24, "24 turns remain at start")
```

and replace these two:

```gdscript
	check(GameState.phase == 24, "24 advances reach phase 24 (got %d)" % GameState.phase)
	check(GameState.current_year() == 1934,
		"phase 24 lands on 1934 (got %d)" % GameState.current_year())
```

with:

```gdscript
	check(GameState.turn == 24, "24 advances reach turn 24 (got %d)" % GameState.turn)
	check(GameState.phase == 24,
		"with no card delays, phase tracks turn (got %d)" % GameState.phase)
	# A delay-free run is faster than history: 24 phases against a calendar
	# calibrated to canonical play, which costs ~30.
	check(GameState.current_year() < 1934,
		"a delay-free campaign finishes ahead of 1934 (got %d)" % GameState.current_year())
```

- [x] **Step 2: Run the smoke test and confirm it fails**

```bash
godot --headless res://tools/smoke_test.tscn
```

Expected: `SMOKE FAIL`, or a parse error naming `TURNS_TOTAL` or `turn`.

- [x] **Step 3: Add the turn counter and calendar constants**

In `autoload/game_state.gd`, replace:

```gdscript
const PHASES_TOTAL := 24
const YEARS_SPAN := HISTORICAL_FINISH_YEAR - START_YEAR   # 20 years over 24 phases
```

with:

```gdscript
## The player's turn budget -- a session-length design target, not a rule. The
## real constraint is FINAL_DEADLINE_YEAR.
const TURNS_TOTAL := 24
## Calendar phases consumed by canonical play. The year is derived from this,
## NOT from TURNS_TOTAL: card delays advance the calendar without granting a
## turn, so canonical play costs about 30 phases against 24 turns. Calibrated
## in Task 1b Step 7 so canonical play lands on HISTORICAL_FINISH_YEAR.
const CALENDAR_PHASES := 30
const YEARS_SPAN := HISTORICAL_FINISH_YEAR - START_YEAR   # 1914 -> 1934
```

Replace:

```gdscript
var phase: int = 0
```

with:

```gdscript
var phase: int = 0                    # calendar time: turns + card delays
var turn: int = 0                     # player decisions taken
```

In `new_game()`, replace:

```gdscript
	phase = 0
```

with:

```gdscript
	phase = 0
	turn = 0
```

- [x] **Step 4: Count the turn in `advance_turn()`**

Replace:

```gdscript
func advance_turn() -> void:
	if game_over:
		return
	_build_miles(1)
```

with:

```gdscript
func advance_turn() -> void:
	if game_over:
		return
	turn += 1
	_build_miles(1)
```

- [x] **Step 5: Rebase the year on `CALENDAR_PHASES`**

Replace:

```gdscript
func current_year() -> int:
	return START_YEAR + int(floor(float(phase) * float(YEARS_SPAN) / float(PHASES_TOTAL)))


## Phases left before the historical finish. Negative once the player overruns.
func phases_remaining() -> int:
	return PHASES_TOTAL - phase
```

with:

```gdscript
func current_year() -> int:
	return START_YEAR + int(floor(float(phase) * float(YEARS_SPAN) / float(CALENDAR_PHASES)))


## Turns left in the budget. Negative once the player overruns it; this is a
## pacing signal, not a loss condition -- the deadline is a year.
func turns_remaining() -> int:
	return TURNS_TOTAL - turn
```

- [x] **Step 6: Update the HUD**

In `scenes/ui/hud.gd`, replace the two date lines. First, inside `_ready()`:

```gdscript
	GameState.turn_advanced.connect(func(y: int, p: int): labels["date"].text = "Phase %d of %d  ·  %d" % [p, GameState.PHASES_TOTAL, y])
```

with:

```gdscript
	GameState.turn_advanced.connect(func(y: int, _p: int): labels["date"].text = "Turn %d  ·  %d" % [GameState.turn, y])
```

Then, inside `_refresh()`:

```gdscript
	labels["date"].text = "Phase %d of %d  ·  %d" % [GameState.phase, GameState.PHASES_TOTAL, GameState.current_year()]
```

with:

```gdscript
	labels["date"].text = "Turn %d  ·  %d" % [GameState.turn, GameState.current_year()]
```

- [x] **Step 7: Calibrate `CALENDAR_PHASES`**

```bash
godot --headless res://tools/sim_test.tscn
```

Read the `phase` number and the `grade=` word in `SIM RESULT`.

- If the run prints `SIM PASS` **and** `grade=matched_history`, calibration is
  done. Go to Step 8.
- If `grade=behind_history`: **raise** `CALENDAR_PHASES` by 1 and re-run.
- If `grade=ahead_of_history`: **lower** `CALENDAR_PHASES` by 1 and re-run.
- **Maximum 6 adjustments.** If it has not reached `matched_history` after the
  sixth, or if the result word is ever anything but `system_complete`, **STOP
  and report** the last three `SIM RESULT` lines. Change no other constant.

- [x] **Step 8: Run the full harness**

```bash
godot --headless res://tools/smoke_test.tscn
```
Expected: `SMOKE PASS`.

```bash
godot --headless res://tools/sim_test.tscn
```
Expected: `SIM PASS`, with `grade=matched_history`.

Then confirm nothing still references the removed names:

```bash
grep -rn "PHASES_TOTAL\|phases_remaining" --include=*.gd .
```
Expected: **no output.** If anything prints, fix that reference and re-run both
tests.

- [x] **Step 9: Commit and stop for review**

```bash
git add -A
git commit -m "fix: split the player turn counter from the calendar

phase was counting both player turns and calendar time. Card delays advance the
calendar without granting a turn, so canonical play used 20 turns but 30
phases, and a year formula calibrated to 24 landed on 1939 -- one year from the
1940 loss, with every playthrough grading behind_history.

turn now counts decisions and phase counts calendar time, with the year derived
from CALENDAR_PHASES calibrated to canonical play. The clock is driven purely
by delays, so careful play finishes ahead of history and reckless play behind.
This makes completion_grade() meaningful as the date axis of the ending matrix.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

**STOP. Report the final SIM RESULT line and the grade, and wait for review.**

---

### Task 2: Bounded economy — close the unbounded funds loop

The defect: alternating `issue_bond` (+3 funds, −1 support) and `outreach`
(−1 funds, +2 support) nets +2 funds and +1 support every two turns, forever.
Funds grow without bound, support and crew pin at their caps, and four of the
five loss conditions become unreachable.

The fix has two parts: **bond issuance is capped at 2 per campaign**, and
`outreach` / `improve_camp` **cost more each time they are used**.

> **Note for the reviewer:** the design spec §2 removes `issue_bond` entirely,
> replacing it with the Make the Case set piece. That set piece is P3 work, so
> removing it here would leave the campaign with no income. The cap is the P1
> stand-in; P3 replaces the two issuances with the set piece.

**Files:**
- Modify: `autoload/game_state.gd`
- Modify: `scenes/ui/decision_panel.gd`
- Modify: `tools/smoke_test.gd`, `tools/sim_test.gd`

**Interfaces:**
- Consumes: `GameState.phase`, `GameState.current_year()` from Task 1.
- Produces: `GameState.bonds_issued: int`, `GameState.MAX_BOND_ISSUES := 2`,
  `GameState.action_cost(action: StringName) -> int`,
  `GameState.can_take_action(action: StringName) -> bool`.

- [x] **Step 1: Write the failing exploit probe in the sim**

In `tools/sim_test.gd`, add this function at the end of the file:

```gdscript
## Plays the bond/outreach alternation that used to generate unbounded funds.
## Returns the highest funds value reached.
func _exploit_probe() -> int:
	GameState.new_game()
	EventManager.reset()
	var peak := GameState.funds
	for i in 40:
		if GameState.game_over:
			break
		GameState.work_pace = GameState.Pace.STEADY
		if i % 2 == 0:
			GameState.take_action(&"issue_bond")
		else:
			GameState.take_action(&"outreach")
		GameState.advance_turn()
		peak = maxi(peak, GameState.funds)
	return peak
```

In `_ready()`, immediately before the `var win := ...` line, add:

```gdscript
	var exploit_peak := _exploit_probe()
	print("SIM EXPLOIT: peak funds under bond/outreach alternation = %d" % exploit_peak)
```

and change the `win` condition line from:

```gdscript
	var win := final_result == &"system_complete" and final_year <= 1940
```

to:

```gdscript
	var win := final_result == &"system_complete" and final_year <= 1940
	# Regression guard: no repeatable action loop may outrun phase overhead.
	# Two bonds at BOND_FUNDS_GAIN is the entire authorized income; anything
	# above that means a repeatable loop is manufacturing funds.
	win = win and exploit_peak <= GameState.START_FUNDS + (GameState.MAX_BOND_ISSUES * GameState.BOND_FUNDS_GAIN)
```

- [x] **Step 2: Run the sim and confirm the probe fails**

```bash
godot --headless res://tools/sim_test.tscn
```

Expected: `SIM EXPLOIT: peak funds under bond/outreach alternation = <a number
well above 35>`, followed by `SIM FAIL`. This is the defect reproducing.

Record the number — the reviewer wants it.

- [x] **Step 3: Add the economy constants and state**

> **Already done in Task 1:** `MAX_BOND_ISSUES`, `BOND_FUNDS_GAIN := 20`,
> `var bonds_issued`, its reset in `new_game()`, and the cap check inside
> `take_action()`. **Do not add them again.** Task 1 needed them to make the
> compressed campaign winnable. This task adds only the *escalation* half.

In `autoload/game_state.gd`, replace:

```gdscript
const OUTREACH_FUNDS_COST := 1
const OUTREACH_SUPPORT_GAIN := 2
const CAMP_FUNDS_COST := 1
const CAMP_CREW_GAIN := 2
```

with:

```gdscript
const OUTREACH_FUNDS_COST := 1
const OUTREACH_SUPPORT_GAIN := 2
const CAMP_FUNDS_COST := 1
const CAMP_CREW_GAIN := 2
## Each use of a repeatable action raises the price of the next use of that
## same action, so topping up a meter is a decision rather than bookkeeping.
const ACTION_COST_ESCALATION := 1
```

Add to the state variables, immediately after `var bonds_issued: int = 0`:

```gdscript
var action_uses: Dictionary = {}      # StringName -> int
```

In `new_game()`, immediately after `bonds_issued = 0`, add:

```gdscript
	action_uses = {}
```

- [x] **Step 4: Add the cost and affordability functions**

Add these two functions immediately above `take_action()`:

```gdscript
## Current funds price of a repeatable action, rising with each prior use.
## issue_bond is not priced in funds -- it is gated by MAX_BOND_ISSUES.
func action_cost(action: StringName) -> int:
	var uses: int = action_uses.get(action, 0)
	match action:
		&"outreach":
			return OUTREACH_FUNDS_COST + uses * ACTION_COST_ESCALATION
		&"improve_camp":
			return CAMP_FUNDS_COST + uses * ACTION_COST_ESCALATION
		_:
			return 0


## Whether the action is currently allowed. The DecisionPanel renders from this
## so affordability rules live in one place.
func can_take_action(action: StringName) -> bool:
	if game_over:
		return false
	match action:
		&"issue_bond":
			return bonds_issued < MAX_BOND_ISSUES and public_support >= BOND_MIN_SUPPORT
		&"outreach", &"improve_camp":
			return funds >= action_cost(action)
		_:
			return false
```

- [x] **Step 5: Rewrite `take_action()` to use them**

Replace the whole of `take_action()`. This is its current text, including the
bond cap Task 1 added — match it exactly:

```gdscript
func take_action(action: StringName) -> bool:
	if game_over:
		return false
	match action:
		&"issue_bond":
			if public_support < BOND_MIN_SUPPORT:
				return false
			if bonds_issued >= MAX_BOND_ISSUES:
				return false
			bonds_issued += 1
			_set_funds(funds + BOND_FUNDS_GAIN)
			_set_support(public_support - BOND_SUPPORT_COST)
		&"outreach":
			if funds < OUTREACH_FUNDS_COST:
				return false
			_set_funds(funds - OUTREACH_FUNDS_COST)
			_set_support(public_support + OUTREACH_SUPPORT_GAIN)
		&"improve_camp":
			if funds < CAMP_FUNDS_COST:
				return false
			_set_funds(funds - CAMP_FUNDS_COST)
			_set_crew(crew_wellbeing + CAMP_CREW_GAIN)
		_:
			return false
	_check_end_conditions()
	return true
```

> The bond guards move into `can_take_action()` from Step 4, so the replacement
> below drops them from the `match` body. `bonds_issued += 1` stays.

with:

```gdscript
func take_action(action: StringName) -> bool:
	if not can_take_action(action):
		return false
	var cost := action_cost(action)
	match action:
		&"issue_bond":
			bonds_issued += 1
			_set_funds(funds + BOND_FUNDS_GAIN)
			_set_support(public_support - BOND_SUPPORT_COST)
		&"outreach":
			_set_funds(funds - cost)
			_set_support(public_support + OUTREACH_SUPPORT_GAIN)
		&"improve_camp":
			_set_funds(funds - cost)
			_set_crew(crew_wellbeing + CAMP_CREW_GAIN)
		_:
			return false
	action_uses[action] = int(action_uses.get(action, 0)) + 1
	_check_end_conditions()
	return true
```

- [x] **Step 6: Update the DecisionPanel to render live costs**

In `scenes/ui/decision_panel.gd`, replace `refresh_affordability()`:

```gdscript
func refresh_affordability() -> void:
	action_select.set_item_disabled(1, GameState.public_support < GameState.BOND_MIN_SUPPORT)
	action_select.set_item_disabled(2, GameState.funds < GameState.OUTREACH_FUNDS_COST)
	action_select.set_item_disabled(3, GameState.funds < GameState.CAMP_FUNDS_COST)
	_refresh_risk()
```

with:

```gdscript
func refresh_affordability() -> void:
	action_select.set_item_disabled(1, not GameState.can_take_action(&"issue_bond"))
	action_select.set_item_disabled(2, not GameState.can_take_action(&"outreach"))
	action_select.set_item_disabled(3, not GameState.can_take_action(&"improve_camp"))
	var bonds_left := GameState.MAX_BOND_ISSUES - GameState.bonds_issued
	action_select.set_item_text(1, "Issue bond (+%d funds, -%d support) - %d left"
		% [GameState.BOND_FUNDS_GAIN, GameState.BOND_SUPPORT_COST, bonds_left])
	action_select.set_item_text(2, "Community outreach (-%d funds, +%d support)"
		% [GameState.action_cost(&"outreach"), GameState.OUTREACH_SUPPORT_GAIN])
	action_select.set_item_text(3, "Improve the camps (-%d funds, +%d crew)"
		% [GameState.action_cost(&"improve_camp"), GameState.CAMP_CREW_GAIN])
	_refresh_risk()
```

- [x] **Step 6b: Fix the two leftover "season" strings**

Task 1 removed the seasonal calendar but could not touch this file. Two
user-visible strings still contradict the HUD, which now reads "Phase 3 of 24".

Replace line 48:

```gdscript
	end_button.text = "End season"
```

with:

```gdscript
	end_button.text = "End phase"
```

Replace lines 79–80 (the comment as well as the string):

```gdscript
	# roll is skipped entirely, so this is the risk only "if the season passes quietly".
	risk_label.text = "If the season passes quietly: %s chance of %s" % [String(preview["level"]), noun]
```

with:

```gdscript
	# roll is skipped entirely, so this is the risk only "if the phase passes quietly".
	risk_label.text = "If the phase passes quietly: %s chance of %s" % [String(preview["level"]), noun]
```

Finally, the hardcoded bond figure in `ACTION_LABELS` is stale — Task 1 raised
`BOND_FUNDS_GAIN` from 3 to 20. Step 6 overwrites these labels at runtime, so
the player never sees the wrong number, but the source should not lie. Replace:

```gdscript
	"Issue bond (+3 funds, -1 support)",
	"Community outreach (-1 funds, +2 support)",
	"Improve the camps (-1 funds, +2 crew)",
```

with:

```gdscript
	# Placeholder text only -- refresh_affordability() rewrites all three from
	# the live GameState constants and the current escalated costs.
	"Issue bond",
	"Community outreach",
	"Improve the camps",
```

- [x] **Step 7: Add smoke assertions for the cap and escalation**

In `tools/smoke_test.gd`, add the call `_check_economy()` in `_ready()`
immediately after `_check_phase_calendar()`, and add this function at the end:

```gdscript
func _check_economy() -> void:
	GameState.new_game()
	check(GameState.action_cost(&"outreach") == GameState.OUTREACH_FUNDS_COST,
		"first outreach costs the base price")
	GameState.take_action(&"outreach")
	check(GameState.action_cost(&"outreach") == GameState.OUTREACH_FUNDS_COST + GameState.ACTION_COST_ESCALATION,
		"second outreach costs more than the first")
	GameState.new_game()
	var issued := 0
	for i in 10:
		if GameState.take_action(&"issue_bond"):
			issued += 1
		GameState.take_action(&"outreach")
	check(issued == GameState.MAX_BOND_ISSUES,
		"bond issuance is capped at %d (got %d)" % [GameState.MAX_BOND_ISSUES, issued])
	check(not GameState.can_take_action(&"issue_bond"),
		"issuing the cap exhausts the bond action")
	GameState.new_game()
	EventManager.reset()
```

- [x] **Step 8: Run the full harness**

```bash
godot --headless res://tools/smoke_test.tscn
```
Expected: `SMOKE PASS`.

```bash
godot --headless res://tools/sim_test.tscn
```
Expected: `SIM EXPLOIT: peak funds ... = <a number at or below 70>` followed by
`SIM PASS`.

If the canonical run now fails to complete because funds ran out, **STOP and
report** — do not raise `MAX_BOND_ISSUES` or lower `PHASE_OVERHEAD` on your own.

- [x] **Step 9: Commit and stop for review**

```bash
git add -A
git commit -m "fix: bound the economy so no action loop generates unbounded funds

Alternating issue_bond and outreach netted +2 funds and +1 support every two
turns forever, which made bond_crisis, project_cancelled and work_halted
unreachable. Bond issuance is now capped per campaign and repeatable actions
escalate in cost with each use.

Adds a sim exploit probe as the regression guard: a greedy alternating policy
may not outrun phase overhead.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

**STOP. Report the SIM EXPLOIT line from Step 2 and from Step 8, and wait for
review.**

---

### Task 3: Export cards to historian-editable Markdown

Migrates the 26 authored cards out of `.tres` into one Markdown file each. This
task only **writes** Markdown — the game still loads `.tres`. Nothing breaks.

**Files:**
- Create: `tools/export_cards.gd`, `tools/export_cards.tscn`
- Create: `content/cards/` (26 files, generated)
- Create: `content/README.md`

**Interfaces:**
- Produces: `content/cards/<basename>.md` for each `data/events/<basename>.tres`.
  The basename is shared, which is how Task 4 knows where to write back.

- [x] **Step 1: Create the scene shell**

Create `tools/export_cards.tscn` with exactly this content:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tools/export_cards.gd" id="1"]

[node name="ExportCards" type="Node"]
script = ExtResource("1")
```

- [x] **Step 2: Write the exporter**

Create `tools/export_cards.gd`:

```gdscript
extends Node
## One-shot migration: data/events/*.tres -> content/cards/*.md
## Run:  godot --headless res://tools/export_cards.tscn
## The .md basename matches the .tres basename; import_cards.gd writes back to
## the same filename. Safe to re-run: it overwrites the Markdown, never the .tres.

const EVENTS_DIR := "res://data/events"
const CONTENT_DIR := "res://content/cards"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CONTENT_DIR))
	var dir := DirAccess.open(EVENTS_DIR)
	if dir == null:
		push_error("EXPORT FAIL: no %s" % EVENTS_DIR)
		get_tree().quit(1)
		return
	var files := dir.get_files()
	files.sort()
	var written := 0
	for file in files:
		if not (file.ends_with(".tres") or file.ends_with(".tres.remap")):
			continue
		var clean := file.trim_suffix(".remap")
		var card = load(EVENTS_DIR + "/" + clean)
		if card == null or not (card is EventCard):
			push_error("EXPORT FAIL: %s is not an EventCard" % clean)
			get_tree().quit(1)
			return
		var base := clean.trim_suffix(".tres")
		var path := CONTENT_DIR + "/" + base + ".md"
		var out := FileAccess.open(path, FileAccess.WRITE)
		if out == null:
			push_error("EXPORT FAIL: cannot write %s" % path)
			get_tree().quit(1)
			return
		out.store_string(_render(card))
		out.close()
		written += 1
	print("EXPORT OK: wrote %d card files to %s" % [written, CONTENT_DIR])
	get_tree().quit(0)


func _render(card: EventCard) -> String:
	var s := "---\n"
	s += "event_id: %s\n" % card.event_id
	s += "title: %s\n" % card.title
	s += "phase_id: %s\n" % card.phase_id
	s += "location_name: %s\n" % card.location_name
	s += "mile_start: %d\n" % card.mile_start
	s += "mile_end: %d\n" % card.mile_end
	s += "historical_year_start: %d\n" % card.historical_year_start
	s += "historical_year_end: %d\n" % card.historical_year_end
	s += "is_fixed: %s\n" % ("true" if card.is_fixed else "false")
	s += "weight: %s\n" % str(card.weight)
	s += "canonical_choice: %d\n" % card.canonical_choice
	s += "hazard_kind: %s\n" % card.hazard_kind
	s += "required_flags: %s\n" % _join(card.required_flags)
	s += "blocked_by_flags: %s\n" % _join(card.blocked_by_flags)
	s += "---\n\n"
	s += "## Description\n\n%s\n\n" % card.event_description.strip_edges()
	s += "## Historical fact\n\n%s\n\n" % card.historical_fact.strip_edges()
	s += "## Source note\n\n%s\n\n" % card.historical_source_note.strip_edges()
	s += "## Assumption note\n\n%s\n\n" % card.assumption_note.strip_edges()
	for choice in card.choices:
		s += "## Choice: %s\n\n" % choice.label
		s += "funds: %d\n" % choice.funds_delta
		s += "support: %d\n" % choice.public_support_delta
		s += "readiness: %d\n" % choice.water_readiness_delta
		s += "crew: %d\n" % choice.crew_wellbeing_delta
		s += "time: %d\n" % choice.time_delta_seasons
		s += "grants: %s\n" % _join(choice.granted_flags)
		s += "repeat: %s\n\n" % ("true" if choice.repeat_card else "false")
		s += "%s\n\n" % choice.outcome_text.strip_edges()
	return s


func _join(flags: Array) -> String:
	var parts: Array[String] = []
	for f in flags:
		parts.append(String(f))
	return ", ".join(parts)
```

- [x] **Step 3: Run the exporter**

```bash
godot --headless res://tools/export_cards.tscn
```

Expected: `EXPORT OK: wrote 26 card files to res://content/cards`

If it prints any `EXPORT FAIL`, STOP and report.

- [x] **Step 4: Spot-check one generated file**

Open `content/cards/11_the_803_foot_month.md` and confirm all four are true:

1. The frontmatter block contains `event_id: the_803_foot_month`.
2. `## Historical fact` is followed by prose beginning "City crews and
   contractors competed".
3. There are exactly two `## Choice:` sections.
4. The first choice block contains `grants: foothill_tunnel_complete`.

If any is false, STOP and report which.

- [x] **Step 5: Write the historian's instructions**

Create `content/README.md`:

```markdown
# Editing Hetchy Trail card content

Every encounter in the game is one file in `cards/`. You can edit them in any
text editor. You do not need to install or understand the game engine.

## What a card file looks like

The block between the two `---` lines holds the card's settings. Below it,
each `## Heading` starts a section of writing.

- **Description** — what the player is told is happening, before they choose.
- **Historical fact** — what actually happened. Shown after the player chooses.
- **Source note** — where the fact comes from.
- **Assumption note** — anywhere the game departs from the record. **Every
  departure must be recorded here.** This is a hard project rule.
- **Choice: <name>** — one option the player can pick. The lines beginning
  `funds:`, `support:`, `readiness:`, `crew:`, `time:`, `grants:` and `repeat:`
  are the game effects; the paragraph underneath is what the player reads after
  picking it.

## Safe to change freely

All the prose: titles, descriptions, historical facts, source notes, assumption
notes, choice names, and outcome paragraphs. Fix wording, correct facts, add
detail — none of it can break the game.

## Change only with the developer

`event_id`, `grants:`, `required_flags`, `blocked_by_flags`, `hazard_kind`,
and `canonical_choice`. These wire the card into the rest of the campaign, and
a wrong value will stop the game building.

The number effects (`funds:`, `crew:` and so on) run from -5 to +5, where 1 is
minor, 2 substantial, 3 severe. Adjusting these changes game balance, so tell
the developer when you do.

## A note on seasons

The game advances in construction phases, not calendar seasons. Card writing
may mention winter, snow or heat for atmosphere, but the game does not simulate
weather, and the timing of those mentions is not exact. This is recorded in the
affected cards' assumption notes.

## Applying your edits

The developer runs one command to rebuild the game's data from these files:

    godot --headless res://tools/import_cards.tscn

If anything in a file is malformed, that command stops and names the file and
line, so a mistake is always caught rather than silently ignored.
```

- [x] **Step 6: Confirm the harness is untouched**

This task changed no game code, so both must still pass unchanged.

```bash
godot --headless res://tools/smoke_test.tscn
```
Expected: `SMOKE PASS`.

```bash
godot --headless res://tools/sim_test.tscn
```
Expected: `SIM PASS`.

- [x] **Step 7: Commit and stop for review**

```bash
git add -A
git commit -m "feat: export card content to historian-editable Markdown

One .md per card in content/cards/, sharing the .tres basename. Prose lives as
prose so an agency historian can edit titles, descriptions, historical facts,
source notes, assumption notes and outcome text without engine knowledge.

Game data is unchanged; the game still loads .tres. content/README.md documents
what is safe to edit and what needs the developer.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

**STOP. Report the EXPORT OK line and wait for review.**

---

### Task 4: Import Markdown back to `.tres`, with loud validation

Closes the loop: the historian edits Markdown, one command rebuilds the game
data. The round trip is its own proof — if import is lossless, the existing 207+
smoke assertions still pass against regenerated `.tres` files.

**Files:**
- Create: `tools/import_cards.gd`, `tools/import_cards.tscn`
- Modify: `tools/smoke_test.gd`

**Interfaces:**
- Consumes: `content/cards/*.md` produced by Task 3.
- Produces: regenerated `data/events/*.tres`. Exits 1 with a file-and-line
  message on any malformed input.

- [x] **Step 1: Create the scene shell**

Create `tools/import_cards.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tools/import_cards.gd" id="1"]

[node name="ImportCards" type="Node"]
script = ExtResource("1")
```

- [x] **Step 2: Write the importer**

Create `tools/import_cards.gd`:

```gdscript
extends Node
## Builds data/events/*.tres from content/cards/*.md
## Run:  godot --headless res://tools/import_cards.tscn
## Exits 0 on success, 1 with a file-and-line message on malformed input.
## Never silently skips a card -- silent skipping was the defect this replaces.

const CONTENT_DIR := "res://content/cards"
const EVENTS_DIR := "res://data/events"
const EFFECT_KEYS := ["funds", "support", "readiness", "crew", "time", "grants", "repeat"]

var errors: Array[String] = []


func _ready() -> void:
	var dir := DirAccess.open(CONTENT_DIR)
	if dir == null:
		print("IMPORT FAIL: no %s -- run export_cards first" % CONTENT_DIR)
		get_tree().quit(1)
		return
	var files := dir.get_files()
	files.sort()
	var built := 0
	for file in files:
		if not file.ends_with(".md"):
			continue
		var card := _parse(CONTENT_DIR + "/" + file)
		if card == null:
			continue
		var out := EVENTS_DIR + "/" + file.trim_suffix(".md") + ".tres"
		var err := ResourceSaver.save(card, out)
		if err != OK:
			errors.append("%s: could not write %s (error %d)" % [file, out, err])
			continue
		built += 1
	if errors.is_empty():
		print("IMPORT OK: built %d cards into %s" % [built, EVENTS_DIR])
		get_tree().quit(0)
	else:
		for e in errors:
			print("IMPORT FAIL: %s" % e)
		print("IMPORT FAIL: %d problem(s); no partial run is trustworthy" % errors.size())
		get_tree().quit(1)


func _parse(path: String) -> EventCard:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		errors.append("%s: cannot open" % path)
		return null
	var lines := f.get_as_text().split("\n")
	f.close()
	var name := path.get_file()

	var card := EventCard.new()
	var meta := {}
	var i := 0
	# --- frontmatter ---
	if i >= lines.size() or lines[i].strip_edges() != "---":
		errors.append("%s line 1: must start with ---" % name)
		return null
	i += 1
	while i < lines.size() and lines[i].strip_edges() != "---":
		var line: String = lines[i]
		if line.strip_edges() != "":
			var colon := line.find(":")
			if colon < 0:
				errors.append("%s line %d: expected 'key: value', got '%s'" % [name, i + 1, line])
				return null
			meta[line.substr(0, colon).strip_edges()] = line.substr(colon + 1).strip_edges()
		i += 1
	if i >= lines.size():
		errors.append("%s: frontmatter is never closed with ---" % name)
		return null
	i += 1

	for key in ["event_id", "title", "mile_start", "mile_end", "canonical_choice"]:
		if not meta.has(key):
			errors.append("%s: frontmatter is missing required key '%s'" % [name, key])
			return null

	card.event_id = StringName(meta["event_id"])
	card.title = meta.get("title", "")
	card.phase_id = StringName(meta.get("phase_id", ""))
	card.location_name = meta.get("location_name", "")
	card.mile_start = int(meta["mile_start"])
	card.mile_end = int(meta["mile_end"])
	card.historical_year_start = int(meta.get("historical_year_start", "0"))
	card.historical_year_end = int(meta.get("historical_year_end", "0"))
	card.is_fixed = meta.get("is_fixed", "false") == "true"
	card.weight = float(meta.get("weight", "1.0"))
	card.canonical_choice = int(meta["canonical_choice"])
	card.hazard_kind = StringName(meta.get("hazard_kind", ""))
	card.required_flags = _split(meta.get("required_flags", ""))
	card.blocked_by_flags = _split(meta.get("blocked_by_flags", ""))

	# --- body sections ---
	var section := ""
	var buffer: Array[String] = []
	var choices: Array[EventChoice] = []
	var choice: EventChoice = null

	while i <= lines.size():
		var raw: String = lines[i] if i < lines.size() else "## __END__"
		if raw.begins_with("## "):
			_flush(card, section, buffer, choice)
			if choice != null:
				choices.append(choice)
				choice = null
			buffer = []
			section = raw.substr(3).strip_edges()
			if section.begins_with("Choice:"):
				choice = EventChoice.new()
				choice.label = section.substr(7).strip_edges()
		elif choice != null and _effect_line(raw):
			var colon := raw.find(":")
			var key := raw.substr(0, colon).strip_edges()
			var val := raw.substr(colon + 1).strip_edges()
			match key:
				"funds": choice.funds_delta = int(val)
				"support": choice.public_support_delta = int(val)
				"readiness": choice.water_readiness_delta = int(val)
				"crew": choice.crew_wellbeing_delta = int(val)
				"time": choice.time_delta_seasons = int(val)
				"grants": choice.granted_flags = _split(val)
				"repeat": choice.repeat_card = val == "true"
		else:
			buffer.append(raw)
		i += 1

	if choices.is_empty():
		errors.append("%s: has no '## Choice: <name>' section" % name)
		return null
	if card.canonical_choice < 0 or card.canonical_choice >= choices.size():
		errors.append("%s: canonical_choice %d is out of range (%d choices)"
			% [name, card.canonical_choice, choices.size()])
		return null
	if card.event_description.strip_edges() == "":
		errors.append("%s: '## Description' section is empty" % name)
		return null
	if card.historical_fact.strip_edges() == "":
		errors.append("%s: '## Historical fact' is empty -- the teaching layer is required" % name)
		return null
	if card.assumption_note.strip_edges() == "":
		errors.append("%s: '## Assumption note' is empty -- every deviation must be recorded" % name)
		return null
	card.choices = choices
	return card


## True when the line is one of the choice effect keys, e.g. "funds: -1".
func _effect_line(line: String) -> bool:
	var colon := line.find(":")
	if colon < 0:
		return false
	return EFFECT_KEYS.has(line.substr(0, colon).strip_edges())


func _flush(card: EventCard, section: String, buffer: Array[String], choice: EventChoice) -> void:
	var text := "\n".join(buffer).strip_edges()
	match section:
		"Description": card.event_description = text
		"Historical fact": card.historical_fact = text
		"Source note": card.historical_source_note = text
		"Assumption note": card.assumption_note = text
		_:
			if choice != null:
				choice.outcome_text = text


func _split(csv: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for part in csv.split(","):
		var p := part.strip_edges()
		if p != "":
			out.append(StringName(p))
	return out
```

- [x] **Step 3: Run the importer**

```bash
godot --headless res://tools/import_cards.tscn
```

Expected: `IMPORT OK: built 26 cards into res://data/events`

If it prints `IMPORT FAIL`, read the named file and line. **Do not edit card
prose to make it pass** — if the failure is in authored content, STOP and
report.

- [x] **Step 4: Prove the round trip is lossless**

The `.tres` files were just regenerated from Markdown. The existing smoke
assertions must still hold against them.

```bash
godot --headless res://tools/smoke_test.tscn
```
Expected: `SMOKE PASS`.

```bash
godot --headless res://tools/sim_test.tscn
```
Expected: `SIM PASS`.

```bash
git diff --stat data/events
```
Expected: some `.tres` files show formatting churn (property ordering, float
precision). That is fine. **What must NOT appear is a change in any prose
string.** Run:

```bash
git diff data/events | grep -E "^[-+].*(historical_fact|assumption_note|outcome_text|event_description)" | head -40
```
Expected: no output, or pairs of `-`/`+` lines that are byte-identical apart
from escaping. If any prose text actually differs, STOP and report.

- [x] **Step 5: Add a validation assertion to the smoke test**

In `tools/smoke_test.gd`, add `_check_content_pipeline()` to `_ready()` after
`_check_economy()`, and add at the end of the file:

```gdscript
func _check_content_pipeline() -> void:
	var dir := DirAccess.open("res://content/cards")
	check(dir != null, "content/cards exists")
	if dir == null:
		return
	var md := 0
	for f in dir.get_files():
		if f.ends_with(".md"):
			md += 1
	check(md == EventManager.deck.size(),
		"one Markdown source per card (%d md, %d cards)" % [md, EventManager.deck.size()])
	for card in EventManager.deck:
		check(card.assumption_note != "",
			"card %s records its assumptions" % card.event_id)
		check(card.historical_source_note != "",
			"card %s cites a source" % card.event_id)
```

- [x] **Step 6: Run the harness again**

```bash
godot --headless res://tools/smoke_test.tscn
```
Expected: `SMOKE PASS`.

- [x] **Step 7: Commit and stop for review**

```bash
git add -A
git commit -m "feat: build card data from Markdown, failing loudly on bad input

content/cards/*.md is now the source of truth; import_cards regenerates
data/events/*.tres. Malformed input halts the build naming file and line,
replacing _load_deck()'s silent skip. Missing historical_fact or
assumption_note is a build failure, so the teaching layer cannot rot.

The round trip is proven by the existing smoke and sim suites passing against
regenerated resources.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

**STOP. Report the IMPORT OK line and the `git diff --stat data/events` output,
and wait for review.**

---

### Task 5: Decouple card art from card data

Art currently lives inside the card as a hand-set `Texture2D`, so adding an
image means editing the same file the historian is reviewing. After this task,
art is added by dropping a file into a folder.

**Files:**
- Modify: `resources/event_card.gd`
- Modify: `scenes/ui/event_panel.gd`
- Modify: `tools/export_cards.gd` (drop the removed property)
- Create: `assets/art/cards/.gitkeep`
- Modify: `docs/art_assets.md`
- Modify: `tools/smoke_test.gd`

**Interfaces:**
- Produces: `EventCard.art_path() -> String` and
  `EventCard.load_art() -> Texture2D` (returns `null` when no file exists).
- `EventCard.archival_photo` is **removed**.

- [x] **Step 1: Add the convention lookup to EventCard**

In `resources/event_card.gd`, delete this line:

```gdscript
@export var archival_photo: Texture2D
```

Add these functions at the end of the file:

```gdscript
## Card art resolves by event_id convention rather than a stored reference, so
## images and card text never collide in the same file. Final art wins over a
## generated placeholder.
func art_path() -> String:
	var final_art := "res://assets/art/cards/%s.png" % event_id
	if ResourceLoader.exists(final_art):
		return final_art
	var placeholder := "res://assets/art/cards/%s.placeholder.png" % event_id
	if ResourceLoader.exists(placeholder):
		return placeholder
	return ""


## The card's texture, or null when no art has been produced yet.
func load_art() -> Texture2D:
	var path := art_path()
	if path == "":
		return null
	var res := load(path)
	return res if res is Texture2D else null
```

- [x] **Step 2: Point the EventPanel at it**

In `scenes/ui/event_panel.gd` there are exactly two edits.

**2a.** Replace lines 57–58 inside `show_card()`:

```gdscript
	photo_rect.texture = card.archival_photo
	photo_rect.visible = card.archival_photo != null
```

with:

```gdscript
	var art := card.load_art()
	photo_rect.texture = art
	photo_rect.visible = art != null
```

**2b.** Replace the doc comment on line 3:

```gdscript
## ("What really happened" + assumption note + optional archival photo).
```

with:

```gdscript
## ("What really happened" + assumption note + optional card art, resolved by
## event_id convention from assets/art/cards/).
```

- [x] **Step 3: Drop the removed property from the exporter**

In `tools/export_cards.gd`, confirm `_render()` does not reference
`archival_photo`. It does not in the Task 3 listing — if you added it, remove
it now.

Create the art folder so it exists in git:

```bash
mkdir -p assets/art/cards
touch assets/art/cards/.gitkeep
```

- [x] **Step 4: Add a smoke assertion**

In `tools/smoke_test.gd`, add `_check_card_art()` to `_ready()` after
`_check_content_pipeline()`, and add at the end:

```gdscript
func _check_card_art() -> void:
	for card in EventManager.deck:
		# Art is optional during production; the contract is that a missing
		# image degrades to empty rather than erroring.
		var path := card.art_path()
		check(path == "" or ResourceLoader.exists(path),
			"card %s art path resolves or is empty" % card.event_id)
```

- [x] **Step 5: Update the art documentation**

In `docs/art_assets.md`, replace this sentence in section 3a:

```markdown
Each `EventCard` already has an `archival_photo: Texture2D` slot, and the
EventPanel (plan Task 6) renders it above the description. Target one image per
card. Priority subjects, grouped by division:
```

with:

```markdown
Card art resolves **by filename convention** — no engine editing required.
Drop an image at `assets/art/cards/<event_id>.png` and the card picks it up;
`<event_id>.placeholder.png` is used until final art arrives. The `event_id`
for each card is the first line of its file in `content/cards/`.

This means art and historical content are fully parallel: images are added by
dropping files in a folder, touching nothing the historian is editing. Target
one image per card. Priority subjects, grouped by division:
```

In section 5, replace step 4 of the archival workflow:

```markdown
4. In the Godot Inspector, set the matching card's `archival_photo` property to
   the imported texture.
```

with:

```markdown
4. Name the file `<event_id>.png` and place it in `assets/art/cards/`. No
   editor step is needed — the card finds it by name.
```

- [x] **Step 6: Run the full harness**

```bash
godot --headless res://tools/smoke_test.tscn
```
Expected: `SMOKE PASS`.

```bash
godot --headless res://tools/sim_test.tscn
```
Expected: `SIM PASS`.

- [x] **Step 7: Verify art actually loads end to end**

```bash
godot --headless res://tools/export_cards.tscn
```
Expected: `EXPORT OK: wrote 26 card files`.

```bash
godot --headless res://tools/import_cards.tscn
```
Expected: `IMPORT OK: built 26 cards`.

```bash
godot --headless res://tools/smoke_test.tscn
```
Expected: `SMOKE PASS`. This confirms the full pipeline survives the property
removal.

- [x] **Step 8: Commit and stop for review**

```bash
git add -A
git commit -m "feat: resolve card art by event_id convention

Removes EventCard.archival_photo. Art now loads from
assets/art/cards/<event_id>.png, falling back to <event_id>.placeholder.png,
degrading to no image when neither exists.

Art production and historian content review no longer touch the same files, so
the two tracks can run in parallel. art_assets.md updated to match.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

**STOP. P1 is complete. Report all five task outcomes and wait for review.**

---

### Task 6: Revive the dead hazard system

**Measured defect.** A canonical campaign runs 20 turns: **15 carry a fixed
spine card**, 2 a texture card, 3 nothing.
[event_manager.gd:50](../../../autoload/event_manager.gd#L50) returns a due
fixed card *before* the pace-risk roll executes, so the roll runs on 5 turns out
of 20. At STEADY's 10% that is **0.5 expected hazards per campaign** — observed
0. The pace-risk mechanic, its five authored hazard cards, and the DecisionPanel
telegraph are all dead weight.

The system was built for a 73-turn campaign with ~50 empty turns. There are now
3. Suppressing the roll on milestone turns made sense when milestone turns were
rare; at 75% density it silences the mechanic entirely.

**The fix:** the roll happens every turn. When it hits, the hazard resolves
*first*, then the milestone card follows in the same turn. `try_draw()` becomes
a queue so no card is lost and the schedule does not slip — a hazard must not
cost a turn, or it would push the calendar and break the `matched_history`
calibration from Task 1b.

Expected after this change: ~2 hazards per campaign at STEADY, ~6 at PUSHED.
Pace becomes a real decision again.

**Files:**
- Modify: `autoload/event_manager.gd`
- Modify: `scenes/journey/journey.gd`
- Modify: `scenes/ui/decision_panel.gd`
- Modify: `tools/smoke_test.gd`, `tools/sim_test.gd`

**Interfaces:**
- Produces: `EventManager.try_draw_queue() -> Array[EventCard]`, returning 0, 1
  or 2 cards in resolution order (hazard first).
- `EventManager.try_draw()` is **removed**. All four call sites are updated
  below.

- [x] **Step 1: Make the sim assert that hazards actually fire**

In `tools/sim_test.gd`, find the win condition and add a third clause. Replace:

```gdscript
	# Two bonds at BOND_FUNDS_GAIN is the entire authorized income; anything
	# above that means a repeatable loop is manufacturing funds.
	win = win and exploit_peak <= GameState.START_FUNDS + (GameState.MAX_BOND_ISSUES * GameState.BOND_FUNDS_GAIN)
```

with:

```gdscript
	# Two bonds at BOND_FUNDS_GAIN is the entire authorized income; anything
	# above that means a repeatable loop is manufacturing funds.
	win = win and exploit_peak <= GameState.START_FUNDS + (GameState.MAX_BOND_ISSUES * GameState.BOND_FUNDS_GAIN)
	# The pace-risk mechanic must be alive in real play, not just in the probes.
	# This is the guard that would have caught the fixed-spine suppression.
	win = win and hazards_seen > 0
```

- [x] **Step 2: Run the sim and confirm it fails**

```bash
godot --headless res://tools/sim_test.tscn
```

Expected: `SIM RESULT` ending in `0 hazards`, then `SIM FAIL`. That is the
defect reproducing.

- [x] **Step 3: Replace `try_draw()` with a queue**

In `autoload/event_manager.gd`, replace the whole of `try_draw()`:

```gdscript
func try_draw() -> EventCard:
	if GameState.game_over:
		return null
	var available := _available_cards()
	for card in available:
		if card.is_fixed:
			return _draw(card)
	# Pace-risk: the season just worked may trigger a hazard before texture cards.
	# A due fixed spine card returns above and skips this roll, so on milestone
	# turns the real hazard chance is 0 -- the DecisionPanel telegraph is worded
	# "if the season passes quietly" to stay honest about that.
	var risk := _risk_for(GameState.work_pace)
	if randf() < float(risk["chance"]):
		var hazard := _pick_hazard(risk["kind"])
		if hazard != null:
			return _draw(hazard)
	if available.is_empty() or randf() > event_chance:
		return null
	return _draw(_weighted_pick(available))
```

with:

```gdscript
## Cards to resolve this turn, in order. Empty, one, or two entries.
##
## The pace-risk roll runs on EVERY turn, including milestone turns. It used to
## be skipped whenever a fixed card was due, which silenced it: the fixed spine
## occupies 15 of a campaign's 20 turns, so the roll fired on 5. A hazard is
## queued AHEAD of the milestone rather than replacing it, so no card is lost
## and a hazard never costs the player a turn.
func try_draw_queue() -> Array[EventCard]:
	var queue: Array[EventCard] = []
	if GameState.game_over:
		return queue
	var available := _available_cards()
	var risk := _risk_for(GameState.work_pace)
	if randf() < float(risk["chance"]):
		var hazard := _pick_hazard(risk["kind"])
		if hazard != null:
			queue.append(_draw(hazard))
	for card in available:
		if card.is_fixed:
			queue.append(_draw(card))
			return queue
	# A texture card only when no milestone is due.
	if available.is_empty() or randf() > event_chance:
		return queue
	queue.append(_draw(_weighted_pick(available)))
	return queue
```

- [x] **Step 4: Teach Journey to play a queue**

In `scenes/journey/journey.gd`, replace this line near the top:

```gdscript
## The only script that calls GameState.advance_turn() and EventManager.try_draw().
```

with:

```gdscript
## The only script that calls GameState.advance_turn() and
## EventManager.try_draw_queue().
```

Replace:

```gdscript
var current_card: EventCard
```

with:

```gdscript
var current_card: EventCard
var pending: Array[EventCard] = []
```

Replace the tail of `_on_decisions()`:

```gdscript
	current_card = EventManager.try_draw()
	if current_card != null:
		event_panel.show_card(current_card)
	else:
		_begin_decide()
```

with:

```gdscript
	pending = EventManager.try_draw_queue()
	_show_next()
```

Replace the whole of `_on_event_choice()`:

```gdscript
func _on_event_choice(index: int) -> void:
	var card := current_card
	current_card = null
	EventManager.resolve_choice(card, index)
	if not GameState.game_over:
		_begin_decide()
```

with:

```gdscript
func _on_event_choice(index: int) -> void:
	var card := current_card
	current_card = null
	EventManager.resolve_choice(card, index)
	_show_next()


## Shows the next queued card, or hands the turn back to the player when the
## queue is empty. A hazard that ends the game stops the queue here.
func _show_next() -> void:
	if GameState.game_over:
		pending.clear()
		return
	if pending.is_empty():
		_begin_decide()
		return
	current_card = pending.pop_front()
	event_panel.show_card(current_card)
```

- [x] **Step 5: Make the telegraph honest**

The hedge in `scenes/ui/decision_panel.gd` existed only because of the
suppression this task removes. Replace:

```gdscript
	# Worded as a conditional: on turns a fixed milestone card is due, the hazard
	# roll is skipped entirely, so this is the risk only "if the phase passes quietly".
	risk_label.text = "If the phase passes quietly: %s chance of %s" % [String(preview["level"]), noun]
```

with:

```gdscript
	# The pace-risk roll now runs every turn, milestone or not, so this reads
	# as a plain statement rather than a conditional.
	risk_label.text = "This phase: %s chance of %s" % [String(preview["level"]), noun]
```

- [x] **Step 6: Update the two harness call sites**

In `tools/sim_test.gd` there are two. Replace both occurrences of:

```gdscript
		var card := EventManager.try_draw()
		if card != null:
			EventManager.resolve_choice(card, card.canonical_choice)
```

with:

```gdscript
		for card in EventManager.try_draw_queue():
			if GameState.game_over:
				break
			EventManager.resolve_choice(card, card.canonical_choice)
```

In `tools/smoke_test.gd`, replace the body of `_check_first_turn()`:

```gdscript
	var card := EventManager.try_draw()
	check(card != null and card.event_id == &"cut_the_first_road",
		"first fixed card is Cut the First Road")
	if card != null:
		EventManager.resolve_choice(card, card.canonical_choice)
		check(GameState.has_flag(&"high_sierra_access_complete"),
			"resolving the road card grants high_sierra_access_complete")
```

with:

```gdscript
	# The turn may queue a hazard ahead of the milestone, so the spine card is
	# the LAST entry, not necessarily the only one.
	var queue := EventManager.try_draw_queue()
	check(not queue.is_empty() and queue.back().event_id == &"cut_the_first_road",
		"the first milestone card is Cut the First Road")
	for card in queue:
		EventManager.resolve_choice(card, card.canonical_choice)
	check(GameState.has_flag(&"high_sierra_access_complete"),
		"resolving turn 1 grants high_sierra_access_complete")
```

- [x] **Step 7: Update the UI scene check for queued turns**

Still in `tools/smoke_test.gd`, inside `_check_ui_scenes()`, replace:

```gdscript
	check(journey.event_panel.visible, "turn 1 shows the first fixed card")
	journey.event_panel._on_choice(0)
	check(GameState.miles_built > 0.0 and not GameState.has_flag(&"high_sierra_access_complete"),
		"choosing shows the consequence beat but does not resolve yet")
	journey.event_panel._on_continue(0)
	check(GameState.has_flag(&"high_sierra_access_complete"), "Continue resolves and grants the flag")
```

with:

```gdscript
	check(journey.event_panel.visible, "turn 1 shows a card")
	journey.event_panel._on_choice(0)
	check(not GameState.has_flag(&"high_sierra_access_complete"),
		"choosing shows the consequence beat but does not resolve yet")
	# Turn 1 may queue a hazard ahead of the milestone; drain the whole queue.
	var guard := 0
	while journey.event_panel.visible and guard < 5:
		guard += 1
		journey.event_panel._on_choice(0)
		journey.event_panel._on_continue(0)
	check(guard < 5, "the turn-1 queue drains instead of looping")
	check(GameState.has_flag(&"high_sierra_access_complete"),
		"draining turn 1 resolves the milestone and grants its flag")
```

- [x] **Step 8: Confirm no `try_draw` references survive**

```bash
grep -rn "try_draw()" --include=*.gd .
```
Expected: **no output.** If anything prints, update it and re-run.

- [x] **Step 9: Run the full harness**

```bash
godot --headless res://tools/smoke_test.tscn
```
Expected: `SMOKE PASS`.

```bash
godot --headless res://tools/sim_test.tscn
```
Expected: `SIM PASS`, with a hazard count **greater than 0** in `SIM RESULT`.

Then confirm the calibration survived:

- `grade=matched_history` must still hold. If it has slipped to
  `behind_history`, **STOP and report** — a hazard has cost a turn somewhere,
  which this design forbids. Do not adjust `CALENDAR_PHASES` to compensate.

- [x] **Step 10: Commit**

```bash
git add -A
git commit -m "fix: revive the pace-risk mechanic the compressed campaign silenced

The fixed spine occupies 15 of a campaign's 20 turns, and a due fixed card
returned before the hazard roll ran -- so the roll fired on 5 turns and produced
0.5 expected hazards. The mechanic, its five authored hazard cards, and the
DecisionPanel telegraph were all dead weight.

try_draw() becomes try_draw_queue(). The roll now runs every turn and a hazard
is queued ahead of the milestone rather than replacing it, so no card is lost
and a hazard never costs a turn -- which would otherwise push the calendar and
break the matched_history calibration.

sim_test now asserts hazards_seen > 0: the guard that would have caught this.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

**STOP. Report the SIM RESULT line including the hazard count and grade.**

---

## Definition of done for P1

All five boxes below must be true before P2 begins:

- [x] `godot --headless res://tools/smoke_test.tscn` prints `SMOKE PASS`.
- [x] `godot --headless res://tools/sim_test.tscn` prints `SIM PASS` with
  `turns` between 20 and 28, `grade=matched_history`, and `SIM EXPLOIT` peak
  funds at or below 70.
- [x] Editing prose in a `content/cards/*.md` file and running
  `import_cards.tscn` changes what the game shows.
- [x] Dropping `assets/art/cards/<event_id>.png` makes that image appear on the
  card, with no editor step.
- [x] `docs/ROADMAP.md` P1 row is marked Done.

## Deferred out of P1 (do not do these here)

- Renaming `RouteSegment.winter_sensitive` to `railroad_dependent` — needs a
  `.tres` migration, since renaming the export silently drops the value.
- Replacing the two bond issuances with the Make the Case set piece — P3.
- Adding `minigame_id` and the tier→choice mapping to `EventCard` — P2 owns the
  minigame contract.
- Water readiness as build quality — still an open decision in the spec.
