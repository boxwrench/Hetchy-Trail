extends Control
## Displays one EventCard: description, choices, and the teaching layer
## ("What really happened" + assumption note + optional archival photo).

signal choice_selected(index: int)

var title_label: Label
var body_label: Label
var photo_rect: TextureRect
var fact_label: Label
var note_label: Label
var buttons_box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	title_label = _add_label(box)
	body_label = _add_label(box)
	photo_rect = TextureRect.new()
	photo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo_rect.custom_minimum_size = Vector2(0, 220)
	box.add_child(photo_rect)
	buttons_box = VBoxContainer.new()
	box.add_child(buttons_box)
	box.add_child(HSeparator.new())
	fact_label = _add_label(box)
	note_label = _add_label(box)
	note_label.modulate = Color(1, 1, 1, 0.7)


func _add_label(parent: Node) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(640, 0)
	parent.add_child(label)
	return label


func show_card(card: EventCard) -> void:
	title_label.text = "%s — %s, %d" % [card.title, card.location_name, card.historical_year_start]
	body_label.text = card.event_description
	photo_rect.texture = card.archival_photo
	photo_rect.visible = card.archival_photo != null
	fact_label.text = "What really happened: " + card.historical_fact
	note_label.text = card.assumption_note
	note_label.visible = card.assumption_note != ""
	for child in buttons_box.get_children():
		child.queue_free()
	for i in card.choices.size():
		var button := Button.new()
		button.text = card.choices[i].label
		button.pressed.connect(_on_choice.bind(i))
		buttons_box.add_child(button)
	show()


func _on_choice(index: int) -> void:
	hide()
	choice_selected.emit(index)
