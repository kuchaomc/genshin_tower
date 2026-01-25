extends Control

## 主菜单右侧抽屉内嵌的角色选择面板（不切场景）

signal closed

@onready var character_container: HFlowContainer = %CharacterContainer
@onready var confirm_button: Button = %ConfirmButton
@onready var back_button: Button = %BackButton
@onready var description_label: Label = %DescriptionLabel

var selected_character: CharacterData = null
var character_buttons: Array[Button] = []

var _button_group: ButtonGroup = ButtonGroup.new()
var _portrait_fade_material: ShaderMaterial = null

# 返回/确认按钮悬停Tween缓存（用于打断旧Tween，避免抖动）
var _button_hover_tweens: Dictionary = {}
var _button_base_scales: Dictionary = {}
var _button_base_modulates: Dictionary = {}


func _ready() -> void:
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
		confirm_button.disabled = true
		confirm_button.focus_mode = Control.FOCUS_ALL
		_setup_action_button_style(confirm_button, true)
		_bind_hover_effect(confirm_button)

	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		back_button.focus_mode = Control.FOCUS_ALL
		_setup_action_button_style(back_button, false)
		_bind_hover_effect(back_button)

	# 等待数据加载完成后再刷新角色列表
	if DataManager:
		if not DataManager.is_connected("data_loaded", _on_data_loaded):
			DataManager.data_loaded.connect(_on_data_loaded)
		_on_data_loaded()
	else:
		push_warning("CharacterSelectPanel: DataManager未找到")


func show_panel() -> void:
	visible = true
	# 打开时默认把焦点给返回按钮，避免键盘/手柄导航丢失
	if back_button:
		back_button.grab_focus()


## 绑定按钮的悬停/焦点特效
func _bind_hover_effect(button: Button) -> void:
	if not is_instance_valid(button):
		return
	_ensure_button_pivot_center(button)
	if not button.resized.is_connected(_on_button_resized.bind(button)):
		button.resized.connect(_on_button_resized.bind(button))
	if not _button_base_scales.has(button):
		_button_base_scales[button] = button.scale
	if not _button_base_modulates.has(button):
		_button_base_modulates[button] = button.modulate

	if not button.mouse_entered.is_connected(_on_button_mouse_entered.bind(button)):
		button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
	if not button.mouse_exited.is_connected(_on_button_mouse_exited.bind(button)):
		button.mouse_exited.connect(_on_button_mouse_exited.bind(button))
	if not button.focus_entered.is_connected(_on_button_mouse_entered.bind(button)):
		button.focus_entered.connect(_on_button_mouse_entered.bind(button))
	if not button.focus_exited.is_connected(_on_button_mouse_exited.bind(button)):
		button.focus_exited.connect(_on_button_mouse_exited.bind(button))


func _on_button_mouse_entered(button: Button) -> void:
	_play_button_hover(button, true)


func _on_button_mouse_exited(button: Button) -> void:
	_play_button_hover(button, false)


func _play_button_hover(button: Button, hovered: bool) -> void:
	if not is_instance_valid(button):
		return
	# 禁用时不做悬停动画，避免误导
	if button.disabled:
		return
	_ensure_button_pivot_center(button)

	var old_tween: Tween = _button_hover_tweens.get(button)
	if old_tween and old_tween.is_running():
		old_tween.kill()

	var tween := create_tween()
	_button_hover_tweens[button] = tween
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	var base_scale: Vector2 = _button_base_scales.get(button, Vector2.ONE)
	var base_modulate: Color = _button_base_modulates.get(button, Color(1, 1, 1, 1))

	var target_scale := base_scale * (Vector2(1.03, 1.03) if hovered else Vector2.ONE)
	var target_modulate := (Color(base_modulate.r * 1.12, base_modulate.g * 1.12, base_modulate.b * 1.12, base_modulate.a) if hovered else base_modulate)

	tween.parallel().tween_property(button, "scale", target_scale, 0.12)
	tween.parallel().tween_property(button, "modulate", target_modulate, 0.12)


func _on_button_resized(button: Button) -> void:
	_ensure_button_pivot_center(button)


func _ensure_button_pivot_center(button: Control) -> void:
	if not is_instance_valid(button):
		return
	# pivot_offset 默认是左上角，这里改为中心点，让缩放从中间开始
	button.pivot_offset = button.size * 0.5


func _setup_action_button_style(button: Button, is_confirm: bool) -> void:
	if not is_instance_valid(button):
		return
	# flat=true 会禁用背景绘制，这里强制关闭
	button.flat = false

	var base_bg := Color(0.10, 0.10, 0.10, 0.55)
	var hover_bg := Color(0.12, 0.12, 0.12, 0.70)
	var pressed_bg := Color(0.14, 0.14, 0.14, 0.80)
	var border := Color(1, 1, 1, 0.18)
	if is_confirm:
		border = Color(0.20, 0.60, 1.00, 0.75)
		base_bg = Color(0.08, 0.18, 0.28, 0.60)
		hover_bg = Color(0.10, 0.22, 0.34, 0.75)
		pressed_bg = Color(0.10, 0.26, 0.40, 0.85)

	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = base_bg
	normal_sb.border_width_left = 2
	normal_sb.border_width_top = 2
	normal_sb.border_width_right = 2
	normal_sb.border_width_bottom = 2
	normal_sb.border_color = border
	normal_sb.corner_radius_top_left = 10
	normal_sb.corner_radius_top_right = 10
	normal_sb.corner_radius_bottom_right = 10
	normal_sb.corner_radius_bottom_left = 10

	var hover_sb := normal_sb.duplicate(true) as StyleBoxFlat
	hover_sb.bg_color = hover_bg

	var pressed_sb := normal_sb.duplicate(true) as StyleBoxFlat
	pressed_sb.bg_color = pressed_bg
	pressed_sb.border_color = Color(border.r, border.g, border.b, minf(1.0, border.a * 1.15))

	button.add_theme_stylebox_override("normal", normal_sb)
	button.add_theme_stylebox_override("hover", hover_sb)
	button.add_theme_stylebox_override("pressed", pressed_sb)
	button.add_theme_stylebox_override("hover_pressed", pressed_sb)


func _on_data_loaded() -> void:
	load_characters()


## 加载角色列表
func load_characters() -> void:
	if not is_instance_valid(character_container):
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
	var characters: Array = []
	if DataManager:
		characters = DataManager.get_all_characters()
	if characters.is_empty():
		push_warning("CharacterSelectPanel: 没有找到角色数据")
		_create_default_character()
		if DataManager:
			characters = DataManager.get_all_characters()

	for character in characters:
		_create_character_button(character)


func _create_default_character() -> void:
	if not DataManager:
		return
	var default_char := CharacterData.new()
	default_char.id = "kamisato_ayaka"
	default_char.display_name = "神里绫华"
	default_char.description = "使用剑进行近战攻击的角色"

	var default_stats := CharacterStats.new()
	default_stats.max_health = 100.0
	default_stats.move_speed = 100.0
	default_stats.attack = 25.0
	default_char.stats = default_stats

	default_char.scene_path = "res://scenes/characters/kamisato_ayaka.tscn"
	DataManager.characters[default_char.id] = default_char


func _create_character_button(character: CharacterData) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(260, 460)
	button.text = ""
	button.toggle_mode = true
	button.button_group = _button_group
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_character_selected.bind(character, button))

	# 卡片样式
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

	var portrait_texture: Texture2D = null
	var portrait_path := _get_character_portrait_path(character.id)
	if not portrait_path.is_empty():
		portrait_texture = (DataManager.get_texture(portrait_path) as Texture2D) if (DataManager and DataManager.has_method("get_texture")) else (load(portrait_path) as Texture2D)
	if not portrait_texture and character.icon:
		portrait_texture = character.icon

	if portrait_texture:
		var portrait_rect := TextureRect.new()
		portrait_rect.texture = portrait_texture
		portrait_rect.material = _get_portrait_fade_material()
		portrait_rect.custom_minimum_size = Vector2(220, 300)
		portrait_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vbox.add_child(portrait_rect)

	var name_label := Label.new()
	name_label.text = character.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	name_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(name_label)

	var stats_label := Label.new()
	var char_stats := character.get_stats()
	stats_label.text = "HP: %d\n速度: %d\n伤害: %d" % [char_stats.max_health, char_stats.move_speed, char_stats.attack]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	stats_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(stats_label)

	character_container.add_child(button)
	character_buttons.append(button)


func _get_character_portrait_path(character_id: String) -> String:
	match character_id:
		"kamisato_ayaka":
			return "res://textures/characters/kamisato_ayaka/portraits/ayaka角色立绘.png"
		"nahida":
			return "res://textures/characters/nahida/portraits/nahida角色立绘.png"
		_:
			return ""


func _on_character_selected(character: CharacterData, pressed_button: Button) -> void:
	selected_character = character
	if pressed_button:
		pressed_button.button_pressed = true

	# 播放选中角色语音
	if BGMManager and character and not character.id.is_empty():
		BGMManager.play_character_voice(character.id, "选中角色", 0.0, 0.0, true)

	if description_label:
		description_label.text = character.get_description()

	if confirm_button:
		confirm_button.disabled = false


func _on_confirm_pressed() -> void:
	if not selected_character:
		push_warning("CharacterSelectPanel: 未选择角色")
		return

	if not RunManager:
		push_error("CharacterSelectPanel: RunManager未找到")
		return

	if not GameManager:
		push_error("CharacterSelectPanel: GameManager未找到")
		return

	RunManager.start_new_run(selected_character)
	# 进入武器选择界面
	if GameManager.has_method("go_to_weapon_select"):
		GameManager.go_to_weapon_select()
	else:
		GameManager.change_scene_to("res://scenes/ui/weapon_select.tscn")


func _on_back_pressed() -> void:
	closed.emit()


func _get_portrait_fade_material() -> ShaderMaterial:
	if _portrait_fade_material:
		return _portrait_fade_material
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\n\nuniform float feather = 0.12;\n\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\t\n\tfloat dx = min(UV.x, 1.0 - UV.x);\n\tfloat dy = min(UV.y, 1.0 - UV.y);\n\tfloat d = min(dx, dy);\n\tfloat a = smoothstep(0.0, feather, d);\n\tCOLOR = vec4(c.rgb, c.a * a);\n}\n"
	_portrait_fade_material = ShaderMaterial.new()
	_portrait_fade_material.shader = shader
	return _portrait_fade_material
