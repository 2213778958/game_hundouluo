class_name Hostile
extends CharacterBody2D

## 杂兵会走会射；第三关头目会开枪，打倒即通关。敌弹留在本模块。

enum Role { GRUNT, BOSS }

## 第三关头目所在关序号。打倒后 `stage_cleared` 带这个值。
const STAGE_BOSS := 3
## 杂兵血量。
const GRUNT_HP := 8
## 头目血量。
const BOSS_HP := 104
## 杂兵水平走速，像素/秒。
const GRUNT_WALK_SPEED := 56.0
const GRAVITY := 900.0
const MUZZLE_OFFSET := 10.0
## 杂兵与头目身体物理层。
const BODY_LAYER := 4
## 敌弹物理层。不占用玩家弹层。
const SHOT_LAYER := 16
## 敌弹检测地面与玩家。
const SHOT_MASK := 1 | 2
const GRUNT_COOLDOWN := 0.9
const BOSS_COOLDOWN := 0.5
const GRUNT_SHOT_SPEED := 200.0
const BOSS_SHOT_SPEED := 280.0
const GRUNT_SHOT_DAMAGE := 1
const BOSS_SHOT_DAMAGE := 2
const GRUNT_SHOT_RANGE := 320.0
const BOSS_SHOT_RANGE := 520.0
const GRUNT_MUZZLE := Color(0.25, 1.0, 0.85)
const GRUNT_SHOT_TINT := Color(0.15, 0.95, 1.0)
const BOSS_MUZZLE := Color(1.0, 0.22, 0.9)
const BOSS_SHOT_TINT := Color(1.0, 0.35, 1.0)
## 打倒后侧躺，避免仍像站着的活人。
const DEATH_FALL_RADIANS := PI * 0.5
## 尸体变暗，和活着的霓虹外壳分开。
const DEATH_MODULATE := Color(0.55, 0.62, 0.72)

## 当前身份：杂兵或头目。
var role: Role = Role.GRUNT
## 当前血量。
var hp: int = GRUNT_HP
## 是否还活着。
var alive: bool = true
## 水平朝向，开火与精灵翻转用。
var facing: Vector2 = Vector2.LEFT
## 杂兵巡逻左界。
var patrol_min_x: float = -100000.0
## 杂兵巡逻右界。
var patrol_max_x: float = 100000.0

var _last_fire_sec: float = -1000.0

## 杂兵或头目被打倒。
signal defeated
## 头目被打倒，第三关通关。杂兵不会发这个信号。
signal stage_cleared(stage_index: int)


func _init() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	collision_layer = BODY_LAYER
	collision_mask = 1
	_setup_body(Vector2(12, 18))
	_setup_look(_drone_texture())
	configure_grunt(Vector2.ZERO)


## 配置为会走会射的杂兵。外形是未来无人机。
func configure_grunt(spawn: Vector2, min_x: float = -100000.0, max_x: float = 100000.0) -> void:
	role = Role.GRUNT
	hp = GRUNT_HP
	alive = true
	facing = Vector2.LEFT
	patrol_min_x = min_x
	patrol_max_x = max_x
	position = spawn
	velocity = Vector2.ZERO
	_last_fire_sec = -1000.0
	_resize_body(Vector2(12, 18))
	_set_texture(_drone_texture())
	_apply_alive_look()


## 配置为第三关头目。打倒即通关。
func configure_boss(spawn: Vector2) -> void:
	role = Role.BOSS
	hp = BOSS_HP
	alive = true
	facing = Vector2.LEFT
	patrol_min_x = spawn.x
	patrol_max_x = spawn.x
	position = spawn
	velocity = Vector2.ZERO
	_last_fire_sec = -1000.0
	_resize_body(Vector2(18, 28))
	_set_texture(_boss_texture())
	_apply_alive_look()


## 杂兵水平走动。头目站住。axis 为 -1、0、1。
func apply_walk(axis: float) -> void:
	if not alive or role != Role.GRUNT:
		velocity.x = 0.0
		return
	velocity.x = axis * GRUNT_WALK_SPEED
	if absf(axis) > 0.01:
		facing = Vector2.RIGHT if axis > 0.0 else Vector2.LEFT
		_face_sprite()


## 不聪明：朝目标水平转向。不寻路。打倒后不再转身。
func face_toward(world_pos: Vector2) -> void:
	if not alive:
		return
	if world_pos.x < position.x:
		facing = Vector2.LEFT
	elif world_pos.x > position.x:
		facing = Vector2.RIGHT
	_face_sprite()


## 不进树时推进杂兵走动。头目不走。
func step(delta: float) -> void:
	if not alive or role != Role.GRUNT:
		velocity.x = 0.0
		return
	_update_patrol_velocity()
	position.x += velocity.x * delta


## 朝 facing 开火。冷却中返回空齐射。敌弹留在本模块。
func fire(now_sec: float) -> EnemyVolley:
	var volley := EnemyVolley.new()
	if not alive:
		return volley
	if facing.length_squared() < 0.0001:
		return volley
	var cooldown := BOSS_COOLDOWN if role == Role.BOSS else GRUNT_COOLDOWN
	if now_sec - _last_fire_sec < cooldown:
		return volley
	_last_fire_sec = now_sec
	var direction := facing.normalized()
	var origin := global_position + direction * MUZZLE_OFFSET
	volley.fired = true
	volley.muzzle_origin = origin
	volley.muzzle_color = BOSS_MUZZLE if role == Role.BOSS else GRUNT_MUZZLE
	var shot := EnemyShot.new()
	shot.origin = origin
	shot.velocity = direction * (BOSS_SHOT_SPEED if role == Role.BOSS else GRUNT_SHOT_SPEED)
	shot.damage = BOSS_SHOT_DAMAGE if role == Role.BOSS else GRUNT_SHOT_DAMAGE
	shot.max_range = BOSS_SHOT_RANGE if role == Role.BOSS else GRUNT_SHOT_RANGE
	shot.tint = BOSS_SHOT_TINT if role == Role.BOSS else GRUNT_SHOT_TINT
	shot.is_energy = true
	shot.radius = 2.0
	volley.shots.append(shot)
	if is_inside_tree():
		var host := get_parent()
		if host == null:
			host = self
		var flash: Node = volley.instantiate_muzzle()
		if flash != null:
			host.add_child(flash)
		host.add_child(shot.instantiate_projectile())
	return volley


## 被打中掉血。打倒后侧躺并换成残骸，看得出已经死了。头目血归零发通关。
func take_damage(amount: int) -> void:
	if not alive or amount <= 0:
		return
	hp = maxi(0, hp - amount)
	if hp > 0:
		return
	alive = false
	velocity = Vector2.ZERO
	_apply_dead_look()
	defeated.emit()
	if role == Role.BOSS:
		stage_cleared.emit(STAGE_BOSS)


func _physics_process(delta: float) -> void:
	if role == Role.GRUNT and alive:
		_update_patrol_velocity()
	else:
		velocity.x = 0.0
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	move_and_slide()


func _update_patrol_velocity() -> void:
	if position.x <= patrol_min_x:
		apply_walk(1.0)
	elif position.x >= patrol_max_x:
		apply_walk(-1.0)
	elif absf(velocity.x) < 0.01:
		apply_walk(-1.0 if facing.x < 0.0 else 1.0)


func _setup_body(size: Vector2) -> void:
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	add_child(col)


func _resize_body(size: Vector2) -> void:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null:
		return
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape


func _setup_look(texture: Texture2D) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)


func _set_texture(texture: Texture2D) -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _face_sprite() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	sprite.flip_h = facing.x > 0.0


func _apply_alive_look() -> void:
	collision_layer = BODY_LAYER
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	sprite.rotation = 0.0
	sprite.modulate = Color.WHITE
	sprite.visible = true
	_face_sprite()


func _apply_dead_look() -> void:
	collision_layer = 0
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	sprite.rotation = DEATH_FALL_RADIANS
	sprite.modulate = DEATH_MODULATE
	sprite.visible = true
	sprite.texture = _wrecked_boss_texture() if role == Role.BOSS else _wrecked_drone_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _drone_texture() -> ImageTexture:
	const WIDTH := 16
	const HEIGHT := 20
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var hull := Color(0.08, 0.22, 0.38)
	var trim := Color(0.12, 0.95, 1.0)
	var visor := Color(1.0, 0.22, 0.86)
	var thruster := Color(0.35, 1.0, 0.55)
	for y in range(4, 16):
		for x in range(3, 13):
			image.set_pixel(x, y, hull)
	for y in range(5, 15):
		image.set_pixel(3, y, trim)
		image.set_pixel(12, y, trim)
	for y in range(2, 6):
		for x in range(5, 11):
			image.set_pixel(x, y, visor)
	for y in range(16, 20):
		for x in range(6, 10):
			image.set_pixel(x, y, thruster)
	return ImageTexture.create_from_image(image)


func _boss_texture() -> ImageTexture:
	const WIDTH := 24
	const HEIGHT := 32
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var hull := Color(0.12, 0.1, 0.28)
	var trim := Color(0.55, 0.2, 1.0)
	var visor := Color(1.0, 0.25, 0.9)
	var core := Color(0.2, 1.0, 0.85)
	for y in range(6, 30):
		for x in range(3, 21):
			image.set_pixel(x, y, hull)
	for y in range(7, 29):
		image.set_pixel(3, y, trim)
		image.set_pixel(20, y, trim)
	for y in range(2, 8):
		for x in range(7, 17):
			image.set_pixel(x, y, visor)
	for y in range(12, 18):
		for x in range(9, 15):
			image.set_pixel(x, y, core)
	image.set_pixel(11, 0, trim)
	image.set_pixel(12, 0, trim)
	image.set_pixel(11, 1, visor)
	image.set_pixel(12, 1, visor)
	return ImageTexture.create_from_image(image)


func _wrecked_drone_texture() -> ImageTexture:
	const WIDTH := 16
	const HEIGHT := 20
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var hull := Color(0.05, 0.1, 0.16)
	var crack := Color(0.2, 0.95, 1.0)
	var spark := Color(1.0, 0.45, 0.15)
	for y in range(8, 16):
		for x in range(2, 14):
			image.set_pixel(x, y, hull)
	for x in range(4, 12):
		image.set_pixel(x, 11, crack)
	image.set_pixel(5, 9, spark)
	image.set_pixel(10, 13, spark)
	image.set_pixel(7, 15, crack)
	return ImageTexture.create_from_image(image)


func _wrecked_boss_texture() -> ImageTexture:
	const WIDTH := 24
	const HEIGHT := 32
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var hull := Color(0.08, 0.06, 0.14)
	var crack := Color(0.7, 0.25, 1.0)
	var spark := Color(0.25, 1.0, 0.8)
	for y in range(12, 28):
		for x in range(2, 22):
			image.set_pixel(x, y, hull)
	for x in range(5, 19):
		image.set_pixel(x, 18, crack)
	image.set_pixel(8, 15, spark)
	image.set_pixel(15, 22, spark)
	image.set_pixel(12, 24, crack)
	return ImageTexture.create_from_image(image)


class Pixels:
	extends RefCounted

	static func texture(color: Color, width: int, height: int) -> ImageTexture:
		var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
		image.fill(color)
		return ImageTexture.create_from_image(image)


class EnemyShot:
	extends RefCounted

	## 枪口世界坐标。
	var origin: Vector2 = Vector2.ZERO
	## 弹体速度，像素/秒。
	var velocity: Vector2 = Vector2.ZERO
	## 命中伤害。
	var damage: int = 0
	## 最远飞行距离，像素。
	var max_range: float = 0.0
	## 能量弹，供霓虹描画。
	var is_energy: bool = true
	## 弹体霓虹色。
	var tint: Color = Color.WHITE
	## 碰撞半宽近似。
	var radius: float = 2.0

	## 生成敌弹节点。不走玩家武器库。
	func instantiate_projectile() -> Area2D:
		var body := EnemyProjectile.new()
		body.setup(self)
		return body


class EnemyVolley:
	extends RefCounted

	## 本次是否真正出膛。
	var fired: bool = false
	## 枪口闪光位置。
	var muzzle_origin: Vector2 = Vector2.ZERO
	## 枪口霓虹色。
	var muzzle_color: Color = Color.BLACK
	## 本次敌弹。空数组表示没打出。
	var shots: Array[EnemyShot] = []

	## 生成枪口闪光。未开火时返回 null。
	func instantiate_muzzle() -> Sprite2D:
		if not fired:
			return null
		var flash := MuzzleFlash.new()
		flash.setup(muzzle_origin, muzzle_color)
		return flash


class EnemyProjectile:
	extends Area2D

	var _velocity: Vector2 = Vector2.ZERO
	var _max_range: float = 0.0
	var _travelled: float = 0.0
	## 命中伤害。
	var damage: int = 0

	func setup(shot: EnemyShot) -> void:
		position = shot.origin
		_velocity = shot.velocity
		_max_range = shot.max_range
		damage = shot.damage
		collision_layer = SHOT_LAYER
		collision_mask = SHOT_MASK
		monitoring = true
		monitorable = true
		set_meta("enemy_shot", true)
		set_meta("damage", shot.damage)
		var sprite := Sprite2D.new()
		var width := 8 if shot.is_energy else 4
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

	func _physics_process(delta: float) -> void:
		var step := _velocity.length() * delta
		position += _velocity * delta
		_travelled += step
		if _travelled >= _max_range:
			queue_free()


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
