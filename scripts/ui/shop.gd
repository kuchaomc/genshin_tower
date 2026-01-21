extends Node2D

## 商店界面脚本
## 功能：
## - 随机提供 3 个升级可购买
## - 提供 1 个圣遗物自选包（打开后进入圣遗物选择界面）
## - 使用 RunManager 的摩拉（gold）作为货币
## - 升级价格随稀有度变化，自选包价格 = 当前层数 * 50

signal upgrade_purchased(upgrade_id: String, price: int)
signal artifact_pack_purchased(price: int)

@onready var title_label: Label = $CanvasLayer/VBoxContainer/TitleLabel
@onready var gold_label: Label = $CanvasLayer/VBoxContainer/GoldLabel
@onready var upgrade_container: VBoxContainer = $CanvasLayer/VBoxContainer/UpgradeContainer
@onready var artifact_pack_button: Button = $CanvasLayer/VBoxContainer/ArtifactPackButton
@onready var back_button: Button = $CanvasLayer/VBoxContainer/BackButton

## 当前可购买的升级列表（UpgradeData）
var available_upgrades: Array[UpgradeData] = []

## 已购买的升级ID
var purchased_upgrades: Dictionary = {}

## 圣遗物自选包是否已购买
var artifact_pack_already_purchased: bool = false

## 商店中升级数量
@export var upgrade_count: int = 3

func _ready() -> void:
	if title_label:
		title_label.text = "商店"
	
	_update_gold_label()
	_generate_upgrade_options()
	_display_upgrades()
	
	if artifact_pack_button:
		_update_artifact_pack_button_text()
		if not artifact_pack_button.pressed.is_connected(_on_artifact_pack_pressed):
			artifact_pack_button.pressed.connect(_on_artifact_pack_pressed)
	
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

## 生成升级选项（从 UpgradeRegistry 中随机抽取）
func _generate_upgrade_options() -> void:
	available_upgrades.clear()
	
	var registry := UpgradeRegistry
	
	var character_id := ""
	var current_floor := RunManager.current_floor
	var current_upgrades: Dictionary = RunManager.upgrades
	
	if RunManager.current_character:
		character_id = RunManager.current_character.id
	
	var picked: Array = registry.pick_random_upgrades(
		character_id,
		current_upgrades,
		current_floor,
		upgrade_count
	)
	
	for u in picked:
		if u is UpgradeData:
			available_upgrades.append(u)
	
	if available_upgrades.is_empty():
		push_warning("Shop: 没有可用的升级选项")


## 显示升级列表
func _display_upgrades() -> void:
	if not upgrade_container:
		return
	
	# 清空容器
	for child in upgrade_container.get_children():
		child.queue_free()
	
	for upgrade in available_upgrades:
		_create_upgrade_button(upgrade)


## 根据稀有度计算升级价格
## 可以根据实际体验再微调数值
func _get_upgrade_price(upgrade: UpgradeData) -> int:
	match upgrade.rarity:
		UpgradeData.Rarity.COMMON:
			return 50
		UpgradeData.Rarity.UNCOMMON:
			return 100
		UpgradeData.Rarity.RARE:
			return 150
		UpgradeData.Rarity.EPIC:
			return 200
		UpgradeData.Rarity.LEGENDARY:
			return 300
		_:
			return 100


## 创建单个升级购买按钮
func _create_upgrade_button(upgrade: UpgradeData) -> void:
	var price := _get_upgrade_price(upgrade)
	var button := Button.new()
	button.custom_minimum_size = Vector2(450, 130)
	
	# 点击回调
	button.pressed.connect(_on_upgrade_buy_pressed.bind(upgrade, price, button))
	
	# 内容布局，参考升级选择界面
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	button.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	
	# 第一行：稀有度 + 名称 + 等级
	var title_hbox := HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(title_hbox)
	
	var rarity_label := Label.new()
	rarity_label.text = upgrade.get_rarity_stars()
	rarity_label.add_theme_color_override("font_color", upgrade.get_rarity_color())
	title_hbox.add_child(rarity_label)
	
	var name_label := Label.new()
	var current_level := RunManager.get_upgrade_level(upgrade.id)
	
	if current_level > 0:
		name_label.text = "%s (Lv.%d → %d)" % [upgrade.display_name, current_level, current_level + 1]
	else:
		name_label.text = upgrade.display_name
	name_label.add_theme_color_override("font_color", upgrade.get_rarity_color())
	title_hbox.add_child(name_label)
	
	if upgrade.max_level > 0:
		var max_level_label := Label.new()
		max_level_label.text = "/ %d" % upgrade.max_level
		max_level_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		title_hbox.add_child(max_level_label)
	
	# 描述
	var desc_label := Label.new()
	desc_label.text = upgrade.get_formatted_description(current_level)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.x = 400
	vbox.add_child(desc_label)
	
	# 标签
	if upgrade.tags.size() > 0:
		var tags_label := Label.new()
		tags_label.text = "标签: " + ", ".join(upgrade.tags)
		tags_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		tags_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(tags_label)
	
	# 价格行
	var price_label := Label.new()
	price_label.text = "价格：%d 摩拉" % price
	price_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	vbox.add_child(price_label)
	
	# 根据当前金币状态设置是否可点击
	var can_afford := _can_afford(price)
	if not can_afford:
		button.disabled = true
		button.modulate = Color(0.6, 0.6, 0.6, 1.0)
	
	upgrade_container.add_child(button)


## 处理升级购买
func _on_upgrade_buy_pressed(upgrade: UpgradeData, price: int, button: Button) -> void:
	if purchased_upgrades.has(upgrade.id):
		return
	
	# 尝试扣除摩拉
	if not RunManager.spend_gold(price):
		print("摩拉不足，无法购买升级：", upgrade.display_name)
		return
	
	# 记录购买并应用升级
	purchased_upgrades[upgrade.id] = true
	RunManager.add_upgrade(upgrade.id, 1)
	_update_gold_label()
	
	# 按钮灰掉，避免重复购买
	if button:
		button.disabled = true
		button.modulate = Color(0.5, 0.5, 0.5, 1.0)
	
	emit_signal("upgrade_purchased", upgrade.id, price)
	print("购买升级：", upgrade.display_name, " 花费：", price, "摩拉")


## 更新圣遗物自选包按钮文本
func _update_artifact_pack_button_text() -> void:
	if not artifact_pack_button:
		return
	
	# 最少按第1层计价，避免 0 楼层出现 0 价格
	var floor_num: int = maxi(1, RunManager.current_floor)
	
	var price: int = floor_num * 50
	if artifact_pack_already_purchased:
		artifact_pack_button.text = "圣遗物自选包（已购买）"
		artifact_pack_button.disabled = true
	else:
		artifact_pack_button.text = "圣遗物自选包 - 价格：%d 摩拉（当前层数 %d）" % [price, floor_num]
		artifact_pack_button.disabled = not _can_afford(price)


## 购买圣遗物自选包
func _on_artifact_pack_pressed() -> void:
	if artifact_pack_already_purchased:
		return
	
	var floor_num: int = maxi(1, RunManager.current_floor)
	var price: int = floor_num * 50
	
	if not RunManager.spend_gold(price):
		print("摩拉不足，无法购买圣遗物自选包")
		return
	
	artifact_pack_already_purchased = true
	_update_gold_label()
	_update_artifact_pack_button_text()
	emit_signal("artifact_pack_purchased", price)
	print("购买圣遗物自选包，花费：", price, "摩拉")
	
	# 打开圣遗物选择界面（选择完会自动返回地图）
	if GameManager:
		GameManager.show_artifact_selection()


## 返回地图
func _on_back_pressed() -> void:
	GameManager.go_to_map_view()


## 更新摩拉显示
func _update_gold_label() -> void:
	if not gold_label:
		return
	
	gold_label.text = "当前摩拉：%d" % RunManager.gold


## 判断是否有足够摩拉
func _can_afford(price: int) -> bool:
	return RunManager.gold >= price
