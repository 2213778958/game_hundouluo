extends RefCounted

const ArsenalScript := preload("res://arsenal/arsenal.gd")

## Independent three-stage HP budget. Hostiles may match these later.
const STAGE1_HP := 32
const STAGE2_HP := 72
const STAGE3_HP := 104
const STAGE_HP_BUDGET := 208
const COMBAT_SECONDS := 60.0
## Mid-range shotgun: two of five pellets land.
const SHOTGUN_MID_HIT := 0.4


func run() -> PackedStringArray:
	var failures: PackedStringArray = []
	_rifle_is_straight_player_shot(failures)
	_shotgun_is_close_scatter(failures)
	_laser_is_energy_line(failures)
	_cooldown_blocks_then_allows(failures)
	_zero_facing_does_not_fire(failures)
	_each_weapon_can_finish_three_stages(failures)
	_muzzle_and_energy_are_neon(failures)
	_spawned_shot_is_player_not_enemy(failures)
	_only_three_player_kinds(failures)
	return failures


func _check(failures: PackedStringArray, ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


func _rifle_is_straight_player_shot(failures: PackedStringArray) -> void:
	var arsenal: RefCounted = ArsenalScript.new(ArsenalScript.Kind.RIFLE)
	var volley: RefCounted = arsenal.call("fire", Vector2.ZERO, Vector2.RIGHT, 0.0)
	_check(failures, volley.get("fired") == true, "rifle should fire")
	var shots: Array = volley.get("shots")
	_check(failures, shots.size() == 1, "rifle fires one bullet, got %s" % shots.size())
	if shots.is_empty():
		return
	var shot: RefCounted = shots[0]
	_check(failures, shot.get("damage") > 0, "rifle damage must be positive")
	_check(failures, shot.get("pierce") == false, "rifle bullet does not pierce")
	_check(failures, shot.get("is_energy") == false, "rifle is a bullet, not energy")
	_check(failures, shot.get("max_range") >= 400.0, "rifle must reach across a stage")
	var vel: Vector2 = shot.get("velocity")
	_check(
		failures,
		vel.normalized().is_equal_approx(Vector2.RIGHT),
		"rifle must shoot straight along facing"
	)


func _shotgun_is_close_scatter(failures: PackedStringArray) -> void:
	var rifle: RefCounted = ArsenalScript.new(ArsenalScript.Kind.RIFLE)
	var rifle_shot: RefCounted = rifle.call("fire", Vector2.ZERO, Vector2.RIGHT, 0.0).get("shots")[0]
	var arsenal: RefCounted = ArsenalScript.new(ArsenalScript.Kind.SHOTGUN)
	var volley: RefCounted = arsenal.call("fire", Vector2.ZERO, Vector2.RIGHT, 0.0)
	var shots: Array = volley.get("shots")
	_check(failures, shots.size() == 5, "shotgun fires five pellets, got %s" % shots.size())
	if shots.size() < 2:
		return
	_check(
		failures,
		shots[0].get("max_range") <= 160.0,
		"shotgun is close range, got %s" % shots[0].get("max_range")
	)
	_check(
		failures,
		shots[0].get("max_range") < rifle_shot.get("max_range"),
		"shotgun range must be shorter than rifle"
	)
	_check(failures, shots[0].get("pierce") == false, "shotgun pellets do not pierce")
	var dirs: Dictionary = {}
	for shot in shots:
		var key := str((shot.get("velocity") as Vector2).angle())
		dirs[key] = true
	_check(failures, dirs.size() >= 3, "shotgun pellets must scatter, unique dirs=%s" % dirs.size())


func _laser_is_energy_line(failures: PackedStringArray) -> void:
	var rifle: RefCounted = ArsenalScript.new(ArsenalScript.Kind.RIFLE)
	var rifle_shot: RefCounted = rifle.call("fire", Vector2.ZERO, Vector2.RIGHT, 0.0).get("shots")[0]
	var arsenal: RefCounted = ArsenalScript.new(ArsenalScript.Kind.LASER)
	var volley: RefCounted = arsenal.call("fire", Vector2.ZERO, Vector2.RIGHT, 0.0)
	var shots: Array = volley.get("shots")
	_check(failures, shots.size() == 1, "laser fires one energy bolt, got %s" % shots.size())
	if shots.is_empty():
		return
	var shot: RefCounted = shots[0]
	_check(failures, shot.get("is_energy") == true, "laser is energy")
	_check(failures, shot.get("pierce") == true, "laser pierces along the line")
	_check(
		failures,
		shot.get("max_range") >= rifle_shot.get("max_range"),
		"laser must reach at least as far as the rifle"
	)
	var vel: Vector2 = shot.get("velocity")
	_check(
		failures,
		vel.normalized().is_equal_approx(Vector2.RIGHT),
		"laser must travel in a straight line"
	)
	_check(
		failures,
		vel.length() > rifle_shot.get("velocity").length(),
		"laser bolt must be faster than a rifle bullet"
	)


func _cooldown_blocks_then_allows(failures: PackedStringArray) -> void:
	var arsenal: RefCounted = ArsenalScript.new(ArsenalScript.Kind.RIFLE)
	var first: RefCounted = arsenal.call("fire", Vector2.ZERO, Vector2.RIGHT, 0.0)
	var blocked: RefCounted = arsenal.call("fire", Vector2.ZERO, Vector2.RIGHT, 0.001)
	var later: RefCounted = arsenal.call("fire", Vector2.ZERO, Vector2.RIGHT, 1.0)
	_check(failures, first.get("fired") == true, "first rifle shot should fire")
	_check(failures, blocked.get("fired") == false, "rifle must cool down")
	_check(failures, (blocked.get("shots") as Array).is_empty(), "cooldown volley has no shots")
	_check(failures, later.get("fired") == true, "rifle should fire after cooldown")


func _zero_facing_does_not_fire(failures: PackedStringArray) -> void:
	var arsenal: RefCounted = ArsenalScript.new(ArsenalScript.Kind.LASER)
	var volley: RefCounted = arsenal.call("fire", Vector2(8, 8), Vector2.ZERO, 0.0)
	_check(failures, volley.get("fired") == false, "zero facing must not fire")
	_check(failures, (volley.get("shots") as Array).is_empty(), "zero facing has no shots")


func _each_weapon_can_finish_three_stages(failures: PackedStringArray) -> void:
	_check(
		failures,
		STAGE1_HP + STAGE2_HP + STAGE3_HP == STAGE_HP_BUDGET,
		"stage HP budget literals must sum"
	)
	_check(
		failures,
		_damage_in(ArsenalScript.Kind.RIFLE, 1.0) >= STAGE_HP_BUDGET,
		"rifle 60s damage must clear three stages (%s hp)" % STAGE_HP_BUDGET
	)
	_check(
		failures,
		_damage_in(ArsenalScript.Kind.SHOTGUN, SHOTGUN_MID_HIT) >= STAGE_HP_BUDGET,
		"shotgun mid-range 60s damage must clear three stages (%s hp)" % STAGE_HP_BUDGET
	)
	_check(
		failures,
		_damage_in(ArsenalScript.Kind.LASER, 1.0) >= STAGE_HP_BUDGET,
		"laser 60s damage must clear three stages (%s hp)" % STAGE_HP_BUDGET
	)


func _damage_in(kind: int, hit_factor: float) -> int:
	var arsenal: RefCounted = ArsenalScript.new(kind)
	var t := 0.0
	var total := 0.0
	while t < COMBAT_SECONDS:
		var volley: RefCounted = arsenal.call("fire", Vector2.ZERO, Vector2.RIGHT, t)
		for shot in volley.get("shots"):
			total += float(shot.get("damage")) * hit_factor
		t += 0.05
	return int(total)


func _muzzle_and_energy_are_neon(failures: PackedStringArray) -> void:
	for kind in [ArsenalScript.Kind.RIFLE, ArsenalScript.Kind.SHOTGUN, ArsenalScript.Kind.LASER]:
		var arsenal: RefCounted = ArsenalScript.new(kind)
		var volley: RefCounted = arsenal.call("fire", Vector2(3, 4), Vector2.UP, 0.0)
		var muzzle: Color = volley.get("muzzle_color")
		_check(failures, _is_neon(muzzle), "kind %s muzzle must be neon, got %s" % [kind, muzzle])
		_check(
			failures,
			volley.get("muzzle_origin") == Vector2(3, 4),
			"kind %s muzzle origin follows the barrel" % kind
		)
		var shots: Array = volley.get("shots")
		_check(failures, not shots.is_empty(), "kind %s fired no shots for neon check" % kind)
		for shot in shots:
			var tint: Color = shot.get("tint")
			_check(failures, _is_neon(tint), "kind %s shot tint must be neon, got %s" % [kind, tint])


func _is_neon(color: Color) -> bool:
	return color.s >= 0.45 and color.v >= 0.7


func _spawned_shot_is_player_not_enemy(failures: PackedStringArray) -> void:
	var arsenal: RefCounted = ArsenalScript.new(ArsenalScript.Kind.RIFLE)
	var volley: RefCounted = arsenal.call("fire", Vector2.ZERO, Vector2.RIGHT, 0.0)
	var shots: Array = volley.get("shots")
	if shots.is_empty():
		_check(failures, false, "rifle spawn check needs a shot")
		return
	var body: Area2D = shots[0].call("instantiate_projectile")
	var expected_layer := 1 << (ArsenalScript.PLAYER_SHOT_LAYER - 1)
	_check(failures, body != null, "player shot must spawn a body")
	if body != null:
		_check(failures, body.collision_layer == expected_layer, "player shot uses PLAYER_SHOT_LAYER")
		_check(
			failures,
			body.get_meta("player_shot") == true,
			"spawned body is marked as a player shot"
		)
		_check(failures, not body.has_meta("enemy_shot"), "arsenal must not spawn enemy shots")
		body.free()
	var muzzle: Node2D = volley.call("instantiate_muzzle")
	_check(failures, muzzle != null, "fired volley must spawn a muzzle flash")
	if muzzle != null:
		_check(failures, muzzle.get_meta("muzzle_flash") == true, "muzzle node is a flash, not a tool")
		muzzle.free()


func _only_three_player_kinds(failures: PackedStringArray) -> void:
	_check(failures, ArsenalScript.Kind.RIFLE == 0, "rifle is kind 0")
	_check(failures, ArsenalScript.Kind.SHOTGUN == 1, "shotgun is kind 1")
	_check(failures, ArsenalScript.Kind.LASER == 2, "laser is kind 2")
	var names: PackedStringArray = PackedStringArray(ArsenalScript.Kind.keys())
	_check(failures, names.size() == 3, "only rifle, shotgun, laser; no enemy kind")
	_check(failures, arsenal_has_no_enemy_fire(), "arsenal must not expose enemy fire")


func arsenal_has_no_enemy_fire() -> bool:
	var dummy: RefCounted = ArsenalScript.new(ArsenalScript.Kind.RIFLE)
	for method_name in ["fire_enemy", "enemy_fire", "spawn_enemy_shot", "hostile_fire"]:
		if dummy.has_method(method_name):
			return false
	return true
