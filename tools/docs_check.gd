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
