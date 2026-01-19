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

# 是否使用旧版升级系统（兼容模式）
var _use_legacy_system: bool = false

# 旧版升级数据（兼容）
const LEGACY_UPGRADES = {
	"damage": {
		"name": "伤害提升",
		"description": "增加10%攻击伤害",
		"max_level": 5
	},
	"health": {
		"name": "生命提升",
		"description": "增加20点最大生命值",
		"max_level": 5
	},
	"speed": {
		"name": "速度提升",
		"description": "增加10%移动速度",
		"max_level": 5
	},
	"attack_speed": {
		"name": "攻击速度",
		"description": "增加10%攻击速度",
		"max_level": 5
	}
}

func _ready() -> void:
	# 检查是否有新的升级系统
	_use_legacy_system = not _has_upgrade_registry()
	
	generate_upgrade_options()
	display_upgrades()

## 检查是否有 UpgradeRegistry
func _has_upgrade_registry() -> bool:
	return has_node("/root/UpgradeRegistry")

## 获取 UpgradeRegistry
func _get_upgrade_registry() -> Node:
	if has_node("/root/UpgradeRegistry"):
		return get_node("/root/UpgradeRegistry")
	return null

## 生成升级选项
func generate_upgrade_options() -> void:
	available_upgrades.clear()
	
	if _use_legacy_system:
		_generate_legacy_options()
	else:
		_generate_new_options()

## 生成新版升级选项
func _generate_new_options() -> void:
	var registry = _get_upgrade_registry()
	if registry == null:
		_use_legacy_system = true
		_generate_legacy_options()
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
	
	# 如果没有可用升级，尝试使用旧系统
	if available_upgrades.size() == 0:
		print("UpgradeSelection: 没有可用的新版升级，尝试使用旧版系统")
		_use_legacy_system = true
		_generate_legacy_options()

## 生成旧版升级选项（兼容）
func _generate_legacy_options() -> void:
	var upgrade_ids = LEGACY_UPGRADES.keys()
	upgrade_ids.shuffle()
	
	# 选择3个升级
	for i in range(min(upgrade_count, upgrade_ids.size())):
		var upgrade_id = upgrade_ids[i]
		var upgrade_data = LEGACY_UPGRADES[upgrade_id].duplicate()
		upgrade_data["id"] = upgrade_id
		
		# 检查当前等级
		if RunManager:
			var current_level = RunManager.get_upgrade_level(upgrade_id)
			upgrade_data["current_level"] = current_level
			
			# 如果已达到最大等级，跳过
			if current_level >= upgrade_data["max_level"]:
				continue
		
		available_upgrades.append(upgrade_data)

## 显示升级选项
func display_upgrades() -> void:
	if not upgrade_container:
		return
	
	# 清空现有按钮
	for child in upgrade_container.get_children():
		child.queue_free()
	
	# 为每个升级创建按钮
	for upgrade in available_upgrades:
		if _use_legacy_system:
			_create_legacy_upgrade_button(upgrade)
		else:
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
	
	# 稀有度标签
	var rarity_label = Label.new()
	rarity_label.text = "[%s]" % upgrade.get_rarity_name()
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

## 创建旧版升级按钮（兼容）
func _create_legacy_upgrade_button(upgrade: Dictionary) -> void:
	var button = Button.new()
	button.custom_minimum_size = Vector2(400, 100)
	button.pressed.connect(_on_upgrade_selected.bind(upgrade["id"]))
	
	var vbox = VBoxContainer.new()
	button.add_child(vbox)
	
	var name_label = Label.new()
	name_label.text = upgrade["name"]
	if upgrade.has("current_level"):
		name_label.text += " (Lv.%d)" % upgrade["current_level"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(name_label)
	
	var desc_label = Label.new()
	desc_label.text = upgrade["description"]
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(desc_label)
	
	upgrade_container.add_child(button)

## 升级被选中
func _on_upgrade_selected(upgrade_id: String) -> void:
	if RunManager:
		RunManager.add_upgrade(upgrade_id, 1)
	
	emit_signal("upgrade_selected", upgrade_id)
	print("选择升级：", upgrade_id)

## 刷新升级选项（可在运行时调用）
func refresh_options() -> void:
	generate_upgrade_options()
	display_upgrades()
