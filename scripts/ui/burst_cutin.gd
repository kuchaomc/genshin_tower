extends Control
class_name BurstCutin

# 右上角“大招弹出动画”控件
# - 播放时：右侧滑入 + 全屏半透明遮罩淡入
# - 停留：hold_duration
# - 结束：快速滑出 + 遮罩淡出

@export var enter_duration: float = 0.18
@export var hold_duration: float = 0.5
@export var exit_duration: float = 0.12
@export var mask_alpha: float = 0.35
@export var image_shade_alpha: float = 0.15
@export var slide_out_extra_px: float = 40.0
@export var right_margin: float = 0.0

@export var burst_time_scale: float = 0.15
@export var burst_camera_zoom_multiplier: float = 1.35
@export var burst_restore_duration: float = 0.18
@export var burst_effect_duration: float = 1.0

@onready var screen_mask: ColorRect = $ScreenMask
@onready var cutin_container: Control = $CutinContainer
@onready var cutin_image: TextureRect = $CutinContainer/Image
@onready var image_shade: ColorRect = $CutinContainer/ImageShade

var _tween: Tween
var _layout_ready: bool = false
var _final_offset_left: float
var _final_offset_right: float
var _pending_texture: Texture2D

var _burst_effect_active: bool = false
var _prev_engine_time_scale: float = 1.0
var _camera: Camera2D = null
var _camera_prev_zoom: Vector2 = Vector2.ONE
var _camera_tween: Tween = null
var _burst_effect_token: int = 0
var _burst_effect_token_seq: int = 1

func _ready() -> void:
	# Control 的 anchors/offset 布局可能在首帧后才稳定，等一帧后再缓存“最终位置”。
	await get_tree().process_frame
	process_mode = Node.PROCESS_MODE_INHERIT
	_cache_layout_metrics()
	_layout_ready = true
	# 缓存完成后再隐藏到屏幕外，避免把“屏幕外的offset”误当成最终布局。
	_reset_visuals(true)
	if _pending_texture:
		var tex := _pending_texture
		_pending_texture = null
		play(tex)

func _cache_layout_metrics() -> void:
	if not cutin_container:
		return
	_final_offset_left = cutin_container.offset_left
	_final_offset_right = cutin_container.offset_right
	# 如果指定 right_margin，则以它为准（右边贴屏）
	if right_margin >= 0.0:
		_final_offset_right = -right_margin

func play(texture: Texture2D) -> void:
	# 对外接口：传入要展示的贴图并播放一次动画
	if not _layout_ready:
		_pending_texture = texture
		return
	if cutin_image:
		cutin_image.texture = texture
		cutin_image.visible = true
		cutin_image.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_apply_layout_for_texture(texture)
		if OS.is_debug_build() and texture:
			print("BurstCutin: texture size=", texture.get_size())
			print("BurstCutin: image has texture=", cutin_image.texture != null)
	# 注意：不要在这里重新缓存最终offset，否则可能缓存到“动画起点(屏幕外)”
	_reset_visuals(false)
	_play_animation()

func _reset_visuals(hide: bool) -> void:
	# 重置到“准备播放”的初始态
	if _tween:
		_tween.kill()
		_tween = null

	visible = not hide
	if image_shade:
		image_shade.color.a = clampf(image_shade_alpha, 0.0, 1.0)

	if not cutin_container:
		return

	# 使用 _ready 时缓存的最终offset作为动画终点
	cutin_container.modulate = Color(1.0, 1.0, 1.0, 0.0)

	# 起始位置：整体向右平移一个屏幕宽度（滑入起点在屏幕外）
	var w: float = get_viewport().get_visible_rect().size.x
	cutin_container.offset_left = _final_offset_left + w
	cutin_container.offset_right = _final_offset_right + w

func _play_animation() -> void:
	# 动画流程：弹出（enter）-> 停留（hold）-> 收回（exit）
	if not cutin_container:
		return

	visible = true
	cutin_container.visible = true
	_begin_burst_effects_if_needed()
	# 重新取一次viewport宽度，兼容分辨率变化
	var w: float = get_viewport().get_visible_rect().size.x

	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	# 让滑入更“有感知”，避免看起来没滑完就进入下一段
	_tween.set_trans(Tween.TRANS_BACK)
	_tween.set_ease(Tween.EASE_OUT)
	_apply_tween_realtime_compensation(_tween)

	# ========== ENTER：先确保 offset 动画是“主轨”，其它属性并行 ==========
	_tween.tween_property(cutin_container, "offset_left", _final_offset_left, enter_duration)
	_tween.parallel().tween_property(cutin_container, "offset_right", _final_offset_right, enter_duration)
	_tween.parallel().tween_property(cutin_container, "modulate", Color(1.0, 1.0, 1.0, 1.0), enter_duration)
	_tween.tween_callback(_on_enter_finished)

	# ========== HOLD：保证滑入结束后再停留 ==========
	_tween.tween_interval(maxf(hold_duration, 0.0))

	# ========== EXIT：滑出更干脆 ==========
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_property(cutin_container, "offset_left", _final_offset_left + w, exit_duration)
	_tween.parallel().tween_property(cutin_container, "offset_right", _final_offset_right + w, exit_duration)
	_tween.parallel().tween_property(cutin_container, "modulate", Color(1.0, 1.0, 1.0, 0.0), exit_duration)
	_tween.tween_callback(_on_animation_finished)
	if OS.is_debug_build():
		print("BurstCutin: play enter=", enter_duration, " hold=", hold_duration, " exit=", exit_duration)
		print("BurstCutin: final offsets L=", _final_offset_left, " R=", _final_offset_right)
		print("BurstCutin: start offsets L=", cutin_container.offset_left, " R=", cutin_container.offset_right, " alpha=", cutin_container.modulate.a)

func _on_enter_finished() -> void:
	# 滑入结束点：用于调试/兜底，确保容器确实可见
	if not is_instance_valid(cutin_container):
		return
	# 强制修正一次（防止外部布局/脚本覆盖）
	cutin_container.offset_left = _final_offset_left
	cutin_container.offset_right = _final_offset_right
	cutin_container.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if OS.is_debug_build():
		var tex_ok := false
		if is_instance_valid(cutin_image) and cutin_image.texture:
			tex_ok = true
		print("BurstCutin: enter finished offsets L=", cutin_container.offset_left, " R=", cutin_container.offset_right, " alpha=", cutin_container.modulate.a, " tex_ok=", tex_ok)

func _on_animation_finished() -> void:
	if cutin_container:
		# 还原回目标布局，避免下一次播放时位置错乱
		cutin_container.offset_left = _final_offset_left
		cutin_container.offset_right = _final_offset_right
	visible = false

func _apply_tween_realtime_compensation(t: Tween) -> void:
	if not is_instance_valid(t):
		return
	var s: float = clampf(burst_time_scale, 0.01, 1.0)
	if s >= 0.999:
		return
	t.set_speed_scale(1.0 / s)


func _begin_burst_effects_if_needed() -> void:
	var token: int = _burst_effect_token_seq
	_burst_effect_token_seq += 1
	_burst_effect_token = token

	if not _burst_effect_active:
		_burst_effect_active = true
		_prev_engine_time_scale = Engine.time_scale
		Engine.time_scale = clampf(burst_time_scale, 0.01, 1.0)

	if not is_instance_valid(_camera):
		var scene := get_tree().current_scene
		if scene:
			_camera = scene.get_node_or_null("Camera2D") as Camera2D
	if is_instance_valid(_camera):
		_camera_prev_zoom = _camera.zoom
		if _camera_tween and _camera_tween.is_valid():
			_camera_tween.kill()
		_camera_tween = create_tween()
		_camera_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
		_apply_tween_realtime_compensation(_camera_tween)
		_camera_tween.tween_property(_camera, "zoom", _camera_prev_zoom * burst_camera_zoom_multiplier, enter_duration)

	var d: float = maxf(0.01, burst_effect_duration)
	var timer := get_tree().create_timer(d, true, false, true)
	timer.timeout.connect(func() -> void:
		if token != _burst_effect_token:
			return
		_restore_burst_effects_if_needed()
	)


func _restore_burst_effects_if_needed() -> void:
	if not _burst_effect_active:
		return
	_burst_effect_active = false
	Engine.time_scale = _prev_engine_time_scale

	if _camera_tween and _camera_tween.is_valid():
		_camera_tween.kill()
		_camera_tween = null
	if is_instance_valid(_camera):
		var t := create_tween()
		t.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
		t.tween_property(_camera, "zoom", _camera_prev_zoom, maxf(0.01, burst_restore_duration))


func _exit_tree() -> void:
	_restore_burst_effects_if_needed()

func _apply_layout_for_texture(texture: Texture2D) -> void:
	if not is_instance_valid(cutin_container):
		return
	# 使用贴图尺寸来估算宽高比（右侧贴屏）
	var region_size := Vector2.ZERO
	if texture:
		region_size = texture.get_size()
	if region_size.x <= 0.01 or region_size.y <= 0.01:
		return
	# 高度取容器当前高度，宽度按贴图比例计算
	var h: float = cutin_container.offset_bottom - cutin_container.offset_top
	if h <= 0.01:
		h = 120.0
	var w: float = float(region_size.x) / maxf(float(region_size.y), 1.0) * h
	# 右边贴屏：offset_right 取 -right_margin
	cutin_container.offset_right = -right_margin
	cutin_container.offset_left = cutin_container.offset_right - w
	# 同步缓存的最终offset，供动画使用
	_final_offset_left = cutin_container.offset_left
	_final_offset_right = cutin_container.offset_right
