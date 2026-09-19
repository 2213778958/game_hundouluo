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
const FLOOR_TOP := 300.0
const FLOOR_THICKNESS := 40.0
const VIEW_HEIGHT := 360.0
const WORLD_LAYER := 1
const VOID := Color(0.03, 0.04, 0.09)
const NEON := Color(0.12, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.22, 0.86)
const SLAB := Color(0.07, 0.12, 0.22)
const COVER_FILL := Color(0.14, 0.08, 0.26)


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
	_add_solid(
		root,
		"floor",
		"Floor",
		Vector2(length * 0.5, FLOOR_TOP + FLOOR_THICKNESS * 0.5),
		Vector2(length, FLOOR_THICKNESS),
		SLAB,
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
		var pos: Vector2 = slot
		var unit := _make_hostile("grunt", pos, pos.x - 36.0, pos.x + 36.0)
		unit.name = "Grunt_%s" % grunt_i
		root.add_child(unit)
		grunt_i += 1
	var boss_pos: Vector2 = spec["boss"]
	if boss_pos != Vector2.ZERO:
		var boss := _make_hostile("boss", boss_pos, boss_pos.x, boss_pos.x)
		boss.name = "Boss"
		root.add_child(boss)
	return root


## 把三关工厂交给 boot.register_stage。
static func install(boot: Object) -> void:
	if boot == null or not boot.has_method("register_stage"):
		return
	for index in range(1, STAGE_COUNT + 1):
		boot.call("register_stage", index, Callable(Stages, "build_stage").bind(index))


static func _find_boot() -> Object:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var root := (loop as SceneTree).root
		if root != null:
			return root.get_node_or_null("Boot")
	return null


static func _layout(stage_index: int) -> Dictionary:
	match stage_index:
		STAGE_FLAT:
			return {
				"length": 640.0,
				"corridor": false,
				"ceiling_bottom": 0.0,
				"platforms": [],
				"covers": [],
				"grunts": [Vector2(280.0, 284.0), Vector2(460.0, 284.0)],
				"boss": Vector2.ZERO,
				"spawn": Vector2(48.0, 284.0),
			}
		STAGE_COVER:
			return {
				"length": 720.0,
				"corridor": false,
				"ceiling_bottom": 0.0,
				"platforms": [
					Rect2(168.0, 220.0, 96.0, 12.0),
					Rect2(336.0, 176.0, 112.0, 12.0),
					Rect2(520.0, 220.0, 96.0, 12.0),
				],
				"covers": [
					Rect2(248.0, 252.0, 16.0, 48.0),
					Rect2(400.0, 252.0, 16.0, 48.0),
					Rect2(568.0, 252.0, 16.0, 48.0),
				],
				"grunts": [
					Vector2(220.0, 284.0),
					Vector2(380.0, 284.0),
					Vector2(620.0, 284.0),
					Vector2(216.0, 208.0),
					Vector2(392.0, 164.0),
				],
				"boss": Vector2.ZERO,
				"spawn": Vector2(48.0, 284.0),
			}
		STAGE_BOSS:
			return {
				"length": 420.0,
				"corridor": true,
				"ceiling_bottom": 200.0,
				"platforms": [],
				"covers": [],
				"grunts": [],
				"boss": Vector2(356.0, 280.0),
				"spawn": Vector2(40.0, 284.0),
			}
		_:
			return {}


static func _add_backdrop(parent: Node2D, length: float) -> void:
	var backdrop := Sprite2D.new()
	backdrop.name = "Backdrop"
	backdrop.centered = false
	backdrop.texture = _fill_texture(VOID, int(length), int(VIEW_HEIGHT))
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.z_index = -10
	backdrop.set_meta("stage_part", "backdrop")
	parent.add_child(backdrop)


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
	sprite.texture = _slab_texture(fill, edge, maxi(int(size.x), 2), maxi(int(size.y), 2))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(sprite)
	parent.add_child(body)


static func _make_hostile(kind: String, pos: Vector2, min_x: float, max_x: float) -> Node2D:
	var unit: Node2D = _try_hostiles_unit(kind, pos, min_x, max_x)
	if unit == null:
		unit = _stand_in_hostile(kind, pos)
	unit.set_meta("stage_part", kind)
	if not _has_visible_pixel_body(unit):
		_attach_pixel_body(unit, kind)
	return unit


static func _try_hostiles_unit(kind: String, pos: Vector2, min_x: float, max_x: float) -> Node2D:
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
	if kind == "boss" and unit.has_method("configure_boss"):
		unit.call("configure_boss", pos)
	elif unit.has_method("configure_grunt"):
		unit.call("configure_grunt", pos, min_x, max_x)
	else:
		unit.position = pos
	return unit


static func _stand_in_hostile(kind: String, pos: Vector2) -> Sprite2D:
	var body := Sprite2D.new()
	body.position = pos
	body.centered = true
	body.z_index = 1
	body.visible = true
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.texture = _boss_pixel_texture() if kind == "boss" else _grunt_pixel_texture()
	return body


static func _attach_pixel_body(unit: Node2D, kind: String) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "PixelBody"
	sprite.centered = true
	sprite.z_index = 1
	sprite.visible = true
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
	const WIDTH := 16
	const HEIGHT := 20
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var hull := Color(0.06, 0.18, 0.34)
	var rim := Color(0.15, 0.98, 1.0)
	var visor := Color(1.0, 0.28, 0.88)
	var core := Color(0.25, 1.0, 0.62)
	for y in range(5, 16):
		for x in range(3, 13):
			image.set_pixel(x, y, hull)
	for y in range(6, 15):
		image.set_pixel(3, y, rim)
		image.set_pixel(12, y, rim)
	for x in range(4, 12):
		image.set_pixel(x, 5, rim)
	for y in range(2, 6):
		for x in range(5, 11):
			image.set_pixel(x, y, visor)
	image.set_pixel(4, 3, visor)
	image.set_pixel(11, 3, visor)
	for y in range(16, 20):
		for x in range(6, 10):
			image.set_pixel(x, y, core)
	image.set_pixel(5, 17, core)
	image.set_pixel(10, 17, core)
	return ImageTexture.create_from_image(image)


static func _boss_pixel_texture() -> ImageTexture:
	const WIDTH := 24
	const HEIGHT := 32
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var hull := Color(0.14, 0.08, 0.30)
	var rim := Color(0.62, 0.22, 1.0)
	var visor := Color(1.0, 0.24, 0.86)
	var core := Color(0.18, 1.0, 0.90)
	for y in range(7, 29):
		for x in range(3, 21):
			image.set_pixel(x, y, hull)
	for y in range(8, 28):
		image.set_pixel(3, y, rim)
		image.set_pixel(20, y, rim)
	for x in range(4, 20):
		image.set_pixel(x, 7, rim)
	for y in range(2, 8):
		for x in range(7, 17):
			image.set_pixel(x, y, visor)
	for y in range(13, 19):
		for x in range(9, 15):
			image.set_pixel(x, y, core)
	image.set_pixel(11, 0, rim)
	image.set_pixel(12, 0, rim)
	image.set_pixel(11, 1, visor)
	image.set_pixel(12, 1, visor)
	return ImageTexture.create_from_image(image)


static func _slab_texture(fill: Color, edge: Color, width: int, height: int) -> ImageTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(fill)
	var rim := mini(2, height)
	for y in range(rim):
		for x in range(width):
			image.set_pixel(x, y, edge)
	return ImageTexture.create_from_image(image)


static func _fill_texture(color: Color, width: int, height: int) -> ImageTexture:
	var image := Image.create(maxi(width, 1), maxi(height, 1), false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
