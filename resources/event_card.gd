class_name EventCard
extends Resource
## One historical encounter, authored as a .tres file in data/events/.
## Cards carry both the playable event and the teaching layer: the historical
## fact shown to the player, a source note, and an assumption note that records
## every place gameplay deviates from the historical record.

@export var event_id: StringName
@export var title: String = ""
@export var phase_id: StringName
@export var location_name: String = ""

## Game-design stationing on the 0-167 mile alignment, not survey stations.
## The card becomes available once the construction front reaches mile_start.
## Non-fixed cards expire once the front passes mile_end.
@export var mile_start: int = 0
@export var mile_end: int = 167
@export var historical_year_start: int = 0
@export var historical_year_end: int = 0

@export_multiline var event_description: String = ""
@export_multiline var historical_fact: String = ""
@export var archival_photo: Texture2D

@export var choices: Array[EventChoice] = []
## Index into choices marking what actually happened historically.
@export var canonical_choice: int = 0

@export_group("Draw Rules")
## Fixed cards fire automatically (one per turn) as soon as their mile and
## flag conditions are met; they form the historical spine of the campaign.
## Non-fixed cards go into the weighted random draw.
@export var is_fixed: bool = false
@export var weight: float = 1.0
@export var required_flags: Array[StringName] = []
@export var blocked_by_flags: Array[StringName] = []
@export var winter_only: bool = false
## Empty for a normal card. "injury" or "impatience" marks a repeatable
## hazard drawn only by EventManager's pace-risk roll, never the normal deck.
@export var hazard_kind: StringName = &""

@export_group("Historical Notes")
@export_multiline var historical_source_note: String = ""
@export_multiline var assumption_note: String = ""


func is_available(miles: float, is_winter: bool, flags: Dictionary) -> bool:
	if miles < float(mile_start):
		return false
	if not is_fixed and miles > float(mile_end):
		return false
	if winter_only and not is_winter:
		return false
	for flag in required_flags:
		if not flags.has(flag):
			return false
	for flag in blocked_by_flags:
		if flags.has(flag):
			return false
	return true
