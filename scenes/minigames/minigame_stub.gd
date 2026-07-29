extends Control
## STUB. Stands in for every minigame module until the real ones are built.
##
## It exists to prove the contract end to end: a config goes in, a valid
## MinigameResult comes out, and Journey applies the card choice the tier maps
## to. It contains no gameplay and models nothing.
##
## The three tier buttons are a TEST AFFORDANCE, not a design. A single Resolve
## button could only ever exercise one of the three mappings.

signal finished(result: MinigameResult)

var config: MinigameConfig


func open(cfg: MinigameConfig) -> void:
	config = cfg
	var title := $Panel/Box/Title as Label
	title.text = "STUB — %s" % cfg.minigame_id
	var note := $Panel/Box/Note as Label
	note.text = "Placeholder for the real module. Pick a tier to test the mapping."
	for child in ($Panel/Box/Buttons as BoxContainer).get_children():
		child.queue_free()
	for tier in MinigameResult.TIERS:
		var button := Button.new()
		button.text = String(tier)
		button.pressed.connect(_on_tier.bind(tier))
		($Panel/Box/Buttons as BoxContainer).add_child(button)
	show()


func _on_tier(tier: StringName) -> void:
	hide()
	# Score is illustrative only; nothing reads it until a real module exists.
	var target := config.get_int("target_feet", 0)
	var score := 0
	if tier == &"strong":
		score = target
	elif tier == &"fair":
		score = int(round(0.6 * float(target)))
	finished.emit(MinigameResult.make(config.minigame_id, score, tier))
