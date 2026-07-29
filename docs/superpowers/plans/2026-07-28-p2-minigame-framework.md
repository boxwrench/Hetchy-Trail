# Plan — P2: the minigame framework, stub-first

**For the worker model.** Every step is explicit. No step requires a design
decision. If one appears to, stop and report.

## Why this exists

There is no `MinigameConfig`, `MinigameResult`, or module contract anywhere in
the tree. Slot 1 (The Heading) is the first consumer, and
[01-the-heading.md](../specs/minigames/01-the-heading.md) says plainly that the
plan must define the types before building the slot.

This plan builds **the contract and a stub only**. No press-your-luck loop, no
tuning, no `minigame_sim` band verification — those come with the real module.
Per the standing rule, the slot ships as a stub first.

## The one thing that would be wrong to build

`01-the-heading.md` used to specify a five-field result payload. It has been
corrected, and the contract is now, and only:

```
MinigameResult := { score: int, tier: StringName }
```

**No metrics, no deltas, no prose, no flags, no time, no hazard id.** The tier
selects among the driving card's *already authored* `EventChoice`s. If you find
yourself adding a field to carry a consequence, stop — the consequence belongs
to the card.

## Success criteria

1. `godot --headless res://tools/minigame_check.tscn` exits 0 and prints
   `MINIGAME PASS`.
2. `smoke_test` prints `SMOKE PASS (354 checks)` — unchanged.
3. `layout_test` prints `LAYOUT PASS (265 checks)` — unchanged.
4. `sim_test` still reports `grade=matched_history`.
5. Launching the campaign and reaching **The 803-Foot Month** shows the stub,
   and picking a tier applies the matching authored choice.

---

## Task 1 — The two resource types

- [x] Create `resources/minigame_config.gd`:

```gdscript
class_name MinigameConfig
extends Resource
## What a minigame module is handed when it opens. Built by the caller --
## Journey for a card-driven launch, the arcade entry for a standalone one.
##
## Deliberately generic: module-specific numbers live in `params` rather than as
## typed fields, so adding a second minigame never edits this file.

@export var minigame_id: StringName = &""
## The card that opened it. Empty for an arcade launch with no driving card.
@export var event_id: StringName = &""
## Module-specific inputs, e.g. {"target_feet": 803}. Keys are the module's own
## business; nothing outside the module may read them.
@export var params: Dictionary = {}
## 0 means "pick one at runtime". Set non-zero for reproducible runs in tools.
@export var seed: int = 0


func has_param(key: String) -> bool:
	return params.has(key)


func get_int(key: String, fallback: int) -> int:
	if not params.has(key):
		return fallback
	return int(params[key])
```

- [x] Create `resources/minigame_result.gd`:

```gdscript
class_name MinigameResult
extends Resource
## What a minigame module returns. Score and tier, and nothing else.
##
## The module never applies an effect. The tier selects among the driving card's
## authored EventChoices, so all consequence numbers and all prose stay in
## content/. Adding a field here to carry a consequence is a contract violation,
## not a convenience.

const TIERS: Array[StringName] = [&"poor", &"fair", &"strong"]

@export var minigame_id: StringName = &""
## Module-defined magnitude. Comparable only within one minigame_id.
@export var score: int = 0
@export var tier: StringName = &"poor"


func is_valid() -> bool:
	return minigame_id != &"" and TIERS.has(tier)


static func make(id: StringName, p_score: int, p_tier: StringName) -> MinigameResult:
	var r := MinigameResult.new()
	r.minigame_id = id
	r.score = p_score
	r.tier = p_tier
	return r
```

**Do not create `.uid` files.** Godot generates them on import.

## Task 2 — The registry

- [x] Create `resources/minigame_registry.gd`:

```gdscript
class_name MinigameRegistry
extends RefCounted
## Which cards open a minigame, and how each tier maps back onto that card's
## authored choices.
##
## The binding lives HERE and not on EventCard on purpose. content/cards/*.md is
## the canonical source for card data and is historian territory; adding a
## front-matter key there would mean editing content/ and tools/import_cards.gd
## for a framework change. Keeping the binding on this side means the framework
## can land, and be reverted, without touching authored content at all.

## event_id -> binding.
##   minigame_id : which module opens
##   params      : handed to the module as MinigameConfig.params
##   tier_choice : tier -> index into that card's `choices` array
##
## The 803-Foot Month authors exactly two choices, so the map is many-to-one:
##   index 0 = "Chase the record", index 1 = "Hold a sustainable pace".
const BINDINGS := {
	&"the_803_foot_month": {
		"minigame_id": &"the_heading",
		"params": {"target_feet": 803},
		"tier_choice": {&"strong": 0, &"fair": 1, &"poor": 1},
	},
}


static func has_binding(event_id: StringName) -> bool:
	return BINDINGS.has(event_id)


static func config_for(event_id: StringName) -> MinigameConfig:
	if not BINDINGS.has(event_id):
		return null
	var b: Dictionary = BINDINGS[event_id]
	var cfg := MinigameConfig.new()
	cfg.minigame_id = b["minigame_id"]
	cfg.event_id = event_id
	cfg.params = (b["params"] as Dictionary).duplicate(true)
	return cfg


## Which authored choice a tier resolves to. Returns -1 when unmapped, which
## callers must treat as "do not open the minigame" rather than as index 0.
static func choice_for_tier(event_id: StringName, tier: StringName) -> int:
	if not BINDINGS.has(event_id):
		return -1
	var map: Dictionary = BINDINGS[event_id]["tier_choice"]
	if not map.has(tier):
		return -1
	return int(map[tier])
```

## Task 3 — The stub scene

- [x] Create `scenes/minigames/minigame_stub.gd`:

```gdscript
extends Control
## STUB. Stands in for every minigame module until the real ones are built.
##
## It exists to prove the contract end to end: a config goes in, a valid
## MinigameResult comes out, and Journey applies the card choice the tier maps
## to. It contains no gameplay and models nothing.
##
## The three tier buttons are a TEST AFFORDANCE, not a design. A single Resolve
## button could only ever exercise one of the three mappings.

signal finished(result: MinigameResult)

var config: MinigameConfig


func open(cfg: MinigameConfig) -> void:
	config = cfg
	var title := $Panel/Box/Title as Label
	title.text = "STUB — %s" % cfg.minigame_id
	var note := $Panel/Box/Note as Label
	note.text = "Placeholder for the real module. Pick a tier to test the mapping."
	for child in ($Panel/Box/Buttons as BoxContainer).get_children():
		child.queue_free()
	for tier in MinigameResult.TIERS:
		var button := Button.new()
		button.text = String(tier)
		button.pressed.connect(_on_tier.bind(tier))
		($Panel/Box/Buttons as BoxContainer).add_child(button)
	show()


func _on_tier(tier: StringName) -> void:
	hide()
	# Score is illustrative only; nothing reads it until a real module exists.
	var target := config.get_int("target_feet", 0)
	var score := 0
	if tier == &"strong":
		score = target
	elif tier == &"fair":
		score = int(round(0.6 * float(target)))
	finished.emit(MinigameResult.make(config.minigame_id, score, tier))
```

- [x] Create `scenes/minigames/minigame_stub.tscn` with exactly this content:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/minigames/minigame_stub.gd" id="1"]

[node name="MinigameStub" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")

[node name="Panel" type="PanelContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -260.0
offset_top = -110.0
offset_right = 260.0
offset_bottom = 110.0

[node name="Box" type="VBoxContainer" parent="Panel"]
layout_mode = 2

[node name="Title" type="Label" parent="Panel/Box"]
layout_mode = 2
text = "STUB"

[node name="Note" type="Label" parent="Panel/Box"]
layout_mode = 2
autowrap_mode = 3

[node name="Buttons" type="HBoxContainer" parent="Panel/Box"]
layout_mode = 2
```

## Task 4 — Journey integration

- [x] In `scenes/ui/event_panel.gd`, add this method. Put it immediately after
      `_on_choice`, and change nothing else in the file:

```gdscript
## Drive the consequence beat from outside, when a minigame tier picked the
## choice instead of the player pressing a button. Keeps the teaching reveal
## identical either way.
func force_choice(index: int) -> void:
	_on_choice(index)
```

- [x] In `scenes/journey/journey.gd`, add the preload beside the existing ones:

```gdscript
const MINIGAME_STUB_SCENE := preload("res://scenes/minigames/minigame_stub.tscn")
```

- [x] In `scenes/journey/journey.gd`, add an untyped instance var beside `hud`,
      `decision_panel` and `event_panel`:

```gdscript
var minigame_panel
```

- [x] In `_ready()`, after the `event_panel` lines and before the
      `decision_panel.decisions_confirmed.connect(...)` line, add:

```gdscript
	minigame_panel = MINIGAME_STUB_SCENE.instantiate()
	add_child(minigame_panel)
	minigame_panel.hide()
	minigame_panel.finished.connect(_on_minigame_finished)
```

- [x] Add these two methods to `scenes/journey/journey.gd`:

```gdscript
## Cards with a registry binding open their minigame instead of showing choice
## buttons. The tier then picks one of the card's own authored choices, so the
## consequence beat and the teaching reveal are the same either way.
func _try_open_minigame(card: EventCard) -> bool:
	if card == null or not MinigameRegistry.has_binding(card.event_id):
		return false
	var cfg := MinigameRegistry.config_for(card.event_id)
	if cfg == null:
		return false
	minigame_panel.open(cfg)
	return true


func _on_minigame_finished(result: MinigameResult) -> void:
	# A malformed result must never silently resolve as choice 0. Fall back to
	# the ordinary choice buttons instead, so the player still decides.
	if result == null or not result.is_valid() or current_card == null:
		event_panel.show_card(current_card)
		return
	var index := MinigameRegistry.choice_for_tier(current_card.event_id, result.tier)
	if index < 0 or index >= current_card.choices.size():
		event_panel.show_card(current_card)
		return
	event_panel.force_choice(index)
```

- [x] In `scenes/journey/journey.gd` there is exactly one call site, verified at
      line 72. Replace this exact two-line sequence:

```gdscript
	current_card = pending.pop_front()
	event_panel.show_card(current_card)
```

      with:

```gdscript
	current_card = pending.pop_front()
	if not _try_open_minigame(current_card):
		event_panel.show_card(current_card)
```

Indentation is a single tab on the first two lines and two tabs on the third.
The only other occurrence of the string `show_card` in that file is inside a
comment on line 11 — **do not touch it.**

### The GDScript trap in this file

`GameState` and `EventManager` are autoloads, and autoload property access is
typed `Variant`, so **`:=` cannot infer a type from them**. Write
`var x: int = GameState.something`, never `var x := GameState.something`.
`MinigameRegistry` is a `class_name`, not an autoload, so `:=` is fine on its
static calls — which is why the code above uses it there.

## Task 5 — The contract checker

- [x] Create `tools/minigame_check.gd`:

```gdscript
extends Node
## Headless check on the minigame contract. Run:
##   godot --headless res://tools/minigame_check.tscn      (exit 0 PASS, 1 FAIL)
##
## This is NOT minigame_sim. It validates that the wiring is coherent -- every
## binding names a real card, every tier maps to a choice that card actually
## authors. Band verification needs a real module and comes with it.

var passed := 0
var failures: Array[String] = []


func _ready() -> void:
	_check_result_type()
	_check_bindings()
	if failures.is_empty():
		print("MINIGAME PASS (%d checks)" % passed)
	else:
		print("MINIGAME FAIL (%d failures)" % failures.size())
		for f in failures:
			print("  " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _ok(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)


func _check_result_type() -> void:
	var good := MinigameResult.make(&"x", 10, &"fair")
	_ok(good.is_valid(), "a well-formed MinigameResult must validate")
	var bad := MinigameResult.make(&"x", 10, &"excellent")
	_ok(not bad.is_valid(), "an unknown tier must not validate")
	var anon := MinigameResult.make(&"", 0, &"poor")
	_ok(not anon.is_valid(), "a result with no minigame_id must not validate")
	_ok(MinigameResult.TIERS.size() == 3, "there are exactly three tiers")


func _check_bindings() -> void:
	var by_id := {}
	for card in EventManager.deck:
		by_id[card.event_id] = card
	for event_id in MinigameRegistry.BINDINGS:
		_ok(by_id.has(event_id),
			"binding names a card not in the deck: %s" % event_id)
		if not by_id.has(event_id):
			continue
		var card: EventCard = by_id[event_id]
		var cfg := MinigameRegistry.config_for(event_id)
		_ok(cfg != null and cfg.minigame_id != &"",
			"binding has no minigame_id: %s" % event_id)
		for tier in MinigameResult.TIERS:
			var index := MinigameRegistry.choice_for_tier(event_id, tier)
			_ok(index >= 0,
				"tier %s is unmapped on %s" % [tier, event_id])
			_ok(index >= 0 and index < card.choices.size(),
				"tier %s on %s maps to choice %d, but the card authors %d"
					% [tier, event_id, index, card.choices.size()])
```

- [x] Create `tools/minigame_check.tscn` with exactly this content:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tools/minigame_check.gd" id="1"]

[node name="MinigameCheck" type="Node"]
script = ExtResource("1")
```

`EventManager.deck` is `var deck: Array[EventCard]`, verified at
`autoload/event_manager.gd:66`. If it is not, stop and report it — do not guess
an alternative and do not add a fallback.

## Task 6 — Verify

- [x] Run each and record the exact output:

```bash
godot --headless res://tools/minigame_check.tscn
```

**Expected:** `MINIGAME PASS (…)`, exit 0.

```bash
godot --headless res://tools/smoke_test.tscn
```

**Expected:** `SMOKE PASS (354 checks)`, exit 0.

```bash
godot --headless res://tools/layout_test.tscn
```

**Expected:** `LAYOUT PASS (265 checks)`, exit 0.

```bash
godot --headless res://tools/sim_test.tscn
```

**Expected:** unchanged, still reporting `grade=matched_history`.

**If any number moved, stop and report it.** This task adds types, a stub and a
tool. It changes no game rule, so a moved count means something unintended
happened. **Never weaken a check to make the harness green.**

## Task 7 — Prove the deliberate-failure path

A checker that has never failed is not known to work.

- [x] In `resources/minigame_registry.gd`, temporarily change the `tier_choice`
      entry for `&"strong"` from `0` to `7`.
- [x] Run `godot --headless res://tools/minigame_check.tscn`.

**Expected:** exit 1, `MINIGAME FAIL`, and a line reading
`tier strong on the_803_foot_month maps to choice 7, but the card authors 2`.

- [x] Change it back to `0`. Re-run and confirm `MINIGAME PASS` returns.

**If that failure was not detected, stop and report.**

## Task 8 — Commit

- [x] Confirm what changed:

```bash
git status --short
```

**Expected:** new files under `resources/`, `scenes/minigames/`, `tools/`, plus
` M scenes/journey/journey.gd` and ` M scenes/ui/event_panel.gd`. Godot-generated
`.uid` files are expected and should be committed. Two pre-existing untracked
files under `docs/superpowers/` are expected — **leave them alone.**

- [x] Stage **only these paths by name**. Do not use `git add -A` or `git add .`
      under any circumstances — it has twice swept unrelated work into a commit:

```bash
git add resources/minigame_config.gd resources/minigame_result.gd resources/minigame_registry.gd scenes/minigames/ tools/minigame_check.gd tools/minigame_check.tscn scenes/journey/journey.gd scenes/ui/event_panel.gd
```

Then add any `.uid` files Godot generated for those scripts, by name. If none
were generated, skip that rather than creating them.

- [x] Write the commit message to a file and commit with `-F`. Do **not** pass it
      with `-m`: double quotes inside `-m` get re-tokenized by PowerShell and
      produce bad-pathspec errors.

```
feat: the minigame module contract, with a stub as its first consumer

MinigameConfig in, MinigameResult out. The result carries score and tier and
nothing else -- the tier selects among the driving card's already authored
EventChoices, so every consequence number and every line of prose stays in
content/ where the historian owns it.

The card-to-minigame binding lives in MinigameRegistry rather than on
EventCard. Putting it on the card would mean editing content/cards/*.md and
the importer for a framework change; keeping it on this side means the
framework can land and be reverted without touching authored content.

The stub proves the contract end to end and models no gameplay. Its three
tier buttons are a test affordance -- a single Resolve button could only ever
exercise one of the three mappings.

minigame_check validates the wiring: every binding names a real card, every
tier maps to a choice that card actually authors. It is not minigame_sim;
band verification needs a real module and ships with it. Verified by
deliberate breakage: an out-of-range tier mapping is caught and named.

SMOKE 354, LAYOUT 265, sim_test matched_history all unchanged.
```

- [x] Tick the boxes above for what you actually verified, and stop. Do not begin
      any other work.

---

## Stop immediately and report if

- `EventManager.deck` is not the deck property, or the two-line anchor in
  `journey.gd` Task 4 does not match the file exactly.
- Any harness count differs from the numbers above.
- The deliberate-breakage test does not fail as described.
- You are tempted to add a field to `MinigameResult`, to let the stub apply an
  effect directly, to give a minigame a sixth resource, or to make a minigame
  gate progress.
- Any change would touch `content/`, `data/events/` or `data/segments/`. This
  plan must not modify authored content anywhere.

Never weaken a check to make the harness green. A failing check is a finding.
