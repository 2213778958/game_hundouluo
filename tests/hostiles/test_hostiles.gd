extends RefCounted

const HostileScript := preload("res://hostiles/hostiles.gd")


func run() -> PackedStringArray:
	var failures: PackedStringArray = []
	_grunt_walks(failures)
	_grunt_shoots_enemy_energy(failures)
	_grunt_walks_and_shoots(failures)
	_boss_shoots(failures)
	_defeating_boss_clears_stage(failures)
	_defeating_grunt_is_not_clear(failures)
	_enemy_bullets_stay_in_hostiles(failures)
	_pixel_look_is_future_drone(failures)
	_no_scene_or_3d_nodes(failures)
	_nodes_stay_off_tree(failures)
	return failures


func _check(failures: PackedStringArray, ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


func _make_grunt(spawn: Vector2 = Vector2(80, 120)) -> CharacterBody2D:
	var grunt: CharacterBody2D = HostileScript.new()
	grunt.call("configure_grunt", spawn)
	return grunt


func _make_boss(spawn: Vector2 = Vector2(520, 120)) -> CharacterBody2D:
	var boss: CharacterBody2D = HostileScript.new()
	boss.call("configure_boss", spawn)
	return boss


func _grunt_walks(failures: PackedStringArray) -> void:
	var grunt := _make_grunt(Vector2(100, 80))
	grunt.call("apply_walk", 1.0)
	_check(failures, grunt.velocity.x > 0.0, "杂兵 right walk must move right")
	_check(failures, grunt.get("facing") == Vector2.RIGHT, "walking right faces right")
	grunt.call("step", 0.5)
	_check(failures, grunt.position.x > 100.0, "杂兵 step must change x, got %s" % grunt.position.x)
	grunt.call("apply_walk", -1.0)
	_check(failures, grunt.velocity.x < 0.0, "杂兵 left walk must move left")
	_check(failures, grunt.get("facing") == Vector2.LEFT, "walking left faces left")
	var left_x := grunt.position.x
	grunt.call("step", 0.25)
	_check(failures, grunt.position.x < left_x, "杂兵 keeps walking left after step")
	grunt.call("apply_walk", 0.0)
	_check(failures, is_zero_approx(grunt.velocity.x), "release stops horizontal walk")
	grunt.call("configure_grunt", Vector2(50, 80), 40.0, 60.0)
	grunt.position = Vector2(60, 80)
	grunt.call("apply_walk", 1.0)
	grunt.call("step", 0.1)
	_check(failures, grunt.velocity.x < 0.0, "杂兵 turns around at patrol max")
	grunt.free()


func _grunt_shoots_enemy_energy(failures: PackedStringArray) -> void:
	var grunt := _make_grunt(Vector2(40, 64))
	grunt.set("facing", Vector2.LEFT)
	var volley: RefCounted = grunt.call("fire", 0.0)
	_check(failures, volley.get("fired") == true, "杂兵 must shoot")
	var shots: Array = volley.get("shots")
	_check(failures, shots.size() == 1, "杂兵 fires one shot, got %s" % shots.size())
	if shots.is_empty():
		grunt.free()
		return
	var shot: RefCounted = shots[0]
	_check(failures, shot.get("damage") > 0, "enemy shot damage must be positive")
	_check(failures, shot.get("is_energy") == true, "敌弹 must be energy / neon")
	var vel: Vector2 = shot.get("velocity")
	_check(failures, vel.x < 0.0, "杂兵 facing left shoots left")
	_check(failures, _is_neon(shot.get("tint")), "杂兵 shot tint must be neon")
	_check(failures, _is_neon(volley.get("muzzle_color")), "杂兵 muzzle must be neon")
	var blocked: RefCounted = grunt.call("fire", 0.001)
	_check(failures, blocked.get("fired") == false, "杂兵 must cool down")
	var later: RefCounted = grunt.call("fire", 2.0)
	_check(failures, later.get("fired") == true, "杂兵 should fire after cooldown")
	grunt.free()


func _grunt_walks_and_shoots(failures: PackedStringArray) -> void:
	var grunt := _make_grunt(Vector2(90, 100))
	grunt.call("apply_walk", -1.0)
	grunt.call("step", 0.2)
	var walked := grunt.position.x
	_check(failures, walked < 90.0, "走射: 杂兵 must walk before shooting")
	var volley: RefCounted = grunt.call("fire", 0.0)
	_check(failures, volley.get("fired") == true, "走射: 杂兵 must still shoot while walking")
	_check(failures, grunt.velocity.x < 0.0, "走射: walking velocity stays after fire")
	grunt.free()


func _boss_shoots(failures: PackedStringArray) -> void:
	var boss := _make_boss(Vector2(400, 96))
	boss.call("face_toward", Vector2(40, 96))
	_check(failures, boss.get("facing") == Vector2.LEFT, "头目 faces the player side")
	boss.call("apply_walk", 1.0)
	_check(failures, is_zero_approx(boss.velocity.x), "头目 stands and shoots; does not walk")
	var volley: RefCounted = boss.call("fire", 0.0)
	_check(failures, volley.get("fired") == true, "头目 must shoot")
	var shots: Array = volley.get("shots")
	_check(failures, shots.size() == 1, "头目 fires one shot, got %s" % shots.size())
	if not shots.is_empty():
		var shot: RefCounted = shots[0]
		_check(failures, shot.get("is_energy") == true, "头目 shots are energy")
		_check(failures, shot.get("damage") >= 1, "头目 shot damage must land")
		var vel: Vector2 = shot.get("velocity")
		_check(failures, vel.x < 0.0, "头目 fires toward facing")
		_check(failures, _is_neon(shot.get("tint")), "头目 shot tint must be neon")
	_check(failures, _is_neon(volley.get("muzzle_color")), "头目 muzzle must be neon")
	var blocked: RefCounted = boss.call("fire", 0.01)
	_check(failures, blocked.get("fired") == false, "头目 must cool down")
	boss.free()


func _defeating_boss_clears_stage(failures: PackedStringArray) -> void:
	var boss := _make_boss()
	var probe := ClearProbe.new()
	boss.connect("stage_cleared", Callable(probe, "on_cleared"))
	boss.connect("defeated", Callable(probe, "on_defeated"))
	var start_hp: int = boss.get("hp")
	_check(failures, start_hp > 1, "头目 starts with hp, got %s" % start_hp)
	boss.call("take_damage", 1)
	_check(failures, boss.get("hp") == start_hp - 1, "头目 hit drops hp")
	_check(failures, probe.cleared == 0, "wounded 头目 is not 通关 yet")
	_check(failures, boss.get("alive") == true, "wounded 头目 stays alive")
	boss.call("take_damage", start_hp)
	_check(failures, boss.get("hp") == 0, "defeated 头目 hp is 0")
	_check(failures, boss.get("alive") == false, "defeated 头目 is not alive")
	_check(failures, probe.defeated == 1, "头目 emits defeated, got %s" % probe.defeated)
	_check(failures, probe.cleared == 1, "打倒头目 must emit 通关")
	_check(
		failures,
		probe.stage == HostileScript.STAGE_BOSS,
		"通关 reports stage 3, got %s" % probe.stage
	)
	boss.call("take_damage", 9)
	_check(failures, probe.cleared == 1, "通关 emits once")
	var dead_fire: RefCounted = boss.call("fire", 10.0)
	_check(failures, dead_fire.get("fired") == false, "defeated 头目 does not keep shooting")
	boss.free()


func _defeating_grunt_is_not_clear(failures: PackedStringArray) -> void:
	var grunt := _make_grunt()
	var probe := ClearProbe.new()
	grunt.connect("stage_cleared", Callable(probe, "on_cleared"))
	grunt.connect("defeated", Callable(probe, "on_defeated"))
	grunt.call("take_damage", int(grunt.get("hp")))
	_check(failures, grunt.get("alive") == false, "杂兵 can be defeated")
	_check(failures, probe.defeated == 1, "杂兵 emits defeated")
	_check(failures, probe.cleared == 0, "杂兵 must not count as 通关")
	grunt.free()


func _enemy_bullets_stay_in_hostiles(failures: PackedStringArray) -> void:
	var src := FileAccess.get_file_as_string("res://hostiles/hostiles.gd")
	_check(failures, not src.contains("res://arsenal"), "hostiles must not preload arsenal")
	_check(failures, not src.contains("class_name Arsenal"), "hostiles must not alias arsenal")
	var grunt := _make_grunt(Vector2(32, 64))
	grunt.set("facing", Vector2.RIGHT)
	var volley: RefCounted = grunt.call("fire", 0.0)
	var shots: Array = volley.get("shots")
	if shots.is_empty():
		_check(failures, false, "enemy bullet check needs a shot")
		grunt.free()
		return
	var body: Area2D = shots[0].call("instantiate_projectile")
	_check(failures, body != null, "敌弹 must spawn a body")
	if body != null:
		_check(failures, body.collision_layer == HostileScript.SHOT_LAYER, "敌弹 uses SHOT_LAYER")
		_check(failures, body.collision_layer != 8, "敌弹 must not occupy player shot layer 8")
		_check(failures, body.get_meta("enemy_shot") == true, "spawned body is marked as an enemy shot")
		_check(failures, not body.has_meta("player_shot"), "hostiles must not spawn player shots")
		_check(failures, body.get_script() != null, "敌弹 script must exist")
		_check(failures, "class EnemyShot" in src, "EnemyShot lives in hostiles/")
		_check(failures, "class EnemyProjectile" in src, "EnemyProjectile lives in hostiles/")
		_check(failures, "instantiate_projectile" in src, "敌弹 spawn stays in hostiles/")
		var start_x := body.position.x
		body._physics_process(0.1)
		_check(failures, body.position.x > start_x, "敌弹 travel without joining the tree")
		_check(failures, body is Area2D, "敌弹 is a 2D area")
		body.free()
	var muzzle: Node2D = volley.call("instantiate_muzzle")
	_check(failures, muzzle != null, "fired volley must spawn a muzzle flash")
	if muzzle != null:
		_check(failures, muzzle.get_meta("muzzle_flash") == true, "muzzle node is a flash")
		_check(
			failures,
			muzzle.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"muzzle is nearest-neighbor pixels"
		)
		muzzle.free()
	grunt.free()


func _pixel_look_is_future_drone(failures: PackedStringArray) -> void:
	var grunt := _make_grunt()
	var grunt_sprite := _find_sprite(grunt)
	_check(failures, grunt_sprite != null, "杂兵 needs a pixel sprite")
	if grunt_sprite != null:
		_check(
			failures,
			grunt_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"杂兵 sprite must be nearest-neighbor pixels"
		)
		_check(failures, grunt_sprite.texture != null, "杂兵 sprite needs a texture")
		if grunt_sprite.texture != null:
			var image: Image = grunt_sprite.texture.get_image()
			_check(failures, image != null, "杂兵 texture must decode")
			if image != null:
				_check(failures, _has_neon_pixel(image), "杂兵 pixels must include neon sci-fi color")
				_check(failures, image.get_width() <= 16, "杂兵 is a small drone, not a 3D mesh")
	var boss := _make_boss()
	var boss_sprite := _find_sprite(boss)
	_check(failures, boss_sprite != null, "头目 needs a pixel sprite")
	if boss_sprite != null and boss_sprite.texture != null:
		_check(
			failures,
			boss_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"头目 sprite must be nearest-neighbor pixels"
		)
		var boss_image: Image = boss_sprite.texture.get_image()
		_check(failures, boss_image != null, "头目 texture must decode")
		if boss_image != null:
			_check(failures, _has_neon_pixel(boss_image), "头目 pixels must include neon sci-fi color")
			_check(
				failures,
				boss_image.get_width() > 16 and boss_image.get_height() > 20,
				"头目 is larger than a 杂兵 drone"
			)
	if grunt_sprite != null and boss_sprite != null:
		_check(
			failures,
			grunt_sprite.texture != boss_sprite.texture,
			"头目 look must differ from 杂兵"
		)
	grunt.free()
	boss.free()


func _no_scene_or_3d_nodes(failures: PackedStringArray) -> void:
	var grunt := _make_grunt()
	_check(failures, grunt is Node2D, "hostiles are 2D bodies")
	_check(failures, grunt is CharacterBody2D, "hostiles are 2D character bodies")
	_check(failures, grunt.scene_file_path == "", "hostiles must not be a packed scene")
	for child in grunt.get_children():
		_check(failures, not (child is Node3D), "no 3D child %s" % child.name)
	grunt.free()
	var dirs := ["res://hostiles"]
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
				failures.append("hostiles must not add scene files: %s/%s" % [path, fname])
			fname = dir.get_next()
		dir.list_dir_end()


func _nodes_stay_off_tree(failures: PackedStringArray) -> void:
	var grunt := _make_grunt()
	var boss := _make_boss()
	_check(failures, not grunt.is_inside_tree(), "host tests do not put 杂兵 in a scene")
	_check(failures, not boss.is_inside_tree(), "host tests do not put 头目 in a scene")
	var volley: RefCounted = grunt.call("fire", 0.0)
	_check(failures, grunt.get_child_count() <= 2, "off-tree fire must not attach bullets to the 杂兵")
	_check(failures, volley.get("fired") == true, "off-tree 杂兵 can still produce a volley")
	boss.call("take_damage", int(boss.get("hp")))
	_check(failures, not boss.is_inside_tree(), "通关 works without adding the 头目 to a tree")
	grunt.free()
	boss.free()


func _find_sprite(node: Node) -> Sprite2D:
	for child in node.get_children():
		if child is Sprite2D:
			return child
	return null


func _is_neon(color: Color) -> bool:
	return color.s >= 0.45 and color.v >= 0.7


func _has_neon_pixel(image: Image) -> bool:
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a < 0.5:
				continue
			if color.s >= 0.45 and color.v >= 0.7:
				return true
	return false


class ClearProbe:
	extends RefCounted
	var cleared: int = 0
	var defeated: int = 0
	var stage: int = -1

	func on_cleared(stage_index: int) -> void:
		cleared += 1
		stage = stage_index

	func on_defeated() -> void:
		defeated += 1
