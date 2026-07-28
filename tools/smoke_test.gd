extends Node
## Headless smoke test. Run:  godot --headless res://tools/smoke_test.tscn
## Exits 0 on PASS, 1 on FAIL. Never weaken a check to make it pass.

var passed := 0
var failures: Array[String] = []


func _ready() -> void:
	_check_phase_calendar()
	_check_workfronts()
	_check_economy()
	_check_content_pipeline()
	_check_card_art()
	_check_segments()
	_check_deck()
	_check_hazards()
	_check_flag_closure()
	_check_first_turn()
	_check_ui_scenes()
	_check_end_screens()
	_check_reveal_order()
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
	check(EventManager.deck.size() == 26, "exactly 26 event cards loaded (got %d)" % EventManager.deck.size())
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
	# A card now fires because its front was worked, so work one first.
	GameState.set_front(0)
	GameState.work_pace = GameState.Pace.STEADY
	GameState.advance_turn()
	var queue := EventManager.try_draw_queue()
	check(not queue.is_empty() and queue.back().event_id == &"cut_the_first_road",
		"the first milestone card is Cut the First Road")
	for card in queue:
		EventManager.resolve_choice(card, card.canonical_choice)
	check(GameState.has_flag(&"high_sierra_access_complete"),
		"resolving turn 1 grants high_sierra_access_complete")
	GameState.new_game()
	EventManager.reset()


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


func _check_ui_scenes() -> void:
	GameState.new_game()
	EventManager.reset()
	var journey: Node = load("res://scenes/journey/journey.tscn").instantiate()
	add_child(journey)
	check(journey.hud != null and journey.hud.labels.size() == 6, "Journey builds HUD with 6 labels")
	check(journey.decision_panel.end_button != null, "Journey builds DecisionPanel")
	check(not journey.event_panel.visible, "EventPanel starts hidden")
	journey._on_decisions(GameState.Pace.STEADY, &"none", 0)
	check(GameState.miles_built > 0.0, "one turn advances the construction front")
	check(journey.event_panel.visible, "turn 1 shows a card")
	journey.event_panel._on_choice(0)
	check(not GameState.has_flag(&"high_sierra_access_complete"),
		"choosing shows the consequence beat but does not resolve yet")
	# Turn 1 may queue a hazard ahead of the milestone; drain the whole queue.
	var guard := 0
	while journey.event_panel.visible and guard < 5:
		guard += 1
		journey.event_panel._on_choice(0)
		journey.event_panel._on_continue(0)
	check(guard < 5, "the turn-1 queue drains instead of looping")
	check(GameState.has_flag(&"high_sierra_access_complete"),
		"draining turn 1 resolves the milestone and grants its flag")
	journey.queue_free()
	GameState.new_game()
	EventManager.reset()


func _check_phase_calendar() -> void:
	GameState.new_game()
	check(GameState.TURNS_TOTAL == 24, "the turn budget is 24")
	check(GameState.phase == 0, "new game starts at phase 0")
	check(GameState.turn == 0, "new game starts at turn 0")
	check(GameState.current_year() == 1914, "phase 0 is 1914")
	check(GameState.turns_remaining() == 24, "24 turns remain at start")
	for i in 24:
		GameState.work_pace = GameState.Pace.STEADY
		GameState.advance_turn()
	check(GameState.turn == 24, "24 advances reach turn 24 (got %d)" % GameState.turn)
	check(GameState.phase == 24,
		"with no card delays, phase tracks turn (got %d)" % GameState.phase)
	# A delay-free run is faster than history: 24 phases against a calendar
	# calibrated to canonical play, which costs ~30.
	check(GameState.current_year() < 1934,
		"a delay-free campaign finishes ahead of 1934 (got %d)" % GameState.current_year())
	# Two Sierra divisions must stay railroad-dependent; renaming the export
	# would silently drop this from the .tres files.
	var dependent := 0
	for s in GameState.segments:
		if s.winter_sensitive:
			dependent += 1
	check(dependent == 3, "exactly 3 railroad-dependent segments (got %d)" % dependent)
	GameState.new_game()
	EventManager.reset()


func _check_economy() -> void:
	GameState.new_game()
	check(GameState.action_cost(&"outreach") == GameState.OUTREACH_FUNDS_COST,
		"first outreach costs the base price")
	GameState.take_action(&"outreach")
	check(GameState.action_cost(&"outreach") == GameState.OUTREACH_FUNDS_COST + GameState.ACTION_COST_ESCALATION,
		"second outreach costs more than the first")
	GameState.new_game()
	var issued := 0
	for i in 10:
		if GameState.take_action(&"issue_bond"):
			issued += 1
		GameState.take_action(&"outreach")
	check(issued == GameState.MAX_BOND_ISSUES,
		"bond issuance is capped at %d (got %d)" % [GameState.MAX_BOND_ISSUES, issued])
	check(not GameState.can_take_action(&"issue_bond"),
		"issuing the cap exhausts the bond action")
	GameState.new_game()
	EventManager.reset()


func _check_content_pipeline() -> void:
	var dir := DirAccess.open("res://content/cards")
	check(dir != null, "content/cards exists")
	if dir == null:
		return
	var md := 0
	for f in dir.get_files():
		if f.ends_with(".md"):
			md += 1
	check(md == EventManager.deck.size(),
		"one Markdown source per card (%d md, %d cards)" % [md, EventManager.deck.size()])
	for card in EventManager.deck:
		check(card.assumption_note != "",
			"card %s records its assumptions" % card.event_id)
		check(card.historical_source_note != "",
			"card %s cites a source" % card.event_id)


func _check_card_art() -> void:
	for card in EventManager.deck:
		# Art is optional during production; the contract is that a missing
		# image degrades to empty rather than erroring.
		var path := card.art_path()
		check(path == "" or ResourceLoader.exists(path),
			"card %s art path resolves or is empty" % card.event_id)


## Forces every ending with the real Journey UI live. This is the path that
## shipped a crash while 301 checks stayed green: nothing else ends a campaign
## with the UI instantiated.
func _check_end_screens() -> void:
	var endings := {
		&"bond_crisis": func() -> void: GameState._set_funds(-1),
		&"project_cancelled": func() -> void: GameState._set_support(0),
		&"work_halted": func() -> void: GameState._set_crew(0),
		&"city_moves_on": func() -> void: GameState.phase = GameState.CALENDAR_PHASES * 4,
		&"system_complete": func() -> void: GameState.grant_flag(&"hetch_hetchy_water_delivered"),
	}
	for expected in endings:
		GameState.new_game()
		EventManager.reset()
		var journey: Node = load("res://scenes/journey/journey.tscn").instantiate()
		add_child(journey)
		var seen := {"result": &""}
		var on_end := func(r: StringName) -> void: seen["result"] = r
		GameState.game_ended.connect(on_end)
		endings[expected].call()
		GameState._check_end_conditions()
		GameState.game_ended.disconnect(on_end)
		check(seen["result"] == expected,
			"ending '%s' fires (got '%s')" % [expected, seen["result"]])
		check(GameState.game_over, "ending '%s' sets game_over" % expected)
		journey.queue_free()
	GameState.new_game()
	EventManager.reset()


## The teaching layer must not be visible while the player is still choosing.
func _check_reveal_order() -> void:
	GameState.new_game()
	EventManager.reset()
	var panel: Node = load("res://scenes/ui/event_panel.tscn").instantiate()
	add_child(panel)
	var card: EventCard = null
	for c in EventManager.deck:
		if c.historical_fact != "" and c.choices.size() >= 2:
			card = c
			break
	check(card != null, "found a card with a fact and two choices to test")
	if card == null:
		panel.queue_free()
		return
	panel.show_card(card)
	check(not panel.fact_label.visible,
		"the historical fact is hidden while choosing")
	check(not panel.note_label.visible,
		"the assumption note is hidden while choosing")
	panel._on_choice(0)
	check(panel.fact_label.visible,
		"choosing reveals the historical fact")
	check(panel.fact_label.text.contains(card.historical_fact),
		"the revealed fact is the card's own")
	panel.queue_free()
	GameState.new_game()
	EventManager.reset()


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
	var steady: float = GameState.front_progress[0]
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
