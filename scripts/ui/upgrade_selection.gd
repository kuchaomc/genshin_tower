extends Node2D

## 升级选择界面脚本
## 使用新的升级系统，支持稀有度、权重和条件筛选

signal upgrade_selected(upgrade_id: String)

@onready var _ui_root: Control = $CanvasLayer/UIRoot
@onready var _main_margin: MarginContainer = $CanvasLayer/UIRoot/MainMargin
@onready var _body_panel: PanelContainer = $CanvasLayer/UIRoot/MainMargin/MainVBox/BodyPanel

@onready var upgrade_container: VBoxContainer = $CanvasLayer/UIRoot/MainMargin/MainVBox/BodyPanel/BodyMargin/BodyVBox/UpgradeScroll/UpgradeContainer
@onready var title_label: Label = $CanvasLayer/UIRoot/MainMargin/MainVBox/HeaderHBox/TitleLabel

# 可选的升级列表（UpgradeData 类型）
var available_upgrades: Array[UpgradeData] = []

# 升级选项数量
@export var upgrade_count: int = 3

var _is_processing_selection: bool = false

var _ui_tween: Tween = null
var _hover_tweens: Dictionary = {}
var _closing: bool = false
var _layout_cached: bool = false

var _ui_root_final_modulate: Color = Color(1, 1, 1, 1)
var _main_margin_final_scale: Vector2 = Vector2.ONE
var _main_margin_final_position: Vector2 = Vector2.ZERO
var _main_margin_final_modulate: Color = Color(1, 1, 1, 1)

var _panel_style: StyleBoxFlat = null
var _card_style_normal: StyleBoxFlat = null
var _card_style_hover: StyleBoxFlat = null
var _card_style_pressed: StyleBoxFlat = null
var _button_style_normal: StyleBoxFlat = null
var _button_style_hover: StyleBoxFlat = null
var _button_style_pressed: StyleBoxFlat = null
var _button_style_disabled: StyleBoxFlat = null

func _ready() -> void:
	_process_ui_style()
	generate_upgrade_options()
	display_upgrades()
	# 如果是从战斗转场过来（屏幕仍处于黑屏/转场中），在UI准备好后淡入
	if TransitionManager and TransitionManager.is_transitioning:
		await TransitionManager.fade_in(0.4)
	_cache_layout()
	_play_open_animation()

func _process_ui_style() -> void:
	if _panel_style == null:
		_panel_style = StyleBoxFlat.new()
		_panel_style.bg_color = Color(0.10, 0.12, 0.16, 0.98)
		_panel_style.border_width_left = 4
		_panel_style.border_width_top = 4
		_panel_style.border_width_right = 4
		_panel_style.border_width_bottom = 4
		_panel_style.border_color = Color(0.86, 0.88, 0.92, 1.0)
		_panel_style.shadow_color = Color(0, 0, 0, 0.55)
		_panel_style.shadow_size = 10
		_panel_style.shadow_offset = Vector2(0, 8)
		_panel_style.content_margin_left = 0
		_panel_style.content_margin_top = 0
		_panel_style.content_margin_right = 0
		_panel_style.content_margin_bottom = 0

	if _card_style_normal == null:
		_card_style_normal = StyleBoxFlat.new()
		_card_style_normal.bg_color = Color(0.13, 0.15, 0.20, 0.98)
		_card_style_normal.border_width_left = 3
		_card_style_normal.border_width_top = 3
		_card_style_normal.border_width_right = 3
		_card_style_normal.border_width_bottom = 3
		_card_style_normal.border_color = Color(0.40, 0.44, 0.52, 1.0)
		_card_style_normal.corner_radius_top_left = 6
		_card_style_normal.corner_radius_top_right = 6
		_card_style_normal.corner_radius_bottom_left = 6
		_card_style_normal.corner_radius_bottom_right = 6
		_card_style_normal.content_margin_left = 0
		_card_style_normal.content_margin_top = 0
		_card_style_normal.content_margin_right = 0
		_card_style_normal.content_margin_bottom = 0

	if _card_style_hover == null:
		_card_style_hover = _card_style_normal.duplicate() as StyleBoxFlat
		_card_style_hover.border_color = Color(0.62, 0.68, 0.80, 1.0)

	if _card_style_pressed == null:
		_card_style_pressed = _card_style_normal.duplicate() as StyleBoxFlat
		_card_style_pressed.border_color = Color(0.78, 0.82, 0.92, 1.0)

	if _button_style_normal == null:
		_button_style_normal = StyleBoxFlat.new()
		_button_style_normal.bg_color = Color(0.16, 0.20, 0.28, 1.0)
		_button_style_normal.border_width_left = 3
		_button_style_normal.border_width_top = 3
		_button_style_normal.border_width_right = 3
		_button_style_normal.border_width_bottom = 3
		_button_style_normal.border_color = Color(0.80, 0.82, 0.88, 1.0)
		_button_style_normal.corner_radius_top_left = 6
		_button_style_normal.corner_radius_top_right = 6
		_button_style_normal.corner_radius_bottom_left = 6
		_button_style_normal.corner_radius_bottom_right = 6
		_button_style_normal.content_margin_left = 12
		_button_style_normal.content_margin_top = 10
		_button_style_normal.content_margin_right = 12
		_button_style_normal.content_margin_bottom = 10

	if _button_style_hover == null:
		_button_style_hover = _button_style_normal.duplicate() as StyleBoxFlat
		_button_style_hover.bg_color = Color(0.20, 0.25, 0.34, 1.0)
		_button_style_hover.border_color = Color(0.92, 0.94, 0.98, 1.0)

	if _button_style_pressed == null:
		_button_style_pressed = _button_style_normal.duplicate() as StyleBoxFlat
		_button_style_pressed.bg_color = Color(0.12, 0.15, 0.22, 1.0)
		_button_style_pressed.border_color = Color(1.0, 0.92, 0.65, 1.0)

	if _button_style_disabled == null:
		_button_style_disabled = _button_style_normal.duplicate() as StyleBoxFlat
		_button_style_disabled.bg_color = Color(0.10, 0.12, 0.16, 0.70)
		_button_style_disabled.border_color = Color(0.35, 0.38, 0.45, 0.80)

	if is_instance_valid(_body_panel):
		_body_panel.add_theme_stylebox_override("panel", _panel_style)

	if is_instance_valid(title_label):
		title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65, 1.0))

## 生成升级选项
func generate_upgrade_options() -> void:
	available_upgrades.clear()
	
	var registry = UpgradeRegistry
	
	# 获取当前角色ID和楼层
	var character_id = ""
	var current_floor = RunManager.current_floor
	var current_upgrades: Dictionary = RunManager.upgrades
	if RunManager.current_character:
		character_id = RunManager.current_character.id
	
	# 使用注册表的随机选取功能
	var picked: Array = registry.pick_random_upgrades(
		character_id,
		current_upgrades,
		current_floor,
		upgrade_count
	)
	
	for u in picked:
		if u is UpgradeData:
			available_upgrades.append(u)
	
	if available_upgrades.size() == 0:
		push_warning("UpgradeSelection: 没有可用的升级选项")

## 显示升级选项
func display_upgrades() -> void:
	if not upgrade_container:
		return
	
	# 清空现有按钮
	for child in upgrade_container.get_children():
		child.queue_free()
	
	# 为每个升级创建按钮
	for upgrade in available_upgrades:
		_create_upgrade_button(upgrade)
	_refresh_center_pivot()

## 创建新版升级按钮
func _create_upgrade_button(upgrade: UpgradeData) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 132)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _card_style_normal)
	upgrade_container.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var info_v := VBoxContainer.new()
	info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_v.add_theme_constant_override("separation", 6)
	row.add_child(info_v)

	var current_level: int = int(RunManager.get_upgrade_level(upgrade.id))
	var title_h := HBoxContainer.new()
	title_h.add_theme_constant_override("separation", 10)
	info_v.add_child(title_h)

	var rarity_label := Label.new()
	rarity_label.text = upgrade.get_rarity_stars()
	rarity_label.add_theme_color_override("font_color", upgrade.get_rarity_color())
	title_h.add_child(rarity_label)

	var name_label := Label.new()
	if current_level > 0:
		name_label.text = "%s (Lv.%d → %d)" % [upgrade.display_name, current_level, current_level + 1]
	else:
		name_label.text = upgrade.display_name
	name_label.add_theme_color_override("font_color", upgrade.get_rarity_color())
	title_h.add_child(name_label)

	if upgrade.max_level > 0:
		var max_level_label := Label.new()
		max_level_label.text = "/ %d" % upgrade.max_level
		max_level_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		title_h.add_child(max_level_label)

	var desc_label := Label.new()
	desc_label.text = upgrade.get_formatted_description(current_level)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96, 1.0))
	info_v.add_child(desc_label)

	if upgrade.tags.size() > 0:
		var tags_label := Label.new()
		tags_label.text = "标签: " + ", ".join(upgrade.tags)
		tags_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		tags_label.add_theme_font_size_override("font_size", 12)
		info_v.add_child(tags_label)

	var action_v := VBoxContainer.new()
	action_v.size_flags_horizontal = Control.SIZE_SHRINK_END
	action_v.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(action_v)

	var choose_btn := Button.new()
	choose_btn.text = "选择"
	choose_btn.custom_minimum_size = Vector2(140, 52)
	choose_btn.pressed.connect(_on_upgrade_selected.bind(upgrade.id))
	_apply_button_theme(choose_btn)
	_bind_button_fx(choose_btn)
	action_v.add_child(choose_btn)

	_bind_card_fx(card)

## 升级被选中
func _on_upgrade_selected(upgrade_id: String) -> void:
	if _is_processing_selection:
		return
	_is_processing_selection = true
	
	RunManager.add_upgrade(upgrade_id, 1)
	
	emit_signal("upgrade_selected", upgrade_id)
	print("选择升级：", upgrade_id)
	
	# 选择升级后返回地图（当前局继续，不在此处结算整局）
	
	# 返回地图界面：先播放本UI退场动画，再淡出遮罩掩盖切场景加载
	_close_and_do(func() -> void:
		call_deferred("_fade_out_and_go_to_map")
	)

func _fade_out_and_go_to_map() -> void:
	if TransitionManager:
		await TransitionManager.fade_out(0.4)
	GameManager.go_to_map_view()

func _apply_button_theme(button: Button) -> void:
	if not is_instance_valid(button):
		return
	button.add_theme_stylebox_override("normal", _button_style_normal)
	button.add_theme_stylebox_override("hover", _button_style_hover)
	button.add_theme_stylebox_override("pressed", _button_style_pressed)
	button.add_theme_stylebox_override("disabled", _button_style_disabled)
	button.add_theme_color_override("font_color", Color(0.95, 0.96, 0.99, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.65, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.66, 1.0))
	button.focus_mode = Control.FOCUS_ALL
	_ensure_center_pivot(button)

func _ensure_center_pivot(control: Control) -> void:
	if not is_instance_valid(control):
		return
	control.pivot_offset = control.size * 0.5

func _refresh_center_pivot() -> void:
	if is_instance_valid(_main_margin):
		_ensure_center_pivot(_main_margin)
	var controls: Array[Node] = _ui_root.find_children("*", "Control", true, false)
	for n in controls:
		if n is Control:
			_ensure_center_pivot(n as Control)

func _kill_hover_tween_for(target: CanvasItem) -> void:
	if target == null:
		return
	if _hover_tweens.has(target):
		var t: Tween = _hover_tweens[target]
		if t:
			t.kill()
		_hover_tweens.erase(target)

func _bind_button_fx(button: Button) -> void:
	if not is_instance_valid(button):
		return
	if not button.mouse_entered.is_connected(_on_button_mouse_entered.bind(button)):
		button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
	if not button.mouse_exited.is_connected(_on_button_mouse_exited.bind(button)):
		button.mouse_exited.connect(_on_button_mouse_exited.bind(button))
	if not button.button_down.is_connected(_on_button_down.bind(button)):
		button.button_down.connect(_on_button_down.bind(button))
	if not button.button_up.is_connected(_on_button_up.bind(button)):
		button.button_up.connect(_on_button_up.bind(button))
	if not button.focus_entered.is_connected(_on_button_focus_entered.bind(button)):
		button.focus_entered.connect(_on_button_focus_entered.bind(button))
	if not button.focus_exited.is_connected(_on_button_focus_exited.bind(button)):
		button.focus_exited.connect(_on_button_focus_exited.bind(button))
	_ensure_center_pivot(button)

func _get_button_base_scale(button: Button) -> Vector2:
	return Vector2.ONE

func _on_button_mouse_entered(button: Button) -> void:
	_kill_hover_tween_for(button)
	var base_scale := _get_button_base_scale(button)
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(button, "scale", base_scale * 1.03, 0.10)
	_hover_tweens[button] = t

func _on_button_mouse_exited(button: Button) -> void:
	_kill_hover_tween_for(button)
	var base_scale := _get_button_base_scale(button)
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(button, "scale", base_scale, 0.10)
	_hover_tweens[button] = t

func _on_button_focus_entered(button: Button) -> void:
	_on_button_mouse_entered(button)

func _on_button_focus_exited(button: Button) -> void:
	_on_button_mouse_exited(button)

func _on_button_down(button: Button) -> void:
	_kill_hover_tween_for(button)
	var base_scale := _get_button_base_scale(button)
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(button, "scale", base_scale * 0.98, 0.06)
	_hover_tweens[button] = t

func _on_button_up(button: Button) -> void:
	if button.is_hovered() or button.has_focus():
		_on_button_mouse_entered(button)
	else:
		_on_button_mouse_exited(button)

func _bind_card_fx(card: Control) -> void:
	if not is_instance_valid(card):
		return
	if not card.mouse_entered.is_connected(_on_card_mouse_entered.bind(card)):
		card.mouse_entered.connect(_on_card_mouse_entered.bind(card))
	if not card.mouse_exited.is_connected(_on_card_mouse_exited.bind(card)):
		card.mouse_exited.connect(_on_card_mouse_exited.bind(card))
	if not card.gui_input.is_connected(_on_card_gui_input.bind(card)):
		card.gui_input.connect(_on_card_gui_input.bind(card))
	_ensure_center_pivot(card)

func _on_card_mouse_entered(card: Control) -> void:
	card.add_theme_stylebox_override("panel", _card_style_hover)
	_kill_hover_tween_for(card)
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(card, "scale", Vector2.ONE * 1.01, 0.10)
	_hover_tweens[card] = t

func _on_card_mouse_exited(card: Control) -> void:
	card.add_theme_stylebox_override("panel", _card_style_normal)
	_kill_hover_tween_for(card)
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(card, "scale", Vector2.ONE, 0.10)
	_hover_tweens[card] = t

func _on_card_gui_input(event: InputEvent, card: Control) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				card.add_theme_stylebox_override("panel", _card_style_pressed)
			else:
				card.add_theme_stylebox_override("panel", _card_style_hover)

func _kill_ui_tween() -> void:
	if _ui_tween and _ui_tween.is_running():
		_ui_tween.kill()
	_ui_tween = null

func _cache_layout() -> void:
	await get_tree().process_frame
	if is_instance_valid(_ui_root):
		_ui_root_final_modulate = _ui_root.modulate
	if is_instance_valid(_main_margin):
		_main_margin_final_scale = _main_margin.scale
		_main_margin_final_position = _main_margin.position
		_main_margin_final_modulate = _main_margin.modulate
		_ensure_center_pivot(_main_margin)
	_layout_cached = true

func _play_open_animation() -> void:
	if not is_instance_valid(_ui_root) or not is_instance_valid(_main_margin):
		return
	# 进入升级选择时通常已经有转场淡入，这里不再叠加弹出动画，直接设置为最终状态。
	_closing = false
	_ui_root.modulate = _ui_root_final_modulate
	_main_margin.position = _main_margin_final_position
	_main_margin.scale = _main_margin_final_scale
	_main_margin.modulate = _main_margin_final_modulate

func _close_and_do(action: Callable) -> void:
	if _closing:
		return
	_closing = true
	if not is_instance_valid(_ui_root) or not is_instance_valid(_main_margin):
		action.call()
		return
	_kill_ui_tween()
	_ui_tween = create_tween()
	_ui_tween.set_trans(Tween.TRANS_CUBIC)
	_ui_tween.set_ease(Tween.EASE_IN)
	_ui_tween.parallel().tween_property(_main_margin, "modulate", Color(_main_margin_final_modulate.r, _main_margin_final_modulate.g, _main_margin_final_modulate.b, 0.0), 0.18)
	_ui_tween.parallel().tween_property(_main_margin, "position", _main_margin_final_position + Vector2(0, 16), 0.20)
	_ui_tween.parallel().tween_property(_main_margin, "scale", _main_margin_final_scale * 0.96, 0.20)
	_ui_tween.finished.connect(func() -> void:
		action.call()
	)

## 刷新升级选项（可在运行时调用）
func refresh_options() -> void:
	generate_upgrade_options()
	display_upgrades()