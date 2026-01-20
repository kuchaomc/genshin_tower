extends Control

## 暂停菜单脚本
## 显示暂停菜单，包含功能按钮和角色信息展示

# UI节点引用
@onready var continue_button: Button = $MainContainer/LeftPanel/ContinueButton
@onready var settings_button: Button = $MainContainer/LeftPanel/SettingsButton
@onready var main_menu_button: Button = $MainContainer/LeftPanel/MainMenuButton
@onready var character_portrait: TextureRect = $MainContainer/RightPanel/PortraitContainer/CharacterPortrait
@onready var character_name_label: Label = $MainContainer/RightPanel/CharacterName
@onready var gold_label: Label = $MainContainer/RightPanel/GoldDisplay/GoldLabel
@onready var stats_container: VBoxContainer = $MainContainer/RightPanel/StatsContainer
@onready var upgrades_container: VBoxContainer = $MainContainer/RightPanel/UpgradesScrollContainer/UpgradesContainer
@onready var artifacts_container: HBoxContainer = $MainContainer/RightPanel/ArtifactsContainer

# 设置界面引用
var settings_menu: Control = null

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
	
	# 加载设置界面
	_load_settings_menu()
	
	# 更新角色信息
	update_character_info()

## 加载设置界面
func _load_settings_menu() -> void:
	var settings_scene = preload("res://scenes/ui/settings.tscn")
	if settings_scene:
		settings_menu = settings_scene.instantiate()
		if settings_menu:
			# 添加到与暂停菜单相同的父节点下（通常是CanvasLayer）
			var parent = get_parent()
			if parent:
				parent.add_child(settings_menu)
			else:
				# 如果没有父节点，添加到场景根节点
				get_tree().current_scene.add_child(settings_menu)
			# 连接设置界面关闭信号
			if settings_menu.has_signal("settings_closed"):
				settings_menu.settings_closed.connect(_on_settings_closed)
			print("设置界面已加载到暂停菜单")

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
	
	# 更新摩拉显示
	_update_gold_display()
	
	# 更新角色属性
	_update_stats_display()
	
	# 更新已选择升级
	_update_upgrades_display()
	
	# 更新圣遗物显示
	_update_artifacts_display()

## 获取角色立绘路径
func _get_character_portrait_path(character_id: String) -> String:
	# 根据角色ID构建立绘路径
	match character_id:
		"kamisato_ayaka":
			return "res://textures/characters/ayaka角色立绘.png"
		_:
			return ""

## 更新摩拉显示
func _update_gold_display() -> void:
	if gold_label and RunManager:
		gold_label.text = "摩拉: %d" % RunManager.gold

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

## 更新已选择升级显示
func _update_upgrades_display() -> void:
	if not upgrades_container:
		return
	
	# 清空现有升级显示
	for child in upgrades_container.get_children():
		child.queue_free()
	
	# 如果没有 RunManager 或没有升级，显示提示
	if not RunManager or RunManager.upgrades.is_empty():
		var empty_label = Label.new()
		empty_label.text = "暂无升级"
		empty_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		upgrades_container.add_child(empty_label)
		return
	
	# 检查是否有 UpgradeRegistry
	var registry = null
	if has_node("/root/UpgradeRegistry"):
		registry = get_node("/root/UpgradeRegistry")
	
	# 遍历所有已选择的升级
	for upgrade_id in RunManager.upgrades:
		var level = RunManager.upgrades[upgrade_id]
		
		# 创建升级项容器
		var upgrade_item = PanelContainer.new()
		upgrade_item.custom_minimum_size = Vector2(0, 70)
		
		# 设置背景样式
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.2, 0.2, 0.2, 0.8)
		style_box.border_color = Color(0.4, 0.4, 0.4, 0.5)
		style_box.border_width_left = 2
		style_box.border_width_right = 2
		style_box.border_width_top = 2
		style_box.border_width_bottom = 2
		style_box.corner_radius_top_left = 4
		style_box.corner_radius_top_right = 4
		style_box.corner_radius_bottom_left = 4
		style_box.corner_radius_bottom_right = 4
		upgrade_item.add_theme_stylebox_override("panel", style_box)
		
		var vbox = VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.add_theme_constant_override("separation", 4)
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_bottom", 6)
		margin.add_child(vbox)
		upgrade_item.add_child(margin)
		
		# 创建名称和等级标签
		var name_hbox = HBoxContainer.new()
		vbox.add_child(name_hbox)
		
		var name_label = Label.new()
		name_label.text = upgrade_id
		name_label.add_theme_font_size_override("font_size", 18)
		name_hbox.add_child(name_label)
		
		# 如果有 UpgradeRegistry，获取详细信息
		if registry and registry.has_method("get_upgrade"):
			var upgrade_data = registry.get_upgrade(upgrade_id)
			if upgrade_data:
				# 使用升级数据的显示名称
				name_label.text = upgrade_data.display_name
				
				# 设置稀有度颜色
				var rarity_color = upgrade_data.get_rarity_color()
				name_label.add_theme_color_override("font_color", rarity_color)
				
				# 添加等级标签
				var level_label = Label.new()
				level_label.text = "Lv.%d" % level
				if upgrade_data.max_level > 0:
					level_label.text += "/%d" % upgrade_data.max_level
				level_label.add_theme_font_size_override("font_size", 16)
				level_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
				name_hbox.add_child(level_label)
				
				# 添加描述标签
				var desc_label = Label.new()
				desc_label.text = upgrade_data.get_formatted_description(level)
				desc_label.add_theme_font_size_override("font_size", 14)
				desc_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
				desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				vbox.add_child(desc_label)
			else:
				# 如果没有找到升级数据，显示ID和等级
				var level_label = Label.new()
				level_label.text = " (Lv.%d)" % level
				level_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
				name_hbox.add_child(level_label)
		else:
			# 如果没有 UpgradeRegistry，只显示ID和等级
			var level_label = Label.new()
			level_label.text = " (Lv.%d)" % level
			level_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			name_hbox.add_child(level_label)
		
		# 添加间距
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 4)
		upgrades_container.add_child(upgrade_item)
		upgrades_container.add_child(spacer)

## 更新圣遗物显示
func _update_artifacts_display() -> void:
	if not artifacts_container:
		return
	
	# 清空现有显示
	for child in artifacts_container.get_children():
		child.queue_free()
	
	# 如果没有角色节点，显示空槽位
	if not RunManager or not RunManager.current_character_node:
		_create_empty_artifact_slots()
		return
	
	var artifact_manager = RunManager.current_character_node.get_artifact_manager()
	if not artifact_manager:
		_create_empty_artifact_slots()
		return
	
	# 为每个槽位创建显示
	for slot in ArtifactSlot.get_all_slots():
		var artifact = artifact_manager.get_artifact(slot)
		var level = artifact_manager.get_artifact_level(slot) if artifact else -1
		_create_artifact_slot_display(slot, artifact, level)

## 创建空槽位显示
func _create_empty_artifact_slots() -> void:
	for slot in ArtifactSlot.get_all_slots():
		_create_artifact_slot_display(slot, null, -1)

## 创建圣遗物槽位显示
func _create_artifact_slot_display(slot: ArtifactSlot.SlotType, artifact: ArtifactData, level: int) -> void:
	# 创建槽位容器
	var slot_container = VBoxContainer.new()
	slot_container.custom_minimum_size = Vector2(80, 100)
	slot_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# 创建图标按钮（用于显示和工具提示）
	var icon_button = TextureButton.new()
	icon_button.custom_minimum_size = Vector2(64, 64)
	icon_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	
	# 设置图标
	var icon_path = ""
	if artifact:
		# 已装备：显示圣遗物图标
		icon_path = _get_artifact_icon_path(artifact.name)
	else:
		# 未装备：显示槽位图标
		icon_path = _get_slot_icon_path(slot)
	
	if icon_path:
		var icon = load(icon_path)
		if icon:
			icon_button.texture_normal = icon
	
	# 设置工具提示
	var tooltip_text = _create_artifact_tooltip(slot, artifact, level)
	icon_button.tooltip_text = tooltip_text
	
	# 鼠标悬停时改变光标
	icon_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	slot_container.add_child(icon_button)
	
	# 添加等级指示（如果已装备）
	if artifact and level >= 0:
		var level_label = Label.new()
		var effect_percent = 50 if level == 0 else 100
		level_label.text = "Lv.%d (%d%%)" % [level, effect_percent]
		level_label.add_theme_font_size_override("font_size", 12)
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if level == 0:
			level_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
		else:
			level_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		slot_container.add_child(level_label)
	
	artifacts_container.add_child(slot_container)

## 创建圣遗物工具提示文本
func _create_artifact_tooltip(slot: ArtifactSlot.SlotType, artifact: ArtifactData, level: int) -> String:
	var tooltip_lines: Array[String] = []
	
	if artifact:
		# 已装备的圣遗物
		tooltip_lines.append(artifact.name)
		tooltip_lines.append("槽位: %s" % ArtifactSlot.get_slot_name(slot))
		
		var effect_multiplier = 0.5 if level == 0 else 1.0
		var effect_percent = 50 if level == 0 else 100
		tooltip_lines.append("等级: %d (效果: %d%%)" % [level, effect_percent])
		tooltip_lines.append("")
		tooltip_lines.append("属性加成:")
		
		var bonuses = artifact.get_all_stat_bonuses()
		for stat_name in bonuses:
			var base_value = bonuses[stat_name]
			var actual_value = base_value * effect_multiplier
			var stat_display_name = _get_stat_display_name(stat_name)
			var formatted_value = _format_stat_value(stat_name, actual_value)
			tooltip_lines.append("  %s: %s" % [stat_display_name, formatted_value])
	else:
		# 未装备的槽位
		tooltip_lines.append(ArtifactSlot.get_slot_name(slot))
		tooltip_lines.append("未装备")
	
	return "\n".join(tooltip_lines)

## 获取圣遗物图标路径
func _get_artifact_icon_path(artifact_name: String) -> String:
	match artifact_name:
		"历经风雪的思念":
			return "res://textures/ui/历经风雪的思念.png"
		"摧冰而行的执望":
			return "res://textures/ui/摧冰而行的执望.png"
		"冰雪故园的终期":
			return "res://textures/ui/冰雪故园的终期.png"
		"遍结寒霜的傲骨":
			return "res://textures/ui/遍结寒霜的傲骨.png"
		"破冰踏雪的回音":
			return "res://textures/ui/破冰踏雪的回音.png"
		_:
			return ""

## 获取槽位图标路径
func _get_slot_icon_path(slot: ArtifactSlot.SlotType) -> String:
	match slot:
		ArtifactSlot.SlotType.FLOWER:
			return "res://textures/ui/生之花.png"
		ArtifactSlot.SlotType.PLUME:
			return "res://textures/ui/死之羽.png"
		ArtifactSlot.SlotType.SANDS:
			return "res://textures/ui/时之沙.png"
		ArtifactSlot.SlotType.GOBLET:
			return "res://textures/ui/空之杯.png"
		ArtifactSlot.SlotType.CIRCLET:
			return "res://textures/ui/理之冠.png"
		_:
			return ""

## 获取属性显示名称
func _get_stat_display_name(stat_name: String) -> String:
	match stat_name:
		"max_health":
			return "生命值"
		"defense_percent":
			return "减伤"
		"attack":
			return "攻击力"
		"attack_percent":
			return "攻击力百分比"
		"attack_speed":
			return "攻击速度"
		"knockback_force":
			return "击退"
		"crit_rate":
			return "暴击率"
		"crit_damage":
			return "暴击伤害"
		"move_speed":
			return "移动速度"
		_:
			return stat_name

## 格式化属性值显示
func _format_stat_value(stat_name: String, value: float) -> String:
	# 百分比属性显示为百分比
	if stat_name == "defense_percent" or stat_name == "crit_rate" or stat_name == "attack_percent":
		return "%.1f%%" % (value * 100.0)
	# 其他属性显示为数值
	return "%.1f" % value

## 继续游戏按钮
func _on_continue_pressed() -> void:
	hide_menu()
	resume_game.emit()

## 设置按钮
func _on_settings_pressed() -> void:
	open_settings.emit()
	if settings_menu and settings_menu.has_method("show_settings"):
		settings_menu.show_settings()

## 设置界面关闭回调
func _on_settings_closed() -> void:
	print("设置界面已关闭")

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
