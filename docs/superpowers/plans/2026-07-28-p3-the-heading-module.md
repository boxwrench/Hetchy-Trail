# Plan — P3: The Heading, the real module

**Executed by the reviewer, not a worker.** This plan records architecture
decisions and the verification contract. It deliberately does **not** inline the
module source: the code is written directly, because authoring it here and then
transcribing it would author it twice and add a failure mode without adding a
check.

## What is already true

- The contract exists and is verified: `MinigameConfig` in, `MinigameResult` out
  carrying **`score` and `tier` only** (`83e7a17`).
- `MinigameRegistry.BINDINGS` maps `the_803_foot_month` → `the_heading` with a
  tier→choice map, and `minigame_check` validates it (12 checks).
- `Journey` opens a minigame instead of the choice buttons when a card is bound,
  and falls back to the buttons on a malformed result.
- Every tuning input is measured and recorded in
  [01-the-heading.md](../specs/minigames/01-the-heading.md): constants, the
  stamina offset, pace→S₀, the arcade default, and the withdrawn genre claim.

What does not exist is the module. `Journey` hardcodes `minigame_stub.tscn`.

## Scope

**In:** the Heading module scene and script; a `minigame_id` → scene map so
`Journey` stops hardcoding; live campaign inputs (stamina, S₀) reaching the
config; `minigame_sim` band verification.

**Deferred, with reason:**

- **Arcade mode.** `scenes/main/` contains only `.gitkeep` and
  `run/main_scene` is `journey.tscn` — there is no title screen for an arcade
  entry to live on. The default config is decided and recorded; the entry point
  waits for a Main scene. Building a title screen inside a minigame plan would be
  scope creep into unrelated UI.
- **The survey.** Slot 2 (Probe the Face) is blocked on historian question H6.
  The module accepts `s0` and a `surveyed` flag from config, so slot 2 later
  changes a number rather than the module.

## Architecture decisions

**1. The module reads no game state.** Stamina and S₀ arrive in
`MinigameConfig.params`. `Journey` reads `GameState`; the module never does. This
is an inherited invariant and it is also what makes `minigame_sim` possible —
the module can be driven headlessly with synthetic configs.

**2. The scene path lives in the registry, not in `Journey`.** Add a
`SCENES: Dictionary` mapping `minigame_id` → `.tscn` path, and have `Journey`
instantiate by id with the stub as the fallback for any unmapped id. The stub is
kept, not deleted: it is the fallback for slots 2–5, which are unbuilt, and two
of them are blocked.

**3. Stamina and S₀ are computed in `Journey`, from the recorded rulings.**

```
stamina = clampi(GameState.crew_wellbeing + 1, 3, 10)
raw S₀  = { REST: 1, STEADY: 3, PUSHED: 8 }[GameState.work_pace]
applied = max(0, raw - 2) when surveyed, else raw
```

Nothing is surveyed yet, so `surveyed` is false until slot 2 exists. **Note the
consequence and do not "fix" it:** unsurveyed STEADY gives applied S₀ 3, not the
1 that every measurement in the spec used. That is correct — the measured 1 is
the *surveyed* case, and the survey does not exist yet. The bands must be checked
at the unsurveyed values too.

**4. Hazard prose comes from the hazard cards, loaded directly.** The three
`.tres` files in `data/events/` carry authored `outcome_text`. The module loads
them by path at init and displays the text on a bust. It does **not** apply the
card, grant its flags, or return its id — the campaign's own hazard roll is a
separate event at a different scale, and the result payload stays two fields.

**5. Geology is drawn from the config seed.** Equal weights across the three
mixes recorded in the spec. When slot 2 lands it will name the geology instead of
leaving it to the draw; that is a config change, not a module change.

**6. The result's `score` is credited footage, capped at `target_feet`.** The cap
is a recorded ruling. `tier` is computed from the *uncapped* bank against the
thresholds, which is the same thing at and above target and avoids a rounding
edge just below it.

## The verification contract

`minigame_sim` asserts the five bands from the spec. **It runs fixed heuristic
policies, not the exact-DP optimum** — so it must assert the *bands*, never the
DP figures recorded in the spec. Those figures describe optimal play; a heuristic
will not reproduce them, and writing them in as expected values would produce a
tool that fails for the wrong reason.

| Band | Assertion |
|---|---|
| 1 | Best three fixed stopping rounds within 15% on expected banked footage |
| 2 | Under the competent policy, each tier appears ≥10% of the time |
| 3 | A support-using policy beats an otherwise identical never-support policy |
| 4 | A "stop once fair is reached" policy busts 20–45% of shifts |
| 5 | A surveyed shift beats an unsurveyed one on expected footage |

Plus the standing requirement: **`sim_test` still completes with the minigame
skipped entirely.**

**Band 1 is expected to pass and that pass means less than it looks.** Its intent
was withdrawn on measurement — supports make voluntary banking dominated, so the
band is satisfied by a slot with no stopping decision. `minigame_sim` should
print the voluntary-bank rate alongside the band result so the number stays
visible rather than being hidden behind a green tick.

## Tasks

1. `scenes/minigames/the_heading/the_heading.gd` + `.tscn` — the module. Four
   actions plus Bank, stress, the bust roll, three hazards with the brace,
   stamina limit, 12-round cap, `finished(MinigameResult)`.
2. `MinigameRegistry.SCENES` + `scene_for(minigame_id)`, stub as fallback.
3. `Journey` — instantiate by id; add `stamina`, `s0`, `surveyed`, `seed` to the
   config it builds.
4. `tools/minigame_sim.gd` + `.tscn` — the five bands, plus the voluntary-bank
   rate printed unconditionally.
5. Extend `minigame_check` to assert every `SCENES` path exists and every
   `BINDINGS` `minigame_id` has a scene.

## Verification

```bash
godot --headless res://tools/minigame_sim.tscn
godot --headless res://tools/minigame_check.tscn
godot --headless res://tools/smoke_test.tscn
godot --headless res://tools/layout_test.tscn
godot --headless res://tools/sim_test.tscn
godot --headless res://tools/docs_check.tscn
```

Expected: `MINIGAME SIM PASS`, `MINIGAME PASS`, `SMOKE PASS (354 checks)`,
`LAYOUT PASS (265 checks)`, `grade=matched_history`, `DOCS PASS`. The smoke and
layout counts must not move — this adds a module, it changes no campaign rule.

Then the manual check the harness cannot make: launch the campaign, reach
**The 803-Foot Month**, play a shift, and confirm the tier selects the authored
choice and the consequence beat reads correctly.

## Stop and report if

- Any band cannot be satisfied. A design failure reported is cheap; a lowered
  band is not. Band 1's intent is already known to fail — that is recorded, not a
  new finding.
- `smoke_test`, `layout_test` or `sim_test` moves.
- The module needs to read `GameState`, return a sixth field, gate progress, or
  add a resource.
- Any change would touch `content/`, `data/events/` or `data/segments/`. The
  module *reads* the three hazard cards; it must not modify them.
