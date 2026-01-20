extends Control

## 设置中心脚本
## 提供游戏设置功能，包括全屏切换等

# UI节点引用
@onready var fullscreen_switch: CheckButton = $MainContainer/FullscreenContainer/SwitchContainer/FullscreenSwitch
@onready var status_label: Label = $MainContainer/FullscreenContainer/SwitchContainer/StatusLabel
@onready var back_button: Button = $MainContainer/BackButton

# 信号
signal settings_closed

# 设置文件路径
const SETTINGS_FILE_PATH = "user://settings.cfg"
const CONFIG_SECTION = "display"
const CONFIG_KEY_FULLSCREEN = "fullscreen"

# 目标分辨率
const TARGET_RESOLUTION = Vector2i(1920, 1080)

func _ready() -> void:
	# 设置process_mode为ALWAYS，确保暂停时仍能响应输入
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 连接按钮信号
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	if fullscreen_switch:
		fullscreen_switch.toggled.connect(_on_fullscreen_toggled)
	
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
		var is_fullscreen = _is_fullscreen_mode()
		fullscreen_switch.button_pressed = is_fullscreen
		_update_status_display(is_fullscreen)

## 加载设置
func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE_PATH)
	
	if err == OK:
		# 读取全屏设置
		var fullscreen = config.get_value(CONFIG_SECTION, CONFIG_KEY_FULLSCREEN, false)
		apply_fullscreen(fullscreen)
		update_ui_state()
		print("设置已加载")
	else:
		# 如果文件不存在，使用默认设置（窗口模式）
		print("设置文件不存在，使用默认设置（窗口模式）")
		apply_fullscreen(false)
		update_ui_state()

## 保存设置
func save_settings() -> void:
	var config = ConfigFile.new()
	
	# 读取现有设置（如果文件存在）
	config.load(SETTINGS_FILE_PATH)
	
	# 保存全屏设置
	var is_fullscreen = _is_fullscreen_mode()
	config.set_value(CONFIG_SECTION, CONFIG_KEY_FULLSCREEN, is_fullscreen)
	config.save(SETTINGS_FILE_PATH)
	print("设置已保存")

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
	
	if fullscreen_switch:
		fullscreen_switch.text = "开启" if is_fullscreen else "关闭"

## 全屏开关切换
func _on_fullscreen_toggled(button_pressed: bool) -> void:
	apply_fullscreen(button_pressed)
	save_settings()

## 返回按钮
func _on_back_button_pressed() -> void:
	hide_settings()

## 处理ESC键
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("esc") and visible:
		hide_settings()
		get_viewport().set_input_as_handled()
