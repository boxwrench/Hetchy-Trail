# Plan — Late-Viability Probe

**Status:** written, not implemented. Awaiting review before any code changes.

## The question

> **Can a rational, resource-safe policy complete the project after phase 34
> without overrun pressure?**

Overrun pressure is implemented and verified by `smoke_test`, but review
measurement found it unreached. Pressure cannot begin before **phase 35**:
`overrun_years()` requires both `phase > CALENDAR_PHASES + OVERRUN_GRACE_PHASES`
(34) and `current_year() >= 1935`, and `current_year()` does not return 1935
until phase 34 — so `OVERRUN_GRACE_PHASES` is only one of two gates and
lowering it to zero would change nothing. Meanwhile no probe strategy exceeds
**phase 32**:

```
historical / steady      avg phase 30.9 | max phase 32 | overran  0/12
critical path / steady   avg phase 30.9 | max phase 32 | overran  0/12
balanced / steady        avg phase 30.5 | max phase 31 | overran  0/12
bay first / steady       avg phase 31.8 | max phase 32 | overran  0/12
historical / all pushed  avg phase 13.7 | max phase 19 | overran  0/12
historical / all rest    avg phase 32.8 | max phase 35 | overran  6/12
```

Only *all rest* crosses, and it wins 0/12 — it is not slow-but-competent, it is
suicidal, dying of `bond_crisis` and `project_cancelled` well before schedule
could matter.

The probe has no row for the archetype the mechanic exists to punish: a player
who plays **safely** and therefore **slowly**. Every strategy resolves cards
with `card.canonical_choice`, hard-coded, so no strategy can trade schedule for
resources — the only lever that could plausibly push a surviving run past phase
34. Until we know whether such a run exists, tuning `OVERRUN_*` would be fitting
a number to an instrument that cannot observe the mechanic.

**This plan measures. It changes no game behaviour.** Every edit is confined to
`tools/balance_probe.gd`.

## Hard constraints

- **Never run `git add -A`.** Stage only the paths each task names.
- **Never edit `autoload/`, `resources/`, `scenes/`, `content/`, `data/events/`
  or `data/segments/`.** If a probe result seems to require a game change, that
  is the finding — report it, do not make the change.
- **Tune nothing.** No `OVERRUN_*`, economy, pace, card, or segment constant may
  change. Not to make a number look better, not to make a criterion pass.
- Five metrics only. No sixth resource, no new loss condition.
- No new dependencies. No new files except this plan's report output.
- A failing harness is never committed.

## GDScript trap

Property access on an autoload (`GameState`, `EventManager`) is typed `Variant`,
so `:=` cannot infer a type and the parser errors. Use an explicit type:

```gdscript
var phase_now: int = GameState.phase
```

## Stop and report — do not improvise — when

- A verification fails twice in a row after your best fix.
- A quoted "replace this" block does not match the file exactly.
- Output differs from what a step says to expect, even slightly.
- A step needs a decision this plan does not spell out.
- You are tempted to change a constant, a game file, or a success criterion.

## Baseline

Record this before touching anything. Task 1 must reproduce it byte-for-byte.

```
godot --headless res://tools/smoke_test.tscn     -> SMOKE PASS (354 checks)
godot --headless res://tools/sim_test.tscn       -> SIM PASS: system_complete, grade=matched_history
godot --headless res://tools/layout_test.tscn    -> LAYOUT PASS (265 checks)
```

```
BALANCE allocation / pace        wins      | grade a/m/b    | turns, hazards, end states
BALANCE historical / steady      win 12/12 | grade 11/ 1/ 0 | avg 21.2 turns |  2.2 haz/run | { &"system_complete": 12 }
BALANCE historical / push        win  6/12 | grade  5/ 1/ 0 | avg 19.3 turns |  2.8 haz/run | { &"system_complete": 6, &"bond_crisis": 6 }
BALANCE critical path / steady   win 12/12 | grade 11/ 1/ 0 | avg 21.2 turns |  2.2 haz/run | { &"system_complete": 12 }
BALANCE critical path / push     win  6/12 | grade  5/ 1/ 0 | avg 19.3 turns |  2.8 haz/run | { &"system_complete": 6, &"bond_crisis": 6 }
BALANCE balanced / steady        win 12/12 | grade 12/ 0/ 0 | avg 21.0 turns |  2.0 haz/run | { &"system_complete": 12 }
BALANCE balanced / push          win  8/12 | grade  7/ 1/ 0 | avg 19.1 turns |  2.8 haz/run | { &"bond_crisis": 4, &"system_complete": 8 }
BALANCE bay first / steady       win 12/12 | grade  2/10/ 0 | avg 22.0 turns |  2.1 haz/run | { &"system_complete": 12 }
BALANCE bay first / push         win  3/12 | grade  3/ 0/ 0 | avg 20.2 turns |  3.0 haz/run | { &"system_complete": 3, &"bond_crisis": 9 }
BALANCE historical / all pushed  win  0/12 | grade  0/ 0/ 0 | avg  9.3 turns |  4.2 haz/run | { &"bond_crisis": 4, &"work_halted": 8 }
BALANCE historical / all rest    win  0/12 | grade  0/ 0/ 0 | avg 31.8 turns | 13.4 haz/run | { &"unfinished": 4, &"bond_crisis": 6, &"project_cancelled": 2 }
BALANCE PROBE DONE
```

- [ ] **Step 0: Confirm all four.** If any differs, STOP and report before
  editing a file.

---

## Task 1 — An optional card-choice policy

`_run()` currently hard-codes `card.canonical_choice`, so choice is not a
strategy dimension. Make it one, **without changing any existing behaviour**.

- [ ] **Step 1: Widen the signature.** In `tools/balance_probe.gd`, replace:

```gdscript
func _run(label: String, picker: Callable, front_picker: Callable = Callable()) -> void:
```

with:

```gdscript
## choice_picker takes an EventCard and returns an index into card.choices.
## Omitted, every strategy resolves canonically exactly as before -- that
## default is what keeps the ten existing rows comparable across this change.
func _run(label: String, picker: Callable, front_picker: Callable = Callable(),
		choice_picker: Callable = Callable()) -> void:
```

- [ ] **Step 2: Use it at the one resolution site.** Replace:

```gdscript
				var card: EventCard = queue.pop_front()
				EventManager.resolve_choice(card, card.canonical_choice)
```

with:

```gdscript
				var card: EventCard = queue.pop_front()
				var choice_index: int = card.canonical_choice
				if choice_picker.is_valid():
					choice_index = choice_picker.call(card)
				EventManager.resolve_choice(card, choice_index)
```

Change nothing else in the loop. The followup-drain lines below stay as they
are.

- [ ] **Step 3: Verify the change is inert.** Run:

```bash
godot --headless res://tools/balance_probe.tscn
```

Expected: **byte-identical to the baseline block above**, all ten rows. No
strategy passes a `choice_picker` yet, so any difference at all means the edit
changed behaviour it should not have. If even one number moves, STOP and report.

- [ ] **Step 4: Confirm the suites.** `smoke_test`, `sim_test` and `layout_test`
  must be unchanged from Step 0. `sim_test` has its own resolve loop and this
  task does not touch it.

- [ ] **Step 5: Commit.**

```bash
git add tools/balance_probe.gd
```

Message:

```
test: balance probe can vary card choice, not only pace and allocation

Card resolution was hard-coded to canonical_choice, so no strategy could trade
schedule for resources -- the one lever that might carry a surviving run past
the phase where overrun pressure begins. _run() now takes an optional choice
policy, defaulting to canonical so the ten existing rows are unchanged.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

---

## Task 2 — Report phase, not only turns

Turns are not phases: cards add seasons, so a 21-turn run sits near phase 31.
Every conclusion about the 1934 milestone is about phases, and the probe does
not print any. Make these permanent columns, not scratch instrumentation.

- [ ] **Step 1: Add the pressure constant.** After `const MAX_TURNS := 34`, add:

```gdscript
## The first phase at which overrun pressure can apply. Both of its gates must
## open: phase > CALENDAR_PHASES + OVERRUN_GRACE_PHASES (34), and current_year()
## must reach 1935, which it does at phase 34. So 35.
##
## Hard-coded rather than read from GameState ON PURPOSE. This file has to run
## unchanged against commit 406c989, which predates the OVERRUN_* constants, or
## the A/B comparison is not a comparison. A probe that imports the mechanic it
## is measuring cannot be pointed at a build without it.
const PRESSURE_PHASE := 35
```

- [ ] **Step 2: Extend the tally.** Replace:

```gdscript
	var tally := {"wins": 0, "turns": 0, "hazards": 0, "ahead": 0, "matched": 0, "behind": 0}
```

with:

```gdscript
	var tally := {"wins": 0, "turns": 0, "hazards": 0, "ahead": 0, "matched": 0, "behind": 0,
		"phase": 0, "max_phase": 0, "late_wins": 0, "exposure": 0}
```

- [ ] **Step 3: Count exposure as the calendar moves.** Exposure is *phases
  spent under pressure*, which is not derivable from the final phase — a run
  that ends at 38 was exposed for four phases, one that ends at 35 for one.
  `_advance_calendar()` emits `turn_advanced` once per phase, including the
  phases `apply_choice()` inflicts, so the signal is the correct hook.

  Alongside the existing `counter` dictionary, add:

```gdscript
		var exposure := {"phases": 0}
		var on_phase := func(_y: int, p: int) -> void:
			if p >= PRESSURE_PHASE:
				exposure["phases"] += 1
		GameState.turn_advanced.connect(on_phase)
```

  Disconnect it beside the existing disconnects:

```gdscript
		GameState.turn_advanced.disconnect(on_phase)
```

  **Note the lambda-capture rule already recorded in this file:** GDScript
  lambdas capture locals by value, so the counter must be a Dictionary. A plain
  `int` silently stays at zero.

- [ ] **Step 4: Accumulate per seed.** Immediately before
  `var grade := GameState.completion_grade()`, add:

```gdscript
		var end_phase: int = GameState.phase
		tally["phase"] += end_phase
		tally["max_phase"] = maxi(int(tally["max_phase"]), end_phase)
		tally["exposure"] += exposure["phases"]
```

  And inside the existing `if result == &"system_complete":` block, add:

```gdscript
			if end_phase >= PRESSURE_PHASE:
				tally["late_wins"] += 1
```

- [ ] **Step 5: Print the new columns.** Replace:

```gdscript
	print("BALANCE %-24s win %2d/%d | grade %2d/%2d/%2d | avg %4.1f turns | %4.1f haz/run | %s"
		% [label, tally["wins"], SEEDS,
		tally["ahead"], tally["matched"], tally["behind"],
		float(tally["turns"]) / float(SEEDS),
		float(tally["hazards"]) / float(SEEDS), str(modes)])
```

with:

```gdscript
	print("BALANCE %-24s win %2d/%d | grade %2d/%2d/%2d | avg %4.1f turns | phase %4.1f avg %2d max | late wins %2d | exposure %3d | %4.1f haz/run | %s"
		% [label, tally["wins"], SEEDS,
		tally["ahead"], tally["matched"], tally["behind"],
		float(tally["turns"]) / float(SEEDS),
		float(tally["phase"]) / float(SEEDS), tally["max_phase"],
		tally["late_wins"], tally["exposure"],
		float(tally["hazards"]) / float(SEEDS), str(modes)])
```

  Update the header `print` in `_ready()` to match the new columns.

- [ ] **Step 6: Verify.** Run the probe. Every value that existed before must be
  unchanged — same wins, same grades, same avg turns, same hazards, same end
  states. The new columns must show `late wins 0` and `exposure 0` for all rows
  except *historical / all rest*, whose max phase is 35.

  If any pre-existing number moved, STOP and report. If *all rest* also shows
  `exposure 0`, `PRESSURE_PHASE` or the signal hook is wrong — STOP and report,
  do not adjust the constant to force a number.

- [ ] **Step 7: Commit.**

```bash
git add tools/balance_probe.gd
```

Message:

```
test: balance probe reports phase, late wins and overrun exposure

Turns are not phases -- cards add seasons, so a 21-turn run ends near phase 31 --
and every question about the 1934 milestone is a question about phases. The
probe printed none of them, which is why a mechanic no strategy could reach
looked like a mechanic that did nothing.

Exposure counts phases spent at or past PRESSURE_PHASE rather than inferring
from the final phase, because a run ending at 38 was under pressure four times
as long as one ending at 35.

PRESSURE_PHASE is hard-coded so this file runs unchanged against a build with no
OVERRUN_* constants. A probe that imports the mechanic it measures cannot be
pointed at a version without it.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

---

## Task 3 — A conservative choice policy

The policy under test: **protect resources, accept the schedule cost.** It must
be deterministic — same seed, same decisions, every run, at both commits.

- [ ] **Step 1: Add the policy.** Add at the end of `tools/balance_probe.gd`:

```gdscript
## Conservative card resolution: take the option that best protects the five
## metrics and accept whatever delay comes with it. This is the archetype the
## probe was missing -- a player who is competent but slow. Pace and allocation
## policies can only make a run slower by playing WORSE; this one can make a run
## slower by playing SAFER, which is the only way a surviving run plausibly
## reaches the phase where overrun pressure begins.
##
## Deterministic by construction: total ordering with an index tie-break, no
## randomness, so the same seed produces the same decisions at both commits.
##
## Time is not scored. Delay is neither sought nor avoided -- it is simply not
## a term, which is exactly what "accepts schedule delays to protect resources"
## means. Scoring time at all would make this a pace policy in disguise.
func _conservative_choice(card: EventCard) -> int:
	var best := -1
	var best_score := -999
	var fallback := -1
	var fallback_score := -999
	for i in card.choices.size():
		var choice: EventChoice = card.choices[i]
		# Never deliberately re-arm a card. Repeating is a schedule decision
		# dressed as a choice, and it would confound the measurement.
		if choice.repeat_card:
			continue
		var score: int = (choice.funds_delta + choice.public_support_delta
			+ choice.crew_wellbeing_delta)
		if score > fallback_score:
			fallback_score = score
			fallback = i
		# Reject anything that ends the game on the spot. funds is unclamped and
		# loses below zero; support and crew clamp at 0 and lose at 0.
		if GameState.funds + choice.funds_delta < 0:
			continue
		if GameState.public_support + choice.public_support_delta <= 0:
			continue
		if GameState.crew_wellbeing + choice.crew_wellbeing_delta <= 0:
			continue
		if score > best_score:
			best_score = score
			best = i
	if best >= 0:
		return best
	# Every survivable option was rejected, or every option repeats the card.
	# Take the least-bad rather than crashing; a cornered player still moves.
	if fallback >= 0:
		return fallback
	return card.canonical_choice
```

- [ ] **Step 2: Add three rows.** In `_ready()`, after the `bay` lambda, add:

```gdscript
	var careful := func(c: EventCard) -> int: return _conservative_choice(c)
```

  and after the `_run("bay first / push", ...)` line, before the degenerate
  baselines, add:

```gdscript
	# Slow but competent: the archetype the probe could not previously express.
	# Crossed with the two allocations most likely to survive, plus rest, which
	# is the slowest pace a player might defend as caution rather than folly.
	_run("careful / steady", steady, historical, careful)
	_run("careful / critical", steady, critical, careful)
	_run("careful / rest", rested, critical, careful)
```

- [ ] **Step 3: Verify.** Run the probe. The ten existing rows must be unchanged
  in every pre-existing column. Three new rows appear.

  **Do not judge the result here.** Whatever the new rows say, record them and
  move to Task 4. If they look disappointing, that is data, not a bug.

- [ ] **Step 4: Confirm the suites.** `smoke_test`, `sim_test`, `layout_test`
  unchanged from Step 0.

- [ ] **Step 5: Commit.**

```bash
git add tools/balance_probe.gd
```

Message:

```
test: a slow-but-competent strategy the probe could not previously express

Every existing strategy can only lose time by playing worse: pushing too hard,
allocating to the wrong front, resting into a hazard spiral. None can lose time
by playing SAFER, because card resolution was canonical for all of them. That
left the probe with no row for the archetype overrun pressure exists to price --
a player who protects the metrics and pays for it in schedule.

The policy scores the three deltas that can end a run and ignores time entirely,
rejects options that lose on the spot, and never re-arms a card. Deterministic
by index tie-break so the same seed decides the same way at both commits under
comparison.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

---

## Task 4 — The A/B measurement

Measurement only. **Nothing is committed in this task.**

The comparison is pinned to two commits:

| | Commit | State |
|---|---|---|
| **Pre-pressure** | `406c989` | overrun pressure not yet implemented |
| **Post-pressure** | `d9e5745` | pressure and HUD cue landed |

Identical seeds (`3000 + s`, 12 seeds) and identical policies at both, which is
what Task 2's hard-coded `PRESSURE_PHASE` exists to make possible.

- [ ] **Step 1: Run post-pressure.** In the main working tree (whose game code
  is `d9e5745` plus documentation-only commits), run the probe and save the
  output verbatim.

- [ ] **Step 2: Run pre-pressure.** Create a throwaway worktree, copy in **only
  the probe file**, and run it there:

```bash
git worktree add C:/tmp/hetchy-406c989 406c989
```

```bash
cp tools/balance_probe.gd C:/tmp/hetchy-406c989/tools/balance_probe.gd
```

  Then from `C:/tmp/hetchy-406c989`, run `godot --headless --import` once,
  followed by the probe. Save the output verbatim.

  Copy nothing else. Commit nothing in the worktree. If the probe fails to run
  there, it has taken a dependency on the mechanic it is measuring — STOP and
  report rather than patching it in place.

- [ ] **Step 3: Remove the worktree.**

```bash
git worktree remove C:/tmp/hetchy-406c989 --force
```

### The qualification criterion

A choice policy qualifies as **slow but competent** when, at `406c989`:

1. **At least 6 of 12 runs complete** (`system_complete`), and
2. **at least half of those wins finish at phase 35 or later.**

Both must hold. The first says the policy is competent — a policy that mostly
dies proves nothing about late viability. The second says it is genuinely slow —
wins that all land at phase 31 tell us nothing about a milestone at 34.

- [ ] **Step 4: Apply the criterion and take exactly one branch.**

**If no row qualifies — STOP and report:** *late-but-viable play is unreachable.*
Say which half of the criterion failed and by how much. Do **not** loosen the
criterion, add policies until one passes, or compensate by tuning pressure. The
honest finding is that the campaign cannot produce a surviving run past phase
34, which makes overrun pressure unreachable by construction rather than
mistuned — and that is a design question for the reviewer, not a constant to
adjust.

**If a row qualifies:** run that exact policy at `d9e5745` and report both
sides. The delta between them is the pressure mechanic's isolated effect —
every other variable is held fixed by identical seeds, identical policies and
an identical probe file. Report, for the qualifying policy at both commits:
wins, grade split, avg and max phase, late wins, exposure, and end-state
distribution.

- [ ] **Step 5: Report and stop.** Do not tune. Do not proceed to a further
  task. The reviewer decides what the delta means.

---

## Definition of done

- [ ] Three commits, all touching `tools/balance_probe.gd` only.
- [ ] All three suites green and unchanged from Step 0 throughout.
- [ ] The ten pre-existing `BALANCE` rows unchanged in every pre-existing column.
- [ ] A/B output from both commits reported verbatim.
- [ ] The qualification criterion applied as written, with one branch taken.
- [ ] No `OVERRUN_*`, economy, pace, card or segment constant changed.
- [ ] `autoload/`, `resources/`, `scenes/`, `content/`, `data/` untouched.
- [ ] No worktree left behind.
