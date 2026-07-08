extends Node
## Headless smoke test. Run:  godot --headless res://tools/smoke_test.tscn
## Exits 0 on PASS, 1 on FAIL. Never weaken a check to make it pass.

var passed := 0
var failures: Array[String] = []


func _ready() -> void:
	_check_segments()
	_check_deck()
	_check_hazards()
	_check_flag_closure()
	_check_first_turn()
	_check_ui_scenes()
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
	var card := EventManager.try_draw()
	check(card != null and card.event_id == &"cut_the_first_road",
		"first fixed card is Cut the First Road")
	if card != null:
		EventManager.resolve_choice(card, card.canonical_choice)
		check(GameState.has_flag(&"high_sierra_access_complete"),
			"resolving the road card grants high_sierra_access_complete")
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
	journey._on_decisions(GameState.Pace.STEADY, &"none")
	check(GameState.miles_built > 0.0, "one turn advances the construction front")
	check(journey.event_panel.visible, "turn 1 shows the first fixed card")
	journey.event_panel._on_choice(0)
	check(GameState.miles_built > 0.0 and not GameState.has_flag(&"high_sierra_access_complete"),
		"choosing shows the consequence beat but does not resolve yet")
	journey.event_panel._on_continue(0)
	check(GameState.has_flag(&"high_sierra_access_complete"), "Continue resolves and grants the flag")
	journey.queue_free()
	GameState.new_game()
	EventManager.reset()
