extends CanvasLayer
## Read-only display of the five metrics, the date, and the construction front.
## Metrics near a loss condition turn warning-rust; ongoing drains are surfaced.

const WARN_COLOR := Color(0.65, 0.32, 0.18)   # warning rust (#A6532E), per art_assets.md
const FUNDS_WARN_AT := 2                        # bond crisis strikes below 0
const METER_WARN_AT := 2                        # support->cancelled, crew->halt at 0

var labels := {}
var cost_label: Label


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(panel)
	var col := VBoxContainer.new()
	panel.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	for key in ["date", "miles", "funds", "support", "water", "crew"]:
		var label := Label.new()
		row.add_child(label)
		labels[key] = label
	cost_label = Label.new()
	cost_label.modulate = WARN_COLOR
	cost_label.visible = false
	col.add_child(cost_label)
	GameState.funds_changed.connect(_set_funds)
	GameState.support_changed.connect(_set_support)
	GameState.crew_changed.connect(_set_crew)
	GameState.readiness_changed.connect(_set_water)
	GameState.flag_granted.connect(_on_flag)
	GameState.miles_changed.connect(func(_v: float): _set_miles())
	GameState.turn_advanced.connect(func(y: int, _p: int):
		labels["date"].text = "Turn %d  ·  %d" % [GameState.turn, y]
		_update_cost_cue())
	_refresh()


func _refresh() -> void:
	_set_funds(GameState.funds)
	_set_support(GameState.public_support)
	_set_crew(GameState.crew_wellbeing)
	_set_miles()
	labels["date"].text = "Turn %d  ·  %d" % [GameState.turn, GameState.current_year()]
	_set_water(GameState.water_readiness)
	_update_cost_cue()


func _set_funds(v: int) -> void:
	labels["funds"].text = "Funds: %d" % v
	_warn(labels["funds"], v <= FUNDS_WARN_AT)


func _set_support(v: int) -> void:
	labels["support"].text = "Support: %d/10" % v
	_warn(labels["support"], v <= METER_WARN_AT)


func _set_crew(v: int) -> void:
	labels["crew"].text = "Crew: %d/10" % v
	_warn(labels["crew"], v <= METER_WARN_AT)


func _set_water(v: int) -> void:
	var note := " — delivered!" if GameState.has_flag(&"hetch_hetchy_water_delivered") else " (not yet delivered)"
	labels["water"].text = "Water readiness: %d/%d%s" % [v, GameState.READINESS_TARGET, note]


func _on_flag(_f: StringName) -> void:
	_set_water(GameState.water_readiness)
	_update_cost_cue()


## Ongoing drains, in one line. Both are per-phase costs the player cannot see
## in any single number, so surfacing them is what makes them a lesson rather
## than an unexplained decline.
func _update_cost_cue() -> void:
	var cues: Array[String] = []
	if GameState.has_flag(&"pumped_alternative_chosen"):
		cues.append("Pumping: -%d funds every phase" % GameState.PUMPING_SURCHARGE)
	var overrun: int = GameState.overrun_years()
	if overrun > 0:
		cues.append("Behind schedule %d year%s: -%d funds every phase, support slipping"
			% [overrun, "" if overrun == 1 else "s",
			overrun * GameState.OVERRUN_FUNDS_PER_YEAR])
	cost_label.text = "  ·  ".join(cues)
	cost_label.visible = not cues.is_empty()


func _warn(label: Label, on: bool) -> void:
	if on:
		label.add_theme_color_override("font_color", WARN_COLOR)
	else:
		label.remove_theme_color_override("font_color")


## The label's only writer. A front counts as done when its progress is full AND
## it owes no fixed cards -- the same test the DecisionPanel uses for
## "(complete)", so the HUD cannot report 6/6 while a card is still pending.
func _set_miles() -> void:
	labels["miles"].text = "Mile %.1f of 167  ·  %d/%d fronts done" % [
		GameState.miles_built, _fronts_done(), GameState.front_count()]


func _fronts_done() -> int:
	var n := 0
	for i in GameState.front_count():
		if GameState.front_progress[i] >= 1.0 and not EventManager.front_has_pending_fixed(i):
			n += 1
	return n

