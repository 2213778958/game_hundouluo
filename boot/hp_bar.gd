extends Control

## 像素科幻血条。对接玩家 hp_changed(hp, max_hp)，不依赖 player 模块在树里。

const BAR_SIZE := Vector2(160, 10)
const NEON_FILL := Color(1.0, 0.22, 0.86)
const NEON_EDGE := Color(0.12, 0.95, 1.0)
const VOID_TRACK := Color(0.04, 0.06, 0.12, 0.92)

## 当前血量。
var hp: int = 5
## 满血。
var max_hp: int = 5

var _track: ColorRect
var _fill: ColorRect
var _edge: ColorRect


func _init() -> void:
	name = "HpBar"
	custom_minimum_size = BAR_SIZE
	size = BAR_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge = _swatch("Edge", NEON_EDGE, Vector2(-1, -1), BAR_SIZE + Vector2(2, 2))
	_track = _swatch("Track", VOID_TRACK, Vector2.ZERO, BAR_SIZE)
	_fill = _swatch("Fill", NEON_FILL, Vector2.ZERO, BAR_SIZE)
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


func _swatch(node_name: String, color: Color, pos: Vector2, rect_size: Vector2) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.color = color
	rect.position = pos
	rect.size = rect_size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect
