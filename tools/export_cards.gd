extends Node
## One-shot migration: data/events/*.tres -> content/cards/*.md
## Run:  godot --headless res://tools/export_cards.tscn
## The .md basename matches the .tres basename; import_cards.gd writes back to
## the same filename. Safe to re-run: it overwrites the Markdown, never the .tres.

const EVENTS_DIR := "res://data/events"
const CONTENT_DIR := "res://content/cards"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CONTENT_DIR))
	var dir := DirAccess.open(EVENTS_DIR)
	if dir == null:
		push_error("EXPORT FAIL: no %s" % EVENTS_DIR)
		get_tree().quit(1)
		return
	var files := dir.get_files()
	files.sort()
	var written := 0
	for file in files:
		if not (file.ends_with(".tres") or file.ends_with(".tres.remap")):
			continue
		var clean := file.trim_suffix(".remap")
		var card = load(EVENTS_DIR + "/" + clean)
		if card == null or not (card is EventCard):
			push_error("EXPORT FAIL: %s is not an EventCard" % clean)
			get_tree().quit(1)
			return
		var base := clean.trim_suffix(".tres")
		var path := CONTENT_DIR + "/" + base + ".md"
		var out := FileAccess.open(path, FileAccess.WRITE)
		if out == null:
			push_error("EXPORT FAIL: cannot write %s" % path)
			get_tree().quit(1)
			return
		out.store_string(_render(card))
		out.close()
		written += 1
	print("EXPORT OK: wrote %d card files to %s" % [written, CONTENT_DIR])
	get_tree().quit(0)


func _render(card: EventCard) -> String:
	var s := "---\n"
	s += "event_id: %s\n" % card.event_id
	s += "title: %s\n" % card.title
	s += "phase_id: %s\n" % card.phase_id
	s += "location_name: %s\n" % card.location_name
	s += "mile_start: %d\n" % card.mile_start
	s += "mile_end: %d\n" % card.mile_end
	s += "historical_year_start: %d\n" % card.historical_year_start
	s += "historical_year_end: %d\n" % card.historical_year_end
	s += "is_fixed: %s\n" % ("true" if card.is_fixed else "false")
	s += "weight: %s\n" % str(card.weight)
	s += "canonical_choice: %d\n" % card.canonical_choice
	s += "hazard_kind: %s\n" % card.hazard_kind
	s += "required_flags: %s\n" % _join(card.required_flags)
	s += "blocked_by_flags: %s\n" % _join(card.blocked_by_flags)
	s += "---\n\n"
	s += "## Description\n\n%s\n\n" % card.event_description.strip_edges()
	s += "## Historical fact\n\n%s\n\n" % card.historical_fact.strip_edges()
	s += "## Source note\n\n%s\n\n" % card.historical_source_note.strip_edges()
	s += "## Assumption note\n\n%s\n\n" % card.assumption_note.strip_edges()
	for choice in card.choices:
		s += "## Choice: %s\n\n" % choice.label
		s += "funds: %d\n" % choice.funds_delta
		s += "support: %d\n" % choice.public_support_delta
		s += "readiness: %d\n" % choice.water_readiness_delta
		s += "crew: %d\n" % choice.crew_wellbeing_delta
		s += "time: %d\n" % choice.time_delta_seasons
		s += "grants: %s\n" % _join(choice.granted_flags)
		s += "repeat: %s\n\n" % ("true" if choice.repeat_card else "false")
		s += "%s\n\n" % choice.outcome_text.strip_edges()
	return s


func _join(flags: Array) -> String:
	var parts: Array[String] = []
	for f in flags:
		parts.append(String(f))
	return ", ".join(parts)
