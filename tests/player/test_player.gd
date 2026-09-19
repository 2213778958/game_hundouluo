extends RefCounted

const PlayerScript := preload("res://player/player.gd")
const ArsenalScript := preload("res://arsenal/arsenal.gd")


func run() -> PackedStringArray:
	var failures: PackedStringArray = []
	_run_moves_left_and_right(failures)
	_jump_only_from_ground(failures)
	_hit_drops_hp(failures)
	_empty_hp_restarts_stage_not_run(failures)
	_fire_calls_arsenal(failures)
	_run_jump_and_fire_together(failures)
	_jump_and_fire_use_distinct_keys(failures)
	_controls_can_run_jump_and_fire_together(failures)
	_pixel_look_is_neon_scifi(failures)
	return failures


func _check(failures: PackedStringArray, ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


func _make_player(kind: int = ArsenalScript.Kind.RIFLE) -> CharacterBody2D:
	var player: CharacterBody2D = PlayerScript.new()
	player.call("configure", kind, Vector2(48, 120), 1)
	return player


func _run_moves_left_and_right(failures: PackedStringArray) -> void:
	var player := _make_player()
	player.call("apply_run", 1.0)
	_check(failures, player.velocity.x > 0.0, "right input must run right")
	_check(failures, player.get("facing") == Vector2.RIGHT, "running right faces right")
	player.call("apply_run", -1.0)
	_check(failures, player.velocity.x < 0.0, "left input must run left")
	_check(failures, player.get("facing") == Vector2.LEFT, "running left faces left")
	player.call("apply_run", 0.0)
	_check(failures, is_zero_approx(player.velocity.x), "release stops horizontal run")
	_check(failures, player.get("facing") == Vector2.LEFT, "idle keeps last facing")
	player.free()


func _jump_only_from_ground(failures: PackedStringArray) -> void:
	var player := _make_player()
	player.set("on_ground", true)
	var hopped: Variant = player.call("jump")
	_check(failures, hopped == true, "grounded player can jump")
	_check(failures, player.velocity.y < 0.0, "jump velocity is upward")
	_check(failures, player.get("on_ground") == false, "jump leaves the ground")
	var airborne: Variant = player.call("jump")
	_check(failures, airborne == false, "air jump is rejected")
	_check(failures, player.velocity.y < 0.0, "rejected air jump keeps upward velocity")
	player.free()


func _hit_drops_hp(failures: PackedStringArray) -> void:
	var player := _make_player()
	var start_hp: int = player.get("hp")
	_check(failures, start_hp >= 2, "player starts with enough hp to take a non-lethal hit")
	player.call("take_damage", 1)
	_check(failures, player.get("hp") == start_hp - 1, "a hit drops 1 hp, got %s" % player.get("hp"))
	var after: int = player.get("hp")
	player.call("take_damage", 0)
	_check(failures, player.get("hp") == after, "zero damage must not change hp")
	player.call("take_damage", -3)
	_check(failures, player.get("hp") == after, "negative damage must not change hp")
	player.free()


func _empty_hp_restarts_stage_not_run(failures: PackedStringArray) -> void:
	var player := _make_player(ArsenalScript.Kind.LASER)
	player.call("configure", ArsenalScript.Kind.LASER, Vector2(80, 96), 2)
	player.position = Vector2(220, 40)
	player.velocity = Vector2(140, -20)
	var max_hp: int = player.get("hp")
	var probe := RestartProbe.new()
	player.connect("stage_restarted", Callable(probe, "on_restart"))
	player.call("take_damage", max_hp)
	_check(failures, player.get("hp") == max_hp, "重来本关 restores hp, got %s" % player.get("hp"))
	_check(failures, player.position == Vector2(80, 96), "重来本关 returns to 本关起点")
	_check(failures, player.velocity == Vector2.ZERO, "重来本关 clears motion")
	_check(failures, player.get("stage_index") == 2, "重来本关 must not reset the stage index")
	var loadout: RefCounted = player.get("loadout")
	_check(
		failures,
		loadout.call("get_kind") == ArsenalScript.Kind.LASER,
		"重来本关 must not wipe the run loadout"
	)
	_check(failures, probe.stage == 2, "stage_restarted reports the current stage, got %s" % probe.stage)
	player.free()


func _fire_calls_arsenal(failures: PackedStringArray) -> void:
	var rifle := _make_player(ArsenalScript.Kind.RIFLE)
	rifle.position = Vector2(32, 64)
	rifle.set("facing", Vector2.RIGHT)
	var rifle_volley: RefCounted = rifle.call("fire", 0.0)
	_check(failures, rifle_volley.get("fired") == true, "player fire must call arsenal")
	var rifle_shots: Array = rifle_volley.get("shots")
	_check(failures, rifle_shots.size() == 1, "rifle loadout must fire one arsenal bullet, got %s" % rifle_shots.size())
	var muzzle: Vector2 = rifle_volley.get("muzzle_origin")
	_check(failures, muzzle.x > rifle.position.x, "muzzle sits ahead of facing")
	var blocked: RefCounted = rifle.call("fire", 0.001)
	_check(failures, blocked.get("fired") == false, "player fire uses arsenal cooldown")
	rifle.free()

	var shotgun := _make_player(ArsenalScript.Kind.SHOTGUN)
	var shotgun_volley: RefCounted = shotgun.call("fire", 0.0)
	var shotgun_shots: Array = shotgun_volley.get("shots")
	_check(
		failures,
		shotgun_shots.size() == 5,
		"shotgun loadout must fire arsenal scatter, got %s" % shotgun_shots.size()
	)
	shotgun.free()

	var left := _make_player(ArsenalScript.Kind.LASER)
	left.set("facing", Vector2.LEFT)
	var left_volley: RefCounted = left.call("fire", 0.0)
	var left_shots: Array = left_volley.get("shots")
	_check(failures, left_volley.get("fired") == true, "left fire must call arsenal")
	if not left_shots.is_empty():
		var vel: Vector2 = left_shots[0].get("velocity")
		_check(failures, vel.x < 0.0, "facing left fires arsenal shots left")
	left.free()


func _run_jump_and_fire_together(failures: PackedStringArray) -> void:
	var player := _make_player(ArsenalScript.Kind.RIFLE)
	player.call("apply_run", 1.0)
	player.set("on_ground", true)
	var hopped: Variant = player.call("jump")
	var volley: RefCounted = player.call("fire", 0.0)
	_check(failures, player.velocity.x > 0.0, "run + jump + fire must keep running")
	_check(failures, hopped == true, "run + jump + fire must still jump")
	_check(failures, player.velocity.y < 0.0, "run + jump + fire keeps upward jump")
	_check(failures, player.get("on_ground") == false, "run + jump + fire leaves the ground")
	_check(failures, volley.get("fired") == true, "jumping fire must still call arsenal")
	var midair: RefCounted = player.call("fire", 1.0)
	_check(failures, midair.get("fired") == true, "airborne fire must still call arsenal")
	_check(failures, player.velocity.y < 0.0, "airborne fire must not cancel jump")
	player.free()


func _jump_and_fire_use_distinct_keys(failures: PackedStringArray) -> void:
	var player := _make_player()
	player.call("ensure_control_actions")
	var jump_ids := _bind_ids(PlayerScript.ACTION_JUMP)
	var fire_ids := _bind_ids(PlayerScript.ACTION_FIRE)
	var left_ids := _bind_ids(PlayerScript.ACTION_LEFT)
	var right_ids := _bind_ids(PlayerScript.ACTION_RIGHT)
	_check(failures, not jump_ids.is_empty(), "jump must bind at least one key")
	_check(failures, not fire_ids.is_empty(), "fire must bind at least one key")
	_check(failures, _sets_disjoint(jump_ids, fire_ids), "jump and fire must not share a key")
	_check(failures, _sets_disjoint(left_ids, jump_ids), "run and jump must not share a key")
	_check(failures, _sets_disjoint(right_ids, jump_ids), "run and jump must not share a key")
	_check(failures, _sets_disjoint(left_ids, fire_ids), "run and fire must not share a key")
	_check(failures, _sets_disjoint(right_ids, fire_ids), "run and fire must not share a key")
	_check(failures, _sets_disjoint(left_ids, right_ids), "left and right must not share a key")
	player.free()


func _controls_can_run_jump_and_fire_together(failures: PackedStringArray) -> void:
	var player := _make_player(ArsenalScript.Kind.RIFLE)
	player.call("ensure_control_actions")
	_release_player_actions()
	Input.action_press(PlayerScript.ACTION_FIRE)
	player.set("on_ground", true)
	player.velocity = Vector2.ZERO
	player.call("apply_controls", 0.0)
	_check(failures, player.get("on_ground") == true, "fire action alone must not jump")
	_check(failures, is_zero_approx(player.velocity.y), "fire action alone must not apply jump velocity")
	var fire_again: RefCounted = player.call("fire", 0.001)
	_check(failures, fire_again.get("fired") == false, "fire action must call arsenal")
	_release_player_actions()

	var jumper := _make_player(ArsenalScript.Kind.RIFLE)
	jumper.call("ensure_control_actions")
	Input.action_press(PlayerScript.ACTION_JUMP)
	jumper.set("on_ground", true)
	jumper.velocity = Vector2.ZERO
	jumper.call("apply_controls", 1.0)
	_check(failures, jumper.velocity.y < 0.0, "jump action alone must jump")
	var jump_only_fire: RefCounted = jumper.call("fire", 1.0)
	_check(failures, jump_only_fire.get("fired") == true, "jump action alone must not steal fire")
	_release_player_actions()

	var combo := _make_player(ArsenalScript.Kind.RIFLE)
	combo.call("ensure_control_actions")
	combo.set("on_ground", true)
	combo.velocity = Vector2.ZERO
	Input.action_press(PlayerScript.ACTION_RIGHT)
	Input.action_press(PlayerScript.ACTION_JUMP)
	Input.action_press(PlayerScript.ACTION_FIRE)
	combo.call("apply_controls", 2.0)
	_check(failures, combo.velocity.x > 0.0, "right + jump + fire must run")
	_check(failures, combo.velocity.y < 0.0, "right + jump + fire must jump")
	_check(failures, combo.get("on_ground") == false, "right + jump + fire leaves the ground")
	var after_combo: RefCounted = combo.call("fire", 2.001)
	_check(failures, after_combo.get("fired") == false, "right + jump + fire must still call arsenal")
	_release_player_actions()
	player.free()
	jumper.free()
	combo.free()


func _bind_ids(action: String) -> Dictionary:
	var ids := {}
	if not InputMap.has_action(action):
		return ids
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var key_ev := ev as InputEventKey
			var code: int = int(key_ev.physical_keycode)
			if code == 0:
				code = int(key_ev.keycode)
			ids["k:%s" % code] = true
		elif ev is InputEventMouseButton:
			ids["m:%s" % int((ev as InputEventMouseButton).button_index)] = true
	return ids


func _sets_disjoint(left: Dictionary, right: Dictionary) -> bool:
	for key in left.keys():
		if right.has(key):
			return false
	return true


func _release_player_actions() -> void:
	for action in [
		PlayerScript.ACTION_LEFT,
		PlayerScript.ACTION_RIGHT,
		PlayerScript.ACTION_JUMP,
		PlayerScript.ACTION_FIRE,
	]:
		if InputMap.has_action(action):
			Input.action_release(action)


func _pixel_look_is_neon_scifi(failures: PackedStringArray) -> void:
	var player := _make_player()
	var sprite := _find_sprite(player)
	_check(failures, sprite != null, "player needs a pixel sprite")
	if sprite != null:
		_check(
			failures,
			sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"player sprite must be nearest-neighbor pixels"
		)
		_check(failures, sprite.texture != null, "player sprite needs a texture")
		if sprite.texture != null:
			var image: Image = sprite.texture.get_image()
			_check(failures, image != null, "player texture must decode")
			if image != null:
				_check(failures, _has_neon_pixel(image), "player pixels must include neon sci-fi color")
	player.free()


func _find_sprite(node: Node) -> Sprite2D:
	for child in node.get_children():
		if child is Sprite2D:
			return child
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


class RestartProbe:
	extends RefCounted
	var stage: int = -1

	func on_restart(stage_index: int) -> void:
		stage = stage_index
