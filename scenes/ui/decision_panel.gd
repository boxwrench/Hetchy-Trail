extends Control
## DECIDE-phase form: pace + one optional action + End Season, plus a live
## telegraph of the risk the chosen pace carries this season.
## Emits the result; applies nothing itself.

signal decisions_confirmed(pace: int, action: StringName)

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
	decisions_confirmed.emit(pace_select.selected, action)


func set_enabled(on: bool) -> void:
	end_button.disabled = not on
	pace_select.disabled = not on
	action_select.disabled = not on


func refresh_affordability() -> void:
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
	# Worded as a conditional: on turns a fixed milestone card is due, the hazard
	# roll is skipped entirely, so this is the risk only "if the phase passes quietly".
	risk_label.text = "If the phase passes quietly: %s chance of %s" % [String(preview["level"]), noun]
