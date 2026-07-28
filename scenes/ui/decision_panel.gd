extends Control
## DECIDE-phase form: pace + one optional action + End Season, plus a live
## telegraph of the risk the chosen pace carries this season.
## Emits the result; applies nothing itself.

signal decisions_confirmed(pace: int, action: StringName, front: int)

const ACTIONS: Array[StringName] = [&"none", &"issue_bond", &"outreach", &"improve_camp"]
const ACTION_LABELS := [
	"No special action",
	# Placeholder text only -- refresh_affordability() rewrites all three from
	# the live GameState constants and the current escalated costs.
	"Issue bond",
	"Community outreach",
	"Improve the camps",
]

var pace_select: OptionButton
var front_select: OptionButton
var action_select: OptionButton
var end_button: Button
var risk_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	# Bottom-anchored containers grow downward by default, which pushes the bar
	# off the bottom edge; grow upward so it sits on-screen above the edge.
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	front_select = OptionButton.new()
	row.add_child(front_select)
	pace_select = OptionButton.new()
	for pace_name in ["Rest the crews", "Steady work", "Push the pace"]:
		pace_select.add_item(pace_name)
	pace_select.select(GameState.Pace.STEADY)
	pace_select.item_selected.connect(func(_i: int): _refresh_risk())
	row.add_child(pace_select)
	action_select = OptionButton.new()
	for action_label in ACTION_LABELS:
		action_select.add_item(action_label)
	row.add_child(action_select)
	end_button = Button.new()
	end_button.text = "End phase"
	end_button.pressed.connect(_on_end_pressed)
	row.add_child(end_button)
	risk_label = Label.new()
	col.add_child(risk_label)
	refresh_affordability()


func _on_end_pressed() -> void:
	var action: StringName = ACTIONS[action_select.selected]
	action_select.select(0)
	decisions_confirmed.emit(pace_select.selected, action, front_select.selected)


func set_enabled(on: bool) -> void:
	end_button.disabled = not on
	pace_select.disabled = not on
	action_select.disabled = not on
	front_select.disabled = not on


func refresh_affordability() -> void:
	_refresh_fronts()
	action_select.set_item_disabled(1, not GameState.can_take_action(&"issue_bond"))
	action_select.set_item_disabled(2, not GameState.can_take_action(&"outreach"))
	action_select.set_item_disabled(3, not GameState.can_take_action(&"improve_camp"))
	var bonds_left := GameState.MAX_BOND_ISSUES - GameState.bonds_issued
	action_select.set_item_text(1, "Issue bond (+%d funds, -%d support) - %d left"
		% [GameState.BOND_FUNDS_GAIN, GameState.BOND_SUPPORT_COST, bonds_left])
	action_select.set_item_text(2, "Community outreach (-%d funds, +%d support)"
		% [GameState.action_cost(&"outreach"), GameState.OUTREACH_SUPPORT_GAIN])
	action_select.set_item_text(3, "Improve the camps (-%d funds, +%d crew)"
		% [GameState.action_cost(&"improve_camp"), GameState.CAMP_CREW_GAIN])
	_refresh_risk()


func _refresh_risk() -> void:
	var preview: Dictionary = EventManager.risk_preview(pace_select.selected)
	var noun := "injury" if preview["kind"] == &"injury" else "public impatience"
	# The pace-risk roll now runs every turn, milestone or not, so this reads
	# as a plain statement rather than a conditional.
	risk_label.text = "This phase: %s chance of %s" % [String(preview["level"]), noun]


## Rebuilds the front list each turn: finished fronts and fronts still waiting
## on power are shown but disabled, so the player can see the shape of the
## project rather than only its currently-legal moves.
func _refresh_fronts() -> void:
	var chosen := front_select.selected
	front_select.clear()
	for i in GameState.front_count():
		var seg := GameState.segments[i]
		var pct := int(round(GameState.front_progress[i] * 100.0))
		# A front is only finished when its CARDS are done, not when its progress
		# bar fills. Only one fixed card is drawn per turn, so a fast front can
		# reach 100%% still owing cards -- disabling it there locked the Pulgas
		# connection out of the game entirely while every front read complete.
		var owed: bool = EventManager.front_has_pending_fixed(i)
		var label := "%s — %d%%" % [seg.segment_name, pct]
		if GameState.front_progress[i] >= 1.0 and not owed:
			label += " (complete)"
		elif GameState.front_progress[i] >= 1.0:
			label += " (finishing up)"
		elif not GameState.front_is_open(i):
			label += " (waiting)"
		front_select.add_item(label)
		front_select.set_item_disabled(i,
			(GameState.front_progress[i] >= 1.0 and not owed) or not GameState.front_is_open(i))
	if chosen >= 0 and chosen < GameState.front_count() \
			and not front_select.is_item_disabled(chosen):
		front_select.select(chosen)
	else:
		for i in GameState.front_count():
			if not front_select.is_item_disabled(i):
				front_select.select(i)
				break

