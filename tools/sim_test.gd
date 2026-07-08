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
