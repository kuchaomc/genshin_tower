extends Node2D

## 圣遗物选择界面脚本
## 类似升级选择界面，用于让玩家选择获得的圣遗物

signal artifact_selected(artifact: ArtifactData, slot: ArtifactSlot.SlotType)

@onready var artifact_container: VBoxContainer = $CanvasLayer/VBoxContainer/ArtifactContainer
@onready var title_label: Label = $CanvasLayer/VBoxContainer/TitleLabel
@onready var skip_button: Button = $CanvasLayer/VBoxContainer/SkipButton

# 可选的圣遗物列表（ArtifactData 类型）
var available_artifacts: Array[ArtifactData] = []

# 圣遗物选项数量
@export var artifact_count: int = 3

func _ready() -> void:
	if title_label:
		title_label.text = "选择圣遗物"
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)
	generate_artifact_options()
	display_artifacts()

## 生成圣遗物选项
func generate_artifact_options() -> void:
	available_artifacts.clear()
	
	if not RunManager or not RunManager.current_character:
		push_error("ArtifactSelection: RunManager 或当前角色未找到")
		return
	
	# 从角色专属圣遗物套装中随机选择（每次打开宝箱都重新随机）
	# 使用当前时间作为随机种子的一部分，确保每次都是随机的
	randomize()
	
	for i in range(artifact_count):
		var artifact = RunManager.get_random_artifact_from_character_set()
		if artifact:
			available_artifacts.append(artifact)
	
	if available_artifacts.size() == 0:
		push_warning("ArtifactSelection: 没有可用的圣遗物选项")

## 显示圣遗物选项
func display_artifacts() -> void:
	if not artifact_container:
		return
	
	# 清空现有按钮
	for child in artifact_container.get_children():
		child.queue_free()
	
	# 为每个圣遗物创建按钮
	for artifact in available_artifacts:
		_create_artifact_button(artifact)

## 创建圣遗物按钮
func _create_artifact_button(artifact: ArtifactData) -> void:
	var button = Button.new()
	button.custom_minimum_size = Vector2(450, 120)
	
	# 确定圣遗物槽位（从角色套装中查找）
	var slot = _find_artifact_slot(artifact)
	button.pressed.connect(_on_artifact_selected.bind(artifact, slot))
	
	# 创建容器
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	
	var hbox = HBoxContainer.new()
	margin.add_child(hbox)
	
	# 左侧：图标、名称和描述
	var vbox_left = VBoxContainer.new()
	vbox_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox_left)
	
	# 图标和名称的容器
	var icon_name_hbox = HBoxContainer.new()
	vbox_left.add_child(icon_name_hbox)
	
	# 圣遗物图标
	var icon_texture = TextureRect.new()
	icon_texture.custom_minimum_size = Vector2(64, 64)
	icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	var icon_path = _get_artifact_icon_path(artifact.name)
	if icon_path:
		var icon = load(icon_path)
		if icon:
			icon_texture.texture = icon
	icon_name_hbox.add_child(icon_texture)
	
	# 名称
	var name_label = Label.new()
	name_label.text = artifact.name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_name_hbox.add_child(name_label)
	
	# 右侧：属性加成
	var vbox_right = VBoxContainer.new()
	vbox_right.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_child(vbox_right)
	
	# 检查是否已装备该圣遗物
	var is_equipped = false
	var current_level = -1
	if RunManager and RunManager.current_character_node:
		var artifact_manager = RunManager.current_character_node.get_artifact_manager()
		if artifact_manager:
			var equipped_artifact = artifact_manager.get_artifact(slot)
			if equipped_artifact and equipped_artifact.name == artifact.name:
				is_equipped = true
				current_level = artifact_manager.get_artifact_level(slot)
	
	# 属性加成显示
	var bonus_label = Label.new()
	if is_equipped and current_level >= 0:
		# 已装备：显示升级后的效果
		if current_level < 1:
			bonus_label.text = artifact.get_bonus_summary(1)  # 显示升级后的100%效果
			bonus_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))  # 金色表示升级
		else:
			bonus_label.text = artifact.get_bonus_summary(1)  # 已满级
			bonus_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))  # 灰色表示已满级
	else:
		# 未装备：显示0级效果（50%）
		bonus_label.text = artifact.get_bonus_summary(0)
		bonus_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox_right.add_child(bonus_label)
	
	# 等级提示
	var level_hint = Label.new()
	if is_equipped:
		if current_level < 1:
			level_hint.text = "（已装备，选择可升级至100%效果）"
			level_hint.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		else:
			level_hint.text = "（已满级）"
			level_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	else:
		level_hint.text = "（首次获得：50%效果）"
		level_hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
	level_hint.add_theme_font_size_override("font_size", 12)
	vbox_right.add_child(level_hint)
	
	button.add_child(margin)
	artifact_container.add_child(button)

## 查找圣遗物在角色套装中的槽位
func _find_artifact_slot(artifact: ArtifactData) -> ArtifactSlot.SlotType:
	if not RunManager or not RunManager.current_character or not RunManager.current_character.artifact_set:
		return ArtifactSlot.SlotType.FLOWER
	
	var set_data = RunManager.current_character.artifact_set
	for slot in ArtifactSlot.get_all_slots():
		var set_artifact = set_data.get_artifact(slot)
		if set_artifact and set_artifact.name == artifact.name:
			return slot
	
	# 如果找不到，默认返回第一个槽位
	return ArtifactSlot.SlotType.FLOWER

## 圣遗物选择回调
func _on_artifact_selected(artifact: ArtifactData, slot: ArtifactSlot.SlotType) -> void:
	emit_signal("artifact_selected", artifact, slot)
	
	# 添加到库存
	if RunManager:
		RunManager.add_artifact_to_inventory(artifact, slot)
		
		# 自动装备到角色
		RunManager.equip_artifact_to_character(artifact, slot)
	
	# 关闭界面并返回地图
	_return_to_map()

## 跳过按钮回调
func _on_skip_pressed() -> void:
	print("跳过圣遗物选择")
	_return_to_map()

## 获取圣遗物图标路径
func _get_artifact_icon_path(artifact_name: String) -> String:
	# 根据圣遗物名称返回图标路径
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

## 返回地图
func _return_to_map() -> void:
	if GameManager:
		GameManager.go_to_map_view()
	else:
		queue_free()
