extends Node
## Headless layout regression test. Instantiates the real Journey scene, lets it
## lay out, and asserts the interactive panels render WITHIN the viewport.
## Catches the class of bug where a panel exists but is positioned off-screen
## or has zero size -- which the data/logic smoke test cannot see.
## Run:  godot --headless res://tools/layout_test.tscn   (exit 0 PASS, 1 FAIL)

var passed := 0
var failures: Array[String] = []


func _ready() -> void:
	GameState.new_game()
	EventManager.reset()
	var journey: Node = load("res://scenes/journey/journey.tscn").instantiate()
	add_child(journey)
	# Layout is computed over the next frames, not at instantiation.
	await get_tree().process_frame
	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	_check_on_screen("DecisionPanel bar", _first_control_child(journey.decision_panel), vp)
	journey.event_panel.show()
	await get_tree().process_frame
	_check_on_screen("EventPanel body", _first_control_child(journey.event_panel), vp)
	if failures.is_empty():
		print("LAYOUT PASS (%d checks)" % passed)
	else:
		print("LAYOUT FAIL (%d failures)" % failures.size())
	journey.queue_free()
	get_tree().quit(0 if failures.is_empty() else 1)


func _first_control_child(node: Node) -> Control:
	for child in node.get_children():
		if child is Control:
			return child
	return null


func check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failures.append(what)
		push_error("LAYOUT FAIL: " + what)


func _check_on_screen(label: String, ctrl: Control, vp: Vector2) -> void:
	check(ctrl != null, "%s exists" % label)
	if ctrl == null:
		return
	var pos := ctrl.global_position
	var rect_size := ctrl.size
	check(rect_size.x > 0.0 and rect_size.y > 0.0, "%s has non-zero size (got %s)" % [label, rect_size])
	# Allow 1px rounding slack at the edges.
	check(pos.y >= -1.0, "%s top edge is on-screen (y=%.1f)" % [label, pos.y])
	check(pos.y + rect_size.y <= vp.y + 1.0, "%s bottom edge is on-screen (bottom=%.1f, vp=%.0f)" % [label, pos.y + rect_size.y, vp.y])
	check(pos.x >= -1.0 and pos.x + rect_size.x <= vp.x + 1.0, "%s fits horizontally" % label)
