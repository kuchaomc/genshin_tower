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
	
	# 从角色专属圣遗物套装中随机选择
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
	
	# 左侧：名称和描述
	var vbox_left = VBoxContainer.new()
	vbox_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox_left)
	
	# 名称
	var name_label = Label.new()
	name_label.text = artifact.name
	name_label.add_theme_font_size_override("font_size", 20)
	vbox_left.add_child(name_label)
	
	# 描述
	var desc_label = Label.new()
	desc_label.text = artifact.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox_left.add_child(desc_label)
	
	# 右侧：属性加成
	var vbox_right = VBoxContainer.new()
	vbox_right.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_child(vbox_right)
	
	# 属性加成显示
	var bonus_label = Label.new()
	bonus_label.text = artifact.get_bonus_summary()
	bonus_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox_right.add_child(bonus_label)
	
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

## 返回地图
func _return_to_map() -> void:
	if GameManager:
		GameManager.go_to_map_view()
	else:
		queue_free()
