extends Node
## Builds data/events/*.tres from content/cards/*.md
## Run:  godot --headless res://tools/import_cards.tscn
## Exits 0 on success, 1 with a file-and-line message on malformed input.
## Never silently skips a card -- silent skipping was the defect this replaces.

const CONTENT_DIR := "res://content/cards"
const EVENTS_DIR := "res://data/events"
const EFFECT_KEYS := ["funds", "support", "readiness", "crew", "time", "grants", "repeat"]
const META_KEYS := ["event_id", "title", "phase_id", "location_name",
	"mile_start", "mile_end", "historical_year_start", "historical_year_end",
	"is_fixed", "weight", "canonical_choice", "hazard_kind",
	"required_flags", "blocked_by_flags"]
const SECTION_NAMES := ["Description", "Historical fact", "Source note",
	"Assumption note"]
const HAZARD_KINDS := ["", "injury", "impatience"]
const DELTA_MIN := -5
const DELTA_MAX := 5

var errors: Array[String] = []
var seen_ids: Dictionary = {}         # event_id -> source filename
var granted_flags: Dictionary = {}    # every flag any card grants
var required_flags: Dictionary = {}   # flag -> filename that requires it


func _ready() -> void:
	var dir := DirAccess.open(CONTENT_DIR)
	if dir == null:
		print("IMPORT FAIL: no %s -- run export_cards first" % CONTENT_DIR)
		get_tree().quit(1)
		return
	var files := dir.get_files()
	files.sort()
	var built := 0
	for file in files:
		if not file.ends_with(".md"):
			continue
		var card := _parse(CONTENT_DIR + "/" + file)
		if card == null:
			continue
		var out := EVENTS_DIR + "/" + file.trim_suffix(".md") + ".tres"
		var err := ResourceSaver.save(card, out)
		if err != OK:
			errors.append("%s: could not write %s (error %d)" % [file, out, err])
			continue
		built += 1
	# A required flag nobody grants is an unreachable card -- the exact silent
	# failure this pipeline exists to prevent.
	for flag in required_flags:
		if not granted_flags.has(flag):
			errors.append("%s requires flag '%s', which no card grants and GameState does not define" % [required_flags[flag], flag])
	if errors.is_empty():
		print("IMPORT OK: built %d cards into %s" % [built, EVENTS_DIR])
		get_tree().quit(0)
	else:
		for e in errors:
			print("IMPORT FAIL: %s" % e)
		print("IMPORT FAIL: %d problem(s); no partial run is trustworthy" % errors.size())
		get_tree().quit(1)


func _parse(path: String) -> EventCard:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		errors.append("%s: cannot open" % path)
		return null
	var lines := f.get_as_text().split("\n")
	f.close()
	var name := path.get_file()

	var card := EventCard.new()
	var meta := {}
	var i := 0
	# --- frontmatter ---
	if i >= lines.size() or lines[i].strip_edges() != "---":
		errors.append("%s line 1: must start with ---" % name)
		return null
	i += 1
	while i < lines.size() and lines[i].strip_edges() != "---":
		var line: String = lines[i]
		if line.strip_edges() != "":
			var colon := line.find(":")
			if colon < 0:
				errors.append("%s line %d: expected 'key: value', got '%s'" % [name, i + 1, line])
				return null
			meta[line.substr(0, colon).strip_edges()] = line.substr(colon + 1).strip_edges()
		i += 1
	if i >= lines.size():
		errors.append("%s: frontmatter is never closed with ---" % name)
		return null
	i += 1

	for key in meta:
		if not META_KEYS.has(key):
			errors.append("%s: unknown frontmatter key '%s' -- check the spelling against content/README.md" % [name, key])
			return null

	for key in ["event_id", "title", "mile_start", "mile_end", "canonical_choice"]:
		if not meta.has(key):
			errors.append("%s: frontmatter is missing required key '%s'" % [name, key])
			return null

	card.event_id = StringName(meta["event_id"])
	if seen_ids.has(card.event_id):
		errors.append("%s: event_id '%s' is already used by %s -- ids must be unique" % [name, card.event_id, seen_ids[card.event_id]])
		return null
	seen_ids[card.event_id] = name

	card.title = meta.get("title", "")
	card.phase_id = StringName(meta.get("phase_id", ""))
	card.location_name = meta.get("location_name", "")
	card.mile_start = int(meta["mile_start"])
	card.mile_end = int(meta["mile_end"])
	card.historical_year_start = int(meta.get("historical_year_start", "0"))
	card.historical_year_end = int(meta.get("historical_year_end", "0"))
	card.is_fixed = meta.get("is_fixed", "false") == "true"
	card.weight = float(meta.get("weight", "1.0"))
	card.canonical_choice = int(meta["canonical_choice"])
	card.hazard_kind = StringName(meta.get("hazard_kind", ""))
	if not HAZARD_KINDS.has(String(card.hazard_kind)):
		errors.append("%s: hazard_kind '%s' must be empty, 'injury' or 'impatience'" % [name, card.hazard_kind])
		return null
	card.required_flags = _split(meta.get("required_flags", ""))
	card.blocked_by_flags = _split(meta.get("blocked_by_flags", ""))

	# --- body sections ---
	var section := ""
	var buffer: Array[String] = []
	var choices: Array[EventChoice] = []
	var choice: EventChoice = null

	while i <= lines.size():
		var raw: String = lines[i] if i < lines.size() else "## __END__"
		if raw.begins_with("## "):
			_flush(card, section, buffer, choice)
			if choice != null:
				choices.append(choice)
				choice = null
			buffer = []
			section = raw.substr(3).strip_edges()
			if section.begins_with("Choice:"):
				choice = EventChoice.new()
				choice.label = section.substr(7).strip_edges()
				if choice.label == "":
					errors.append("%s line %d: '## Choice:' needs a name after the colon" % [name, i + 1])
					return null
			elif section != "__END__" and not SECTION_NAMES.has(section):
				errors.append("%s line %d: unknown section '## %s' -- expected one of %s or '## Choice: <name>'" % [name, i + 1, section, str(SECTION_NAMES)])
				return null
		elif choice != null and _effect_line(raw):
			var colon := raw.find(":")
			var key := raw.substr(0, colon).strip_edges()
			var val := raw.substr(colon + 1).strip_edges()
			if key != "grants" and key != "repeat":
				if not val.is_valid_int():
					errors.append("%s line %d: '%s' needs a whole number, got '%s'" % [name, i + 1, key, val])
					return null
				if int(val) < DELTA_MIN or int(val) > DELTA_MAX:
					errors.append("%s line %d: '%s: %s' is outside the %d..%d range" % [name, i + 1, key, val, DELTA_MIN, DELTA_MAX])
					return null
			if key == "repeat" and val != "true" and val != "false":
				errors.append("%s line %d: 'repeat' must be true or false, got '%s'" % [name, i + 1, val])
				return null
			match key:
				"funds": choice.funds_delta = int(val)
				"support": choice.public_support_delta = int(val)
				"readiness": choice.water_readiness_delta = int(val)
				"crew": choice.crew_wellbeing_delta = int(val)
				"time": choice.time_delta_seasons = int(val)
				"grants": choice.granted_flags = _split(val)
				"repeat": choice.repeat_card = val == "true"
		else:
			# Inside a choice, a "word: value" line that NEARLY matches an effect
			# key is almost always a misspelling. Silently treating it as prose is
			# how "fund: -1" used to vanish into the outcome text.
			#
			# Deliberately narrow: it fires only on near-misses, not on any
			# "word:" line, so ordinary prose like "Verdict: the board refused"
			# stays legal. Historians write sentences; the check must not punish
			# them for it.
			if choice != null and raw.strip_edges() != "":
				var c := raw.find(":")
				if c > 0:
					var maybe := raw.substr(0, c).strip_edges()
					if maybe.length() < 20 and not maybe.contains(" ") and not EFFECT_KEYS.has(maybe):
						var near := _near_effect_key(maybe)
						if near != "":
							errors.append("%s line %d: '%s:' is not an effect name -- did you mean '%s:'?" % [name, i + 1, maybe, near])
							return null
			buffer.append(raw)
		i += 1

	if choices.is_empty():
		errors.append("%s: has no '## Choice: <name>' section" % name)
		return null
	if card.canonical_choice < 0 or card.canonical_choice >= choices.size():
		errors.append("%s: canonical_choice %d is out of range (%d choices)"
			% [name, card.canonical_choice, choices.size()])
		return null
	if card.event_description.strip_edges() == "":
		errors.append("%s: '## Description' section is empty" % name)
		return null
	if card.historical_fact.strip_edges() == "":
		errors.append("%s: '## Historical fact' is empty -- the teaching layer is required" % name)
		return null
	if card.assumption_note.strip_edges() == "":
		errors.append("%s: '## Assumption note' is empty -- every deviation must be recorded" % name)
		return null
	for flag in card.required_flags:
		required_flags[flag] = name
	for ch in choices:
		for flag in ch.granted_flags:
			granted_flags[flag] = true
	card.choices = choices
	return card


## True when the line is one of the choice effect keys, e.g. "funds: -1".
func _effect_line(line: String) -> bool:
	var colon := line.find(":")
	if colon < 0:
		return false
	return EFFECT_KEYS.has(line.substr(0, colon).strip_edges())


func _flush(card: EventCard, section: String, buffer: Array[String], choice: EventChoice) -> void:
	var text := "\n".join(buffer).strip_edges()
	match section:
		"Description": card.event_description = text
		"Historical fact": card.historical_fact = text
		"Source note": card.historical_source_note = text
		"Assumption note": card.assumption_note = text
		_:
			if choice != null:
				choice.outcome_text = text


func _split(csv: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for part in csv.split(","):
		var p := part.strip_edges()
		if p != "":
			out.append(StringName(p))
	return out


## The effect key a token was probably meant to be, or "" if it looks like
## ordinary prose. Matching on a shared three-letter stem catches "fund",
## "crews" and "suport" without firing on "Verdict" or "Note".
func _near_effect_key(token: String) -> String:
	var lower := token.to_lower()
	if lower.length() < 3:
		return ""
	for key in EFFECT_KEYS:
		if lower.substr(0, 3) == String(key).substr(0, 3):
			return key
	return ""
