extends Node2D

## 角色选择界面脚本

@onready var character_container: HBoxContainer = $CanvasLayer/VBoxContainer/CharacterContainer
@onready var confirm_button: Button = $CanvasLayer/VBoxContainer/ConfirmButton
@onready var back_button: Button = $CanvasLayer/VBoxContainer/BackButton
@onready var description_label: Label = $CanvasLayer/VBoxContainer/DescriptionLabel

var selected_character: CharacterData = null
var character_buttons: Array[Button] = []

func _ready() -> void:
	# 等待数据加载完成
	if DataManager:
		if not DataManager.is_connected("data_loaded", _on_data_loaded):
			DataManager.data_loaded.connect(_on_data_loaded)
		_on_data_loaded()
	else:
		print("错误：DataManager未找到")
	
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
		confirm_button.disabled = true
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _on_data_loaded() -> void:
	load_characters()

## 加载角色列表
func load_characters() -> void:
	if not character_container:
		return
	
	# 清空现有按钮
	for button in character_buttons:
		if is_instance_valid(button):
			button.queue_free()
	character_buttons.clear()
	
	# 获取所有角色
	var characters = DataManager.get_all_characters()
	
	if characters.is_empty():
		print("警告：没有找到角色数据")
		# 创建默认角色
		create_default_character()
		characters = DataManager.get_all_characters()
	
	# 为每个角色创建按钮
	for character in characters:
		create_character_button(character)

## 创建默认角色（如果没有角色数据）
func create_default_character() -> void:
	var default_char = CharacterData.new()
	default_char.id = "kamisato_ayaka"
	default_char.display_name = "神里绫华"
	default_char.description = "使用剑进行近战攻击的角色（Kamisato Ayaka）"
	default_char.max_health = 100.0
	default_char.move_speed = 100.0
	default_char.base_damage = 25.0
	default_char.scene_path = "res://scenes/玩家.tscn"
	
	# 保存到DataManager（临时）
	DataManager.characters[default_char.id] = default_char

## 创建角色按钮
func create_character_button(character: CharacterData) -> void:
	var button = Button.new()
	button.custom_minimum_size = Vector2(150, 200)
	button.text = character.display_name
	button.pressed.connect(_on_character_selected.bind(character))
	
	# 创建垂直布局
	var vbox = VBoxContainer.new()
	button.add_child(vbox)
	
	# 添加图标（如果有）
	if character.icon:
		var icon_rect = TextureRect.new()
		icon_rect.texture = character.icon
		icon_rect.custom_minimum_size = Vector2(100, 100)
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		vbox.add_child(icon_rect)
	
	# 添加名称标签
	var name_label = Label.new()
	name_label.text = character.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# 添加属性标签
	var stats_label = Label.new()
	stats_label.text = "HP: %d\n速度: %d\n伤害: %d" % [character.max_health, character.move_speed, character.base_damage]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_label)
	
	character_container.add_child(button)
	character_buttons.append(button)

## 角色被选中
func _on_character_selected(character: CharacterData) -> void:
	selected_character = character
	
	# 更新描述
	if description_label:
		description_label.text = character.get_description()
	
	# 启用确认按钮
	if confirm_button:
		confirm_button.disabled = false
	
	# 更新按钮样式
	for button in character_buttons:
		if button:
			button.button_pressed = false
	
	# 找到对应的按钮并高亮
	for i in range(character_buttons.size()):
		var button = character_buttons[i]
		if button and button.pressed:
			button.modulate = Color(1.2, 1.2, 1.0, 1.0)
		else:
			if button:
				button.modulate = Color.WHITE

## 确认选择
func _on_confirm_pressed() -> void:
	if not selected_character:
		print("错误：未选择角色")
		return
	
	print("选择角色：", selected_character.display_name)
	
	# 检查必要的单例
	if not RunManager:
		print("错误：RunManager未找到")
		return
	
	if not GameManager:
		print("错误：GameManager未找到")
		return
	
	# 开始新的一局
	RunManager.start_new_run(selected_character)
	
	# 切换到地图界面
	GameManager.go_to_map_view()

## 返回主菜单
func _on_back_pressed() -> void:
	if GameManager:
		GameManager.go_to_main_menu()
