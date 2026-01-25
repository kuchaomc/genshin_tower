extends Control
class_name CGGalleryPanel

signal closed

var _root: Control
var _back_button: Button
var _title: Label

var _list_scroll: ScrollContainer
var _list_vbox: VBoxContainer

var _preview: TextureRect
var _preview_title: Label
var _crt_temp_disable_token: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 10
	outer.offset_top = 10
	outer.offset_right = -10
	outer.offset_bottom = -10
	outer.add_theme_constant_override("separation", 10)
	_root.add_child(outer)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	outer.add_child(top_bar)

	_back_button = Button.new()
	_back_button.text = "返回"
	_back_button.custom_minimum_size = Vector2(120, 40)
	_back_button.pressed.connect(_on_back_pressed)
	top_bar.add_child(_back_button)

	_title = Label.new()
	_title.text = "CG回想"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	top_bar.add_child(_title)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	outer.add_child(body)

	_list_scroll = ScrollContainer.new()
	_list_scroll.custom_minimum_size = Vector2(320, 0)
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_scroll.size_flags_horizontal = Control.SIZE_FILL
	body.add_child(_list_scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 8)
	_list_scroll.add_child(_list_vbox)

	var preview_box := VBoxContainer.new()
	preview_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_box.add_theme_constant_override("separation", 8)
	body.add_child(preview_box)

	_preview_title = Label.new()
	_preview_title.text = ""
	_preview_title.add_theme_font_size_override("font_size", 22)
	preview_box.add_child(_preview_title)

	_preview = TextureRect.new()
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.expand_mode = 1
	_preview.stretch_mode = 5
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_box.add_child(_preview)

func show_panel() -> void:
	if PostProcessManager and PostProcessManager.has_method("push_temp_disable_crt"):
		if _crt_temp_disable_token <= 0:
			_crt_temp_disable_token = int(PostProcessManager.call("push_temp_disable_crt"))
	visible = true
	refresh()
	await get_tree().process_frame
	_back_button.grab_focus()

func hide_panel() -> void:
	_release_crt_temp_disable()
	visible = false

func _exit_tree() -> void:
	_release_crt_temp_disable()

func _release_crt_temp_disable() -> void:
	if _crt_temp_disable_token <= 0:
		return
	if PostProcessManager and PostProcessManager.has_method("pop_temp_disable_crt"):
		PostProcessManager.call("pop_temp_disable_crt", _crt_temp_disable_token)
	_crt_temp_disable_token = 0

func refresh() -> void:
	for c in _list_vbox.get_children():
		c.queue_free()

	if not GameManager:
		_preview_title.text = ""
		_preview.texture = null
		return

	var entries: Array = []
	if GameManager.has_method("get_unlocked_death_cg_entries"):
		entries = GameManager.call("get_unlocked_death_cg_entries")

	if entries.is_empty():
		var empty := Label.new()
		empty.text = "暂无已解锁CG"
		empty.add_theme_font_size_override("font_size", 20)
		_list_vbox.add_child(empty)
		_preview_title.text = ""
		_preview.texture = null
		return

	for e in entries:
		var character_id := str(e.get("character_id", ""))
		var character_name := str(e.get("character_name", ""))
		var enemy_id := str(e.get("enemy_id", ""))
		var enemy_name := str(e.get("enemy_name", ""))
		var char_display := character_name if not character_name.is_empty() else character_id
		if char_display.is_empty():
			char_display = "通用"
		var enemy_display := enemy_name if not enemy_name.is_empty() else enemy_id
		var btn := Button.new()
		btn.text = "%s - 被%s击败" % [char_display, enemy_display]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_select_cg.bind(character_id, character_name, enemy_id, enemy_name))
		_list_vbox.add_child(btn)

	_preview_title.text = ""
	_preview.texture = null

func _on_select_cg(character_id: String, character_name: String, enemy_id: String, enemy_name: String) -> void:
	_preview_title.text = ""
	_preview.texture = null
	if GameManager and GameManager.has_method("show_death_cg_fullscreen"):
		await GameManager.show_death_cg_fullscreen(character_id, character_name, enemy_id, enemy_name)

func _on_back_pressed() -> void:
	hide_panel()
	closed.emit()
