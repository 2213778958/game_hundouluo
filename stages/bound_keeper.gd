extends Node

## 每帧把角色和视角留在本关边界内。

const StagesScript := preload("res://stages/stages.gd")


func _init() -> void:
	process_physics_priority = 100


func _physics_process(_delta: float) -> void:
	_keep()


func _exit_tree() -> void:
	var stage := get_parent()
	if stage == null:
		return
	var host := stage.get_parent()
	if host is Node2D and str(host.name) == "StageHost":
		(host as Node2D).position = Vector2.ZERO


func _keep() -> void:
	var stage := get_parent() as Node2D
	if stage == null:
		return
	var actor := _find_actor(stage)
	if actor == null:
		return
	var cam := stage.get_node_or_null("StageCamera") as Camera2D
	StagesScript.keep_inside(stage, actor, cam)


func _find_actor(stage: Node2D) -> Node2D:
	var named := stage.get_node_or_null("Player")
	if named is Node2D:
		return named as Node2D
	var host := stage.get_parent()
	if host == null:
		return null
	for child in host.get_children():
		if child == stage:
			continue
		if child is CharacterBody2D and child.has_method("apply_run"):
			return child as Node2D
	return null
