class_name GameAudio
extends Node

## 三关共用的燃向循环 BGM 与开枪、受伤、跳跃短音。boot 把本节点挂上后再播放。

const BGM_PATH := "res://audio/bgm.wav"
const FIRE_PATH := "res://audio/sfx_fire.wav"
const HURT_PATH := "res://audio/sfx_hurt.wav"
const JUMP_PATH := "res://audio/sfx_jump.wav"
## 素材许可。原曲，可商用，不是魂斗罗原声。
const LICENSE := "CC0-1.0"
## 平地练手、高台掩体、通道头目共用这一首。
const SHARED_STAGE_COUNT := 3

var _bgm: AudioStreamPlayer
var _fire: AudioStreamPlayer
var _hurt: AudioStreamPlayer
var _jump: AudioStreamPlayer


func _init() -> void:
	name = "GameAudio"
	_bgm = _make_player("Bgm", _load_wav(BGM_PATH, true))
	_fire = _make_player("Fire", _load_wav(FIRE_PATH, false))
	_hurt = _make_player("Hurt", _load_wav(HURT_PATH, false))
	_jump = _make_player("Jump", _load_wav(JUMP_PATH, false))


## 三关共用同一首循环曲。已在播时不重开，方便切关。stage_index 不换曲。
func play_bgm(stage_index: int = 1) -> void:
	if stage_index < 1:
		stage_index = 1
	elif stage_index > SHARED_STAGE_COUNT:
		stage_index = SHARED_STAGE_COUNT
	set_meta("bgm_stage", stage_index)
	_play_if_hung(_bgm, false)


## 停下循环 BGM。
func stop_bgm() -> void:
	_bgm.stop()


## 开枪短音。
func play_fire() -> void:
	_play_sfx(_fire)


## 受伤短音。
func play_hurt() -> void:
	_play_sfx(_hurt)


## 跳跃短音。
func play_jump() -> void:
	_play_sfx(_jump)


## 是否正在循环那一首 BGM。
func is_bgm_playing() -> bool:
	return _bgm.playing


## 三关共用的循环曲流。
func get_bgm_stream() -> AudioStreamWAV:
	return _bgm.stream as AudioStreamWAV


## 开枪短音流。
func get_fire_stream() -> AudioStreamWAV:
	return _fire.stream as AudioStreamWAV


## 受伤短音流。
func get_hurt_stream() -> AudioStreamWAV:
	return _hurt.stream as AudioStreamWAV


## 跳跃短音流。
func get_jump_stream() -> AudioStreamWAV:
	return _jump.stream as AudioStreamWAV


func _play_sfx(player: AudioStreamPlayer) -> void:
	_play_if_hung(player, true)


func _play_if_hung(player: AudioStreamPlayer, restart: bool) -> void:
	if player.stream == null:
		return
	if not is_inside_tree():
		return
	if restart or not player.playing:
		player.play()


func _make_player(player_name: String, stream: AudioStreamWAV) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.autoplay = false
	add_child(player)
	return player


func _load_wav(path: String, loop: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("audio file missing: %s" % path)
		return stream
	var mix_rate := 22050
	var bits := 16
	var channels := 1
	var pcm := PackedByteArray()
	var header := file.get_buffer(12)
	if header.size() < 12:
		return stream
	while file.get_position() + 8 <= file.get_length():
		var chunk_id := file.get_buffer(4).get_string_from_ascii()
		var chunk_size := file.get_32()
		var next_pos := file.get_position() + chunk_size
		if next_pos > file.get_length():
			break
		if chunk_id == "fmt ":
			file.get_16()
			channels = file.get_16()
			mix_rate = file.get_32()
			file.get_32()
			file.get_16()
			bits = file.get_16()
		elif chunk_id == "data":
			pcm = file.get_buffer(chunk_size)
		file.seek(next_pos + (chunk_size % 2))
	if bits != 16 or channels != 1 or pcm.is_empty():
		push_error("audio file must be 16-bit mono PCM: %s" % path)
		return stream
	stream.mix_rate = mix_rate
	stream.data = pcm
	var frames := pcm.size() / 2
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = frames
	else:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream
