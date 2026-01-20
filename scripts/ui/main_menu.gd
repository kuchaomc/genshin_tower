extends Node2D

# 预加载游戏场景
var game_scene = preload("res://scenes/battle/battle_scene.tscn")

# 弹窗节点引用
@onready var help_panel: Panel = $CanvasLayer/Panel
@onready var close_button: Button = $CanvasLayer/Panel/CloseButton

# 当场景加载完成时调用
func _ready() -> void:
	# 连接按钮信号
	var start_button = $CanvasLayer/VBoxContainer/Button
	var help_button = $CanvasLayer/VBoxContainer/Button2
	var quit_button = $CanvasLayer/VBoxContainer/Button3
	
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	if help_button:
		help_button.pressed.connect(_on_help_button_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	# 设置帮助弹窗初始状态为隐藏
	if help_panel:
		help_panel.hide()
	
	print("主界面脚本已加载，帮助弹窗已初始化")

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

# 退出游戏按钮回调
func _on_quit_button_pressed() -> void:
	print("退出游戏按钮被点击")
	get_tree().quit()

# 关闭弹窗按钮回调
func _on_close_button_pressed() -> void:
	print("关闭帮助弹窗")
	if help_panel:
		help_panel.hide()
