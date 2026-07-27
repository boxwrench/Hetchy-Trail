extends Node
## GameState -- the single source of truth for Hetchy Trail.
## Owns the five core metrics, the calendar, the construction front, and the
## campaign flags. Emits signals when state changes; never touches UI.
##
## Metric model (per the historical mapping brief):
##   Funds/Bonds      int, starts at START_FUNDS, no cap. 1 point ~ one major
##                    appropriation. Below zero = bond crisis (loss).
##   Public Support   int 0-10. Zero = project cancelled (loss).
##   Water Readiness  int, accumulates toward READINESS_TARGET as structures
##                    complete. It represents system readiness and future
##                    capacity -- NOT delivered water. Nothing is delivered
##                    until every SYSTEM_FLAGS entry is true and the Pulgas
##                    card converts readiness into delivered water.
##   Crew Wellbeing   int 0-10. Zero = work halts (loss).
##   Time             two counters. `turn` counts player decisions against a
##                    TURNS_TOTAL budget. `phase` counts calendar time: one per
##                    turn, plus one per phase of card-inflicted delay. The year
##                    derives from `phase`, so delays -- not turns spent -- are
##                    what push the finish past October 1934.

signal funds_changed(value: int)
signal support_changed(value: int)
signal readiness_changed(value: int)
signal crew_changed(value: int)
signal miles_changed(value: float)
signal flag_granted(flag: StringName)
signal turn_advanced(year: int, phase: int)
signal game_ended(result: StringName)

enum Pace { REST, STEADY, PUSHED }

const TOTAL_MILES := 167.0
const START_YEAR := 1914
const HISTORICAL_FINISH_YEAR := 1934  # first water reached Pulgas October 24, 1934
const FINAL_DEADLINE_YEAR := 1940     # hard loss: the city turns elsewhere

## One turn is one construction phase, not a calendar season. Seasons survive
## only as narrative framing inside card prose -- the campaign does not simulate
## weather. Each affected card records this in its assumption_note.
##
## The player's turn budget: six divisions, four phases each. This is a
## session-length design target, not a rule -- the real constraint is
## FINAL_DEADLINE_YEAR, reached through accumulated delay.
const TURNS_TOTAL := 24
## Calendar phases consumed by canonical play. The year is derived from this,
## NOT from TURNS_TOTAL: card delays advance the calendar without granting a
## turn, so canonical play costs about 30 phases against 24 turns. Calibrated
## in Task 1b Step 7 so canonical play lands on HISTORICAL_FINISH_YEAR.
const CALENDAR_PHASES := 30
const YEARS_SPAN := HISTORICAL_FINISH_YEAR - START_YEAR   # 1914 -> 1934

# --- Tuning knobs -----------------------------------------------------------
const START_FUNDS := 30
const START_SUPPORT := 6
const START_CREW := 7
const METER_MAX := 10                 # cap for support and crew
const READINESS_TARGET := 30          # display scale for water readiness

## TUNING KNOB. Task 1 Step 10 adjusts STEADY only; PUSHED is always
## STEADY * 1.6, rounded to one decimal.
const MILES_PER_PHASE := {
	Pace.REST: 0.0,
	Pace.STEADY: 6.5,
	Pace.PUSHED: 10.4,
}
const PUSHED_CREW_DRIFT := -1         # crew change per pushed phase
const REST_CREW_DRIFT := 1            # crew change per rest phase
const PHASE_OVERHEAD := 1             # funds spent every phase
const PUMPING_SURCHARGE := 1          # extra per-phase cost if pumps were chosen
## Sierra divisions build at this fraction until the railroad is operational.
## Division-scoped, not calendar-scoped -- it is what makes the railroad worth
## building now that the game no longer tracks winter.
const NO_RAILROAD_FACTOR := 0.4

const BOND_MIN_SUPPORT := 4           # support needed to issue a bond
## A campaign authorizes two major bond measures, echoing the 1910 and 1928
## issues -- large and rare, not an unlimited supply of small ones. This is
## what funds a 24-phase campaign against -34 funds of canonical card costs
## and -24 of phase overhead.
const BOND_FUNDS_GAIN := 20
const BOND_SUPPORT_COST := 1
const MAX_BOND_ISSUES := 2
const OUTREACH_FUNDS_COST := 1
const OUTREACH_SUPPORT_GAIN := 2
const CAMP_FUNDS_COST := 1
const CAMP_CREW_GAIN := 2
# ----------------------------------------------------------------------------

## Delivered Hetch Hetchy water requires every one of these flags -- each
## granted by a fixed historical card. Individual structures may be complete,
## but the city receives nothing until the whole chain works as one system.
const SYSTEM_FLAGS: Array[StringName] = [
	&"dam_complete",
	&"mountain_tunnel_complete",
	&"foothill_tunnel_complete",
	&"san_joaquin_pipeline_complete",
	&"coast_range_tunnel_complete",
	&"alameda_siphon_complete",
	&"bay_crossing_complete",
	&"pulgas_connected",
]

const SEGMENTS_DIR := "res://data/segments"

var funds: int = START_FUNDS
var public_support: int = START_SUPPORT
var water_readiness: int = 0
var crew_wellbeing: int = START_CREW
var miles_built: float = 0.0
var phase: int = 0                    # calendar time: turns + card delays
var turn: int = 0                     # player decisions taken
var work_pace: int = Pace.STEADY
var flags: Dictionary = {}            # StringName -> true
var bonds_issued: int = 0
var game_over: bool = false

var segments: Array[RouteSegment] = []


func _ready() -> void:
	_load_segments()
	new_game()


func new_game() -> void:
	funds = START_FUNDS
	public_support = START_SUPPORT
	water_readiness = 0
	crew_wellbeing = START_CREW
	miles_built = 0.0
	phase = 0
	turn = 0
	work_pace = Pace.STEADY
	flags = {}
	bonds_issued = 0
	game_over = false
	_emit_all()


## Advances one phase: build, crew drift, phase overhead, calendar, end check.
## Called once per turn by Journey, after the player's decisions are applied.
func advance_turn() -> void:
	if game_over:
		return
	turn += 1
	_build_miles(1)
	match work_pace:
		Pace.PUSHED:
			_set_crew(crew_wellbeing + PUSHED_CREW_DRIFT)
		Pace.REST:
			_set_crew(crew_wellbeing + REST_CREW_DRIFT)
	_advance_calendar()
	_check_end_conditions()


## Applies one optional per-turn action from the DecisionPanel.
## Returns false when the action is not currently affordable/allowed.
func take_action(action: StringName) -> bool:
	if game_over:
		return false
	match action:
		&"issue_bond":
			if public_support < BOND_MIN_SUPPORT:
				return false
			if bonds_issued >= MAX_BOND_ISSUES:
				return false
			bonds_issued += 1
			_set_funds(funds + BOND_FUNDS_GAIN)
			_set_support(public_support - BOND_SUPPORT_COST)
		&"outreach":
			if funds < OUTREACH_FUNDS_COST:
				return false
			_set_funds(funds - OUTREACH_FUNDS_COST)
			_set_support(public_support + OUTREACH_SUPPORT_GAIN)
		&"improve_camp":
			if funds < CAMP_FUNDS_COST:
				return false
			_set_funds(funds - CAMP_FUNDS_COST)
			_set_crew(crew_wellbeing + CAMP_CREW_GAIN)
		_:
			return false
	_check_end_conditions()
	return true


## Applies a resolved EventChoice from a card.
func apply_choice(choice: EventChoice) -> void:
	if game_over:
		return
	_set_funds(funds + choice.funds_delta)
	_set_support(public_support + choice.public_support_delta)
	_set_readiness(water_readiness + choice.water_readiness_delta)
	_set_crew(crew_wellbeing + choice.crew_wellbeing_delta)
	for flag in choice.granted_flags:
		grant_flag(flag)
	# Positive time deltas are lost phases: the calendar advances with
	# overhead but no construction. Negative deltas are schedule gains,
	# banked as immediate bonus mileage at the steady rate.
	if choice.time_delta_seasons > 0:
		for i in choice.time_delta_seasons:
			_advance_calendar()
	elif choice.time_delta_seasons < 0:
		_build_miles(-choice.time_delta_seasons)
	_check_end_conditions()


func grant_flag(flag: StringName) -> void:
	if flags.has(flag):
		return
	flags[flag] = true
	flag_granted.emit(flag)


func has_flag(flag: StringName) -> bool:
	return flags.has(flag)


func is_system_connected() -> bool:
	for flag in SYSTEM_FLAGS:
		if not flags.has(flag):
			return false
	return true


func current_segment() -> RouteSegment:
	for segment in segments:
		if segment.contains(miles_built):
			return segment
	return segments.back() if not segments.is_empty() else null


## Display year derived from the phase counter: 24 phases span 1914-1934.
## Overrunning the campaign keeps advancing the year toward FINAL_DEADLINE_YEAR.
func current_year() -> int:
	return START_YEAR + int(floor(float(phase) * float(YEARS_SPAN) / float(CALENDAR_PHASES)))


## Turns left in the budget. Negative once the player overruns it; this is a
## pacing signal, not a loss condition -- the deadline is a year.
func turns_remaining() -> int:
	return TURNS_TOTAL - turn


## Win-screen grade against the historical finish of October 1934.
func completion_grade() -> String:
	var y := current_year()
	if y < HISTORICAL_FINISH_YEAR:
		return "ahead_of_history"
	if y == HISTORICAL_FINISH_YEAR:
		return "matched_history"
	return "behind_history"


# --- internals ---------------------------------------------------------------

func _build_miles(phase_count: int) -> void:
	var segment := current_segment()
	if segment == null:
		return
	var rate: float = MILES_PER_PHASE[work_pace] * segment.build_rate_modifier
	rate *= _crew_factor()
	if segment.winter_sensitive and not has_flag(&"railroad_operational"):
		rate *= NO_RAILROAD_FACTOR
	miles_built = minf(miles_built + rate * phase_count, TOTAL_MILES)
	miles_changed.emit(miles_built)


func _crew_factor() -> float:
	# Crew 7 (start) ~ 1.0; a depleted crew halves progress, a thriving one helps.
	return clampf(0.5 + 0.07 * crew_wellbeing, 0.5, 1.2)


func _advance_calendar() -> void:
	phase += 1
	var overhead := PHASE_OVERHEAD
	if has_flag(&"pumped_alternative_chosen"):
		overhead += PUMPING_SURCHARGE
	_set_funds(funds - overhead)
	turn_advanced.emit(current_year(), phase)


func _check_end_conditions() -> void:
	if game_over:
		return
	if has_flag(&"hetch_hetchy_water_delivered"):
		_end_game(&"system_complete")
	elif funds < 0:
		_end_game(&"bond_crisis")
	elif public_support <= 0:
		_end_game(&"project_cancelled")
	elif crew_wellbeing <= 0:
		_end_game(&"work_halted")
	elif current_year() > FINAL_DEADLINE_YEAR:
		_end_game(&"city_moves_on")


func _end_game(result: StringName) -> void:
	game_over = true
	game_ended.emit(result)


func _set_funds(value: int) -> void:
	funds = value
	funds_changed.emit(funds)


func _set_support(value: int) -> void:
	public_support = clampi(value, 0, METER_MAX)
	support_changed.emit(public_support)


func _set_crew(value: int) -> void:
	crew_wellbeing = clampi(value, 0, METER_MAX)
	crew_changed.emit(crew_wellbeing)


func _set_readiness(value: int) -> void:
	water_readiness = maxi(value, 0)
	readiness_changed.emit(water_readiness)


func _emit_all() -> void:
	funds_changed.emit(funds)
	support_changed.emit(public_support)
	readiness_changed.emit(water_readiness)
	crew_changed.emit(crew_wellbeing)
	miles_changed.emit(miles_built)
	turn_advanced.emit(current_year(), phase)


func _load_segments() -> void:
	segments.clear()
	var dir := DirAccess.open(SEGMENTS_DIR)
	if dir == null:
		push_warning("GameState: no segments directory at %s" % SEGMENTS_DIR)
		return
	var files := dir.get_files()
	files.sort()
	for file in files:
		# Exported builds list .tres files as .tres.remap; load() resolves both.
		if file.ends_with(".tres") or file.ends_with(".tres.remap"):
			var res := load(SEGMENTS_DIR + "/" + file.trim_suffix(".remap"))
			if res is RouteSegment:
				segments.append(res)
	segments.sort_custom(func(a, b): return a.start_mile < b.start_mile)
