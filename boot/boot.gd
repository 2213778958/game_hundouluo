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
	_hp_bar.position = Vector2(8, 6)
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
	_entry.add_child(_make_starfield())
	_add_frame_corners(_entry)
	_entry.add_child(_make_rail("RailLeft", Vector2(10, 28), Vector2(6, 304)))
	_entry.add_child(_make_rail("RailRight", Vector2(624, 28), Vector2(6, 304)))
	_entry.add_child(_make_title_plate())
	_entry.add_child(_make_label("TitleGlow", TITLE, Vector2(2, 30), 640, 28, Color(NEON, 0.28)))
	_title = _make_label("Title", TITLE, Vector2(0, 28), 640, 28, NEON)
	_entry.add_child(_title)
	_entry.add_child(_make_label("Tag", "像素科幻 · 三关突击", Vector2(0, 62), 640, 12, Color(0.55, 0.9, 1.0, 0.85)))
	var prompt := _make_label("Prompt", "选择武器", Vector2(0, 86), 640, 16, MAGENTA)
	_entry.add_child(prompt)
	var row := HBoxContainer.new()
	row.name = "WeaponRow"
	row.position = Vector2(56, 122)
	row.size = Vector2(528, 168)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_entry.add_child(row)
	var names := list_weapon_choices()
	var flavors := PackedStringArray(["直射", "近距散射", "能量直线"])
	for kind in range(names.size()):
		row.add_child(_make_weapon_card(kind, names[kind], flavors[kind]))
	_entry.add_child(_make_label("Hint", "点选武器进入平地练手", Vector2(0, 304), 640, 12, Color(0.7, 0.95, 1.0, 0.8)))
	_entry.add_child(_make_scanlines())


func _make_weapon_card(kind: int, weapon_label: String, flavor: String) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.name = "WeaponCard_%s" % kind
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = _gun_texture(kind)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(96, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)
	var button := Button.new()
	button.name = "Weapon_%s" % kind
	button.text = weapon_label
	button.icon = icon.texture
	button.expand_icon = false
	button.custom_minimum_size = Vector2(156, 52)
	_paint_button(button, _weapon_accent(kind))
	button.pressed.connect(choose_weapon.bind(kind))
	card.add_child(button)
	var flavor_label := Label.new()
	flavor_label.name = "Flavor"
	flavor_label.text = flavor
	flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor_label.add_theme_color_override("font_color", _weapon_accent(kind))
	flavor_label.add_theme_font_size_override("font_size", 11)
	flavor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(flavor_label)
	return card


func _make_label(node_name: String, text: String, pos: Vector2, width: float, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = pos
	label.size = Vector2(width, font_size + 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _paint_button(button: Button, accent: Color) -> void:
	button.add_theme_color_override("font_color", accent)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", MAGENTA)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.16, 0.96)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.anti_aliasing = false
	style.shadow_color = Color(accent, 0.35)
	style.shadow_size = 3
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.1, 0.16, 0.28, 0.98)
	hover.border_color = MAGENTA
	hover.shadow_color = Color(MAGENTA, 0.5)
	hover.shadow_size = 5
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)


func _weapon_accent(kind: int) -> Color:
	match kind:
		WEAPON_SHOTGUN:
			return Color(1.0, 0.55, 0.12)
		WEAPON_LASER:
			return MAGENTA
		_:
			return NEON


func _make_starfield() -> TextureRect:
	var view := TextureRect.new()
	view.name = "Starfield"
	view.texture = _starfield_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.position = Vector2.ZERO
	view.size = Vector2(640, 360)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view


func _make_scanlines() -> TextureRect:
	var view := TextureRect.new()
	view.name = "Scanlines"
	view.texture = _scanline_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.position = Vector2.ZERO
	view.size = Vector2(640, 360)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_TILE
	view.modulate = Color(1, 1, 1, 0.28)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view


func _make_title_plate() -> TextureRect:
	var plate := TextureRect.new()
	plate.name = "TitlePlate"
	plate.texture = _title_plate_texture()
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.position = Vector2(120, 20)
	plate.size = Vector2(400, 56)
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return plate


func _make_rail(node_name: String, pos: Vector2, rail_size: Vector2) -> TextureRect:
	var rail := TextureRect.new()
	rail.name = node_name
	rail.texture = _rail_texture(int(rail_size.x), int(rail_size.y))
	rail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rail.position = pos
	rail.size = rail_size
	rail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rail.stretch_mode = TextureRect.STRETCH_SCALE
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rail


func _add_frame_corners(parent: Control) -> void:
	var frame := Control.new()
	frame.name = "Frame"
	frame.position = Vector2.ZERO
	frame.size = Vector2(640, 360)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	var color := NEON
	var marks := [
		["TL_H", Vector2(16, 12), Vector2(36, 3)],
		["TL_V", Vector2(16, 12), Vector2(3, 36)],
		["TR_H", Vector2(588, 12), Vector2(36, 3)],
		["TR_V", Vector2(621, 12), Vector2(3, 36)],
		["BL_H", Vector2(16, 345), Vector2(36, 3)],
		["BL_V", Vector2(16, 312), Vector2(3, 36)],
		["BR_H", Vector2(588, 345), Vector2(36, 3)],
		["BR_V", Vector2(621, 312), Vector2(3, 36)],
	]
	for mark in marks:
		var rect := ColorRect.new()
		rect.name = str(mark[0])
		rect.color = color
		rect.position = mark[1]
		rect.size = mark[2]
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(rect)
	var inner := ColorRect.new()
	inner.name = "InnerGlow"
	inner.color = Color(MAGENTA, 0.08)
	inner.position = Vector2(22, 18)
	inner.size = Vector2(596, 324)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(inner)


func _starfield_texture() -> ImageTexture:
	const WIDTH := 160
	const HEIGHT := 90
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var high := Color(0.05, 0.07, 0.14, 1)
	var low := Color(0.02, 0.03, 0.08, 1)
	var star := Color(0.55, 0.95, 1.0, 0.9)
	var star_m := Color(1.0, 0.35, 0.9, 0.75)
	var grid := Color(0.12, 0.62, 0.78, 0.38)
	var building := Color(0.06, 0.08, 0.16, 1)
	var window_c := Color(0.2, 0.95, 1.0, 0.85)
	var window_m := Color(1.0, 0.28, 0.86, 0.8)
	for y in HEIGHT:
		var t := float(y) / float(HEIGHT)
		var sky := high.lerp(low, t * 0.55)
		for x in WIDTH:
			image.set_pixel(x, y, sky)
	for y in range(0, 58):
		for x in WIDTH:
			var hash_v := (x * 17 + y * 53) % 61
			if hash_v == 0:
				image.set_pixel(x, y, star)
			elif hash_v == 7:
				image.set_pixel(x, y, star_m)
	for x in WIDTH:
		image.set_pixel(x, 62, NEON)
		image.set_pixel(x, 63, Color(NEON, 0.4))
	var heights := [18, 12, 22, 8, 16, 10, 20, 14, 9, 17, 11, 19, 7, 15]
	var bx := 0
	for i in heights.size():
		var bh: int = heights[i]
		var bw := 10 + (i % 3) * 2
		for y in range(63 - bh, 63):
			for x in range(bx, mini(bx + bw, WIDTH)):
				var lit := (x + y) % 5 == 0 and y > 63 - bh + 2
				if lit:
					image.set_pixel(x, y, window_c if (x + i) % 2 == 0 else window_m)
				else:
					image.set_pixel(x, y, building)
		bx += bw + 1
	for y in range(64, HEIGHT):
		for x in WIDTH:
			if y % 4 == 0 or (x + int(y / 2)) % 12 == 0:
				image.set_pixel(x, y, grid)
	return ImageTexture.create_from_image(image)


func _scanline_texture() -> ImageTexture:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color(0, 0, 0, 0.45))
	image.set_pixel(1, 0, Color(0, 0, 0, 0.45))
	image.set_pixel(0, 1, Color(0, 0, 0, 0))
	image.set_pixel(1, 1, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(image)


func _title_plate_texture() -> ImageTexture:
	const WIDTH := 100
	const HEIGHT := 14
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var plate := Color(0.04, 0.08, 0.16, 0.88)
	var rim := NEON
	var dash := MAGENTA
	for y in HEIGHT:
		for x in WIDTH:
			image.set_pixel(x, y, plate)
	for x in WIDTH:
		image.set_pixel(x, 0, rim)
		image.set_pixel(x, HEIGHT - 1, rim)
	for y in HEIGHT:
		image.set_pixel(0, y, rim)
		image.set_pixel(WIDTH - 1, y, rim)
	for x in range(4, WIDTH - 4, 4):
		image.set_pixel(x, 2, dash)
		image.set_pixel(x, HEIGHT - 3, dash)
	return ImageTexture.create_from_image(image)


func _rail_texture(width: int, height: int) -> ImageTexture:
	var image := Image.create(maxi(width, 2), maxi(height, 8), false, Image.FORMAT_RGBA8)
	var core := NEON
	var dim := Color(0.08, 0.4, 0.5, 0.7)
	var pulse := MAGENTA
	for y in image.get_height():
		for x in image.get_width():
			if x == 0 or x == image.get_width() - 1:
				image.set_pixel(x, y, core)
			elif y % 10 == 0:
				image.set_pixel(x, y, pulse)
			else:
				image.set_pixel(x, y, dim)
	return ImageTexture.create_from_image(image)


func _gun_texture(kind: int) -> ImageTexture:
	var image := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	var hull := Color(0.16, 0.2, 0.34, 1)
	var neon := _weapon_accent(kind)
	var glow := neon.lightened(0.25)
	match kind:
		WEAPON_SHOTGUN:
			_stamp_rect(image, 4, 6, 8, 10, hull)
			_stamp_rect(image, 8, 5, 22, 8, neon)
			_stamp_rect(image, 8, 9, 20, 12, neon)
			_stamp_rect(image, 10, 12, 14, 15, hull)
			_stamp_rect(image, 22, 6, 26, 11, glow)
			image.set_pixel(27, 7, glow)
			image.set_pixel(27, 10, glow)
		WEAPON_LASER:
			_stamp_rect(image, 3, 7, 8, 11, hull)
			_stamp_rect(image, 8, 8, 28, 9, neon)
			_stamp_rect(image, 12, 7, 26, 8, glow)
			_stamp_rect(image, 12, 9, 26, 10, glow)
			_stamp_rect(image, 9, 10, 13, 14, hull)
			image.set_pixel(29, 8, Color.WHITE)
			image.set_pixel(30, 8, glow)
		_:
			_stamp_rect(image, 2, 7, 8, 11, hull)
			_stamp_rect(image, 8, 6, 26, 9, neon)
			_stamp_rect(image, 10, 9, 16, 12, hull)
			_stamp_rect(image, 12, 11, 15, 15, hull)
			_stamp_rect(image, 16, 9, 19, 13, MAGENTA)
			_stamp_rect(image, 26, 6, 30, 9, glow)
			image.set_pixel(31, 7, Color.WHITE)
	return ImageTexture.create_from_image(image)


func _stamp_rect(image: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	for y in range(y0, y1):
		for x in range(x0, x1):
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
				image.set_pixel(x, y, color)


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
