extends Node2D

## 升级选择界面脚本
## 使用新的升级系统，支持稀有度、权重和条件筛选

signal upgrade_selected(upgrade_id: String)

@onready var upgrade_container: VBoxContainer = $CanvasLayer/VBoxContainer/UpgradeContainer
@onready var title_label: Label = $CanvasLayer/VBoxContainer/TitleLabel

# 可选的升级列表（UpgradeData 类型）
var available_upgrades: Array = []

# 升级选项数量
@export var upgrade_count: int = 3

func _ready() -> void:
	generate_upgrade_options()
	display_upgrades()

## 获取 UpgradeRegistry
func _get_upgrade_registry() -> Node:
	if has_node("/root/UpgradeRegistry"):
		return get_node("/root/UpgradeRegistry")
	return null

## 生成升级选项
func generate_upgrade_options() -> void:
	available_upgrades.clear()
	
	var registry = _get_upgrade_registry()
	if registry == null:
		push_error("UpgradeSelection: UpgradeRegistry 未找到，无法生成升级选项")
		return
	
	# 获取当前角色ID和楼层
	var character_id = ""
	var current_floor = 0
	var current_upgrades: Dictionary = {}
	
	if RunManager:
		if RunManager.current_character:
			character_id = RunManager.current_character.id
		current_floor = RunManager.current_floor
		current_upgrades = RunManager.upgrades
	
	# 使用注册表的随机选取功能
	var picked = registry.pick_random_upgrades(
		character_id,
		current_upgrades,
		current_floor,
		upgrade_count
	)
	
	available_upgrades = picked
	
	if available_upgrades.size() == 0:
		push_warning("UpgradeSelection: 没有可用的升级选项")

## 显示升级选项
func display_upgrades() -> void:
	if not upgrade_container:
		return
	
	# 清空现有按钮
	for child in upgrade_container.get_children():
		child.queue_free()
	
	# 为每个升级创建按钮
	for upgrade in available_upgrades:
		_create_upgrade_button(upgrade)

## 创建新版升级按钮
func _create_upgrade_button(upgrade: UpgradeData) -> void:
	var button = Button.new()
	button.custom_minimum_size = Vector2(450, 120)
	button.pressed.connect(_on_upgrade_selected.bind(upgrade.id))
	
	# 创建容器
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	button.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	
	# 标题行（名称 + 稀有度 + 等级）
	var title_hbox = HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(title_hbox)
	
	# 稀有度标签（使用星星emoji）
	var rarity_label = Label.new()
	rarity_label.text = upgrade.get_rarity_stars()
	rarity_label.add_theme_color_override("font_color", upgrade.get_rarity_color())
	title_hbox.add_child(rarity_label)
	
	# 名称标签
	var name_label = Label.new()
	var current_level = 0
	if RunManager:
		current_level = RunManager.get_upgrade_level(upgrade.id)
	
	if current_level > 0:
		name_label.text = "%s (Lv.%d → %d)" % [upgrade.display_name, current_level, current_level + 1]
	else:
		name_label.text = upgrade.display_name
	
	name_label.add_theme_color_override("font_color", upgrade.get_rarity_color())
	title_hbox.add_child(name_label)
	
	# 最大等级显示
	if upgrade.max_level > 0:
		var max_level_label = Label.new()
		max_level_label.text = "/ %d" % upgrade.max_level
		max_level_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		title_hbox.add_child(max_level_label)
	
	# 描述标签
	var desc_label = Label.new()
	desc_label.text = upgrade.get_formatted_description(current_level)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.x = 400
	vbox.add_child(desc_label)
	
	# 标签显示
	if upgrade.tags.size() > 0:
		var tags_label = Label.new()
		tags_label.text = "标签: " + ", ".join(upgrade.tags)
		tags_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		tags_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(tags_label)
	
	upgrade_container.add_child(button)

## 升级被选中
func _on_upgrade_selected(upgrade_id: String) -> void:
	if RunManager:
		RunManager.add_upgrade(upgrade_id, 1)
	
	emit_signal("upgrade_selected", upgrade_id)
	print("选择升级：", upgrade_id)
	
	# 结束当前战斗局（标记为胜利）
	if RunManager:
		RunManager.end_run(true)
	
	# 返回地图界面
	if GameManager:
		GameManager.go_to_map_view()

## 刷新升级选项（可在运行时调用）
func refresh_options() -> void:
	generate_upgrade_options()
	display_upgrades()