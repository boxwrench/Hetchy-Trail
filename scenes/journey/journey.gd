extends Node
## Turn conductor: DECIDE -> RESOLVE -> EVENT -> CHECK.
## The only script that calls GameState.advance_turn() and
## EventManager.try_draw_queue().

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const DECISION_SCENE := preload("res://scenes/ui/decision_panel.tscn")
const EVENT_SCENE := preload("res://scenes/ui/event_panel.tscn")

# Deliberately untyped: these hold scene instances whose custom methods
# (refresh_affordability, show_card, ...) GDScript can't see on base types.
var hud
var decision_panel
var event_panel
var current_card: EventCard
var pending: Array[EventCard] = []


func _ready() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	decision_panel = DECISION_SCENE.instantiate()
	add_child(decision_panel)
	event_panel = EVENT_SCENE.instantiate()
	add_child(event_panel)
	decision_panel.decisions_confirmed.connect(_on_decisions)
	event_panel.choice_selected.connect(_on_event_choice)
	GameState.game_ended.connect(_on_game_ended)
	_begin_decide()


func _begin_decide() -> void:
	decision_panel.refresh_affordability()
	decision_panel.set_enabled(true)


func _on_decisions(pace: int, action: StringName, front: int) -> void:
	decision_panel.set_enabled(false)
	GameState.work_pace = pace
	GameState.set_front(front)
	if action != &"none":
		GameState.take_action(action)
	GameState.advance_turn()
	if GameState.game_over:
		return
	pending = EventManager.try_draw_queue()
	_show_next()


func _on_event_choice(index: int) -> void:
	var card := current_card
	current_card = null
	EventManager.resolve_choice(card, index)
	# Resolving a milestone can unlock the next one on the same front. Queue it
	# behind whatever is already pending rather than drawing it up front.
	var followup: EventCard = EventManager.try_draw_followup(card)
	if followup != null:
		pending.append(followup)
	_show_next()


## Shows the next queued card, or hands the turn back to the player when the
## queue is empty. A hazard that ends the game stops the queue here.
func _show_next() -> void:
	if GameState.game_over:
		pending.clear()
		return
	if pending.is_empty():
		_begin_decide()
		return
	current_card = pending.pop_front()
	event_panel.show_card(current_card)


func _on_game_ended(result: StringName) -> void:
	# Placeholder banner; Task 9's Main scene replaces this screen entirely.
	decision_panel.set_enabled(false)
	event_panel.hide()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var label := Label.new()
	label.text = "Game over: %s (%s, %d)" % [result, GameState.completion_grade(), GameState.current_year()]
	center.add_child(label)
