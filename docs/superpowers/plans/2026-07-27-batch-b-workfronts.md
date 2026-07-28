# Batch B — Workfront Progression Implementation Plan

> **For agentic workers:** Steps use checkbox (`- [ ]`) syntax. Do steps **in
> order**. Never skip a verification step. Tick a box only after running its
> verification and seeing the expected output.

**Goal:** Replace the linear card-spine progression with six workfronts the
player allocates turns across, so pace becomes a real decision and `miles_built`
becomes an honest aggregate of what has been built.

**Design:** [workfront progression spec](../specs/2026-07-27-workfront-progression-design.md).

**Architecture:** Progress lives in `GameState` as a parallel float array
indexed like `segments` — **not** on the `RouteSegment` resources, which are
shared and cached. Cards are re-anchored to fire at progress thresholds within
their own front. **No card or segment data changes.**

**Tech Stack:** Godot 4.7, GDScript. No new dependencies.

## Global Constraints

- **Five metrics only.** Front progress is internal state, not a player
  resource, and is never displayed as one.
- **All game logic lives in `autoload/` and `resources/`.**
- **Never edit prose or data in `content/`, `data/events/` or
  `data/segments/`.** If a test fails because of card content, STOP and report.
- **No new dependencies.** No GPL.
- **A failing harness is never committed.**
- Godot is on `PATH` as `godot`, version `4.7.stable`.

## Baseline (verified 2026-07-27 at commit `0ba0214`)

```bash
godot --headless res://tools/smoke_test.tscn
```
`SMOKE PASS (316 checks)`

```bash
godot --headless res://tools/sim_test.tscn
```
`SIM PASS: system_complete, grade=matched_history`

```bash
godot --headless res://tools/layout_test.tscn
```
`LAYOUT PASS (265 checks)`

- [ ] **Step 0: Confirm all three.** If any fails, STOP and report.

## Batching

**Larger batches than P1.** Three worker tasks in two sessions, then a tuning
pass the reviewer runs.

| Session | Tasks | Why grouped |
|---|---|---|
| 1 | **Task 1** alone | The model and card re-anchoring are one atomic change — the harness cannot be green in between. Largest and least visible if wrong. |
| 2 | **Tasks 2 and 3** | UI and instrumentation. Both mechanical, both fail loudly. |
| 3 | Tuning | Iterative measurement against the spec's success criteria. **Reviewer, not worker.** |

**STOP and report — do not improvise — when:** a verification fails twice after
your best fix; a step's expected output does not match what you see; quoted
"replace this" code does not match the file exactly; a step needs a decision the
plan does not spell out.

---

## Task 1: The workfront model

Everything in this task lands together. Do not commit partway.

**Files:**
- Modify: `autoload/game_state.gd`
- Modify: `autoload/event_manager.gd`
- Modify: `tools/smoke_test.gd`, `tools/sim_test.gd`

**Interfaces produced:**
- `GameState.front_progress: Array[float]` — one per segment, 0.0–1.0
- `GameState.current_front: int`
- `GameState.FRONT_REQUIRES: Dictionary` — front index → gating flag
- `GameState.front_is_open(index: int) -> bool`
- `GameState.front_count() -> int`
- `GameState.set_front(index: int) -> bool`
- `EventManager.front_of_card(card: EventCard) -> int`
- `GameState.current_segment()` and `_build_miles()` are **removed**.

- [ ] **Step 1: Write the failing tests**

In `tools/smoke_test.gd`, add `_check_workfronts()` to `_ready()` immediately
after `_check_phase_calendar()`, and add at the end of the file:

```gdscript
## The six fronts, their gating, and the progress model.
func _check_workfronts() -> void:
	GameState.new_game()
	check(GameState.front_count() == 6, "six workfronts (got %d)" % GameState.front_count())
	check(GameState.front_progress.size() == 6, "one progress entry per front")
	for p in GameState.front_progress:
		check(p == 0.0, "every front starts at zero progress")
	# Fronts 1, 4, 5 and 6 (0-indexed 0, 3, 4, 5) are open from turn one.
	check(GameState.front_is_open(0), "front 1 is open immediately")
	check(GameState.front_is_open(3), "front 4 is open immediately")
	check(GameState.front_is_open(4), "front 5 is open immediately")
	check(GameState.front_is_open(5), "front 6 is open immediately")
	# Fronts 2 and 3 are gated on flags earlier fronts grant.
	check(not GameState.front_is_open(1), "front 2 is closed until power exists")
	check(not GameState.front_is_open(2), "front 3 is closed until Moccasin power exists")
	check(not GameState.set_front(1), "a closed front cannot be selected")
	GameState.grant_flag(&"construction_power_available")
	check(GameState.front_is_open(1), "granting power opens front 2")
	check(GameState.set_front(1), "an open front can be selected")
	# Working a front advances only that front.
	GameState.new_game()
	GameState.set_front(0)
	GameState.work_pace = GameState.Pace.STEADY
	GameState.advance_turn()
	check(GameState.front_progress[0] > 0.0, "working front 1 advances it")
	check(GameState.front_progress[3] == 0.0, "working front 1 leaves front 4 alone")
	check(GameState.miles_built > 0.0, "front progress raises the mile aggregate")
	# Pushing beats steady on the same front.
	GameState.new_game()
	GameState.set_front(0)
	GameState.work_pace = GameState.Pace.STEADY
	GameState.advance_turn()
	var steady := GameState.front_progress[0]
	GameState.new_game()
	GameState.set_front(0)
	GameState.work_pace = GameState.Pace.PUSHED
	GameState.advance_turn()
	check(GameState.front_progress[0] > steady, "pushing advances a front faster than steady")
	# A front caps at 1.0 and never exceeds it.
	GameState.new_game()
	GameState.set_front(0)
	for i in 40:
		GameState.work_pace = GameState.Pace.PUSHED
		GameState.advance_turn()
	check(GameState.front_progress[0] <= 1.0, "front progress never exceeds 1.0")
	GameState.new_game()
	EventManager.reset()
```

- [ ] **Step 2: Run it and confirm it fails**

```bash
godot --headless res://tools/smoke_test.tscn
```
Expected: `SMOKE FAIL`, or a parse error naming `front_count` / `front_progress`.

- [ ] **Step 3: Add the front state to GameState**

In `autoload/game_state.gd`, add after `const NO_RAILROAD_FACTOR := 0.4`:

```gdscript
## TUNING KNOB (Task 1 Step 9). Progress a front gains in one STEADY turn
## before its build_rate_modifier and crew factor apply. Six fronts across a
## 24-turn budget means roughly four turns each.
const FRONT_BASE_PROGRESS := 0.33
const PACE_FACTOR := {
	Pace.REST: 0.0,
	Pace.STEADY: 1.0,
	Pace.PUSHED: 1.6,
}
## Fronts 2 and 3 wait on power earlier fronts provide. Fronts 4, 5 and 6 are
## deliberately ungated: historically they were gated by money and political
## priority, not permission, which the funds and turn budget already model.
const FRONT_REQUIRES := {
	1: &"construction_power_available",
	2: &"moccasin_power_available",
}
```

Replace:

```gdscript
var miles_built: float = 0.0
```

with:

```gdscript
var miles_built: float = 0.0          # derived aggregate; see _recompute_miles()
var front_progress: Array[float] = [] # 0.0-1.0 per segment, parallel to segments
var current_front: int = 0            # the front the player works this turn
```

In `new_game()`, replace `miles_built = 0.0` with:

```gdscript
	miles_built = 0.0
	front_progress.clear()
	for i in segments.size():
		front_progress.append(0.0)
	current_front = 0
```

- [ ] **Step 4: Add the front API**

Add these four functions immediately above `advance_turn()`:

```gdscript
func front_count() -> int:
	return segments.size()


## A front is workable once the flag that opens it has been granted. Fronts
## without an entry in FRONT_REQUIRES are open from turn one.
func front_is_open(index: int) -> bool:
	if index < 0 or index >= segments.size():
		return false
	if not FRONT_REQUIRES.has(index):
		return true
	return has_flag(FRONT_REQUIRES[index])


## Chooses the front to work this turn. Returns false when the front is closed
## or out of range, so the caller can refuse the input.
func set_front(index: int) -> bool:
	if game_over or not front_is_open(index):
		return false
	current_front = index
	return true


## Every front finished. Not the win condition -- that stays SYSTEM_FLAGS.
func all_fronts_complete() -> bool:
	for p in front_progress:
		if p < 1.0:
			return false
	return true
```

- [ ] **Step 5: Replace the mileage engine with the front engine**

Delete `current_segment()` entirely. Replace `_build_miles()`:

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

with:

```gdscript
## Advances the front the player chose this turn. Only that front moves.
func _work_front(phase_count: int) -> void:
	if current_front < 0 or current_front >= segments.size():
		return
	if not front_is_open(current_front):
		return
	var segment := segments[current_front]
	var gain: float = FRONT_BASE_PROGRESS * float(PACE_FACTOR[work_pace])
	gain *= segment.build_rate_modifier
	gain *= _crew_factor()
	if segment.winter_sensitive and not has_flag(&"railroad_operational"):
		gain *= NO_RAILROAD_FACTOR
	front_progress[current_front] = minf(
		front_progress[current_front] + gain * float(phase_count), 1.0)
	_recompute_miles()


## miles_built is the length-weighted sum of front progress -- an honest
## aggregate of what has been built, not an independent counter.
func _recompute_miles() -> void:
	var total := 0.0
	for i in segments.size():
		var seg := segments[i]
		total += front_progress[i] * float(seg.end_mile - seg.start_mile)
	miles_built = minf(total, TOTAL_MILES)
	miles_changed.emit(miles_built)
```

In `advance_turn()`, replace `_build_miles(1)` with `_work_front(1)`.

In `apply_choice()`, replace `_build_miles(-choice.time_delta_seasons)` with:

```gdscript
			_work_front(-choice.time_delta_seasons)
```

- [ ] **Step 6: Re-anchor cards to front progress**

In `autoload/event_manager.gd`, add after the existing constants:

```gdscript
## Which front a card belongs to, derived from its mile_start. Verified against
## the deck: this distributes the 15 fixed cards 3/2/2/2/3/3 across the six
## fronts, with each front's last card granting that front's completion_flag.
func front_of_card(card: EventCard) -> int:
	for i in GameState.segments.size():
		if GameState.segments[i].contains(float(card.mile_start)):
			return i
	return GameState.segments.size() - 1


## The fixed cards belonging to one front, in filename order.
func _fixed_cards_for_front(front: int) -> Array[EventCard]:
	var out: Array[EventCard] = []
	for card in deck:
		if card.is_fixed and front_of_card(card) == front:
			out.append(card)
	return out
```

Replace `_available_cards()`:

```gdscript
func _available_cards() -> Array[EventCard]:
	var out: Array[EventCard] = []
	for card in deck:
		if card.hazard_kind != &"":
			continue   # hazards are drawn only by the pace-risk roll (see try_draw)
		if drawn_ids.has(card.event_id):
			continue
		if card.is_available(GameState.miles_built, GameState.flags):
			out.append(card)
	return out
```

with:

```gdscript
## Cards eligible this turn. Fixed cards are gated by progress on their OWN
## front rather than by a global mile counter: a front with three cards fires
## them at 1/3, 2/3 and completion. This is what makes working a front, rather
## than waiting for the next link in a chain, the thing that advances the game.
func _available_cards() -> Array[EventCard]:
	var out: Array[EventCard] = []
	for card in deck:
		if card.hazard_kind != &"":
			continue
		if drawn_ids.has(card.event_id):
			continue
		if not card.is_available(GameState.miles_built, GameState.flags):
			continue
		if card.is_fixed and not _threshold_reached(card):
			continue
		out.append(card)
	return out


## True when the card's own front has advanced far enough to earn it.
func _threshold_reached(card: EventCard) -> bool:
	var front := front_of_card(card)
	var siblings := _fixed_cards_for_front(front)
	var position := siblings.find(card)
	if position < 0 or siblings.is_empty():
		return true
	var needed := float(position + 1) / float(siblings.size())
	return GameState.front_progress[front] >= needed - 0.0001
```

- [ ] **Step 7: Update the sim to choose fronts**

In `tools/sim_test.gd`, inside the main campaign loop, immediately before
`GameState.advance_turn()`, add:

```gdscript
		GameState.set_front(_pick_front())
```

Add this function at the end of the file:

```gdscript
## Canonical allocation: work the lowest-numbered open, unfinished front. This
## follows the historical build order and is the baseline the balance probe
## measures other strategies against.
func _pick_front() -> int:
	for i in GameState.front_count():
		if GameState.front_is_open(i) and GameState.front_progress[i] < 1.0:
			return i
	return 0
```

Do the same inside `_probe()` and `_exploit_probe()` — add
`GameState.set_front(_pick_front())` immediately before each
`GameState.advance_turn()` call in those functions.

- [ ] **Step 8: Run the harness**

```bash
godot --headless res://tools/smoke_test.tscn
```
Expected: `SMOKE PASS`.

If `_check_flag_closure` or `_check_first_turn` fails, STOP and report — those
guard the card spine and a failure means the re-anchoring is wrong.

- [ ] **Step 9: Tune `FRONT_BASE_PROGRESS`**

```bash
godot --headless res://tools/sim_test.tscn
```

Read the `turns` number.

- If `turns` is **20–28 inclusive** and the run prints `SIM PASS`, tuning is
  done. Go to Step 10.
- If `turns` is **below 20**: lower `FRONT_BASE_PROGRESS` by `0.02`, re-run.
- If `turns` is **above 28**: raise `FRONT_BASE_PROGRESS` by `0.02`, re-run.
- **Maximum 6 adjustments.** If still outside the range, or if the result word
  is ever anything but `system_complete`, **STOP and report** the last three
  `SIM RESULT` lines. Change no other constant.

- [ ] **Step 10: Confirm nothing references the removed engine**

```bash
grep -rn "current_segment\|_build_miles" --include=*.gd .
```
Expected: **no output.**

- [ ] **Step 11: Full harness**

```bash
godot --headless res://tools/smoke_test.tscn
```
`SMOKE PASS`

```bash
godot --headless res://tools/sim_test.tscn
```
`SIM PASS`, `turns` 20–28

```bash
godot --headless res://tools/layout_test.tscn
```
`LAYOUT PASS`

- [ ] **Step 12: Commit**

```bash
git add -A
git commit -m "feat: six workfronts replace the linear card spine

Each turn the player works one of six fronts. Progress lives in GameState as a
float array parallel to segments; miles_built becomes the length-weighted sum,
an honest aggregate rather than an independent counter.

Cards are re-anchored to fire at progress thresholds within their own front,
derived from mile_start with no data changes -- the 15 fixed cards distribute
3/2/2/2/3/3 and each front's last card still grants its completion flag.

Fronts 2 and 3 gate on power earlier fronts provide. Fronts 4-6 stay ungated:
historically they were limited by money and priority, not permission, which the
funds and turn budget already model.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

**STOP. Report the final SIM RESULT line, the final FRONT_BASE_PROGRESS value,
and how many tuning adjustments you made.**

---

## Session 2 — Tasks 2 and 3 together

Both are mechanical and fail loudly. Do them in one session, commit separately.

## Task 2: Let the player choose a front

**Files:** `scenes/ui/decision_panel.gd`, `scenes/ui/hud.gd`, `tools/smoke_test.gd`

- [ ] **Step 1: Add a front selector to the DecisionPanel**

In `scenes/ui/decision_panel.gd`, replace:

```gdscript
signal decisions_confirmed(pace: int, action: StringName)
```

with:

```gdscript
signal decisions_confirmed(pace: int, action: StringName, front: int)
```

Add `var front_select: OptionButton` next to `var pace_select: OptionButton`.

In `_ready()`, immediately before `pace_select = OptionButton.new()`, add:

```gdscript
	front_select = OptionButton.new()
	row.add_child(front_select)
```

Replace `_on_end_pressed()`:

```gdscript
func _on_end_pressed() -> void:
	var action: StringName = ACTIONS[action_select.selected]
	action_select.select(0)
	decisions_confirmed.emit(pace_select.selected, action)
```

with:

```gdscript
func _on_end_pressed() -> void:
	var action: StringName = ACTIONS[action_select.selected]
	action_select.select(0)
	decisions_confirmed.emit(pace_select.selected, action, front_select.selected)
```

In `refresh_affordability()`, add at the top:

```gdscript
	_refresh_fronts()
```

Add this function at the end of the file:

```gdscript
## Rebuilds the front list each turn: finished fronts and fronts still waiting
## on power are shown but disabled, so the player can see the shape of the
## project rather than only its currently-legal moves.
func _refresh_fronts() -> void:
	var chosen := front_select.selected
	front_select.clear()
	for i in GameState.front_count():
		var seg := GameState.segments[i]
		var pct := int(round(GameState.front_progress[i] * 100.0))
		var label := "%s — %d%%" % [seg.segment_name, pct]
		if GameState.front_progress[i] >= 1.0:
			label += " (complete)"
		elif not GameState.front_is_open(i):
			label += " (waiting)"
		front_select.add_item(label)
		front_select.set_item_disabled(i,
			GameState.front_progress[i] >= 1.0 or not GameState.front_is_open(i))
	if chosen >= 0 and chosen < GameState.front_count() \
			and not front_select.is_item_disabled(chosen):
		front_select.select(chosen)
	else:
		for i in GameState.front_count():
			if not front_select.is_item_disabled(i):
				front_select.select(i)
				break
```

- [ ] **Step 2: Route the choice through Journey**

In `scenes/journey/journey.gd`, replace:

```gdscript
func _on_decisions(pace: int, action: StringName) -> void:
	decision_panel.set_enabled(false)
	GameState.work_pace = pace
```

with:

```gdscript
func _on_decisions(pace: int, action: StringName, front: int) -> void:
	decision_panel.set_enabled(false)
	GameState.work_pace = pace
	GameState.set_front(front)
```

- [ ] **Step 3: Update the smoke test's UI call**

In `tools/smoke_test.gd`, inside `_check_ui_scenes()`, replace:

```gdscript
	journey._on_decisions(GameState.Pace.STEADY, &"none")
```

with:

```gdscript
	journey._on_decisions(GameState.Pace.STEADY, &"none", 0)
```

- [ ] **Step 4: Show front progress on the HUD**

In `scenes/ui/hud.gd`, replace the miles readout in `_refresh()`:

```gdscript
	labels["miles"].text = "Mile %.1f of 167" % GameState.miles_built
```

with:

```gdscript
	labels["miles"].text = "Mile %.1f of 167  ·  %d/%d fronts done" % [
		GameState.miles_built, _fronts_done(), GameState.front_count()]
```

Add at the end of the file:

```gdscript
func _fronts_done() -> int:
	var n := 0
	for p in GameState.front_progress:
		if p >= 1.0:
			n += 1
	return n
```

- [ ] **Step 5: Verify**

```bash
godot --headless res://tools/smoke_test.tscn
```
`SMOKE PASS`

```bash
godot --headless res://tools/layout_test.tscn
```
`LAYOUT PASS` — the DecisionPanel is wider now. If it fails horizontally, STOP
and report; do not shrink anything without saying so.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: the player chooses which front to work each turn

DecisionPanel gains a front selector showing every front's percentage, with
finished and not-yet-open fronts visible but disabled -- the shape of the whole
project rather than only the currently-legal moves.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

## Task 3: Teach the balance probe about fronts

**Files:** `tools/balance_probe.gd`

- [ ] **Step 1: Give every strategy a front policy**

In `tools/balance_probe.gd`, replace the `_run()` signature and its pace line:

```gdscript
func _run(label: String, picker: Callable) -> void:
```

with:

```gdscript
func _run(label: String, picker: Callable, front_picker: Callable = Callable()) -> void:
```

Immediately before `GameState.advance_turn()` inside `_run()`, add:

```gdscript
			if front_picker.is_valid():
				GameState.set_front(front_picker.call())
			else:
				GameState.set_front(_lowest_open_front())
```

Add these two helpers at the end of the file:

```gdscript
## Historical order: the lowest-numbered open, unfinished front.
func _lowest_open_front() -> int:
	for i in GameState.front_count():
		if GameState.front_is_open(i) and GameState.front_progress[i] < 1.0:
			return i
	return 0


## Bay and Peninsula first -- the Spring Valley gambit. Historically real, and
## the sharpest test of whether front choice matters.
func _bay_first_front() -> int:
	if GameState.front_progress[5] < 1.0:
		return 5
	return _lowest_open_front()
```

- [ ] **Step 2: Add front-allocation strategies**

In `_ready()`, add after the existing `_run(...)` calls:

```gdscript
	_run("bay first, steady", func(_t: int) -> int: return GameState.Pace.STEADY,
		func() -> int: return _bay_first_front())
	_run("bay first, push", func(_t: int) -> int: return GameState.Pace.PUSHED,
		func() -> int: return _bay_first_front())
```

- [ ] **Step 3: Run it and report**

```bash
godot --headless res://tools/balance_probe.tscn
```
Expected: `BALANCE PROBE DONE` and eight `BALANCE` lines.

**Do not tune anything.** Copy all eight lines into your report — the reviewer
compares them against the spec's success criteria.

- [ ] **Step 4: Full harness and commit**

```bash
godot --headless res://tools/smoke_test.tscn
```
`SMOKE PASS`

```bash
godot --headless res://tools/sim_test.tscn
```
`SIM PASS`

```bash
git add -A
git commit -m "test: balance probe measures front allocation, not just pace

Adds a bay-first strategy -- the Spring Valley gambit, historically real and the
sharpest test of whether choosing a front matters. Every strategy now carries a
front policy, defaulting to historical build order.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

**STOP. Report all eight BALANCE lines verbatim.**

---

## Session 3 — Tuning (reviewer, not worker)

Measured against the [spec's success criteria](../specs/2026-07-27-workfront-progression-design.md#success-criteria):

1. Best strategy wins 8–11 of 12; pushing strategies win at least 5 of 12.
2. `sim_test` completes at `matched_history`.
3. A never-pushing player can still finish.
4. Front 6 first is survivable but measurably costly — not strictly wrong.

If (1) fails after tuning, **the design failed and we say so** rather than
lowering the bar.

## Definition of done

- [ ] All three suites green.
- [ ] `grep -rn "current_segment\|_build_miles" --include=*.gd .` is empty.
- [ ] `balance_probe` meets the success criteria.
- [ ] `data/events` and `data/segments` are untouched by the whole batch.
