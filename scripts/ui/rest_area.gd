extends Node2D

## 休息处场景脚本
## 功能：
## - 选择恢复20%血量
## - 选择升级一个已有的升级

signal rest_completed

@onready var _ui_root: Control = $CanvasLayer/UIRoot
@onready var _main_margin: MarginContainer = $CanvasLayer/UIRoot/MainMargin
@onready var _rest_panel: PanelContainer = $CanvasLayer/UIRoot/MainMargin/MainVBox/RestPanel

@onready var title_label: Label = $CanvasLayer/UIRoot/MainMargin/MainVBox/TitleLabel
@onready var description_label: Label = $CanvasLayer/UIRoot/MainMargin/MainVBox/RestPanel/RestMargin/RestVBox/DescriptionLabel
@onready var choice_container: VBoxContainer = $CanvasLayer/UIRoot/MainMargin/MainVBox/RestPanel/RestMargin/RestVBox/ChoiceContainer
@onready var upgrade_selection_container: VBoxContainer = $CanvasLayer/UIRoot/MainMargin/MainVBox/RestPanel/RestMargin/RestVBox/UpgradeSelectionContainer
@onready var back_button: Button = $CanvasLayer/UIRoot/MainMargin/MainVBox/BackButton

var _ui_tween: Tween = null
var _hover_tweens: Dictionary = {}
var _closing: bool = false
var _layout_cached: bool = false

var _ui_root_final_modulate: Color = Color(1, 1, 1, 1)
var _main_margin_final_scale: Vector2 = Vector2.ONE
var _main_margin_final_position: Vector2 = Vector2.ZERO

var _panel_style: StyleBoxFlat = null
var _button_style_normal: StyleBoxFlat = null
var _button_style_hover: StyleBoxFlat = null
var _button_style_pressed: StyleBoxFlat = null
var _button_style_disabled: StyleBoxFlat = null

## 当前状态
enum RestState {
	CHOOSING,           # 选择休息方式
	SELECTING_UPGRADE,  # 选择要升级的升级
	COMPLETED           # 完成
}

var current_state: RestState = RestState.CHOOSING

## 玩家已有的升级列表（用于显示可升级的选项）
var owned_upgrades: Array = []

func _ready() -> void:
	_process_ui_style()
	_setup_container_auto_style()
	call_deferred("_cache_layout")
	call_deferred("_play_open_animation")
	
	_setup_ui()
	_show_rest_choices()
	
	# 连接返回按钮
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

func _setup_container_auto_style() -> void:
	if is_instance_valid(choice_container) and not choice_container.child_entered_tree.is_connected(_on_container_child_entered):
		choice_container.child_entered_tree.connect(_on_container_child_entered)
	if is_instance_valid(upgrade_selection_container) and not upgrade_selection_container.child_entered_tree.is_connected(_on_container_child_entered):
		upgrade_selection_container.child_entered_tree.connect(_on_container_child_entered)

func _on_container_child_entered(node: Node) -> void:
	if node is Button:
		_bind_button_fx(node as Button)

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

	if is_instance_valid(_rest_panel):
		_rest_panel.add_theme_stylebox_override("panel", _panel_style)
		_rest_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		_ensure_center_pivot(_rest_panel)

	if title_label:
		title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65, 1.0))
	if description_label:
		description_label.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96, 1.0))

	if _button_style_normal == null:
		_button_style_normal = StyleBoxFlat.new()
		_button_style_normal.bg_color = Color(0.16, 0.18, 0.24, 1.0)
		_button_style_normal.border_width_left = 3
		_button_style_normal.border_width_top = 3
		_button_style_normal.border_width_right = 3
		_button_style_normal.border_width_bottom = 3
		_button_style_normal.border_color = Color(0.86, 0.88, 0.92, 0.90)
		_button_style_normal.content_margin_left = 12
		_button_style_normal.content_margin_top = 10
		_button_style_normal.content_margin_right = 12
		_button_style_normal.content_margin_bottom = 10

		_button_style_hover = _button_style_normal.duplicate()
		_button_style_hover.bg_color = Color(0.20, 0.22, 0.30, 1.0)
		_button_style_hover.border_color = Color(1.0, 0.96, 0.72, 0.95)

		_button_style_pressed = _button_style_normal.duplicate()
		_button_style_pressed.bg_color = Color(0.12, 0.14, 0.20, 1.0)
		_button_style_pressed.border_color = Color(1.0, 0.96, 0.72, 0.85)

		_button_style_disabled = _button_style_normal.duplicate()
		_button_style_disabled.bg_color = Color(0.12, 0.13, 0.16, 1.0)
		_button_style_disabled.border_color = Color(0.55, 0.57, 0.62, 0.70)

	_apply_button_theme(back_button)

func _apply_button_theme(button: Button) -> void:
	if not is_instance_valid(button):
		return
	button.focus_mode = Control.FOCUS_ALL
	_ensure_center_pivot(button)
	button.add_theme_stylebox_override("normal", _button_style_normal)
	button.add_theme_stylebox_override("hover", _button_style_hover)
	button.add_theme_stylebox_override("pressed", _button_style_pressed)
	button.add_theme_stylebox_override("disabled", _button_style_disabled)
	button.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.92, 0.95, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.92, 0.95, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.65, 0.67, 0.72, 1.0))
	if not button.has_meta("ui_base_scale"):
		button.set_meta("ui_base_scale", button.scale)

func _ensure_center_pivot(control: Control) -> void:
	if not is_instance_valid(control):
		return
	control.pivot_offset = control.size * 0.5
	if control.has_meta("ui_pivot_bound") and bool(control.get_meta("ui_pivot_bound")):
		return
	control.set_meta("ui_pivot_bound", true)
	if not control.resized.is_connected(_on_control_resized.bind(control)):
		control.resized.connect(_on_control_resized.bind(control))
	call_deferred("_refresh_center_pivot", control)

func _refresh_center_pivot(control: Control) -> void:
	if not is_instance_valid(control):
		return
	control.pivot_offset = control.size * 0.5

func _on_control_resized(control: Control) -> void:
	if not is_instance_valid(control):
		return
	control.pivot_offset = control.size * 0.5

func _kill_hover_tween_for(target: CanvasItem) -> void:
	if target == null:
		return
	var key: String = str(target.get_instance_id())
	if _hover_tweens.has(key):
		var t: Tween = _hover_tweens[key]
		if t and t.is_running():
			t.kill()
		_hover_tweens.erase(key)

func _get_button_base_scale(button: Button) -> Vector2:
	var base_scale := Vector2.ONE
	if is_instance_valid(button):
		base_scale = button.scale
		if button.has_meta("ui_base_scale"):
			var v: Variant = button.get_meta("ui_base_scale")
			if v is Vector2:
				base_scale = v
	return base_scale

func _bind_button_fx(button: Button) -> void:
	if not is_instance_valid(button):
		return
	_apply_button_theme(button)
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

func _on_button_mouse_entered(button: Button) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	_on_button_focus_entered(button)

func _on_button_mouse_exited(button: Button) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	_on_button_focus_exited(button)

func _on_button_focus_entered(button: Button) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	_kill_hover_tween_for(button)
	var base_scale := _get_button_base_scale(button)
	var t: Tween = create_tween()
	t.set_trans(Tween.TRANS_CUBIC)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(button, "scale", base_scale * 1.03, 0.12)
	_hover_tweens[str(button.get_instance_id())] = t

func _on_button_focus_exited(button: Button) -> void:
	if not is_instance_valid(button):
		return
	_kill_hover_tween_for(button)
	var base_scale := _get_button_base_scale(button)
	var t: Tween = create_tween()
	t.set_trans(Tween.TRANS_CUBIC)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(button, "scale", base_scale, 0.10)
	_hover_tweens[str(button.get_instance_id())] = t

func _on_button_down(button: Button) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	_kill_hover_tween_for(button)
	var base_scale := _get_button_base_scale(button)
	var t: Tween = create_tween()
	t.set_trans(Tween.TRANS_CUBIC)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(button, "scale", base_scale * 0.98, 0.06)
	_hover_tweens[str(button.get_instance_id())] = t

func _on_button_up(button: Button) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	if button.is_hovered() or button.has_focus():
		_on_button_focus_entered(button)
	else:
		_on_button_focus_exited(button)

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
		_ensure_center_pivot(_main_margin)
	_layout_cached = true

func _play_open_animation() -> void:
	if not is_instance_valid(_ui_root) or not is_instance_valid(_main_margin):
		return
	await get_tree().process_frame
	if not _layout_cached:
		await _cache_layout()
	_kill_ui_tween()
	_closing = false
	_ui_root.modulate = Color(_ui_root_final_modulate.r, _ui_root_final_modulate.g, _ui_root_final_modulate.b, 0.0)
	_main_margin.position = _main_margin_final_position + Vector2(0, 18)
	_main_margin.scale = _main_margin_final_scale * 0.96
	_ui_tween = create_tween()
	_ui_tween.set_trans(Tween.TRANS_CUBIC)
	_ui_tween.set_ease(Tween.EASE_OUT)
	_ui_tween.parallel().tween_property(_ui_root, "modulate", _ui_root_final_modulate, 0.22)
	_ui_tween.parallel().tween_property(_main_margin, "position", _main_margin_final_position, 0.28)
	_ui_tween.parallel().tween_property(_main_margin, "scale", _main_margin_final_scale * 1.01, 0.18)
	_ui_tween.tween_property(_main_margin, "scale", _main_margin_final_scale, 0.12)

func _close_and_do(action: Callable) -> void:
	if _closing:
		return
	_closing = true
	if is_instance_valid(back_button):
		back_button.disabled = true
	if not is_instance_valid(_ui_root) or not is_instance_valid(_main_margin):
		action.call()
		return
	_kill_ui_tween()
	_ui_tween = create_tween()
	_ui_tween.set_trans(Tween.TRANS_CUBIC)
	_ui_tween.set_ease(Tween.EASE_IN)
	_ui_tween.parallel().tween_property(_ui_root, "modulate", Color(_ui_root_final_modulate.r, _ui_root_final_modulate.g, _ui_root_final_modulate.b, 0.0), 0.18)
	_ui_tween.parallel().tween_property(_main_margin, "position", _main_margin_final_position + Vector2(0, 16), 0.20)
	_ui_tween.parallel().tween_property(_main_margin, "scale", _main_margin_final_scale * 0.96, 0.20)
	_ui_tween.finished.connect(func() -> void:
		action.call()
	)

## 初始化UI
func _setup_ui() -> void:
	if title_label:
		title_label.text = "休息处"
	
	if description_label:
		description_label.text = "你找到了一个安静的休息处，可以在这里恢复体力或提升能力。"

## 显示休息选项
func _show_rest_choices() -> void:
	current_state = RestState.CHOOSING
	
	# 清空容器
	_clear_container(choice_container)
	_clear_container(upgrade_selection_container)
	
	# 隐藏升级选择容器
	if upgrade_selection_container:
		upgrade_selection_container.visible = false
	
	if choice_container:
		choice_container.visible = true
	
	# 更新描述
	if description_label:
		description_label.text = "你找到了一个安静的休息处，可以在这里恢复体力或提升能力。"
	
	# 创建选项按钮
	_create_heal_option()
	_create_upgrade_option()

## 创建恢复生命值选项
func _create_heal_option() -> void:
	if not choice_container:
		return
	
	var heal_button = Button.new()
	
	# 计算恢复量
	var heal_percent = 20
	var heal_amount = 0
	if RunManager:
		heal_amount = int(RunManager.max_health * (heal_percent / 100.0))
	
	heal_button.text = "休息恢复 - 恢复 %d%% 生命值（+%d HP）" % [heal_percent, heal_amount]
	heal_button.custom_minimum_size = Vector2(500, 80)
	heal_button.pressed.connect(_on_heal_selected)
	
	# 添加样式
	var heal_label = Label.new()
	heal_label.text = "当前生命值: %d / %d" % [int(RunManager.health) if RunManager else 0, int(RunManager.max_health) if RunManager else 0]
	heal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heal_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	
	choice_container.add_child(heal_button)
	choice_container.add_child(heal_label)
	
	# 添加间隔
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	choice_container.add_child(spacer)

## 创建升级选项
func _create_upgrade_option() -> void:
	if not choice_container:
		return
	
	# 获取已有升级
	_load_owned_upgrades()
	
	var upgrade_button = Button.new()
	
	if owned_upgrades.size() > 0:
		upgrade_button.text = "强化升级 - 选择一个已有的升级进行强化"
		upgrade_button.pressed.connect(_on_upgrade_option_selected)
	else:
		upgrade_button.text = "强化升级 - 没有可强化的升级"
		upgrade_button.disabled = true
	
	upgrade_button.custom_minimum_size = Vector2(500, 80)
	choice_container.add_child(upgrade_button)
	
	# 显示已有升级数量
	var info_label = Label.new()
	info_label.text = "当前拥有 %d 个可强化的升级" % owned_upgrades.size()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	choice_container.add_child(info_label)

## 加载已有升级
func _load_owned_upgrades() -> void:
	owned_upgrades.clear()
	var registry = UpgradeRegistry
	
	# 遍历玩家已有的升级
	for upgrade_id in RunManager.upgrades:
		var current_level = RunManager.upgrades[upgrade_id]
		var upgrade_data = registry.get_upgrade(upgrade_id)
		
		if upgrade_data == null:
			continue
		
		# 检查是否可以继续升级（未达到最大等级）
		if upgrade_data.max_level <= 0 or current_level < upgrade_data.max_level:
			owned_upgrades.append({
				"id": upgrade_id,
				"data": upgrade_data,
				"current_level": current_level
			})

## 选择恢复生命值
func _on_heal_selected() -> void:
	# 恢复20%生命值
	var heal_amount = RunManager.max_health * 0.20
	RunManager.heal(heal_amount)
	
	print("休息处：恢复 %.0f 点生命值" % heal_amount)
	
	# 显示结果
	_show_result("恢复完成！", "恢复了 %.0f 点生命值\n当前生命值: %d / %d" % [heal_amount, int(RunManager.health), int(RunManager.max_health)])

## 选择升级选项
func _on_upgrade_option_selected() -> void:
	current_state = RestState.SELECTING_UPGRADE
	
	# 隐藏选择容器
	if choice_container:
		choice_container.visible = false
	
	# 显示升级选择容器
	if upgrade_selection_container:
		upgrade_selection_container.visible = true
	
	# 更新描述
	if description_label:
		description_label.text = "选择一个升级进行强化（等级+1）："
	
	# 显示可选升级
	_display_upgrade_options()

## 显示可选升级列表
func _display_upgrade_options() -> void:
	_clear_container(upgrade_selection_container)
	
	if not upgrade_selection_container:
		return
	
	# 添加返回按钮
	var back_btn = Button.new()
	back_btn.text = "返回"
	back_btn.custom_minimum_size = Vector2(200, 50)
	back_btn.pressed.connect(_show_rest_choices)
	upgrade_selection_container.add_child(back_btn)
	
	# 添加间隔
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	upgrade_selection_container.add_child(spacer)
	
	# 为每个可升级的升级创建按钮
	for upgrade_info in owned_upgrades:
		_create_upgrade_button(upgrade_info)

## 创建升级按钮
func _create_upgrade_button(upgrade_info: Dictionary) -> void:
	if not upgrade_selection_container:
		return
	
	var upgrade_data: UpgradeData = upgrade_info.data
	var current_level: int = upgrade_info.current_level
	var upgrade_id: String = upgrade_info.id
	
	var button = Button.new()
	button.custom_minimum_size = Vector2(500, 100)
	button.pressed.connect(_on_upgrade_selected.bind(upgrade_id))
	
	# 创建容器
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	button.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)
	
	# 标题行（名称 + 稀有度 + 等级）
	var title_hbox = HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(title_hbox)
	
	# 稀有度标签
	var rarity_label = Label.new()
	rarity_label.text = upgrade_data.get_rarity_stars()
	rarity_label.add_theme_color_override("font_color", upgrade_data.get_rarity_color())
	title_hbox.add_child(rarity_label)
	
	# 名称和等级
	var name_label = Label.new()
	var next_level = current_level + 1
	var max_level_text = ""
	if upgrade_data.max_level > 0:
		max_level_text = " / %d" % upgrade_data.max_level
	
	name_label.text = "%s (Lv.%d → %d%s)" % [upgrade_data.display_name, current_level, next_level, max_level_text]
	name_label.add_theme_color_override("font_color", upgrade_data.get_rarity_color())
	title_hbox.add_child(name_label)
	
	# 描述
	var desc_label = Label.new()
	desc_label.text = upgrade_data.get_formatted_description(current_level)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.x = 450
	vbox.add_child(desc_label)
	
	upgrade_selection_container.add_child(button)

## 选择升级
func _on_upgrade_selected(upgrade_id: String) -> void:
	var upgrade_data = UpgradeRegistry.get_upgrade(upgrade_id)
	if not upgrade_data:
		_complete_rest()
		return
	
	var old_level = RunManager.get_upgrade_level(upgrade_id)
	
	# 升级
	RunManager.add_upgrade(upgrade_id, 1)
	
	var new_level = RunManager.get_upgrade_level(upgrade_id)
	
	print("休息处：强化 %s (Lv.%d → Lv.%d)" % [upgrade_data.display_name, old_level, new_level])
	
	# 显示结果
	_show_result("强化成功！", "%s\nLv.%d → Lv.%d\n%s" % [
		upgrade_data.display_name,
		old_level,
		new_level,
		upgrade_data.get_formatted_description(new_level - 1)
	])

## 显示结果
func _show_result(result_title: String, result_text: String) -> void:
	current_state = RestState.COMPLETED
	
	# 隐藏所有选择容器
	if choice_container:
		choice_container.visible = false
	if upgrade_selection_container:
		upgrade_selection_container.visible = false
	
	# 更新标题和描述
	if title_label:
		title_label.text = result_title
	if description_label:
		description_label.text = result_text
	
	# 显示返回按钮
	if back_button:
		back_button.visible = true
		back_button.text = "返回地图"

## 完成休息
func _complete_rest() -> void:
	emit_signal("rest_completed")
	
	# 返回地图
	_close_and_do(func() -> void:
		GameManager.go_to_map_view()
	)

## 返回按钮点击
func _on_back_pressed() -> void:
	_complete_rest()

## 清空容器
func _clear_container(container: Control) -> void:
	if not container:
		return
	
	for child in container.get_children():
		child.queue_free()

## UpgradeRegistry 为 Autoload，直接使用全局名即可
