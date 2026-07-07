# Decision Weight & Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the recurring pace/action decision carry weight — pace now tilts a per-season risk of injury (push) or impatience (rest) scaled by board state, and every consequence is surfaced with its authored narrative and metric changes.

**Architecture:** Pure additions to the existing autoload + resource model. `EventManager` gains a pace-risk roll and a read-only `risk_preview()` query; a small pool of repeatable **hazard** EventCards supplies the narrative. The three display scenes (event/decision/HUD) surface consequences and stakes. No new resource, no sixth metric, no logic in scenes.

**Tech Stack:** Godot 4.7 (GDScript only), PowerShell, git. Design spec: [docs/superpowers/specs/2026-07-06-decision-weight-design.md](../specs/2026-07-06-decision-weight-design.md).

## Global Constraints

Every task inherits these. Violating one is a task failure even if the code runs.

- **Five metrics only** (funds, public_support, water_readiness, crew_wellbeing, time) plus `miles_built` and flags. **Never add a sixth resource.**
- **UI never mutates state.** Scenes read GameState/EventManager and call their public methods. Display panels never assign GameState fields.
- **All game logic lives in `autoload/` and `resources/`.** The pace-risk model lives in `EventManager`; scenes only render what it reports.
- **Do not edit the authored historical cards** `data/events/01_*.tres … 21_*.tres`. New hazard cards are authored fresh (Task 1).
- **Every historical deviation is recorded** in a card's `assumption_note`.
- **One-node `.tscn` shells only.** No `.tscn` in this plan is edited by hand; all display nodes are built in `_ready()`.
- **Harness gate — after every task, all three must exit 0 before committing. Never weaken a check to make it pass; fix the cause.**
  ```powershell
  $godot = "C:\Users\wests\AppData\Local\Microsoft\WinGet\Links\godot.exe"
  & $godot --headless res://tools/smoke_test.tscn;  $LASTEXITCODE   # data/logic integrity
  & $godot --headless res://tools/sim_test.tscn;    $LASTEXITCODE   # winnability/balance
  & $godot --headless res://tools/layout_test.tscn; $LASTEXITCODE   # panels render on-screen
  ```
- **Two-strike rule:** if the same verification fails twice after your best fix, stop and report to the user with the exact error output.
- Run all commands from the repository root `C:\GitHub\Hetchy-Trail`.

## File map

| File | Task | Responsibility |
|------|------|----------------|
| `resources/event_card.gd` | 1 | +`hazard_kind` field |
| `data/events/h1_powder_blast.tres` … `h5_ratepayers_grumble.tres` | 1 | 5 repeatable hazard cards (3 injury, 2 impatience) |
| `autoload/event_manager.gd` | 1, 2 | exclude hazards from normal draw (1); pace-risk roll + `risk_preview` (2) |
| `scenes/ui/event_panel.gd` | 3 | consequence beat (outcome_text + deltas) before resolving |
| `scenes/ui/decision_panel.gd` | 4 | per-pace risk telegraph via `risk_preview` |
| `scenes/ui/hud.gd` | 5 | warning colors near loss + ongoing-cost cue |
| `tools/smoke_test.gd` | 1, 3 | hazard/deck checks (1); drive the consequence beat (3) |
| `tools/layout_test.gd` | 3 | assert the consequence beat renders on-screen |
| `tools/sim_test.gd` | 6 | keep winnable + assert hazards fire under push/rest |

## Suggested models (per the session's subagent policy)

Complete code is given for every task, so implementers can be **haiku** except where balance/winnability judgment is central. Reviewers are **sonnet** where a task touches the draw path, the event-resolution flow, or winnability; **haiku** for pure presentation diffs.

| Task | Implementer | Reviewer |
|------|-------------|----------|
| 1 hazard cards + field + exclusion | haiku | sonnet (touches draw path + adds data) |
| 2 pace-risk roll + risk_preview | sonnet (core mechanic, balance) | sonnet |
| 3 consequence beat | haiku | sonnet (event-resolution flow) |
| 4 risk telegraph | haiku | haiku |
| 5 HUD warnings | haiku | haiku |
| 6 sim hazard guard | haiku | sonnet (winnability guard) |

---

### Task 1: Hazard cards, the `hazard_kind` field, and normal-draw exclusion

Introduces the hazard content and makes it **inert** — cards exist in the deck but are never drawn yet (the pace-risk roll arrives in Task 2). This keeps every harness green after this task.

**Files:**
- Modify: `resources/event_card.gd` (add one export)
- Modify: `autoload/event_manager.gd` (`_available_cards` excludes hazards)
- Create: `data/events/h1_powder_blast.tres`, `h2_rockfall_in_the_heading.tres`, `h3_cave_in.tres`, `h4_board_questions_the_delay.tres`, `h5_ratepayers_grumble.tres`
- Modify: `tools/smoke_test.gd` (`_check_deck` count + a new `_check_hazards`)

**Interfaces:**
- Produces: `EventCard.hazard_kind: StringName` (`&""` = normal card; `&"injury"` / `&"impatience"` = hazard). Consumed by Task 2 (`_hazard_pool`, `try_draw`) and Task 6.
- Produces: 5 hazard cards, each with exactly one choice whose `repeat_card = true` (so the card re-arms after firing).

- [ ] **Step 1: Add the field to `EventCard`**

In `resources/event_card.gd`, inside the `@export_group("Draw Rules")` block, add the line directly after `@export var winter_only: bool = false`:

```gdscript
	## Empty for a normal card. "injury" or "impatience" marks a repeatable
	## hazard drawn only by EventManager's pace-risk roll, never the normal deck.
	@export var hazard_kind: StringName = &""
```

- [ ] **Step 2: Exclude hazards from the normal draw**

In `autoload/event_manager.gd`, in `_available_cards()`, add the hazard skip as the first check inside the loop. Replace:

```gdscript
	for card in deck:
		if drawn_ids.has(card.event_id):
			continue
```

with:

```gdscript
	for card in deck:
		if card.hazard_kind != &"":
			continue   # hazards are drawn only by the pace-risk roll (see try_draw)
		if drawn_ids.has(card.event_id):
			continue
```

- [ ] **Step 3: Author the 5 hazard cards**

Create each file exactly. They are non-fixed, span the whole route (mile 0–167), and each single choice sets `repeat_card = true`.

`data/events/h1_powder_blast.tres`:

```
[gd_resource type="Resource" script_class="EventCard" load_steps=4 format=3]

[ext_resource type="Script" path="res://resources/event_card.gd" id="1"]
[ext_resource type="Script" path="res://resources/event_choice.gd" id="2"]

[sub_resource type="Resource" id="choice_press_on"]
script = ExtResource("2")
label = "Absorb the setback"
outcome_text = "A charge lets go before the heading is clear. Two men are pulled out hurt; both will mend, but the shift is lost and the camp is shaken."
funds_delta = -1
crew_wellbeing_delta = -2
repeat_card = true

[resource]
script = ExtResource("1")
event_id = &"hazard_powder_blast"
title = "Premature Blast"
phase_id = &"hazard"
location_name = "A tunnel heading"
mile_start = 0
mile_end = 167
historical_year_start = 1914
historical_year_end = 1934
event_description = "A powder charge detonates before the crew is clear of the heading."
historical_fact = "Drill-and-blast tunneling was the most dangerous work on the aqueduct. Premature detonations, misfires, and falling rock injured and killed workers throughout the project's two decades."
choices = Array[ExtResource("2")]([SubResource("choice_press_on")])
canonical_choice = 0
is_fixed = false
weight = 1.0
hazard_kind = &"injury"
historical_source_note = "SFPUC historical materials; the project's general construction-safety record."
assumption_note = "A representative hazard, not a specific documented incident. It stands in for the routine dangers of drill-and-blast work and is kept deliberately distinct from the named Mitchell Shaft memorial."
```

`data/events/h2_rockfall_in_the_heading.tres`:

```
[gd_resource type="Resource" script_class="EventCard" load_steps=4 format=3]

[ext_resource type="Script" path="res://resources/event_card.gd" id="1"]
[ext_resource type="Script" path="res://resources/event_choice.gd" id="2"]

[sub_resource type="Resource" id="choice_press_on"]
script = ExtResource("2")
label = "Timber it and go on"
outcome_text = "Loose rock comes down where a man was working moments before. He is bruised, not broken, but the crew works the next round watching the back."
crew_wellbeing_delta = -1
repeat_card = true

[resource]
script = ExtResource("1")
event_id = &"hazard_rockfall"
title = "Rockfall in the Heading"
phase_id = &"hazard"
location_name = "A tunnel heading"
mile_start = 0
mile_end = 167
historical_year_start = 1914
historical_year_end = 1934
event_description = "Ground works loose overhead in an active bore."
historical_fact = "Falling rock in the tunnel headings was a constant threat; crews timbered and later gunited the bores to hold the ground, but injuries from falls of ground were common."
choices = Array[ExtResource("2")]([SubResource("choice_press_on")])
canonical_choice = 0
is_fixed = false
weight = 1.0
hazard_kind = &"injury"
historical_source_note = "SFPUC historical materials; general tunnel-construction practice of the era."
assumption_note = "A representative hazard rather than a specific documented incident."
```

`data/events/h3_cave_in.tres`:

```
[gd_resource type="Resource" script_class="EventCard" load_steps=4 format=3]

[ext_resource type="Script" path="res://resources/event_card.gd" id="1"]
[ext_resource type="Script" path="res://resources/event_choice.gd" id="2"]

[sub_resource type="Resource" id="choice_press_on"]
script = ExtResource("2")
label = "Re-timber and recover"
outcome_text = "A run of ground caves behind the timbering. No one is buried, but clearing and re-setting the sets costs a shift and a hard day's pay in materials."
funds_delta = -1
crew_wellbeing_delta = -1
repeat_card = true

[resource]
script = ExtResource("1")
event_id = &"hazard_cave_in"
title = "Ground Runs Behind the Sets"
phase_id = &"hazard"
location_name = "A tunnel heading"
mile_start = 0
mile_end = 167
historical_year_start = 1914
historical_year_end = 1934
event_description = "Bad ground collapses behind the timber sets."
historical_fact = "In squeezing or broken ground the crews fought caves and running material, re-timbering and reinforcing to keep the bore open — slow, costly, and dangerous work."
choices = Array[ExtResource("2")]([SubResource("choice_press_on")])
canonical_choice = 0
is_fixed = false
weight = 1.0
hazard_kind = &"injury"
historical_source_note = "SFPUC historical materials; general tunnel-construction practice of the era."
assumption_note = "A representative hazard rather than a specific documented incident."
```

`data/events/h4_board_questions_the_delay.tres`:

```
[gd_resource type="Resource" script_class="EventCard" load_steps=4 format=3]

[ext_resource type="Script" path="res://resources/event_card.gd" id="1"]
[ext_resource type="Script" path="res://resources/event_choice.gd" id="2"]

[sub_resource type="Resource" id="choice_answer"]
script = ExtResource("2")
label = "Answer the Board"
outcome_text = "Another season with the headings quiet, and the Board wants to know why. You spend goodwill and a little money keeping the doubters on side."
funds_delta = -1
public_support_delta = -1
repeat_card = true

[resource]
script = ExtResource("1")
event_id = &"hazard_board_impatient"
title = "The Board Questions the Delay"
phase_id = &"hazard"
location_name = "City Hall, San Francisco"
mile_start = 0
mile_end = 167
historical_year_start = 1914
historical_year_end = 1934
event_description = "An idle season draws hard questions from the city's overseers."
historical_fact = "The project ran for two decades under close political and financial scrutiny; long stretches without visible progress fed skepticism about cost and schedule at City Hall and in the press."
choices = Array[ExtResource("2")]([SubResource("choice_answer")])
canonical_choice = 0
is_fixed = false
weight = 1.0
hazard_kind = &"impatience"
historical_source_note = "SFPUC historical materials; the project's political and financing history."
assumption_note = "A representative expression of political impatience, not a specific documented meeting."
```

`data/events/h5_ratepayers_grumble.tres`:

```
[gd_resource type="Resource" script_class="EventCard" load_steps=4 format=3]

[ext_resource type="Script" path="res://resources/event_card.gd" id="1"]
[ext_resource type="Script" path="res://resources/event_choice.gd" id="2"]

[sub_resource type="Resource" id="choice_weather"]
script = ExtResource("2")
label = "Weather the grumbling"
outcome_text = "Ratepayers ask what they are paying for while the mountains stay silent. Support slips a little; the work will have to speak for itself."
public_support_delta = -1
repeat_card = true

[resource]
script = ExtResource("1")
event_id = &"hazard_ratepayers"
title = "Ratepayers Grumble"
phase_id = &"hazard"
location_name = "San Francisco"
mile_start = 0
mile_end = 167
historical_year_start = 1914
historical_year_end = 1934
event_description = "With no water flowing yet, the public wonders where the years are going."
historical_fact = "San Franciscans paid for the project for twenty years before a drop of Hetch Hetchy water arrived, and public patience was not unlimited during the long build."
choices = Array[ExtResource("2")]([SubResource("choice_weather")])
canonical_choice = 0
is_fixed = false
weight = 1.0
hazard_kind = &"impatience"
historical_source_note = "SFPUC historical materials; the project's public-financing history."
assumption_note = "A representative expression of public impatience, not a specific documented episode."
```

- [ ] **Step 4: Update the smoke test — deck count and hazard checks**

In `tools/smoke_test.gd`, change the deck-count assertion in `_check_deck()` from `21` to `26`:

```gdscript
	check(EventManager.deck.size() == 26, "exactly 26 event cards loaded (got %d)" % EventManager.deck.size())
```

Add `_check_hazards()` to the `_ready()` run list, on the line after `_check_deck()`:

```gdscript
	_check_deck()
	_check_hazards()
```

Append this function to the end of `tools/smoke_test.gd`:

```gdscript
func _check_hazards() -> void:
	var kinds := {&"injury": 0, &"impatience": 0}
	for card in EventManager.deck:
		if card.hazard_kind == &"":
			continue
		check(kinds.has(card.hazard_kind),
			"hazard %s has a valid kind (injury/impatience)" % card.event_id)
		if kinds.has(card.hazard_kind):
			kinds[card.hazard_kind] += 1
		check(card.choices.size() == 1, "hazard %s has exactly one choice" % card.event_id)
		if card.choices.size() == 1:
			check(card.choices[0].repeat_card,
				"hazard %s re-arms itself (repeat_card)" % card.event_id)
			check(card.choices[0].outcome_text != "",
				"hazard %s has outcome_text for the consequence beat" % card.event_id)
		check(not card.is_fixed, "hazard %s is not a fixed spine card" % card.event_id)
	check(kinds[&"injury"] == 3, "exactly 3 injury hazards (got %d)" % kinds[&"injury"])
	check(kinds[&"impatience"] == 2, "exactly 2 impatience hazards (got %d)" % kinds[&"impatience"])
```

- [ ] **Step 5: Run the harness gate**

```powershell
$godot = "C:\Users\wests\AppData\Local\Microsoft\WinGet\Links\godot.exe"
& $godot --headless res://tools/smoke_test.tscn;  $LASTEXITCODE
& $godot --headless res://tools/sim_test.tscn;    $LASTEXITCODE
& $godot --headless res://tools/layout_test.tscn; $LASTEXITCODE
```

Expected: `SMOKE PASS`, `SIM PASS`, `LAYOUT PASS`, each exit `0`. (Hazards are inert this task, so sim/layout are unchanged; smoke now counts 26 cards and validates the 5 hazards.) If smoke fails on a hazard check, the fault is in the `.tres` you just wrote — fix the card, not the check.

- [ ] **Step 6: Commit**

```powershell
git add resources/event_card.gd autoload/event_manager.gd data/events/ tools/smoke_test.gd
git commit -m "feat: repeatable hazard cards + hazard_kind field (inert until pace-risk roll)"
```

---

### Task 2: The pace-risk roll and `risk_preview`

Wires the hazards to pace. After this task, pushing risks injuries and resting risks impatience, both amplified when the relevant meter is already low.

**Files:**
- Modify: `autoload/event_manager.gd` (constants, `try_draw`, new helpers, `risk_preview`)

**Interfaces:**
- Consumes: `EventCard.hazard_kind` (Task 1); `GameState.work_pace`, `GameState.Pace`, `crew_wellbeing`, `public_support`, `season`, `miles_built`, `flags`.
- Produces: `EventManager.risk_preview(pace: int) -> Dictionary` returning `{"kind": StringName, "level": StringName}` where `kind` is `&"injury"`/`&"impatience"` and `level` is `&"low"`/`&"elevated"`/`&"high"`. Consumed by Task 4. Turn contract unchanged: still at most one event per turn, fixed spine still fires first.

- [ ] **Step 1: Add the tuning constants**

In `autoload/event_manager.gd`, directly below the existing `@export_range(0.0, 1.0) var event_chance := 0.6` line, add:

```gdscript

# --- Pace-risk tuning (Task 10 balance pass may adjust these) ---------------
const PUSHED_INJURY_CHANCE := 0.30      # base chance of an injury on a PUSHED season
const REST_IMPATIENCE_CHANCE := 0.35    # base chance of impatience on a REST season
const STEADY_MISHAP_CHANCE := 0.08      # low baseline on a STEADY season
const LOW_CREW_THRESHOLD := 4           # crew at/below this amplifies injury risk
const LOW_SUPPORT_THRESHOLD := 4        # support at/below this amplifies impatience
const LOW_METER_RISK_BONUS := 0.25      # added chance when the relevant meter is low
# ----------------------------------------------------------------------------
```

- [ ] **Step 2: Add the risk model and hazard-pool helpers**

Append these functions to `autoload/event_manager.gd` (after `_weighted_pick`):

```gdscript
## The dominant hazard kind and roll chance for a pace, given current state.
func _risk_for(pace: int) -> Dictionary:
	match pace:
		GameState.Pace.PUSHED:
			var c := PUSHED_INJURY_CHANCE
			if GameState.crew_wellbeing <= LOW_CREW_THRESHOLD:
				c += LOW_METER_RISK_BONUS
			return {"kind": &"injury", "chance": c}
		GameState.Pace.REST:
			var c := REST_IMPATIENCE_CHANCE
			if GameState.public_support <= LOW_SUPPORT_THRESHOLD:
				c += LOW_METER_RISK_BONUS
			return {"kind": &"impatience", "chance": c}
		_:
			# STEADY: a low chance, aimed at whichever meter is currently weaker.
			if GameState.crew_wellbeing <= GameState.public_support:
				return {"kind": &"injury", "chance": STEADY_MISHAP_CHANCE}
			return {"kind": &"impatience", "chance": STEADY_MISHAP_CHANCE}


## Read-only telegraph for the DecisionPanel (Task 4). No side effects.
func risk_preview(pace: int) -> Dictionary:
	var risk := _risk_for(pace)
	var chance: float = risk["chance"]
	var level: StringName = &"low"
	if chance >= 0.40:
		level = &"high"
	elif chance >= 0.25:
		level = &"elevated"
	return {"kind": risk["kind"], "level": level}


func _hazard_pool(kind: StringName) -> Array[EventCard]:
	var is_winter := GameState.season == GameState.Season.WINTER
	var out: Array[EventCard] = []
	for card in deck:
		if card.hazard_kind != kind:
			continue
		if drawn_ids.has(card.event_id):
			continue
		if card.is_available(GameState.miles_built, is_winter, GameState.flags):
			out.append(card)
	return out


func _pick_hazard(kind: StringName) -> EventCard:
	var pool := _hazard_pool(kind)
	if pool.is_empty():
		return null
	return _weighted_pick(pool)
```

- [ ] **Step 3: Insert the roll into `try_draw`**

In `autoload/event_manager.gd`, replace the body of `try_draw()`:

```gdscript
func try_draw() -> EventCard:
	if GameState.game_over:
		return null
	var available := _available_cards()
	for card in available:
		if card.is_fixed:
			return _draw(card)
	if available.is_empty() or randf() > event_chance:
		return null
	return _draw(_weighted_pick(available))
```

with:

```gdscript
func try_draw() -> EventCard:
	if GameState.game_over:
		return null
	var available := _available_cards()
	for card in available:
		if card.is_fixed:
			return _draw(card)
	# Pace-risk: the season just worked may trigger a hazard before texture cards.
	var risk := _risk_for(GameState.work_pace)
	if randf() < float(risk["chance"]):
		var hazard := _pick_hazard(risk["kind"])
		if hazard != null:
			return _draw(hazard)
	if available.is_empty() or randf() > event_chance:
		return null
	return _draw(_weighted_pick(available))
```

- [ ] **Step 4: Run the harness gate**

```powershell
$godot = "C:\Users\wests\AppData\Local\Microsoft\WinGet\Links\godot.exe"
& $godot --headless res://tools/smoke_test.tscn;  $LASTEXITCODE
& $godot --headless res://tools/sim_test.tscn;    $LASTEXITCODE
& $godot --headless res://tools/layout_test.tscn; $LASTEXITCODE
```

Expected: all three PASS, exit `0`. The sim plays STEADY (low hazard rate), so it must still finish `system_complete` ≤1940. If SIM now FAILs because crew is drained by STEADY mishaps, the STEADY rate is too high — lower `STEADY_MISHAP_CHANCE` (this is the only knob to touch here); do not weaken a check. Two failed attempts → stop and report the printed SIM lines.

- [ ] **Step 5: Commit**

```powershell
git add autoload/event_manager.gd
git commit -m "feat: pace-risk roll - push risks injury, rest risks impatience, scaled by board state"
```

---

### Task 3: The consequence beat

Before an event resolves, the panel shows the choice's authored `outcome_text` and the metric changes, then a Continue button. This is the centerpiece of "felt" feedback and applies to every card, hazards included.

**Files:**
- Modify: `scenes/ui/event_panel.gd`
- Modify: `tools/smoke_test.gd` (`_check_ui_scenes` drives the new two-step flow)
- Modify: `tools/layout_test.gd` (assert the beat renders on-screen)

**Interfaces:**
- Consumes: `EventCard.choices[i]` fields `outcome_text`, `funds_delta`, `public_support_delta`, `water_readiness_delta`, `crew_wellbeing_delta`, `time_delta_seasons`, `label`.
- Produces: unchanged public contract — `show_card(card)` and `choice_selected(index)` still emitted only after the panel hides. New internal methods `_on_choice(index)` (now shows the beat) and `_on_continue(index)` (hides + emits). Journey is unchanged.

- [ ] **Step 1: Rewrite `event_panel.gd` to add the beat**

Replace the entire contents of `scenes/ui/event_panel.gd` with:

```gdscript
extends Control
## Displays one EventCard: description, choices, and the teaching layer
## ("What really happened" + assumption note + optional archival photo).
## On a choice, shows the outcome_text + metric changes as a consequence beat,
## then emits choice_selected only after the player presses Continue.

signal choice_selected(index: int)

var title_label: Label
var body_label: Label
var photo_rect: TextureRect
var fact_label: Label
var note_label: Label
var buttons_box: VBoxContainer
var current_card: EventCard


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
	current_card = card
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


## First press: swap the choice buttons for the consequence beat.
func _on_choice(index: int) -> void:
	var choice: EventChoice = current_card.choices[index]
	for child in buttons_box.get_children():
		child.queue_free()
	var outcome := _add_label(buttons_box)
	outcome.text = choice.outcome_text
	var deltas := _add_label(buttons_box)
	deltas.text = _deltas_text(choice)
	var cont := Button.new()
	cont.text = "Continue"
	cont.pressed.connect(_on_continue.bind(index))
	buttons_box.add_child(cont)


## Second press: hide and report the choice so it is applied.
func _on_continue(index: int) -> void:
	hide()
	choice_selected.emit(index)


func _deltas_text(choice: EventChoice) -> String:
	var parts: Array[String] = []
	if choice.funds_delta != 0:
		parts.append("Funds %+d" % choice.funds_delta)
	if choice.public_support_delta != 0:
		parts.append("Support %+d" % choice.public_support_delta)
	if choice.water_readiness_delta != 0:
		parts.append("Readiness %+d" % choice.water_readiness_delta)
	if choice.crew_wellbeing_delta != 0:
		parts.append("Crew %+d" % choice.crew_wellbeing_delta)
	if choice.time_delta_seasons > 0:
		parts.append("lost %d season(s)" % choice.time_delta_seasons)
	elif choice.time_delta_seasons < 0:
		parts.append("banked %d season(s)" % -choice.time_delta_seasons)
	if parts.is_empty():
		return "No change to the ledger."
	return "   ".join(parts)
```

- [ ] **Step 2: Update the smoke UI check to drive both presses**

In `tools/smoke_test.gd`, in `_check_ui_scenes()`, replace:

```gdscript
	journey.event_panel._on_choice(0)
	check(GameState.has_flag(&"high_sierra_access_complete"), "resolving via UI grants the flag")
```

with:

```gdscript
	journey.event_panel._on_choice(0)
	check(GameState.miles_built > 0.0 and not GameState.has_flag(&"high_sierra_access_complete"),
		"choosing shows the consequence beat but does not resolve yet")
	journey.event_panel._on_continue(0)
	check(GameState.has_flag(&"high_sierra_access_complete"), "Continue resolves and grants the flag")
```

- [ ] **Step 3: Extend the layout test to cover the beat**

In `tools/layout_test.gd`, replace this block in `_ready()`:

```gdscript
	journey.event_panel.show()
	await get_tree().process_frame
	_check_on_screen("EventPanel body", _first_control_child(journey.event_panel), vp)
```

with:

```gdscript
	journey.event_panel.show_card(EventManager.deck[0])
	await get_tree().process_frame
	_check_on_screen("EventPanel body", _first_control_child(journey.event_panel), vp)
	journey.event_panel._on_choice(0)
	await get_tree().process_frame
	_check_on_screen("Consequence beat", _first_control_child(journey.event_panel), vp)
```

- [ ] **Step 4: Run the harness gate**

```powershell
$godot = "C:\Users\wests\AppData\Local\Microsoft\WinGet\Links\godot.exe"
& $godot --headless res://tools/smoke_test.tscn;  $LASTEXITCODE
& $godot --headless res://tools/sim_test.tscn;    $LASTEXITCODE
& $godot --headless res://tools/layout_test.tscn; $LASTEXITCODE
```

Expected: all three PASS, exit `0`. Note the sim resolves choices through `EventManager.resolve_choice` directly (not the panel), so it is unaffected by the beat.

- [ ] **Step 5: Commit**

```powershell
git add scenes/ui/event_panel.gd tools/smoke_test.gd tools/layout_test.gd
git commit -m "feat: consequence beat - show outcome text and metric changes before resolving"
```

---

### Task 4: DecisionPanel risk telegraph

Each pace option now shows its risk read from current state, so the stakes are visible before committing.

**Files:**
- Modify: `scenes/ui/decision_panel.gd`

**Interfaces:**
- Consumes: `EventManager.risk_preview(pace: int) -> {kind, level}` (Task 2).
- Produces: no new public surface; adds an internal `_refresh_risk()` and a `risk_label`. `refresh_affordability()` now also refreshes the telegraph.

- [ ] **Step 1: Rewrite `decision_panel.gd` to add the telegraph**

Replace the entire contents of `scenes/ui/decision_panel.gd` with:

```gdscript
extends Control
## DECIDE-phase form: pace + one optional action + End Season, plus a live
## telegraph of the risk the chosen pace carries this season.
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
var risk_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	# Bottom-anchored containers grow downward by default, which pushes the bar
	# off the bottom edge; grow upward so it sits on-screen above the edge.
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	pace_select = OptionButton.new()
	for pace_name in ["Rest the crews", "Steady work", "Push the pace"]:
		pace_select.add_item(pace_name)
	pace_select.select(GameState.Pace.STEADY)
	pace_select.item_selected.connect(func(_i: int): _refresh_risk())
	row.add_child(pace_select)
	action_select = OptionButton.new()
	for action_label in ACTION_LABELS:
		action_select.add_item(action_label)
	row.add_child(action_select)
	end_button = Button.new()
	end_button.text = "End season"
	end_button.pressed.connect(_on_end_pressed)
	row.add_child(end_button)
	risk_label = Label.new()
	col.add_child(risk_label)
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
	_refresh_risk()


func _refresh_risk() -> void:
	var preview: Dictionary = EventManager.risk_preview(pace_select.selected)
	var noun := "injury" if preview["kind"] == &"injury" else "public impatience"
	risk_label.text = "This season's risk: %s chance of %s" % [String(preview["level"]), noun]
```

- [ ] **Step 2: Run the harness gate**

```powershell
$godot = "C:\Users\wests\AppData\Local\Microsoft\WinGet\Links\godot.exe"
& $godot --headless res://tools/smoke_test.tscn;  $LASTEXITCODE
& $godot --headless res://tools/sim_test.tscn;    $LASTEXITCODE
& $godot --headless res://tools/layout_test.tscn; $LASTEXITCODE
```

Expected: all three PASS, exit `0`. The layout test's DecisionPanel check confirms the now-taller bar still sits on-screen (it grows upward). If the bar's top edge fails the on-screen check, the panel is too tall for the viewport — it should not be; report if so rather than shrinking the check.

- [ ] **Step 3: Commit**

```powershell
git add scenes/ui/decision_panel.gd
git commit -m "feat: DecisionPanel telegraphs each pace's risk from current board state"
```

---

### Task 5: HUD warnings and ongoing-cost cue

Metrics trending toward a loss condition turn warning-rust, and the silent pumped-line winter surcharge is finally shown.

**Files:**
- Modify: `scenes/ui/hud.gd`

**Interfaces:**
- Consumes: existing GameState signals/fields; `has_flag(&"pumped_alternative_chosen")`.
- Produces: no new public surface. `labels` still has exactly its 6 keys (the smoke UI check asserts `labels.size() == 6`); the ongoing-cost cue is a separate `cost_label`.

- [ ] **Step 1: Rewrite `hud.gd` with warning colors and the cost cue**

Replace the entire contents of `scenes/ui/hud.gd` with:

```gdscript
extends CanvasLayer
## Read-only display of the five metrics, the date, and the construction front.
## Metrics near a loss condition turn warning-rust; ongoing drains are surfaced.

const SEASONS := ["Winter", "Spring", "Summer", "Fall"]
const WARN_COLOR := Color(0.65, 0.32, 0.18)   # warning rust (#A6532E), per art_assets.md
const FUNDS_WARN_AT := 2                        # bond crisis strikes below 0
const METER_WARN_AT := 2                        # support->cancelled, crew->halt at 0

var labels := {}
var cost_label: Label


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(panel)
	var col := VBoxContainer.new()
	panel.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	for key in ["date", "miles", "funds", "support", "water", "crew"]:
		var label := Label.new()
		row.add_child(label)
		labels[key] = label
	cost_label = Label.new()
	cost_label.modulate = WARN_COLOR
	cost_label.visible = false
	col.add_child(cost_label)
	GameState.funds_changed.connect(_set_funds)
	GameState.support_changed.connect(_set_support)
	GameState.crew_changed.connect(_set_crew)
	GameState.readiness_changed.connect(_set_water)
	GameState.flag_granted.connect(_on_flag)
	GameState.miles_changed.connect(func(v: float): labels["miles"].text = "Mile %.1f of 167" % v)
	GameState.turn_advanced.connect(func(y: int, s: int): labels["date"].text = "%s %d" % [SEASONS[s], y])
	_refresh()


func _refresh() -> void:
	_set_funds(GameState.funds)
	_set_support(GameState.public_support)
	_set_crew(GameState.crew_wellbeing)
	labels["miles"].text = "Mile %.1f of 167" % GameState.miles_built
	labels["date"].text = "%s %d" % [SEASONS[GameState.season], GameState.year]
	_set_water(GameState.water_readiness)
	_update_cost_cue()


func _set_funds(v: int) -> void:
	labels["funds"].text = "Funds: %d" % v
	_warn(labels["funds"], v <= FUNDS_WARN_AT)


func _set_support(v: int) -> void:
	labels["support"].text = "Support: %d/10" % v
	_warn(labels["support"], v <= METER_WARN_AT)


func _set_crew(v: int) -> void:
	labels["crew"].text = "Crew: %d/10" % v
	_warn(labels["crew"], v <= METER_WARN_AT)


func _set_water(v: int) -> void:
	var note := " — delivered!" if GameState.has_flag(&"hetch_hetchy_water_delivered") else " (not yet delivered)"
	labels["water"].text = "Water readiness: %d/%d%s" % [v, GameState.READINESS_TARGET, note]


func _on_flag(_f: StringName) -> void:
	_set_water(GameState.water_readiness)
	_update_cost_cue()


func _update_cost_cue() -> void:
	if GameState.has_flag(&"pumped_alternative_chosen"):
		cost_label.text = "Pumping: -1 funds every winter"
		cost_label.visible = true
	else:
		cost_label.visible = false


func _warn(label: Label, on: bool) -> void:
	if on:
		label.add_theme_color_override("font_color", WARN_COLOR)
	else:
		label.remove_theme_color_override("font_color")
```

- [ ] **Step 2: Run the harness gate**

```powershell
$godot = "C:\Users\wests\AppData\Local\Microsoft\WinGet\Links\godot.exe"
& $godot --headless res://tools/smoke_test.tscn;  $LASTEXITCODE
& $godot --headless res://tools/sim_test.tscn;    $LASTEXITCODE
& $godot --headless res://tools/layout_test.tscn; $LASTEXITCODE
```

Expected: all three PASS, exit `0`. The smoke UI check still sees `labels.size() == 6` (the cost cue is a separate label, not a `labels` entry).

- [ ] **Step 3: Commit**

```powershell
git add scenes/ui/hud.gd
git commit -m "feat: HUD warns on metrics nearing a loss and surfaces the pumping surcharge"
```

---

### Task 6: Sim guard — hazards fire and the campaign still wins

Locks in the mechanic: the seeded canonical run must still complete, and a deterministic probe proves injuries fire under push and impatience fires under rest.

**Files:**
- Modify: `tools/sim_test.gd`

**Interfaces:**
- Consumes: `EventManager.event_drawn(card)`, `EventCard.hazard_kind`, `GameState.Pace`, `advance_turn`, `try_draw`, `resolve_choice`.
- Produces: `SIM PASS` only when the canonical run finishes `system_complete` ≤1940 **and** both probes see their hazard kind.

- [ ] **Step 1: Rewrite `sim_test.gd` to add the probes**

Replace the entire contents of `tools/sim_test.gd` with:

```gdscript
extends Node
## Plays a full campaign headless (STEADY pace, canonical choices) and then runs
## two deterministic probes proving the pace-risk mechanic fires.
## Run:  godot --headless res://tools/sim_test.tscn
## PASS = system complete by 1940 AND injuries fire under push, impatience under
## rest. Deterministic (fixed seed). Never weaken a check to make it pass.

const MAX_TURNS := 160
const PROBE_TURNS := 25
const SEASONS := ["Winter", "Spring", "Summer", "Fall"]

var result: StringName = &""
var hazards_seen := 0


func _ready() -> void:
	seed(1234)
	# --- Canonical winnability run (STEADY) ---
	GameState.new_game()
	EventManager.reset()
	GameState.game_ended.connect(func(r: StringName): result = r)
	var count_hazards := func(card: EventCard):
		if card.hazard_kind != &"":
			hazards_seen += 1
	EventManager.event_drawn.connect(count_hazards)
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
	EventManager.event_drawn.disconnect(count_hazards)
	var final_result := result
	var final_year := GameState.year
	print("SIM RESULT: %s | %s %d | mile %.0f | readiness %d | funds %d | support %d | crew %d | %d turns | %d hazards"
		% [final_result, SEASONS[GameState.season], final_year, GameState.miles_built,
		GameState.water_readiness, GameState.funds, GameState.public_support,
		GameState.crew_wellbeing, turns, hazards_seen])

	# --- Mechanic probes (deterministic; continue the seeded RNG stream) ---
	var injuries := _probe(GameState.Pace.PUSHED, &"injury")
	var impatience := _probe(GameState.Pace.REST, &"impatience")
	print("SIM PROBE: push->injury=%d  rest->impatience=%d" % [injuries, impatience])

	var win := final_result == &"system_complete" and final_year <= 1940
	if win and injuries > 0 and impatience > 0:
		print("SIM PASS: system_complete, grade=%s" % GameState.completion_grade())
		get_tree().quit(0)
	else:
		print("SIM FAIL")
		get_tree().quit(1)


## Force a pace for PROBE_TURNS from a fresh game; return how many hazards of the
## given kind fired. Injuries can drain crew to a loss, which just ends the probe.
func _probe(pace: int, kind: StringName) -> int:
	GameState.new_game()
	EventManager.reset()
	var seen := {"n": 0}
	var cb := func(card: EventCard):
		if card.hazard_kind == kind:
			seen["n"] += 1
	EventManager.event_drawn.connect(cb)
	for i in PROBE_TURNS:
		if GameState.game_over:
			break
		GameState.work_pace = pace
		GameState.advance_turn()
		if GameState.game_over:
			break
		var card := EventManager.try_draw()
		if card != null:
			EventManager.resolve_choice(card, card.canonical_choice)
	EventManager.event_drawn.disconnect(cb)
	return seen["n"]
```

- [ ] **Step 2: Run the harness gate**

```powershell
$godot = "C:\Users\wests\AppData\Local\Microsoft\WinGet\Links\godot.exe"
& $godot --headless res://tools/smoke_test.tscn;  $LASTEXITCODE
& $godot --headless res://tools/sim_test.tscn;    $LASTEXITCODE
& $godot --headless res://tools/layout_test.tscn; $LASTEXITCODE
```

Expected: all three PASS, exit `0`. The `SIM PROBE:` line should show non-zero counts for both. If a probe shows `0`, the corresponding base chance in Task 2 is too low for `PROBE_TURNS` to reliably trigger under the seed — raise it slightly in `event_manager.gd` (that is a real mechanic gap, not a test to weaken) and re-run. Two failed attempts → stop and report the printed SIM lines.

- [ ] **Step 3: Commit**

```powershell
git add tools/sim_test.gd
git commit -m "test: sim guards winnability and proves pace-risk hazards fire"
```

---

## After this plan

Update `.superpowers/sdd/progress.md` with a Decision-Weight section (Tasks DW1–DW6), then **resume the original [playable-core plan](../../plans/2026-07-05-playable-core.md) at Task 8** (route map). The pace-risk chances added here become additional knobs for that plan's **Task 10 balance pass** — tune `PUSHED_INJURY_CHANCE`, `REST_IMPATIENCE_CHANCE`, `STEADY_MISHAP_CHANCE`, and `LOW_METER_RISK_BONUS` alongside the existing pace/funds knobs so the canonical run still lands 1932–1936 and the probes stay green.

**Deferred (own future plans, not started here):** mini-games on event cards (the "redeem resources from a poor choice" hook, placeholder-first) and the art-asset pass.
