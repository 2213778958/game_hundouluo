extends RefCounted

const AudioScript := preload("res://audio/audio.gd")


func run() -> PackedStringArray:
	var failures: PackedStringArray = []
	_license_is_cc0_not_contra(failures)
	_assets_exist(failures)
	_one_looping_bgm_for_three_stages(failures)
	_boot_hangs_playback(failures)
	_sfx_are_short_distinct_one_shots(failures)
	_play_methods_drive_players(failures)
	_no_scene_or_3d_nodes(failures)
	return failures


func _check(failures: PackedStringArray, ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


func _license_is_cc0_not_contra(failures: PackedStringArray) -> void:
	_check(failures, AudioScript.LICENSE == "CC0-1.0", "audio LICENSE constant must be CC0-1.0")
	var text := FileAccess.get_file_as_string("res://audio/LICENSE.txt")
	_check(failures, "CC0" in text, "audio/LICENSE.txt must state CC0")
	_check(failures, "Contra" in text or "魂斗罗" in text, "license must record that this is not Contra OST")
	_check(
		failures,
		not text.contains("Konami soundtrack") or text.contains("Not derived"),
		"license must say the track is original"
	)


func _assets_exist(failures: PackedStringArray) -> void:
	for path in [
		"res://audio/bgm.wav",
		"res://audio/sfx_fire.wav",
		"res://audio/sfx_hurt.wav",
		"res://audio/sfx_jump.wav",
	]:
		_check(failures, FileAccess.file_exists(path), "missing %s" % path)


func _one_looping_bgm_for_three_stages(failures: PackedStringArray) -> void:
	_check(
		failures,
		AudioScript.SHARED_STAGE_COUNT == 3,
		"BGM is shared by three stages, got SHARED_STAGE_COUNT=%s" % AudioScript.SHARED_STAGE_COUNT
	)
	var audio: Node = AudioScript.new()
	var bgm: AudioStreamWAV = audio.call("get_bgm_stream")
	_check(failures, bgm != null, "bgm stream must load")
	if bgm != null:
		_check(
			failures,
			bgm.loop_mode == AudioStreamWAV.LOOP_FORWARD,
			"bgm must loop forward, got %s" % bgm.loop_mode
		)
		_check(failures, bgm.loop_begin == 0, "bgm loop starts at the beginning")
		_check(failures, bgm.loop_end > bgm.loop_begin, "bgm loop end must be after begin")
		_check(failures, not bgm.data.is_empty(), "bgm pcm must not be empty")
		var seconds := _stream_seconds(bgm)
		_check(failures, seconds >= 4.0, "bgm must be a track, got %.2fs" % seconds)
		var first_data := bgm.data
		for stage in range(1, 4):
			audio.call("play_bgm", stage)
			var again: AudioStreamWAV = audio.call("get_bgm_stream")
			_check(
				failures,
				again == bgm,
				"stage %s must keep the same looping BGM object" % stage
			)
			_check(
				failures,
				again != null and again.data == first_data,
				"stage %s must not swap in another track" % stage
			)
			_check(
				failures,
				audio.get_meta("bgm_stage") == stage,
				"play_bgm accepts stage %s without changing the clip" % stage
			)
			_check(
				failures,
				audio.call("is_bgm_playing") == false,
				"stage %s BGM stays stopped until boot hangs the node" % stage
			)
	audio.free()


func _boot_hangs_playback(failures: PackedStringArray) -> void:
	var audio: Node = AudioScript.new()
	var bgm := audio.get_node_or_null("Bgm") as AudioStreamPlayer
	_check(failures, bgm != null, "GameAudio must expose a Bgm player for boot to hang")
	if bgm != null:
		_check(failures, bgm.autoplay == false, "boot hangs playback; BGM must not autoplay")
		_check(failures, bgm.playing == false, "constructing GameAudio must not start BGM")
	_check(failures, audio.call("is_bgm_playing") == false, "is_bgm_playing is false until boot calls play_bgm")
	audio.free()


func _sfx_are_short_distinct_one_shots(failures: PackedStringArray) -> void:
	var audio: Node = AudioScript.new()
	var fire: AudioStreamWAV = audio.call("get_fire_stream")
	var hurt: AudioStreamWAV = audio.call("get_hurt_stream")
	var jump: AudioStreamWAV = audio.call("get_jump_stream")
	var named := {"fire": fire, "hurt": hurt, "jump": jump}
	for sfx_name in named:
		var stream: AudioStreamWAV = named[sfx_name]
		_check(failures, stream != null, "%s stream must load" % sfx_name)
		if stream == null:
			continue
		_check(
			failures,
			stream.loop_mode == AudioStreamWAV.LOOP_DISABLED,
			"%s must be a one-shot, got loop_mode=%s" % [sfx_name, stream.loop_mode]
		)
		_check(failures, not stream.data.is_empty(), "%s pcm must not be empty" % sfx_name)
		var seconds := _stream_seconds(stream)
		_check(failures, seconds > 0.02, "%s is too short to hear, got %.3fs" % [sfx_name, seconds])
		_check(failures, seconds < 1.0, "%s must be a short clip, got %.3fs" % [sfx_name, seconds])
	if fire != null and hurt != null and jump != null:
		_check(failures, fire.data != hurt.data, "fire and hurt must be different clips")
		_check(failures, fire.data != jump.data, "fire and jump must be different clips")
		_check(failures, hurt.data != jump.data, "hurt and jump must be different clips")
	var bgm: AudioStreamWAV = audio.call("get_bgm_stream")
	if bgm != null and fire != null:
		_check(failures, bgm.data != fire.data, "bgm must not reuse a sfx clip")
	audio.free()


func _play_methods_drive_players(failures: PackedStringArray) -> void:
	var audio: Node = AudioScript.new()
	for method_name in ["play_bgm", "stop_bgm", "play_fire", "play_hurt", "play_jump", "is_bgm_playing"]:
		_check(failures, audio.has_method(method_name), "GameAudio must expose %s for boot" % method_name)
	var bgm := audio.get_node_or_null("Bgm") as AudioStreamPlayer
	var fire := audio.get_node_or_null("Fire") as AudioStreamPlayer
	var hurt := audio.get_node_or_null("Hurt") as AudioStreamPlayer
	var jump := audio.get_node_or_null("Jump") as AudioStreamPlayer
	_check(failures, bgm != null and fire != null and hurt != null and jump != null, "boot hangs Bgm/Fire/Hurt/Jump players")
	if bgm == null or fire == null or hurt == null or jump == null:
		audio.free()
		return
	var bgm_stream: AudioStream = bgm.stream
	audio.call("play_bgm", 1)
	audio.call("play_bgm", 2)
	audio.call("play_bgm", 3)
	audio.call("play_fire")
	audio.call("play_hurt")
	audio.call("play_jump")
	_check(failures, not audio.is_inside_tree(), "host tests do not put the module in a scene")
	_check(failures, not bgm.playing, "play_bgm waits until boot hangs this node")
	_check(failures, not fire.playing and not hurt.playing and not jump.playing, "sfx wait until boot hangs this node")
	_check(failures, bgm.stream == bgm_stream, "play_bgm must not replace the loop per stage")
	_check(failures, fire.stream != jump.stream, "fire and jump players must keep distinct streams")
	audio.call("stop_bgm")
	_check(failures, audio.call("is_bgm_playing") == false, "stop_bgm leaves the loop halted")
	audio.free()


func _no_scene_or_3d_nodes(failures: PackedStringArray) -> void:
	var audio: Node = AudioScript.new()
	_check(failures, audio is Node, "GameAudio is a Node boot can hang")
	_check(failures, not (audio is Node3D), "audio module must not use 3D nodes")
	_check(failures, audio.scene_file_path == "", "audio module must not be a packed scene")
	for child in audio.get_children():
		_check(failures, child is AudioStreamPlayer, "child %s must be AudioStreamPlayer" % child.name)
		_check(failures, not (child is AudioStreamPlayer3D), "no AudioStreamPlayer3D")
		_check(failures, not (child is Node3D), "no 3D child nodes")
	audio.free()


func _stream_seconds(stream: AudioStreamWAV) -> float:
	if stream == null or stream.mix_rate <= 0:
		return 0.0
	var bytes_per_sample := 2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1
	if stream.stereo:
		bytes_per_sample *= 2
	if bytes_per_sample <= 0:
		return 0.0
	return float(stream.data.size()) / float(stream.mix_rate * bytes_per_sample)
