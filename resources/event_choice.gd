class_name EventChoice
extends Resource
## One player choice on an EventCard. Effects use the five-point impact model
## from the historical mapping brief: each delta is roughly -3..+3, where
## 1 is minor, 2 substantial, 3 severe. Time deltas are measured in seasons.

@export var label: String = ""
@export_multiline var outcome_text: String = ""

@export_group("Resource Effects")
@export_range(-5, 5) var funds_delta: int = 0
@export_range(-5, 5) var public_support_delta: int = 0
@export_range(-5, 5) var water_readiness_delta: int = 0
@export_range(-5, 5) var crew_wellbeing_delta: int = 0
@export_range(-5, 5) var time_delta_seasons: int = 0

@export_group("Campaign Flags")
@export var granted_flags: Array[StringName] = []

## When true, picking this choice returns the card to the deck so it can fire
## again later (e.g. a failed bond vote that can be attempted again).
@export var repeat_card: bool = false
