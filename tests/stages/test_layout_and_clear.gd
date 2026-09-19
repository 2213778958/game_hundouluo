extends RefCounted

const StagesScript := preload("res://stages/stages.gd")
const PlayerScript := preload("res://player/player.gd")


func run() -> PackedStringArray:
	var failures: PackedStringArray = []
	_grunt_spacing(failures)
	_max_rise_follows_player(failures)
	_platforms_are_one_jump(failures)
	_ready_survival(failures)
	_defeat_each_slot(failures)
	_killing_one_does_not_advance(failures)
	_all_flat_grunts_go_to_stage_two(failures)
	_boss_stage_clears_only_on_boss(failures)
	return failures


func _check(failures: PackedStringArray, ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


func _expected_max_rise() -> int:
	var jump := float(PlayerScript.JUMP_VELOCITY)
	var gravity := float(PlayerScript.GRAVITY)
	return int(floor(jump * jump / (2.0 * gravity))) - 8


func _grunt_spacing(failures: PackedStringArray) -> void:
	var count := StagesScript.grunt_count(1)
	var slots := StagesScript.layout_slots(1)
	_check(failures, slots == count, "平地练手 layout_slots must equal grunt count, no 头目")
	_check(failures, slots >= 1, "任一关 layout_slots < 1 is a failed layout")
	var min_pair := StagesScript.min_pair_spacing()
	var min_adj := StagesScript.min_grunt_spacing()
	_check(
		failures,
		count >= 3 or (count == 2 and min_pair >= float(PlayerScript.RUN_SPEED) * 1.5),
		"平地练手 needs >= 3 杂兵, or 2 with spacing >= RUN_SPEED * 1.5"
	)
	var stage: Node2D = StagesScript.build_stage(1)
	_check(failures, stage != null, "spacing check needs 平地练手")
	if stage == null:
		return
	var xs: Array[float] = []
	for grunt in _find_parts(stage, "grunt"):
		if grunt is Node2D:
			xs.append((grunt as Node2D).position.x)
	xs.sort()
	_check(failures, xs.size() == count, "built 杂兵 count must match layout")
	if xs.size() == 2:
		_check(
			failures,
			xs[1] - xs[0] >= min_pair,
			"two 平地练手 杂兵 must be >= %s px apart, got %s" % [min_pair, xs[1] - xs[0]]
		)
	for i in range(1, xs.size()):
		var gap := xs[i] - xs[i - 1]
		_check(
			failures,
			gap >= min_adj,
			"adjacent 平地练手 杂兵 x gap %s must be >= RUN_SPEED * 1.2 (%s)" % [gap, min_adj]
		)
	stage.free()


func _max_rise_follows_player(failures: PackedStringArray) -> void:
	var expected := _expected_max_rise()
	_check(
		failures,
		StagesScript.max_rise() == expected,
		"max_rise must be floor(JUMP_VELOCITY^2 / (2 * GRAVITY)) - 8, got %s expected %s"
		% [StagesScript.max_rise(), expected]
	)
	_check(
		failures,
		is_equal_approx(StagesScript.max_step_gap(), float(PlayerScript.RUN_SPEED) * 0.35),
		"max_step_gap must be RUN_SPEED * 0.35"
	)
	var cover_h := StagesScript.player_collision_height()
	_check(failures, cover_h > 0.0, "player collision height must be readable")
	var stage: Node2D = StagesScript.build_stage(2)
	_check(failures, stage != null, "max_rise cover check needs 高台掩体")
	if stage == null:
		return
	var rise := float(StagesScript.max_rise())
	for box in _find_parts(stage, "cover"):
		var rect := _solid_rect(box)
		_check(failures, rect.size != Vector2.ZERO, "掩体 %s needs a collision rect" % box.name)
		_check(
			failures,
			rect.size.y >= cover_h and rect.size.y <= rise,
			"掩体 %s height %s must be in [player %s, max_rise %s]"
			% [box.name, rect.size.y, cover_h, rise]
		)
	stage.free()


func _platforms_are_one_jump(failures: PackedStringArray) -> void:
	_check(failures, StagesScript.has_platforms(2), "高台掩体 must have platforms")
	_check(failures, StagesScript.has_cover(2), "高台掩体 must have cover")
	_check(
		failures,
		StagesScript.grunt_count(2) > StagesScript.grunt_count(1),
		"高台掩体 杂兵数 must exceed 平地练手"
	)
	var stage: Node2D = StagesScript.build_stage(2)
	_check(failures, stage != null, "one-jump check needs 高台掩体")
	if stage == null:
		return
	var platforms := _find_parts(stage, "platform")
	_check(failures, platforms.size() >= 2, "高台掩体 needs >= 2 高台")
	var covers := _find_parts(stage, "cover")
	_check(failures, covers.size() >= 2, "高台掩体 needs >= 2 掩体")
	var duties: Dictionary = {}
	var floor_runner := 0
	var platform_sentry := 0
	var floor_top := 300.0
	for grunt in _find_parts(stage, "grunt"):
		var duty := str(grunt.get_meta("duty", ""))
		duties[duty] = true
		var on_floor := grunt is Node2D and is_equal_approx((grunt as Node2D).position.y, _stand_y(floor_top))
		if duty == "runner" and on_floor:
			floor_runner += 1
		if duty == "sentry" and not on_floor:
			platform_sentry += 1
	_check(failures, duties.size() >= 2, "高台掩体 火力更密: duty kinds >= 2, got %s" % duties.size())
	_check(failures, floor_runner >= 1, "高台掩体 floor needs a 游走")
	_check(failures, platform_sentry >= 1, "高台掩体 高台 needs a 哨位")
	var rise := float(StagesScript.max_rise())
	var gap := StagesScript.max_step_gap()
	var surfaces: Array[Dictionary] = []
	surfaces.append(_surface_dict(0.0, StagesScript.stage_length(2), floor_top, false))
	for platform in platforms:
		var rect := _solid_rect(platform)
		_check(failures, rect.size.x >= 80.0, "高台 %s must be a standable ledge" % platform.name)
		surfaces.append(_surface_dict(rect.position.x, rect.end.x, rect.position.y, true))
	var reached := _reachable_surfaces(surfaces, rise, gap)
	for i in range(surfaces.size()):
		if bool(surfaces[i]["platform"]):
			_check(
				failures,
				reached[i],
				"高台 top y=%s x=%s..%s must be one-jump reachable (rise<=%s gap<=%s)"
				% [surfaces[i]["top"], surfaces[i]["left"], surfaces[i]["right"], rise, gap]
			)
	for grunt in _find_parts(stage, "grunt"):
		if str(grunt.get_meta("duty", "")) != "sentry" or not (grunt is Node2D):
			continue
		var gx := (grunt as Node2D).position.x
		var on_reachable := false
		for i in range(surfaces.size()):
			if not bool(surfaces[i]["platform"]) or not reached[i]:
				continue
			if gx >= float(surfaces[i]["left"]) and gx <= float(surfaces[i]["right"]):
				on_reachable = true
		_check(failures, on_reachable, "台上哨位 %s must stand on a reachable 高台" % grunt.name)
	stage.free()


func _ready_survival(failures: PackedStringArray) -> void:
	for index in range(1, 4):
		var slots := StagesScript.layout_slots(index)
		_check(failures, slots >= 1, "stage %s layout_slots must be >= 1, got %s" % [index, slots])
		if index == 1:
			_check(
				failures,
				slots >= 3 or slots == 2,
				"平地练手 layout_slots must meet 现象 1 杂兵下限"
			)
		var loose: Node2D = StagesScript.build_stage(index)
		_check(failures, loose != null, "ready-survival needs stage %s" % index)
		if loose != null:
			_check(
				failures,
				StagesScript.living_hostile_count(loose) == slots,
				"build_stage(%s) living %s must equal layout_slots %s"
				% [index, StagesScript.living_hostile_count(loose), slots]
			)
			_check(
				failures,
				StagesScript.ready_survival_held(loose),
				"build_stage(%s) must record 就绪存活" % index
			)
			_check(failures, not StagesScript.is_cleared(loose), "fresh stage %s is not cleared" % index)
			loose.free()
	if not ResourceLoader.exists("res://boot/boot.gd"):
		failures.append("boot missing; cannot prove go_to_stage 就绪存活")
		return
	var script: Script = load("res://boot/boot.gd")
	if script == null or not script.can_instantiate():
		failures.append("boot cannot instantiate for 就绪存活")
		return
	var boot: Object = script.new()
	StagesScript.install(boot)
	for index in range(1, 4):
		boot.call("go_to_stage", index)
		var host: Node = boot.get_node_or_null("StageHost")
		_check(failures, host != null and host.get_child_count() > 0, "go_to_stage(%s) must host a stage" % index)
		if host == null or host.get_child_count() == 0:
			continue
		var stage: Node = host.get_child(0)
		var slots := StagesScript.layout_slots(index)
		_check(
			failures,
			StagesScript.living_hostile_count(stage) == slots,
			"go_to_stage(%s) before fire: living %s must equal layout_slots %s"
			% [index, StagesScript.living_hostile_count(stage), slots]
		)
		_check(
			failures,
			StagesScript.ready_survival_held(stage),
			"go_to_stage(%s) must hold 就绪存活 before the first shot" % index
		)
	boot.free()


func _defeat_each_slot(failures: PackedStringArray) -> void:
	var stage: Node2D = StagesScript.build_stage(1)
	_check(failures, stage != null, "分别打倒 needs 平地练手")
	if stage == null:
		return
	var grunts := _find_parts(stage, "grunt")
	_check(failures, grunts.size() >= 2, "分别打倒 needs more than one 杂兵")
	_check(failures, StagesScript.ready_survival_held(stage), "分别打倒 requires 就绪存活 first")
	for i in range(grunts.size()):
		_defeat_unit(grunts[i])
		var last := i == grunts.size() - 1
		_check(
			failures,
			StagesScript.is_cleared(stage) == last,
			"平地练手 is_cleared after %s/%s downs must be %s"
			% [i + 1, grunts.size(), last]
		)
	stage.free()
	var cover: Node2D = StagesScript.build_stage(2)
	_check(failures, cover != null, "分别打倒 needs 高台掩体")
	if cover == null:
		return
	var units := _find_parts(cover, "grunt")
	for i in range(units.size()):
		_defeat_unit(units[i])
		var last := i == units.size() - 1
		_check(
			failures,
			StagesScript.is_cleared(cover) == last,
			"高台掩体 is_cleared after %s/%s downs must be %s"
			% [i + 1, units.size(), last]
		)
	cover.free()


func _killing_one_does_not_advance(failures: PackedStringArray) -> void:
	var boot := _make_boot()
	if boot == null:
		failures.append("boot missing; cannot prove 杀 1 只不切")
		return
	StagesScript.install(boot)
	boot.call("go_to_stage", 1)
	var stage := _hosted_stage(boot)
	_check(failures, stage != null, "杀 1 只不切 needs hosted 平地练手")
	if stage == null:
		boot.free()
		return
	var grunts := _find_parts(stage, "grunt")
	_check(failures, grunts.size() >= 2, "杀 1 只不切 needs leftover 杂兵")
	if grunts.is_empty():
		boot.free()
		return
	_defeat_unit(grunts[0])
	_drive_clear_watcher(stage)
	_check(failures, not StagesScript.is_cleared(stage), "杀 1 只 must not clear 平地练手")
	_check(failures, boot.get("current_stage") == 1, "杀 1 只 must keep 平地练手, got %s" % boot.get("current_stage"))
	boot.free()


func _all_flat_grunts_go_to_stage_two(failures: PackedStringArray) -> void:
	var boot := _make_boot()
	if boot == null:
		failures.append("boot missing; cannot prove go_to_stage(2)")
		return
	StagesScript.install(boot)
	boot.call("go_to_stage", 1)
	var stage := _hosted_stage(boot)
	_check(failures, stage != null, "go_to_stage(2) needs hosted 平地练手")
	if stage == null:
		boot.free()
		return
	for grunt in _find_parts(stage, "grunt"):
		_defeat_unit(grunt)
	_check(failures, StagesScript.is_cleared(stage), "杀完全部 平地练手 杂兵 must clear")
	_drive_clear_watcher(stage)
	_check(
		failures,
		boot.get("current_stage") == 2,
		"杀完全部才 go_to_stage(2), got %s" % boot.get("current_stage")
	)
	var next_stage := _hosted_stage(boot)
	_check(failures, next_stage != null, "go_to_stage(2) must host 高台掩体")
	if next_stage != null:
		_check(failures, next_stage.name == "高台掩体", "next node must be 高台掩体")
	boot.free()


func _boss_stage_clears_only_on_boss(failures: PackedStringArray) -> void:
	var boot := _make_boot()
	if boot == null:
		failures.append("boot missing; cannot prove 打倒头目才通关")
		return
	StagesScript.install(boot)
	boot.call("go_to_stage", 3)
	var stage := _hosted_stage(boot)
	_check(failures, stage != null, "通道头目 通关 needs hosted stage")
	if stage == null:
		boot.free()
		return
	_check(failures, StagesScript.ready_survival_held(stage), "通道头目 must hold 就绪存活")
	_check(
		failures,
		StagesScript.living_hostile_count(stage) == StagesScript.layout_slots(3),
		"通道头目 ready living must equal layout_slots"
	)
	var sentries := []
	for grunt in _find_parts(stage, "grunt"):
		if str(grunt.get_meta("duty", "")) == "sentry":
			sentries.append(grunt)
	var boss := _find_part(stage, "boss")
	_check(failures, boss != null, "通道头目 must place a 头目")
	if not sentries.is_empty():
		_defeat_unit(sentries[0])
		_drive_clear_watcher(stage)
		_check(failures, not StagesScript.is_cleared(stage), "打倒哨位 must not 通关")
		_check(
			failures,
			boot.get("current_stage") == 3,
			"打倒哨位 must not leave 通道头目, got %s" % boot.get("current_stage")
		)
	if boss != null:
		_defeat_unit(boss)
	_drive_clear_watcher(stage)
	_check(failures, StagesScript.is_cleared(stage), "打倒头目 must 通关")
	_check(
		failures,
		boot.get("current_stage") == 3,
		"头目死后停在第三关, got %s" % boot.get("current_stage")
	)
	_check(failures, StagesScript.next_stage(3) == 0, "第三关之后不造第四关")
	boot.free()


func _make_boot() -> Object:
	if not ResourceLoader.exists("res://boot/boot.gd"):
		return null
	var script: Script = load("res://boot/boot.gd")
	if script == null or not script.can_instantiate():
		return null
	return script.new()


func _hosted_stage(boot: Object) -> Node:
	var host: Node = boot.get_node_or_null("StageHost")
	if host == null or host.get_child_count() == 0:
		return null
	return host.get_child(0)


func _drive_clear_watcher(stage: Node) -> void:
	if stage == null or not is_instance_valid(stage):
		return
	var watcher := stage.get_node_or_null("ClearWatcher")
	if watcher == null:
		StagesScript.advance_if_cleared(null, stage)
		return
	if watcher.has_method("_physics_process"):
		watcher.call("_physics_process", 1.0 / 60.0)
	if watcher.has_method("_advance"):
		watcher.call("_advance")


func _stand_y(surface_top: float) -> float:
	return surface_top - 40.0 * 0.5


func _surface_dict(left: float, right: float, top: float, is_platform: bool) -> Dictionary:
	return {"left": left, "right": right, "top": top, "platform": is_platform}


func _reachable_surfaces(surfaces: Array[Dictionary], max_rise: float, max_gap: float) -> Array[bool]:
	var reached: Array[bool] = []
	reached.resize(surfaces.size())
	reached.fill(false)
	if surfaces.is_empty():
		return reached
	reached[0] = true
	var changed := true
	while changed:
		changed = false
		for i in range(surfaces.size()):
			if not reached[i]:
				continue
			for j in range(surfaces.size()):
				if reached[j]:
					continue
				if _can_step(surfaces[i], surfaces[j], max_rise, max_gap):
					reached[j] = true
					changed = true
	return reached


func _can_step(from_s: Dictionary, to_s: Dictionary, max_rise: float, max_gap: float) -> bool:
	var rise := float(from_s["top"]) - float(to_s["top"])
	if rise > max_rise:
		return false
	return _horizontal_gap(from_s, to_s) <= max_gap


func _horizontal_gap(a: Dictionary, b: Dictionary) -> float:
	var a_right := float(a["right"])
	var a_left := float(a["left"])
	var b_right := float(b["right"])
	var b_left := float(b["left"])
	if a_right < b_left:
		return b_left - a_right
	if b_right < a_left:
		return a_left - b_right
	return 0.0


func _solid_rect(node: Node) -> Rect2:
	if not (node is Node2D):
		return Rect2()
	var body := node as Node2D
	for child in body.get_children():
		if child is CollisionShape2D:
			var shape := (child as CollisionShape2D).shape
			if shape is RectangleShape2D:
				var size: Vector2 = (shape as RectangleShape2D).size
				return Rect2(body.position - size * 0.5, size)
	return Rect2()


func _defeat_unit(unit: Node) -> void:
	if unit.has_method("take_damage"):
		var hp: Variant = unit.get("hp")
		unit.call("take_damage", int(hp) if typeof(hp) == TYPE_INT else 999)
		return
	unit.set_meta("alive", false)
	if "alive" in unit:
		unit.set("alive", false)


func _find_part(node: Node, part: String) -> Node:
	if str(node.get_meta("stage_part", "")) == part:
		return node
	for child in node.get_children():
		var found := _find_part(child, part)
		if found != null:
			return found
	return null


func _find_parts(node: Node, part: String) -> Array[Node]:
	var found: Array[Node] = []
	if str(node.get_meta("stage_part", "")) == part:
		found.append(node)
	for child in node.get_children():
		found.append_array(_find_parts(child, part))
	return found
