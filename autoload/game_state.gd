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
## turn, so canonical play costs about 32 phases against 24 turns. Calibrated
## so canonical play lands on HISTORICAL_FINISH_YEAR; recalibrated in Batch B
## Session 3, when two-card chaining shortened canonical play from 35 phases to
## 32 and left it finishing in 1932.
##
## At 20 years over ~32 phases the matched-history band is under two phases
## wide, so this cannot be centred: canonical play sits at the top of the band
## and ANY change that shortens the campaign needs this recalibrated with it.
const CALENDAR_PHASES := 32
const YEARS_SPAN := HISTORICAL_FINISH_YEAR - START_YEAR   # 1914 -> 1934

# --- Tuning knobs -----------------------------------------------------------
const START_FUNDS := 30
const START_SUPPORT := 6
const START_CREW := 7
const METER_MAX := 10                 # cap for support and crew
const READINESS_TARGET := 30          # display scale for water readiness

const PUSHED_CREW_DRIFT := -1         # crew change per pushed phase
const REST_CREW_DRIFT := 1            # crew change per rest phase
const PHASE_OVERHEAD := 1             # funds spent every phase
const PUMPING_SURCHARGE := 1          # extra per-phase cost if pumps were chosen
## October 1934 is a binding milestone, not a cliff and not merely a score.
## Passing it begins pressure that arrives at the EXISTING loss conditions on
## its own -- no new loss condition, and no sixth resource.
##
## Grace first: canonical play lands on CALENDAR_PHASES exactly, so without a
## buffer any slippage at all would punish a correctly-paced run.
const OVERRUN_GRACE_PHASES := 2
## Extra funds of phase overhead per year past HISTORICAL_FINISH_YEAR. Linear
## and legible on purpose -- the player should be able to read the HUD and say
## "this is costing me two funds a phase".
const OVERRUN_FUNDS_PER_YEAR := 1
## While overrunning, public support slips by one every this many phases.
const OVERRUN_SUPPORT_INTERVAL := 3
## Fronts beyond the railhead build slower until the railroad runs. Kept mild:
## railroad_operational comes from a weighted texture card that may never be
## drawn, so this must be an incentive, not a trap.
const NO_RAILROAD_FACTOR := 0.7

## TUNING KNOB (Task 1 Step 9). Progress a front gains in one STEADY turn
## before its build_rate_modifier and crew factor apply. Six fronts across a
## 24-turn budget means roughly four turns each.
const FRONT_BASE_PROGRESS := 0.45
const PACE_FACTOR := {
	Pace.REST: 0.0,
	Pace.STEADY: 1.0,
	Pace.PUSHED: 1.6,
}
## Fronts 2 and 3 wait on power earlier fronts provide. Fronts 4, 5 and 6 are
## deliberately ungated: historically they were gated by money and political
## priority, not permission, which the funds and turn budget already model.
const FRONT_REQUIRES := {
	1: &"construction_power_available",
	2: &"moccasin_power_available",
}

const BOND_MIN_SUPPORT := 4           # support needed to issue a bond
## A campaign authorizes two major bond measures, echoing the 1910 and 1928
## issues -- large and rare, not an unlimited supply of small ones. This is
## what funds a 24-phase campaign against -34 funds of canonical card costs
## and -24 of phase overhead.
const BOND_FUNDS_GAIN := 18
const BOND_SUPPORT_COST := 1
const MAX_BOND_ISSUES := 2
const OUTREACH_FUNDS_COST := 1
const OUTREACH_SUPPORT_GAIN := 2
const CAMP_FUNDS_COST := 1
const CAMP_CREW_GAIN := 2
## Each use of a repeatable action raises the price of the next use of that
## same action, so topping up a meter is a decision rather than bookkeeping.
const ACTION_COST_ESCALATION := 1
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
var miles_built: float = 0.0          # derived aggregate; see _recompute_miles()
var front_progress: Array[float] = [] # 0.0-1.0 per segment, parallel to segments
var current_front: int = 0            # the front the player works this turn
var phase: int = 0                    # calendar time: turns + card delays
var turn: int = 0                     # player decisions taken
var work_pace: int = Pace.STEADY
var flags: Dictionary = {}            # StringName -> true
var bonds_issued: int = 0
var action_uses: Dictionary = {}      # StringName -> int
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
	front_progress.clear()
	for i in segments.size():
		front_progress.append(0.0)
	current_front = 0
	phase = 0
	turn = 0
	work_pace = Pace.STEADY
	flags = {}
	bonds_issued = 0
	action_uses = {}
	game_over = false
	_emit_all()


func front_count() -> int:
	return segments.size()


## A front is workable once the flag that opens it has been granted. Fronts
## without an entry in FRONT_REQUIRES are open from turn one.
func front_is_open(index: int) -> bool:
	if index < 0 or index >= segments.size():
		return false
	if not FRONT_REQUIRES.has(index):
		return true
	return has_flag(FRONT_REQUIRES[index])


## Chooses the front to work this turn. Returns false when the front is closed
## or out of range, so the caller can refuse the input.
func set_front(index: int) -> bool:
	if game_over or not front_is_open(index):
		return false
	current_front = index
	return true


## Every front finished. Not the win condition -- that stays SYSTEM_FLAGS.
func all_fronts_complete() -> bool:
	for p in front_progress:
		if p < 1.0:
			return false
	return true


## Advances one phase: build, crew drift, phase overhead, calendar, end check.
## Called once per turn by Journey, after the player's decisions are applied.
func advance_turn() -> void:
	if game_over:
		return
	turn += 1
	_work_front(1)
	match work_pace:
		Pace.PUSHED:
			_set_crew(crew_wellbeing + PUSHED_CREW_DRIFT)
		Pace.REST:
			_set_crew(crew_wellbeing + REST_CREW_DRIFT)
	_advance_calendar()
	_check_end_conditions()


## Current funds price of a repeatable action, rising with each prior use.
## issue_bond is not priced in funds -- it is gated by MAX_BOND_ISSUES.
func action_cost(action: StringName) -> int:
	var uses: int = action_uses.get(action, 0)
	match action:
		&"outreach":
			return OUTREACH_FUNDS_COST + uses * ACTION_COST_ESCALATION
		&"improve_camp":
			return CAMP_FUNDS_COST + uses * ACTION_COST_ESCALATION
		_:
			return 0


## Whether the action is currently allowed. The DecisionPanel renders from this
## so affordability rules live in one place.
func can_take_action(action: StringName) -> bool:
	if game_over:
		return false
	match action:
		&"issue_bond":
			return bonds_issued < MAX_BOND_ISSUES and public_support >= BOND_MIN_SUPPORT
		&"outreach", &"improve_camp":
			return funds >= action_cost(action)
		_:
			return false


## Applies one optional per-turn action from the DecisionPanel.
## Returns false when the action is not currently affordable/allowed.
func take_action(action: StringName) -> bool:
	if not can_take_action(action):
		return false
	var cost := action_cost(action)
	match action:
		&"issue_bond":
			bonds_issued += 1
			_set_funds(funds + BOND_FUNDS_GAIN)
			_set_support(public_support - BOND_SUPPORT_COST)
		&"outreach":
			_set_funds(funds - cost)
			_set_support(public_support + OUTREACH_SUPPORT_GAIN)
		&"improve_camp":
			_set_funds(funds - cost)
			_set_crew(crew_wellbeing + CAMP_CREW_GAIN)
		_:
			return false
	action_uses[action] = int(action_uses.get(action, 0)) + 1
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
		_work_front(-choice.time_delta_seasons)
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


## Years past October 1934, after the grace phases. Zero while on schedule.
## The single source of overrun pressure: both the funds and support terms read
## it, and the HUD displays it, so there is one definition to reason about.
func overrun_years() -> int:
	if phase <= CALENDAR_PHASES + OVERRUN_GRACE_PHASES:
		return 0
	return maxi(0, current_year() - HISTORICAL_FINISH_YEAR)


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

## Advances the front the player chose this turn. Only that front moves.
func _work_front(phase_count: int) -> void:
	if current_front < 0 or current_front >= segments.size():
		return
	if not front_is_open(current_front):
		return
	var segment := segments[current_front]
	var gain: float = FRONT_BASE_PROGRESS * float(PACE_FACTOR[work_pace])
	gain *= segment.build_rate_modifier
	gain *= _crew_factor()
	# Front 0 is the railhead itself; only fronts beyond it wait on the line.
	if current_front > 0 and segment.winter_sensitive and not has_flag(&"railroad_operational"):
		gain *= NO_RAILROAD_FACTOR
	front_progress[current_front] = minf(
		front_progress[current_front] + gain * float(phase_count), 1.0)
	_recompute_miles()


## miles_built is the length-weighted sum of front progress -- an honest
## aggregate of what has been built, not an independent counter.
func _recompute_miles() -> void:
	var total := 0.0
	for i in segments.size():
		var seg := segments[i]
		total += front_progress[i] * float(seg.end_mile - seg.start_mile)
	miles_built = minf(total, TOTAL_MILES)
	miles_changed.emit(miles_built)


func _crew_factor() -> float:
	# Crew 7 (start) ~ 1.0; a depleted crew halves progress, a thriving one helps.
	return clampf(0.5 + 0.07 * crew_wellbeing, 0.5, 1.2)


func _advance_calendar() -> void:
	phase += 1
	var overhead := PHASE_OVERHEAD
	if has_flag(&"pumped_alternative_chosen"):
		overhead += PUMPING_SURCHARGE
	# Overrun pressure rides on the CALENDAR, not on turns. apply_choice() calls
	# this once per phase of card-inflicted delay, so a card that costs two
	# phases is priced exactly like two slow turns -- one code path, no drift.
	var overrun := overrun_years()
	overhead += overrun * OVERRUN_FUNDS_PER_YEAR
	_set_funds(funds - overhead)
	if overrun > 0 and phase % OVERRUN_SUPPORT_INTERVAL == 0:
		_set_support(public_support - 1)
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
