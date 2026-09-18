extends SceneTree

## Thin host runner: every tests/<module>/test_*.gd with run().


func _init() -> void:
	quit(_run_all())


func _run_all() -> int:
	var tests_dir := DirAccess.open("res://tests")
	if tests_dir == null:
		push_error("tests/ missing")
		return 1
	var failures: PackedStringArray = []
	var modules: PackedStringArray = []
	tests_dir.list_dir_begin()
	var entry := tests_dir.get_next()
	while entry != "":
		if tests_dir.current_is_dir() and not entry.begins_with("."):
			modules.append(entry)
		entry = tests_dir.get_next()
	tests_dir.list_dir_end()
	modules.sort()
	if modules.is_empty():
		push_error("no test modules under tests/")
		return 1
	for module_name in modules:
		failures.append_array(_run_module(module_name))
	if failures.is_empty():
		print("all modules passed: %s" % ", ".join(modules))
		return 0
	for msg in failures:
		printerr(msg)
	print("%d failure(s)" % failures.size())
	return 1


func _run_module(module_name: String) -> PackedStringArray:
	var failures: PackedStringArray = []
	var path := "res://tests/%s" % module_name
	var dir := DirAccess.open(path)
	if dir == null:
		failures.append("%s missing" % path)
		return failures
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
		var script: Script = load("%s/%s" % [path, script_name])
		if script == null or not script.can_instantiate():
			failures.append("load failed: %s/%s" % [module_name, script_name])
			continue
		var inst: Object = script.new()
		if inst == null or not inst.has_method("run"):
			failures.append("%s/%s has no run()" % [module_name, script_name])
			continue
		var got: Variant = inst.call("run")
		if got is PackedStringArray:
			failures.append_array(got)
		else:
			failures.append("%s/%s run() must return PackedStringArray" % [module_name, script_name])
	return failures
