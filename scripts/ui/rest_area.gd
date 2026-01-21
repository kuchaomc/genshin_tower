extends Node2D

## 休息处场景脚本
## 功能：
## - 选择恢复20%血量
## - 选择升级一个已有的升级

signal rest_completed

@onready var title_label: Label = $CanvasLayer/VBoxContainer/TitleLabel
@onready var description_label: Label = $CanvasLayer/VBoxContainer/DescriptionLabel
@onready var choice_container: VBoxContainer = $CanvasLayer/VBoxContainer/ChoiceContainer
@onready var upgrade_selection_container: VBoxContainer = $CanvasLayer/VBoxContainer/UpgradeSelectionContainer
@onready var back_button: Button = $CanvasLayer/VBoxContainer/BackButton

## 当前状态
enum RestState {
	CHOOSING,           # 选择休息方式
	SELECTING_UPGRADE,  # 选择要升级的升级
	COMPLETED           # 完成
}

var current_state: RestState = RestState.CHOOSING

## 玩家已有的升级列表（用于显示可升级的选项）
var owned_upgrades: Array = []

func _ready() -> void:
	_setup_ui()
	_show_rest_choices()
	
	# 连接返回按钮
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

## 初始化UI
func _setup_ui() -> void:
	if title_label:
		title_label.text = "休息处"
	
	if description_label:
		description_label.text = "你找到了一个安静的休息处，可以在这里恢复体力或提升能力。"

## 显示休息选项
func _show_rest_choices() -> void:
	current_state = RestState.CHOOSING
	
	# 清空容器
	_clear_container(choice_container)
	_clear_container(upgrade_selection_container)
	
	# 隐藏升级选择容器
	if upgrade_selection_container:
		upgrade_selection_container.visible = false
	
	if choice_container:
		choice_container.visible = true
	
	# 更新描述
	if description_label:
		description_label.text = "你找到了一个安静的休息处，可以在这里恢复体力或提升能力。"
	
	# 创建选项按钮
	_create_heal_option()
	_create_upgrade_option()

## 创建恢复生命值选项
func _create_heal_option() -> void:
	if not choice_container:
		return
	
	var heal_button = Button.new()
	
	# 计算恢复量
	var heal_percent = 20
	var heal_amount = 0
	if RunManager:
		heal_amount = int(RunManager.max_health * (heal_percent / 100.0))
	
	heal_button.text = "休息恢复 - 恢复 %d%% 生命值（+%d HP）" % [heal_percent, heal_amount]
	heal_button.custom_minimum_size = Vector2(500, 80)
	heal_button.pressed.connect(_on_heal_selected)
	
	# 添加样式
	var heal_label = Label.new()
	heal_label.text = "当前生命值: %d / %d" % [int(RunManager.health) if RunManager else 0, int(RunManager.max_health) if RunManager else 0]
	heal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heal_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	
	choice_container.add_child(heal_button)
	choice_container.add_child(heal_label)
	
	# 添加间隔
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	choice_container.add_child(spacer)

## 创建升级选项
func _create_upgrade_option() -> void:
	if not choice_container:
		return
	
	# 获取已有升级
	_load_owned_upgrades()
	
	var upgrade_button = Button.new()
	
	if owned_upgrades.size() > 0:
		upgrade_button.text = "强化升级 - 选择一个已有的升级进行强化"
		upgrade_button.pressed.connect(_on_upgrade_option_selected)
	else:
		upgrade_button.text = "强化升级 - 没有可强化的升级"
		upgrade_button.disabled = true
	
	upgrade_button.custom_minimum_size = Vector2(500, 80)
	choice_container.add_child(upgrade_button)
	
	# 显示已有升级数量
	var info_label = Label.new()
	info_label.text = "当前拥有 %d 个可强化的升级" % owned_upgrades.size()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	choice_container.add_child(info_label)

## 加载已有升级
func _load_owned_upgrades() -> void:
	owned_upgrades.clear()
	
	if not RunManager:
		return
	
	var registry = _get_upgrade_registry()
	if not registry:
		return
	
	# 遍历玩家已有的升级
	for upgrade_id in RunManager.upgrades:
		var current_level = RunManager.upgrades[upgrade_id]
		var upgrade_data = registry.get_upgrade(upgrade_id)
		
		if upgrade_data == null:
			continue
		
		# 检查是否可以继续升级（未达到最大等级）
		if upgrade_data.max_level <= 0 or current_level < upgrade_data.max_level:
			owned_upgrades.append({
				"id": upgrade_id,
				"data": upgrade_data,
				"current_level": current_level
			})

## 选择恢复生命值
func _on_heal_selected() -> void:
	if not RunManager:
		_complete_rest()
		return
	
	# 恢复20%生命值
	var heal_amount = RunManager.max_health * 0.20
	RunManager.heal(heal_amount)
	
	print("休息处：恢复 %.0f 点生命值" % heal_amount)
	
	# 显示结果
	_show_result("恢复完成！", "恢复了 %.0f 点生命值\n当前生命值: %d / %d" % [heal_amount, int(RunManager.health), int(RunManager.max_health)])

## 选择升级选项
func _on_upgrade_option_selected() -> void:
	current_state = RestState.SELECTING_UPGRADE
	
	# 隐藏选择容器
	if choice_container:
		choice_container.visible = false
	
	# 显示升级选择容器
	if upgrade_selection_container:
		upgrade_selection_container.visible = true
	
	# 更新描述
	if description_label:
		description_label.text = "选择一个升级进行强化（等级+1）："
	
	# 显示可选升级
	_display_upgrade_options()

## 显示可选升级列表
func _display_upgrade_options() -> void:
	_clear_container(upgrade_selection_container)
	
	if not upgrade_selection_container:
		return
	
	# 添加返回按钮
	var back_btn = Button.new()
	back_btn.text = "返回"
	back_btn.custom_minimum_size = Vector2(200, 50)
	back_btn.pressed.connect(_show_rest_choices)
	upgrade_selection_container.add_child(back_btn)
	
	# 添加间隔
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	upgrade_selection_container.add_child(spacer)
	
	# 为每个可升级的升级创建按钮
	for upgrade_info in owned_upgrades:
		_create_upgrade_button(upgrade_info)

## 创建升级按钮
func _create_upgrade_button(upgrade_info: Dictionary) -> void:
	if not upgrade_selection_container:
		return
	
	var upgrade_data: UpgradeData = upgrade_info.data
	var current_level: int = upgrade_info.current_level
	var upgrade_id: String = upgrade_info.id
	
	var button = Button.new()
	button.custom_minimum_size = Vector2(500, 100)
	button.pressed.connect(_on_upgrade_selected.bind(upgrade_id))
	
	# 创建容器
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	button.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)
	
	# 标题行（名称 + 稀有度 + 等级）
	var title_hbox = HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(title_hbox)
	
	# 稀有度标签
	var rarity_label = Label.new()
	rarity_label.text = upgrade_data.get_rarity_stars()
	rarity_label.add_theme_color_override("font_color", upgrade_data.get_rarity_color())
	title_hbox.add_child(rarity_label)
	
	# 名称和等级
	var name_label = Label.new()
	var next_level = current_level + 1
	var max_level_text = ""
	if upgrade_data.max_level > 0:
		max_level_text = " / %d" % upgrade_data.max_level
	
	name_label.text = "%s (Lv.%d → %d%s)" % [upgrade_data.display_name, current_level, next_level, max_level_text]
	name_label.add_theme_color_override("font_color", upgrade_data.get_rarity_color())
	title_hbox.add_child(name_label)
	
	# 描述
	var desc_label = Label.new()
	desc_label.text = upgrade_data.get_formatted_description(current_level)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.x = 450
	vbox.add_child(desc_label)
	
	upgrade_selection_container.add_child(button)

## 选择升级
func _on_upgrade_selected(upgrade_id: String) -> void:
	if not RunManager:
		_complete_rest()
		return
	
	var registry = _get_upgrade_registry()
	if not registry:
		_complete_rest()
		return
	
	var upgrade_data = registry.get_upgrade(upgrade_id)
	if not upgrade_data:
		_complete_rest()
		return
	
	var old_level = RunManager.get_upgrade_level(upgrade_id)
	
	# 升级
	RunManager.add_upgrade(upgrade_id, 1)
	
	var new_level = RunManager.get_upgrade_level(upgrade_id)
	
	print("休息处：强化 %s (Lv.%d → Lv.%d)" % [upgrade_data.display_name, old_level, new_level])
	
	# 显示结果
	_show_result("强化成功！", "%s\nLv.%d → Lv.%d\n%s" % [
		upgrade_data.display_name,
		old_level,
		new_level,
		upgrade_data.get_formatted_description(new_level - 1)
	])

## 显示结果
func _show_result(result_title: String, result_text: String) -> void:
	current_state = RestState.COMPLETED
	
	# 隐藏所有选择容器
	if choice_container:
		choice_container.visible = false
	if upgrade_selection_container:
		upgrade_selection_container.visible = false
	
	# 更新标题和描述
	if title_label:
		title_label.text = result_title
	if description_label:
		description_label.text = result_text
	
	# 显示返回按钮
	if back_button:
		back_button.visible = true
		back_button.text = "返回地图"

## 完成休息
func _complete_rest() -> void:
	emit_signal("rest_completed")
	
	# 返回地图
	if GameManager:
		GameManager.go_to_map_view()

## 返回按钮点击
func _on_back_pressed() -> void:
	_complete_rest()

## 清空容器
func _clear_container(container: Control) -> void:
	if not container:
		return
	
	for child in container.get_children():
		child.queue_free()

## 获取 UpgradeRegistry
func _get_upgrade_registry() -> Node:
	# UpgradeRegistry 是 Autoload（见 project.godot），直接使用全局名即可
	return UpgradeRegistry if is_instance_valid(UpgradeRegistry) else null
