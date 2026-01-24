extends Node2D

## 商店界面脚本
## 功能：
## - 随机提供 3 个升级可购买
## - 提供 1 个圣遗物自选包（打开后进入圣遗物选择界面）
## - 使用 RunManager 的摩拉（gold）作为货币
## - 升级价格随稀有度变化，自选包价格 = 当前层数 * 50

signal upgrade_purchased(upgrade_id: String, price: int)
signal artifact_pack_purchased(price: int)

@onready var _ui_root: Control = $CanvasLayer/UIRoot
@onready var _main_margin: MarginContainer = $CanvasLayer/UIRoot/MainMargin
@onready var _upgrades_panel: PanelContainer = $CanvasLayer/UIRoot/MainMargin/MainVBox/BodyHBox/UpgradesPanel
@onready var _artifact_pack_panel: PanelContainer = $CanvasLayer/UIRoot/MainMargin/MainVBox/BodyHBox/ArtifactPackPanel

@onready var title_label: Label = $CanvasLayer/UIRoot/MainMargin/MainVBox/HeaderHBox/TitleLabel
@onready var gold_label: Label = $CanvasLayer/UIRoot/MainMargin/MainVBox/HeaderHBox/GoldLabel

@onready var upgrade_container: VBoxContainer = $CanvasLayer/UIRoot/MainMargin/MainVBox/BodyHBox/UpgradesPanel/UpgradesMargin/UpgradesVBox/UpgradesScroll/UpgradeContainer

@onready var artifact_title_label: Label = $CanvasLayer/UIRoot/MainMargin/MainVBox/BodyHBox/ArtifactPackPanel/ArtifactPackMargin/ArtifactPackVBox/ArtifactTitleLabel
@onready var artifact_desc_label: Label = $CanvasLayer/UIRoot/MainMargin/MainVBox/BodyHBox/ArtifactPackPanel/ArtifactPackMargin/ArtifactPackVBox/ArtifactDescLabel
@onready var artifact_price_label: Label = $CanvasLayer/UIRoot/MainMargin/MainVBox/BodyHBox/ArtifactPackPanel/ArtifactPackMargin/ArtifactPackVBox/ArtifactPriceLabel
@onready var artifact_pack_button: Button = $CanvasLayer/UIRoot/MainMargin/MainVBox/BodyHBox/ArtifactPackPanel/ArtifactPackMargin/ArtifactPackVBox/ArtifactPackButton

@onready var back_button: Button = $CanvasLayer/UIRoot/MainMargin/MainVBox/FooterHBox/BackButton

var _ui_tween: Tween = null
var _hover_tweens: Dictionary = {}
var _closing: bool = false

var _ui_root_final_modulate: Color = Color(1, 1, 1, 1)
var _main_margin_final_scale: Vector2 = Vector2.ONE
var _main_margin_final_position: Vector2 = Vector2.ZERO
var _layout_cached: bool = false

var _panel_style: StyleBoxFlat = null
var _button_style_normal: StyleBoxFlat = null
var _button_style_hover: StyleBoxFlat = null
var _button_style_pressed: StyleBoxFlat = null
var _button_style_disabled: StyleBoxFlat = null

var _card_style_normal: StyleBoxFlat = null
var _card_style_hover: StyleBoxFlat = null
var _card_style_disabled: StyleBoxFlat = null

## 当前可购买的升级列表（UpgradeData）
var available_upgrades: Array[UpgradeData] = []

## 已购买的升级ID
var purchased_upgrades: Dictionary = {}

## 圣遗物自选包是否已购买
var artifact_pack_already_purchased: bool = false

## 商店中升级数量
@export var upgrade_count: int = 3

func _refresh_shop_ui() -> void:
	_update_gold_label()
	_update_artifact_pack_button_text()
	_display_upgrades()

func _ready() -> void:
	_process_ui_style()
	_setup_button_fx()
	call_deferred("_cache_layout")
	call_deferred("_play_open_animation")

	if title_label:
		title_label.text = "商店"
	
	_update_gold_label()
	_generate_upgrade_options()
	_display_upgrades()
	
	if artifact_pack_button:
		_update_artifact_pack_button_text()
		if not artifact_pack_button.pressed.is_connected(_on_artifact_pack_pressed):
			artifact_pack_button.pressed.connect(_on_artifact_pack_pressed)
	
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

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

	if is_instance_valid(_upgrades_panel):
		_upgrades_panel.add_theme_stylebox_override("panel", _panel_style)
		_upgrades_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(_artifact_pack_panel):
		_artifact_pack_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	if title_label:
		title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65, 1.0))
	if gold_label:
		gold_label.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96, 1.0))
	if artifact_title_label:
		artifact_title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65, 1.0))
	if artifact_desc_label:
		artifact_desc_label.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96, 1.0))
	if artifact_price_label:
		artifact_price_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))

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

	if _card_style_normal == null:
		_card_style_normal = StyleBoxFlat.new()
		_card_style_normal.bg_color = Color(0.12, 0.14, 0.18, 1.0)
		_card_style_normal.border_width_left = 4
		_card_style_normal.border_width_top = 4
		_card_style_normal.border_width_right = 4
		_card_style_normal.border_width_bottom = 4
		_card_style_normal.border_color = Color(0.86, 0.88, 0.92, 0.85)
		_card_style_normal.shadow_color = Color(0, 0, 0, 0.45)
		_card_style_normal.shadow_size = 8
		_card_style_normal.shadow_offset = Vector2(0, 6)
		_card_style_normal.content_margin_left = 0
		_card_style_normal.content_margin_top = 0
		_card_style_normal.content_margin_right = 0
		_card_style_normal.content_margin_bottom = 0

		_card_style_hover = _card_style_normal.duplicate()
		_card_style_hover.bg_color = Color(0.14, 0.16, 0.22, 1.0)
		_card_style_hover.border_color = Color(1.0, 0.96, 0.72, 0.90)

		_card_style_disabled = _card_style_normal.duplicate()
		_card_style_disabled.bg_color = Color(0.10, 0.11, 0.13, 1.0)
		_card_style_disabled.border_color = Color(0.55, 0.57, 0.62, 0.70)

	# 右侧自选包面板用“商品卡片”风格（更像商店商品）
	if is_instance_valid(_artifact_pack_panel):
		_artifact_pack_panel.add_theme_stylebox_override("panel", _card_style_normal)
		_bind_card_fx(_artifact_pack_panel, false)

	_apply_button_theme(artifact_pack_button)
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
	if not button.has_meta("ui_base_modulate"):
		button.set_meta("ui_base_modulate", button.modulate)

func _ensure_center_pivot(control: Control) -> void:
	if not is_instance_valid(control):
		return
	# 让scale以控件中心为原点，而不是左上角
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

func _setup_button_fx() -> void:
	_bind_button_fx(artifact_pack_button)
	_bind_button_fx(back_button)

func _kill_hover_tween_for(target: CanvasItem) -> void:
	if target == null:
		return
	var key: String = str(target.get_instance_id())
	if _hover_tweens.has(key):
		var t: Tween = _hover_tweens[key]
		if t and t.is_running():
			t.kill()
		_hover_tweens.erase(key)

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

func _bind_card_fx(card: Control, disabled: bool) -> void:
	if not is_instance_valid(card):
		return
	_ensure_center_pivot(card)
	if not card.has_meta("ui_base_scale"):
		card.set_meta("ui_base_scale", card.scale)
	# PanelContainer 作为卡片时：鼠标进入/离开做轻微缩放 + 换边框色
	if card is PanelContainer:
		var panel := card as PanelContainer
		panel.add_theme_stylebox_override("panel", _card_style_disabled if disabled else _card_style_normal)

	if disabled:
		return
	if not card.mouse_entered.is_connected(_on_card_mouse_entered.bind(card)):
		card.mouse_entered.connect(_on_card_mouse_entered.bind(card))
	if not card.mouse_exited.is_connected(_on_card_mouse_exited.bind(card)):
		card.mouse_exited.connect(_on_card_mouse_exited.bind(card))

func _get_control_base_scale(control: Control) -> Vector2:
	var base_scale := Vector2.ONE
	if is_instance_valid(control):
		base_scale = control.scale
		if control.has_meta("ui_base_scale"):
			var v: Variant = control.get_meta("ui_base_scale")
			if v is Vector2:
				base_scale = v
	return base_scale

func _on_card_mouse_entered(card: Control) -> void:
	if not is_instance_valid(card):
		return
	_kill_hover_tween_for(card)
	var base_scale := _get_control_base_scale(card)
	if card is PanelContainer:
		(card as PanelContainer).add_theme_stylebox_override("panel", _card_style_hover)
	var t: Tween = create_tween()
	t.set_trans(Tween.TRANS_CUBIC)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(card, "scale", base_scale * 1.015, 0.12)
	_hover_tweens[str(card.get_instance_id())] = t

func _on_card_mouse_exited(card: Control) -> void:
	if not is_instance_valid(card):
		return
	_kill_hover_tween_for(card)
	var base_scale := _get_control_base_scale(card)
	if card is PanelContainer:
		(card as PanelContainer).add_theme_stylebox_override("panel", _card_style_normal)
	var t: Tween = create_tween()
	t.set_trans(Tween.TRANS_CUBIC)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(card, "scale", base_scale, 0.10)
	_hover_tweens[str(card.get_instance_id())] = t

func _get_button_base_scale(button: Button) -> Vector2:
	var base_scale := Vector2.ONE
	if is_instance_valid(button):
		base_scale = button.scale
		if button.has_meta("ui_base_scale"):
			var v: Variant = button.get_meta("ui_base_scale")
			if v is Vector2:
				base_scale = v
	return base_scale

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
	# 鼠标仍在按钮上时回到hover态，否则回到基础态
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
	if is_instance_valid(artifact_pack_button):
		artifact_pack_button.disabled = true

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

## 生成升级选项（从 UpgradeRegistry 中随机抽取）
func _generate_upgrade_options() -> void:
	available_upgrades.clear()
	
	var registry = UpgradeRegistry
	
	var character_id := ""
	var current_floor: int = int(RunManager.current_floor)
	var current_upgrades: Dictionary = RunManager.upgrades
	
	if RunManager.current_character:
		character_id = RunManager.current_character.id
	
	var picked: Array = registry.pick_random_upgrades(
		character_id,
		current_upgrades,
		current_floor,
		upgrade_count
	)
	
	for u in picked:
		if u is UpgradeData:
			available_upgrades.append(u)
	
	if available_upgrades.is_empty():
		push_warning("Shop: 没有可用的升级选项")


## 显示升级列表
func _display_upgrades() -> void:
	if not upgrade_container:
		return
	
	# 清空容器
	for child in upgrade_container.get_children():
		child.queue_free()
	
	for upgrade in available_upgrades:
		_create_upgrade_button(upgrade)


## 根据稀有度计算升级价格
## 可以根据实际体验再微调数值
func _get_upgrade_price(upgrade: UpgradeData) -> int:
	match upgrade.rarity:
		UpgradeData.Rarity.COMMON:
			return 50
		UpgradeData.Rarity.UNCOMMON:
			return 100
		UpgradeData.Rarity.RARE:
			return 150
		UpgradeData.Rarity.EPIC:
			return 200
		UpgradeData.Rarity.LEGENDARY:
			return 300
		_:
			return 100


## 创建单个升级购买按钮
func _create_upgrade_button(upgrade: UpgradeData) -> void:
	var price: int = _get_upgrade_price(upgrade)
	var can_afford: bool = _can_afford(price)
	var already_purchased: bool = purchased_upgrades.has(upgrade.id)
	var disabled: bool = already_purchased or (not can_afford)

	# 商品卡片（非“选项按钮”）
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 148)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	_bind_card_fx(card, disabled)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)

	var right: VBoxContainer = VBoxContainer.new()
	right.custom_minimum_size = Vector2(160, 0)
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)

	# 左侧：信息
	var title_hbox: HBoxContainer = HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 10)
	left.add_child(title_hbox)
	
	var rarity_label: Label = Label.new()
	rarity_label.text = upgrade.get_rarity_stars()
	rarity_label.add_theme_color_override("font_color", upgrade.get_rarity_color())
	title_hbox.add_child(rarity_label)
	
	var name_label: Label = Label.new()
	var current_level: int = int(RunManager.get_upgrade_level(upgrade.id))
	
	if current_level > 0:
		name_label.text = "%s (Lv.%d → %d)" % [upgrade.display_name, current_level, current_level + 1]
	else:
		name_label.text = upgrade.display_name
	name_label.add_theme_color_override("font_color", upgrade.get_rarity_color())
	title_hbox.add_child(name_label)
	
	if upgrade.max_level > 0:
		var max_level_label: Label = Label.new()
		max_level_label.text = "/ %d" % upgrade.max_level
		max_level_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		title_hbox.add_child(max_level_label)
	
	# 描述
	var desc_label: Label = Label.new()
	desc_label.text = upgrade.get_formatted_description(current_level)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.x = 400
	left.add_child(desc_label)
	
	# 标签
	if upgrade.tags.size() > 0:
		var tags_label: Label = Label.new()
		tags_label.text = "标签: " + ", ".join(upgrade.tags)
		tags_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		tags_label.add_theme_font_size_override("font_size", 12)
		left.add_child(tags_label)

	# 右侧：价格 + 购买按钮
	var price_label: Label = Label.new()
	price_label.text = "%d" % price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 22)
	price_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
	right.add_child(price_label)

	var price_unit: Label = Label.new()
	price_unit.text = "摩拉"
	price_unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_unit.add_theme_font_size_override("font_size", 14)
	price_unit.add_theme_color_override("font_color", Color(0.80, 0.84, 0.90, 1.0))
	right.add_child(price_unit)

	var buy_button: Button = Button.new()
	buy_button.text = "购买"
	buy_button.custom_minimum_size = Vector2(140, 44)
	_apply_button_theme(buy_button)
	_ensure_center_pivot(buy_button)
	if already_purchased:
		buy_button.disabled = true
		buy_button.text = "已购买"
		buy_button.modulate = Color(0.75, 0.75, 0.78, 1.0)
	elif not can_afford:
		buy_button.disabled = true
		buy_button.text = "不足"
	else:
		_bind_button_fx(buy_button)
	buy_button.pressed.connect(_on_upgrade_buy_pressed.bind(upgrade, price, buy_button, card))
	right.add_child(buy_button)

	upgrade_container.add_child(card)


## 处理升级购买
func _on_upgrade_buy_pressed(upgrade: UpgradeData, price: int, buy_button: Button, card: PanelContainer) -> void:
	if purchased_upgrades.has(upgrade.id):
		return
	
	# 尝试扣除摩拉
	if not RunManager.spend_gold(price):
		print("摩拉不足，无法购买升级：", upgrade.display_name)
		return
	
	# 记录购买并应用升级
	purchased_upgrades[upgrade.id] = true
	RunManager.add_upgrade(upgrade.id, 1)
	_update_gold_label()
	
	# 按钮灰掉，避免重复购买
	if is_instance_valid(buy_button):
		buy_button.disabled = true
		buy_button.text = "已购买"
		buy_button.modulate = Color(0.75, 0.75, 0.78, 1.0)
	if is_instance_valid(card):
		card.scale = Vector2.ONE
		card.modulate = Color(0.70, 0.70, 0.72, 1.0)
		if card is PanelContainer:
			(card as PanelContainer).add_theme_stylebox_override("panel", _card_style_disabled)
	
	emit_signal("upgrade_purchased", upgrade.id, price)
	print("购买升级：", upgrade.display_name, " 花费：", price, "摩拉")
	# 刷新其它商品（金币变化会影响可购买状态）
	call_deferred("_refresh_shop_ui")


## 更新圣遗物自选包按钮文本
func _update_artifact_pack_button_text() -> void:
	if not artifact_pack_button:
		return
	
	# 最少按第1层计价，避免 0 楼层出现 0 价格
	var floor_num: int = maxi(1, RunManager.current_floor)
	
	var price: int = floor_num * 50
	if artifact_pack_already_purchased:
		if artifact_price_label:
			artifact_price_label.text = "价格：%d 摩拉" % price
		artifact_pack_button.text = "已购买"
		artifact_pack_button.disabled = true
	else:
		if artifact_price_label:
			artifact_price_label.text = "价格：%d 摩拉" % price
		artifact_pack_button.text = "购买"
		artifact_pack_button.disabled = not _can_afford(price)

	# 同步右侧卡片的可交互状态/样式
	if is_instance_valid(_artifact_pack_panel):
		_bind_card_fx(_artifact_pack_panel, artifact_pack_button.disabled)


## 购买圣遗物自选包
func _on_artifact_pack_pressed() -> void:
	if artifact_pack_already_purchased:
		return
	
	var floor_num: int = maxi(1, RunManager.current_floor)
	var price: int = floor_num * 50
	
	if not RunManager.spend_gold(price):
		print("摩拉不足，无法购买圣遗物自选包")
		return
	
	artifact_pack_already_purchased = true
	_update_gold_label()
	_update_artifact_pack_button_text()
	emit_signal("artifact_pack_purchased", price)
	print("购买圣遗物自选包，花费：", price, "摩拉")
	
	# 打开圣遗物选择界面（选择完会自动返回地图）
	if GameManager:
		_close_and_do(func() -> void:
			GameManager.show_artifact_selection()
		)


## 返回地图
func _on_back_pressed() -> void:
	if GameManager:
		_close_and_do(func() -> void:
			GameManager.go_to_map_view()
		)


## 更新摩拉显示
func _update_gold_label() -> void:
	if not gold_label:
		return
	
	gold_label.text = "当前摩拉：%d" % RunManager.gold


## 判断是否有足够摩拉
func _can_afford(price: int) -> bool:
	return RunManager.gold >= price
