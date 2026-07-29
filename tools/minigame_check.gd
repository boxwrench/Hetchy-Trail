extends Node
## Headless check on the minigame contract. Run:
##   godot --headless res://tools/minigame_check.tscn      (exit 0 PASS, 1 FAIL)
##
## This is NOT minigame_sim. It validates that the wiring is coherent -- every
## binding names a real card, every tier maps to a choice that card actually
## authors. Band verification needs a real module and comes with it.

var passed := 0
var failures: Array[String] = []


func _ready() -> void:
	_check_result_type()
	_check_bindings()
	_check_scenes()
	if failures.is_empty():
		print("MINIGAME PASS (%d checks)" % passed)
	else:
		print("MINIGAME FAIL (%d failures)" % failures.size())
		for f in failures:
			print("  " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _ok(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)


func _check_result_type() -> void:
	var good := MinigameResult.make(&"x", 10, &"fair")
	_ok(good.is_valid(), "a well-formed MinigameResult must validate")
	var bad := MinigameResult.make(&"x", 10, &"excellent")
	_ok(not bad.is_valid(), "an unknown tier must not validate")
	var anon := MinigameResult.make(&"", 0, &"poor")
	_ok(not anon.is_valid(), "a result with no minigame_id must not validate")
	_ok(MinigameResult.TIERS.size() == 3, "there are exactly three tiers")


## Every registered scene must exist and be instantiable, and every bound
## minigame_id must resolve to a real module rather than silently falling back to
## the stub. The fallback is deliberate for UNBUILT slots; it must never quietly
## absorb a typo in a slot that is supposed to be finished.
func _check_scenes() -> void:
	_ok(ResourceLoader.exists(MinigameRegistry.STUB_SCENE),
		"the stub fallback scene is missing: %s" % MinigameRegistry.STUB_SCENE)
	for id in MinigameRegistry.SCENES:
		var path: String = MinigameRegistry.SCENES[id]
		_ok(ResourceLoader.exists(path), "scene for %s does not exist: %s" % [id, path])
		if not ResourceLoader.exists(path):
			continue
		var packed: Resource = load(path)
		_ok(packed is PackedScene, "scene for %s is not a PackedScene: %s" % [id, path])
		_ok(MinigameRegistry.scene_for(id) == path,
			"scene_for(%s) did not return its registered path" % id)
	for event_id in MinigameRegistry.BINDINGS:
		var mid: StringName = MinigameRegistry.BINDINGS[event_id]["minigame_id"]
		_ok(MinigameRegistry.SCENES.has(mid),
			"%s is bound to minigame_id %s, which has no scene and would fall back to the stub"
				% [event_id, mid])


func _check_bindings() -> void:
	var by_id := {}
	for card in EventManager.deck:
		by_id[card.event_id] = card
	for event_id in MinigameRegistry.BINDINGS:
		_ok(by_id.has(event_id),
			"binding names a card not in the deck: %s" % event_id)
		if not by_id.has(event_id):
			continue
		var card: EventCard = by_id[event_id]
		var cfg := MinigameRegistry.config_for(event_id)
		_ok(cfg != null and cfg.minigame_id != &"",
			"binding has no minigame_id: %s" % event_id)
		for tier in MinigameResult.TIERS:
			var index := MinigameRegistry.choice_for_tier(event_id, tier)
			_ok(index >= 0,
				"tier %s is unmapped on %s" % [tier, event_id])
			_ok(index >= 0 and index < card.choices.size(),
				"tier %s on %s maps to choice %d, but the card authors %d"
					% [tier, event_id, index, card.choices.size()])
