extends Node2D

## 升级选择界面脚本

signal upgrade_selected(upgrade_id: String)

@onready var upgrade_container: VBoxContainer = $CanvasLayer/VBoxContainer/UpgradeContainer
@onready var title_label: Label = $CanvasLayer/VBoxContainer/TitleLabel

# 可选的升级列表
var available_upgrades: Array[Dictionary] = []

# 升级数据
const UPGRADES = {
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
	generate_upgrade_options()
	display_upgrades()

## 生成升级选项（随机3个）
func generate_upgrade_options() -> void:
	available_upgrades.clear()
	
	var upgrade_ids = UPGRADES.keys()
	upgrade_ids.shuffle()
	
	# 选择3个升级
	for i in range(min(3, upgrade_ids.size())):
		var upgrade_id = upgrade_ids[i]
		var upgrade_data = UPGRADES[upgrade_id].duplicate()
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
		create_upgrade_button(upgrade)

## 创建升级按钮
func create_upgrade_button(upgrade: Dictionary) -> void:
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
