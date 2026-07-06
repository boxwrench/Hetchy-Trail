extends CanvasLayer
## Read-only display of the five metrics, the date, and the construction front.

const SEASONS := ["Winter", "Spring", "Summer", "Fall"]

var labels := {}


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)
	for key in ["date", "miles", "funds", "support", "water", "crew"]:
		var label := Label.new()
		row.add_child(label)
		labels[key] = label
	GameState.funds_changed.connect(func(v: int): labels["funds"].text = "Funds: %d" % v)
	GameState.support_changed.connect(func(v: int): labels["support"].text = "Support: %d/10" % v)
	GameState.crew_changed.connect(func(v: int): labels["crew"].text = "Crew: %d/10" % v)
	GameState.readiness_changed.connect(_set_water)
	GameState.flag_granted.connect(func(_f: StringName): _set_water(GameState.water_readiness))
	GameState.miles_changed.connect(func(v: float): labels["miles"].text = "Mile %.1f of 167" % v)
	GameState.turn_advanced.connect(func(y: int, s: int): labels["date"].text = "%s %d" % [SEASONS[s], y])
	_refresh()


func _refresh() -> void:
	labels["funds"].text = "Funds: %d" % GameState.funds
	labels["support"].text = "Support: %d/10" % GameState.public_support
	labels["crew"].text = "Crew: %d/10" % GameState.crew_wellbeing
	labels["miles"].text = "Mile %.1f of 167" % GameState.miles_built
	labels["date"].text = "%s %d" % [SEASONS[GameState.season], GameState.year]
	_set_water(GameState.water_readiness)


func _set_water(v: int) -> void:
	var note := " — delivered!" if GameState.has_flag(&"hetch_hetchy_water_delivered") else " (not yet delivered)"
	labels["water"].text = "Water readiness: %d/%d%s" % [v, GameState.READINESS_TARGET, note]
