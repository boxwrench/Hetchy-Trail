# Plan — Documentation reference check

**For the worker model.** Every step is explicit. No step requires a design
decision. If one appears to, stop and report.

## Why this exists

`ROADMAP.md` states the project's central documentation hazard plainly:

> Worker agents read docs as instruction, so a stale document actively causes
> deleted concepts to be restored.

The harness protects code and data — `smoke_test` runs 354 checks, `layout_test`
265. **Nothing checks the documentation**, and `docs/` now contains 28 Markdown
files with 120 relative links between them, into `content/cards/`, into
`data/events/`, and into each other.

A link that rots points a future worker at a file that is not there. A worker
that cannot find a referenced file does not stop — it invents the contents. This
tool closes that gap.

It is deliberately unrelated to the minigame work in flight, touches no game
code, and cannot change anything the player sees.

## Success criteria

1. `godot --headless res://tools/docs_check.tscn` exits 0 and prints `DOCS PASS`.
2. Introducing a broken link makes it exit 1 and name the offending file.
3. `smoke_test` and `layout_test` still pass, unchanged.

---

## Task 1 — Create the checker script

- [ ] Create `tools/docs_check.gd` with exactly this content:

```gdscript
extends Node
## Headless documentation reference check. Walks every Markdown file in docs/
## and the repository root, and asserts that every relative link resolves to a
## file or directory that actually exists.
##
## Why this exists: docs in this repo are read by agents as instruction. A link
## that rots points a future worker at a file that is not there, and a worker
## that cannot find a referenced file will invent its contents rather than stop.
##
## Run:  godot --headless res://tools/docs_check.tscn   (exit 0 PASS, 1 FAIL)

const SCAN_DIRS: Array[String] = ["res://docs"]

var checked := 0
var failures: Array[String] = []
var _fence := RegEx.new()
var _span := RegEx.new()
var _link := RegEx.new()


func _ready() -> void:
	# Fenced blocks and inline code spans are stripped before matching, because
	# GDScript samples in these docs contain bracket-paren sequences that look
	# exactly like Markdown links -- Array[StringName]([&"flag"]) is one.
	_fence.compile("```[\\s\\S]*?```")
	_span.compile("`[^`\\n]*`")
	_link.compile("\\[[^\\]\\n]*\\]\\(([^)\\s]+)\\)")
	for f in _root_markdown():
		_check_file(f)
	for dir in SCAN_DIRS:
		_walk(dir)
	if failures.is_empty():
		print("DOCS PASS (%d links checked)" % checked)
	else:
		print("DOCS FAIL (%d broken)" % failures.size())
		for f in failures:
			print("  " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _root_markdown() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open("res://")
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".md"):
			out.append("res://" + f)
	return out


func _walk(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".md"):
			_check_file(path.path_join(f))
	for sub in d.get_directories():
		_walk(path.path_join(sub))


func _check_file(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return
	text = _fence.sub(text, "", true)
	text = _span.sub(text, "", true)
	var base_dir := path.get_base_dir()
	for m in _link.search_all(text):
		var target := m.get_string(1)
		if target.begins_with("http://") or target.begins_with("https://"):
			continue
		if target.begins_with("#") or target.begins_with("mailto:"):
			continue
		checked += 1
		var rel := target.split("#")[0].uri_decode()
		if rel.is_empty():
			continue
		var resolved := base_dir.path_join(rel).simplify_path()
		if FileAccess.file_exists(resolved):
			continue
		if DirAccess.dir_exists_absolute(resolved):
			continue
		failures.append("%s -> %s (resolved to %s)" % [path, target, resolved])
		push_error("DOCS FAIL: %s -> %s" % [path, target])
```

- [ ] Create `tools/docs_check.tscn` with exactly this content:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tools/docs_check.gd" id="1"]

[node name="DocsCheck" type="Node"]
script = ExtResource("1")
```

**Do not create a `.uid` file.** Godot generates it on import.

### Notes on the code, so you do not "fix" it

- **Directory links are legal.** `FOLLOW-UPS.md` links to
  `superpowers/specs/minigames/`, a directory. That is why both
  `FileAccess.file_exists` and `DirAccess.dir_exists_absolute` are checked.
  Removing either check will produce a false failure.
- **The code-stripping is not optional.** Without it, the GDScript sample
  containing `Array[StringName]([&"flag"])` in the minigame spec is matched as a
  Markdown link and reported broken. That exact false positive has already been
  investigated once by hand.
- **`uri_decode()` handles `%20`** in link targets. Leave it in even though no
  current link needs it.

## Task 2 — Verify it passes on the current tree

- [ ] Run:

```bash
godot --headless res://tools/docs_check.tscn
```

**Expected:** a line reading `DOCS PASS (120 links checked)` and exit code 0.

The count was 120 when this plan was last verified against the tree, and the
tree was confirmed to have **zero broken links** at that moment. **If the count
differs but the line still says `DOCS PASS`, that is fine** — docs change, and
the count is informational. The word `PASS` is the gate.

**If it says `DOCS FAIL`, stop and report.** Do not fix the links and do not
adjust the checker. A genuine broken link found on the first run is a real
finding and needs a reviewer, not a patch.

## Task 3 — Prove it actually fails

A checker that has never failed is not known to work.

- [ ] Create a temporary file `docs/_break_test.md` containing exactly:

```markdown
# Temporary

[this file does not exist](does-not-exist-xyz.md)
[neither does this one](../content/cards/99_not_a_card.md)
```

- [ ] Run the checker again.

**Expected:** exit code 1, a line reading `DOCS FAIL (2 broken)`, and two
indented lines below it, both beginning `res://docs/_break_test.md ->`.

The second case matters more than the first: it proves the tool catches a broken
link **out of `docs/` and into `content/`**, which is the drift the roadmap
warns about.

- [ ] Delete `docs/_break_test.md`.
- [ ] Run the checker once more and confirm it prints `DOCS PASS` again.

**If either failure was not detected, stop and report.** Do not proceed to
commit a checker that does not catch a broken link.

## Task 4 — Confirm nothing else moved

- [ ] Run both existing harness tools:

```bash
godot --headless res://tools/smoke_test.tscn
```

**Expected:** `SMOKE PASS (354 checks)`, exit 0.

```bash
godot --headless res://tools/layout_test.tscn
```

**Expected:** `LAYOUT PASS (265 checks)`, exit 0.

Both must be unchanged. This task adds a tool; it does not touch game code, and
any movement in these numbers means something unintended happened.

## Task 5 — Document and commit

- [ ] In `docs/ROADMAP.md`, in the **Verification harness** section, add the new
      tool after the `sim_test` block and before the `balance_probe` block:

```bash
godot --headless res://tools/docs_check.tscn
```

      followed by this paragraph:

> Checks that every relative link in `docs/` and the repository root resolves.
> Exits 0 or 1 like the other two. Docs are read by agents as instruction here,
> so a rotted cross-reference is a real defect, not cosmetic.

- [ ] Confirm `docs/_break_test.md` is gone:

```bash
git status --short
```

**Expected:** your three new entries — `?? tools/docs_check.gd`,
`?? tools/docs_check.tscn`, and ` M docs/ROADMAP.md` — plus
`?? tools/docs_check.gd.uid` if Godot generated one, which is expected and
should be committed.

**These four untracked paths already existed before you started. Leave every one
of them alone — do not stage them, do not delete them, do not edit them:**

```
?? docs/superpowers/plans/2026-07-28-docs-reference-check.md
?? docs/superpowers/plans/2026-07-28-p2-minigame-framework.md
?? docs/superpowers/specs/minigames/RESEARCH-PROMPTS.md
?? tools/balance_probe.gd.uid
```

**If `docs/_break_test.md` appears in that list, delete it before continuing.**

- [ ] Stage **only these paths by name**. Do not use `git add -A` or `git add .`
      under any circumstances:

```bash
git add tools/docs_check.gd tools/docs_check.tscn tools/docs_check.gd.uid docs/ROADMAP.md
```

(If no `.uid` file was generated, omit it from that command rather than creating one.)

- [ ] Commit with exactly this message:

```
tools: check that documentation links resolve

Docs in this repo are read by agents as instruction, so a rotted
cross-reference points a future worker at a file that is not there -- and a
worker that cannot find a referenced file invents its contents rather than
stopping. The harness covered code and data and nothing covered the 120
relative links across 28 Markdown files.

Fenced blocks and inline code spans are stripped before matching, because
GDScript samples in these docs contain bracket-paren sequences that parse as
Markdown links. Directory targets are accepted, because at least one link
points at a directory.

Verified by deliberate breakage: two bad links, one of them from docs/ into
content/, are both detected and named. SMOKE 354, LAYOUT 265 unchanged.
```

- [ ] Tick the boxes above for what you actually verified, and stop. Do not
      begin any other work.

---

## Stop immediately and report if

- The first run of the checker reports a broken link.
- The deliberate-breakage test does not produce exactly two failures.
- `smoke_test` or `layout_test` reports a different number than stated above.
- You are tempted to change the regular expressions, relax a check, or delete a
  link from a document to make the checker pass.

Never weaken a check to make the harness green. A failing check is a finding.
