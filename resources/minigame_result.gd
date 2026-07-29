class_name MinigameResult
extends Resource
## What a minigame module returns. Score and tier, and nothing else.
##
## The module never applies an effect. The tier selects among the driving card's
## authored EventChoices, so all consequence numbers and all prose stay in
## content/. Adding a field here to carry a consequence is a contract violation,
## not a convenience.

const TIERS: Array[StringName] = [&"poor", &"fair", &"strong"]

@export var minigame_id: StringName = &""
## Module-defined magnitude. Comparable only within one minigame_id.
@export var score: int = 0
@export var tier: StringName = &"poor"


func is_valid() -> bool:
	return minigame_id != &"" and TIERS.has(tier)


static func make(id: StringName, p_score: int, p_tier: StringName) -> MinigameResult:
	var r := MinigameResult.new()
	r.minigame_id = id
	r.score = p_score
	r.tier = p_tier
	return r
