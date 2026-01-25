extends Node

## 后处理管理器（AutoLoad）
## 管理全屏后处理效果，如受伤红屏、暗角等

const SETTINGS_FILE_PATH = "user://settings.cfg"
const CONFIG_SECTION_POSTPROCESS = "postprocess"
const CONFIG_KEY_CRT_ENABLED = "crt_enabled"

# ========== 受伤效果 ==========
var hurt_vignette_scene: PackedScene = preload("res://scenes/vfx/hurt_vignette.tscn")
var hurt_vignette_instance: CanvasLayer = null
var hurt_vignette_material: ShaderMaterial = null

# ========== CRT 效果（全局屏幕滤镜） ==========
var crt_scene: PackedScene = preload("res://scenes/vfx/crt_canvas.tscn")
var crt_instance: CanvasLayer = null
var crt_material: ShaderMaterial = null
 
# CRT 用户设置值（来自 settings.cfg）
var _crt_enabled_user_setting: bool = true
# CRT 临时禁用 token：用于“查看CG时不加滤镜”等场景
var _crt_temp_disable_tokens: Dictionary = {}
var _crt_temp_disable_token_seq: int = 1

# 动画参数
var _hurt_tween: Tween = null
var _hurt_effect_duration: float = 1.0  # 效果持续时间（秒）
var _hurt_fade_in_duration: float = 0.1  # 淡入时间
var _hurt_fade_out_duration: float = 0.9  # 淡出时间

func _ready() -> void:
	# 初始化受伤效果
	_setup_hurt_vignette()
	# 初始化 CRT 效果
	_setup_crt()
	# 启动时读取设置并应用 CRT 开关
	_apply_crt_enabled_from_settings()

func _apply_crt_enabled_from_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_FILE_PATH)
	var is_enabled: bool = true
	if err == OK:
		is_enabled = bool(config.get_value(CONFIG_SECTION_POSTPROCESS, CONFIG_KEY_CRT_ENABLED, true))
	set_crt_enabled(is_enabled)

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

## 设置 CRT 后处理（全局屏幕滤镜）
func _setup_crt() -> void:
	if crt_instance:
		return
	
	crt_instance = crt_scene.instantiate()
	add_child(crt_instance)
	
	var color_rect := crt_instance.get_node("ColorRect") as ColorRect
	if color_rect and color_rect.material:
		crt_material = color_rect.material as ShaderMaterial
		# 默认参数初始化（避免未赋值导致的异常效果）
		crt_material.set_shader_parameter("enabled", 1.0)
	else:
		push_warning("PostProcessManager: crt_material 未初始化")

## 开关 CRT（用户设置）
func set_crt_enabled(is_enabled: bool) -> void:
	_crt_enabled_user_setting = is_enabled
	_apply_crt_effective_state()

func push_temp_disable_crt() -> int:
	var token: int = _crt_temp_disable_token_seq
	_crt_temp_disable_token_seq += 1
	_crt_temp_disable_tokens[token] = true
	_apply_crt_effective_state()
	return token

func pop_temp_disable_crt(token: int) -> void:
	if token <= 0:
		return
	if _crt_temp_disable_tokens.has(token):
		_crt_temp_disable_tokens.erase(token)
	_apply_crt_effective_state()

func _is_crt_temporarily_disabled() -> bool:
	return not _crt_temp_disable_tokens.is_empty()

func _apply_crt_effective_state() -> void:
	if not crt_material:
		return
	var enabled: bool = _crt_enabled_user_setting and (not _is_crt_temporarily_disabled())
	crt_material.set_shader_parameter("enabled", 1.0 if enabled else 0.0)

## 设置 CRT 总强度（0~1）
func set_crt_strength(value: float) -> void:
	if not crt_material:
		return
	crt_material.set_shader_parameter("strength", clamp(value, 0.0, 1.0))

## 设置 CRT 色散（0~0.01）
func set_crt_aberration(value: float) -> void:
	if not crt_material:
		return
	crt_material.set_shader_parameter("aberration", clamp(value, 0.0, 0.01))

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
