extends RefCounted


func run() -> PackedStringArray:
	var failures: PackedStringArray = []
	_project_is_pixel_scifi_desktop(failures)
	_boot_autoload_is_wired(failures)
	_main_scene_is_defined(failures)
	_windows_export_preset_exists(failures)
	return failures


func _check(failures: PackedStringArray, ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


func _project_is_pixel_scifi_desktop(failures: PackedStringArray) -> void:
	_check(
		failures,
		str(ProjectSettings.get_setting("application/config/name")) == "突击三关",
		"project name must be 突击三关"
	)
	var features: PackedStringArray = ProjectSettings.get_setting("application/config/features")
	_check(failures, "4.7" in features, "project features must include 4.7, got %s" % str(features))
	_check(
		failures,
		int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 640,
		"viewport width must be 640"
	)
	_check(
		failures,
		int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 360,
		"viewport height must be 360"
	)
	_check(
		failures,
		str(ProjectSettings.get_setting("display/window/stretch/mode")) == "canvas_items",
		"stretch mode must be canvas_items"
	)
	_check(
		failures,
		str(ProjectSettings.get_setting("display/window/stretch/scale_mode")) == "integer",
		"stretch scale_mode must be integer"
	)
	_check(
		failures,
		str(ProjectSettings.get_setting("rendering/renderer/rendering_method")) == "gl_compatibility",
		"renderer must be gl_compatibility"
	)
	_check(
		failures,
		int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) == 0,
		"default texture filter must be nearest"
	)


func _boot_autoload_is_wired(failures: PackedStringArray) -> void:
	_check(failures, ProjectSettings.has_setting("autoload/Boot"), "project.godot must autoload Boot for stages")
	var boot_path := str(ProjectSettings.get_setting("autoload/Boot"))
	_check(
		failures,
		boot_path.contains("res://boot/boot.gd"),
		"Boot autoload must point at res://boot/boot.gd, got %s" % boot_path
	)
	_check(failures, boot_path.begins_with("*"), "Boot autoload must be a singleton (*), got %s" % boot_path)


func _main_scene_is_defined(failures: PackedStringArray) -> void:
	_check(
		failures,
		ProjectSettings.has_setting("application/run/main_scene"),
		"project.godot must set run/main_scene so godot --path . can start"
	)
	var main_path := str(ProjectSettings.get_setting("application/run/main_scene"))
	_check(
		failures,
		main_path == "res://boot/main.tscn",
		"main scene must be res://boot/main.tscn, got %s" % main_path
	)
	_check(failures, ResourceLoader.exists(main_path), "main scene file must exist: %s" % main_path)
	if not ResourceLoader.exists(main_path):
		return
	var packed: Resource = load(main_path)
	_check(failures, packed is PackedScene, "main scene must be a PackedScene")
	if not (packed is PackedScene):
		return
	var inst: Node = (packed as PackedScene).instantiate()
	_check(failures, inst is Node2D, "main scene root must be Node2D, got %s" % inst.get_class())
	_check(
		failures,
		not str(inst.get_class()).contains("3D"),
		"main scene must not be a 3D node"
	)
	inst.free()


func _windows_export_preset_exists(failures: PackedStringArray) -> void:
	_check(failures, FileAccess.file_exists("res://export_presets.cfg"), "export_presets.cfg is missing")
	var cfg := ConfigFile.new()
	var err := cfg.load("res://export_presets.cfg")
	_check(failures, err == OK, "export_presets.cfg must parse")
	if err != OK:
		return
	var found := false
	for section in cfg.get_sections():
		if not str(section).begins_with("preset.") or str(section).contains("options"):
			continue
		var platform := str(cfg.get_value(section, "platform", ""))
		if platform != "Windows Desktop":
			continue
		found = true
		_check(failures, bool(cfg.get_value(section, "runnable", false)) == true, "Windows preset should be runnable")
		var options := "%s.options" % section
		_check(
			failures,
			str(cfg.get_value(options, "binary_format/architecture", "")) == "x86_64",
			"Windows preset must export x86_64"
		)
		_check(
			failures,
			str(cfg.get_value(options, "application/product_name", "")) == "突击三关",
			"Windows product_name must be 突击三关"
		)
		var export_path := str(cfg.get_value(section, "export_path", ""))
		_check(
			failures,
			export_path.ends_with(".exe") or export_path.contains("exports"),
			"Windows export_path should target a desktop exe, got %s" % export_path
		)
		_check(
			failures,
			str(cfg.get_value(options, "codesign/identity", "")) == "",
			"do not commit codesign identity secrets"
		)
		_check(
			failures,
			str(cfg.get_value(options, "codesign/password", "")) == "",
			"do not commit codesign passwords"
		)
	_check(failures, found, "export_presets.cfg needs a Windows Desktop preset")
