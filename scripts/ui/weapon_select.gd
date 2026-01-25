extends Control
class_name WeaponSelect

## 武器选择界面
## 流程：选择角色后进入此界面 -> 选择武器 -> 进入地图

var _root: Control
var _back_button: Button
var _confirm_button: Button
var _title: Label

var _weapon_list_scroll: ScrollContainer
var _weapon_list_vbox: VBoxContainer

var _preview_title: Label
var _preview_icon: TextureRect
var _preview_desc: Label

var _selected_weapon_id: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_refresh_weapon_list()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.07, 0.09, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 28
	outer.offset_top = 24
	outer.offset_right = -28
	outer.offset_bottom = -24
	outer.add_theme_constant_override("separation", 16)
	_root.add_child(outer)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	outer.add_child(top_bar)

	_back_button = Button.new()
	_back_button.text = "返回"
	_back_button.custom_minimum_size = Vector2(160, 52)
	_back_button.add_theme_font_size_override("font_size", 22)
	_back_button.pressed.connect(_on_back_pressed)
	top_bar.add_child(_back_button)

	_title = Label.new()
	_title.text = "选择武器"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 40)
	top_bar.add_child(_title)

	_confirm_button = Button.new()
	_confirm_button.text = "确认"
	_confirm_button.custom_minimum_size = Vector2(160, 52)
	_confirm_button.add_theme_font_size_override("font_size", 22)
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_on_confirm_pressed)
	top_bar.add_child(_confirm_button)

	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	outer.add_child(body)

	_weapon_list_scroll = ScrollContainer.new()
	_weapon_list_scroll.custom_minimum_size = Vector2(420, 0)
	_weapon_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_weapon_list_scroll)

	_weapon_list_vbox = VBoxContainer.new()
	_weapon_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_list_vbox.add_theme_constant_override("separation", 8)
	_weapon_list_scroll.add_child(_weapon_list_vbox)

	var preview := VBoxContainer.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.add_theme_constant_override("separation", 12)
	body.add_child(preview)

	_preview_title = Label.new()
	_preview_title.text = ""
	_preview_title.add_theme_font_size_override("font_size", 30)
	preview.add_child(_preview_title)

	_preview_icon = TextureRect.new()
	_preview_icon.custom_minimum_size = Vector2(240, 240)
	_preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(_preview_icon)

	_preview_desc = Label.new()
	_preview_desc.text = ""
	_preview_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_desc.add_theme_font_size_override("font_size", 22)
	preview.add_child(_preview_desc)

func _refresh_weapon_list() -> void:
	for c in _weapon_list_vbox.get_children():
		c.queue_free()

	_selected_weapon_id = ""
	_preview_title.text = ""
	_preview_icon.texture = null
	_preview_desc.text = ""
	_confirm_button.disabled = true

	if not RunManager or not RunManager.current_character:
		var tip := Label.new()
		tip.text = "未选择角色，无法选择武器"
		tip.add_theme_font_size_override("font_size", 24)
		_weapon_list_vbox.add_child(tip)
		return

	var weapon_ids: Array[String] = []
	if RunManager.has_method("get_owned_weapon_ids"):
		weapon_ids = RunManager.get_owned_weapon_ids()

	if weapon_ids.is_empty():
		var tip2 := Label.new()
		tip2.text = "暂无可用武器"
		tip2.add_theme_font_size_override("font_size", 24)
		_weapon_list_vbox.add_child(tip2)
		return

	for wid in weapon_ids:
		# 兜底：按当前角色武器类型过滤，避免出现“法器角色能选单手剑”等情况
		if RunManager and RunManager.has_method("is_weapon_compatible_with_current_character"):
			if not bool(RunManager.is_weapon_compatible_with_current_character(wid)):
				continue
		_create_weapon_button(wid)

func _create_weapon_button(weapon_id: String) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 72)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 22)
	btn.text = RunManager.get_weapon_display_name(weapon_id) if RunManager and RunManager.has_method("get_weapon_display_name") else weapon_id
	btn.pressed.connect(_on_weapon_pressed.bind(weapon_id))

	# 左侧图标
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if RunManager and RunManager.has_method("get_weapon_icon"):
		icon.texture = RunManager.get_weapon_icon(weapon_id)
	h.add_child(icon)

	var label := Label.new()
	label.text = btn.text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 22)
	h.add_child(label)

	btn.text = ""
	btn.add_child(h)
	_weapon_list_vbox.add_child(btn)

func _on_weapon_pressed(weapon_id: String) -> void:
	_selected_weapon_id = weapon_id
	_confirm_button.disabled = false

	var name := weapon_id
	var desc := ""
	var icon: Texture2D = null
	if RunManager:
		if RunManager.has_method("get_weapon_display_name"):
			name = RunManager.get_weapon_display_name(weapon_id)
		if RunManager.has_method("get_weapon_description"):
			desc = RunManager.get_weapon_description(weapon_id)
		if RunManager.has_method("get_weapon_icon"):
			icon = RunManager.get_weapon_icon(weapon_id)

	_preview_title.text = name
	_preview_desc.text = desc
	_preview_icon.texture = icon

func _on_confirm_pressed() -> void:
	if _selected_weapon_id.is_empty():
		return
	if RunManager and RunManager.has_method("equip_weapon"):
		RunManager.equip_weapon(_selected_weapon_id)
	if GameManager:
		GameManager.go_to_map_view()

func _on_back_pressed() -> void:
	# 返回角色选择，让玩家重新选角色/武器
	if GameManager:
		GameManager.go_to_character_select()
