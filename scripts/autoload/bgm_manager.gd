extends Node

## 全局BGM管理器（AutoLoad）
## - 统一控制主菜单/地图/战斗BGM
## - 切换曲目时保存播放进度，回切时继续播放
## - 播放音效（如命中音效等）
const TRACK_MAIN_MENU: StringName = &"main_menu"
const TRACK_MAP: StringName = &"map"
const TRACK_BATTLE: StringName = &"battle"

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

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "BGMPlayer"
	_player.bus = "Master"
	_player.volume_db = VOLUME_DB_NORMAL
	add_child(_player)
	if not _player.finished.is_connected(_on_player_finished):
		_player.finished.connect(_on_player_finished)
	
	# 默认进入游戏即主菜单BGM
	play_track(TRACK_MAIN_MENU)

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

	var stream := load(path) as AudioStream
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
	
	var stream := load(sound_path) as AudioStream
	if not stream:
		push_warning("BGMManager: 无法加载音效：%s" % sound_path)
		return
	
	# 创建临时音效播放器
	var sound_player = AudioStreamPlayer.new()
	sound_player.stream = stream
	sound_player.volume_db = volume_db
	sound_player.bus = "Master"
	add_child(sound_player)
	
	# 播放音效
	sound_player.play()
	
	# 播放完成后自动删除播放器
	if not sound_player.finished.is_connected(_on_sound_finished):
		sound_player.finished.connect(_on_sound_finished.bind(sound_player))

## 音效播放完成回调
func _on_sound_finished(player: AudioStreamPlayer) -> void:
	if player and is_instance_valid(player):
		player.queue_free()

## 播放命中音效
func play_hit_sound() -> void:
	play_sound(SOUND_HIT)
