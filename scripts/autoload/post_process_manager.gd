extends Node

## 后处理管理器（AutoLoad）
## 管理全屏后处理效果，如受伤红屏、暗角等

# ========== 受伤效果 ==========
var hurt_vignette_scene: PackedScene = preload("res://scenes/vfx/hurt_vignette.tscn")
var hurt_vignette_instance: CanvasLayer = null
var hurt_vignette_material: ShaderMaterial = null

# 动画参数
var _hurt_tween: Tween = null
var _hurt_effect_duration: float = 1.0  # 效果持续时间（秒）
var _hurt_fade_in_duration: float = 0.1  # 淡入时间
var _hurt_fade_out_duration: float = 0.9  # 淡出时间

func _ready() -> void:
	# 初始化受伤效果
	_setup_hurt_vignette()

## 设置受伤暗角效果
func _setup_hurt_vignette() -> void:
	if hurt_vignette_instance:
		return
	
	hurt_vignette_instance = hurt_vignette_scene.instantiate()
	add_child(hurt_vignette_instance)
	
	# 获取 ShaderMaterial 引用
	var color_rect = hurt_vignette_instance.get_node("ColorRect") as ColorRect
	if color_rect and color_rect.material:
		hurt_vignette_material = color_rect.material as ShaderMaterial
		# 确保初始状态为不可见
		hurt_vignette_material.set_shader_parameter("intensity", 0.0)

## 播放受伤效果
## intensity: 效果强度（0.0-1.0），默认1.0
## duration: 效果总持续时间（秒），默认1.0
func play_hurt_effect(intensity: float = 1.0, duration: float = 1.0) -> void:
	if not hurt_vignette_material:
		push_warning("PostProcessManager: hurt_vignette_material 未初始化")
		return
	
	# 停止之前的动画
	if _hurt_tween and _hurt_tween.is_valid():
		_hurt_tween.kill()
	
	# 计算淡入淡出时间
	var fade_in_time = min(0.1, duration * 0.1)
	var fade_out_time = duration - fade_in_time
	
	# 创建新的 Tween 动画
	_hurt_tween = create_tween()
	_hurt_tween.set_ease(Tween.EASE_OUT)
	_hurt_tween.set_trans(Tween.TRANS_QUAD)
	
	# 淡入
	_hurt_tween.tween_method(_set_hurt_intensity, 0.0, intensity, fade_in_time)
	
	# 淡出
	_hurt_tween.set_ease(Tween.EASE_IN)
	_hurt_tween.set_trans(Tween.TRANS_QUAD)
	_hurt_tween.tween_method(_set_hurt_intensity, intensity, 0.0, fade_out_time)

## 设置受伤效果强度
func _set_hurt_intensity(value: float) -> void:
	if hurt_vignette_material:
		hurt_vignette_material.set_shader_parameter("intensity", value)

## 立即停止受伤效果
func stop_hurt_effect() -> void:
	if _hurt_tween and _hurt_tween.is_valid():
		_hurt_tween.kill()
	_set_hurt_intensity(0.0)
