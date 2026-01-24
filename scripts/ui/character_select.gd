extends Node2D

## 角色选择界面脚本

@onready var background_rect: TextureRect = %Background
@onready var character_container: HFlowContainer = %CharacterContainer
@onready var confirm_button: Button = %ConfirmButton
@onready var back_button: Button = %BackButton
@onready var description_label: Label = %DescriptionLabel

var selected_character: CharacterData = null
var character_buttons: Array[Button] = []

# 主界面背景图目录（与主界面保持一致）
var MAIN_MENU_BACKGROUND_DIR: String = "res://textures/background"
var _main_menu_bg_exts: PackedStringArray = PackedStringArray(["png", "jpg", "jpeg", "webp"])
var _main_menu_bg_fallback_paths: PackedStringArray = PackedStringArray([
	"res://textures/background/00131-3390311460.png",
	"res://textures/background/00161-1240093822.png",
	"res://textures/background/00183-1277078224.png",
])
var _main_menu_bg_fallback_preloads: Array[Texture2D] = [
	preload("res://textures/background/00131-3390311460.png"),
	preload("res://textures/background/00161-1240093822.png"),
	preload("res://textures/background/00183-1277078224.png"),
]

# 背景图候选缓存（目录内容运行期不会变化，缓存可减少IO/遍历）
var _background_candidates_cache: PackedStringArray = []

# 左侧菜单与角色卡片交互Tween缓存
var _hover_tweens: Dictionary = {}
var _card_hover_tweens: Dictionary = {}

var _button_group: ButtonGroup = ButtonGroup.new()

# 主菜单背景历史记录（沿用主界面逻辑：角色选择不做随机，直接使用上次背景）
const _BG_HISTORY_FILE_PATH: String = "user://main_menu_bg.cfg"
const _BG_HISTORY_SECTION: String = "main_menu"
const _BG_HISTORY_KEY_LAST_BG: String = "last_background"

var _portrait_fade_material: ShaderMaterial = null

func _ready() -> void:
	_apply_background_from_main_menu_history()
	_setup_menu_hover_effects()

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
		confirm_button.focus_mode = Control.FOCUS_ALL
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		back_button.focus_mode = Control.FOCUS_ALL

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
	selected_character = null
	if confirm_button:
		confirm_button.disabled = true
	
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
	
	# 创建默认属性
	var default_stats = CharacterStats.new()
	default_stats.max_health = 100.0
	default_stats.move_speed = 100.0
	default_stats.attack = 25.0
	default_char.stats = default_stats
	
	default_char.scene_path = "res://scenes/characters/kamisato_ayaka.tscn"
	
	# 保存到DataManager（临时）
	DataManager.characters[default_char.id] = default_char

## 创建角色按钮
func create_character_button(character: CharacterData) -> void:
	var button = Button.new()
	button.custom_minimum_size = Vector2(260, 460)
	button.text = ""  # 移除按钮文本，因为我们在内部显示
	button.toggle_mode = true
	button.button_group = _button_group
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_character_selected.bind(character, button))

	# 卡片样式：深色半透明底+圆角+描边；hover/选中时更亮并带蓝色描边
	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	normal_sb.border_width_left = 2
	normal_sb.border_width_top = 2
	normal_sb.border_width_right = 2
	normal_sb.border_width_bottom = 2
	normal_sb.border_color = Color(0.0, 0.0, 0.0, 0.55)
	normal_sb.corner_radius_top_left = 14
	normal_sb.corner_radius_top_right = 14
	normal_sb.corner_radius_bottom_right = 14
	normal_sb.corner_radius_bottom_left = 14

	var hover_sb := normal_sb.duplicate(true) as StyleBoxFlat
	hover_sb.bg_color = Color(0.1, 0.1, 0.1, 0.45)
	hover_sb.border_color = Color(0.2, 0.6, 1.0, 0.55)

	var pressed_sb := normal_sb.duplicate(true) as StyleBoxFlat
	pressed_sb.bg_color = Color(0.12, 0.12, 0.12, 0.55)
	pressed_sb.border_color = Color(0.2, 0.6, 1.0, 0.95)

	button.add_theme_stylebox_override("normal", normal_sb)
	button.add_theme_stylebox_override("hover", hover_sb)
	button.add_theme_stylebox_override("pressed", pressed_sb)
	button.add_theme_stylebox_override("hover_pressed", pressed_sb)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	button.mouse_entered.connect(_on_card_mouse_entered.bind(button))
	button.mouse_exited.connect(_on_card_mouse_exited.bind(button))
	button.focus_entered.connect(_on_card_focus_entered.bind(button))
	button.focus_exited.connect(_on_card_focus_exited.bind(button))
	
	# 创建垂直布局
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	button.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	# 优先使用角色立绘，如果没有则使用图标
	var portrait_texture: Texture2D = null
	var portrait_path = _get_character_portrait_path(character.id)
	if portrait_path:
		if DataManager:
			portrait_texture = DataManager.get_texture(portrait_path)
		else:
			portrait_texture = load(portrait_path) as Texture2D
	
	# 如果立绘加载失败，尝试使用图标
	if not portrait_texture and character.icon:
		portrait_texture = character.icon
	
	# 添加立绘/图标
	if portrait_texture:
		var portrait_rect = TextureRect.new()
		portrait_rect.texture = portrait_texture
		portrait_rect.material = _get_portrait_fade_material()
		portrait_rect.custom_minimum_size = Vector2(220, 300)
		portrait_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vbox.add_child(portrait_rect)
	
	# 添加名称标签
	var name_label = Label.new()
	name_label.text = character.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	name_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(name_label)
	
	# 添加属性标签（显示在立绘下方）
	var stats_label = Label.new()
	var char_stats = character.get_stats()
	stats_label.text = "HP: %d\n速度: %d\n伤害: %d" % [char_stats.max_health, char_stats.move_speed, char_stats.attack]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	stats_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(stats_label)
	
	character_container.add_child(button)
	character_buttons.append(button)

## 获取角色立绘路径
func _get_character_portrait_path(character_id: String) -> String:
	# 根据角色ID构建立绘路径
	match character_id:
		"kamisato_ayaka":
			return "res://textures/characters/kamisato_ayaka/portraits/ayaka角色立绘.png"
		_:
			return ""

## 角色被选中
func _on_character_selected(character: CharacterData, pressed_button: Button) -> void:
	selected_character = character
	if pressed_button:
		pressed_button.button_pressed = true
	
	# 播放选中角色语音
	if BGMManager and character and not character.id.is_empty():
		BGMManager.play_character_voice(character.id, "选中角色", 0.0, 0.2, true)
	
	# 更新描述
	if description_label:
		description_label.text = character.get_description()
	
	# 启用确认按钮
	if confirm_button:
		confirm_button.disabled = false
	
	_update_card_visuals()

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


func _update_card_visuals() -> void:
	for button in character_buttons:
		if not is_instance_valid(button):
			continue
		if button.button_pressed:
			button.modulate = Color(1.08, 1.08, 1.08, 1.0)
		else:
			button.modulate = Color(1, 1, 1, 1)


func _on_card_mouse_entered(button: Button) -> void:
	_play_card_hover(button, true)


func _on_card_mouse_exited(button: Button) -> void:
	_play_card_hover(button, false)


func _on_card_focus_entered(button: Button) -> void:
	_play_card_hover(button, true)


func _on_card_focus_exited(button: Button) -> void:
	_play_card_hover(button, false)


func _play_card_hover(button: Button, hovered: bool) -> void:
	if not is_instance_valid(button):
		return
	var old_tween: Tween = _card_hover_tweens.get(button)
	if old_tween and old_tween.is_running():
		old_tween.kill()
	var tween := create_tween()
	_card_hover_tweens[button] = tween
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	var target_scale := Vector2(1.02, 1.02) if hovered else Vector2.ONE
	tween.tween_property(button, "scale", target_scale, 0.12)


func setup_menu_hover_effects() -> void:
	_setup_menu_hover_effects()


func _setup_menu_hover_effects() -> void:
	if confirm_button:
		_bind_hover_for_button(confirm_button)
	if back_button:
		_bind_hover_for_button(back_button)


func _bind_hover_for_button(button: Button) -> void:
	var row := button.get_parent() as Node
	if row == null:
		return
	var indicator_space := row.get_node_or_null("IndicatorSpace") as Control
	if indicator_space == null:
		return
	var indicator := indicator_space.get_node_or_null("CenterContainer/Indicator") as ColorRect
	if indicator == null:
		return
	indicator.visible = false
	indicator.modulate = Color(1, 1, 1, 0)
	indicator_space.custom_minimum_size = Vector2(0, 0)
	if not button.mouse_entered.is_connected(_on_menu_button_mouse_entered.bind(row)):
		button.mouse_entered.connect(_on_menu_button_mouse_entered.bind(row))
	if not button.mouse_exited.is_connected(_on_menu_button_mouse_exited.bind(row)):
		button.mouse_exited.connect(_on_menu_button_mouse_exited.bind(row))
	if not button.focus_entered.is_connected(_on_menu_button_mouse_entered.bind(row)):
		button.focus_entered.connect(_on_menu_button_mouse_entered.bind(row))
	if not button.focus_exited.is_connected(_on_menu_button_mouse_exited.bind(row)):
		button.focus_exited.connect(_on_menu_button_mouse_exited.bind(row))


func _on_menu_button_mouse_entered(row: Node) -> void:
	_play_hover_animation(row, true)


func _on_menu_button_mouse_exited(row: Node) -> void:
	_play_hover_animation(row, false)


func _play_hover_animation(row: Node, hovered: bool) -> void:
	var indicator_space := row.get_node_or_null("IndicatorSpace") as Control
	if indicator_space == null:
		return
	var indicator := indicator_space.get_node_or_null("CenterContainer/Indicator") as ColorRect
	if indicator == null:
		return
	var old_tween: Tween = _hover_tweens.get(row)
	if old_tween and old_tween.is_running():
		old_tween.kill()
	var tween := create_tween()
	_hover_tweens[row] = tween
	if hovered:
		indicator.visible = true
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(indicator_space, "custom_minimum_size", Vector2(18, 0), 0.12)
		tween.parallel().tween_property(indicator, "modulate", Color(1, 1, 1, 1), 0.12)
	else:
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(indicator_space, "custom_minimum_size", Vector2(0, 0), 0.12)
		tween.parallel().tween_property(indicator, "modulate", Color(1, 1, 1, 0), 0.12)
		tween.finished.connect(func() -> void:
			if is_instance_valid(indicator):
				indicator.visible = false
		)


func _apply_background_from_main_menu_history() -> void:
	if not is_instance_valid(background_rect):
		return
	var last_bg_path: String = _load_last_background_path()
	var tex := _try_load_texture(last_bg_path)
	if tex:
		background_rect.texture = tex
		return

	# 读取失败/资源不存在时：使用固定兜底（不随机）
	if _main_menu_bg_fallback_preloads.size() > 0:
		background_rect.texture = _main_menu_bg_fallback_preloads[0]
		return

	# 兜底资源为空时，再尝试从目录取第一个（保持确定性）
	var candidates := _get_background_candidates_cached()
	if candidates.is_empty():
		return
	background_rect.texture = _try_load_texture(String(candidates[0]))


func _load_last_background_path() -> String:
	var config := ConfigFile.new()
	var err: Error = config.load(_BG_HISTORY_FILE_PATH)
	if err != OK:
		return ""
	return String(config.get_value(_BG_HISTORY_SECTION, _BG_HISTORY_KEY_LAST_BG, ""))


func _try_load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if DataManager and DataManager.has_method("get_texture"):
		return DataManager.get_texture(path) as Texture2D
	return load(path) as Texture2D


func _get_portrait_fade_material() -> ShaderMaterial:
	if _portrait_fade_material:
		return _portrait_fade_material
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\n\nuniform float feather = 0.12;\n\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\t\n\tfloat dx = min(UV.x, 1.0 - UV.x);\n\tfloat dy = min(UV.y, 1.0 - UV.y);\n\tfloat d = min(dx, dy);\n\tfloat a = smoothstep(0.0, feather, d);\n\tCOLOR = vec4(c.rgb, c.a * a);\n}\n"
	_portrait_fade_material = ShaderMaterial.new()
	_portrait_fade_material.shader = shader
	return _portrait_fade_material


func _get_background_candidates_cached() -> PackedStringArray:
	if not _background_candidates_cache.is_empty():
		return _background_candidates_cache
	_background_candidates_cache = _collect_background_candidates()
	return _background_candidates_cache


func _collect_background_candidates() -> PackedStringArray:
	var result: PackedStringArray = []
	var dir := DirAccess.open(MAIN_MENU_BACKGROUND_DIR)
	if dir == null:
		return _main_menu_bg_fallback_paths
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if dir.current_is_dir():
			continue
		var ext := name.get_extension().to_lower()
		if _main_menu_bg_exts.has(ext):
			result.append(MAIN_MENU_BACKGROUND_DIR.path_join(name))
	dir.list_dir_end()
	if result.is_empty():
		return _main_menu_bg_fallback_paths
	return result
