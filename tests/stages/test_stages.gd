extends RefCounted

const StagesScript := preload("res://stages/stages.gd")


func run() -> PackedStringArray:
	var failures: PackedStringArray = []
	_three_hardcoded_stages(failures)
	_flat_training_is_open_ground(failures)
	_cover_stage_has_platforms_and_denser_fire(failures)
	_boss_stage_is_short_corridor(failures)
	_hostiles_have_visible_pixel_bodies(failures)
	_absent_hostiles_are_opaque_sprite2d(failures)
	_solids_are_visible_pixels(failures)
	_not_a_level_editor(failures)
	_pixel_look_is_neon_scifi(failures)
	_install_registers_builders(failures)
	_nodes_stay_off_tree_and_2d(failures)
	_actor_and_camera_stay_inside_bounds(failures)
	return failures


func _check(failures: PackedStringArray, ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


func _three_hardcoded_stages(failures: PackedStringArray) -> void:
	var names: PackedStringArray = StagesScript.list_stages()
	_check(
		failures,
		names == PackedStringArray(["平地练手", "高台掩体", "通道头目"]),
		"three stages must be 平地练手 / 高台掩体 / 通道头目, got %s" % str(names)
	)
	_check(failures, StagesScript.STAGE_COUNT == 3, "there are exactly three hardcoded stages")
	_check(failures, StagesScript.stage_name(1) == "平地练手", "stage 1 is 平地练手")
	_check(failures, StagesScript.stage_name(2) == "高台掩体", "stage 2 is 高台掩体")
	_check(failures, StagesScript.stage_name(3) == "通道头目", "stage 3 product name is 通道头目")
	_check(failures, StagesScript.scene_name(1) == "平地练手", "scene 1 is 平地练手")
	_check(failures, StagesScript.scene_name(2) == "高台掩体", "scene 2 is 高台掩体")
	_check(failures, StagesScript.scene_name(3) == "短通道头目", "scene 3 is 短通道头目")
	_check(failures, StagesScript.stage_name(0) == "", "stage 0 is not a playable stage")
	_check(failures, StagesScript.stage_name(4) == "", "there is no fourth stage")
	_check(failures, StagesScript.build_stage(0) == null, "build_stage(0) is null")
	_check(failures, StagesScript.build_stage(4) == null, "build_stage(4) is null")
	var first := StagesScript.build_stage(1)
	var again := StagesScript.build_stage(1)
	_check(failures, first != null and again != null, "平地练手 must build")
	if first != null and again != null:
		_check(failures, first.name == "平地练手", "built stage 1 node is 平地练手")
		_check(
			failures,
			first.get_meta("stage_length") == again.get_meta("stage_length"),
			"hardcoded 平地练手 length must not change between builds"
		)
		_check(
			failures,
			_count_part(first, "grunt") == _count_part(again, "grunt"),
			"hardcoded grunt slots must not change between builds"
		)
		first.free()
		again.free()
	var third := StagesScript.build_stage(3)
	_check(failures, third != null, "短通道头目 must build")
	if third != null:
		_check(failures, third.name == "短通道头目", "built stage 3 node is 短通道头目")
		third.free()


func _flat_training_is_open_ground(failures: PackedStringArray) -> void:
	var stage: Node2D = StagesScript.build_stage(1)
	_check(failures, stage != null, "平地练手 scene must exist")
	if stage == null:
		return
	_check(failures, _count_part(stage, "floor") >= 1, "平地练手 needs a floor")
	_check(failures, _count_part(stage, "platform") == 0, "平地练手 is flat: no platforms")
	_check(failures, _count_part(stage, "cover") == 0, "平地练手 is open: no cover")
	_check(failures, _count_part(stage, "corridor") == 0, "平地练手 is not a corridor")
	_check(failures, _count_part(stage, "boss") == 0, "平地练手 has no 头目")
	_check(failures, _count_part(stage, "grunt") >= 1, "平地练手 has 杂兵")
	var first_grunt := _find_part(stage, "grunt")
	_assert_visible_pixel_body(failures, first_grunt, "平地练手 杂兵")
	_check(failures, _count_part(stage, "spawn") == 1, "平地练手 has a player spawn")
	_check(failures, StagesScript.has_platforms(1) == false, "layout: 平地练手 has no platforms")
	_check(failures, StagesScript.has_cover(1) == false, "layout: 平地练手 has no cover")
	_check(failures, StagesScript.has_boss(1) == false, "layout: 平地练手 has no boss")
	_check(failures, StagesScript.is_corridor(1) == false, "layout: 平地练手 is not a corridor")
	_check(failures, StagesScript.grunt_count(1) == _count_part(stage, "grunt"), "grunt slots match layout")
	stage.free()


func _cover_stage_has_platforms_and_denser_fire(failures: PackedStringArray) -> void:
	var stage: Node2D = StagesScript.build_stage(2)
	_check(failures, stage != null, "高台掩体 scene must exist")
	if stage == null:
		return
	_check(failures, stage.name == "高台掩体", "built stage 2 node is 高台掩体")
	_check(failures, _count_part(stage, "platform") >= 2, "高台掩体 needs 高台")
	_check(failures, _count_part(stage, "cover") >= 2, "高台掩体 needs 掩体")
	_check(failures, _count_part(stage, "floor") >= 1, "高台掩体 still has a floor")
	_check(failures, _count_part(stage, "boss") == 0, "高台掩体 has no 头目")
	_check(
		failures,
		_count_part(stage, "grunt") > StagesScript.grunt_count(1),
		"高台掩体 火力更密: more 杂兵 than 平地练手"
	)
	_check(failures, StagesScript.has_platforms(2), "layout: 高台掩体 has platforms")
	_check(failures, StagesScript.has_cover(2), "layout: 高台掩体 has cover")
	_check(failures, not StagesScript.has_boss(2), "layout: 高台掩体 has no boss")
	_check(failures, not StagesScript.is_corridor(2), "layout: 高台掩体 is not the short corridor")
	stage.free()


func _boss_stage_is_short_corridor(failures: PackedStringArray) -> void:
	var stage: Node2D = StagesScript.build_stage(3)
	_check(failures, stage != null, "短通道头目 scene must exist")
	if stage == null:
		return
	_check(failures, _count_part(stage, "corridor") >= 1, "短通道头目 needs corridor solids")
	_check(failures, _count_part(stage, "boss") == 1, "短通道头目 has one 头目")
	_check(failures, _count_part(stage, "platform") == 0, "短通道头目 has no extra 高台")
	_check(failures, StagesScript.has_boss(3), "layout: 通道头目 has a boss")
	_check(failures, StagesScript.is_corridor(3), "layout: 通道头目 is a corridor")
	_check(
		failures,
		StagesScript.stage_length(3) < StagesScript.stage_length(1),
		"第三关是短通道: length %s must be < 平地练手 %s"
		% [StagesScript.stage_length(3), StagesScript.stage_length(1)]
	)
	_check(
		failures,
		float(stage.get_meta("stage_length")) == StagesScript.stage_length(3),
		"built corridor length matches the hardcoded layout"
	)
	var boss := _find_part(stage, "boss")
	_check(failures, boss != null, "头目 node must be placed")
	_assert_visible_pixel_body(failures, boss, "短通道头目")
	if boss != null:
		var spawn := _find_part(stage, "spawn")
		if spawn != null:
			_check(failures, boss.position.x > spawn.position.x, "头目 stands at the far end of the corridor")
	if ResourceLoader.exists("res://hostiles/hostiles.gd") and boss != null and boss.has_method("take_damage"):
		var probe := ClearProbe.new()
		if boss.has_signal("stage_cleared"):
			boss.connect("stage_cleared", Callable(probe, "on_cleared"))
		var hp: Variant = boss.get("hp")
		if typeof(hp) == TYPE_INT:
			boss.call("take_damage", int(hp))
			_check(failures, probe.cleared == 1, "打倒通道头目 must 通关")
			_check(failures, probe.stage == 3, "通关 reports stage 3, got %s" % probe.stage)
	stage.free()


func _hostiles_have_visible_pixel_bodies(failures: PackedStringArray) -> void:
	for index in range(1, 4):
		var stage: Node2D = StagesScript.build_stage(index)
		_check(failures, stage != null, "visibility check needs stage %s" % index)
		if stage == null:
			continue
		var grunts := _find_parts(stage, "grunt")
		var bosses := _find_parts(stage, "boss")
		if index == 1:
			_check(failures, grunts.size() >= 1, "平地练手 visibility requires at least one 杂兵 node")
			_check(failures, bosses.is_empty(), "平地练手 visibility must not count a 头目")
		if index == 3:
			_check(failures, bosses.size() == 1, "短通道头目 visibility requires a 头目 node")
		_check(
			failures,
			grunts.size() == _count_part(stage, "grunt"),
			"stage %s grunt visibility walk must match stage_part count" % index
		)
		for grunt in grunts:
			_assert_visible_pixel_body(failures, grunt, "stage %s 杂兵 %s" % [index, grunt.name])
			_check(
				failures,
				grunt.position.y < 300.0,
				"stage %s 杂兵 %s must stand on the 平地, not inside the floor" % [index, grunt.name]
			)
		for unit in bosses:
			_assert_visible_pixel_body(failures, unit, "stage %s 头目" % index)
		stage.free()


func _absent_hostiles_are_opaque_sprite2d(failures: PackedStringArray) -> void:
	var hostiles_present := ResourceLoader.exists("res://hostiles/hostiles.gd")
	if hostiles_present:
		return
	var stage1: Node2D = StagesScript.build_stage(1)
	_check(failures, stage1 != null, "absent hostiles: 平地练手 must build")
	if stage1 != null:
		var grunts := _find_parts(stage1, "grunt")
		_check(failures, grunts.size() >= 1, "absent hostiles: 平地练手 still has 杂兵")
		for grunt in grunts:
			_check(failures, grunt is Sprite2D, "absent hostiles: 杂兵 %s must be Sprite2D" % grunt.name)
			_check(failures, not (grunt is Marker2D), "absent hostiles: 杂兵 must not be Marker2D")
			_check(failures, bool(grunt.get_meta("hostile_stand_in", false)), "absent hostiles: 杂兵 is a stand-in")
			_assert_visible_pixel_body(failures, grunt, "absent hostiles 杂兵 %s" % grunt.name)
			if grunt is Sprite2D:
				var sprite := grunt as Sprite2D
				_check(failures, sprite.self_modulate.a >= 1.0, "absent hostiles: 杂兵 self_modulate must stay opaque")
				if sprite.texture != null:
					var image: Image = sprite.texture.get_image()
					if image != null:
						_check(
							failures,
							image.get_width() >= 24 and image.get_height() >= 24,
							"absent hostiles: 杂兵 %s texture %sx%s must be large enough to see"
							% [grunt.name, image.get_width(), image.get_height()]
						)
		stage1.free()
	var stage3: Node2D = StagesScript.build_stage(3)
	_check(failures, stage3 != null, "absent hostiles: 短通道头目 must build")
	if stage3 != null:
		var boss := _find_part(stage3, "boss")
		_check(failures, boss != null, "absent hostiles: 头目 node must exist")
		if boss != null:
			_check(failures, boss is Sprite2D, "absent hostiles: 头目 must be Sprite2D")
			_check(failures, not (boss is Marker2D), "absent hostiles: 头目 must not be Marker2D")
			_check(failures, bool(boss.get_meta("hostile_stand_in", false)), "absent hostiles: 头目 is a stand-in")
			_assert_visible_pixel_body(failures, boss, "absent hostiles 头目")
		stage3.free()


func _solids_are_visible_pixels(failures: PackedStringArray) -> void:
	var flat: Node2D = StagesScript.build_stage(1)
	_check(failures, flat != null, "visible solids need 平地练手")
	if flat != null:
		_assert_visible_solid(failures, _find_part(flat, "floor"), "平地练手 floor", 600, 40)
		flat.free()
	var cover: Node2D = StagesScript.build_stage(2)
	_check(failures, cover != null, "visible solids need 高台掩体")
	if cover != null:
		_assert_visible_solid(failures, _find_part(cover, "floor"), "高台掩体 floor", 600, 40)
		var platforms := _find_parts(cover, "platform")
		_check(failures, platforms.size() >= 2, "高台掩体 visible solids need 高台")
		for platform in platforms:
			_assert_visible_solid(failures, platform, "高台 %s" % platform.name, 80, 8)
		var covers := _find_parts(cover, "cover")
		_check(failures, covers.size() >= 2, "高台掩体 visible solids need 掩体")
		for box in covers:
			_assert_visible_solid(failures, box, "掩体 %s" % box.name, 16, 48)
		cover.free()
	var corridor: Node2D = StagesScript.build_stage(3)
	_check(failures, corridor != null, "visible solids need 短通道头目")
	if corridor != null:
		_assert_visible_solid(failures, _find_part(corridor, "floor"), "短通道 floor", 400, 40)
		var walls := _find_parts(corridor, "corridor")
		_check(failures, walls.size() >= 1, "短通道 needs visible corridor solids")
		for wall in walls:
			_assert_visible_solid(failures, wall, "短通道 %s" % wall.name, 8, 8)
		corridor.free()


func _not_a_level_editor(failures: PackedStringArray) -> void:
	var src := FileAccess.get_file_as_string("res://stages/stages.gd")
	_check(failures, not src.contains("func save_stage"), "stages must not save edited layouts")
	_check(failures, not src.contains("func load_stage"), "stages must not load edited layouts")
	_check(failures, not src.contains("func add_tile"), "stages must not paint tiles")
	_check(failures, not src.contains("class LevelEditor"), "stages must not ship a level editor")
	_check(failures, not src.contains("EditorPlugin"), "stages is a game, not an editor plugin")
	_check(failures, "func build_stage" in src, "stages expose hardcoded builders")
	var dirs := ["res://stages"]
	while not dirs.is_empty():
		var path: String = dirs.pop_back()
		var dir := DirAccess.open(path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if dir.current_is_dir() and not fname.begins_with("."):
				dirs.append("%s/%s" % [path, fname])
			elif fname.ends_with(".tscn") or fname.ends_with(".scn"):
				failures.append("stages must not add scene files: %s/%s" % [path, fname])
			fname = dir.get_next()
		dir.list_dir_end()


func _pixel_look_is_neon_scifi(failures: PackedStringArray) -> void:
	var stage: Node2D = StagesScript.build_stage(1)
	_check(failures, stage != null, "pixel check needs 平地练手")
	if stage == null:
		return
	var floor_body := _find_part(stage, "floor")
	var sprite := _find_sprite(floor_body) if floor_body != null else null
	_check(failures, sprite != null, "stage solids need a pixel sprite")
	if sprite != null:
		_check(
			failures,
			sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"stage sprite must be nearest-neighbor pixels"
		)
		_check(failures, sprite.texture != null, "stage sprite needs a texture")
		if sprite.texture != null:
			var image: Image = sprite.texture.get_image()
			_check(failures, image != null, "stage texture must decode")
			if image != null:
				_check(failures, _has_neon_pixel(image), "stage pixels must include neon sci-fi color")
	stage.free()


func _install_registers_builders(failures: PackedStringArray) -> void:
	var boot := BootStub.new()
	StagesScript.install(boot)
	_check(failures, boot.builders.has(1) and boot.builders.has(2) and boot.builders.has(3), "install registers three stages")
	var built: Variant = boot.builders[2].call()
	_check(failures, built is Node2D, "registered builder must return a Node2D")
	if built is Node2D:
		var node := built as Node2D
		_check(failures, node.name == "高台掩体", "boot builder for stage 2 builds 高台掩体")
		node.free()
	var ignored := BootStub.new()
	StagesScript.install(null)
	_check(failures, ignored.builders.is_empty(), "install(null) is a no-op")
	if ResourceLoader.exists("res://boot/boot.gd"):
		var script: Script = load("res://boot/boot.gd")
		if script != null and script.can_instantiate():
			var real_boot: Object = script.new()
			StagesScript.install(real_boot)
			if real_boot.has_method("go_to_stage"):
				real_boot.call("go_to_stage", 1)
				var host: Node = real_boot.get_node_or_null("StageHost")
				_check(failures, host != null, "boot StageHost must exist")
				if host != null and host.get_child_count() > 0:
					_check(failures, host.get_child(0).name == "平地练手", "install + go_to_stage(1) builds 平地练手")
			real_boot.free()


func _nodes_stay_off_tree_and_2d(failures: PackedStringArray) -> void:
	var catalog := StagesScript.new()
	_check(failures, not catalog.is_inside_tree(), "suite instantiates stages off the tree")
	_check(failures, str(catalog.get_class()) != "Node3D", "stages catalog must not be a 3D node")
	catalog.free()
	for index in range(1, 4):
		var stage: Node2D = StagesScript.build_stage(index)
		_check(failures, stage != null, "stage %s must build" % index)
		if stage == null:
			continue
		_check(failures, not stage.is_inside_tree(), "host tests do not put stage %s in a scene" % index)
		_check(failures, stage is Node2D, "stage %s is 2D" % index)
		_check(failures, stage.scene_file_path == "", "stage %s must not be a packed scene" % index)
		_walk_no_3d(stage, failures)
		stage.free()


func _actor_and_camera_stay_inside_bounds(failures: PackedStringArray) -> void:
	_check(failures, StagesScript.stage_bounds(0) == Rect2(), "stage 0 has no playable bounds")
	_check(failures, StagesScript.stage_bounds(4) == Rect2(), "there is no fourth-stage bounds")
	_check(
		failures,
		StagesScript.stage_bounds(1) == Rect2(0, 0, 640, 360),
		"平地练手 bounds are the 640x360 map"
	)
	_check(
		failures,
		StagesScript.stage_bounds(2) == Rect2(0, 0, 720, 360),
		"高台掩体 bounds are the 720x360 map"
	)
	_check(
		failures,
		StagesScript.stage_bounds(3) == Rect2(0, 0, 420, 360),
		"通道头目 bounds are the 420x360 map"
	)
	_check(
		failures,
		StagesScript.clamp_actor(1, Vector2(-40, 200)) == Vector2(0, 200),
		"actor cannot walk off the left of 平地练手"
	)
	_check(
		failures,
		StagesScript.clamp_actor(1, Vector2(800, 200)) == Vector2(640, 200),
		"actor cannot walk off the right of 平地练手"
	)
	_check(
		failures,
		StagesScript.clamp_actor(1, Vector2(100, -20)) == Vector2(100, 0),
		"actor cannot leave the top of the map"
	)
	_check(
		failures,
		StagesScript.clamp_actor(1, Vector2(100, 500)) == Vector2(100, 360),
		"actor cannot fall out the bottom of the map"
	)
	_check(
		failures,
		StagesScript.clamp_actor(1, Vector2(120, 200)) == Vector2(120, 200),
		"actor inside 平地练手 stays put"
	)
	_check(
		failures,
		StagesScript.clamp_actor(2, Vector2(900, 10)) == Vector2(720, 10),
		"actor cannot walk past 高台掩体 length 720"
	)
	_check(
		failures,
		StagesScript.clamp_actor(3, Vector2(500, 200)) == Vector2(420, 200),
		"actor cannot walk past 通道头目 length 420"
	)
	_check(
		failures,
		StagesScript.clamp_actor(0, Vector2(-9, 9)) == Vector2(-9, 9),
		"clamp_actor on an illegal stage is a no-op"
	)
	_check(
		failures,
		StagesScript.clamp_camera(1, Vector2(0, 0)) == Vector2(320, 180),
		"平地练手 fills the view: camera stays at the map center"
	)
	_check(
		failures,
		StagesScript.clamp_camera(1, Vector2(999, 999)) == Vector2(320, 180),
		"平地练手 camera cannot pan off the 640x360 map"
	)
	_check(
		failures,
		StagesScript.clamp_camera(2, Vector2(200, 180)) == Vector2(320, 180),
		"高台掩体 camera cannot show x < 0"
	)
	_check(
		failures,
		StagesScript.clamp_camera(2, Vector2(700, 180)) == Vector2(400, 180),
		"高台掩体 camera cannot show x > 720"
	)
	_check(
		failures,
		StagesScript.clamp_camera(2, Vector2(360, 180)) == Vector2(360, 180),
		"高台掩体 camera may follow inside 320..400"
	)
	_check(
		failures,
		StagesScript.clamp_camera(3, Vector2(0, 0)) == Vector2(320, 180),
		"短通道 narrower than the view left-aligns the camera"
	)
	for index in range(1, 4):
		var stage: Node2D = StagesScript.build_stage(index)
		_check(failures, stage != null, "bounds check needs stage %s" % index)
		if stage == null:
			continue
		_check(failures, _count_part(stage, "bound") >= 2, "stage %s needs left/right bound walls" % index)
		var cam_node := _find_part(stage, "camera")
		_check(failures, cam_node is Camera2D, "stage %s needs a Camera2D" % index)
		if cam_node is Camera2D:
			var cam := cam_node as Camera2D
			var length := int(StagesScript.stage_length(index))
			_check(failures, cam.limit_left == 0, "stage %s camera limit_left is 0" % index)
			_check(failures, cam.limit_top == 0, "stage %s camera limit_top is 0" % index)
			_check(failures, cam.limit_right == length, "stage %s camera limit_right is %s" % [index, length])
			_check(failures, cam.limit_bottom == 360, "stage %s camera limit_bottom is 360" % index)
			var actor := Node2D.new()
			actor.position = Vector2(-80, 900)
			StagesScript.keep_inside(stage, actor, cam)
			var bounds: Rect2 = StagesScript.stage_bounds(index)
			_check(
				failures,
				actor.position.x >= bounds.position.x and actor.position.x <= bounds.end.x,
				"keep_inside clamps stage %s actor x into %s..%s, got %s"
				% [index, bounds.position.x, bounds.end.x, actor.position.x]
			)
			_check(
				failures,
				actor.position.y >= bounds.position.y and actor.position.y <= bounds.end.y,
				"keep_inside clamps stage %s actor y into %s..%s, got %s"
				% [index, bounds.position.y, bounds.end.y, actor.position.y]
			)
			_check(
				failures,
				cam.position == StagesScript.clamp_camera(index, actor.position),
				"keep_inside parks stage %s camera inside the map" % index
			)
			actor.free()
		stage.free()
	var host := Node2D.new()
	host.name = "StageHost"
	var cover: Node2D = StagesScript.build_stage(2)
	_check(failures, cover != null, "scroll check needs 高台掩体")
	if cover != null:
		host.add_child(cover)
		var walker := Node2D.new()
		walker.position = Vector2(680, 200)
		host.add_child(walker)
		StagesScript.keep_inside(cover, walker)
		_check(
			failures,
			is_equal_approx(walker.position.x, 680.0),
			"actor still on the 720 map stays at 680, got %s" % walker.position.x
		)
		_check(
			failures,
			is_equal_approx(host.position.x, -80.0),
			"StageHost must scroll -80 so 高台掩体 x=720 stays on screen, got %s" % host.position.x
		)
	host.free()


func _walk_no_3d(node: Node, failures: PackedStringArray) -> void:
	_check(
		failures,
		not str(node.get_class()).ends_with("3D") and str(node.get_class()).find("3D") == -1,
		"3D node %s is not allowed" % node.name
	)
	for child in node.get_children():
		_walk_no_3d(child, failures)


func _count_part(node: Node, part: String) -> int:
	var total := 0
	if str(node.get_meta("stage_part", "")) == part:
		total += 1
	for child in node.get_children():
		total += _count_part(child, part)
	return total


func _find_part(node: Node, part: String) -> Node:
	if str(node.get_meta("stage_part", "")) == part:
		return node
	for child in node.get_children():
		var found := _find_part(child, part)
		if found != null:
			return found
	return null


func _find_parts(node: Node, part: String) -> Array[Node]:
	var found: Array[Node] = []
	if str(node.get_meta("stage_part", "")) == part:
		found.append(node)
	for child in node.get_children():
		found.append_array(_find_parts(child, part))
	return found


func _assert_visible_pixel_body(failures: PackedStringArray, node: Node, label: String) -> void:
	_check(failures, node != null, "%s node must exist" % label)
	if node == null:
		return
	_check(failures, not (node is Marker2D), "%s must not be an invisible Marker2D" % label)
	_check(failures, node is CanvasItem, "%s must be a CanvasItem" % label)
	var sprite := _find_visible_pixel_sprite(node)
	_check(failures, sprite != null, "%s needs a visible pixel Sprite2D body" % label)
	if sprite == null:
		return
	_check(failures, sprite.visible, "%s sprite must be visible" % label)
	_check(failures, sprite.modulate.a >= 0.5, "%s sprite modulate must stay opaque" % label)
	_check(
		failures,
		sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"%s sprite must be nearest-neighbor pixels" % label
	)
	_check(failures, sprite.texture != null, "%s sprite needs a texture" % label)
	if sprite.texture == null:
		return
	var image: Image = sprite.texture.get_image()
	_check(failures, image != null, "%s texture must decode" % label)
	if image == null:
		return
	_check(failures, image.get_width() >= 8 and image.get_height() >= 8, "%s pixel body must be large enough to see" % label)
	var opaque := _opaque_pixel_count(image)
	_check(failures, opaque >= 16, "%s must paint a visible pixel body, got %s opaque pixels" % [label, opaque])
	_check(failures, _has_neon_pixel(image), "%s pixels must include neon sci-fi color" % label)


func _assert_visible_solid(failures: PackedStringArray, node: Node, label: String, min_w: int, min_h: int) -> void:
	_check(failures, node != null, "%s node must exist" % label)
	if node == null:
		return
	_check(failures, node is CanvasItem, "%s must be a CanvasItem" % label)
	var sprite := _find_visible_pixel_sprite(node)
	_check(failures, sprite != null, "%s needs a visible opaque Sprite2D" % label)
	if sprite == null:
		return
	_check(failures, sprite.visible, "%s sprite must be visible" % label)
	_check(failures, sprite.modulate.a >= 0.5, "%s sprite modulate must stay opaque" % label)
	_check(failures, sprite.texture != null, "%s sprite needs a texture" % label)
	if sprite.texture == null:
		return
	var image: Image = sprite.texture.get_image()
	_check(failures, image != null, "%s texture must decode" % label)
	if image == null:
		return
	_check(
		failures,
		image.get_width() >= min_w and image.get_height() >= min_h,
		"%s sprite size %sx%s must be at least %sx%s" % [label, image.get_width(), image.get_height(), min_w, min_h]
	)
	var opaque := _opaque_pixel_count(image)
	_check(failures, opaque >= 64, "%s must paint visible pixels, got %s" % [label, opaque])
	_check(failures, _has_neon_pixel(image), "%s pixels must include neon sci-fi color" % label)


func _find_visible_pixel_sprite(node: Node) -> Sprite2D:
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.visible and sprite.modulate.a >= 0.5 and sprite.texture != null:
			var image: Image = sprite.texture.get_image()
			if image != null and _opaque_pixel_count(image) >= 16:
				return sprite
	for child in node.get_children():
		var found := _find_visible_pixel_sprite(child)
		if found != null:
			return found
	return null


func _opaque_pixel_count(image: Image) -> int:
	var total := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a >= 0.5:
				total += 1
	return total


func _find_sprite(node: Node) -> Sprite2D:
	if node == null:
		return null
	if node is Sprite2D:
		return node
	for child in node.get_children():
		var found := _find_sprite(child)
		if found != null:
			return found
	return null


func _has_neon_pixel(image: Image) -> bool:
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a < 0.5:
				continue
			if color.s >= 0.45 and color.v >= 0.7:
				return true
	return false


class BootStub:
	extends RefCounted
	var builders: Dictionary = {}

	func register_stage(stage_index: int, builder: Callable) -> void:
		builders[stage_index] = builder


class ClearProbe:
	extends RefCounted
	var cleared: int = 0
	var stage: int = -1

	func on_cleared(stage_index: int) -> void:
		cleared += 1
		stage = stage_index
