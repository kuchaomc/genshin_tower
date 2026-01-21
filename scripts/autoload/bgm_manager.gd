extends Node

## 全局BGM管理器（AutoLoad）
## - 统一控制主菜单/地图/战斗BGM
## - 切换曲目时保存播放进度，回切时继续播放
## - 播放音效（如命中音效等）
const TRACK_MAIN_MENU: StringName = &"main_menu"
const TRACK_MAP: StringName = &"map"
const TRACK_BATTLE: StringName = &"battle"

# Audio Bus 相关
const BUS_MASTER: StringName = &"Master"
const BUS_BGM: StringName = &"BGM"
const BUS_SFX: StringName = &"SFX"

# 与设置界面共用的配置路径（Settings 使用 ConfigFile 写入该文件）
const SETTINGS_FILE_PATH: String = "user://settings.cfg"
const CONFIG_SECTION_AUDIO: String = "audio"
const CONFIG_KEY_BGM_VOLUME: String = "bgm_volume"
const CONFIG_KEY_SFX_VOLUME: String = "sfx_volume"

const VOLUME_DB_NORMAL: float = 0.0
const VOLUME_DB_SILENT: float = -60.0
const FADE_OUT_SEC: float = 0.6
const FADE_IN_SEC: float = 0.6

const TRACK_PATHS: Dictionary = {
	TRACK_MAIN_MENU: "res://voice/白夜洇润 Unfurling Night.mp3",
	TRACK_MAP: "res://voice/挪德卡莱 Nod-Krai.mp3",
	TRACK_BATTLE: "res://voice/切心的渴求 A Thirst That Cuts.mp3",
}

# 音效路径
const SOUND_HIT: String = "res://voice/击中.WAV"

var _player: AudioStreamPlayer
var _positions: Dictionary = {} # StringName -> float
var _current_track: StringName = &""
var _switching: bool = false
var _queued_track: StringName = &""
var _tween: Tween

var _bgm_volume_linear: float = 1.0
var _sfx_volume_linear: float = 1.0

# ==============================
# SFX Pool / Cache（减少频繁创建节点与 load 引发的卡顿）
# ==============================
const MAX_SFX_PLAYERS: int = 8
var _sfx_players: Array[AudioStreamPlayer] = []
var _audio_stream_cache: Dictionary = {} # String -> AudioStream

func _ready() -> void:
	# 确保Audio Bus存在（避免项目未配置默认bus_layout时无法分离控制音量）
	_ensure_audio_buses()
	# 启动时读取并应用音量设置
	_load_audio_settings_from_config()

	_player = AudioStreamPlayer.new()
	_player.name = "BGMPlayer"
	_player.bus = BUS_BGM
	_player.volume_db = VOLUME_DB_NORMAL
	add_child(_player)
	if not _player.finished.is_connected(_on_player_finished):
		_player.finished.connect(_on_player_finished)

	# 初始化音效播放器池
	_init_sfx_pool()
	
	# 默认进入游戏即主菜单BGM
	play_track(TRACK_MAIN_MENU)

func _init_sfx_pool() -> void:
	_sfx_players.clear()
	for i in range(MAX_SFX_PLAYERS):
		var p := AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.bus = BUS_SFX
		add_child(p)
		_sfx_players.append(p)

func _ensure_audio_buses() -> void:
	# Master 是引擎默认总线；BGM/SFX 可能不存在，需要运行时补齐
	_ensure_bus(BUS_BGM, BUS_MASTER)
	_ensure_bus(BUS_SFX, BUS_MASTER)

func _ensure_bus(bus_name: StringName, send_to: StringName) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		return
	AudioServer.add_bus(AudioServer.bus_count)
	idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send_to)

func _load_audio_settings_from_config() -> void:
	var config := ConfigFile.new()
	var err: Error = config.load(SETTINGS_FILE_PATH)
	if err != OK:
		# 没有配置文件时使用默认音量
		_apply_audio_volumes(1.0, 1.0)
		return
	var bgm_v: float = float(config.get_value(CONFIG_SECTION_AUDIO, CONFIG_KEY_BGM_VOLUME, 1.0))
	var sfx_v: float = float(config.get_value(CONFIG_SECTION_AUDIO, CONFIG_KEY_SFX_VOLUME, 1.0))
	_apply_audio_volumes(bgm_v, sfx_v)

func _apply_audio_volumes(bgm_linear: float, sfx_linear: float) -> void:
	set_bgm_volume_linear(bgm_linear)
	set_sfx_volume_linear(sfx_linear)

func set_bgm_volume_linear(value: float) -> void:
	_bgm_volume_linear = clampf(value, 0.0, 1.0)
	var idx := AudioServer.get_bus_index(BUS_BGM)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, _linear_to_bus_db(_bgm_volume_linear))

func get_bgm_volume_linear() -> float:
	return _bgm_volume_linear

func set_sfx_volume_linear(value: float) -> void:
	_sfx_volume_linear = clampf(value, 0.0, 1.0)
	var idx := AudioServer.get_bus_index(BUS_SFX)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, _linear_to_bus_db(_sfx_volume_linear))

func get_sfx_volume_linear() -> float:
	return _sfx_volume_linear

func _linear_to_bus_db(value: float) -> float:
	# 线性音量转分贝：0 -> 极小（近似静音）；其余使用 Godot 内置 linear_to_db
	if value <= 0.0:
		return -80.0
	return linear_to_db(value)

func play_track(track: StringName) -> void:
	if track.is_empty():
		return
	
	# 同一首歌且正在播放：不打断，继续原进度
	if _current_track == track and _player and _player.playing and _player.stream != null:
		return

	# 记录最新的目标曲目；如果正在切换，等当前切换结束后再处理（只保留最后一次请求）
	_queued_track = track
	if _switching:
		return

	_switching = true
	while not _queued_track.is_empty():
		var next_track := _queued_track
		_queued_track = &""
		await _switch_to(next_track)
	_switching = false

func _switch_to(track: StringName) -> void:
	if track.is_empty():
		return

	# 如果当前正在播其它曲目：先淡出到静音（不中断播放），再记录进度并切换
	if _player and _player.playing and _player.stream != null and not _current_track.is_empty() and _current_track != track:
		await _fade_to(VOLUME_DB_SILENT, FADE_OUT_SEC)
		_positions[_current_track] = _player.get_playback_position()

	_current_track = track

	var path: String = TRACK_PATHS.get(track, "")
	if path.is_empty():
		push_warning("BGMManager: 未配置的曲目key：%s" % str(track))
		return

	var stream := _get_audio_stream(path)
	if not stream:
		push_warning("BGMManager: 无法加载音频：%s" % path)
		return

	_player.stream = stream
	var pos: float = float(_positions.get(track, 0.0))
	if pos < 0.0:
		pos = 0.0

	_player.volume_db = VOLUME_DB_SILENT
	_player.play(pos)
	await _fade_to(VOLUME_DB_NORMAL, FADE_IN_SEC)

func stop() -> void:
	_save_current_position()
	if _player:
		_player.stop()

func _save_current_position() -> void:
	if _current_track.is_empty():
		return
	if _player and _player.playing:
		_positions[_current_track] = _player.get_playback_position()

func get_current_track() -> StringName:
	return _current_track

func _fade_to(target_db: float, duration_sec: float) -> void:
	if not _player:
		return
	if duration_sec <= 0.0:
		_player.volume_db = target_db
		return

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", target_db, duration_sec)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	await _tween.finished

func _on_player_finished() -> void:
	# 到结尾后循环播放，并重置该曲目的进度
	if _current_track.is_empty() or not _player:
		return
	_positions[_current_track] = 0.0
	_player.volume_db = VOLUME_DB_NORMAL
	_player.play(0.0)

## 播放音效
## sound_path: 音效文件路径
## volume_db: 音量（分贝），默认0.0
func play_sound(sound_path: String, volume_db: float = 0.0) -> void:
	if sound_path.is_empty():
		return
	
	var stream := _get_audio_stream(sound_path)
	if not stream:
		push_warning("BGMManager: 无法加载音效：%s" % sound_path)
		return
	
	# 从池中取一个可用播放器（避免每次 new/queue_free）
	var sound_player := _get_available_sfx_player()
	if not sound_player:
		return
	sound_player.stream = stream
	sound_player.volume_db = volume_db
	sound_player.play()

func _get_available_sfx_player() -> AudioStreamPlayer:
	# 优先找空闲的
	for p in _sfx_players:
		if p and not p.playing:
			return p
	# 全部忙：复用第一个（打断最早的音效），避免无限增长
	if _sfx_players.size() > 0 and _sfx_players[0]:
		_sfx_players[0].stop()
		return _sfx_players[0]
	return null

func _get_audio_stream(path: String) -> AudioStream:
	if path.is_empty():
		return null
	# 优先复用 DataManager 的资源缓存（统一入口）
	if DataManager and DataManager.has_method("load_cached"):
		var res := DataManager.load_cached(path)
		return res as AudioStream if res is AudioStream else null
	# 回退：本地缓存
	if _audio_stream_cache.has(path):
		return _audio_stream_cache[path] as AudioStream
	var stream := load(path) as AudioStream
	if stream:
		_audio_stream_cache[path] = stream
	return stream

## 播放命中音效
func play_hit_sound() -> void:
	play_sound(SOUND_HIT)
