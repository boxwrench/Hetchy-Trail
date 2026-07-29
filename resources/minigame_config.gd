class_name MinigameConfig
extends Resource
## What a minigame module is handed when it opens. Built by the caller --
## Journey for a card-driven launch, the arcade entry for a standalone one.
##
## Deliberately generic: module-specific numbers live in `params` rather than as
## typed fields, so adding a second minigame never edits this file.

@export var minigame_id: StringName = &""
## The card that opened it. Empty for an arcade launch with no driving card.
@export var event_id: StringName = &""
## Module-specific inputs, e.g. {"target_feet": 803}. Keys are the module's own
## business; nothing outside the module may read them.
@export var params: Dictionary = {}
## 0 means "pick one at runtime". Set non-zero for reproducible runs in tools.
@export var seed: int = 0


func has_param(key: String) -> bool:
	return params.has(key)


func get_int(key: String, fallback: int) -> int:
	if not params.has(key):
		return fallback
	return int(params[key])
