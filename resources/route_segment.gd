class_name RouteSegment
extends Resource
## One of the six construction divisions on the 0-167 mile game alignment.
## Mile ranges are game-design stationing (rounded component lengths), not
## historical engineering survey stations.

@export var segment_name: String = ""
@export var phase_id: StringName
@export var start_mile: int = 0
@export var end_mile: int = 0
@export var year_start: int = 0
@export var year_end: int = 0

## Multiplies the per-season build rate while the construction front is in
## this segment. Below 1.0 is slow ground (Coast Range), above 1.0 is fast
## (San Joaquin Valley pipeline).
@export var build_rate_modifier: float = 1.0

## Sierra divisions build at NO_RAILROAD_FACTOR until the Hetch Hetchy Railroad
## is operational. Named for the seasonal model this game no longer simulates;
## the property now means "railroad-dependent". DEFERRED CLEANUP: renaming this
## export would silently drop the value from the six segment .tres files, so the
## name stays until a migration is written.
@export var winter_sensitive: bool = false

## GameState flag that marks this division complete; the map lights the
## segment when the flag is granted.
@export var completion_flag: StringName

## One warm sentence for the map label.
@export_multiline var blurb: String = ""


func contains(miles: float) -> bool:
	return miles >= float(start_mile) and miles < float(end_mile)
