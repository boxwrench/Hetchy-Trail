extends Control
## DECIDE-phase form: pace + one optional action + End Season.
## Emits the result; applies nothing itself.

signal decisions_confirmed(pace: int, action: StringName)

const ACTIONS: Array[StringName] = [&"none", &"issue_bond", &"outreach", &"improve_camp"]
const ACTION_LABELS := [
	"No special action",
	"Issue bond (+3 funds, -1 support)",
	"Community outreach (-1 funds, +2 support)",
	"Improve the camps (-1 funds, +2 crew)",
]

var pace_select: OptionButton
var action_select: OptionButton
var end_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	pace_select = OptionButton.new()
	for pace_name in ["Rest the crews", "Steady work", "Push the pace"]:
		pace_select.add_item(pace_name)
	pace_select.select(GameState.Pace.STEADY)
	row.add_child(pace_select)
	action_select = OptionButton.new()
	for action_label in ACTION_LABELS:
		action_select.add_item(action_label)
	row.add_child(action_select)
	end_button = Button.new()
	end_button.text = "End season"
	end_button.pressed.connect(_on_end_pressed)
	row.add_child(end_button)
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
	action_select.set_item_disabled(1, GameState.public_support < GameState.BOND_MIN_SUPPORT)
	action_select.set_item_disabled(2, GameState.funds < GameState.OUTREACH_FUNDS_COST)
	action_select.set_item_disabled(3, GameState.funds < GameState.CAMP_FUNDS_COST)
