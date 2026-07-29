extends Node
## Headless band verification for The Heading. Run:
##   godot --headless res://tools/minigame_sim.tscn      (exit 0 PASS, 1 FAIL)
##
## Asserts the five acceptance bands from
## docs/superpowers/specs/minigames/01-the-heading.md.
##
## IMPORTANT: this drives FIXED HEURISTIC POLICIES, not the exact-DP optimum. The
## figures recorded in the spec describe optimal play; a heuristic will not
## reproduce them, and asserting them here would build a tool that fails for the
## wrong reason and then gets "fixed" by loosening a band. Assert the BANDS.
##
## Band 1 is expected to pass and that pass means less than it looks: its intent
## was withdrawn on measurement, because Set supports makes voluntary banking
## dominated. The voluntary-bank rate is printed unconditionally so the number
## stays visible instead of hiding behind a green tick.

const HEADING := "res://scenes/minigames/the_heading/the_heading.tscn"
const TRIALS := 600
const TARGET := 803
const SURVEYED_S0 := 1
const UNSURVEYED_S0 := 3

var passed := 0
var failures: Array[String] = []
var module


func _ready() -> void:
	var packed: Resource = load(HEADING)
	if not (packed is PackedScene):
		print("MINIGAME SIM FAIL (1 failures)")
		print("  cannot load %s" % HEADING)
		get_tree().quit(1)
		return
	module = (packed as PackedScene).instantiate()
	add_child(module)

	_band1_no_dominant_stopping_round()
	_band2_not_a_coin_flip()
	_band3_supports_earn_their_place()
	_band4_bust_rate_in_band()
	_band5_survey_matters()
	_report_voluntary_bank()

	if failures.is_empty():
		print("MINIGAME SIM PASS (%d checks)" % passed)
	else:
		print("MINIGAME SIM FAIL (%d failures)" % failures.size())
		for f in failures:
			print("  " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _ok(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)


## Runs TRIALS shifts under `policy`, which is handed the module and returns the
## action StringName to take. Seeds are fixed so a run is reproducible.
func _run(policy: Callable, s0: int, stamina: int = 8) -> Dictionary:
	var out := {
		"feet": 0.0, "poor": 0, "fair": 0, "strong": 0,
		"hazard_shifts": 0, "wiped": 0, "banked": 0, "supports": 0,
	}
	for i in TRIALS:
		var cfg := MinigameConfig.new()
		cfg.minigame_id = &"the_heading"
		cfg.params = {"target_feet": TARGET, "stamina": stamina, "s0": s0,
			"geology": "jointed"}
		cfg.seed = 9001 + i * 7919
		module.open(cfg)
		var guard := 0
		while not module.over and guard < 64:
			guard += 1
			var action: StringName = policy.call(module)
			if action == &"supports":
				out["supports"] = int(out["supports"]) + 1
			if action == &"bank":
				out["banked"] = int(out["banked"]) + 1
			module.take(action)
		out["feet"] = float(out["feet"]) + minf(module.bank, float(TARGET))
		var tier: String = String(module.tier_for(module.bank))
		out[tier] = int(out[tier]) + 1
		if module.hazards > 0:
			out["hazard_shifts"] = int(out["hazard_shifts"]) + 1
		if module.wiped:
			out["wiped"] = int(out["wiped"]) + 1
	return out


# ── policies ────────────────────────────────────────────────────────────────

## Full rounds only, banking at a fixed round. Used for band 1.
func _stop_at_round(m, n: int) -> StringName:
	return &"bank" if m.rounds >= n else &"full"


## What a reasonable human does: ease the ground when it is strained, otherwise
## drive a full round, and stop once the target is in hand.
func _competent(m) -> StringName:
	if m.bank >= float(TARGET):
		return &"bank"
	if m.condition() == "strained" and m.stamina >= 2:
		return &"supports"
	return &"full"


## The same policy with the timber taken away, for band 3.
func _competent_no_supports(m) -> StringName:
	if m.bank >= float(TARGET):
		return &"bank"
	return &"full"


## Stop the moment `fair` is in hand. Band 4 is defined against this.
func _stop_at_fair(m) -> StringName:
	return &"bank" if m.bank >= m.fair_feet else &"full"


# ── bands ───────────────────────────────────────────────────────────────────

func _band1_no_dominant_stopping_round() -> void:
	var means: Array[float] = []
	var labels: Array[String] = []
	for n in [3, 4, 5, 6, 7, 8]:
		var r := _run(func(m): return _stop_at_round(m, n), SURVEYED_S0)
		means.append(float(r["feet"]) / float(TRIALS))
		labels.append("round %d" % n)
	var sorted := means.duplicate()
	sorted.sort()
	sorted.reverse()
	var best: float = sorted[0]
	var third: float = sorted[2]
	var spread: float = 0.0 if best <= 0.0 else (best - third) / best
	print("  band 1  fixed stopping rounds (mean credited ft):")
	for i in means.size():
		print("            %-9s %7.1f" % [labels[i], means[i]])
	print("            best three spread: %.2f%%" % (spread * 100.0))
	_ok(spread <= 0.15,
		"band 1: best three stopping rounds spread %.1f%% > 15%%" % (spread * 100.0))


func _band2_not_a_coin_flip() -> void:
	var r := _run(_competent, SURVEYED_S0)
	var p := 100.0 * float(r["poor"]) / float(TRIALS)
	var f := 100.0 * float(r["fair"]) / float(TRIALS)
	var s := 100.0 * float(r["strong"]) / float(TRIALS)
	print("  band 2  competent play: poor %.1f%%  fair %.1f%%  strong %.1f%%" % [p, f, s])
	_ok(p >= 10.0, "band 2: poor only %.1f%% (needs >= 10%%)" % p)
	_ok(f >= 10.0, "band 2: fair only %.1f%% (needs >= 10%%)" % f)
	_ok(s >= 10.0, "band 2: strong only %.1f%% (needs >= 10%%)" % s)


func _band3_supports_earn_their_place() -> void:
	var with_timber := _run(_competent, SURVEYED_S0)
	var without := _run(_competent_no_supports, SURVEYED_S0)
	var a := float(with_timber["feet"]) / float(TRIALS)
	var b := float(without["feet"]) / float(TRIALS)
	print("  band 3  with timber %.1f ft   without %.1f ft   (+%.1f)" % [a, b, a - b])
	_ok(a > b, "band 3: supports do not earn their place (%.1f vs %.1f ft)" % [a, b])


func _band4_bust_rate_in_band() -> void:
	var r := _run(_stop_at_fair, SURVEYED_S0)
	var rate := 100.0 * float(r["hazard_shifts"]) / float(TRIALS)
	print("  band 4  stop-at-fair hazard rate: %.1f%%  (band 20-45%%)" % rate)
	_ok(rate >= 20.0 and rate <= 45.0,
		"band 4: stop-at-fair hazard rate %.1f%% outside 20-45%%" % rate)


func _band5_survey_matters() -> void:
	var surveyed := _run(_competent, SURVEYED_S0)
	var blind := _run(_competent, UNSURVEYED_S0)
	var a := float(surveyed["feet"]) / float(TRIALS)
	var b := float(blind["feet"]) / float(TRIALS)
	print("  band 5  surveyed %.1f ft   unsurveyed %.1f ft   (+%.1f)" % [a, b, a - b])
	_ok(a > b, "band 5: the survey does not pay (%.1f vs %.1f ft)" % [a, b])


func _report_voluntary_bank() -> void:
	# Not a band. Band 1's pass is hollow without this context, but read the number
	# carefully: the heuristic banks at target because it is INSTRUCTED to, so a
	# high rate here is not evidence that stopping is ever correct. Under exact
	# backward induction the optimal policy banks 0.0% of the time, because Set
	# supports makes reducing the risk always cheaper than stopping. That is why
	# the press-your-luck claim was withdrawn. See finding 4 in the slot spec.
	var r := _run(_competent, SURVEYED_S0)
	var rate := 100.0 * float(r["banked"]) / float(TRIALS)
	print("  note    heuristic banked at target in %.1f%% of shifts -- it is told to." % rate)
	print("          Optimal play banks 0.0%: supports dominate stopping. Not a failure;")
	print("          the archetype claim was withdrawn rather than the numbers retuned.")
