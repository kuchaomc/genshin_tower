extends Control

## 设置中心脚本
## 提供游戏设置功能，包括全屏切换等

# UI节点引用
@onready var fullscreen_switch: CheckButton = $MainContainer/FullscreenContainer/SwitchContainer/FullscreenSwitch
@onready var status_label: Label = $MainContainer/FullscreenContainer/SwitchContainer/StatusLabel
@onready var crt_switch: CheckButton = $MainContainer/CRTContainer/SwitchContainerCRT/CRTSwitch
@onready var crt_status_label: Label = $MainContainer/CRTContainer/SwitchContainerCRT/StatusLabelCRT
@onready var bloom_switch: CheckButton = $MainContainer/BloomContainer/SwitchContainerBloom/BloomSwitch
@onready var bloom_status_label: Label = $MainContainer/BloomContainer/SwitchContainerBloom/StatusLabelBloom
@onready var burst_effect_switch: CheckButton = $MainContainer/BurstEffectContainer/SwitchContainerBurst/BurstEffectSwitch
@onready var burst_status_label: Label = $MainContainer/BurstEffectContainer/SwitchContainerBurst/StatusLabelBurst

@onready var bgm_volume_slider: HSlider = $MainContainer/AudioBGMContainer/SliderContainerBGM/BGMVolumeSlider
@onready var bgm_value_label: Label = $MainContainer/AudioBGMContainer/SliderContainerBGM/BGMValueLabel
@onready var sfx_volume_slider: HSlider = $MainContainer/AudioSFXContainer/SliderContainerSFX/SFXVolumeSlider
@onready var sfx_value_label: Label = $MainContainer/AudioSFXContainer/SliderContainerSFX/SFXValueLabel

@onready var back_button: Button = $MainContainer/BackButton

# 信号
signal settings_closed

# 设置文件路径
const SETTINGS_FILE_PATH = "user://settings.cfg"
const CONFIG_SECTION = "display"
const CONFIG_KEY_FULLSCREEN = "fullscreen"
const CONFIG_SECTION_POSTPROCESS = "postprocess"
const CONFIG_KEY_CRT_ENABLED = "crt_enabled"
const CONFIG_KEY_BLOOM_ENABLED = "bloom_enabled"
const CONFIG_SECTION_UI = "ui"
const CONFIG_KEY_BURST_READY_EFFECT_ENABLED = "burst_ready_effect_enabled"

const CONFIG_SECTION_AUDIO = "audio"
const CONFIG_KEY_BGM_VOLUME = "bgm_volume"
const CONFIG_KEY_SFX_VOLUME = "sfx_volume"

# 目标分辨率
const TARGET_RESOLUTION = Vector2i(1920, 1080)

var _crt_enabled: bool = true
var _bloom_enabled: bool = true
var _burst_ready_effect_enabled: bool = true

var _bgm_volume_linear: float = 1.0
var _sfx_volume_linear: float = 1.0

func _ready() -> void:
	# 设置process_mode为ALWAYS，确保暂停时仍能响应输入
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 连接按钮信号
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	if fullscreen_switch:
		fullscreen_switch.toggled.connect(_on_fullscreen_toggled)
	if crt_switch:
		crt_switch.toggled.connect(_on_crt_toggled)
	if bloom_switch:
		bloom_switch.toggled.connect(_on_bloom_toggled)
	if burst_effect_switch:
		burst_effect_switch.toggled.connect(_on_burst_effect_toggled)
	if bgm_volume_slider:
		bgm_volume_slider.value_changed.connect(_on_bgm_volume_changed)
	if sfx_volume_slider:
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	
	# 加载设置
	load_settings()
	
	# 初始隐藏
	visible = false

## 显示设置界面
func show_settings() -> void:
	visible = true
	# 更新UI状态
	update_ui_state()

## 隐藏设置界面
func hide_settings() -> void:
	visible = false
	settings_closed.emit()

## 检查当前是否为全屏模式
func _is_fullscreen_mode() -> bool:
	var current_mode = DisplayServer.window_get_mode()
	return (current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or 
			current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

## 更新UI状态
func update_ui_state() -> void:
	if fullscreen_switch and status_label:
		var is_fullscreen: bool = _is_fullscreen_mode()
		fullscreen_switch.button_pressed = is_fullscreen
		_update_status_display(is_fullscreen)
	if crt_switch and crt_status_label:
		crt_switch.button_pressed = _crt_enabled
		_update_crt_status_display(_crt_enabled)
	if bloom_switch and bloom_status_label:
		bloom_switch.button_pressed = _bloom_enabled
		_update_bloom_status_display(_bloom_enabled)
	if burst_effect_switch and burst_status_label:
		burst_effect_switch.button_pressed = _burst_ready_effect_enabled
		_update_burst_effect_status_display(_burst_ready_effect_enabled)
	if bgm_volume_slider and bgm_value_label:
		bgm_volume_slider.set_value_no_signal(_bgm_volume_linear)
		_update_volume_label(bgm_value_label, _bgm_volume_linear)
	if sfx_volume_slider and sfx_value_label:
		sfx_volume_slider.set_value_no_signal(_sfx_volume_linear)
		_update_volume_label(sfx_value_label, _sfx_volume_linear)

## 加载设置
func load_settings() -> void:
	var config := ConfigFile.new()
	var err: Error = config.load(SETTINGS_FILE_PATH)
	
	if err == OK:
		# 读取全屏设置
		var fullscreen: bool = bool(config.get_value(CONFIG_SECTION, CONFIG_KEY_FULLSCREEN, false))
		apply_fullscreen(fullscreen)
		# 读取CRT设置
		var crt_enabled: bool = bool(config.get_value(CONFIG_SECTION_POSTPROCESS, CONFIG_KEY_CRT_ENABLED, true))
		_apply_crt(crt_enabled)
		# 读取Bloom设置
		var bloom_enabled: bool = bool(config.get_value(CONFIG_SECTION_POSTPROCESS, CONFIG_KEY_BLOOM_ENABLED, true))
		_apply_bloom(bloom_enabled)
		# 读取大招充能特效设置
		var burst_effect_enabled: bool = bool(config.get_value(CONFIG_SECTION_UI, CONFIG_KEY_BURST_READY_EFFECT_ENABLED, true))
		_apply_burst_ready_effect(burst_effect_enabled)
		# 读取音量设置
		var bgm_volume: float = float(config.get_value(CONFIG_SECTION_AUDIO, CONFIG_KEY_BGM_VOLUME, 1.0))
		var sfx_volume: float = float(config.get_value(CONFIG_SECTION_AUDIO, CONFIG_KEY_SFX_VOLUME, 1.0))
		_apply_audio_volumes(bgm_volume, sfx_volume)
		update_ui_state()
		print("设置已加载")
	else:
		# 如果文件不存在，使用默认设置（窗口模式）
		print("设置文件不存在，使用默认设置（窗口模式）")
		apply_fullscreen(false)
		_apply_crt(true)
		_apply_bloom(true)
		_apply_burst_ready_effect(true)
		_apply_audio_volumes(1.0, 1.0)
		update_ui_state()

## 保存设置
func save_settings() -> void:
	var config := ConfigFile.new()
	
	# 读取现有设置（如果文件存在）
	config.load(SETTINGS_FILE_PATH)
	
	# 保存全屏设置
	var is_fullscreen: bool = _is_fullscreen_mode()
	config.set_value(CONFIG_SECTION, CONFIG_KEY_FULLSCREEN, is_fullscreen)
	# 保存CRT设置
	config.set_value(CONFIG_SECTION_POSTPROCESS, CONFIG_KEY_CRT_ENABLED, _crt_enabled)
	# 保存Bloom设置
	config.set_value(CONFIG_SECTION_POSTPROCESS, CONFIG_KEY_BLOOM_ENABLED, _bloom_enabled)
	# 保存大招充能特效设置
	config.set_value(CONFIG_SECTION_UI, CONFIG_KEY_BURST_READY_EFFECT_ENABLED, _burst_ready_effect_enabled)
	# 保存音量设置
	config.set_value(CONFIG_SECTION_AUDIO, CONFIG_KEY_BGM_VOLUME, _bgm_volume_linear)
	config.set_value(CONFIG_SECTION_AUDIO, CONFIG_KEY_SFX_VOLUME, _sfx_volume_linear)
	config.save(SETTINGS_FILE_PATH)
	print("设置已保存")

func _apply_audio_volumes(bgm_linear: float, sfx_linear: float) -> void:
	_bgm_volume_linear = clampf(bgm_linear, 0.0, 1.0)
	_sfx_volume_linear = clampf(sfx_linear, 0.0, 1.0)
	if BGMManager:
		if BGMManager.has_method("set_bgm_volume_linear"):
			BGMManager.call("set_bgm_volume_linear", _bgm_volume_linear)
		if BGMManager.has_method("set_sfx_volume_linear"):
			BGMManager.call("set_sfx_volume_linear", _sfx_volume_linear)

func _update_volume_label(label: Label, value_linear: float) -> void:
	if not label:
		return
	var pct := int(round(clampf(value_linear, 0.0, 1.0) * 100.0))
	label.text = "%d%%" % pct

## 应用全屏设置
func apply_fullscreen(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_size(TARGET_RESOLUTION)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		print("已切换到全屏模式 (1920x1080)")
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(TARGET_RESOLUTION)
		var screen_size = DisplayServer.screen_get_size()
		DisplayServer.window_set_position((screen_size - TARGET_RESOLUTION) / 2)
		print("已切换到窗口模式 (1920x1080)")
	
	# 更新状态显示
	_update_status_display(enabled)

## 更新状态显示
func _update_status_display(is_fullscreen: bool) -> void:
	if status_label:
		if is_fullscreen:
			status_label.text = "全屏模式"
			status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
		else:
			status_label.text = "窗口模式"
			status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))
	
	# 仅使用 StatusLabel 显示状态，避免与 CheckButton.text 重复显示

## 更新 CRT 状态显示
func _update_crt_status_display(is_enabled: bool) -> void:
	if crt_status_label:
		if is_enabled:
			crt_status_label.text = "开启"
			crt_status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
		else:
			crt_status_label.text = "关闭"
			crt_status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))
	# 仅使用 StatusLabel 显示状态，避免与 CheckButton.text 重复显示

## 更新 Bloom 状态显示
func _update_bloom_status_display(is_enabled: bool) -> void:
	if bloom_status_label:
		if is_enabled:
			bloom_status_label.text = "开启"
			bloom_status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
		else:
			bloom_status_label.text = "关闭"
			bloom_status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))
	# 仅使用 StatusLabel 显示状态，避免与 CheckButton.text 重复显示

## 更新大招充能特效状态显示
func _update_burst_effect_status_display(is_enabled: bool) -> void:
	if burst_status_label:
		if is_enabled:
			burst_status_label.text = "开启"
			burst_status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
		else:
			burst_status_label.text = "关闭"
			burst_status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))
	# 仅使用 StatusLabel 显示状态，避免与 CheckButton.text 重复显示

## 全屏开关切换
func _on_fullscreen_toggled(button_pressed: bool) -> void:
	apply_fullscreen(button_pressed)
	save_settings()

## CRT 开关切换
func _on_crt_toggled(button_pressed: bool) -> void:
	_apply_crt(button_pressed)
	save_settings()

## Bloom 开关切换
func _on_bloom_toggled(button_pressed: bool) -> void:
	_apply_bloom(button_pressed)
	save_settings()

## 大招充能特效开关切换
func _on_burst_effect_toggled(button_pressed: bool) -> void:
	_apply_burst_ready_effect(button_pressed)
	save_settings()

func _on_bgm_volume_changed(value: float) -> void:
	_bgm_volume_linear = clampf(float(value), 0.0, 1.0)
	if bgm_value_label:
		_update_volume_label(bgm_value_label, _bgm_volume_linear)
	if BGMManager and BGMManager.has_method("set_bgm_volume_linear"):
		BGMManager.call("set_bgm_volume_linear", _bgm_volume_linear)
	save_settings()

func _on_sfx_volume_changed(value: float) -> void:
	_sfx_volume_linear = clampf(float(value), 0.0, 1.0)
	if sfx_value_label:
		_update_volume_label(sfx_value_label, _sfx_volume_linear)
	if BGMManager and BGMManager.has_method("set_sfx_volume_linear"):
		BGMManager.call("set_sfx_volume_linear", _sfx_volume_linear)
	save_settings()

func _apply_crt(is_enabled: bool) -> void:
	_crt_enabled = is_enabled
	_update_crt_status_display(is_enabled)
	if PostProcessManager:
		PostProcessManager.set_crt_enabled(is_enabled)

func _apply_bloom(is_enabled: bool) -> void:
	_bloom_enabled = is_enabled
	_update_bloom_status_display(is_enabled)
	_apply_bloom_to_all_battle_scenes(is_enabled)

func _apply_burst_ready_effect(is_enabled: bool) -> void:
	_burst_ready_effect_enabled = is_enabled
	_update_burst_effect_status_display(is_enabled)
	_apply_burst_effect_to_all_skill_ui(is_enabled)

## 将设置同步给当前场景中的所有 SkillUI（实时生效）
func _apply_burst_effect_to_all_skill_ui(is_enabled: bool) -> void:
	var tree := get_tree()
	if not tree:
		return
	var nodes := tree.get_nodes_in_group("skill_ui")
	for n in nodes:
		var ui := n as Node
		if ui and ui.has_method("set_global_ready_particles_enabled"):
			ui.call("set_global_ready_particles_enabled", is_enabled)

## 将设置同步给当前战斗场景（实时生效）
func _apply_bloom_to_all_battle_scenes(is_enabled: bool) -> void:
	var tree := get_tree()
	if not tree:
		return
	var nodes := tree.get_nodes_in_group("battle_manager")
	for n in nodes:
		var bm := n as Node
		if bm and bm.has_method("set_bloom_enabled"):
			bm.call("set_bloom_enabled", is_enabled)

## 返回按钮
func _on_back_button_pressed() -> void:
	hide_settings()

## 处理ESC键
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("esc") and visible:
		hide_settings()
		get_viewport().set_input_as_handled()
