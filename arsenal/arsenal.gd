class_name Arsenal
extends RefCounted

## 玩家武器库：步枪、散弹枪、激光枪与子弹数值。敌人子弹不走本模块。
enum Kind { RIFLE, SHOTGUN, LASER }

## 玩家弹体所在物理层。敌弹不得占用。
const PLAYER_SHOT_LAYER := 4
## 玩家弹体检测地面与杂兵/头目。
const PLAYER_SHOT_MASK := 1 | 4

var _kind: Kind
var _last_fire_sec: float = -1000.0


func _init(kind: Kind = Kind.RIFLE) -> void:
	_kind = kind


## 当前选中的玩家武器。
func get_kind() -> Kind:
	return _kind


## 从枪口朝 facing 开火。冷却中或朝向为零时返回空齐射。
func fire(origin: Vector2, facing: Vector2, now_sec: float) -> Volley:
	var volley := Volley.new()
	if facing.length_squared() < 0.0001:
		return volley
	var profile := _profile(_kind)
	var cooldown := float(profile["cooldown"])
	if now_sec - _last_fire_sec < cooldown:
		return volley
	_last_fire_sec = now_sec
	var direction := facing.normalized()
	volley.fired = true
	volley.muzzle_origin = origin
	volley.muzzle_color = profile["muzzle"]
	var pellets := int(profile["pellets"])
	var spread := float(profile["spread"])
	for i in pellets:
		var shot := Shot.new()
		var turn := 0.0
		if pellets > 1:
			turn = (float(i) / float(pellets - 1) * 2.0 - 1.0) * spread
		shot.origin = origin
		shot.velocity = direction.rotated(turn) * float(profile["speed"])
		shot.damage = int(profile["damage"])
		shot.max_range = float(profile["max_range"])
		shot.pierce = bool(profile["pierce"])
		shot.is_energy = bool(profile["energy"])
		shot.tint = profile["tint"]
		shot.radius = float(profile["radius"])
		shot.kind = _kind
		volley.shots.append(shot)
	return volley


func _profile(kind: Kind) -> Dictionary:
	# Numbers keep 60s mid-range fire above 208 HP so all three loadouts
	# can finish 平地练手 / 高台掩体 / 通道头目.
	match kind:
		Kind.SHOTGUN:
			return {
				"damage": 2,
				"cooldown": 0.38,
				"speed": 380.0,
				"max_range": 128.0,
				"pellets": 5,
				"spread": 0.35,
				"pierce": false,
				"energy": false,
				"radius": 2.0,
				"muzzle": Color(1.0, 0.55, 0.12),
				"tint": Color(1.0, 0.82, 0.28),
			}
		Kind.LASER:
			return {
				"damage": 3,
				"cooldown": 0.16,
				"speed": 900.0,
				"max_range": 640.0,
				"pellets": 1,
				"spread": 0.0,
				"pierce": true,
				"energy": true,
				"radius": 2.0,
				"muzzle": Color(1.0, 0.18, 0.86),
				"tint": Color(1.0, 0.42, 1.0),
			}
		_:
			return {
				"damage": 2,
				"cooldown": 0.12,
				"speed": 520.0,
				"max_range": 560.0,
				"pellets": 1,
				"spread": 0.0,
				"pierce": false,
				"energy": false,
				"radius": 2.0,
				"muzzle": Color(0.38, 0.95, 1.0),
				"tint": Color(0.12, 0.95, 1.0),
			}


class Pixels:
	extends RefCounted

	static func texture(color: Color, width: int, height: int) -> ImageTexture:
		var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
		image.fill(color)
		return ImageTexture.create_from_image(image)


class Shot:
	extends RefCounted

	## 枪口世界坐标。
	var origin: Vector2 = Vector2.ZERO
	## 弹体速度，像素/秒。
	var velocity: Vector2 = Vector2.ZERO
	## 命中伤害。
	var damage: int = 0
	## 最远飞行距离，像素。
	var max_range: float = 0.0
	## 激光穿过目标；步枪与散弹停在第一击。
	var pierce: bool = false
	## 能量弹（激光）与实弹区分，供霓虹描画。
	var is_energy: bool = false
	## 弹体霓虹色。
	var tint: Color = Color.WHITE
	## 碰撞半宽近似。
	var radius: float = 2.0
	## 发出该弹的武器。
	var kind: int = 0

	## 生成玩家弹体节点。敌弹不得调用。
	func instantiate_projectile() -> Area2D:
		var body := PlayerProjectile.new()
		body.setup(self)
		return body


class Volley:
	extends RefCounted

	## 本次是否真正出膛。
	var fired: bool = false
	## 枪口闪光位置。
	var muzzle_origin: Vector2 = Vector2.ZERO
	## 枪口霓虹色。
	var muzzle_color: Color = Color.BLACK
	## 本次玩家弹。空数组表示没打出。
	var shots: Array[Shot] = []

	## 生成枪口闪光。未开火时返回 null。
	func instantiate_muzzle() -> Sprite2D:
		if not fired:
			return null
		var flash := MuzzleFlash.new()
		flash.setup(muzzle_origin, muzzle_color)
		return flash


class PlayerProjectile:
	extends Area2D

	const _LAYER := 4
	const _MASK := 1 | 4

	var _velocity: Vector2 = Vector2.ZERO
	var _max_range: float = 0.0
	var _travelled: float = 0.0
	var _hit_ids: Dictionary = {}
	var damage: int = 0
	var pierce: bool = false

	func setup(shot: Shot) -> void:
		position = shot.origin
		_velocity = shot.velocity
		_max_range = shot.max_range
		damage = shot.damage
		pierce = shot.pierce
		collision_layer = 1 << (_LAYER - 1)
		collision_mask = _MASK
		monitoring = true
		monitorable = true
		set_meta("player_shot", true)
		set_meta("damage", shot.damage)
		set_meta("pierce", shot.pierce)
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
		var sprite := Sprite2D.new()
		var width := 10 if shot.is_energy else 4
		var height := 2 if shot.is_energy else 4
		sprite.texture = Pixels.texture(shot.tint, width, height)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if _velocity.length_squared() > 0.0:
			sprite.rotation = _velocity.angle()
		add_child(sprite)
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(float(width), float(height))
		col.shape = shape
		add_child(col)

	## 玩家弹打中地面或杂兵/头目。命中杂兵头目扣血；步枪与散弹停在第一击，激光穿过目标。
	func resolve_hit(body: Node) -> void:
		if body == null or not is_instance_valid(body):
			return
		if is_queued_for_deletion():
			return
		var id := body.get_instance_id()
		if _hit_ids.has(id):
			return
		_hit_ids[id] = true
		if body.has_method("take_damage") and body.get("alive") != null:
			body.call("take_damage", damage)
			if not pierce:
				queue_free()
			return
		queue_free()

	func _on_body_entered(body: Node) -> void:
		resolve_hit(body)

	func _physics_process(delta: float) -> void:
		var step := _velocity.length() * delta
		position += _velocity * delta
		_travelled += step
		if _travelled >= _max_range:
			queue_free()
			return
		_resolve_overlaps()

	func _resolve_overlaps() -> void:
		if not is_inside_tree() or not monitoring:
			return
		for body in get_overlapping_bodies():
			resolve_hit(body)
			if is_queued_for_deletion():
				return


class MuzzleFlash:
	extends Sprite2D

	var _life: float = 0.06

	func setup(origin: Vector2, color: Color) -> void:
		position = origin
		texture = Pixels.texture(color, 6, 6)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		set_meta("muzzle_flash", true)

	func _process(delta: float) -> void:
		_life -= delta
		if _life <= 0.0:
			queue_free()
