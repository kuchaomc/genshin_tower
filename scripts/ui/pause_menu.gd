extends Control

## 暂停菜单脚本
## 显示暂停菜单，包含功能按钮和角色信息展示

# UI节点引用
@onready var continue_button: Button = $MainContainer/LeftPanel/ContinueButton
@onready var settings_button: Button = $MainContainer/LeftPanel/SettingsButton
@onready var main_menu_button: Button = $MainContainer/LeftPanel/MainMenuButton
@onready var character_portrait: TextureRect = $MainContainer/RightPanel/PortraitContainer/CharacterPortrait
@onready var character_name_label: Label = $MainContainer/RightPanel/CharacterName
@onready var stats_container: VBoxContainer = $MainContainer/RightPanel/StatsContainer

# 信号
signal resume_game
signal open_settings
signal return_to_main_menu

func _ready() -> void:
	# 设置process_mode为ALWAYS，确保暂停时仍能响应输入
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 连接按钮信号
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	
	# 初始隐藏
	visible = false
	
	# 更新角色信息
	update_character_info()

## 显示暂停菜单
func show_menu() -> void:
	visible = true
	# 暂停游戏树
	# 这会自动暂停所有使用默认PROCESS_MODE_INHERIT的节点，包括：
	# - 所有节点的 _process、_physics_process、_input 等函数
	# - Timer节点（敌人生成计时器等）
	# - get_tree().create_timer() 创建的计时器（warning动画、重击伤害序列等）
	# - AnimatedSprite2D的动画播放（包括重击动画）
	# - 角色的攻击、移动、伤害判定等所有逻辑
	# - 敌人的AI、移动、伤害判定等所有逻辑
	get_tree().paused = true
	# 确保重击动画在暂停时保持可见（不会被隐藏）
	_preserve_charged_effect_visibility()
	update_character_info()

## 隐藏暂停菜单
func hide_menu() -> void:
	visible = false
	# 恢复游戏树，所有暂停的内容会自动恢复
	get_tree().paused = false

## 确保重击动画在暂停时保持可见
func _preserve_charged_effect_visibility() -> void:
	# 查找场景中的玩家角色
	var battle_manager = get_tree().get_first_node_in_group("battle_manager")
	if not battle_manager:
		var scene_root = get_tree().current_scene
		if scene_root and scene_root is BattleManager:
			battle_manager = scene_root
	
	if battle_manager and battle_manager.has_method("get_player"):
		var player = battle_manager.get_player()
		if player and player.has_method("get_charged_effect"):
			var charged_effect = player.get_charged_effect()
			if charged_effect:
				# 如果动画正在播放且可见，确保它在暂停时保持可见
				# AnimatedSprite2D在暂停时会自动保持当前帧
				# 我们只需要确保它不会被动画完成信号隐藏
				if charged_effect.visible and charged_effect.is_playing():
					# 动画会保持当前帧，不需要额外操作
					pass

## 更新角色信息显示
func update_character_info() -> void:
	if not RunManager or not RunManager.current_character:
		return
	
	var character_data = RunManager.current_character
	
	# 更新角色名称
	if character_name_label:
		character_name_label.text = character_data.display_name
	
	# 更新角色立绘
	if character_portrait:
		# 尝试加载角色立绘
		var portrait_path = _get_character_portrait_path(character_data.id)
		if portrait_path:
			var portrait_texture = load(portrait_path)
			if portrait_texture:
				character_portrait.texture = portrait_texture
				character_portrait.visible = true
				print("已加载角色立绘: ", portrait_path)
			else:
				print("警告：无法加载立绘文件: ", portrait_path)
				# 如果没有立绘，尝试使用icon
				if character_data.icon:
					character_portrait.texture = character_data.icon
					character_portrait.visible = true
				else:
					character_portrait.visible = false
		elif character_data.icon:
			character_portrait.texture = character_data.icon
			character_portrait.visible = true
		else:
			character_portrait.visible = false
			print("警告：角色没有立绘或图标")
	
	# 更新角色属性
	_update_stats_display()

## 获取角色立绘路径
func _get_character_portrait_path(character_id: String) -> String:
	# 根据角色ID构建立绘路径
	match character_id:
		"kamisato_ayaka":
			return "res://textures/characters/ayaka角色立绘.png"
		_:
			return ""

## 更新属性显示
func _update_stats_display() -> void:
	if not RunManager or not RunManager.current_character:
		return
	
	var character_data = RunManager.current_character
	var stats = character_data.get_stats()
	
	# 获取当前玩家实例（如果存在）
	var current_hp = RunManager.health
	var max_hp = RunManager.max_health
	
	# 如果战斗场景中有玩家实例，使用实时数据
	var battle_manager = get_tree().get_first_node_in_group("battle_manager")
	if not battle_manager:
		# 查找场景根节点（通常是BattleManager）
		var scene_root = get_tree().current_scene
		if scene_root and scene_root is BattleManager:
			battle_manager = scene_root
	
	if battle_manager and battle_manager.has_method("get_player"):
		var player = battle_manager.get_player()
		if player:
			current_hp = player.current_health
			max_hp = player.max_health
			if player.current_stats:
				stats = player.current_stats
	
	# 更新各个属性标签
	var labels = stats_container.get_children()
	if labels.size() >= 7:
		labels[0].text = "生命值: %d/%d" % [int(current_hp), int(max_hp)]
		labels[1].text = "攻击力: %.0f" % stats.attack
		labels[2].text = "防御: %.0f%%" % (stats.defense_percent * 100)
		labels[3].text = "移动速度: %.0f" % stats.move_speed
		labels[4].text = "暴击率: %.0f%%" % (stats.crit_rate * 100)
		labels[5].text = "暴击伤害: +%.0f%%" % (stats.crit_damage * 100)
		labels[6].text = "攻击速度: %.1fx" % stats.attack_speed

## 继续游戏按钮
func _on_continue_pressed() -> void:
	hide_menu()
	resume_game.emit()

## 设置按钮
func _on_settings_pressed() -> void:
	open_settings.emit()
	# TODO: 实现设置界面

## 返回主菜单按钮
func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	return_to_main_menu.emit()
	if GameManager:
		GameManager.go_to_main_menu()

## 处理ESC键（由外部调用或内部调用）
func handle_esc_key() -> void:
	if visible:
		# 如果菜单已显示，关闭它
		hide_menu()
	else:
		# 如果菜单未显示，打开它
		show_menu()

func _input(event: InputEvent) -> void:
	# 确保暂停菜单可以响应ESC键
	# 只有在菜单可见时才处理ESC键（关闭菜单）
	# 打开菜单由battle_manager处理
	if event.is_action_pressed("esc") and visible:
		hide_menu()
		get_viewport().set_input_as_handled()
