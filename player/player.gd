class_name Player
extends CharacterBody2D

## 玩家：方向移动、跳跃、血量与开火。开火走 arsenal。血没了重来本关，不整局清档。

const ArsenalScript := preload("res://arsenal/arsenal.gd")

const MAX_HP := 5
const RUN_SPEED := 140.0
const JUMP_VELOCITY := -320.0
const GRAVITY := 900.0
const MUZZLE_OFFSET := 10.0

## 左移动作。与跳跃、开火键位不相交。
const ACTION_LEFT := "player_left"
## 右移动作。与跳跃、开火键位不相交。
const ACTION_RIGHT := "player_right"
## 跳跃动作。不与开火共用键。
const ACTION_JUMP := "player_jump"
## 开火动作。不与跳跃共用键。
const ACTION_FIRE := "player_fire"

## 当前血量。
var hp: int = MAX_HP
## 水平朝向，开火与精灵翻转用。
var facing: Vector2 = Vector2.RIGHT
## 是否站在地面。跳跃只在地面生效。
var on_ground: bool = true
## 当前关卡序号。重来本关时不清零。
var stage_index: int = 0
## 本关起点。
var spawn_position: Vector2 = Vector2.ZERO
## 整局选用的武器。重来本关不清。
var loadout: RefCounted

## 血没了重来本关。参数仍是当前关。
signal stage_restarted(stage_index: int)
## 血量变化，供 boot 血条。
signal hp_changed(hp: int, max_hp: int)


func _init() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	collision_layer = 2
	collision_mask = 1
	loadout = ArsenalScript.new(ArsenalScript.Kind.RIFLE)
	ensure_control_actions()
	_setup_body()
	_setup_look()


## 选定武器并放到本关起点。
func configure(kind: int, spawn: Vector2, stage: int) -> void:
	loadout = ArsenalScript.new(kind)
	spawn_position = spawn
	stage_index = stage
	position = spawn
	hp = MAX_HP
	velocity = Vector2.ZERO
	facing = Vector2.RIGHT
	on_ground = true
	_face_sprite()
	hp_changed.emit(hp, MAX_HP)


## 方向移动。axis 为 -1、0、1。
func apply_run(axis: float) -> void:
	velocity.x = axis * RUN_SPEED
	if absf(axis) > 0.01:
		facing = Vector2.RIGHT if axis > 0.0 else Vector2.LEFT
		_face_sprite()


## 地面起跳。离地时无效。
func jump() -> bool:
	if not on_ground:
		return false
	velocity.y = JUMP_VELOCITY
	on_ground = false
	return true


## 被打中掉血。血没了重来本关，不整局清档。
func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	hp = maxi(0, hp - amount)
	hp_changed.emit(hp, MAX_HP)
	if hp == 0:
		_restart_current_stage()


## 注册方向、跳跃、开火动作。跳跃与开火键位不相交，可同时按。
func ensure_control_actions() -> void:
	_bind_keys(ACTION_LEFT, [KEY_LEFT, KEY_A])
	_bind_keys(ACTION_RIGHT, [KEY_RIGHT, KEY_D])
	_bind_keys(ACTION_JUMP, [KEY_SPACE])
	_bind_keys(ACTION_FIRE, [KEY_Z, KEY_J])
	_bind_mouse(ACTION_FIRE, MOUSE_BUTTON_LEFT)


## 读本帧方向、跳、开火。三套动作可同时生效。
func apply_controls(now_sec: float) -> void:
	ensure_control_actions()
	apply_run(Input.get_axis(ACTION_LEFT, ACTION_RIGHT))
	if Input.is_action_just_pressed(ACTION_JUMP):
		jump()
	if Input.is_action_pressed(ACTION_FIRE):
		fire(now_sec)


## 开火调用 arsenal。冷却中返回空齐射。
func fire(now_sec: float) -> RefCounted:
	var aim := facing
	if aim.length_squared() < 0.0001:
		aim = Vector2.RIGHT
	var muzzle := global_position + aim.normalized() * MUZZLE_OFFSET
	var volley: RefCounted = loadout.call("fire", muzzle, aim, now_sec)
	if bool(volley.get("fired")) and is_inside_tree():
		var host := get_parent()
		if host == null:
			host = self
		var flash: Node = volley.call("instantiate_muzzle")
		if flash != null:
			host.add_child(flash)
		for shot in volley.get("shots"):
			host.add_child(shot.call("instantiate_projectile"))
	return volley


func _physics_process(delta: float) -> void:
	on_ground = is_on_floor()
	apply_controls(Time.get_ticks_msec() / 1000.0)
	if not on_ground:
		velocity.y += GRAVITY * delta
	move_and_slide()
	on_ground = is_on_floor()


func _bind_keys(action: String, keycodes: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for keycode in keycodes:
		var code: int = int(keycode)
		if _has_key_event(action, code):
			continue
		var ev := InputEventKey.new()
		ev.keycode = code as Key
		ev.physical_keycode = code as Key
		InputMap.action_add_event(action, ev)


func _bind_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if _has_mouse_event(action, button):
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _has_key_event(action: String, keycode: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var key_ev := ev as InputEventKey
			if int(key_ev.physical_keycode) == keycode or int(key_ev.keycode) == keycode:
				return true
	return false


func _has_mouse_event(action: String, button: MouseButton) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == button:
			return true
	return false


func _restart_current_stage() -> void:
	hp = MAX_HP
	position = spawn_position
	velocity = Vector2.ZERO
	on_ground = true
	hp_changed.emit(hp, MAX_HP)
	stage_restarted.emit(stage_index)


func _setup_body() -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 22)
	col.shape = shape
	col.position = Vector2(0, 1)
	add_child(col)


func _setup_look() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = _soldier_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)


func _face_sprite() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	sprite.flip_h = facing.x < 0.0


func _soldier_texture() -> ImageTexture:
	const WIDTH := 16
	const HEIGHT := 24
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var body := Color(0.12, 0.95, 1.0)
	var visor := Color(1.0, 0.22, 0.86)
	var boot := Color(0.38, 0.22, 0.95)
	for y in range(8, 22):
		for x in range(4, 12):
			image.set_pixel(x, y, body)
	for y in range(2, 8):
		for x in range(5, 11):
			image.set_pixel(x, y, visor)
	for y in range(22, 24):
		for x in range(4, 12):
			image.set_pixel(x, y, boot)
	return ImageTexture.create_from_image(image)
