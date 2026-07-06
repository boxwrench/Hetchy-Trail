extends Node
## Plays a full campaign headless: Steady pace, sensible actions, always the
## canonical (historical) choice. Run:  godot --headless res://tools/sim_test.tscn
## PASS = system complete by 1940. Deterministic (fixed seed).

const MAX_TURNS := 160
const SEASONS := ["Winter", "Spring", "Summer", "Fall"]

var result: StringName = &""


func _ready() -> void:
	seed(1234)
	GameState.new_game()
	EventManager.reset()
	GameState.game_ended.connect(func(r: StringName): result = r)
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
	print("SIM RESULT: %s | %s %d | mile %.0f | readiness %d | funds %d | support %d | crew %d | %d turns"
		% [result, SEASONS[GameState.season], GameState.year, GameState.miles_built,
		GameState.water_readiness, GameState.funds, GameState.public_support,
		GameState.crew_wellbeing, turns])
	if result == &"system_complete" and GameState.year <= 1940:
		print("SIM PASS: system_complete, grade=%s" % GameState.completion_grade())
		get_tree().quit(0)
	else:
		print("SIM FAIL")
		get_tree().quit(1)
