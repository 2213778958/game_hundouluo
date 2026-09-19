extends CanvasLayer

## 入口、武器选择、血条与三关切换。主场景开打；切关走本 autoload。不编译依赖 stages。

const HpBarScript := preload("res://boot/hp_bar.gd")

## 步枪。与 arsenal Kind.RIFLE 同值。
const WEAPON_RIFLE := 0
## 散弹枪。与 arsenal Kind.SHOTGUN 同值。
const WEAPON_SHOTGUN := 1
## 激光枪。与 arsenal Kind.LASER 同值。
const WEAPON_LASER := 2

## 可切关卡数：平地练手、高台掩体、通道头目。
const STAGE_COUNT := 3

const AUDIO_PATH := "res://audio/audio.gd"
const PLAYER_PATH := "res://player/player.gd"
const STAGES_PATH := "res://stages/stages.gd"
const TITLE := "突击三关"
const NEON := Color(0.12, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.22, 0.86)
const VOID := Color(0.03, 0.04, 0.09)

## 当前选中的初始武器。
var selected_weapon: int = WEAPON_RIFLE
## 当前关。0 入口选择，1 平地练手，2 高台掩体，3 通道头目。
var current_stage: int = 0

## 选好武器。
signal weapon_chosen(kind: int)
## 切到某一关。stages 监听或查询 current_stage。
signal stage_changed(stage_index: int)

var _hp_bar: Control
var _entry: Control
var _title: Label
var _stage_host: Node2D
var _stage_builders: Dictionary = {}
var _audio: Node
var _player: Node
var _hp_bound: Object


func _init() -> void:
	name = "Boot"
	layer = 10
	follow_viewport_enabled = false
	_stage_host = Node2D.new()
	_stage_host.name = "StageHost"
	add_child(_stage_host)
	_hp_bar = HpBarScript.new()
	_hp_bar.position = Vector2(16, 8)
	_hp_bar.visible = false
	add_child(_hp_bar)
	_build_entry()


func _ready() -> void:
	hang_stages()


## 开打前可选的三套武器名。
func list_weapon_choices() -> PackedStringArray:
	return PackedStringArray(["步枪", "散弹枪", "激光枪"])


## 三关名，供切关 UI 与 stages 对齐。
func list_stages() -> PackedStringArray:
	return PackedStringArray(["平地练手", "高台掩体", "通道头目"])


## 关卡序号对应的关名。1 平地练手，2 高台掩体，3 通道头目。
func stage_name(stage_index: int) -> String:
	var names := list_stages()
	if stage_index < 1 or stage_index > names.size():
		return ""
	return names[stage_index - 1]


## 武器整数对应中文名。非法值空串。
func weapon_name(kind: int) -> String:
	var names := list_weapon_choices()
	if kind < 0 or kind >= names.size():
		return ""
	return names[kind]


## 按 Kind 整数选定步枪 / 散弹枪 / 激光枪并进入第一关。
func choose_weapon(kind: int) -> void:
	if kind < WEAPON_RIFLE or kind > WEAPON_LASER:
		return
	selected_weapon = kind
	weapon_chosen.emit(kind)
	if _player != null and is_instance_valid(_player) and _player.has_method("configure"):
		_player.call("configure", selected_weapon, _player.position, maxi(current_stage, 1))
	go_to_stage(1)


## 按界面上的中文名选择。未列出的名字（含机枪）忽略。
func choose_weapon_by_name(weapon_label: String) -> void:
	var kind := list_weapon_choices().find(weapon_label)
	if kind == -1:
		return
	choose_weapon(kind)


## 显示入口与武器选择，不进入关卡。
func show_entry() -> void:
	current_stage = 0
	_clear_stage_host()
	_entry.visible = true
	_hp_bar.visible = false
	_sync_audio()
	stage_changed.emit(0)


## 切到 1–3 关。stages 可先 register_stage 再调用。
func go_to_stage(stage_index: int) -> void:
	if stage_index < 1 or stage_index > STAGE_COUNT:
		return
	current_stage = stage_index
	_entry.visible = false
	_hp_bar.visible = true
	_rebuild_stage()
	_sync_audio()
	_sync_player()
	stage_changed.emit(current_stage)


## 重来本关：重建当前关节点，不清所选武器。
func restart_stage() -> void:
	if current_stage < 1:
		return
	go_to_stage(current_stage)


## stages 注册某一关的节点工厂。未注册时仍更新 current_stage。
func register_stage(stage_index: int, builder: Callable) -> void:
	if stage_index < 1 or stage_index > STAGE_COUNT:
		return
	if builder.is_null() or not builder.is_valid():
		return
	_stage_builders[stage_index] = builder


## 把玩家 hp_changed 接到血条。source 不必进 SceneTree。
func bind_hp_bar(source: Object) -> void:
	if source == null:
		return
	if _hp_bound != null and is_instance_valid(_hp_bound) and _hp_bound.has_signal("hp_changed"):
		if _hp_bound.is_connected("hp_changed", Callable(self, "set_hp")):
			_hp_bound.disconnect("hp_changed", Callable(self, "set_hp"))
	_hp_bound = source
	if source.has_signal("hp_changed"):
		if not source.is_connected("hp_changed", Callable(self, "set_hp")):
			source.connect("hp_changed", Callable(self, "set_hp"))
	var current: Variant = source.get("hp")
	var maximum: Variant = source.get("MAX_HP")
	if typeof(current) == TYPE_INT and typeof(maximum) == TYPE_INT:
		set_hp(int(current), int(maximum))
	elif typeof(current) == TYPE_INT and typeof(source.get("max_hp")) == TYPE_INT:
		set_hp(int(current), int(source.get("max_hp")))


## 更新血条。签名对齐 player.hp_changed。
func set_hp(hp: int, max_hp: int) -> void:
	_hp_bar.call("set_hp", hp, max_hp)


## 血条当前比例，0..1。
func get_hp_ratio() -> float:
	return float(_hp_bar.call("get_ratio"))


## 血条节点，供 stages 叠 HUD。
func get_hp_bar() -> Control:
	return _hp_bar


## 入口选择是否还在前台。
func is_entry_visible() -> bool:
	return _entry.visible


## 运行时挂上 stages 并 register_stage。不 preload stages；catalog 为空则按路径 load。
func hang_stages(catalog: Node = null) -> void:
	var node := catalog
	if node == null:
		node = _try_make_stages()
	if node == null:
		return
	if node.has_method("install"):
		node.call("install", self)
	if catalog == null and node.get_parent() == null:
		node.free()


## Hang GameAudio 进树，BGM/短音才能出声。audio 模块不在本票树里时由调用方传入桩。
func hang_audio(audio: Node) -> void:
	if audio == null:
		return
	if audio.get_parent() == self:
		_audio = audio
		_sync_audio()
		return
	if audio.get_parent() != null:
		audio.get_parent().remove_child(audio)
	add_child(audio)
	_audio = audio
	_sync_audio()


## 记下玩家节点并接血条。不把玩家抢到 Boot 下，关卡仍归 stages。
func attach_player(player: Node) -> void:
	_player = player
	bind_hp_bar(player)
	_sync_player()


func _build_entry() -> void:
	_entry = Control.new()
	_entry.name = "Entry"
	_entry.position = Vector2.ZERO
	_entry.size = Vector2(640, 360)
	add_child(_entry)
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = VOID
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(640, 360)
	_entry.add_child(backdrop)
	_title = _make_label("Title", TITLE, Vector2(0, 36), 640, 28, NEON)
	_entry.add_child(_title)
	var prompt := _make_label("Prompt", "选择武器", Vector2(0, 88), 640, 16, MAGENTA)
	_entry.add_child(prompt)
	var row := HBoxContainer.new()
	row.name = "WeaponRow"
	row.position = Vector2(80, 160)
	row.size = Vector2(480, 48)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_entry.add_child(row)
	var names := list_weapon_choices()
	for kind in range(names.size()):
		var button := Button.new()
		button.name = "Weapon_%s" % kind
		button.text = names[kind]
		button.custom_minimum_size = Vector2(140, 40)
		_paint_button(button)
		button.pressed.connect(choose_weapon.bind(kind))
		row.add_child(button)


func _make_label(node_name: String, text: String, pos: Vector2, width: float, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = pos
	label.size = Vector2(width, font_size + 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _paint_button(button: Button) -> void:
	button.add_theme_color_override("font_color", NEON)
	button.add_theme_color_override("font_hover_color", MAGENTA)
	button.add_theme_color_override("font_pressed_color", MAGENTA)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.1, 0.18, 0.95)
	style.border_color = NEON
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.border_color = MAGENTA
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)


func _rebuild_stage() -> void:
	_clear_stage_host()
	if not _stage_builders.has(current_stage):
		return
	var builder: Callable = _stage_builders[current_stage]
	if not builder.is_valid():
		return
	var node: Variant = builder.call()
	if node is Node:
		_stage_host.add_child(node)


func _clear_stage_host() -> void:
	for child in _stage_host.get_children():
		_stage_host.remove_child(child)
		child.free()


func _sync_audio() -> void:
	if _audio == null:
		_audio = _try_make_audio()
	if _audio == null:
		return
	if current_stage >= 1 and _audio.has_method("play_bgm"):
		_audio.call("play_bgm", current_stage)
	elif current_stage < 1 and _audio.has_method("stop_bgm"):
		_audio.call("stop_bgm")


func _try_make_audio() -> Node:
	if not ResourceLoader.exists(AUDIO_PATH):
		return null
	var script: Script = load(AUDIO_PATH)
	if script == null or not script.can_instantiate():
		return null
	var audio: Node = script.new()
	if audio.get_parent() != self:
		add_child(audio)
	return audio


func _sync_player() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _try_make_player()
	if _player == null:
		return
	if _player.has_method("configure") and current_stage >= 1:
		_player.call("configure", selected_weapon, _read_stage_spawn(), current_stage)
	bind_hp_bar(_player)


func _read_stage_spawn() -> Vector2:
	for child in _stage_host.get_children():
		if child.has_meta("player_spawn"):
			var marked: Variant = child.get_meta("player_spawn")
			if marked is Vector2 and marked != Vector2.ZERO:
				return marked
		var marker := child.get_node_or_null("PlayerSpawn")
		if marker is Node2D:
			return (marker as Node2D).position
	if _player != null and is_instance_valid(_player) and _player.get("spawn_position") is Vector2:
		var marked: Vector2 = _player.get("spawn_position")
		if marked != Vector2.ZERO:
			return marked
	return Vector2(48, 120)


func _try_make_stages() -> Node:
	if not ResourceLoader.exists(STAGES_PATH):
		return null
	var script: Script = load(STAGES_PATH)
	if script == null or not script.can_instantiate():
		return null
	return script.new()


func _try_make_player() -> Node:
	if not ResourceLoader.exists(PLAYER_PATH):
		return null
	var script: Script = load(PLAYER_PATH)
	if script == null or not script.can_instantiate():
		return null
	var player: Node = script.new()
	_stage_host.add_child(player)
	return player
