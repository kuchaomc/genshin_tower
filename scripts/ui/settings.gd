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
@onready var movement_trail_switch: CheckButton = $MainContainer/MovementTrailContainer/SwitchContainerMovementTrail/MovementTrailSwitch
@onready var movement_trail_status_label: Label = $MainContainer/MovementTrailContainer/SwitchContainerMovementTrail/StatusLabelMovementTrail
@onready var nsfw_switch: CheckButton = $MainContainer/NSFWContainer/SwitchContainerNSFW/NSFWSwitch
@onready var nsfw_status_label: Label = $MainContainer/NSFWContainer/SwitchContainerNSFW/StatusLabelNSFW

@onready var bgm_volume_slider: HSlider = $MainContainer/AudioBGMContainer/SliderContainerBGM/BGMVolumeSlider
@onready var bgm_value_label: Label = $MainContainer/AudioBGMContainer/SliderContainerBGM/BGMValueLabel
@onready var sfx_volume_slider: HSlider = $MainContainer/AudioSFXContainer/SliderContainerSFX/SFXVolumeSlider
@onready var sfx_value_label: Label = $MainContainer/AudioSFXContainer/SliderContainerSFX/SFXValueLabel

@onready var voice_volume_slider: HSlider = $MainContainer/AudioVoiceContainer/SliderContainerVoice/VoiceVolumeSlider
@onready var voice_value_label: Label = $MainContainer/AudioVoiceContainer/SliderContainerVoice/VoiceValueLabel

@onready var back_button: Button = $MainContainer/BackButton

# 信号
signal settings_closed
signal nsfw_changed(is_enabled: bool)

# 侧滑动画与输入接管
var _slide_tween: Tween
var _esc_close_enabled: bool = true

# 设置文件路径
const SETTINGS_FILE_PATH = "user://settings.cfg"
const CONFIG_SECTION = "display"
const CONFIG_KEY_FULLSCREEN = "fullscreen"
const CONFIG_SECTION_POSTPROCESS = "postprocess"
const CONFIG_KEY_CRT_ENABLED = "crt_enabled"
const CONFIG_KEY_BLOOM_ENABLED = "bloom_enabled"
const CONFIG_SECTION_UI = "ui"
const CONFIG_KEY_BURST_READY_EFFECT_ENABLED = "burst_ready_effect_enabled"
const CONFIG_KEY_NSFW_ENABLED = "nsfw_enabled"

const CONFIG_SECTION_VFX = "vfx"
const CONFIG_KEY_MOVEMENT_TRAIL_ENABLED = "movement_trail_enabled"

const CONFIG_SECTION_AUDIO = "audio"
const CONFIG_KEY_BGM_VOLUME = "bgm_volume"
const CONFIG_KEY_SFX_VOLUME = "sfx_volume"
const CONFIG_KEY_VOICE_VOLUME = "voice_volume"

# 目标分辨率
const TARGET_RESOLUTION = Vector2i(1920, 1080)

# 保存防抖：避免滑条拖动时频繁写入 user:// 配置文件造成卡顿
const _SAVE_DEBOUNCE_SECONDS: float = 0.25

var _crt_enabled: bool = true
var _bloom_enabled: bool = true
var _burst_ready_effect_enabled: bool = true
var _movement_trail_enabled: bool = true
var _nsfw_enabled: bool = false

const _DEV_PASSWORD: String = "kuchao"

var _nsfw_pwd_window: Window
var _nsfw_pwd_edit: LineEdit
var _nsfw_pwd_error: Label

var _bgm_volume_linear: float = 1.0
var _sfx_volume_linear: float = 1.0
var _voice_volume_linear: float = 1.0

var _save_timer: Timer
var _save_pending: bool = false

func _ready() -> void:
	# 设置process_mode为ALWAYS，确保暂停时仍能响应输入
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 保存防抖Timer：UI改变后延迟写入配置文件
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = _SAVE_DEBOUNCE_SECONDS
	_save_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_save_timer.timeout.connect(_on_save_timer_timeout)
	add_child(_save_timer)
	
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
	if movement_trail_switch:
		movement_trail_switch.toggled.connect(_on_movement_trail_toggled)
	if nsfw_switch:
		nsfw_switch.toggled.connect(_on_nsfw_toggled)
	if bgm_volume_slider:
		bgm_volume_slider.value_changed.connect(_on_bgm_volume_changed)
	if sfx_volume_slider:
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	if voice_volume_slider:
		voice_volume_slider.value_changed.connect(_on_voice_volume_changed)
	
	# 加载设置
	load_settings()
	
	# 初始隐藏
	visible = false

## 显示设置界面
func show_settings() -> void:
	# 防止从侧滑隐藏态返回时offset未复位导致界面仍在屏幕外
	offset_left = 0.0
	offset_right = 0.0
	visible = true
	# 更新UI状态
	update_ui_state()

## 隐藏设置界面
func hide_settings() -> void:
	_flush_pending_save()
	# 防止下次直接 show_settings 时仍处于屏幕外
	offset_left = 0.0
	offset_right = 0.0
	visible = false
	settings_closed.emit()

func set_esc_close_enabled(enabled: bool) -> void:
	_esc_close_enabled = enabled

func set_back_button_visible(is_visible: bool) -> void:
	if back_button:
		back_button.visible = is_visible

func set_background_visible(is_visible: bool) -> void:
	var bg := get_node_or_null("Background") as CanvasItem
	if bg:
		bg.visible = is_visible

func _kill_slide_tween() -> void:
	if _slide_tween and _slide_tween.is_running():
		_slide_tween.kill()
	_slide_tween = null

## 从右侧滑入显示（用于主界面/暂停菜单右侧抽屉同款效果）
func show_settings_slide_from_right() -> void:
	show_settings()
	await get_tree().process_frame
	var w := get_viewport().get_visible_rect().size.x
	# anchors 为全屏时：同时设置左右offset可实现整体水平平移
	offset_left = w
	offset_right = w
	_kill_slide_tween()
	_slide_tween = create_tween()
	_slide_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_slide_tween.set_trans(Tween.TRANS_CUBIC)
	_slide_tween.set_ease(Tween.EASE_OUT)
	_slide_tween.parallel().tween_property(self, "offset_left", 0.0, 0.32)
	_slide_tween.parallel().tween_property(self, "offset_right", 0.0, 0.32)

## 向右侧滑出隐藏（关闭后再发出 settings_closed）
func hide_settings_slide_to_right() -> void:
	if not visible:
		return
	_flush_pending_save()
	await get_tree().process_frame
	var w := get_viewport().get_visible_rect().size.x
	_kill_slide_tween()
	_slide_tween = create_tween()
	_slide_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_slide_tween.set_trans(Tween.TRANS_CUBIC)
	_slide_tween.set_ease(Tween.EASE_IN)
	_slide_tween.parallel().tween_property(self, "offset_left", w, 0.24)
	_slide_tween.parallel().tween_property(self, "offset_right", w, 0.24)
	_slide_tween.finished.connect(func() -> void:
		# 复位offset，保证后续普通 show_settings 也能直接显示
		offset_left = 0.0
		offset_right = 0.0
		visible = false
		settings_closed.emit()
	)

func _exit_tree() -> void:
	# 防止节点被移除时丢失最后一次修改
	_flush_pending_save()

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
	if movement_trail_switch and movement_trail_status_label:
		movement_trail_switch.button_pressed = _movement_trail_enabled
		_update_movement_trail_status_display(_movement_trail_enabled)
	if nsfw_switch and nsfw_status_label:
		nsfw_switch.set_block_signals(true)
		nsfw_switch.button_pressed = _nsfw_enabled
		nsfw_switch.set_block_signals(false)
		_update_nsfw_status_display(_nsfw_enabled)
	if bgm_volume_slider and bgm_value_label:
		bgm_volume_slider.set_value_no_signal(_bgm_volume_linear)
		_update_volume_label(bgm_value_label, _bgm_volume_linear)
	if sfx_volume_slider and sfx_value_label:
		sfx_volume_slider.set_value_no_signal(_sfx_volume_linear)
		_update_volume_label(sfx_value_label, _sfx_volume_linear)
	if voice_volume_slider and voice_value_label:
		voice_volume_slider.set_value_no_signal(_voice_volume_linear)
		_update_volume_label(voice_value_label, _voice_volume_linear)

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
		# 读取NSFW表情设置
		var nsfw_enabled: bool = bool(config.get_value(CONFIG_SECTION_UI, CONFIG_KEY_NSFW_ENABLED, false))
		_apply_nsfw(nsfw_enabled)
		# 读取移动拖尾设置
		var movement_trail_enabled: bool = bool(config.get_value(CONFIG_SECTION_VFX, CONFIG_KEY_MOVEMENT_TRAIL_ENABLED, true))
		_apply_movement_trail(movement_trail_enabled)
		# 读取音量设置
		var bgm_volume: float = float(config.get_value(CONFIG_SECTION_AUDIO, CONFIG_KEY_BGM_VOLUME, 1.0))
		var sfx_volume: float = float(config.get_value(CONFIG_SECTION_AUDIO, CONFIG_KEY_SFX_VOLUME, 1.0))
		var voice_volume: float = float(config.get_value(CONFIG_SECTION_AUDIO, CONFIG_KEY_VOICE_VOLUME, 1.0))
		_apply_audio_volumes(bgm_volume, sfx_volume, voice_volume)
		update_ui_state()
		print("设置已加载")
	else:
		# 如果文件不存在，使用默认设置（窗口模式）
		print("设置文件不存在，使用默认设置（窗口模式）")
		apply_fullscreen(false)
		_apply_crt(true)
		_apply_bloom(true)
		_apply_burst_ready_effect(true)
		_apply_nsfw(false)
		_apply_movement_trail(true)
		_apply_audio_volumes(1.0, 1.0, 1.0)
		update_ui_state()
		_save_settings_now()

## 保存设置
func save_settings() -> void:
	_save_settings_now()

func _request_save_settings() -> void:
	_save_pending = true
	if _save_timer:
		_save_timer.start()
	else:
		_save_settings_now()

func _on_save_timer_timeout() -> void:
	_save_settings_now()

func _flush_pending_save() -> void:
	if not _save_pending:
		return
	if _save_timer:
		_save_timer.stop()
	_save_settings_now()

func _save_settings_now() -> void:
	_save_pending = false
	if _save_timer:
		_save_timer.stop()
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
	# 保存NSFW表情设置
	config.set_value(CONFIG_SECTION_UI, CONFIG_KEY_NSFW_ENABLED, _nsfw_enabled)
	# 保存移动拖尾设置
	config.set_value(CONFIG_SECTION_VFX, CONFIG_KEY_MOVEMENT_TRAIL_ENABLED, _movement_trail_enabled)
	# 保存音量设置
	config.set_value(CONFIG_SECTION_AUDIO, CONFIG_KEY_BGM_VOLUME, _bgm_volume_linear)
	config.set_value(CONFIG_SECTION_AUDIO, CONFIG_KEY_SFX_VOLUME, _sfx_volume_linear)
	config.set_value(CONFIG_SECTION_AUDIO, CONFIG_KEY_VOICE_VOLUME, _voice_volume_linear)
	config.save(SETTINGS_FILE_PATH)
	print("设置已保存")

func _apply_audio_volumes(bgm_linear: float, sfx_linear: float, voice_linear: float) -> void:
	_bgm_volume_linear = clampf(bgm_linear, 0.0, 1.0)
	_sfx_volume_linear = clampf(sfx_linear, 0.0, 1.0)
	_voice_volume_linear = clampf(voice_linear, 0.0, 1.0)
	if BGMManager:
		if BGMManager.has_method("set_bgm_volume_linear"):
			BGMManager.call("set_bgm_volume_linear", _bgm_volume_linear)
		if BGMManager.has_method("set_sfx_volume_linear"):
			BGMManager.call("set_sfx_volume_linear", _sfx_volume_linear)
		if BGMManager.has_method("set_voice_volume_linear"):
			BGMManager.call("set_voice_volume_linear", _voice_volume_linear)

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

## 更新移动拖尾状态显示
func _update_movement_trail_status_display(is_enabled: bool) -> void:
	if movement_trail_status_label:
		if is_enabled:
			movement_trail_status_label.text = "开启"
			movement_trail_status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
		else:
			movement_trail_status_label.text = "关闭"
			movement_trail_status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))

## 更新NSFW表情状态显示
func _update_nsfw_status_display(is_enabled: bool) -> void:
	if nsfw_status_label:
		if is_enabled:
			nsfw_status_label.text = "开启"
			nsfw_status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
		else:
			nsfw_status_label.text = "关闭"
			nsfw_status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))

## 全屏开关切换
func _on_fullscreen_toggled(button_pressed: bool) -> void:
	apply_fullscreen(button_pressed)
	_request_save_settings()

## CRT 开关切换
func _on_crt_toggled(button_pressed: bool) -> void:
	_apply_crt(button_pressed)
	_request_save_settings()

## Bloom 开关切换
func _on_bloom_toggled(button_pressed: bool) -> void:
	_apply_bloom(button_pressed)
	_request_save_settings()

## 大招充能特效开关切换
func _on_burst_effect_toggled(button_pressed: bool) -> void:
	_apply_burst_ready_effect(button_pressed)
	_request_save_settings()

## 移动拖尾开关切换
func _on_movement_trail_toggled(button_pressed: bool) -> void:
	_apply_movement_trail(button_pressed)
	_request_save_settings()

## NSFW表情开关切换
func _on_nsfw_toggled(button_pressed: bool) -> void:
	if button_pressed:
		# 先将开关弹回关闭，再进行密码验证；验证通过才真正开启
		_set_nsfw_switch_pressed_no_signal(false)
		_open_nsfw_password_prompt()
		return
	_apply_nsfw(false)
	_request_save_settings()

func _on_bgm_volume_changed(value: float) -> void:
	_bgm_volume_linear = clampf(float(value), 0.0, 1.0)
	if bgm_value_label:
		_update_volume_label(bgm_value_label, _bgm_volume_linear)
	if BGMManager and BGMManager.has_method("set_bgm_volume_linear"):
		BGMManager.call("set_bgm_volume_linear", _bgm_volume_linear)
	_request_save_settings()

func _on_sfx_volume_changed(value: float) -> void:
	_sfx_volume_linear = clampf(float(value), 0.0, 1.0)
	if sfx_value_label:
		_update_volume_label(sfx_value_label, _sfx_volume_linear)
	if BGMManager and BGMManager.has_method("set_sfx_volume_linear"):
		BGMManager.call("set_sfx_volume_linear", _sfx_volume_linear)
	_request_save_settings()

func _on_voice_volume_changed(value: float) -> void:
	_voice_volume_linear = clampf(float(value), 0.0, 1.0)
	if voice_value_label:
		_update_volume_label(voice_value_label, _voice_volume_linear)
	if BGMManager and BGMManager.has_method("set_voice_volume_linear"):
		BGMManager.call("set_voice_volume_linear", _voice_volume_linear)
	_request_save_settings()

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

func _apply_movement_trail(is_enabled: bool) -> void:
	_movement_trail_enabled = is_enabled
	_update_movement_trail_status_display(is_enabled)
	_apply_movement_trail_to_all_characters(is_enabled)

func _apply_nsfw(is_enabled: bool) -> void:
	_nsfw_enabled = is_enabled
	_update_nsfw_status_display(is_enabled)
	_apply_nsfw_to_all_battle_scenes(is_enabled)
	nsfw_changed.emit(is_enabled)


func _set_nsfw_switch_pressed_no_signal(is_pressed: bool) -> void:
	if not nsfw_switch:
		return
	nsfw_switch.set_block_signals(true)
	nsfw_switch.button_pressed = is_pressed
	nsfw_switch.set_block_signals(false)


func _open_nsfw_password_prompt() -> void:
	# 懒加载创建一次即可
	if _nsfw_pwd_window == null:
		_build_nsfw_password_window()
	if _nsfw_pwd_error:
		_nsfw_pwd_error.text = ""
	if _nsfw_pwd_edit:
		_nsfw_pwd_edit.text = ""
	_nsfw_pwd_window.popup_centered()
	await get_tree().process_frame
	if _nsfw_pwd_edit:
		_nsfw_pwd_edit.grab_focus()


func _build_nsfw_password_window() -> void:
	_nsfw_pwd_window = Window.new()
	_nsfw_pwd_window.title = "开发者验证"
	_nsfw_pwd_window.visible = false
	_nsfw_pwd_window.transient = true
	_nsfw_pwd_window.exclusive = true
	_nsfw_pwd_window.unresizable = true
	_nsfw_pwd_window.size = Vector2i(420, 170)
	_nsfw_pwd_window.close_requested.connect(func(): _nsfw_pwd_window.hide())
	add_child(_nsfw_pwd_window)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_top = 12
	v.offset_right = -12
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 8)
	_nsfw_pwd_window.add_child(v)

	var tip := Label.new()
	tip.text = "请输入开发者密码："
	v.add_child(tip)

	_nsfw_pwd_edit = LineEdit.new()
	_nsfw_pwd_edit.placeholder_text = "密码"
	_nsfw_pwd_edit.secret = true
	_nsfw_pwd_edit.text_submitted.connect(func(_t: String): _submit_nsfw_password())
	v.add_child(_nsfw_pwd_edit)

	_nsfw_pwd_error = Label.new()
	_nsfw_pwd_error.text = ""
	_nsfw_pwd_error.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	v.add_child(_nsfw_pwd_error)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)

	var ok := Button.new()
	ok.text = "确认"
	ok.pressed.connect(_submit_nsfw_password)
	h.add_child(ok)

	var cancel := Button.new()
	cancel.text = "取消"
	cancel.pressed.connect(func(): _nsfw_pwd_window.hide())
	h.add_child(cancel)


func _submit_nsfw_password() -> void:
	if _nsfw_pwd_edit == null:
		return
	var input := _nsfw_pwd_edit.text.strip_edges()
	if input == _DEV_PASSWORD:
		_apply_nsfw(true)
		_set_nsfw_switch_pressed_no_signal(true)
		_request_save_settings()
		if _nsfw_pwd_window:
			_nsfw_pwd_window.hide()
	else:
		if _nsfw_pwd_error:
			_nsfw_pwd_error.text = "密码错误"
		_nsfw_pwd_edit.select_all()
		_nsfw_pwd_edit.grab_focus()

## 将设置同步给当前场景中的所有角色（实时生效）
func _apply_movement_trail_to_all_characters(is_enabled: bool) -> void:
	var tree := get_tree()
	if not tree:
		return
	var nodes := tree.get_nodes_in_group("characters")
	for n in nodes:
		var c := n as Node
		if c and c.has_method("set_movement_trail_enabled"):
			c.call("set_movement_trail_enabled", is_enabled)

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

## 将设置同步给当前战斗场景（实时生效）
func _apply_nsfw_to_all_battle_scenes(is_enabled: bool) -> void:
	var tree := get_tree()
	if not tree:
		return
	var nodes := tree.get_nodes_in_group("battle_manager")
	for n in nodes:
		var bm := n as Node
		if bm and bm.has_method("set_nsfw_enabled"):
			bm.call("set_nsfw_enabled", is_enabled)

## 返回按钮
func _on_back_button_pressed() -> void:
	hide_settings()

## 处理ESC键
func _input(event: InputEvent) -> void:
	if not _esc_close_enabled:
		return
	if event.is_action_pressed("esc") and visible:
		hide_settings()
		get_viewport().set_input_as_handled()
