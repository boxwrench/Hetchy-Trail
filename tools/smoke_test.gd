extends Node
## Headless smoke test. Run:  godot --headless res://tools/smoke_test.tscn
## Exits 0 on PASS, 1 on FAIL. Never weaken a check to make it pass.

var passed := 0
var failures: Array[String] = []


func _ready() -> void:
	_check_segments()
	_check_deck()
	_check_flag_closure()
	_check_first_turn()
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
	check(EventManager.deck.size() == 21, "exactly 21 event cards loaded (got %d)" % EventManager.deck.size())
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
