class_name Stages
extends Node

## 三关写死场景：平地练手、高台掩体、短通道头目。不是关卡编辑器。

## 第一关：平地练手。
const STAGE_FLAT := 1
## 第二关：高台掩体。
const STAGE_COVER := 2
## 第三关：短通道头目（产品名：通道头目）。
const STAGE_BOSS := 3
## 可切关卡数。
const STAGE_COUNT := 3

const HOSTILES_PATH := "res://hostiles/hostiles.gd"
const PLAYER_PATH := "res://player/player.gd"
const FLOOR_TOP := 300.0
const FLOOR_THICKNESS := 48.0
const VIEW_WIDTH := 640.0
const VIEW_HEIGHT := 360.0
const BOUND_THICKNESS := 16.0
const WORLD_LAYER := 1
const GRUNT_SPRITE_H := 40
const BOSS_SPRITE_H := 64
const RUNNER_PATROL_HALF := 60.0
const VOID := Color(0.03, 0.04, 0.09)
const NEON := Color(0.12, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.22, 0.86)
const SLAB := Color(0.10, 0.18, 0.32)
const FLOOR_FILL := Color(0.16, 0.26, 0.42)
const COVER_FILL := Color(0.22, 0.10, 0.38)


func _init() -> void:
	var boot := _find_boot()
	if boot != null:
		install(boot)


## 三关写死目录。第三关产品名与 boot 对齐为通道头目。
static func list_stages() -> PackedStringArray:
	return PackedStringArray(["平地练手", "高台掩体", "通道头目"])


## 关卡序号对应的关名。1 平地练手，2 高台掩体，3 通道头目。
static func stage_name(stage_index: int) -> String:
	var names := list_stages()
	if stage_index < 1 or stage_index > names.size():
		return ""
	return names[stage_index - 1]


## 写死场景节点名。第三关是短通道头目。
static func scene_name(stage_index: int) -> String:
	match stage_index:
		STAGE_FLAT:
			return "平地练手"
		STAGE_COVER:
			return "高台掩体"
		STAGE_BOSS:
			return "短通道头目"
		_:
			return ""


## 关卡水平长度。非法序号为 0。
static func stage_length(stage_index: int) -> float:
	if stage_index < 1 or stage_index > STAGE_COUNT:
		return 0.0
	return float(_layout(stage_index)["length"])


## 该关写死的杂兵数量。
static func grunt_count(stage_index: int) -> int:
	if stage_index < 1 or stage_index > STAGE_COUNT:
		return 0
	var slots: Array = _layout(stage_index)["grunts"]
	return slots.size()


## 该关布局槽位数：杂兵条数加头目。小于 1 视为布置失败。
static func layout_slots(stage_index: int) -> int:
	if stage_index < 1 or stage_index > STAGE_COUNT:
		return 0
	var slots := grunt_count(stage_index)
	if has_boss(stage_index):
		slots += 1
	return slots


## 从 player 跳跃常数算出的一跳最大升高。禁止写死与跳跃脱节的像素。
static func max_rise() -> int:
	var jump := absf(_player_constant("JUMP_VELOCITY", -320.0))
	var gravity := _player_constant("GRAVITY", 900.0)
	if gravity <= 0.0:
		return 0
	return int(floor(jump * jump / (2.0 * gravity))) - 8


## 一跳允许的水平间隙，按 player 跑速。
static func max_step_gap() -> float:
	return _player_constant("RUN_SPEED", 140.0) * 0.35


## 相邻布局杂兵站位的最小水平间距，按 player 跑速。
static func min_grunt_spacing() -> float:
	return _player_constant("RUN_SPEED", 140.0) * 1.2


## 恰好两只杂兵时的最小水平间距，按 player 跑速。
static func min_pair_spacing() -> float:
	return _player_constant("RUN_SPEED", 140.0) * 1.5


## 玩家碰撞盒高度，掩体高度下界。
static func player_collision_height() -> float:
	if not ResourceLoader.exists(PLAYER_PATH):
		return 22.0
	var script: Script = load(PLAYER_PATH)
	if script == null or not script.can_instantiate():
		return 22.0
	var probe: Node = script.new()
	var height := 22.0
	for child in probe.get_children():
		if child is CollisionShape2D:
			var shape := (child as CollisionShape2D).shape
			if shape is RectangleShape2D:
				height = (shape as RectangleShape2D).size.y
				break
	probe.free()
	return height


## 树上仍能造成伤害的杂兵/头目数。
static func living_hostile_count(stage: Node) -> int:
	return _living_hostile_count(stage)


## go_to_stage 之后、开火之前，活敌是否等于布局槽位。
static func ready_survival_held(stage: Node) -> bool:
	if stage == null or not is_instance_valid(stage):
		return false
	return bool(stage.get_meta("ready_survival", false))


## 该关是否有高台。
static func has_platforms(stage_index: int) -> bool:
	if stage_index < 1 or stage_index > STAGE_COUNT:
		return false
	var platforms: Array = _layout(stage_index)["platforms"]
	return not platforms.is_empty()


## 该关是否有掩体。
static func has_cover(stage_index: int) -> bool:
	if stage_index < 1 or stage_index > STAGE_COUNT:
		return false
	var covers: Array = _layout(stage_index)["covers"]
	return not covers.is_empty()


## 该关是否有头目。
static func has_boss(stage_index: int) -> bool:
	if stage_index < 1 or stage_index > STAGE_COUNT:
		return false
	return _layout(stage_index)["boss"] != Vector2.ZERO


## 该关是否是短通道。
static func is_corridor(stage_index: int) -> bool:
	if stage_index < 1 or stage_index > STAGE_COUNT:
		return false
	return bool(_layout(stage_index)["corridor"])


## 关卡世界矩形。左上为原点，宽是关长，高是视口高。非法序号为空矩形。
static func stage_bounds(stage_index: int) -> Rect2:
	if stage_index < 1 or stage_index > STAGE_COUNT:
		return Rect2()
	return Rect2(0.0, 0.0, stage_length(stage_index), VIEW_HEIGHT)


## 把角色坐标夹在关卡边界内。非法序号原样返回。
static func clamp_actor(stage_index: int, world_position: Vector2) -> Vector2:
	var bounds := stage_bounds(stage_index)
	if bounds.size == Vector2.ZERO:
		return world_position
	return Vector2(
		clampf(world_position.x, bounds.position.x, bounds.end.x),
		clampf(world_position.y, bounds.position.y, bounds.end.y)
	)


## 把视角中心夹在关卡内，使画面尽量不露出地图外。关卡比视口窄时左对齐。
static func clamp_camera(
	stage_index: int,
	camera_center: Vector2,
	view_size: Vector2 = Vector2.ZERO
) -> Vector2:
	var view := view_size
	if view == Vector2.ZERO:
		view = Vector2(VIEW_WIDTH, VIEW_HEIGHT)
	var bounds := stage_bounds(stage_index)
	if bounds.size == Vector2.ZERO:
		return camera_center
	return Vector2(
		_clamp_center(camera_center.x, bounds.position.x, bounds.end.x, view.x),
		_clamp_center(camera_center.y, bounds.position.y, bounds.end.y, view.y)
	)


## 把角色和视角留在本关边界内。StageHost 在固定 CanvasLayer 下会平移以跟随。
static func keep_inside(
	stage: Node2D,
	actor: Node2D,
	camera: Camera2D = null,
	view_size: Vector2 = Vector2.ZERO
) -> void:
	if stage == null or actor == null:
		return
	var index := int(stage.get_meta("stage_index", 0))
	actor.position = clamp_actor(index, actor.position)
	var cam := camera
	if cam == null:
		cam = stage.get_node_or_null("StageCamera") as Camera2D
	if cam != null:
		cam.position = clamp_camera(index, actor.position, view_size)
		_apply_camera_limits(cam, index)
	_scroll_host(stage, index, actor.position, view_size)


## 建造一关写死场景。非法序号返回 null。
static func build_stage(stage_index: int) -> Node2D:
	if stage_index < 1 or stage_index > STAGE_COUNT:
		return null
	var spec := _layout(stage_index)
	var length := float(spec["length"])
	var root := Node2D.new()
	root.name = scene_name(stage_index)
	root.set_meta("stage_index", stage_index)
	root.set_meta("stage_name", stage_name(stage_index))
	root.set_meta("scene_name", scene_name(stage_index))
	root.set_meta("stage_length", length)
	root.set_meta("player_spawn", spec["spawn"])
	_add_backdrop(root, length)
	_add_stage_bounds(root, length)
	_add_solid(
		root,
		"floor",
		"Floor",
		Vector2(length * 0.5, FLOOR_TOP + FLOOR_THICKNESS * 0.5),
		Vector2(length, FLOOR_THICKNESS),
		FLOOR_FILL,
		NEON
	)
	if bool(spec["corridor"]):
		var ceiling_bottom := float(spec["ceiling_bottom"])
		var ceiling_height := ceiling_bottom
		_add_solid(
			root,
			"corridor",
			"Ceiling",
			Vector2(length * 0.5, ceiling_height * 0.5),
			Vector2(length, ceiling_height),
			SLAB,
			MAGENTA
		)
		_add_solid(
			root,
			"corridor",
			"EndWall",
			Vector2(length - 8.0, (FLOOR_TOP + ceiling_bottom) * 0.5),
			Vector2(16.0, FLOOR_TOP - ceiling_bottom),
			COVER_FILL,
			MAGENTA
		)
	var platform_i := 1
	for platform in spec["platforms"]:
		var rect: Rect2 = platform
		_add_solid(
			root,
			"platform",
			"Platform_%s" % platform_i,
			rect.position + rect.size * 0.5,
			rect.size,
			SLAB,
			NEON
		)
		platform_i += 1
	var cover_i := 1
	for cover in spec["covers"]:
		var box: Rect2 = cover
		_add_solid(
			root,
			"cover",
			"Cover_%s" % cover_i,
			box.position + box.size * 0.5,
			box.size,
			COVER_FILL,
			MAGENTA
		)
		cover_i += 1
	var spawn := Marker2D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = spec["spawn"]
	spawn.set_meta("stage_part", "spawn")
	root.add_child(spawn)
	var grunt_i := 1
	for slot in spec["grunts"]:
		var grunt := _slot_as_dict(slot, "runner")
		var pos: Vector2 = grunt["pos"]
		var unit := _make_hostile(
			"grunt",
			pos,
			float(grunt["min_x"]),
			float(grunt["max_x"]),
			str(grunt["duty"])
		)
		unit.name = "Grunt_%s" % grunt_i
		root.add_child(unit)
		grunt_i += 1
	var boss_pos: Vector2 = spec["boss"]
	if boss_pos != Vector2.ZERO:
		var boss := _make_hostile("boss", boss_pos, boss_pos.x, boss_pos.x, "boss")
		boss.name = "Boss"
		root.add_child(boss)
	var slots := layout_slots(stage_index)
	var living := _living_hostile_count(root)
	root.set_meta("layout_slots", slots)
	root.set_meta("hostile_count", living)
	root.set_meta("ready_survival", slots >= 1 and living == slots)
	_add_clear_watcher(root)
	return root


## 把三关工厂交给 boot.register_stage。
static func install(boot: Object) -> void:
	if boot == null or not boot.has_method("register_stage"):
		return
	for index in range(1, STAGE_COUNT + 1):
		boot.call("register_stage", index, Callable(Stages, "build_stage").bind(index))


## 打完当前关后的下一关。第三关之后没有下一关，返回 0。
static func next_stage(stage_index: int) -> int:
	if stage_index < 1 or stage_index >= STAGE_COUNT:
		return 0
	return stage_index + 1


## 本关是否已清空：就绪存活曾成立，且每一个该打倒的布局槽位都已死。
static func is_cleared(stage: Node) -> bool:
	if stage == null or not is_instance_valid(stage):
		return false
	if not bool(stage.get_meta("ready_survival", false)):
		return false
	var index := int(stage.get_meta("stage_index", 0))
	if has_boss(index):
		return _boss_is_dead(stage)
	var expected := int(stage.get_meta("layout_slots", 0))
	if expected < 1:
		expected = layout_slots(index)
	if expected < 1:
		return false
	if _count_hostiles(stage) != expected:
		return false
	return _living_hostile_count(stage) == 0


## 打完则切到下一关。未清空、已是第三关、或没有 boot.go_to_stage 则不切。返回切到的关号，未切为 0。
static func advance_if_cleared(boot: Object, stage: Node) -> int:
	if stage == null or not is_instance_valid(stage):
		return 0
	if not is_cleared(stage):
		return 0
	var nxt := next_stage(int(stage.get_meta("stage_index", 0)))
	if nxt < 1:
		return 0
	var target := boot
	if target == null or not is_instance_valid(target) or not target.has_method("go_to_stage"):
		target = _boot_of(stage)
	if target == null or not is_instance_valid(target) or not target.has_method("go_to_stage"):
		return 0
	target.call("go_to_stage", nxt)
	return nxt


static func _find_boot() -> Object:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var root := (loop as SceneTree).root
		if root != null:
			return root.get_node_or_null("Boot")
	return null


static func _boot_of(stage: Node) -> Object:
	var node := stage
	while node != null:
		if node.has_method("go_to_stage"):
			return node
		node = node.get_parent()
	return null


static func _add_clear_watcher(parent: Node2D) -> void:
	var watcher_script: Script = load("res://stages/clear_watcher.gd")
	if watcher_script == null or not watcher_script.can_instantiate():
		return
	var watcher: Node = watcher_script.new()
	watcher.name = "ClearWatcher"
	parent.add_child(watcher)


static func _is_hostile_part(node: Node) -> bool:
	var part := str(node.get_meta("stage_part", ""))
	return part == "grunt" or part == "boss"


static func _is_living(unit: Node) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	if "alive" in unit:
		return bool(unit.alive)
	return bool(unit.get_meta("alive", true))


static func _collect_hostiles(node: Node, into: Array[Node]) -> void:
	if _is_hostile_part(node):
		into.append(node)
	for child in node.get_children():
		_collect_hostiles(child, into)


static func _count_hostiles(node: Node) -> int:
	var hostiles: Array[Node] = []
	_collect_hostiles(node, hostiles)
	return hostiles.size()


static func _living_hostile_count(node: Node) -> int:
	var hostiles: Array[Node] = []
	_collect_hostiles(node, hostiles)
	var living := 0
	for unit in hostiles:
		if _is_living(unit):
			living += 1
	return living


static func _layout(stage_index: int) -> Dictionary:
	var rise := float(max_rise())
	var cover_h := rise
	var cover_top := FLOOR_TOP - cover_h
	match stage_index:
		STAGE_FLAT:
			var length := 640.0
			return {
				"length": length,
				"corridor": false,
				"ceiling_bottom": 0.0,
				"platforms": [],
				"covers": [],
				"grunts": [
					_grunt_spec("runner", 200.0, FLOOR_TOP, length),
					_grunt_spec("runner", 380.0, FLOOR_TOP, length),
					_grunt_spec("runner", 560.0, FLOOR_TOP, length),
				],
				"boss": Vector2.ZERO,
				"spawn": _stand_on(48.0, FLOOR_TOP, GRUNT_SPRITE_H),
			}
		STAGE_COVER:
			var length := 720.0
			var p1_top := FLOOR_TOP - rise
			var p2_top := p1_top - rise
			return {
				"length": length,
				"corridor": false,
				"ceiling_bottom": 0.0,
				"platforms": [
					Rect2(200.0, p1_top, 96.0, 12.0),
					Rect2(280.0, p2_top, 112.0, 12.0),
				],
				"covers": [
					Rect2(88.0, cover_top, 24.0, cover_h),
					Rect2(600.0, cover_top, 24.0, cover_h),
				],
				"grunts": [
					_grunt_spec("runner", 140.0, FLOOR_TOP, length),
					_grunt_spec("runner", 520.0, FLOOR_TOP, length),
					_grunt_spec("sentry", 248.0, p1_top, length),
					_grunt_spec("sentry", 336.0, p2_top, length),
				],
				"boss": Vector2.ZERO,
				"spawn": _stand_on(48.0, FLOOR_TOP, GRUNT_SPRITE_H),
			}
		STAGE_BOSS:
			var length := 420.0
			return {
				"length": length,
				"corridor": true,
				"ceiling_bottom": 200.0,
				"platforms": [],
				"covers": [],
				"grunts": [
					_grunt_spec("sentry", 150.0, FLOOR_TOP, length),
				],
				"boss": _stand_on(356.0, FLOOR_TOP, BOSS_SPRITE_H),
				"spawn": _stand_on(40.0, FLOOR_TOP, GRUNT_SPRITE_H),
			}
		_:
			return {}


static func _grunt_spec(duty: String, x: float, surface_top: float, length: float) -> Dictionary:
	var pos := _stand_on(x, surface_top, GRUNT_SPRITE_H)
	var min_x := pos.x
	var max_x := pos.x
	if duty == "runner":
		min_x = maxf(8.0, pos.x - RUNNER_PATROL_HALF)
		max_x = minf(length - 8.0, pos.x + RUNNER_PATROL_HALF)
	return {
		"duty": duty,
		"pos": pos,
		"min_x": min_x,
		"max_x": max_x,
	}


static func _slot_as_dict(slot: Variant, default_duty: String) -> Dictionary:
	if slot is Dictionary:
		var spec: Dictionary = slot
		var pos: Vector2 = spec["pos"]
		return {
			"duty": str(spec.get("duty", default_duty)),
			"pos": pos,
			"min_x": float(spec.get("min_x", pos.x)),
			"max_x": float(spec.get("max_x", pos.x)),
		}
	var stand: Vector2 = slot
	return {
		"duty": default_duty,
		"pos": stand,
		"min_x": stand.x - RUNNER_PATROL_HALF,
		"max_x": stand.x + RUNNER_PATROL_HALF,
	}


static func _player_constant(name: String, fallback: float) -> float:
	if not ResourceLoader.exists(PLAYER_PATH):
		return fallback
	var script: Script = load(PLAYER_PATH)
	if script == null:
		return fallback
	var constants: Dictionary = script.get_script_constant_map()
	if not constants.has(name):
		return fallback
	var value: Variant = constants[name]
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return fallback


static func _boss_is_dead(stage: Node) -> bool:
	var bosses: Array[Node] = []
	_collect_parts(stage, "boss", bosses)
	if bosses.is_empty():
		return false
	for unit in bosses:
		if _is_living(unit):
			return false
	return true


static func _collect_parts(node: Node, part: String, into: Array[Node]) -> void:
	if str(node.get_meta("stage_part", "")) == part:
		into.append(node)
	for child in node.get_children():
		_collect_parts(child, part, into)


static func _clamp_center(center: float, bound_min: float, bound_max: float, view_span: float) -> float:
	var half := view_span * 0.5
	var lo := bound_min + half
	var hi := bound_max - half
	if lo > hi:
		return lo
	return clampf(center, lo, hi)


static func _apply_camera_limits(camera: Camera2D, stage_index: int) -> void:
	var bounds := stage_bounds(stage_index)
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	camera.limit_smoothed = false
	camera.position_smoothing_enabled = false


static func _scroll_host(
	stage: Node2D,
	stage_index: int,
	actor_pos: Vector2,
	view_size: Vector2
) -> void:
	var host := stage.get_parent()
	if host == null or not (host is Node2D) or str(host.name) != "StageHost":
		return
	var view := view_size
	if view == Vector2.ZERO:
		view = Vector2(VIEW_WIDTH, VIEW_HEIGHT)
	var cam_center := clamp_camera(stage_index, actor_pos, view)
	(host as Node2D).position = -(cam_center - view * 0.5)


static func _add_stage_bounds(parent: Node2D, length: float) -> void:
	var height := VIEW_HEIGHT + FLOOR_THICKNESS
	_add_solid(
		parent,
		"bound",
		"LeftBound",
		Vector2(-BOUND_THICKNESS * 0.5, height * 0.5),
		Vector2(BOUND_THICKNESS, height),
		SLAB,
		NEON
	)
	_add_solid(
		parent,
		"bound",
		"RightBound",
		Vector2(length + BOUND_THICKNESS * 0.5, height * 0.5),
		Vector2(BOUND_THICKNESS, height),
		SLAB,
		NEON
	)
	var cam := Camera2D.new()
	cam.name = "StageCamera"
	cam.enabled = true
	cam.position = Vector2(VIEW_WIDTH * 0.5, VIEW_HEIGHT * 0.5)
	cam.set_meta("stage_part", "camera")
	_apply_camera_limits(cam, int(parent.get_meta("stage_index", 0)))
	parent.add_child(cam)
	var keeper_script: Script = load("res://stages/bound_keeper.gd")
	if keeper_script != null and keeper_script.can_instantiate():
		var keeper: Node = keeper_script.new()
		keeper.name = "BoundKeeper"
		parent.add_child(keeper)


static func _add_backdrop(parent: Node2D, length: float) -> void:
	var backdrop := Sprite2D.new()
	backdrop.name = "Backdrop"
	backdrop.centered = false
	backdrop.texture = _fill_texture(VOID, int(length), int(VIEW_HEIGHT))
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.z_index = -10
	backdrop.set_meta("stage_part", "backdrop")
	parent.add_child(backdrop)


static func _stand_on(x: float, surface_top: float, sprite_h: int) -> Vector2:
	return Vector2(x, surface_top - float(sprite_h) * 0.5)


static func _add_solid(
	parent: Node2D,
	part: String,
	node_name: String,
	center: Vector2,
	size: Vector2,
	fill: Color,
	edge: Color
) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = center
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.set_meta("stage_part", part)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var sprite := Sprite2D.new()
	sprite.visible = true
	sprite.modulate = Color.WHITE
	sprite.self_modulate = Color.WHITE
	sprite.texture = _slab_texture(fill, edge, maxi(int(size.x), 2), maxi(int(size.y), 2))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(sprite)
	parent.add_child(body)


static func _make_hostile(
	kind: String,
	pos: Vector2,
	min_x: float,
	max_x: float,
	duty: String = ""
) -> Node2D:
	var slot_duty := duty if duty != "" else kind
	var unit: Node2D = _try_hostiles_unit(kind, pos, min_x, max_x, slot_duty)
	var stand_in := unit == null
	if stand_in:
		unit = _stand_in_hostile(kind, pos)
	unit.set_meta("stage_part", kind)
	unit.set_meta("duty", slot_duty)
	unit.set_meta("alive", true)
	unit.set_meta("hostile_stand_in", stand_in)
	if not _has_visible_pixel_body(unit):
		_attach_pixel_body(unit, kind)
	return unit


static func _try_hostiles_unit(
	kind: String,
	pos: Vector2,
	min_x: float,
	max_x: float,
	duty: String
) -> Node2D:
	if not ResourceLoader.exists(HOSTILES_PATH):
		return null
	var script: Script = load(HOSTILES_PATH)
	if script == null or not script.can_instantiate():
		return null
	var inst: Node = script.new()
	if inst == null or not (inst is Node2D):
		if inst != null and inst is Node:
			inst.free()
		return null
	var unit := inst as Node2D
	if (kind == "boss" or duty == "boss") and unit.has_method("configure_boss"):
		unit.call("configure_boss", pos)
	elif unit.has_method("configure_grunt"):
		if duty == "sentry":
			unit.call("configure_grunt", pos, pos.x, pos.x)
		else:
			unit.call("configure_grunt", pos, min_x, max_x)
	else:
		unit.position = pos
	return unit


static func _stand_in_hostile(kind: String, pos: Vector2) -> Sprite2D:
	var body := Sprite2D.new()
	body.position = pos
	body.centered = true
	body.z_index = 2
	body.visible = true
	body.modulate = Color.WHITE
	body.self_modulate = Color.WHITE
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.texture = _boss_pixel_texture() if kind == "boss" else _grunt_pixel_texture()
	return body


static func _attach_pixel_body(unit: Node2D, kind: String) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "PixelBody"
	sprite.centered = true
	sprite.z_index = 2
	sprite.visible = true
	sprite.modulate = Color.WHITE
	sprite.self_modulate = Color.WHITE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = _boss_pixel_texture() if kind == "boss" else _grunt_pixel_texture()
	unit.add_child(sprite)


static func _has_visible_pixel_body(node: Node) -> bool:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return false
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.modulate.a >= 0.5 and sprite.self_modulate.a >= 0.5 and sprite.texture != null:
			var image: Image = sprite.texture.get_image()
			if image != null and _opaque_pixel_count(image) >= 16:
				return true
	for child in node.get_children():
		if _has_visible_pixel_body(child):
			return true
	return false


static func _opaque_pixel_count(image: Image) -> int:
	var total := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a >= 0.5:
				total += 1
	return total


static func _grunt_pixel_texture() -> ImageTexture:
	const WIDTH := 32
	const HEIGHT := 40
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var hull := Color(0.10, 0.32, 0.52)
	var rim := Color(0.15, 0.98, 1.0)
	var visor := Color(1.0, 0.28, 0.88)
	var core := Color(0.25, 1.0, 0.62)
	for y in range(10, 32):
		for x in range(6, 26):
			image.set_pixel(x, y, hull)
	for y in range(11, 31):
		image.set_pixel(6, y, rim)
		image.set_pixel(25, y, rim)
	for x in range(7, 25):
		image.set_pixel(x, 10, rim)
	for y in range(2, 12):
		for x in range(10, 22):
			image.set_pixel(x, y, visor)
	image.set_pixel(8, 5, visor)
	image.set_pixel(23, 5, visor)
	for y in range(32, 40):
		for x in range(12, 20):
			image.set_pixel(x, y, core)
	image.set_pixel(10, 34, core)
	image.set_pixel(21, 34, core)
	return ImageTexture.create_from_image(image)


static func _boss_pixel_texture() -> ImageTexture:
	const WIDTH := 48
	const HEIGHT := 64
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var hull := Color(0.22, 0.10, 0.42)
	var rim := Color(0.72, 0.28, 1.0)
	var visor := Color(1.0, 0.24, 0.86)
	var core := Color(0.18, 1.0, 0.90)
	for y in range(14, 58):
		for x in range(6, 42):
			image.set_pixel(x, y, hull)
	for y in range(15, 57):
		image.set_pixel(6, y, rim)
		image.set_pixel(41, y, rim)
	for x in range(7, 41):
		image.set_pixel(x, 14, rim)
	for y in range(2, 16):
		for x in range(14, 34):
			image.set_pixel(x, y, visor)
	for y in range(26, 38):
		for x in range(18, 30):
			image.set_pixel(x, y, core)
	image.set_pixel(22, 0, rim)
	image.set_pixel(23, 0, rim)
	image.set_pixel(24, 0, rim)
	image.set_pixel(25, 0, rim)
	image.set_pixel(22, 1, visor)
	image.set_pixel(23, 1, visor)
	image.set_pixel(24, 1, visor)
	image.set_pixel(25, 1, visor)
	return ImageTexture.create_from_image(image)


static func _slab_texture(fill: Color, edge: Color, width: int, height: int) -> ImageTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(fill)
	var plate := 16
	var seam := Color(fill.r * 0.55, fill.g * 0.55, fill.b * 0.55, 1.0)
	for x in range(0, width, plate):
		for y in range(height):
			image.set_pixel(x, y, seam)
	for y in range(0, height, plate):
		for x in range(width):
			image.set_pixel(x, y, seam)
	var rim := mini(3, height)
	for y in range(rim):
		for x in range(width):
			image.set_pixel(x, y, edge)
	return ImageTexture.create_from_image(image)


static func _fill_texture(color: Color, width: int, height: int) -> ImageTexture:
	var image := Image.create(maxi(width, 1), maxi(height, 1), false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
