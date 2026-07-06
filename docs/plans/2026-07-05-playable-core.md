# Hetchy Trail Playable Core — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. If you don't have those skills, simply execute tasks in order, one step at a time, and never skip a verification step.

**Goal:** Take the finished data model and singletons to a playable, verified game loop: harness → HUD → decisions → event cards → map → menus → balance.

**Architecture:** All game logic already lives in the `GameState` and `EventManager` autoloads plus `.tres` data (see [technical_design.md](../technical_design.md)). This plan adds only presentation and verification. Scenes are one-node `.tscn` shells; all child nodes are built in `_ready()` — hand-editing complex scene text is the #1 way agents corrupt Godot projects, so we don't do it.

**Tech Stack:** Godot 4.7 (GDScript only, no addons, no external dependencies), PowerShell for commands, git.

## Global Constraints

Every task inherits these. Violating one is a task failure even if the code runs.

- **Five metrics only** (funds, public_support, water_readiness, crew_wellbeing, time) plus `miles_built` and flags. Never add a resource, currency, or meter.
- **UI never mutates state.** Scenes read GameState fields and call `GameState.take_action()` / `GameState.advance_turn()` / `EventManager.resolve_choice()`. Never assign `GameState.funds = x` from a scene.
- **One-node .tscn shells only.** Every `.tscn` in this plan is exactly 5 lines (shell template in Task 4). All children are created in `_ready()`.
- **Do not edit files in `data/`** (cards and segments are authored historical content) except when Task 1's parse-repair step explicitly requires a mechanical syntax fix. Balance tuning happens only in the named constants at the top of `autoload/game_state.gd` and `event_chance` in `event_manager.gd`.
- **Do not modify** `docs/Hetchy Trail Historical Game Mapping.pdf`, anything in `assets/art/archival/` without a CREDITS.md row, or the two autoloads' public method signatures.
- **Harness gate:** after every task, `smoke_test` and `sim_test` must exit 0 before committing. Never weaken a check to make it pass; fix the cause.
- **Two-strike rule:** if the same verification fails twice after your best fix, stop and report to the user with the exact error output.
- Keep every new file under ~150 lines, one responsibility each.
- `$godot` in commands below means the Godot executable path found in Task 1. Run all commands from the repository root.

---

### Task 1: Install Godot and validate the project imports

**Files:**
- Modify: none (repair `data/*.tres` only if the parse-repair step triggers)

**Interfaces:**
- Produces: a working `$godot` executable path; a project that imports with zero script/resource errors. Every later task depends on this.

- [ ] **Step 1: Locate or install Godot**

Run: `Get-Command godot -ErrorAction SilentlyContinue; Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Links" -Filter "godot*" -ErrorAction SilentlyContinue`

If nothing is found: `winget install --id GodotEngine.GodotEngine -e --accept-source-agreements --accept-package-agreements`, then re-run the locate command. If winget is unavailable, ask the user to download the standard (non-.NET) 4.x Windows build from godotengine.org and give you the path.

Record the path: `$godot = "<found path>"`. Verify: `& $godot --version` — Expected: a version string starting `4.` (4.3 or later required).

- [ ] **Step 2: Import the project headless**

Run: `& $godot --headless --import . 2>&1 | Tee-Object -Variable importLog; $LASTEXITCODE`

Expected: import completes and returns to the prompt. Then: `$importLog | Select-String -Pattern "ERROR|SCRIPT ERROR|Parse Error" | Select-Object -First 20`

Expected: **no matches**. Warnings (e.g. about missing UIDs) are fine and will disappear on first editor save.

- [ ] **Step 3 (only if Step 2 showed errors): mechanical .tres repair**

The one known risk is the typed-array serialization in the 21 hand-written card files. If errors mention `Array[ExtResource...]` or parse failures in `data/events/`:
1. Open one failing file and read the exact error line/column.
2. Determine the correct syntax empirically: open the project in the editor (`& $godot -e .`), create a throwaway `EventCard` resource in the Inspector with two choices, save it as `data/events/zz_probe.tres`, close the editor, and read that file to see how Godot serializes `choices` and the flag arrays.
3. Apply the same pattern to all 21 files with find/replace (only the syntax — never change ids, deltas, flags, or text), delete `zz_probe.tres`, re-run Step 2.
Do NOT delete or stub any card. If the repair isn't a clear mechanical substitution, stop and report (two-strike rule).

- [ ] **Step 4: Commit**

```powershell
git add -A; git commit -m "chore: validate project import under Godot 4.x"
```
(Commit even if nothing changed except normalization — if truly nothing changed, skip the commit.)

---

### Task 2: Headless smoke test

**Files:**
- Create: `tools/smoke_test.gd`, `tools/smoke_test.tscn`

**Interfaces:**
- Consumes: `GameState` (autoload: `segments`, `new_game()`, `flags`, `SYSTEM_FLAGS`), `EventManager` (autoload: `deck`, `reset()`, `try_draw()`, `resolve_choice(card, index)`).
- Produces: the command `& $godot --headless res://tools/smoke_test.tscn` exiting 0 with `SMOKE PASS`. Later tasks append checks to this file.

- [ ] **Step 1: Write the test scene shell**

Create `tools/smoke_test.tscn` exactly:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tools/smoke_test.gd" id="1"]

[node name="SmokeTest" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: Write the smoke test**

Create `tools/smoke_test.gd`:

```gdscript
extends Node
## Headless smoke test. Run:  godot --headless res://tools/smoke_test.tscn
## Exits 0 on PASS, 1 on FAIL. Never weaken a check to make it pass.

var passed := 0
var failures: Array[String] = []


func _ready() -> void:
	_check_segments()
	_check_deck()
	_check_flag_closure()
	_check_first_turn()
	if failures.is_empty():
		print("SMOKE PASS (%d checks)" % passed)
	else:
		print("SMOKE FAIL (%d failures)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failures.append(what)
		push_error("SMOKE FAIL: " + what)


func _check_segments() -> void:
	check(GameState.segments.size() == 6, "exactly 6 route segments loaded")
	var expected_start := 0
	for s in GameState.segments:
		check(s.start_mile == expected_start,
			"segment %s starts at mile %d" % [s.segment_name, expected_start])
		check(s.completion_flag != StringName(), "segment %s has a completion flag" % s.segment_name)
		expected_start = s.end_mile
	check(expected_start == 167, "segments cover the full 167 miles")


func _check_deck() -> void:
	check(EventManager.deck.size() == 21, "exactly 21 event cards loaded (got %d)" % EventManager.deck.size())
	for card in EventManager.deck:
		check(card.event_id != StringName(), "card '%s' has an event_id" % card.title)
		check(card.choices.size() >= 1, "card %s has at least one choice" % card.event_id)
		check(card.canonical_choice >= 0 and card.canonical_choice < card.choices.size(),
			"card %s canonical_choice in range" % card.event_id)
		check(card.historical_fact != "", "card %s has a historical_fact (teaching layer)" % card.event_id)
		check(card.mile_start <= card.mile_end, "card %s mile range valid" % card.event_id)


func _check_flag_closure() -> void:
	# A flag is guaranteed by the fixed spine when some fixed card grants it on
	# EVERY terminal choice. A repeat_card choice returns the card to the deck
	# instead of exiting, so it is not an escape path and is excluded; a card
	# whose only choices repeat guarantees nothing.
	var guaranteed := {}
	for card in EventManager.deck:
		if not card.is_fixed or card.choices.is_empty():
			continue
		var terminal: Array = []
		for choice in card.choices:
			if not choice.repeat_card:
				terminal.append(choice)
		if terminal.is_empty():
			continue
		var common := {}
		for flag in terminal[0].granted_flags:
			common[flag] = true
		for i in range(1, terminal.size()):
			var keep := {}
			for flag in terminal[i].granted_flags:
				if common.has(flag):
					keep[flag] = true
			common = keep
		for flag in common:
			guaranteed[flag] = true
	for card in EventManager.deck:
		if not card.is_fixed:
			continue
		for flag in card.required_flags:
			check(guaranteed.has(flag),
				"fixed card %s requires '%s', which must be guaranteed by the fixed spine" % [card.event_id, flag])
	for flag in GameState.SYSTEM_FLAGS:
		check(guaranteed.has(flag), "system flag '%s' is guaranteed by the fixed spine" % flag)


func _check_first_turn() -> void:
	GameState.new_game()
	EventManager.reset()
	var card := EventManager.try_draw()
	check(card != null and card.event_id == &"cut_the_first_road",
		"first fixed card is Cut the First Road")
	if card != null:
		EventManager.resolve_choice(card, card.canonical_choice)
		check(GameState.has_flag(&"high_sierra_access_complete"),
			"resolving the road card grants high_sierra_access_complete")
	GameState.new_game()
	EventManager.reset()
```

- [ ] **Step 3: Run it and confirm it passes**

Run: `& $godot --headless res://tools/smoke_test.tscn; $LASTEXITCODE`

Expected: last lines contain `SMOKE PASS (…)` and exit code `0`. If a data check fails, the data or a singleton has a real bug — investigate the specific failure message; do not edit the check.

- [ ] **Step 4: Commit**

```powershell
git add tools/; git commit -m "test: headless smoke test for data model and singletons"
```

---

### Task 3: Full-campaign simulation harness

**Files:**
- Create: `tools/sim_test.gd`, `tools/sim_test.tscn`

**Interfaces:**
- Consumes: everything Task 2 consumes, plus `GameState.advance_turn()`, `take_action()`, `work_pace`, `game_over`, `game_ended`, `completion_grade()`.
- Produces: `& $godot --headless res://tools/sim_test.tscn` exiting 0 with `SIM PASS: system_complete …`. This is the permanent balance guard: any future change that breaks winnability fails this command.

- [ ] **Step 1: Write the scene shell**

Create `tools/sim_test.tscn` — same 5-line shell as Task 2 Step 1, with `path="res://tools/sim_test.gd"` and node name `SimTest`.

- [ ] **Step 2: Write the simulation**

Create `tools/sim_test.gd`:

```gdscript
extends Node
## Plays a full campaign headless: Steady pace, sensible actions, always the
## canonical (historical) choice. Run:  godot --headless res://tools/sim_test.tscn
## PASS = system complete by 1940. Deterministic (fixed seed).

const MAX_TURNS := 160
const SEASONS := ["Winter", "Spring", "Summer", "Fall"]

var result: StringName = &""


func _ready() -> void:
	seed(1234)
	GameState.new_game()
	EventManager.reset()
	GameState.game_ended.connect(func(r: StringName): result = r)
	var turns := 0
	for i in MAX_TURNS:
		if GameState.game_over:
			break
		turns += 1
		GameState.work_pace = GameState.Pace.STEADY
		if GameState.funds <= 2 and GameState.public_support >= GameState.BOND_MIN_SUPPORT:
			GameState.take_action(&"issue_bond")
		elif GameState.public_support <= 3 and GameState.funds >= 2:
			GameState.take_action(&"outreach")
		elif GameState.crew_wellbeing <= 3 and GameState.funds >= 2:
			GameState.take_action(&"improve_camp")
		GameState.advance_turn()
		if GameState.game_over:
			break
		var card := EventManager.try_draw()
		if card != null:
			EventManager.resolve_choice(card, card.canonical_choice)
	print("SIM RESULT: %s | %s %d | mile %.0f | readiness %d | funds %d | support %d | crew %d | %d turns"
		% [result, SEASONS[GameState.season], GameState.year, GameState.miles_built,
		GameState.water_readiness, GameState.funds, GameState.public_support,
		GameState.crew_wellbeing, turns])
	if result == &"system_complete" and GameState.year <= 1940:
		print("SIM PASS: system_complete, grade=%s" % GameState.completion_grade())
		get_tree().quit(0)
	else:
		print("SIM FAIL")
		get_tree().quit(1)
```

- [ ] **Step 3: Run it**

Run: `& $godot --headless res://tools/sim_test.tscn; $LASTEXITCODE`

Expected: `SIM PASS: system_complete, …` and exit code `0`. The finish year will likely be 1930–1938 with first-pass balance; any completion ≤1940 passes this task (Task 10 tightens it).

- [ ] **Step 4 (only if SIM FAIL): tune the named knobs**

Read the printed state to see what ran out. Adjust **only** these, one at a time, re-running after each: `MILES_PER_SEASON`, `START_FUNDS`, `WINTER_PAYROLL`, `SNOWBOUND_FACTOR` (in `game_state.gd`) and `event_chance` (in `event_manager.gd`). Never edit card data. Two failed attempts → stop and report the printed sim lines.

- [ ] **Step 5: Commit**

```powershell
git add -A; git commit -m "test: deterministic full-campaign simulation harness"
```

---

### Task 4: HUD

**Files:**
- Create: `scenes/ui/hud.gd`, `scenes/ui/hud.tscn`

**Interfaces:**
- Consumes: all GameState signals and fields; `GameState.READINESS_TARGET`, `has_flag(&"hetch_hetchy_water_delivered")`.
- Produces: scene `res://scenes/ui/hud.tscn` (root `CanvasLayer`, script exposes `labels: Dictionary` with keys `date, miles, funds, support, water, crew`). Journey (Task 7) instances it.

- [ ] **Step 1: Write the shell**

Create `scenes/ui/hud.tscn` — the shell template every UI scene in this plan uses (change path/name/type per task):

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/ui/hud.gd" id="1"]

[node name="HUD" type="CanvasLayer"]
script = ExtResource("1")
```

- [ ] **Step 2: Write the script**

Create `scenes/ui/hud.gd`:

```gdscript
extends CanvasLayer
## Read-only display of the five metrics, the date, and the construction front.

const SEASONS := ["Winter", "Spring", "Summer", "Fall"]

var labels := {}


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)
	for key in ["date", "miles", "funds", "support", "water", "crew"]:
		var label := Label.new()
		row.add_child(label)
		labels[key] = label
	GameState.funds_changed.connect(func(v: int): labels["funds"].text = "Funds: %d" % v)
	GameState.support_changed.connect(func(v: int): labels["support"].text = "Support: %d/10" % v)
	GameState.crew_changed.connect(func(v: int): labels["crew"].text = "Crew: %d/10" % v)
	GameState.readiness_changed.connect(_set_water)
	GameState.flag_granted.connect(func(_f: StringName): _set_water(GameState.water_readiness))
	GameState.miles_changed.connect(func(v: float): labels["miles"].text = "Mile %.1f of 167" % v)
	GameState.turn_advanced.connect(func(y: int, s: int): labels["date"].text = "%s %d" % [SEASONS[s], y])
	_refresh()


func _refresh() -> void:
	labels["funds"].text = "Funds: %d" % GameState.funds
	labels["support"].text = "Support: %d/10" % GameState.public_support
	labels["crew"].text = "Crew: %d/10" % GameState.crew_wellbeing
	labels["miles"].text = "Mile %.1f of 167" % GameState.miles_built
	labels["date"].text = "%s %d" % [SEASONS[GameState.season], GameState.year]
	_set_water(GameState.water_readiness)


func _set_water(v: int) -> void:
	var note := " — delivered!" if GameState.has_flag(&"hetch_hetchy_water_delivered") else " (not yet delivered)"
	labels["water"].text = "Water readiness: %d/%d%s" % [v, GameState.READINESS_TARGET, note]
```

- [ ] **Step 3: Verify headless (parse + smoke)**

Run: `& $godot --headless res://tools/smoke_test.tscn; $LASTEXITCODE` — Expected: `SMOKE PASS`, exit 0 (this also recompiles all scripts; a syntax error in hud.gd fails here). Full HUD instantiation is verified in Task 7's UI check.

- [ ] **Step 4: Commit**

```powershell
git add scenes/ui/; git commit -m "feat: HUD scene displaying the five metrics"
```

---

### Task 5: DecisionPanel

**Files:**
- Create: `scenes/ui/decision_panel.gd`, `scenes/ui/decision_panel.tscn`

**Interfaces:**
- Consumes: `GameState.Pace`, `BOND_MIN_SUPPORT`, `OUTREACH_FUNDS_COST`, `CAMP_FUNDS_COST`, `funds`, `public_support`.
- Produces: scene `res://scenes/ui/decision_panel.tscn` (root `Control`). Signal `decisions_confirmed(pace: int, action: StringName)`; methods `set_enabled(on: bool)`, `refresh_affordability()`. Actions are exactly `&"none"`, `&"issue_bond"`, `&"outreach"`, `&"improve_camp"`.

- [ ] **Step 1: Write the shell**

Create `scenes/ui/decision_panel.tscn` — Task 4 shell with `path="res://scenes/ui/decision_panel.gd"`, name `DecisionPanel`, type `Control`.

- [ ] **Step 2: Write the script**

Create `scenes/ui/decision_panel.gd`:

```gdscript
extends Control
## DECIDE-phase form: pace + one optional action + End Season.
## Emits the result; applies nothing itself.

signal decisions_confirmed(pace: int, action: StringName)

const ACTIONS: Array[StringName] = [&"none", &"issue_bond", &"outreach", &"improve_camp"]
const ACTION_LABELS := [
	"No special action",
	"Issue bond (+3 funds, -1 support)",
	"Community outreach (-1 funds, +2 support)",
	"Improve the camps (-1 funds, +2 crew)",
]

var pace_select: OptionButton
var action_select: OptionButton
var end_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	pace_select = OptionButton.new()
	for pace_name in ["Rest the crews", "Steady work", "Push the pace"]:
		pace_select.add_item(pace_name)
	pace_select.select(GameState.Pace.STEADY)
	row.add_child(pace_select)
	action_select = OptionButton.new()
	for action_label in ACTION_LABELS:
		action_select.add_item(action_label)
	row.add_child(action_select)
	end_button = Button.new()
	end_button.text = "End season"
	end_button.pressed.connect(_on_end_pressed)
	row.add_child(end_button)
	refresh_affordability()


func _on_end_pressed() -> void:
	var action: StringName = ACTIONS[action_select.selected]
	action_select.select(0)
	decisions_confirmed.emit(pace_select.selected, action)


func set_enabled(on: bool) -> void:
	end_button.disabled = not on
	pace_select.disabled = not on
	action_select.disabled = not on


func refresh_affordability() -> void:
	action_select.set_item_disabled(1, GameState.public_support < GameState.BOND_MIN_SUPPORT)
	action_select.set_item_disabled(2, GameState.funds < GameState.OUTREACH_FUNDS_COST)
	action_select.set_item_disabled(3, GameState.funds < GameState.CAMP_FUNDS_COST)
```

- [ ] **Step 3: Verify headless** — same command and expectation as Task 4 Step 3.

- [ ] **Step 4: Commit**

```powershell
git add scenes/ui/; git commit -m "feat: DecisionPanel with pace and single-action form"
```

---

### Task 6: EventPanel (the teaching card)

**Files:**
- Create: `scenes/ui/event_panel.gd`, `scenes/ui/event_panel.tscn`

**Interfaces:**
- Consumes: `EventCard` fields (`title`, `location_name`, `historical_year_start/end`, `event_description`, `historical_fact`, `assumption_note`, `archival_photo`, `choices` with `label`).
- Produces: scene `res://scenes/ui/event_panel.tscn` (root `Control`, hidden by default). Method `show_card(card: EventCard)`; signal `choice_selected(index: int)` (emitted after the panel hides itself).

- [ ] **Step 1: Write the shell** — Task 4 shell, `path="res://scenes/ui/event_panel.gd"`, name `EventPanel`, type `Control`.

- [ ] **Step 2: Write the script**

Create `scenes/ui/event_panel.gd`:

```gdscript
extends Control
## Displays one EventCard: description, choices, and the teaching layer
## ("What really happened" + assumption note + optional archival photo).

signal choice_selected(index: int)

var title_label: Label
var body_label: Label
var photo_rect: TextureRect
var fact_label: Label
var note_label: Label
var buttons_box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	title_label = _add_label(box)
	body_label = _add_label(box)
	photo_rect = TextureRect.new()
	photo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo_rect.custom_minimum_size = Vector2(0, 220)
	box.add_child(photo_rect)
	buttons_box = VBoxContainer.new()
	box.add_child(buttons_box)
	box.add_child(HSeparator.new())
	fact_label = _add_label(box)
	note_label = _add_label(box)
	note_label.modulate = Color(1, 1, 1, 0.7)


func _add_label(parent: Node) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(640, 0)
	parent.add_child(label)
	return label


func show_card(card: EventCard) -> void:
	title_label.text = "%s — %s, %d" % [card.title, card.location_name, card.historical_year_start]
	body_label.text = card.event_description
	photo_rect.texture = card.archival_photo
	photo_rect.visible = card.archival_photo != null
	fact_label.text = "What really happened: " + card.historical_fact
	note_label.text = card.assumption_note
	note_label.visible = card.assumption_note != ""
	for child in buttons_box.get_children():
		child.queue_free()
	for i in card.choices.size():
		var button := Button.new()
		button.text = card.choices[i].label
		button.pressed.connect(_on_choice.bind(i))
		buttons_box.add_child(button)
	show()


func _on_choice(index: int) -> void:
	hide()
	choice_selected.emit(index)
```

- [ ] **Step 3: Verify headless** — same as Task 4 Step 3.

- [ ] **Step 4: Commit**

```powershell
git add scenes/ui/; git commit -m "feat: EventPanel with choices and teaching layer"
```

---

### Task 7: Journey conductor — first playable

**Files:**
- Create: `scenes/journey/journey.gd`, `scenes/journey/journey.tscn`
- Modify: `project.godot` (set main scene), `tools/smoke_test.gd` (add UI check)

**Interfaces:**
- Consumes: the three UI scenes (Tasks 4–6), `GameState.advance_turn/take_action/work_pace/game_over/game_ended/completion_grade`, `EventManager.try_draw/resolve_choice`.
- Produces: a runnable game at `res://scenes/journey/journey.tscn`; the only caller of `advance_turn()` and `try_draw()`.

- [ ] **Step 1: Write the shell** — Task 4 shell, `path="res://scenes/journey/journey.gd"`, name `Journey`, type `Node`.

- [ ] **Step 2: Write the conductor**

Create `scenes/journey/journey.gd`:

```gdscript
extends Node
## Turn conductor: DECIDE -> RESOLVE -> EVENT -> CHECK.
## The only script that calls GameState.advance_turn() and EventManager.try_draw().

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const DECISION_SCENE := preload("res://scenes/ui/decision_panel.tscn")
const EVENT_SCENE := preload("res://scenes/ui/event_panel.tscn")

# Deliberately untyped: these hold scene instances whose custom methods
# (refresh_affordability, show_card, ...) GDScript can't see on base types.
var hud
var decision_panel
var event_panel
var current_card: EventCard


func _ready() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	decision_panel = DECISION_SCENE.instantiate()
	add_child(decision_panel)
	event_panel = EVENT_SCENE.instantiate()
	add_child(event_panel)
	decision_panel.decisions_confirmed.connect(_on_decisions)
	event_panel.choice_selected.connect(_on_event_choice)
	GameState.game_ended.connect(_on_game_ended)
	_begin_decide()


func _begin_decide() -> void:
	decision_panel.refresh_affordability()
	decision_panel.set_enabled(true)


func _on_decisions(pace: int, action: StringName) -> void:
	decision_panel.set_enabled(false)
	GameState.work_pace = pace
	if action != &"none":
		GameState.take_action(action)
	GameState.advance_turn()
	if GameState.game_over:
		return
	current_card = EventManager.try_draw()
	if current_card != null:
		event_panel.show_card(current_card)
	else:
		_begin_decide()


func _on_event_choice(index: int) -> void:
	var card := current_card
	current_card = null
	EventManager.resolve_choice(card, index)
	if not GameState.game_over:
		_begin_decide()


func _on_game_ended(result: StringName) -> void:
	# Placeholder banner; Task 9's Main scene replaces this screen entirely.
	decision_panel.set_enabled(false)
	event_panel.hide()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var label := Label.new()
	label.text = "Game over: %s (%s, %d)" % [result, GameState.completion_grade(), GameState.year]
	center.add_child(label)
```

- [ ] **Step 3: Set the main scene**

In `project.godot`, under `[application]`, add this line directly after `config/features=...`:

```
run/main_scene="res://scenes/journey/journey.tscn"
```

- [ ] **Step 4: Add the UI instantiation check to the smoke test**

In `tools/smoke_test.gd`: in `_ready()`, add `_check_ui_scenes()` on the line after `_check_first_turn()`, and append this function at the end of the file:

```gdscript
func _check_ui_scenes() -> void:
	GameState.new_game()
	EventManager.reset()
	var journey: Node = load("res://scenes/journey/journey.tscn").instantiate()
	add_child(journey)
	check(journey.hud != null and journey.hud.labels.size() == 6, "Journey builds HUD with 6 labels")
	check(journey.decision_panel.end_button != null, "Journey builds DecisionPanel")
	check(not journey.event_panel.visible, "EventPanel starts hidden")
	journey._on_decisions(GameState.Pace.STEADY, &"none")
	check(GameState.miles_built > 0.0, "one turn advances the construction front")
	check(journey.event_panel.visible, "turn 1 shows the first fixed card")
	journey.event_panel._on_choice(0)
	check(GameState.has_flag(&"high_sierra_access_complete"), "resolving via UI grants the flag")
	journey.queue_free()
	GameState.new_game()
	EventManager.reset()
```

- [ ] **Step 5: Verify — harness and a human playthrough**

Run: `& $godot --headless res://tools/smoke_test.tscn; $LASTEXITCODE` — Expected: `SMOKE PASS`, exit 0.
Run: `& $godot --headless res://tools/sim_test.tscn; $LASTEXITCODE` — Expected: `SIM PASS`, exit 0.
Then tell the user: run `& $godot .` (or press F5 in the editor) and play ~10 seasons — metrics should move, cards should appear with "What really happened" text. This human check is required before Task 8 begins.

- [ ] **Step 6: Commit**

```powershell
git add -A; git commit -m "feat: Journey turn conductor - first playable loop"
```

---

### Task 8: The lighting map

**Files:**
- Create: `scenes/map/map.gd`, `scenes/map/map.tscn`
- Modify: `scenes/journey/journey.gd` (instance the map)

**Interfaces:**
- Consumes: `GameState.segments` (`start_mile`, `end_mile`, `segment_name`, `completion_flag`), `miles_built`, `flags`, `flag_granted`, `miles_changed`, `is_system_connected()`.
- Produces: scene `res://scenes/map/map.tscn` (root `Node2D`), pure presentation.

- [ ] **Step 1: Write the shell** — Task 4 shell, `path="res://scenes/map/map.gd"`, name `Map`, type `Node2D`.

- [ ] **Step 2: Write the map**

Create `scenes/map/map.gd`:

```gdscript
extends Node2D
## The 167-mile route as six divisions that light up as their completion
## flags are granted -- a system connecting, not a wagon moving west.

const COLOR_PENDING := Color(0.35, 0.33, 0.30)
const COLOR_ACTIVE := Color(0.85, 0.65, 0.25)
const COLOR_DONE := Color(0.35, 0.65, 0.90)
const COLOR_FLOWING := Color(0.30, 0.80, 1.0)


func _ready() -> void:
	GameState.flag_granted.connect(func(_f: StringName): queue_redraw())
	GameState.miles_changed.connect(func(_v: float): queue_redraw())


func _draw() -> void:
	var size := get_viewport_rect().size
	var left := 60.0
	var right := size.x - 60.0
	var y := size.y * 0.28
	var connected := GameState.is_system_connected()
	for segment in GameState.segments:
		var x1: float = lerpf(left, right, segment.start_mile / GameState.TOTAL_MILES)
		var x2: float = lerpf(left, right, segment.end_mile / GameState.TOTAL_MILES)
		var color := COLOR_PENDING
		if connected:
			color = COLOR_FLOWING
		elif GameState.has_flag(segment.completion_flag):
			color = COLOR_DONE
		elif GameState.miles_built >= float(segment.start_mile):
			color = COLOR_ACTIVE
		draw_line(Vector2(x1, y), Vector2(x2 - 4.0, y), color, 6.0)
		draw_circle(Vector2(x2, y), 5.0, color)
		draw_string(ThemeDB.fallback_font, Vector2(x1, y - 14.0),
			segment.segment_name, HORIZONTAL_ALIGNMENT_LEFT, x2 - x1, 11)
	var front_x: float = lerpf(left, right, GameState.miles_built / GameState.TOTAL_MILES)
	draw_line(Vector2(front_x, y - 8.0), Vector2(front_x, y + 8.0), Color.WHITE, 2.0)
```

- [ ] **Step 3: Instance it in Journey**

In `scenes/journey/journey.gd`, add to the constants block:

```gdscript
const MAP_SCENE := preload("res://scenes/map/map.tscn")
```

and add these two lines at the very top of `_ready()` (the map must sit behind the UI):

```gdscript
	add_child(MAP_SCENE.instantiate())
```

- [ ] **Step 4: Verify** — run both harness commands (expected: PASS, exit 0), then tell the user to run the game and confirm: divisions light amber as the front enters them, blue as division cards resolve.

- [ ] **Step 5: Commit**

```powershell
git add -A; git commit -m "feat: route map with divisions lighting up on completion flags"
```

---

### Task 9: Main scene — title and end screens

**Files:**
- Create: `scenes/main/main.gd`, `scenes/main/main.tscn`
- Modify: `project.godot` (main scene → main.tscn)

**Interfaces:**
- Consumes: `GameState.new_game()/game_ended/completion_grade()/year/has_flag`, `EventManager.reset()`, `res://scenes/journey/journey.tscn`.
- Produces: `res://scenes/main/main.tscn` as the game's entry point.

- [ ] **Step 1: Write the shell** — Task 4 shell, `path="res://scenes/main/main.gd"`, name `Main`, type `Node`.

- [ ] **Step 2: Write the script**

Create `scenes/main/main.gd`:

```gdscript
extends Node
## Screen switcher: title -> journey -> end summary. No game logic.

const JOURNEY_SCENE := preload("res://scenes/journey/journey.tscn")

const RESULT_TEXT := {
	&"system_complete": "At 10:12 a.m., Sierra water reaches Pulgas.\nThe 167-mile gravity system is complete.",
	&"bond_crisis": "The treasury is empty and no bonds can be sold.\nThe aqueduct stands unfinished.",
	&"project_cancelled": "The public has lost faith. The city votes\nto abandon the mountain water project.",
	&"work_halted": "The camps are empty. Without a workforce,\nthe headings fall silent.",
	&"city_moves_on": "Too many years, too little water.\nSan Francisco turns to other sources.",
}
const GRADE_TEXT := {
	"ahead_of_history": "You beat history: the real system connected in October 1934.",
	"matched_history": "You matched history: the real system connected in October 1934.",
	"behind_history": "The real crews connected the system in October 1934.",
}

var current_screen: Node


func _ready() -> void:
	GameState.game_ended.connect(_on_game_ended)
	_show_title()


func _swap(screen: Node) -> void:
	if current_screen != null:
		current_screen.queue_free()
	current_screen = screen
	add_child(screen)


func _show_title() -> void:
	_swap(_build_screen("Hetchy Trail",
		"San Francisco, 1914. Bring the Sierra water 167 miles to the city.",
		"Begin the journey", _start_game))


func _start_game() -> void:
	GameState.new_game()
	EventManager.reset()
	_swap(JOURNEY_SCENE.instantiate())


func _on_game_ended(result: StringName) -> void:
	var body: String = RESULT_TEXT.get(result, String(result))
	if result == &"system_complete":
		body += "\n\nFinished %d. %s" % [GameState.year, GRADE_TEXT[GameState.completion_grade()]]
		if GameState.has_flag(&"row_expansion_secured"):
			body += "\nYour wide right-of-way left room for three more pipelines to come."
	_swap(_build_screen("The Journey Ends", body, "Play again", _show_title))


func _build_screen(title: String, body: String, button_text: String, on_press: Callable) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 32)
	box.add_child(title_label)
	var body_label := Label.new()
	body_label.text = body
	box.add_child(body_label)
	var button := Button.new()
	button.text = button_text
	button.pressed.connect(on_press)
	box.add_child(button)
	return root
```

- [ ] **Step 3: Point the project at Main**

In `project.godot`, change the `run/main_scene` line to:

```
run/main_scene="res://scenes/main/main.tscn"
```

- [ ] **Step 4: Verify** — run both harness commands (PASS, exit 0). Tell the user: run the game; title → play a few seasons → (optionally set `FINAL_DEADLINE_YEAR` lower temporarily to see a loss screen — revert it) → Play again works.

- [ ] **Step 5: Commit**

```powershell
git add -A; git commit -m "feat: Main scene with title and end screens"
```

---

### Task 10: Balance pass — land near 1934

**Files:**
- Modify: `autoload/game_state.gd` (constants only), `autoload/event_manager.gd` (`event_chance` only), `tools/sim_test.gd` (tighten the pass window)

**Interfaces:**
- Consumes: the sim harness.
- Produces: canonical play finishing 1932–1936; the tightened sim guards this forever.

- [ ] **Step 1: Tighten the sim window**

In `tools/sim_test.gd`, replace the pass condition line with:

```gdscript
	if result == &"system_complete" and GameState.year >= 1932 and GameState.year <= 1936:
```

- [ ] **Step 2: Run and tune**

Run: `& $godot --headless res://tools/sim_test.tscn; $LASTEXITCODE`

If FAIL: read the printed year. Finishing too early → lower `MILES_PER_SEASON[Pace.STEADY]` in steps of 0.25 or reduce segment-crossing speed via `SNOWBOUND_FACTOR`; too late → the reverse; dying of funds → raise `START_FUNDS` by 1. One knob per attempt, re-run each time, maximum four attempts, then stop and report all printed sim lines.

- [ ] **Step 3: Full gate and play**

Run both harness commands (PASS, exit 0). Tell the user: play one full campaign start to finish and judge feel — numbers can pass while pacing feels wrong; their verdict outranks the sim.

- [ ] **Step 4: Commit**

```powershell
git add -A; git commit -m "balance: canonical campaign lands 1932-1936"
```

---

## After this plan

M5 (archival photos with credits, art pass, audio, export presets) needs its own plan and the user's SFPUC material — do not start it from here. When adding new event cards later: follow any existing card file as the template, keep the five-delta model, always fill `historical_fact` and `assumption_note`, add the file with the next numeric prefix, and update the deck-count check in `tools/smoke_test.gd` (that count-bump is the one sanctioned smoke-test edit).
