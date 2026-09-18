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
