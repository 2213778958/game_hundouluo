extends Node

## 本关敌人清空后切到下一关。不在敌人 defeated 回调里切，避免切关拆掉正在发信号的节点。

const StagesScript := preload("res://stages/stages.gd")


func _init() -> void:
	process_physics_priority = 80


func _physics_process(_delta: float) -> void:
	var stage := get_parent()
	if stage == null or not is_instance_valid(stage):
		return
	if not StagesScript.is_cleared(stage):
		return
	set_physics_process(false)
	call_deferred("_advance")


func _advance() -> void:
	var stage := get_parent()
	if stage == null or not is_instance_valid(stage):
		return
	StagesScript.advance_if_cleared(null, stage)
