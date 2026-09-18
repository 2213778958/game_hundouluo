extends SceneTree

## Thin host runner: load tests/arsenal/ only.


func _init() -> void:
	quit(_run_arsenal_only())


func _run_arsenal_only() -> int:
	var dir := DirAccess.open("res://tests/arsenal")
	if dir == null:
		push_error("tests/arsenal missing")
		return 1
	var failures: PackedStringArray = []
	var names: PackedStringArray = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.begins_with("test_") and fname.ends_with(".gd"):
			names.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	names.sort()
	for script_name in names:
		var script: Script = load("res://tests/arsenal/%s" % script_name)
		if script == null or not script.can_instantiate():
			failures.append("load failed: %s" % script_name)
			continue
		var inst: Object = script.new()
		if inst == null or not inst.has_method("run"):
			failures.append("%s has no run()" % script_name)
			continue
		var got: Variant = inst.call("run")
		if got is PackedStringArray:
			failures.append_array(got)
		else:
			failures.append("%s run() must return PackedStringArray" % script_name)
	if failures.is_empty():
		print("arsenal: all tests passed")
		return 0
	for msg in failures:
		printerr(msg)
	print("arsenal: %d failure(s)" % failures.size())
	return 1
