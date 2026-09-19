extends RefCounted

const BootScript := preload("res://boot/boot.gd")
const HpBarScript := preload("res://boot/hp_bar.gd")


func run() -> PackedStringArray:
	var failures: PackedStringArray = []
	_entry_shows_title_and_three_weapons(failures)
	_player_can_choose_each_starting_weapon(failures)
	_machine_gun_is_not_a_choice(failures)
	_hp_bar_tracks_hp_changed(failures)
	_stage_switch_covers_three_stages(failures)
	_restart_keeps_weapon(failures)
	_hang_audio_without_audio_module(failures)
	_nodes_stay_off_tree_and_2d(failures)
	_boot_does_not_compile_depend_on_stages(failures)
	_weapon_opens_visible_flat_training(failures)
	_boot_surfaces_are_not_plain(failures)
	return failures


func _check(failures: PackedStringArray, ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


func _make_boot() -> CanvasLayer:
	return BootScript.new()


func _entry_shows_title_and_three_weapons(failures: PackedStringArray) -> void:
	var boot := _make_boot()
	_check(failures, not boot.is_inside_tree(), "boot tests must not enter the SceneTree")
	_check(failures, str(boot.get_class()) == "CanvasLayer", "boot overlay is a CanvasLayer, not a 3D world")
	_check(failures, boot.get("current_stage") == 0, "boot starts at the entry screen")
	_check(failures, boot.call("is_entry_visible") == true, "entry / weapon select is visible at boot")
	_check(failures, _find_label_text(boot, "突击三关"), "entry must show title 突击三关")
	var choices: PackedStringArray = boot.call("list_weapon_choices")
	_check(
		failures,
		choices == PackedStringArray(["步枪", "散弹枪", "激光枪"]),
		"starting weapons must be 步枪 / 散弹枪 / 激光枪, got %s" % str(choices)
	)
	var buttons := _weapon_button_texts(boot)
	for weapon_name in ["步枪", "散弹枪", "激光枪"]:
		_check(failures, weapon_name in buttons, "weapon select UI missing %s" % weapon_name)
	_check(failures, boot.call("get_hp_bar").visible == false, "hp bar stays hidden on the entry screen")
	boot.free()


func _player_can_choose_each_starting_weapon(failures: PackedStringArray) -> void:
	for pair in [
		["步枪", BootScript.WEAPON_RIFLE],
		["散弹枪", BootScript.WEAPON_SHOTGUN],
		["激光枪", BootScript.WEAPON_LASER],
	]:
		var boot := _make_boot()
		var probe := ChoiceProbe.new()
		boot.connect("weapon_chosen", Callable(probe, "on_chosen"))
		boot.connect("stage_changed", Callable(probe, "on_stage"))
		boot.call("choose_weapon_by_name", pair[0])
		_check(
			failures,
			boot.get("selected_weapon") == pair[1],
			"%s must store kind %s, got %s" % [pair[0], pair[1], boot.get("selected_weapon")]
		)
		_check(failures, probe.kind == pair[1], "%s must emit weapon_chosen" % pair[0])
		_check(failures, boot.get("current_stage") == 1, "choosing %s starts 平地练手" % pair[0])
		_check(failures, probe.stage == 1, "choosing %s must emit stage_changed(1)" % pair[0])
		_check(failures, boot.call("is_entry_visible") == false, "weapon select hides after %s" % pair[0])
		_check(failures, boot.call("get_hp_bar").visible == true, "hp bar shows after choosing %s" % pair[0])
		_check(failures, boot.call("weapon_name", pair[1]) == pair[0], "weapon_name must round-trip %s" % pair[0])
		boot.free()
	var by_int := _make_boot()
	by_int.call("choose_weapon", BootScript.WEAPON_LASER)
	_check(failures, by_int.get("selected_weapon") == BootScript.WEAPON_LASER, "choose_weapon accepts 激光枪 int")
	by_int.free()


func _machine_gun_is_not_a_choice(failures: PackedStringArray) -> void:
	var boot := _make_boot()
	var before: int = boot.get("selected_weapon")
	boot.call("choose_weapon_by_name", "机枪")
	_check(failures, boot.get("selected_weapon") == before, "机枪 must not be a starting weapon")
	_check(failures, boot.get("current_stage") == 0, "rejecting 机枪 must not leave the entry")
	boot.call("choose_weapon", 99)
	_check(failures, boot.get("selected_weapon") == before, "unknown weapon kind must be ignored")
	var listed: PackedStringArray = boot.call("list_weapon_choices")
	_check(failures, listed.find("机枪") == -1, "list_weapon_choices must not include 机枪")
	var buttons := _weapon_button_texts(boot)
	_check(failures, buttons.find("机枪") == -1, "weapon buttons must not include 机枪")
	boot.free()


func _hp_bar_tracks_hp_changed(failures: PackedStringArray) -> void:
	var bar: Control = HpBarScript.new()
	_check(failures, not bar.is_inside_tree(), "hp bar tests must not enter the SceneTree")
	bar.call("set_hp", 2, 5)
	_check(failures, is_equal_approx(bar.call("get_ratio"), 0.4), "hp 2/5 must fill 0.4, got %s" % bar.call("get_ratio"))
	var fill := bar.get_node_or_null("Fill") as ColorRect
	_check(failures, fill != null, "hp bar needs a Fill rect")
	if fill != null:
		_check(failures, fill.color.s >= 0.45 and fill.color.v >= 0.7, "hp fill must be neon sci-fi, got %s" % fill.color)
		_check(failures, is_equal_approx(fill.size.x, 160.0 * 0.4), "fill width follows hp ratio")
	bar.call("set_hp", 0, 5)
	_check(failures, is_equal_approx(bar.call("get_ratio"), 0.0), "empty hp is an empty bar")
	bar.call("set_hp", 9, 5)
	_check(failures, is_equal_approx(bar.call("get_ratio"), 1.0), "hp must clamp to max")
	bar.free()

	var boot := _make_boot()
	var source := HpSource.new()
	boot.call("bind_hp_bar", source)
	_check(failures, is_equal_approx(boot.call("get_hp_ratio"), 1.0), "bind_hp_bar reads starting hp")
	source.hp = 3
	source.hp_changed.emit(3, 5)
	_check(failures, is_equal_approx(boot.call("get_hp_ratio"), 0.6), "hp_changed must drive the boot hp bar")
	boot.call("set_hp", 1, 5)
	_check(failures, is_equal_approx(boot.call("get_hp_ratio"), 0.2), "set_hp is the public hp bar API")
	_check(failures, not source.is_inside_tree(), "hp source stays off the tree")
	source.free()
	boot.free()


func _stage_switch_covers_three_stages(failures: PackedStringArray) -> void:
	var boot := _make_boot()
	var stages: PackedStringArray = boot.call("list_stages")
	_check(
		failures,
		stages == PackedStringArray(["平地练手", "高台掩体", "通道头目"]),
		"three stages must be 平地练手 / 高台掩体 / 通道头目, got %s" % str(stages)
	)
	_check(failures, boot.call("stage_name", 1) == "平地练手", "stage 1 is 平地练手")
	_check(failures, boot.call("stage_name", 2) == "高台掩体", "stage 2 is 高台掩体")
	_check(failures, boot.call("stage_name", 3) == "通道头目", "stage 3 is 通道头目")
	var factory := StageFactory.new()
	boot.call("register_stage", 1, Callable(factory, "make_flat"))
	boot.call("register_stage", 2, Callable(factory, "make_cover"))
	boot.call("register_stage", 3, Callable(factory, "make_boss"))
	var probe := ChoiceProbe.new()
	boot.connect("stage_changed", Callable(probe, "on_stage"))
	boot.call("go_to_stage", 1)
	_check(failures, boot.get("current_stage") == 1, "go_to_stage(1) is 平地练手")
	_check(failures, _host_child_name(boot) == "Flat", "stage 1 builder must run")
	boot.call("go_to_stage", 2)
	_check(failures, boot.get("current_stage") == 2, "go_to_stage(2) is 高台掩体")
	_check(failures, _host_child_name(boot) == "Cover", "stage 2 builder must replace stage 1")
	_check(failures, probe.stage == 2, "stage_changed reports 高台掩体")
	boot.call("go_to_stage", 3)
	_check(failures, boot.get("current_stage") == 3, "go_to_stage(3) is 通道头目")
	_check(failures, _host_child_name(boot) == "Boss", "stage 3 builder must replace stage 2")
	boot.call("go_to_stage", 0)
	_check(failures, boot.get("current_stage") == 3, "stage 0 is entry, not a playable stage switch")
	boot.call("go_to_stage", 4)
	_check(failures, boot.get("current_stage") == 3, "there is no fourth stage")
	_check(failures, factory.flat == 1 and factory.cover == 1 and factory.boss == 1, "each stage built once before restart")
	boot.free()


func _restart_keeps_weapon(failures: PackedStringArray) -> void:
	var boot := _make_boot()
	var factory := StageFactory.new()
	boot.call("register_stage", 2, Callable(factory, "make_cover"))
	boot.call("choose_weapon", BootScript.WEAPON_SHOTGUN)
	boot.call("go_to_stage", 2)
	boot.call("restart_stage")
	_check(failures, boot.get("current_stage") == 2, "restart_stage stays on 高台掩体")
	_check(failures, boot.get("selected_weapon") == BootScript.WEAPON_SHOTGUN, "restart_stage must not wipe 散弹枪")
	_check(failures, factory.cover == 2, "restart_stage rebuilds the current stage node")
	_check(failures, _host_child_name(boot) == "Cover", "rebuilt stage is still 高台掩体")
	boot.call("show_entry")
	_check(failures, boot.get("current_stage") == 0, "show_entry returns to weapon select")
	_check(failures, boot.call("is_entry_visible") == true, "entry is visible after show_entry")
	_check(failures, boot.get("selected_weapon") == BootScript.WEAPON_SHOTGUN, "show_entry keeps the last loadout")
	boot.free()


func _hang_audio_without_audio_module(failures: PackedStringArray) -> void:
	var boot := _make_boot()
	var audio := AudioStub.new()
	boot.call("hang_audio", audio)
	_check(failures, audio.get_parent() == boot, "boot hangs GameAudio as a child")
	_check(failures, not audio.is_inside_tree(), "hung audio still stays off the host SceneTree")
	boot.call("go_to_stage", 3)
	_check(failures, audio.last_stage == 3, "go_to_stage tells hung audio to play_bgm for 通道头目")
	boot.call("show_entry")
	_check(failures, audio.stopped == true, "returning to entry stops BGM")
	boot.free()


func _nodes_stay_off_tree_and_2d(failures: PackedStringArray) -> void:
	var boot := _make_boot()
	_check(failures, not boot.is_inside_tree(), "suite instantiates boot off the tree")
	_check(failures, boot.scene_file_path == "", "boot must not be a packed scene")
	_check(failures, str(boot.get_class()) != "Node3D", "boot must not be a 3D node")
	_walk_no_3d(boot, failures)
	var dir := DirAccess.open("res://boot")
	_check(failures, dir != null, "boot/ must exist")
	var saw_main := false
	if dir != null:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if fname == "main.tscn":
				saw_main = true
			elif fname.ends_with(".tscn"):
				failures.append("only boot/main.tscn may be a packed scene, found %s" % fname)
			_check(failures, not fname.ends_with(".scn"), "no packed .scn, found %s" % fname)
			fname = dir.get_next()
		dir.list_dir_end()
	_check(failures, saw_main, "boot/main.tscn must exist so godot --path . has a main scene")
	boot.free()


func _boot_does_not_compile_depend_on_stages(failures: PackedStringArray) -> void:
	var src := FileAccess.get_file_as_string("res://boot/boot.gd")
	_check(failures, src != "", "boot.gd must be readable")
	_check(failures, not src.contains("preload(\"res://stages"), "boot.gd must not preload stages")
	_check(failures, not src.contains("preload('res://stages"), "boot.gd must not preload stages")
	_check(failures, not src.contains("class_name Stages"), "boot.gd must not alias stages")
	_check(
		failures,
		"ResourceLoader.exists" in src and "STAGES_PATH" in src,
		"boot must hang stages at runtime via STAGES_PATH"
	)
	_check(failures, "func hang_stages" in src, "boot must expose hang_stages for the autoload path")


func _boot_surfaces_are_not_plain(failures: PackedStringArray) -> void:
	var boot := _make_boot()
	var entry := boot.get_node_or_null("Entry")
	_check(failures, entry != null, "entry surface must exist")
	var starfield: TextureRect = null
	if entry != null:
		starfield = entry.get_node_or_null("Starfield") as TextureRect
	_check(failures, starfield != null and starfield.texture != null, "entry needs a pixel starfield, not a flat void")
	if starfield != null:
		_check(
			failures,
			starfield.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"entry starfield must stay nearest-neighbor pixels"
		)
		var sky := starfield.texture.get_image()
		_check(failures, sky != null, "starfield texture must expose pixels")
		if sky != null:
			_check(failures, _unique_opaque_colors(sky) >= 10, "entry backdrop must not be a single flat color")
			_check(failures, _image_has_neon(sky), "entry backdrop must include neon sci-fi color")
			_check(failures, _image_has_warm_accent(sky), "entry backdrop needs a second accent besides cyan")
	_assert_pixel_layer(failures, entry, "Scanlines", 3, true, "entry scanlines")
	_assert_pixel_layer(failures, entry, "Frame", 4, true, "entry frame")
	_assert_pixel_layer(failures, entry, "RailLeft", 3, true, "entry left rail")
	_assert_pixel_layer(failures, entry, "RailRight", 3, true, "entry right rail")
	_assert_pixel_layer(failures, entry, "TitlePlate", 4, true, "title plate")
	_assert_pixel_layer(failures, entry, "Deck", 3, true, "entry deck")
	_assert_pixel_layer(failures, entry, "StatusBar", 3, true, "entry status bar")
	_check(failures, _find_label_text(boot, "像素科幻 · 三关突击"), "entry must show a sci-fi tag under the title")
	_check(failures, _find_label_text(boot, "点选武器进入平地练手"), "entry must hint how to start")
	var gun_images: Array[Image] = []
	for pair in [["0", "直射"], ["1", "近距散射"], ["2", "能量直线"]]:
		var card := entry.get_node_or_null("WeaponRow/WeaponCard_%s" % pair[0]) if entry != null else null
		_check(failures, card != null, "weapon card %s missing" % pair[0])
		if card == null:
			continue
		_assert_pixel_layer(failures, card, "CardBack", 4, true, "weapon card %s back" % pair[0])
		_assert_pixel_layer(failures, card, "Accent", 3, true, "weapon card %s accent" % pair[0])
		var icon := card.get_node_or_null("Icon") as TextureRect
		_check(failures, icon != null and icon.texture != null, "weapon card %s needs a pixel gun icon" % pair[0])
		if icon != null and icon.texture != null:
			_check(
				failures,
				icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
				"weapon icon %s must be nearest-neighbor pixels" % pair[0]
			)
			var gun := icon.texture.get_image()
			_check(failures, gun != null and _image_has_neon(gun), "weapon icon %s must be neon sci-fi" % pair[0])
			if gun != null:
				gun_images.append(gun)
		var button := card.get_node_or_null("Weapon_%s" % pair[0]) as Button
		_check(failures, button != null and button.icon != null, "weapon button %s needs an icon, not plain text" % pair[0])
		var flavor := card.get_node_or_null("Flavor") as Label
		_check(failures, flavor != null and flavor.text == pair[1], "weapon card %s flavor must be %s" % [pair[0], pair[1]])
	if gun_images.size() == 3:
		_check(failures, _images_differ(gun_images[0], gun_images[1]), "步枪 and 散弹枪 icons must not share one silhouette")
		_check(failures, _images_differ(gun_images[0], gun_images[2]), "步枪 and 激光枪 icons must not share one silhouette")
		_check(failures, _images_differ(gun_images[1], gun_images[2]), "散弹枪 and 激光枪 icons must not share one silhouette")
	boot.free()

	var bar: Control = HpBarScript.new()
	_check(failures, bar.get_node_or_null("Caption") != null, "hp bar needs an HP caption")
	_check(failures, bar.get_node_or_null("Readout") != null, "hp bar needs a numeric readout")
	_check(failures, bar.get_node_or_null("Frame") is TextureRect, "hp bar needs a pixel frame")
	_check(failures, bar.get_node_or_null("Ticks") != null, "hp bar needs segment ticks")
	_check(failures, bar.get_node_or_null("Pips") != null, "hp bar needs energy pips")
	_check(failures, bar.get_node_or_null("Glow") != null, "hp bar needs a neon glow")
	_assert_pixel_layer(failures, bar, "Hatch", 3, true, "hp hatch")
	_assert_pixel_layer(failures, bar, "TrackGrid", 2, false, "hp track grid")
	_assert_pixel_layer(failures, bar, "LifeMark", 3, true, "hp life mark")
	_check(failures, bar.get_child_count() >= 12, "hp bar chrome must be more than a plain rectangle")
	bar.call("set_hp", 2, 5)
	var readout := bar.get_node_or_null("Readout") as Label
	_check(failures, readout != null and readout.text == "2/5", "hp readout must track 2/5, got %s" % (readout.text if readout != null else ""))
	var hatch := bar.get_node_or_null("Hatch") as TextureRect
	_check(failures, hatch != null and is_equal_approx(hatch.size.x, 160.0 * 0.4), "hp hatch width must follow 2/5")
	var pips := bar.get_node_or_null("Pips")
	_check(failures, pips != null and pips.get_child_count() == 5, "hp pips must match max hp")
	if pips != null and pips.get_child_count() >= 5:
		_check(failures, (pips.get_child(0) as ColorRect).color.v >= 0.7, "filled hp pip must stay neon")
		_check(failures, (pips.get_child(3) as ColorRect).color.v < 0.5, "empty hp pip must dim")
	var frame := bar.get_node_or_null("Frame") as TextureRect
	if frame != null and frame.texture != null:
		_check(failures, frame.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "hp frame must be nearest-neighbor pixels")
		var chrome := frame.texture.get_image()
		_check(failures, chrome != null and _image_has_neon(chrome), "hp frame must include neon sci-fi color")
		if chrome != null:
			_check(failures, _unique_opaque_colors(chrome) >= 3, "hp frame must not be a single rim color")
			_check(failures, _image_has_warm_accent(chrome), "hp frame needs a second accent besides cyan")
	bar.free()


func _weapon_opens_visible_flat_training(failures: PackedStringArray) -> void:
	if not ResourceLoader.exists("res://stages/stages.gd"):
		failures.append("stages catalog missing; cannot hang 平地练手")
		return
	for pair in [
		["步枪", BootScript.WEAPON_RIFLE],
		["散弹枪", BootScript.WEAPON_SHOTGUN],
		["激光枪", BootScript.WEAPON_LASER],
	]:
		var boot := _make_boot()
		var probe := ChoiceProbe.new()
		boot.connect("stage_changed", Callable(probe, "on_stage"))
		boot.call("hang_stages")
		boot.call("choose_weapon_by_name", pair[0])
		_check(failures, boot.get("current_stage") == 1, "choosing %s must enter 平地练手" % pair[0])
		_check(failures, probe.stage == 1, "choosing %s must switch via boot stage_changed(1)" % pair[0])
		var host := boot.get_node_or_null("StageHost")
		_check(failures, host != null and host.get_child_count() > 0, "choosing %s must put a stage under StageHost" % pair[0])
		if host == null or host.get_child_count() == 0:
			boot.free()
			continue
		var stage: Node = host.get_child(0)
		_check(failures, stage.name == "平地练手", "choosing %s must build 平地练手, got %s" % [pair[0], stage.name])
		_check(failures, _count_stage_part(stage, "floor") >= 1, "平地练手 after %s must have ground" % pair[0])
		_check(failures, _count_stage_part(stage, "grunt") >= 1, "平地练手 after %s must have 杂兵" % pair[0])
		var floor_node := _find_stage_part(stage, "floor")
		var grunt := _find_stage_part(stage, "grunt")
		_check(failures, _has_visible_sprite(floor_node), "平地练手 ground must be a visible sprite after %s" % pair[0])
		_check(failures, _has_visible_sprite(grunt), "平地练手 杂兵 must be a visible sprite after %s" % pair[0])
		boot.free()


func _walk_no_3d(node: Node, failures: PackedStringArray) -> void:
	_check(
		failures,
		not str(node.get_class()).ends_with("3D") and str(node.get_class()).find("3D") == -1,
		"3D node %s is not allowed" % node.name
	)
	for child in node.get_children():
		_walk_no_3d(child, failures)


func _weapon_button_texts(boot: Node) -> PackedStringArray:
	var texts: PackedStringArray = []
	_collect_buttons(boot, texts)
	return texts


func _collect_buttons(node: Node, texts: PackedStringArray) -> void:
	if node is Button:
		texts.append((node as Button).text)
	for child in node.get_children():
		_collect_buttons(child, texts)


func _find_label_text(node: Node, wanted: String) -> bool:
	if node is Label and (node as Label).text == wanted:
		return true
	for child in node.get_children():
		if _find_label_text(child, wanted):
			return true
	return false


func _host_child_name(boot: Node) -> String:
	var host := boot.get_node_or_null("StageHost")
	if host == null or host.get_child_count() == 0:
		return ""
	return str(host.get_child(0).name)


func _count_stage_part(node: Node, part: String) -> int:
	var total := 0
	if str(node.get_meta("stage_part", "")) == part:
		total += 1
	for child in node.get_children():
		total += _count_stage_part(child, part)
	return total


func _find_stage_part(node: Node, part: String) -> Node:
	if str(node.get_meta("stage_part", "")) == part:
		return node
	for child in node.get_children():
		var found := _find_stage_part(child, part)
		if found != null:
			return found
	return null


func _assert_pixel_layer(
	failures: PackedStringArray,
	parent: Node,
	node_name: String,
	min_colors: int,
	need_neon: bool,
	label: String
) -> void:
	_check(failures, parent != null, "%s parent missing" % label)
	if parent == null:
		return
	var view := parent.get_node_or_null(node_name) as TextureRect
	_check(failures, view != null and view.texture != null, "%s needs a pixel texture, not a flat node" % label)
	if view == null or view.texture == null:
		return
	_check(
		failures,
		view.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"%s must stay nearest-neighbor pixels" % label
	)
	var image := view.texture.get_image()
	_check(failures, image != null, "%s texture must expose pixels" % label)
	if image == null:
		return
	_check(
		failures,
		_unique_visible_colors(image) >= min_colors,
		"%s must use several pixel colors, got %s" % [label, _unique_visible_colors(image)]
	)
	if need_neon:
		_check(failures, _image_has_neon(image), "%s must include neon sci-fi color" % label)


func _image_has_neon(image: Image) -> bool:
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a >= 0.5 and color.s >= 0.45 and color.v >= 0.7:
				return true
	return false


func _image_has_warm_accent(image: Image) -> bool:
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a < 0.5 or color.s < 0.4 or color.v < 0.55:
				continue
			if color.r > color.b + 0.08:
				return true
	return false


func _images_differ(a: Image, b: Image) -> bool:
	if a.get_width() != b.get_width() or a.get_height() != b.get_height():
		return true
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				return true
	return false


func _unique_visible_colors(image: Image) -> int:
	var seen := {}
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a < 0.12:
				continue
			seen[color] = true
	return seen.size()


func _unique_opaque_colors(image: Image) -> int:
	var seen := {}
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a < 0.5:
				continue
			seen[color] = true
	return seen.size()


func _has_visible_sprite(node: Node) -> bool:
	if node == null:
		return false
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.visible and sprite.texture != null and sprite.modulate.a >= 0.5:
			return true
	for child in node.get_children():
		if _has_visible_sprite(child):
			return true
	return false


class ChoiceProbe:
	extends RefCounted
	var kind: int = -1
	var stage: int = -1

	func on_chosen(weapon_kind: int) -> void:
		kind = weapon_kind

	func on_stage(stage_index: int) -> void:
		stage = stage_index


class HpSource:
	extends Node
	signal hp_changed(hp: int, max_hp: int)
	const MAX_HP := 5
	var hp: int = MAX_HP


class AudioStub:
	extends Node
	var last_stage: int = -1
	var stopped: bool = false

	func play_bgm(stage_index: int = 1) -> void:
		last_stage = stage_index
		stopped = false

	func stop_bgm() -> void:
		stopped = true


class StageFactory:
	extends RefCounted
	var flat: int = 0
	var cover: int = 0
	var boss: int = 0

	func make_flat() -> Node2D:
		flat += 1
		var node := Node2D.new()
		node.name = "Flat"
		return node

	func make_cover() -> Node2D:
		cover += 1
		var node := Node2D.new()
		node.name = "Cover"
		return node

	func make_boss() -> Node2D:
		boss += 1
		var node := Node2D.new()
		node.name = "Boss"
		return node
