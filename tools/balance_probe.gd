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
	print("BALANCE PROBE DONE")
	get_tree().quit(0)


func _run(label: String, picker: Callable) -> void:
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
