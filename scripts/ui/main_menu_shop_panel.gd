extends Control
class_name MainMenuShopPanel

signal closed

const CG_PRICE_PRIMOGEMS: int = 100
const WEAPON_PRICE_PRIMOGEMS: int = 500

# 与现有工程约定保持一致：主菜单/CG资源位于 textures/cg
const _CG_TEXTURE_DIR: String = "res://textures/cg"
const _CG_EXTS: PackedStringArray = ["png", "jpg", "jpeg", "webp"]

# Android 导出后可能无法枚举 res:// 目录：提供兜底列表 + preload 强引用，确保资源被打包。
const _CG_FALLBACK_PATHS: PackedStringArray = [
	"res://textures/cg/神里绫华-女仆装.png",
	"res://textures/cg/神里绫华-护士服.png",
	"res://textures/cg/神里绫华-普通.png",
	"res://textures/cg/神里绫华-校服.png",
	"res://textures/cg/神里绫华-泳装.png",
]
const _CG_FALLBACK_PRELOADS: Array[Texture2D] = [
	preload("res://textures/cg/神里绫华-女仆装.png"),
	preload("res://textures/cg/神里绫华-护士服.png"),
	preload("res://textures/cg/神里绫华-普通.png"),
	preload("res://textures/cg/神里绫华-校服.png"),
	preload("res://textures/cg/神里绫华-泳装.png"),
]

const _SETTINGS_FILE_PATH: String = "user://settings.cfg"
const _SETTINGS_SECTION_UI: String = "ui"
const _SETTINGS_KEY_NSFW_ENABLED: String = "nsfw_enabled"

var _root: Control

var _back_button: Button
var _title: Label
var _primogems_label: Label

var _tabs: TabContainer

# CG 页
var _cg_list_scroll: ScrollContainer
var _cg_list_vbox: VBoxContainer
var _cg_preview_title: Label
var _cg_preview: TextureRect
var _cg_buy_button: Button
var _cg_buy_hint: Label

# 当前选中的CG（用资源路径做ID，避免重名）
var _selected_cg_id: String = ""

# 武器页
var _weapon_list_scroll: ScrollContainer
var _weapon_list_vbox: VBoxContainer
var _weapon_preview_title: Label
var _weapon_preview_icon: TextureRect
var _weapon_buy_button: Button
var _weapon_buy_hint: Label
var _selected_weapon_id: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	if GameManager and GameManager.has_signal("primogems_total_changed"):
		if not GameManager.primogems_total_changed.is_connected(_on_primogems_total_changed):
			GameManager.primogems_total_changed.connect(_on_primogems_total_changed)

func show_panel() -> void:
	visible = true
	refresh()
	await get_tree().process_frame
	if is_instance_valid(_back_button):
		_back_button.grab_focus()

func hide_panel() -> void:
	visible = false

func refresh() -> void:
	_update_primogems_label()
	_refresh_cg_list()
	_refresh_weapon_list()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 24
	outer.offset_top = 24
	outer.offset_right = -24
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
	_title.text = "商店"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 40)
	top_bar.add_child(_title)

	_primogems_label = Label.new()
	_primogems_label.text = "原石：0"
	_primogems_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	_primogems_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_primogems_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_primogems_label.add_theme_font_size_override("font_size", 24)
	top_bar.add_child(_primogems_label)

	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_constant_override("tab_height", 56)
	outer.add_child(_tabs)
	var tab_bar := _tabs.get_tab_bar()
	if is_instance_valid(tab_bar):
		tab_bar.add_theme_font_size_override("font_size", 24)

	_build_tab_cg()
	_build_tab_character()
	_build_tab_weapon()

func _build_tab_cg() -> void:
	var page := Control.new()
	page.name = "CG"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(page)

	var body := HBoxContainer.new()
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_theme_constant_override("separation", 16)
	page.add_child(body)

	_cg_list_scroll = ScrollContainer.new()
	_cg_list_scroll.custom_minimum_size = Vector2(380, 0)
	_cg_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cg_list_scroll.size_flags_horizontal = Control.SIZE_FILL
	body.add_child(_cg_list_scroll)

	_cg_list_vbox = VBoxContainer.new()
	_cg_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cg_list_vbox.add_theme_constant_override("separation", 8)
	_cg_list_scroll.add_child(_cg_list_vbox)

	var preview_box := VBoxContainer.new()
	preview_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_box.add_theme_constant_override("separation", 12)
	body.add_child(preview_box)

	_cg_preview_title = Label.new()
	_cg_preview_title.text = ""
	_cg_preview_title.add_theme_font_size_override("font_size", 28)
	preview_box.add_child(_cg_preview_title)

	_cg_preview = TextureRect.new()
	_cg_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cg_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cg_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cg_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cg_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_box.add_child(_cg_preview)

	_cg_buy_hint = Label.new()
	_cg_buy_hint.text = ""
	_cg_buy_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cg_buy_hint.add_theme_font_size_override("font_size", 20)
	preview_box.add_child(_cg_buy_hint)

	_cg_buy_button = Button.new()
	_cg_buy_button.text = "购买"
	_cg_buy_button.custom_minimum_size = Vector2(240, 60)
	_cg_buy_button.add_theme_font_size_override("font_size", 22)
	_cg_buy_button.pressed.connect(_on_buy_selected_cg_pressed)
	preview_box.add_child(_cg_buy_button)

func _build_tab_character() -> void:
	var page := VBoxContainer.new()
	page.name = "角色"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10)
	_tabs.add_child(page)

	var label := Label.new()
	label.text = "角色商店暂未开放"
	label.add_theme_font_size_override("font_size", 26)
	page.add_child(label)

func _build_tab_weapon() -> void:
	var page := Control.new()
	page.name = "武器"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(page)

	var body := HBoxContainer.new()
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_theme_constant_override("separation", 16)
	page.add_child(body)

	_weapon_list_scroll = ScrollContainer.new()
	_weapon_list_scroll.custom_minimum_size = Vector2(380, 0)
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

	_weapon_preview_title = Label.new()
	_weapon_preview_title.text = ""
	_weapon_preview_title.add_theme_font_size_override("font_size", 28)
	preview.add_child(_weapon_preview_title)

	_weapon_preview_icon = TextureRect.new()
	_weapon_preview_icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_preview_icon.custom_minimum_size = Vector2(240, 240)
	_weapon_preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weapon_preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_weapon_preview_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(_weapon_preview_icon)

	_weapon_buy_hint = Label.new()
	_weapon_buy_hint.text = ""
	_weapon_buy_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_weapon_buy_hint.add_theme_font_size_override("font_size", 20)
	preview.add_child(_weapon_buy_hint)

	_weapon_buy_button = Button.new()
	_weapon_buy_button.text = "购买"
	_weapon_buy_button.custom_minimum_size = Vector2(240, 60)
	_weapon_buy_button.add_theme_font_size_override("font_size", 22)
	_weapon_buy_button.disabled = true
	_weapon_buy_button.pressed.connect(_on_buy_selected_weapon_pressed)
	preview.add_child(_weapon_buy_button)

	_refresh_weapon_list()


func _refresh_weapon_list() -> void:
	if not is_instance_valid(_weapon_list_vbox):
		return
	for c in _weapon_list_vbox.get_children():
		c.queue_free()
	_selected_weapon_id = ""
	_weapon_preview_title.text = ""
	_weapon_preview_icon.texture = null
	_weapon_buy_hint.text = ""
	_weapon_buy_button.disabled = true

	if not RunManager or not RunManager.has_method("get_all_weapon_ids"):
		var tip := Label.new()
		tip.text = "无法读取武器列表"
		tip.add_theme_font_size_override("font_size", 24)
		_weapon_list_vbox.add_child(tip)
		return

	var ids := RunManager.get_all_weapon_ids()
	if ids.is_empty():
		var tip2 := Label.new()
		tip2.text = "暂无武器"
		tip2.add_theme_font_size_override("font_size", 24)
		_weapon_list_vbox.add_child(tip2)
		return

	for wid in ids:
		# 无锋剑默认拥有，不在商店出售
		if str(wid) == "wufeng_sword":
			continue
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 52)
		btn.add_theme_font_size_override("font_size", 22)
		var name := RunManager.get_weapon_display_name(str(wid)) if RunManager.has_method("get_weapon_display_name") else str(wid)
		var owned := GameManager.is_shop_weapon_unlocked(str(wid)) if (GameManager and GameManager.has_method("is_shop_weapon_unlocked")) else false
		btn.text = "%s（已拥有）" % name if owned else "%s（%d原石）" % [name, WEAPON_PRICE_PRIMOGEMS]
		btn.pressed.connect(_on_select_weapon.bind(str(wid)))
		_weapon_list_vbox.add_child(btn)


func _on_select_weapon(weapon_id: String) -> void:
	_selected_weapon_id = weapon_id
	_update_selected_weapon_preview()


func _update_selected_weapon_preview() -> void:
	_weapon_preview_title.text = ""
	_weapon_preview_icon.texture = null
	_weapon_buy_hint.text = ""
	_weapon_buy_button.disabled = true

	if _selected_weapon_id.is_empty():
		return
	var name := RunManager.get_weapon_display_name(_selected_weapon_id) if (RunManager and RunManager.has_method("get_weapon_display_name")) else _selected_weapon_id
	_weapon_preview_title.text = name
	_weapon_preview_icon.texture = RunManager.get_weapon_icon(_selected_weapon_id) if (RunManager and RunManager.has_method("get_weapon_icon")) else null

	var owned := GameManager.is_shop_weapon_unlocked(_selected_weapon_id) if (GameManager and GameManager.has_method("is_shop_weapon_unlocked")) else false
	if owned:
		_weapon_buy_hint.text = "已拥有"
		_weapon_buy_button.text = "已拥有"
		_weapon_buy_button.disabled = true
		return

	_weapon_buy_button.text = "购买（%d原石）" % WEAPON_PRICE_PRIMOGEMS
	_weapon_buy_button.disabled = false
	_weapon_buy_hint.text = "购买后可在武器选择界面使用"


func _on_buy_selected_weapon_pressed() -> void:
	if _selected_weapon_id.is_empty():
		return
	if not GameManager:
		return
	if GameManager.has_method("is_shop_weapon_unlocked") and bool(GameManager.call("is_shop_weapon_unlocked", _selected_weapon_id)):
		return
	if GameManager.has_method("spend_primogems"):
		var ok: bool = bool(GameManager.call("spend_primogems", WEAPON_PRICE_PRIMOGEMS))
		if not ok:
			_weapon_buy_hint.text = "原石不足"
			return
	if GameManager.has_method("unlock_shop_weapon"):
		GameManager.call("unlock_shop_weapon", _selected_weapon_id)
	var keep := _selected_weapon_id
	_refresh_weapon_list()
	_on_select_weapon(keep)

func _on_back_pressed() -> void:
	hide_panel()
	closed.emit()

func _on_primogems_total_changed(_total: int) -> void:
	_update_primogems_label()

func _update_primogems_label() -> void:
	var v: int = 0
	if GameManager and GameManager.has_method("get_primogems_total"):
		v = int(GameManager.get_primogems_total())
	_primogems_label.text = "原石：%d" % v

func _is_nsfw_enabled_from_settings() -> bool:
	var config := ConfigFile.new()
	var err: Error = config.load(_SETTINGS_FILE_PATH)
	if err != OK:
		return false
	return bool(config.get_value(_SETTINGS_SECTION_UI, _SETTINGS_KEY_NSFW_ENABLED, false))

# 收集CG资源路径。
# - 编辑器/PC：优先枚举目录
# - Android 导出：若枚举失败则回退到显式列表
func _collect_cg_candidates() -> PackedStringArray:
	var result: PackedStringArray = []
	var dir := DirAccess.open(_CG_TEXTURE_DIR)
	if dir == null:
		return _CG_FALLBACK_PATHS
	
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if dir.current_is_dir():
			continue
		var ext := name.get_extension().to_lower()
		if ext in _CG_EXTS:
			result.append(_CG_TEXTURE_DIR.path_join(name))
	dir.list_dir_end()
	if result.is_empty():
		return _CG_FALLBACK_PATHS
	result.sort()
	return result

func _refresh_cg_list() -> void:
	for c in _cg_list_vbox.get_children():
		c.queue_free()

	_selected_cg_id = ""
	_cg_preview_title.text = ""
	_cg_preview.texture = null
	_cg_buy_hint.text = ""
	_cg_buy_button.disabled = true

	if not _is_nsfw_enabled_from_settings():
		var tip := Label.new()
		tip.text = "请在设置中开启NSFW…"
		tip.add_theme_font_size_override("font_size", 22)
		_cg_list_vbox.add_child(tip)
		return

	var candidates := _collect_cg_candidates()
	if candidates.is_empty():
		var empty := Label.new()
		empty.text = "CG文件夹为空"
		empty.add_theme_font_size_override("font_size", 24)
		_cg_list_vbox.add_child(empty)
		return

	for path_any in candidates:
		var path: String = String(path_any)
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 52)
		btn.add_theme_font_size_override("font_size", 22)
		btn.text = _format_cg_list_text(path)
		btn.pressed.connect(_on_select_cg.bind(path))
		_cg_list_vbox.add_child(btn)

func _format_cg_list_text(path: String) -> String:
	var file_name := path.get_file().get_basename()
	var owned: bool = false
	if GameManager and GameManager.has_method("is_shop_cg_unlocked"):
		owned = bool(GameManager.call("is_shop_cg_unlocked", path))
	if owned:
		return "%s（已拥有）" % file_name
	return "%s（%d原石）" % [file_name, CG_PRICE_PRIMOGEMS]

func _on_select_cg(path: String) -> void:
	_selected_cg_id = path
	_update_selected_cg_preview()

func _update_selected_cg_preview() -> void:
	_cg_preview_title.text = ""
	_cg_preview.texture = null
	_cg_buy_hint.text = ""
	_cg_buy_button.disabled = true

	if _selected_cg_id.is_empty():
		return

	var file_name := _selected_cg_id.get_file().get_basename()
	_cg_preview_title.text = file_name

	var owned: bool = false
	if GameManager and GameManager.has_method("is_shop_cg_unlocked"):
		owned = bool(GameManager.call("is_shop_cg_unlocked", _selected_cg_id))

	if owned:
		var tex := load(_selected_cg_id) as Texture2D
		_cg_preview.texture = tex
		_cg_buy_hint.text = "已购买"
		_cg_buy_button.text = "已拥有"
		_cg_buy_button.disabled = true
		return

	_cg_buy_button.text = "购买（%d原石）" % CG_PRICE_PRIMOGEMS
	_cg_buy_button.disabled = false
	_cg_buy_hint.text = "购买后可在此处预览"

func _on_buy_selected_cg_pressed() -> void:
	if _selected_cg_id.is_empty():
		return

	if not GameManager:
		return

	if GameManager.has_method("is_shop_cg_unlocked") and bool(GameManager.call("is_shop_cg_unlocked", _selected_cg_id)):
		return

	# 扣除原石 + 记录解锁（跨局存档）
	if GameManager.has_method("spend_primogems"):
		var ok: bool = bool(GameManager.call("spend_primogems", CG_PRICE_PRIMOGEMS))
		if not ok:
			_cg_buy_hint.text = "原石不足"
			return
	if GameManager.has_method("unlock_shop_cg"):
		GameManager.call("unlock_shop_cg", _selected_cg_id)

	var keep_id := _selected_cg_id
	refresh()
	# 重新选中，避免刷新后预览区清空
	_on_select_cg(keep_id)
