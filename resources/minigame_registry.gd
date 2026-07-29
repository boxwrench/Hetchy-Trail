class_name MinigameRegistry
extends RefCounted
## Which cards open a minigame, and how each tier maps back onto that card's
## authored choices.
##
## The binding lives HERE and not on EventCard on purpose. content/cards/*.md is
## the canonical source for card data and is historian territory; adding a
## front-matter key there would mean editing content/ and tools/import_cards.gd
## for a framework change. Keeping the binding on this side means the framework
## can land, and be reverted, without touching authored content at all.

## event_id -> binding.
##   minigame_id : which module opens
##   params      : handed to the module as MinigameConfig.params
##   tier_choice : tier -> index into that card's `choices` array
##
## The 803-Foot Month authors exactly two choices, so the map is many-to-one:
##   index 0 = "Chase the record", index 1 = "Hold a sustainable pace".
const BINDINGS := {
	&"the_803_foot_month": {
		"minigame_id": &"the_heading",
		"params": {"target_feet": 803},
		"tier_choice": {&"strong": 0, &"fair": 1, &"poor": 1},
	},
}


static func has_binding(event_id: StringName) -> bool:
	return BINDINGS.has(event_id)


static func config_for(event_id: StringName) -> MinigameConfig:
	if not BINDINGS.has(event_id):
		return null
	var b: Dictionary = BINDINGS[event_id]
	var cfg := MinigameConfig.new()
	cfg.minigame_id = b["minigame_id"]
	cfg.event_id = event_id
	cfg.params = (b["params"] as Dictionary).duplicate(true)
	return cfg


## Which authored choice a tier resolves to. Returns -1 when unmapped, which
## callers must treat as "do not open the minigame" rather than as index 0.
static func choice_for_tier(event_id: StringName, tier: StringName) -> int:
	if not BINDINGS.has(event_id):
		return -1
	var map: Dictionary = BINDINGS[event_id]["tier_choice"]
	if not map.has(tier):
		return -1
	return int(map[tier])
