extends Node
## Balance instrument. Plays the full campaign under several pace strategies,
## many seeds each, and reports win rate, finish grade, and failure modes.
## Run:  godot --headless res://tools/balance_probe.tscn
##
## This is a measurement tool, not a test -- it always exits 0. The pass/fail
## guards live in sim_test. Use this when tuning to see WHY a strategy fails.
##
## Reading it: no strategy should win every time, and no strategy that a
## reasonable player would try should almost always lose.
##
## The probe measures TWO different games and must not collapse them:
##   * pace       -- steady versus pushed on whichever front is being worked
##   * allocation -- which front receives this turn, the decision workfronts
##                   exist to create
## Earlier versions ran six pace policies over a single allocation policy, so
## they could not see the allocation decision at all. Strategies are now a
## matrix of the two, and the grade columns are reported alongside wins:
## allocation frequently costs nothing in survival while costing a great deal
## in finish year, and a win-rate-only view throws that signal away.

const SEEDS := 12
const MAX_TURNS := 34
## The first phase at which overrun pressure can apply. Both of its gates must
## open: phase > CALENDAR_PHASES + OVERRUN_GRACE_PHASES (34), and current_year()
## must reach 1935, which it does at phase 34. So 35.
##
## Hard-coded rather than read from GameState ON PURPOSE. This file has to run
## unchanged against commit 406c989, which predates the OVERRUN_* constants, or
## the A/B comparison is not a comparison. A probe that imports the mechanic it
## is measuring cannot be pointed at a build without it.
const PRESSURE_PHASE := 35


func _ready() -> void:
	var steady := func(_t: int) -> int: return GameState.Pace.STEADY
	var pushed := func(_t: int) -> int: return GameState.Pace.PUSHED
	var rested := func(_t: int) -> int: return GameState.Pace.REST
	var push_crew := func(_t: int) -> int:
		return GameState.Pace.PUSHED if GameState.crew_wellbeing >= 6 else GameState.Pace.STEADY
	var historical := func() -> int: return _lowest_open_front()
	var critical := func() -> int: return _critical_path_front()
	var balanced := func() -> int: return _balanced_front()
	var bay := func() -> int: return _bay_first_front()
	var careful := func(c: EventCard) -> int: return _conservative_choice(c)
	print("BALANCE %-24s %-9s | %-14s | %s"
		% ["allocation / pace", "wins", "grade a/m/b", "turns, phases, late wins, exposure, hazards, end states"])
	_run("historical / steady", steady, historical)
	_run("historical / push", push_crew, historical)
	_run("critical path / steady", steady, critical)
	_run("critical path / push", push_crew, critical)
	_run("balanced / steady", steady, balanced)
	_run("balanced / push", push_crew, balanced)
	_run("bay first / steady", steady, bay)
	_run("bay first / push", push_crew, bay)
	# Slow but competent: the archetype the probe could not previously express.
	# Crossed with the two allocations most likely to survive, plus rest, which
	# is the slowest pace a player might defend as caution rather than folly.
	_run("careful / steady", steady, historical, careful)
	_run("careful / critical", steady, critical, careful)
	_run("careful / rest", rested, critical, careful)
	# Degenerate pace baselines under historical allocation; they bracket the
	# range and catch a build where pace has stopped mattering in either
	# direction.
	_run("historical / all pushed", pushed, historical)
	_run("historical / all rest", rested, historical)
	print("BALANCE PROBE DONE")
	get_tree().quit(0)


## choice_picker takes an EventCard and returns an index into card.choices.
## Omitted, every strategy resolves canonically exactly as before -- that
## default is what keeps the ten existing rows comparable across this change.
func _run(label: String, picker: Callable, front_picker: Callable = Callable(),
		choice_picker: Callable = Callable()) -> void:
	var tally := {"wins": 0, "turns": 0, "hazards": 0, "ahead": 0, "matched": 0, "behind": 0,
		"phase": 0, "max_phase": 0, "late_wins": 0, "exposure": 0}
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
		var exposure := {"phases": 0}
		var on_phase := func(_y: int, p: int) -> void:
			if p >= PRESSURE_PHASE:
				exposure["phases"] += 1
		GameState.game_ended.connect(on_end)
		EventManager.event_drawn.connect(on_draw)
		GameState.turn_advanced.connect(on_phase)
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
			# Drain rather than iterate a snapshot: resolving a milestone can
			# chain into the next one on the same front, appending to this queue.
			var queue := EventManager.try_draw_queue()
			while not queue.is_empty():
				if GameState.game_over:
					break
				var card: EventCard = queue.pop_front()
				var choice_index: int = card.canonical_choice
				if choice_picker.is_valid():
					choice_index = choice_picker.call(card)
				EventManager.resolve_choice(card, choice_index)
				var followup: EventCard = EventManager.try_draw_followup(card)
				if followup != null:
					queue.append(followup)
		var end_phase: int = GameState.phase
		tally["phase"] += end_phase
		tally["max_phase"] = maxi(int(tally["max_phase"]), end_phase)
		tally["exposure"] += exposure["phases"]
		var grade := GameState.completion_grade()
		EventManager.event_drawn.disconnect(on_draw)
		GameState.game_ended.disconnect(on_end)
		GameState.turn_advanced.disconnect(on_phase)
		var result: StringName = outcome["result"]
		modes[result] = int(modes.get(result, 0)) + 1
		tally["turns"] += turns
		tally["hazards"] += counter["hazards"]
		if result == &"system_complete":
			tally["wins"] += 1
			if end_phase >= PRESSURE_PHASE:
				tally["late_wins"] += 1
			if grade == "ahead_of_history":
				tally["ahead"] += 1
			elif grade == "matched_history":
				tally["matched"] += 1
			else:
				tally["behind"] += 1
	print("BALANCE %-24s win %2d/%d | grade %2d/%2d/%2d | avg %4.1f turns | phase %4.1f avg %2d max | late wins %2d | exposure %3d | %4.1f haz/run | %s"
		% [label, tally["wins"], SEEDS,
		tally["ahead"], tally["matched"], tally["behind"],
		float(tally["turns"]) / float(SEEDS),
		float(tally["phase"]) / float(SEEDS), tally["max_phase"],
		tally["late_wins"], tally["exposure"],
		float(tally["hazards"]) / float(SEEDS), str(modes)])


## The same reflex a competent player would use: cover the metric nearest a loss.
##
## The bond trigger is deliberately 8, matching sim_test's canonical bot rather
## than the 3 this used before. At 3 the bot was not competent, it was myopic:
## a bond is worth BOND_FUNDS_GAIN and only MAX_BOND_ISSUES are authorised, so
## waiting until funds are nearly gone risks skipping the window entirely. Under
## smooth spending that never showed. Under workfronts, pushing makes spending
## lumpy -- a hazard plus an escalated camp in one turn -- so runs stepped from
## 4 funds straight to below zero and died holding an unissued bond. That scored
## as "pushing is unaffordable" when it was really "the bot did not bank".
func _take_sensible_action() -> void:
	if GameState.funds <= 8 and GameState.can_take_action(&"issue_bond"):
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


## A front still deserves a turn while it is unfinished OR still owes fixed
## cards. Every allocation policy must use this, not a bare progress test --
## see _lowest_open_front() for what stranding a front's last card does.
func _needs_work(index: int) -> bool:
	return GameState.front_progress[index] < 1.0 or EventManager.front_has_pending_fixed(index)


## Critical path first: fronts 1-3 are the gated chain (each opens the next),
## so nothing else can substitute for time spent on them. Ungated fronts 4-6
## get a turn only when the chain has nothing workable. This is the policy a
## player who has understood the prerequisite graph would play, and it is the
## upper bound the other allocation policies are measured against.
func _critical_path_front() -> int:
	for i in 3:
		if GameState.front_is_open(i) and _needs_work(i):
			return i
	return _lowest_open_front()


## Balanced: spread effort, always working whichever open front has advanced
## least. The intuitive "keep everything moving" policy, and the one most
## likely to punish a player for treating six fronts as six equal claims when
## three of them gate each other.
func _balanced_front() -> int:
	var choice := -1
	var lowest := 2.0
	for i in GameState.front_count():
		if not GameState.front_is_open(i) or not _needs_work(i):
			continue
		if GameState.front_progress[i] < lowest:
			lowest = GameState.front_progress[i]
			choice = i
	return choice if choice >= 0 else _lowest_open_front()


## Bay and Peninsula first -- the Spring Valley gambit. Historically real, and
## the sharpest test of whether front choice matters.
##
## Pinned on PROGRESS ONLY -- deliberately unlike _lowest_open_front(), which
## also pins on pending cards. Front 6's cards are flag-gated behind fronts 4
## and 5 (card 19 needs coast_range_committed; card 21 needs all seven other
## system flags), so front_has_pending_fixed(5) is permanently true here.
## Pinning on it livelocks the strategy onto front 6 for the entire run: 34.0
## turns, unfinished, every seed -- a probe that reports a verdict on front
## allocation while never allocating. Front 6's cards are collected later by
## _lowest_open_front() once the earlier fronts have granted their flags.
func _bay_first_front() -> int:
	if GameState.front_progress[5] < 1.0:
		return 5
	return _lowest_open_front()


## Conservative card resolution: take the option that best protects the five
## metrics and accept whatever delay comes with it. This is the archetype the
## probe was missing -- a player who is competent but slow. Pace and allocation
## policies can only make a run slower by playing WORSE; this one can make a run
## slower by playing SAFER, which is the only way a surviving run plausibly
## reaches the phase where overrun pressure begins.
##
## Deterministic by construction: total ordering with an index tie-break, no
## randomness, so the same seed produces the same decisions at both commits.
##
## Time is not scored. Delay is neither sought nor avoided -- it is simply not
## a term, which is exactly what "accepts schedule delays to protect resources"
## means. Scoring time at all would make this a pace policy in disguise.
func _conservative_choice(card: EventCard) -> int:
	var best := -1
	var best_score := -999
	var fallback := -1
	var fallback_score := -999
	for i in card.choices.size():
		var choice: EventChoice = card.choices[i]
		# Never deliberately re-arm a card. Repeating is a schedule decision
		# dressed as a choice, and it would confound the measurement.
		if choice.repeat_card:
			continue
		var score: int = (choice.funds_delta + choice.public_support_delta
			+ choice.crew_wellbeing_delta)
		if score > fallback_score:
			fallback_score = score
			fallback = i
		# Reject anything that ends the game on the spot. funds is unclamped and
		# loses below zero; support and crew clamp at 0 and lose at 0.
		if GameState.funds + choice.funds_delta < 0:
			continue
		if GameState.public_support + choice.public_support_delta <= 0:
			continue
		if GameState.crew_wellbeing + choice.crew_wellbeing_delta <= 0:
			continue
		if score > best_score:
			best_score = score
			best = i
	if best >= 0:
		return best
	# Every survivable option was rejected, or every option repeats the card.
	# Take the least-bad rather than crashing; a cornered player still moves.
	if fallback >= 0:
		return fallback
	return card.canonical_choice

