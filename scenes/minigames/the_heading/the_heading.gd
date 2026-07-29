extends Control
## The Heading -- the signature minigame. Drill, load powder, blast, muck out,
## then decide: bank what the crew holds, or drive one more round.
##
## Reads no game state. Everything it needs arrives in MinigameConfig.params, and
## it returns score and tier ONLY. The tier selects among the driving card's
## authored EventChoices, so every consequence number and every line of prose
## stays in content/ where the historian owns it.
##
## Constants below are the accepted tuning study's, re-measured 2026-07-28. See
## docs/superpowers/specs/minigames/01-the-heading.md before changing any of them
## -- in particular, Deep's +9 stress has been measured and confirmed, and the
## slot's archetype claim was withdrawn rather than the numbers retuned.

signal finished(result: MinigameResult)

const MINIGAME_ID := &"the_heading"

const BUST_BASE := 0.02
const BUST_COEFF := 0.0175
const BUST_CAP := 0.55
const ROUND_CAP := 12
const FAIR_FRACTION := 0.60
const FULL_ROUNDS_TO_TARGET := 6.0

## Ground-condition cue thresholds. The exact stress value is never shown -- the
## player reads the ground, which is the skill being taught.
const STEADY_MAX := 3
const WORKING_MAX := 8

## `mult` scales a Full round, which is target_feet / FULL_ROUNDS_TO_TARGET.
const ACTIONS := {
	&"short": {"name": "Short round", "mult": 0.80, "stress": 1, "stamina": 1},
	&"full": {"name": "Full round", "mult": 1.00, "stress": 2, "stamina": 1},
	&"deep": {"name": "Deep round", "mult": 2.20, "stress": 9, "stamina": 2},
	&"supports": {"name": "Set supports", "mult": 0.00, "stress": -3, "stamina": 1},
}
const ACTION_ORDER: Array[StringName] = [&"short", &"full", &"deep", &"supports"]

## Hazard shares conditional on a bust. Slot 2 will name the geology instead of
## leaving it to the draw; that is a config change, not a module change.
const GEOLOGY := {
	&"jointed": {
		"name": "Jointed rock",
		"blast": 0.25, "rockfall": 0.55, "ground": 0.20,
		"survey": "Blocky, close-jointed rock. The crown will shed.",
	},
	&"granite": {
		"name": "Sound granite",
		"blast": 0.55, "rockfall": 0.35, "ground": 0.10,
		"survey": "Sound granite, tight and dry, but it takes heavy powder.",
	},
	&"wet": {
		"name": "Wet / running ground",
		"blast": 0.25, "rockfall": 0.35, "ground": 0.40,
		"survey": "Water-charged ground. It will not stand unsupported.",
	},
}
const GEOLOGY_ORDER: Array[StringName] = [&"jointed", &"granite", &"wet"]

## Bust prose is the hazard card's own authored text. The module reads these
## cards; it never applies one, grants its flags, or returns its id. The
## campaign's hazard roll is a separate event at a different scale.
const HAZARD_CARDS := {
	&"blast": "res://data/events/h1_powder_blast.tres",
	&"rockfall": "res://data/events/h2_rockfall_in_the_heading.tres",
	&"ground": "res://data/events/h3_cave_in.tres",
}

var target_feet: int = 803
var full_feet: float = 133.833
var fair_feet: float = 481.8
var geology: StringName = &"jointed"
var stress: int = 1
var bank: float = 0.0
var stamina: int = 8
var rounds: int = 0
var braced: bool = false
var over: bool = false
## Instrumentation for minigame_sim. Not part of MinigameResult -- the contract
## is two fields, and a hazard count is a measurement, not a consequence.
var hazards: int = 0
var wiped: bool = false

var _rng := RandomNumberGenerator.new()
var _log: Array[String] = []
var _hazard_text: Dictionary = {}
## Built once. Rebuilding them each round would mean freeing the button that is
## mid-signal, and queue_free() never lands in a headless tool that processes no
## frames -- which silently leaked a node per round until minigame_sim hung.
var _buttons: Dictionary = {}


func _ready() -> void:
	for key in HAZARD_CARDS:
		var path: String = HAZARD_CARDS[key]
		var card: Resource = load(path) if ResourceLoader.exists(path) else null
		if card is EventCard:
			_hazard_text[key] = (card as EventCard).event_description
		else:
			# A missing hazard card is a content problem, not a reason to invent
			# prose. Say nothing rather than make something up.
			_hazard_text[key] = ""
	_build_buttons()
	hide()


func _build_buttons() -> void:
	var box := $Panel/Box/Buttons as BoxContainer
	for key in ACTION_ORDER:
		var button := Button.new()
		button.pressed.connect(take.bind(key))
		box.add_child(button)
		_buttons[key] = button
	var bank_button := Button.new()
	bank_button.text = "Bank the shift"
	bank_button.pressed.connect(take.bind(&"bank"))
	box.add_child(bank_button)
	_buttons[&"bank"] = bank_button


## Opens a shift. `params` may carry target_feet, stamina, s0, surveyed and
## geology; every one has a documented default so an arcade launch works too.
func open(cfg: MinigameConfig) -> void:
	target_feet = maxi(1, cfg.get_int("target_feet", 803))
	full_feet = float(target_feet) / FULL_ROUNDS_TO_TARGET
	fair_feet = FAIR_FRACTION * float(target_feet)
	stamina = clampi(cfg.get_int("stamina", 8), 3, 10)
	stress = maxi(0, cfg.get_int("s0", 1))
	if cfg.seed != 0:
		_rng.seed = cfg.seed
	else:
		_rng.randomize()
	var named: StringName = StringName(str(cfg.params.get("geology", "")))
	geology = named if GEOLOGY.has(named) else GEOLOGY_ORDER[_rng.randi_range(0, 2)]
	bank = 0.0
	rounds = 0
	braced = false
	over = false
	hazards = 0
	wiped = false
	_log.clear()
	var geo: Dictionary = GEOLOGY[geology]
	_note("Shift opened at the heading. %s. Crew good for %d rounds of work."
		% [geo["name"], stamina])
	($Panel/Box/Result as Label).text = ""
	_paint()
	show()


func bust_chance(s: int) -> float:
	return clampf(BUST_BASE + BUST_COEFF * float(maxi(0, s)), 0.0, BUST_CAP)


func tier_for(feet: float) -> StringName:
	if feet >= float(target_feet):
		return &"strong"
	if feet >= fair_feet:
		return &"fair"
	return &"poor"


func condition() -> String:
	if stress <= STEADY_MAX:
		return "steady"
	if stress <= WORKING_MAX:
		return "working"
	return "strained"


func footage_for(key: StringName) -> float:
	var a: Dictionary = ACTIONS[key]
	return full_feet * float(a["mult"])


func take(key: StringName) -> void:
	if over:
		return
	if key == &"bank":
		_close("The crew calls the shift. The footage stands.")
		return
	if not ACTIONS.has(key):
		return
	var a: Dictionary = ACTIONS[key]
	var cost: int = int(a["stamina"])
	if cost > stamina or rounds >= ROUND_CAP:
		return

	rounds += 1
	stamina -= cost
	stress = maxi(0, stress + int(a["stress"]))
	var supporting: bool = key == &"supports"
	# Set supports delivers its protected window as part of the action, before
	# the roll is read. It is the safe action; that is its whole job.
	if supporting:
		braced = true

	var busted: bool = _rng.randf() < bust_chance(stress)
	if not busted:
		if supporting:
			_note("Sets framed and wedged. The ground eases behind them.")
		else:
			bank += footage_for(key)
			_note("%s pulled clean. %d ft added, %d ft held."
				% [a["name"], roundi(footage_for(key)), roundi(bank)])
			if braced:
				braced = false
				_note("The support window closed unused.")
	else:
		_resolve_hazard(key, supporting)
		if over:
			return

	if stamina <= 0:
		_close("The crew worked out the shift. What stood at the whistle is credited.")
		return
	if rounds >= ROUND_CAP:
		_close("The month ran out before the crew did.")
		return
	_paint()


func _resolve_hazard(key: StringName, supporting: bool) -> void:
	var geo: Dictionary = GEOLOGY[geology]
	var roll: float = _rng.randf()
	var blast: float = float(geo["blast"])
	var rockfall: float = float(geo["rockfall"])
	var which: StringName = &"ground"
	if roll < blast:
		which = &"blast"
	elif roll < blast + rockfall:
		which = &"rockfall"

	hazards += 1
	var prose: String = str(_hazard_text.get(which, ""))
	if which == &"blast":
		_note(prose + " The round is spoiled; this advance is not credited.")
		if not supporting:
			braced = false
	elif which == &"rockfall":
		var lost: float = bank * 0.5
		bank -= lost
		_note(prose + " %d ft goes back to muck -- half of what was held."
			% roundi(lost))
		if not supporting:
			braced = false
	else:
		if braced:
			braced = false
			_note(prose + " The timber took it. Footage stands and the heading goes on.")
		else:
			var all: float = bank
			bank = 0.0
			wiped = true
			_note(prose + " %d ft is gone." % roundi(all))
			_close("The ground took the shift. Nothing from it is credited.")


func _close(reason: String) -> void:
	over = true
	var credited: int = roundi(minf(bank, float(target_feet)))
	var tier: StringName = tier_for(bank)
	_note("Shift closed -- %d ft, %s." % [credited, tier])
	($Panel/Box/Result as Label).text = "%s\n%d ft credited. %s." % [reason, credited, tier]
	_paint()
	hide()
	finished.emit(MinigameResult.make(MINIGAME_ID, credited, tier))


func _note(line: String) -> void:
	_log.append(line)
	var box := $Panel/Box/Log as Label
	if box != null:
		box.text = "\n".join(_log.slice(maxi(0, _log.size() - 6)))


func _paint() -> void:
	var geo: Dictionary = GEOLOGY[geology]
	($Panel/Box/Title as Label).text = "The Heading -- %s" % geo["name"]
	($Panel/Box/Survey as Label).text = str(geo["survey"])
	($Panel/Box/Stats/Cond as Label).text = "Ground: %s" % condition()
	($Panel/Box/Stats/Bank as Label).text = "Held: %d ft of %d (all at risk)" % [roundi(bank), target_feet]
	($Panel/Box/Stats/Stam as Label).text = "Stamina: %d" % stamina
	($Panel/Box/Stats/Timber as Label).text = "Timber: %s" % ("standing" if braced else "none")
	($Panel/Box/Phase as Label).text = _prompt()

	for key in ACTION_ORDER:
		var a: Dictionary = ACTIONS[key]
		var button := _buttons[key] as Button
		if button == null:
			continue
		if key == &"supports":
			button.text = "%s (eases the ground, 1 stamina)" % a["name"]
		else:
			button.text = "%s (+%d ft, %d stamina)" % [
				a["name"], roundi(footage_for(key)), int(a["stamina"])]
		button.disabled = over or int(a["stamina"]) > stamina or rounds >= ROUND_CAP
	var bank_button := _buttons.get(&"bank") as Button
	if bank_button != null:
		bank_button.disabled = over


func _prompt() -> String:
	if bank >= float(target_feet):
		return "Credit is capped at the target. Banking keeps it; another round risks it for nothing."
	if condition() == "strained":
		return "The ground is strained. Bank, ease it with timber, or press the heading."
	if braced:
		return "The timber is ready. Choose the round it will cover."
	return "Drill a round, set timber, or bank what the crew already holds."
