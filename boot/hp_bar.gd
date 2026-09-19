extends Control

## 像素科幻血条。对接玩家 hp_changed(hp, max_hp)，不依赖 player 模块在树里。

const BAR_SIZE := Vector2(160, 10)
const BAR_POS := Vector2(24, 6)
const NEON_FILL := Color(1.0, 0.22, 0.86)
const NEON_EDGE := Color(0.12, 0.95, 1.0)
const VOID_TRACK := Color(0.04, 0.06, 0.12, 0.92)
const DIM_PIP := Color(0.16, 0.08, 0.2, 0.9)
const HUD_SIZE := Vector2(232, 28)

## 当前血量。
var hp: int = 5
## 满血。
var max_hp: int = 5

var _track: ColorRect
var _fill: ColorRect
var _edge: ColorRect
var _glow: ColorRect
var _hatch: TextureRect
var _track_grid: TextureRect
var _scan: TextureRect
var _caption: Label
var _readout: Label
var _pips: Control


func _init() -> void:
	name = "HpBar"
	custom_minimum_size = HUD_SIZE
	size = HUD_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow = _swatch("Glow", Color(NEON_FILL, 0.28), BAR_POS + Vector2(-3, -3), BAR_SIZE + Vector2(6, 6))
	_edge = _swatch("Edge", NEON_EDGE, BAR_POS + Vector2(-1, -1), BAR_SIZE + Vector2(2, 2))
	_track = _swatch("Track", VOID_TRACK, BAR_POS, BAR_SIZE)
	_track_grid = _pixel_layer("TrackGrid", _track_grid_texture(), BAR_POS, BAR_SIZE)
	_fill = _swatch("Fill", NEON_FILL, BAR_POS, BAR_SIZE)
	_hatch = _pixel_layer("Hatch", _hatch_texture(), BAR_POS, BAR_SIZE)
	_scan = _pixel_layer("Scan", _scan_texture(), BAR_POS + Vector2(-2, -2), BAR_SIZE + Vector2(4, 4))
	_add_frame()
	_add_ticks()
	_add_brackets()
	_add_life_mark()
	_caption = _hud_label("Caption", "HP", Vector2(2, 5), 20, NEON_EDGE)
	_readout = _hud_label("Readout", "5/5", Vector2(188, 5), 40, NEON_FILL)
	_pips = Control.new()
	_pips.name = "Pips"
	_pips.position = Vector2(24, 20)
	_pips.size = Vector2(160, 6)
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pips)
	_layout_fill()


## 按玩家血量重画。供 hp_changed 与 boot.set_hp。
func set_hp(current: int, maximum: int) -> void:
	max_hp = maxi(1, maximum)
	hp = clampi(current, 0, max_hp)
	_layout_fill()


## 当前血量相对满血，0..1。
func get_ratio() -> float:
	return float(hp) / float(max_hp)


func _layout_fill() -> void:
	if _fill == null:
		return
	_fill.size = Vector2(BAR_SIZE.x * get_ratio(), BAR_SIZE.y)
	if _hatch != null:
		_hatch.size = Vector2(BAR_SIZE.x * get_ratio(), BAR_SIZE.y)
	if _glow != null:
		_glow.size = Vector2(6.0 + BAR_SIZE.x * get_ratio(), _glow.size.y)
	if _readout != null:
		_readout.text = "%s/%s" % [hp, max_hp]
	_layout_pips()


func _layout_pips() -> void:
	if _pips == null:
		return
	for child in _pips.get_children():
		_pips.remove_child(child)
		child.free()
	var count := clampi(max_hp, 1, 8)
	var gap := 3.0
	var pip_w := (160.0 - gap * float(count - 1)) / float(count)
	for i in count:
		var pip := ColorRect.new()
		pip.name = "Pip_%s" % i
		pip.color = NEON_FILL if i < hp else DIM_PIP
		pip.position = Vector2(float(i) * (pip_w + gap), 0)
		pip.size = Vector2(pip_w, 4)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pips.add_child(pip)


func _add_frame() -> void:
	var frame := TextureRect.new()
	frame.name = "Frame"
	frame.texture = _frame_texture()
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.position = BAR_POS + Vector2(-2, -2)
	frame.size = BAR_SIZE + Vector2(4, 4)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)


func _add_ticks() -> void:
	var ticks := Control.new()
	ticks.name = "Ticks"
	ticks.position = BAR_POS
	ticks.size = BAR_SIZE
	ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ticks)
	for i in range(1, 5):
		var tick := ColorRect.new()
		tick.name = "Tick_%s" % i
		tick.color = Color(NEON_EDGE, 0.55)
		tick.position = Vector2(float(i) * 32.0 - 1.0, 1)
		tick.size = Vector2(1, BAR_SIZE.y - 2)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ticks.add_child(tick)


func _add_brackets() -> void:
	var color := NEON_EDGE
	_swatch("BracketTL_H", color, Vector2(20, 2), Vector2(8, 2))
	_swatch("BracketTL_V", color, Vector2(20, 2), Vector2(2, 8))
	_swatch("BracketTR_H", color, Vector2(180, 2), Vector2(8, 2))
	_swatch("BracketTR_V", color, Vector2(186, 2), Vector2(2, 8))
	_swatch("BracketBL_H", color, Vector2(20, 18), Vector2(8, 2))
	_swatch("BracketBL_V", color, Vector2(20, 12), Vector2(2, 8))
	_swatch("BracketBR_H", color, Vector2(180, 18), Vector2(8, 2))
	_swatch("BracketBR_V", color, Vector2(186, 12), Vector2(2, 8))


func _hud_label(node_name: String, text: String, pos: Vector2, width: float, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = pos
	label.size = Vector2(width, 14)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _frame_texture() -> ImageTexture:
	var width := int(BAR_SIZE.x) + 4
	var height := int(BAR_SIZE.y) + 4
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var rim := Color(0.18, 0.98, 1.0, 0.95)
	var corner := Color(1.0, 0.28, 0.9, 1.0)
	var amber := Color(1.0, 0.7, 0.22, 1)
	var tick := Color(0.55, 1.0, 1.0, 0.9)
	for x in width:
		image.set_pixel(x, 0, rim)
		image.set_pixel(x, height - 1, rim if x % 3 != 0 else corner)
	for y in height:
		image.set_pixel(0, y, rim)
		image.set_pixel(width - 1, y, rim)
	for y in 3:
		for x in 3:
			image.set_pixel(x, y, corner)
			image.set_pixel(width - 1 - x, y, corner)
			image.set_pixel(x, height - 1 - y, corner)
			image.set_pixel(width - 1 - x, height - 1 - y, corner)
	image.set_pixel(0, 0, amber)
	image.set_pixel(width - 1, 0, amber)
	image.set_pixel(0, height - 1, amber)
	image.set_pixel(width - 1, height - 1, amber)
	for x in range(8, width - 8, 8):
		image.set_pixel(x, 1, tick)
		image.set_pixel(x, height - 2, Color(corner, 0.8))
	return ImageTexture.create_from_image(image)


func _track_grid_texture() -> ImageTexture:
	var image := Image.create(32, 10, false, Image.FORMAT_RGBA8)
	for y in 10:
		for x in 32:
			var c := Color(0.08, 0.16, 0.28, 0.55)
			if x % 8 == 0:
				c = Color(0.2, 0.85, 1.0, 0.45)
			elif y == 0 or y == 9:
				c = Color(1.0, 0.28, 0.86, 0.25)
			image.set_pixel(x, y, c)
	return ImageTexture.create_from_image(image)


func _hatch_texture() -> ImageTexture:
	var image := Image.create(16, 10, false, Image.FORMAT_RGBA8)
	for y in 10:
		for x in 16:
			if (x + y) % 4 == 0:
				image.set_pixel(x, y, Color(1.0, 0.75, 0.95, 0.55))
			elif (x + y) % 4 == 2:
				image.set_pixel(x, y, Color(0.4, 1.0, 1.0, 0.35))
			else:
				image.set_pixel(x, y, Color(1.0, 0.22, 0.86, 0.12))
	image.set_pixel(0, 0, Color(1.0, 0.22, 0.86, 0.9))
	image.set_pixel(1, 0, Color(0.12, 0.95, 1.0, 0.9))
	return ImageTexture.create_from_image(image)


func _scan_texture() -> ImageTexture:
	var image := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	for y in 4:
		for x in 8:
			if y == 1:
				image.set_pixel(x, y, Color(0.2, 0.95, 1.0, 0.22))
			elif y == 3:
				image.set_pixel(x, y, Color(1.0, 0.22, 0.86, 0.12))
			else:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
	image.set_pixel(2, 1, Color(1.0, 1.0, 1.0, 0.3))
	return ImageTexture.create_from_image(image)


func _add_life_mark() -> void:
	var mark := TextureRect.new()
	mark.name = "LifeMark"
	mark.texture = _life_mark_texture()
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mark.position = Vector2(188, 16)
	mark.size = Vector2(40, 8)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_SCALE
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mark)


func _life_mark_texture() -> ImageTexture:
	var image := Image.create(20, 4, false, Image.FORMAT_RGBA8)
	for y in 4:
		for x in 20:
			image.set_pixel(x, y, Color(0.04, 0.06, 0.1, 0.85))
	for x in range(1, 19, 4):
		var lit := x < 13
		var c := Color(1.0, 0.22, 0.86, 1) if lit else Color(0.2, 0.12, 0.24, 0.9)
		image.set_pixel(x, 1, c)
		image.set_pixel(x + 1, 1, c)
		image.set_pixel(x, 2, c)
		image.set_pixel(x + 1, 2, c)
	image.set_pixel(0, 0, Color(0.12, 0.95, 1.0, 1))
	image.set_pixel(19, 0, Color(1.0, 0.7, 0.22, 1))
	return ImageTexture.create_from_image(image)


func _pixel_layer(node_name: String, texture: Texture2D, pos: Vector2, rect_size: Vector2) -> TextureRect:
	var view := TextureRect.new()
	view.name = node_name
	view.texture = texture
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.position = pos
	view.size = rect_size
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_TILE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	return view


func _swatch(node_name: String, color: Color, pos: Vector2, rect_size: Vector2) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.color = color
	rect.position = pos
	rect.size = rect_size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect
