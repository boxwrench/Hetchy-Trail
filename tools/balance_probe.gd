extends Node
## Balance instrument. Plays the full campaign under several pace strategies,
## many seeds each, and reports win rate, finish grade, and failure modes.
## Run:  godot --headless res://tools/balance_probe.tscn
##
## This is a measurement tool, not a test -- it always exits 0. The pass/fail
## guards live in sim_test. Use this when tuning to see WHY a strategy fails.
##
## Reading it: no strategy should win every time, and no strategy that a
## reasonable player would try should almost always lose. If "all steady" wins
## 10/10 while every pushing strategy wins 3/10, pace is not a decision.

const SEEDS := 12
const MAX_TURNS := 34


func _ready() -> void:
	_run("all steady", func(_t: int) -> int: return GameState.Pace.STEADY)
	_run("all pushed", func(_t: int) -> int: return GameState.Pace.PUSHED)
	_run("all rest", func(_t: int) -> int: return GameState.Pace.REST)
	_run("push while crew>=6", func(_t: int) -> int:
		return GameState.Pace.PUSHED if GameState.crew_wellbeing >= 6 else GameState.Pace.STEADY)
	_run("push first 4", func(t: int) -> int:
		return GameState.Pace.PUSHED if t < 4 else GameState.Pace.STEADY)
	_run("rest when crew<=3", func(_t: int) -> int:
		return GameState.Pace.REST if GameState.crew_wellbeing <= 3 else GameState.Pace.STEADY)
	_run("bay first, steady", func(_t: int) -> int: return GameState.Pace.STEADY,
		func() -> int: return _bay_first_front())
	_run("bay first, push", func(_t: int) -> int: return GameState.Pace.PUSHED,
		func() -> int: return _bay_first_front())
	print("BALANCE PROBE DONE")
	get_tree().quit(0)


func _run(label: String, picker: Callable, front_picker: Callable = Callable()) -> void:
	var tally := {"wins": 0, "turns": 0, "hazards": 0, "ahead": 0}
	var modes := {}
	for s in SEEDS:
		seed(3000 + s)
		GameState.new_game()
		EventManager.reset()
		var outcome := {"result": &"unfinished"}
		var on_end := func(r: StringName) -> void: outcome["result"] = r
		# NOTE: GDScript lambdas capture locals by value, so the counter must be
		# a Dictionary. A plain int here silently stays at zero.
		var counter := {"hazards": 0}
		var on_draw := func(c: EventCard) -> void:
			if c.hazard_kind != &"":
				counter["hazards"] += 1
		GameState.game_ended.connect(on_end)
		EventManager.event_drawn.connect(on_draw)
		var turns := 0
		for i in MAX_TURNS:
			if GameState.game_over:
				break
			GameState.work_pace = picker.call(turns)
			turns += 1
			_take_sensible_action()
			if front_picker.is_valid():
				GameState.set_front(front_picker.call())
			else:
				GameState.set_front(_lowest_open_front())
			GameState.advance_turn()
			if GameState.game_over:
				break
			for card in EventManager.try_draw_queue():
				if GameState.game_over:
					break
				EventManager.resolve_choice(card, card.canonical_choice)
		var grade := GameState.completion_grade()
		EventManager.event_drawn.disconnect(on_draw)
		GameState.game_ended.disconnect(on_end)
		var result: StringName = outcome["result"]
		modes[result] = int(modes.get(result, 0)) + 1
		tally["turns"] += turns
		tally["hazards"] += counter["hazards"]
		if result == &"system_complete":
			tally["wins"] += 1
			if grade == "ahead_of_history":
				tally["ahead"] += 1
	print("BALANCE %-20s win %2d/%d | ahead %2d | avg %4.1f turns | %4.1f hazards/run | %s"
		% [label, tally["wins"], SEEDS, tally["ahead"],
		float(tally["turns"]) / float(SEEDS),
		float(tally["hazards"]) / float(SEEDS), str(modes)])


## The same reflex a competent player would use: cover the metric nearest a loss.
func _take_sensible_action() -> void:
	if GameState.funds <= 3 and GameState.can_take_action(&"issue_bond"):
		GameState.take_action(&"issue_bond")
	elif GameState.crew_wellbeing <= 4 and GameState.can_take_action(&"improve_camp"):
		GameState.take_action(&"improve_camp")
	elif GameState.public_support <= 3 and GameState.can_take_action(&"outreach"):
		GameState.take_action(&"outreach")


## Historical order: the lowest-numbered open front that is either unfinished or
## still owes fixed cards. This MUST match sim_test._pick_front() exactly -- it
## is the baseline every other strategy is measured against, and if the two
## differ the probe and the sim are playing different games.
##
## The pending-cards clause is load-bearing, not defensive. Only one fixed card
## is drawn per turn, so a front can reach 100%% still owing its completion card.
## Abandoning it there strands that card forever, the campaign can never satisfy
## SYSTEM_FLAGS, and every strategy reports 0/12 -- a probe that measures nothing
## while looking like a verdict on the design.
func _lowest_open_front() -> int:
	for i in GameState.front_count():
		if not GameState.front_is_open(i):
			continue
		if GameState.front_progress[i] < 1.0 or EventManager.front_has_pending_fixed(i):
			return i
	return 0


## Bay and Peninsula first -- the Spring Valley gambit. Historically real, and
## the sharpest test of whether front choice matters. Same pending-cards rule:
## front 6 must be worked until its cards are drawn, not until its bar fills.
func _bay_first_front() -> int:
	if GameState.front_progress[5] < 1.0 or EventManager.front_has_pending_fixed(5):
		return 5
	return _lowest_open_front()

