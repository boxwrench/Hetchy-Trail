extends Node
## Plays a full campaign headless (STEADY pace, canonical choices) and then runs
## two deterministic probes proving the pace-risk mechanic fires.
## Run:  godot --headless res://tools/sim_test.tscn
## PASS = system complete by 1940 AND injuries fire under push, impatience under
## rest. Deterministic (fixed seed). Never weaken a check to make it pass.

const MAX_TURNS := 40
const PROBE_TURNS := 12

var result: StringName = &""
var hazards_seen := 0


func _ready() -> void:
	seed(1234)
	# --- Canonical winnability run (STEADY) ---
	GameState.new_game()
	EventManager.reset()
	var on_ended := func(r: StringName): result = r
	GameState.game_ended.connect(on_ended)
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
		if GameState.funds <= 8 and GameState.public_support >= GameState.BOND_MIN_SUPPORT:
			GameState.take_action(&"issue_bond")
		elif GameState.public_support <= 3 and GameState.funds >= 2:
			GameState.take_action(&"outreach")
		elif GameState.crew_wellbeing <= 3 and GameState.funds >= 2:
			GameState.take_action(&"improve_camp")
		GameState.set_front(_pick_front())
		GameState.advance_turn()
		if GameState.game_over:
			break
		for card in EventManager.try_draw_queue():
			if GameState.game_over:
				break
			EventManager.resolve_choice(card, card.canonical_choice)
	EventManager.event_drawn.disconnect(count_hazards)
	var final_result := result
	var final_year := GameState.current_year()
	# Cache the grade while GameState still holds the canonical end state; the
	# probes below call new_game() and would otherwise pollute completion_grade().
	var final_grade := GameState.completion_grade()
	GameState.game_ended.disconnect(on_ended)
	print("SIM RESULT: %s | phase %d | %d | mile %.0f | readiness %d | funds %d | support %d | crew %d | %d turns | %d hazards"
		% [final_result, GameState.phase, final_year, GameState.miles_built,
		GameState.water_readiness, GameState.funds, GameState.public_support,
		GameState.crew_wellbeing, turns, hazards_seen])

	# --- Mechanic probes (deterministic; continue the seeded RNG stream) ---
	var injuries := _probe(GameState.Pace.PUSHED, &"injury")
	var impatience := _probe(GameState.Pace.REST, &"impatience")
	print("SIM PROBE: push->injury=%d  rest->impatience=%d" % [injuries, impatience])

	var exploit_peak := _exploit_probe()
	print("SIM EXPLOIT: peak funds under bond/outreach alternation = %d" % exploit_peak)
	var win := final_result == &"system_complete" and final_year <= 1940
	# Regression guard: no repeatable action loop may outrun phase overhead.
	# Two bonds at BOND_FUNDS_GAIN is the entire authorized income; anything
	# above that means a repeatable loop is manufacturing funds.
	win = win and exploit_peak <= GameState.START_FUNDS + (GameState.MAX_BOND_ISSUES * GameState.BOND_FUNDS_GAIN)
	# The pace-risk mechanic must be alive in real play, not just in the probes.
	# This is the guard that would have caught the fixed-spine suppression.
	win = win and hazards_seen > 0
	if win and injuries > 0 and impatience > 0:
		print("SIM PASS: system_complete, grade=%s" % final_grade)
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
		GameState.set_front(_pick_front())
		GameState.advance_turn()
		if GameState.game_over:
			break
		for card in EventManager.try_draw_queue():
			if GameState.game_over:
				break
			EventManager.resolve_choice(card, card.canonical_choice)
	EventManager.event_drawn.disconnect(cb)
	return seen["n"]


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
		GameState.set_front(_pick_front())
		GameState.advance_turn()
		peak = maxi(peak, GameState.funds)
	return peak


## Canonical allocation: work the lowest-numbered open, unfinished front. This
## follows the historical build order and is the baseline the balance probe
## measures other strategies against.
func _pick_front() -> int:
	for i in GameState.front_count():
		if not GameState.front_is_open(i):
			continue
		if GameState.front_progress[i] < 1.0 or EventManager.front_has_pending_fixed(i):
			return i
	return 0
