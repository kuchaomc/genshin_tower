extends CanvasLayer
class_name CGUnlockOverlay

signal exit_to_result_requested

var _root: Control
var _bg: ColorRect
var _exit_button: Button
var _title_label: Label
var _cg_texture_rect: TextureRect
var _hint_label: Label

func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0, 0, 0, 0.92)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_bg)

	_exit_button = Button.new()
	_exit_button.text = "退出至结算"
	_exit_button.position = Vector2(16, 16)
	_exit_button.custom_minimum_size = Vector2(160, 42)
	_exit_button.pressed.connect(_on_exit_pressed)
	_root.add_child(_exit_button)

	_title_label = Label.new()
	_title_label.text = ""
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title_label.offset_left = 24
	_title_label.offset_top = 72
	_title_label.offset_right = -24
	_title_label.offset_bottom = 140
	_title_label.add_theme_font_size_override("font_size", 36)
	_root.add_child(_title_label)

	_cg_texture_rect = TextureRect.new()
	_cg_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cg_texture_rect.offset_left = 120
	_cg_texture_rect.offset_top = 140
	_cg_texture_rect.offset_right = -120
	_cg_texture_rect.offset_bottom = -80
	_cg_texture_rect.expand_mode = 1
	_cg_texture_rect.stretch_mode = 5
	_cg_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_cg_texture_rect)

	_hint_label = Label.new()
	_hint_label.text = ""
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_label.offset_left = 24
	_hint_label.offset_top = -64
	_hint_label.offset_right = -24
	_hint_label.offset_bottom = -24
	_hint_label.add_theme_font_size_override("font_size", 20)
	_hint_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_root.add_child(_hint_label)

func show_cg(character_id: String, character_name: String, enemy_id: String, enemy_name: String) -> void:
	var char_display := character_name if not character_name.is_empty() else character_id
	var enemy_display := enemy_name if not enemy_name.is_empty() else enemy_id
	_title_label.text = "%s - 被%s击败" % [char_display, enemy_display]

	var tex: Texture2D = null
	if GameManager and GameManager.has_method("get_death_cg_texture"):
		tex = GameManager.call("get_death_cg_texture", character_id, enemy_id, enemy_name)
	_cg_texture_rect.texture = tex
	if tex:
		_hint_label.text = ""
	else:
		_hint_label.text = "未找到死亡CG资源"

	show()
	await get_tree().process_frame
	_exit_button.grab_focus()

func _on_exit_pressed() -> void:
	exit_to_result_requested.emit()
	hide()
