extends Node2D

# 预加载游戏场景
var game_scene = preload("res://scenes/battle/battle_scene.tscn")

# 弹窗节点引用
@onready var help_panel: Panel = $CanvasLayer/Panel
@onready var close_button: Button = $CanvasLayer/Panel/CloseButton

# 设置界面引用
var settings_menu: Control = null

# 当场景加载完成时调用
func _ready() -> void:
	# 连接按钮信号
	var start_button = $CanvasLayer/VBoxContainer/Button
	var help_button = $CanvasLayer/VBoxContainer/Button2
	var settings_button = $CanvasLayer/VBoxContainer/Button4
	var quit_button = $CanvasLayer/VBoxContainer/Button3
	
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	if help_button:
		help_button.pressed.connect(_on_help_button_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_button_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	# 设置帮助弹窗初始状态为隐藏
	if help_panel:
		help_panel.hide()
	
	# 加载设置界面
	_load_settings_menu()
	
	print("主界面脚本已加载，帮助弹窗已初始化")

## 加载设置界面
func _load_settings_menu() -> void:
	var settings_scene = preload("res://scenes/ui/settings.tscn")
	if settings_scene:
		settings_menu = settings_scene.instantiate()
		if settings_menu:
			# 添加到CanvasLayer下
			var canvas_layer = $CanvasLayer
			if canvas_layer:
				canvas_layer.add_child(settings_menu)
				# 连接设置界面关闭信号
				if settings_menu.has_signal("settings_closed"):
					settings_menu.settings_closed.connect(_on_settings_closed)
				print("设置界面已加载")

# 开始游戏按钮回调
func _on_start_button_pressed() -> void:
	print("开始游戏按钮被点击")
	# 切换到角色选择界面
	if GameManager:
		GameManager.go_to_character_select()
	else:
		# 如果没有GameManager，直接进入游戏场景
		get_tree().change_scene_to_packed(game_scene)

# 游戏说明按钮回调
func _on_help_button_pressed() -> void:
	print("游戏说明按钮被点击")
	if help_panel:
		help_panel.show()

# 设置按钮回调
func _on_settings_button_pressed() -> void:
	print("设置按钮被点击")
	if settings_menu and settings_menu.has_method("show_settings"):
		settings_menu.show_settings()

# 设置界面关闭回调
func _on_settings_closed() -> void:
	print("设置界面已关闭")

# 退出游戏按钮回调
func _on_quit_button_pressed() -> void:
	print("退出游戏按钮被点击")
	get_tree().quit()

# 关闭弹窗按钮回调
func _on_close_button_pressed() -> void:
	print("关闭帮助弹窗")
	if help_panel:
		help_panel.hide()
