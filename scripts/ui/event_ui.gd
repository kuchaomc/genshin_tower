extends Node2D

## 奇遇事件界面脚本
## 功能：
## - 从EventRegistry随机选取并显示事件
## - 根据事件类型显示不同的UI（奖励、选择、战斗等）
## - 处理事件结果并应用奖励
## - 支持多种事件类型和交互方式

signal event_completed(event_id: String)
signal reward_given(reward_type: EventData.RewardType, reward_value: Variant)

const DUPLICATE_ARTIFACT_TO_GOLD: int = 500

@onready var _ui_root: Control = $CanvasLayer/UIRoot
@onready var _main_margin: MarginContainer = $CanvasLayer/UIRoot/MainMargin
@onready var _event_panel: PanelContainer = $CanvasLayer/UIRoot/MainMargin/MainVBox/EventPanel

@onready var title_label: Label = $CanvasLayer/UIRoot/MainMargin/MainVBox/HeaderHBox/TitleLabel
@onready var gold_label: Label = $CanvasLayer/UIRoot/MainMargin/MainVBox/HeaderHBox/GoldLabel
@onready var description_label: Label = $CanvasLayer/UIRoot/MainMargin/MainVBox/EventPanel/EventMargin/EventVBox/DescriptionLabel
@onready var content_container: VBoxContainer = $CanvasLayer/UIRoot/MainMargin/MainVBox/EventPanel/EventMargin/EventVBox/ContentContainer
@onready var choice_container: VBoxContainer = $CanvasLayer/UIRoot/MainMargin/MainVBox/EventPanel/EventMargin/EventVBox/ChoiceContainer

var _ui_tween: Tween = null
var _hover_tweens: Dictionary = {}
var _closing: bool = false
var _layout_cached: bool = false

var _ui_root_final_modulate: Color = Color(1, 1, 1, 1)
var _main_margin_final_scale: Vector2 = Vector2.ONE
var _main_margin_final_position: Vector2 = Vector2.ZERO
var _main_margin_final_modulate: Color = Color(1, 1, 1, 1)

var _panel_style: StyleBoxFlat = null
var _button_style_normal: StyleBoxFlat = null
var _button_style_hover: StyleBoxFlat = null
var _button_style_pressed: StyleBoxFlat = null
var _button_style_disabled: StyleBoxFlat = null

## 当前显示的事件
var current_event: EventData = null

## 当前事件ID
var current_event_id: String = ""

func _ready() -> void:
	_process_ui_style()
	_setup_container_auto_style()
	call_deferred("_cache_layout")
	call_deferred("_play_open_animation")
	_update_gold_label()
	
	# 获取随机事件
	_load_random_event()
	
	# 显示事件内容
	_display_event()

func _setup_container_auto_style() -> void:
	if is_instance_valid(content_container) and not content_container.child_entered_tree.is_connected(_on_container_child_entered):
		content_container.child_entered_tree.connect(_on_container_child_entered)
	if is_instance_valid(choice_container) and not choice_container.child_entered_tree.is_connected(_on_container_child_entered):
		choice_container.child_entered_tree.connect(_on_container_child_entered)

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

	if is_instance_valid(_event_panel):
		_event_panel.add_theme_stylebox_override("panel", _panel_style)
		_event_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		_ensure_center_pivot(_event_panel)

	if title_label:
		title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65, 1.0))
	if description_label:
		description_label.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96, 1.0))
	if gold_label:
		gold_label.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96, 1.0))

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
		_main_margin_final_modulate = _main_margin.modulate
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
	_ui_root.modulate = _ui_root_final_modulate
	_main_margin.position = _main_margin_final_position + Vector2(0, 18)
	_main_margin.scale = _main_margin_final_scale * 0.96
	_main_margin.modulate = Color(_main_margin_final_modulate.r, _main_margin_final_modulate.g, _main_margin_final_modulate.b, 0.0)
	_ui_tween = create_tween()
	_ui_tween.set_trans(Tween.TRANS_CUBIC)
	_ui_tween.set_ease(Tween.EASE_OUT)
	_ui_tween.parallel().tween_property(_main_margin, "modulate", _main_margin_final_modulate, 0.22)
	_ui_tween.parallel().tween_property(_main_margin, "position", _main_margin_final_position, 0.28)
	_ui_tween.parallel().tween_property(_main_margin, "scale", _main_margin_final_scale * 1.01, 0.18)
	_ui_tween.tween_property(_main_margin, "scale", _main_margin_final_scale, 0.12)

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

func _update_gold_label() -> void:
	if not is_instance_valid(gold_label):
		return
	if RunManager:
		gold_label.text = "当前摩拉：%d" % int(RunManager.gold)
	else:
		gold_label.text = "当前摩拉：0"

## 加载随机事件
func _load_random_event() -> void:
	var registry = EventRegistry
	
	var character_id := ""
	var current_floor := 0
	
	if RunManager.current_character:
		character_id = RunManager.current_character.id
	current_floor = RunManager.current_floor
	
	# 开发者选项可强制指定下一次事件：优先消费该ID
	var forced_id := ""
	if registry and registry.has_method("consume_forced_event_id"):
		forced_id = str(registry.consume_forced_event_id())
	if not forced_id.is_empty() and registry and registry.has_method("get_event"):
		var forced_event := registry.get_event(forced_id)
		if forced_event:
			current_event = forced_event
		else:
			current_event = registry.pick_random_event(character_id, current_floor)
	else:
		current_event = registry.pick_random_event(character_id, current_floor)
	
	if current_event:
		current_event_id = current_event.id
		print("EventUI: 加载事件 '%s' (%s)" % [current_event.display_name, current_event.id])
	else:
		push_error("EventUI: 无法加载事件")
		# 如果无法加载事件，显示默认消息
		current_event = null

## 显示事件内容
func _display_event() -> void:
	if not current_event:
		_show_error_message()
		return
	_update_gold_label()
	
	# 设置标题和描述
	if title_label:
		title_label.text = current_event.display_name
		title_label.add_theme_color_override("font_color", current_event.get_rarity_color())
	
	if description_label:
		var context = {
			"floor": RunManager.current_floor,
			"gold": RunManager.gold,
			"health": RunManager.health
		}
		description_label.text = current_event.get_formatted_description(context)
	
	# 清空内容容器
	_clear_content()
	
	# 根据事件类型显示不同的UI
	match current_event.event_type:
		EventData.EventType.REWARD:
			_show_reward_event()
		EventData.EventType.CHOICE:
			_show_choice_event()
		EventData.EventType.BATTLE:
			_show_battle_event()
		EventData.EventType.SHOP:
			_show_shop_event()
		EventData.EventType.REST:
			_show_rest_event()
		EventData.EventType.UPGRADE:
			_show_upgrade_event()
		EventData.EventType.RANDOM:
			_show_random_event()
		_:
			_show_default_event()

## 清空内容容器
func _clear_content() -> void:
	if content_container:
		for child in content_container.get_children():
			child.queue_free()
	
	if choice_container:
		for child in choice_container.get_children():
			child.queue_free()

## 显示奖励事件
func _show_reward_event() -> void:
	if not content_container:
		return
	
	var reward_label = Label.new()
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# 如果是圣遗物奖励，预先抽取并显示具体信息
	if current_event.reward_type == EventData.RewardType.ARTIFACT:
		var artifact_result = RunManager.get_random_artifact_with_slot_from_character_set()
		if artifact_result.is_empty():
			reward_label.text = "获得圣遗物！（但没有可用的圣遗物套装）"
			reward_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.9))
			content_container.add_child(reward_label)
			var confirm_button = Button.new()
			confirm_button.text = "确认"
			confirm_button.custom_minimum_size = Vector2(200, 50)
			confirm_button.pressed.connect(_complete_event)
			content_container.add_child(confirm_button)
		else:
			var artifact: ArtifactData = artifact_result.artifact
			var slot: ArtifactSlot.SlotType = artifact_result.slot
			var slot_name = ArtifactSlot.get_slot_name(slot)
			var preview_text := "获得圣遗物！\n%s（%s）\n%s" % [artifact.name, slot_name, artifact.get_bonus_summary(0)]
			if RunManager and RunManager.has_artifact_in_inventory(artifact.name, slot):
				preview_text += "\n\n当前槽位已有，将转化为%d摩拉" % DUPLICATE_ARTIFACT_TO_GOLD
			reward_label.text = preview_text
			reward_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.9))
			content_container.add_child(reward_label)
			var confirm_button = Button.new()
			confirm_button.text = "获得奖励"
			confirm_button.custom_minimum_size = Vector2(200, 50)
			# 直接使用已抽取的圣遗物
			confirm_button.pressed.connect(func(): _give_specific_artifact(artifact, slot); _complete_event())
			content_container.add_child(confirm_button)
	else:
		reward_label.text = _get_reward_preview_text(current_event)
		reward_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		content_container.add_child(reward_label)
		
		# 自动应用奖励
		var confirm_button = Button.new()
		confirm_button.text = "获得奖励"
		confirm_button.custom_minimum_size = Vector2(200, 50)
		confirm_button.pressed.connect(_on_reward_confirmed)
		content_container.add_child(confirm_button)

## 显示选择事件
func _show_choice_event() -> void:
	if not choice_container or not current_event.choices:
		return
	
	for i in range(current_event.choices.size()):
		var choice = current_event.choices[i]
		var choice_button = Button.new()
		choice_button.text = choice.get("text", "选择 %d" % (i + 1))
		choice_button.custom_minimum_size = Vector2(400, 60)
		choice_button.pressed.connect(_on_choice_selected.bind(i))
		choice_container.add_child(choice_button)

## 显示战斗事件
func _show_battle_event() -> void:
	if not content_container:
		return
	
	var battle_label = Label.new()
	battle_label.text = "准备战斗！"
	battle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(battle_label)
	
	var battle_button = Button.new()
	battle_button.text = "开始战斗"
	battle_button.custom_minimum_size = Vector2(200, 50)
	battle_button.pressed.connect(_on_battle_started)
	content_container.add_child(battle_button)

## 显示商店事件
func _show_shop_event() -> void:
	if not content_container:
		return
	
	# 古董店：出售“全套满级圣遗物”（当前角色专属），售价1000，仅限一次（one_time_only 由 EventRegistry 控制）
	if current_event_id == "antique_shop":
		var shop_label = Label.new()
		shop_label.text = "古董店老板拿出压箱底的藏品。"
		shop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content_container.add_child(shop_label)
		
		var buy_button = Button.new()
		buy_button.text = "购买（1000摩拉）"
		buy_button.custom_minimum_size = Vector2(240, 50)
		buy_button.pressed.connect(_on_antique_shop_buy_pressed)
		content_container.add_child(buy_button)
		
		var leave_button = Button.new()
		leave_button.text = "离开"
		leave_button.custom_minimum_size = Vector2(200, 50)
		leave_button.pressed.connect(_complete_event)
		content_container.add_child(leave_button)
		return
	
	var shop_label = Label.new()
	shop_label.text = "特殊商店（功能待实现）"
	shop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(shop_label)
	
	var leave_button = Button.new()
	leave_button.text = "离开"
	leave_button.custom_minimum_size = Vector2(200, 50)
	leave_button.pressed.connect(_complete_event)
	content_container.add_child(leave_button)

## 显示休息事件
func _show_rest_event() -> void:
	if not content_container:
		return
	
	var rest_label = Label.new()
	rest_label.text = "你找到了一个休息的地方。"
	rest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(rest_label)
	
	var rest_button = Button.new()
	rest_button.text = "休息"
	rest_button.custom_minimum_size = Vector2(200, 50)
	rest_button.pressed.connect(_on_rest_confirmed)
	content_container.add_child(rest_button)
	
	var skip_button = Button.new()
	skip_button.text = "不休息"
	skip_button.custom_minimum_size = Vector2(200, 50)
	skip_button.pressed.connect(_on_rest_skipped)
	content_container.add_child(skip_button)

## 显示升级事件
func _show_upgrade_event() -> void:
	if not content_container:
		return
	
	var upgrade_label = Label.new()
	upgrade_label.text = "你获得了升级奖励！"
	upgrade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(upgrade_label)
	
	var upgrade_button = Button.new()
	upgrade_button.text = "获得升级"
	upgrade_button.custom_minimum_size = Vector2(200, 50)
	upgrade_button.pressed.connect(_on_upgrade_reward_confirmed)
	content_container.add_child(upgrade_button)

## 显示随机事件
func _show_random_event() -> void:
	if not content_container:
		return
	
	# 根据事件ID处理特定的随机事件
	if current_event_id == "weather_change":
		_show_weather_change_event()
	elif current_event_id == "fate_dice":
		_show_fate_dice_event()
	else:
		# 默认随机选择一种类型
		var rng: RandomNumberGenerator = null
		if RunManager:
			rng = RunManager.get_rng() as RandomNumberGenerator
		if not rng:
			push_warning("EventUI: RunManager 不可用，创建临时 RNG")
			rng = RandomNumberGenerator.new()
			rng.randomize()
		var random_type: int = rng.randi_range(0, 2)
		match random_type:
			0:
				_show_reward_event()
			1:
				_show_choice_event()
			_:
				_show_default_event()

## 显示天气变化事件
func _show_weather_change_event() -> void:
	if not content_container:
		return
	_clear_content()
	
	var rng: RandomNumberGenerator = null
	if RunManager:
		rng = RunManager.get_rng() as RandomNumberGenerator
	if not rng:
		push_warning("EventUI: RunManager 不可用，创建临时 RNG")
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var random: float = rng.randf()
	var result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var confirm_button = Button.new()
	confirm_button.text = "确认"
	confirm_button.custom_minimum_size = Vector2(200, 50)
	confirm_button.pressed.connect(_complete_event)
	
	if random < 0.2:
		var dmg: float = 0.0
		if RunManager:
			dmg = RunManager.max_health * 0.10
			RunManager.take_damage(dmg)
		result_label.text = "暴雨导致滑倒，生命值-%d（-10%%）\n当前生命值: %d/%d" % [int(round(dmg)), int(RunManager.health) if RunManager else 0, int(RunManager.max_health) if RunManager else 0]
		result_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		content_container.add_child(result_label)
		content_container.add_child(confirm_button)
	elif random < 0.5:
		var heal_amount: float = 0.0
		if RunManager:
			heal_amount = RunManager.max_health * 0.05
			RunManager.heal(heal_amount)
		result_label.text = "微风拂面，生命值+%d（+5%%）\n当前生命值: %d/%d" % [int(round(heal_amount)), int(RunManager.health) if RunManager else 0, int(RunManager.max_health) if RunManager else 0]
		result_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		content_container.add_child(result_label)
		content_container.add_child(confirm_button)
	else:
		result_label.text = "天气变化没有带来任何影响\n当前生命值: %d/%d" % [int(RunManager.health) if RunManager else 0, int(RunManager.max_health) if RunManager else 0]
		result_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		content_container.add_child(result_label)
		content_container.add_child(confirm_button)

## 显示命运的骰子事件
func _show_fate_dice_event() -> void:
	if not content_container:
		return
	
	_clear_content()
	var pre_label := Label.new()
	pre_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pre_label.text = "点击开始投掷骰子"
	content_container.add_child(pre_label)
	var roll_button := Button.new()
	roll_button.text = "开始投掷"
	roll_button.custom_minimum_size = Vector2(200, 50)
	roll_button.pressed.connect(func() -> void: _show_fate_dice_roll_result())
	content_container.add_child(roll_button)


func _show_fate_dice_roll_result() -> void:
	if not content_container:
		return
	_clear_content()
	
	var rng: RandomNumberGenerator = null
	if RunManager:
		rng = RunManager.get_rng() as RandomNumberGenerator
	if not rng:
		push_warning("EventUI: RunManager 不可用，创建临时 RNG")
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var random: float = rng.randf()
	var result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	if random < 0.1:
		# 10%概率：获得圣遗物
		# 先抽取圣遗物以显示具体名称
		var artifact_result = RunManager.get_random_artifact_with_slot_from_character_set() if RunManager else {}
		if artifact_result.is_empty():
			result_label.text = "获得圣遗物！（但没有可用的圣遗物套装）"
			result_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.9))
			var confirm_button = Button.new()
			confirm_button.text = "确认"
			confirm_button.custom_minimum_size = Vector2(200, 50)
			confirm_button.pressed.connect(_complete_event)
			content_container.add_child(result_label)
			content_container.add_child(confirm_button)
		else:
			var artifact: ArtifactData = artifact_result.artifact
			var slot: ArtifactSlot.SlotType = artifact_result.slot
			var slot_name = ArtifactSlot.get_slot_name(slot)
			var preview_text := "获得圣遗物！\n%s（%s）\n%s" % [artifact.name, slot_name, artifact.get_bonus_summary(0)]
			if RunManager and RunManager.has_artifact_in_inventory(artifact.name, slot):
				preview_text += "\n\n当前槽位已有，将转化为%d摩拉" % DUPLICATE_ARTIFACT_TO_GOLD
			result_label.text = preview_text
			result_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.9))
			var confirm_button = Button.new()
			confirm_button.text = "确认"
			confirm_button.custom_minimum_size = Vector2(200, 50)
			# 直接使用已抽取的圣遗物，而不是再随机一次
			confirm_button.pressed.connect(func(): _give_specific_artifact(artifact, slot); _complete_event())
			content_container.add_child(result_label)
			content_container.add_child(confirm_button)
	elif random < 0.3:
		# 20%概率：触发战斗
		result_label.text = "触发了战斗！"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		var battle_button = Button.new()
		battle_button.text = "开始战斗"
		battle_button.custom_minimum_size = Vector2(200, 50)
		battle_button.pressed.connect(_on_battle_started)
		content_container.add_child(result_label)
		content_container.add_child(battle_button)
	elif random < 0.6:
		# 30%概率：获得500摩拉
		result_label.text = "获得500摩拉！"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		var confirm_button = Button.new()
		confirm_button.text = "确认"
		confirm_button.custom_minimum_size = Vector2(200, 50)
		confirm_button.pressed.connect(func(): _apply_reward(EventData.RewardType.GOLD, 500, current_event); _complete_event())
		content_container.add_child(result_label)
		content_container.add_child(confirm_button)
	else:
		# 40%概率：生命值恢复30%
		result_label.text = "生命值恢复30%！"
		result_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		var confirm_button = Button.new()
		confirm_button.text = "确认"
		confirm_button.custom_minimum_size = Vector2(200, 50)
		confirm_button.pressed.connect(func(): _apply_reward(EventData.RewardType.HEALTH, -30, current_event); _complete_event())
		content_container.add_child(result_label)
		content_container.add_child(confirm_button)

## 显示默认事件
func _show_default_event() -> void:
	if not content_container:
		return
	
	var default_label = Label.new()
	default_label.text = "这是一个神秘的事件..."
	default_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(default_label)

## 显示错误消息
func _show_error_message() -> void:
	if title_label:
		title_label.text = "错误"
	if description_label:
		description_label.text = "无法加载事件"

# ========== 事件处理 ==========

## 确认奖励
func _on_reward_confirmed() -> void:
	if not current_event:
		return
	
	var lines: Array[String] = _apply_reward(current_event.reward_type, current_event.reward_value, current_event)
	_show_reward_result(lines)

## 选择选项
func _on_choice_selected(choice_index: int) -> void:
	if not current_event or choice_index < 0 or choice_index >= current_event.choices.size():
		return
	
	var choice = current_event.choices[choice_index]
	
	# 检查是否需要支付成本
	if choice.has("cost") and choice.cost > 0:
		if not RunManager.spend_gold(choice.cost):
			_show_event_warning("摩拉不足，无法选择此选项")
			return
		_update_gold_label()
	
	# 应用奖励
	if choice.has("reward_type") and choice.reward_type != null:
		var reward_type = choice.get("reward_type")
		var reward_value = choice.get("reward_value")
		
		# 检查是否是战斗选项
		if choice.has("is_battle") and choice.is_battle:
			# 触发战斗
			_mark_event_triggered()
			if GameManager:
				_close_and_do(func() -> void:
					GameManager.start_battle()
				)
			return
		
		# 检查是否包含圣遗物奖励，如果是则显示获得的圣遗物信息
		var has_artifact_reward = false
		if reward_type == EventData.RewardType.ARTIFACT:
			has_artifact_reward = true
		elif reward_type == EventData.RewardType.MULTIPLE and reward_value is Dictionary:
			has_artifact_reward = reward_value.has("artifact")
		
		if has_artifact_reward:
			_show_artifact_reward_result(reward_type, reward_value)
			return
		
		var lines: Array[String] = _apply_reward(reward_type, reward_value, current_event)
		_show_choice_result(str(choice.get("description", "")), lines)
		return
	
	# 允许 choice 不带奖励：也应该展示选择后的提示（如果有）。
	_show_choice_result(str(choice.get("description", "")), [])
	return


func _show_choice_result(choice_desc: String, reward_lines: Array[String]) -> void:
	if not is_instance_valid(content_container):
		_complete_event()
		return
	_clear_content()
	var result_label := Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var parts: Array[String] = []
	if not choice_desc.is_empty():
		parts.append(choice_desc)
	parts.append("本次结果：\n" + ("\n".join(reward_lines) if not reward_lines.is_empty() else "（无）"))
	result_label.text = "\n\n".join(parts)
	content_container.add_child(result_label)
	var confirm_button := Button.new()
	confirm_button.text = "确认"
	confirm_button.custom_minimum_size = Vector2(200, 50)
	confirm_button.pressed.connect(_complete_event)
	content_container.add_child(confirm_button)

## 开始战斗
func _on_battle_started() -> void:
	if not current_event:
		return
	
	# 标记事件已触发
	_mark_event_triggered()
	
	# 如果事件有敌人数据，可以在这里设置
	# 目前直接进入战斗场景
	if GameManager:
		_close_and_do(func() -> void:
			GameManager.start_battle()
		)
	else:
		_complete_event()

## 确认休息
func _on_rest_confirmed() -> void:
	if not current_event:
		return
	
	# 休息事件改为数据驱动：直接按 reward_type/reward_value 执行（支持 MULTIPLE 内 gold 为负表示成本）
	if not _can_afford_reward(current_event.reward_type, current_event.reward_value, current_event):
		_show_event_warning("摩拉不足，无法休息")
		return
	_apply_reward(current_event.reward_type, current_event.reward_value, current_event)
	_update_gold_label()
	_complete_event()


func _on_rest_skipped() -> void:
	if not current_event:
		return
	_complete_event()


func _on_upgrade_reward_confirmed() -> void:
	if not current_event:
		return
	var lines: Array[String] = _apply_reward(current_event.reward_type, current_event.reward_value, current_event)
	_show_reward_result(lines)

## 确认升级
func _on_upgrade_confirmed() -> void:
	if not current_event:
		return
	
	# 在场景切换之前先标记事件（因为场景切换后节点会被移除）
	_mark_event_triggered()
	emit_signal("event_completed", current_event_id)
	
	# 打开升级选择界面
	if GameManager:
		_close_and_do(func() -> void:
			GameManager.show_upgrade_selection()
		)


# ========== 奖励处理 ==========

## 应用奖励
func _apply_reward(reward_type: EventData.RewardType, reward_value: Variant, event_data: EventData = null) -> Array[String]:
	var reward_lines: Array[String] = []
	# 处理随机奖励范围
	var actual_value = _get_actual_reward_value(reward_type, reward_value, event_data)
	
	match reward_type:
		EventData.RewardType.GOLD:
			if actual_value is int or actual_value is float:
				var amount := int(actual_value)
				if amount < 0:
					# 负数表示花费
					if not RunManager.spend_gold(abs(amount)):
						print("摩拉不足，无法支付：", abs(amount))
						return reward_lines
					_update_gold_label()
					reward_lines.append("摩拉 -%d" % abs(amount))
				else:
					RunManager.add_gold(amount)
					print("获得摩拉：", amount)
					_update_gold_label()
					reward_lines.append("摩拉 +%d" % amount)
		EventData.RewardType.HEALTH:
			if actual_value is int or actual_value is float:
				# 检查是否是百分比（负数表示百分比）
				if actual_value < 0:
					var percent = abs(actual_value)
					var heal_amount = RunManager.max_health * (percent / 100.0)
					RunManager.heal(heal_amount)
					print("恢复生命值：", heal_amount, " (", percent, "%)")
					reward_lines.append("生命值 +%d（%d%%）" % [int(round(heal_amount)), int(percent)])
				else:
					RunManager.heal(float(actual_value))
					print("恢复生命值：", actual_value)
					reward_lines.append("生命值 +%d" % int(actual_value))
		EventData.RewardType.UPGRADE:
			if actual_value == null:
				# 随机选择一个升级
				reward_lines.append_array(_give_random_upgrade())
			elif actual_value is int:
				# 给多个随机升级
				for i in range(actual_value):
					reward_lines.append_array(_give_random_upgrade())
			elif actual_value is StringName:
				var actual_str: String = String(actual_value)
				if actual_str == "random":
					# 随机选择一个升级
					reward_lines.append_array(_give_random_upgrade())
				elif actual_str == "random_max":
					# 随机选择一个升级并直接满级
					reward_lines.append_array(_give_random_upgrade_max_level())
				else:
					# 直接给指定的升级
					var level = 1
					if event_data and event_data.has("upgrade_level"):
						level = event_data.upgrade_level
					reward_lines.append_array(_give_upgrade_levels(actual_str, int(level)))
			elif actual_value is String:
				if actual_value == "random":
					# 随机选择一个升级
					reward_lines.append_array(_give_random_upgrade())
				elif actual_value == "random_max":
					# 随机选择一个升级并直接满级
					reward_lines.append_array(_give_random_upgrade_max_level())
				else:
					# 直接给指定的升级
					var level = 1
					if event_data and event_data.has("upgrade_level"):
						level = event_data.upgrade_level
					reward_lines.append_array(_give_upgrade_levels(actual_value, int(level)))
		
		EventData.RewardType.ARTIFACT:
			# 圣遗物奖励：从角色专属圣遗物套装中随机抽取
			var artifact_count_to_give = 1
			if actual_value is int:
				artifact_count_to_give = actual_value
			
			for i in range(artifact_count_to_give):
				var result = RunManager.get_random_artifact_with_slot_from_character_set()
				if result.is_empty():
					print("无法获取圣遗物：角色没有专属圣遗物套装")
					continue
				
				var artifact: ArtifactData = result.artifact
				var slot: ArtifactSlot.SlotType = result.slot
				_give_specific_artifact(artifact, slot)
				reward_lines.append("圣遗物：%s（%s）" % [artifact.name, ArtifactSlot.get_slot_name(slot)])
		
		EventData.RewardType.MULTIPLE:
			if actual_value is Dictionary:
				# 处理多种奖励
				for key in actual_value:
					var value = actual_value[key]
					if key == "gold":
						# 如果事件有随机范围，且gold是最大值，则使用随机范围
						if event_data and event_data.reward_min > 0 and event_data.reward_max > 0:
							var rng: RandomNumberGenerator = RunManager.get_rng() as RandomNumberGenerator
							var random_gold = rng.randi_range(int(event_data.reward_min), int(event_data.reward_max))
							RunManager.add_gold(random_gold)
							print("获得摩拉：", random_gold)
							_update_gold_label()
							reward_lines.append("摩拉 +%d" % random_gold)
						else:
							var gold_amount := int(value)
							if gold_amount < 0:
								if not RunManager.spend_gold(abs(gold_amount)):
									print("摩拉不足，无法支付：", abs(gold_amount))
									return reward_lines
								_update_gold_label()
								reward_lines.append("摩拉 -%d" % abs(gold_amount))
							else:
								RunManager.add_gold(gold_amount)
								_update_gold_label()
								reward_lines.append("摩拉 +%d" % gold_amount)
					elif key == "health":
						if value is int or value is float:
							var hv := float(value)
							if hv < 0.0:
								# 负数表示扣血
								RunManager.take_damage(abs(hv))
								reward_lines.append("生命值 -%d" % int(abs(hv)))
							elif hv > 1000.0:
								# 大数值表示全满
								RunManager.heal(RunManager.max_health)
								reward_lines.append("生命值已回满")
							else:
								# 正数表示恢复生命值
								RunManager.heal(hv)
								reward_lines.append("生命值 +%d" % int(hv))
					elif key == "upgrade":
						if value is String:
							reward_lines.append_array(_give_upgrade_levels(value, 1))
						elif value is int:
							for i in range(value):
								reward_lines.append_array(_give_random_upgrade())
					elif key == "artifact":
						# 圣遗物奖励：从角色专属圣遗物套装中随机抽取
						var artifact_num = 1
						if value is int:
							artifact_num = value
						
						for j in range(artifact_num):
							var result = RunManager.get_random_artifact_with_slot_from_character_set()
							if result.is_empty():
								print("无法获取圣遗物：角色没有专属圣遗物套装")
								continue
							
							var artifact: ArtifactData = result.artifact
							var slot: ArtifactSlot.SlotType = result.slot
							_give_specific_artifact(artifact, slot)
							reward_lines.append("圣遗物：%s（%s）" % [artifact.name, ArtifactSlot.get_slot_name(slot)])
	
	emit_signal("reward_given", reward_type, actual_value)
	return reward_lines


func _can_afford_reward(reward_type: EventData.RewardType, reward_value: Variant, event_data: EventData = null) -> bool:
	if not RunManager:
		return false
	# 对 REST/SHOP 等场景，需要在结算前判断是否能支付成本（gold为负数）
	if reward_type == EventData.RewardType.GOLD and (reward_value is int or reward_value is float):
		return int(reward_value) >= 0 or RunManager.gold >= abs(int(reward_value))
	if reward_type == EventData.RewardType.MULTIPLE and reward_value is Dictionary:
		if reward_value.has("gold"):
			var gv: Variant = reward_value.get("gold")
			if gv is int or gv is float:
				var g := int(gv)
				if g < 0 and RunManager.gold < abs(g):
					return false
		return true
	return true


func _show_event_warning(text: String) -> void:
	if not is_instance_valid(content_container):
		return
	# 避免重复堆叠提示
	var existing := content_container.get_node_or_null("EventWarning") as Label
	if existing:
		existing.text = text
		return
	var warn := Label.new()
	warn.name = "EventWarning"
	warn.text = text
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	content_container.add_child(warn)


func _on_antique_shop_buy_pressed() -> void:
	if not RunManager:
		return
	if not RunManager.current_character or not RunManager.current_character.artifact_set:
		_show_event_warning("当前角色没有专属圣遗物套装")
		return
	if not RunManager.spend_gold(1000):
		_show_event_warning("摩拉不足，无法购买")
		return
	_update_gold_label()
	# 购买全套：每个槽位给1次，并装备
	for slot in ArtifactSlot.get_all_slots():
		var a: ArtifactData = RunManager.current_character.artifact_set.get_artifact(slot)
		if a == null:
			continue
		_give_specific_artifact(a, slot)
	_complete_event()

## 获取实际奖励值（处理随机范围）
func _get_actual_reward_value(reward_type: EventData.RewardType, reward_value: Variant, event_data: EventData) -> Variant:
	if not event_data:
		return reward_value
	
	# MULTIPLE 奖励必须保留字典结构，否则后续无法正确分发各项奖励
	if reward_type == EventData.RewardType.MULTIPLE and reward_value is Dictionary:
		return reward_value
	
	# 检查是否有随机范围
	if event_data.reward_min > 0 and event_data.reward_max > 0 and (reward_value is int or reward_value is float):
		# 使用随机范围
		var rng: RandomNumberGenerator = null
		if RunManager:
			rng = RunManager.get_rng() as RandomNumberGenerator
		if not rng:
			push_warning("EventUI: RunManager 不可用，创建临时 RNG")
			rng = RandomNumberGenerator.new()
			rng.randomize()
		var random_value: int = rng.randi_range(int(event_data.reward_min), int(event_data.reward_max))
		return random_value
	
	# 检查reward_value是否是数组范围
	if reward_value is Array and reward_value.size() == 2:
		var min_val = reward_value[0]
		var max_val = reward_value[1]
		var rng: RandomNumberGenerator = null
		if RunManager:
			rng = RunManager.get_rng() as RandomNumberGenerator
		if not rng:
			push_warning("EventUI: RunManager 不可用，创建临时 RNG")
			rng = RandomNumberGenerator.new()
			rng.randomize()
		return rng.randi_range(int(min_val), int(max_val))
	
	return reward_value

## 给予随机升级
func _give_random_upgrade() -> Array[String]:
	var registry = UpgradeRegistry
	
	var character_id := ""
	var current_floor := 0
	var current_upgrades: Dictionary = {}
	
	if RunManager.current_character:
		character_id = RunManager.current_character.id
	current_floor = RunManager.current_floor
	current_upgrades = RunManager.upgrades
	
	var picked = registry.pick_random_upgrades(character_id, current_upgrades, current_floor, 1)
	if picked.size() > 0:
		var upgrade: UpgradeData = picked[0]
		return _give_upgrade_levels(upgrade.id, 1)
	return []

## 给予随机升级并直接满级
func _give_random_upgrade_max_level() -> Array[String]:
	var registry = UpgradeRegistry
	
	var character_id := ""
	var current_floor := 0
	var current_upgrades: Dictionary = {}
	
	if RunManager.current_character:
		character_id = RunManager.current_character.id
	current_floor = RunManager.current_floor
	current_upgrades = RunManager.upgrades
	
	var picked = registry.pick_random_upgrades(character_id, current_upgrades, current_floor, 1)
	if picked.size() > 0:
		var upgrade: UpgradeData = picked[0]
		# max_level<=0 表示无上限：此时“满级”的语义不明确，避免强行设为默认5级。
		# 处理策略：
		# - 有上限：直接补到上限
		# - 无上限：提升 5 级
		var current_level: int = int(RunManager.get_upgrade_level(upgrade.id))
		if upgrade.max_level > 0:
			var levels_to_add: int = upgrade.max_level - current_level
			if levels_to_add > 0:
				return _give_upgrade_levels(upgrade.id, levels_to_add)
		else:
			return _give_upgrade_levels(upgrade.id, 5)
	return []


func _give_upgrade_levels(upgrade_id: String, levels_to_add: int) -> Array[String]:
	if levels_to_add <= 0:
		return []
	if not RunManager:
		return []
	if upgrade_id.is_empty():
		return []
	var before_level: int = int(RunManager.get_upgrade_level(upgrade_id))
	RunManager.add_upgrade(upgrade_id, levels_to_add)
	var after_level: int = before_level + levels_to_add
	var upgrade: UpgradeData = null
	if UpgradeRegistry:
		upgrade = UpgradeRegistry.get_upgrade(upgrade_id)
	if upgrade == null:
		return ["升级：%s +%d（Lv.%d→%d）" % [upgrade_id, levels_to_add, before_level, after_level]]
	var lines: Array[String] = []
	lines.append("升级：%s +%d（Lv.%d→%d）" % [upgrade.display_name, levels_to_add, before_level, after_level])
	var formatted_desc := _format_upgrade_description_for_gain(upgrade, before_level, after_level)
	if not formatted_desc.is_empty():
		lines.append("效果：%s" % formatted_desc)
	return lines


func _format_upgrade_description_for_gain(upgrade: UpgradeData, before_level: int, after_level: int) -> String:
	if upgrade == null:
		return ""
	var formatted := upgrade.description
	var before_value: float = upgrade.get_value_at_level(before_level)
	var after_value: float = upgrade.get_value_at_level(after_level)
	var delta: float = after_value - before_value
	formatted = formatted.replace("{value}", _format_upgrade_value_for_ui(upgrade, delta))
	formatted = formatted.replace("{current}", _format_upgrade_value_for_ui(upgrade, before_value))
	formatted = formatted.replace("{next}", _format_upgrade_value_for_ui(upgrade, after_value))
	formatted = formatted.replace("{level}", str(before_level))
	formatted = formatted.replace("{max_level}", str(upgrade.max_level))
	return formatted


func _format_upgrade_value_for_ui(upgrade: UpgradeData, value: float) -> String:
	if upgrade == null:
		return str(value)
	var is_percent := upgrade.upgrade_type == UpgradeData.UpgradeType.STAT_PERCENT
	if not is_percent:
		match upgrade.target_stat:
			UpgradeData.TargetStat.DEFENSE_PERCENT, UpgradeData.TargetStat.CRIT_RATE, UpgradeData.TargetStat.CRIT_DAMAGE:
				is_percent = true
	if is_percent:
		return "%.0f%%" % (value * 100.0) if value < 1.0 else "%.0f%%" % value
	var snapped_value: float = snappedf(value, 0.1)
	if abs(snapped_value - float(roundi(snapped_value))) < 0.0001:
		return "%.0f" % snapped_value
	return "%.1f" % snapped_value

## 给予指定的圣遗物（用于已预先抽取的情况）
func _give_specific_artifact(artifact: ArtifactData, slot: ArtifactSlot.SlotType) -> void:
	if not artifact:
		return
	if not RunManager:
		return
	
	var slot_name = ArtifactSlot.get_slot_name(slot)
	if RunManager.has_artifact_in_inventory(artifact.name, slot):
		RunManager.add_gold(DUPLICATE_ARTIFACT_TO_GOLD)
		_update_gold_label()
		_show_event_warning("当前槽位已有，转化为%d摩拉" % DUPLICATE_ARTIFACT_TO_GOLD)
		print("圣遗物重复，转化为摩拉：%s（%s） -> %d" % [artifact.name, slot_name, DUPLICATE_ARTIFACT_TO_GOLD])
		return
	
	# 添加到库存并装备
	RunManager.add_artifact_to_inventory(artifact, slot)
	RunManager.equip_artifact_to_character(artifact, slot)
	
	print("获得圣遗物：%s（%s）" % [artifact.name, slot_name])

## 显示圣遗物奖励结果（用于选择事件中的圣遗物奖励）
func _show_artifact_reward_result(reward_type: EventData.RewardType, reward_value: Variant) -> void:
	# 清空选择按钮
	if choice_container:
		for child in choice_container.get_children():
			child.queue_free()
	
	# 清空内容容器
	_clear_content()
	
	# 抽取圣遗物
	var artifact_result = RunManager.get_random_artifact_with_slot_from_character_set()
	
	var result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	if artifact_result.is_empty():
		result_label.text = "获得圣遗物！（但没有可用的圣遗物套装）"
		result_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.9))
		content_container.add_child(result_label)
		
		# 如果有其他奖励（MULTIPLE类型），也要应用
		if reward_type == EventData.RewardType.MULTIPLE and reward_value is Dictionary:
			_apply_non_artifact_rewards(reward_value)
		
		var confirm_button = Button.new()
		confirm_button.text = "确认"
		confirm_button.custom_minimum_size = Vector2(200, 50)
		confirm_button.pressed.connect(_complete_event)
		content_container.add_child(confirm_button)
	else:
		var artifact: ArtifactData = artifact_result.artifact
		var slot: ArtifactSlot.SlotType = artifact_result.slot
		var slot_name = ArtifactSlot.get_slot_name(slot)
		
		# 构建显示文本
		var display_text = "获得圣遗物！\n%s（%s）\n%s" % [artifact.name, slot_name, artifact.get_bonus_summary(0)]
		if RunManager and RunManager.has_artifact_in_inventory(artifact.name, slot):
			display_text += "\n\n当前槽位已有，将转化为%d摩拉" % DUPLICATE_ARTIFACT_TO_GOLD
		
		# 如果是MULTIPLE类型且有其他奖励，添加到显示
		if reward_type == EventData.RewardType.MULTIPLE and reward_value is Dictionary:
			var other_rewards: Array[String] = []
			for key in reward_value:
				if key != "artifact":
					var value = reward_value[key]
					if key == "gold":
						other_rewards.append("摩拉 +%d" % int(value))
					elif key == "health":
						if value < 0:
							other_rewards.append("生命值 %d" % int(value))
						else:
							other_rewards.append("生命值 +%d" % int(value))
			if other_rewards.size() > 0:
				display_text += "\n\n其他奖励：" + ", ".join(other_rewards)
		
		result_label.text = display_text
		result_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.9))
		content_container.add_child(result_label)
		
		var confirm_button = Button.new()
		confirm_button.text = "获得奖励"
		confirm_button.custom_minimum_size = Vector2(200, 50)
		# 点击后给予圣遗物和其他奖励
		confirm_button.pressed.connect(func():
			_give_specific_artifact(artifact, slot)
			if reward_type == EventData.RewardType.MULTIPLE and reward_value is Dictionary:
				_apply_non_artifact_rewards(reward_value)
			_complete_event()
		)
		content_container.add_child(confirm_button)

## 应用非圣遗物奖励（用于MULTIPLE类型中排除圣遗物后的其他奖励）
func _apply_non_artifact_rewards(reward_dict: Dictionary) -> void:
	for key in reward_dict:
		if key == "artifact":
			continue  # 跳过圣遗物，已单独处理
		
		var value = reward_dict[key]
		if key == "gold":
			RunManager.add_gold(int(value))
			print("获得摩拉：", value)
		elif key == "health":
			if value is float and value < 0:
				RunManager.take_damage(abs(value))
			else:
				RunManager.heal(float(value))
		elif key == "upgrade":
			if value is String:
				RunManager.add_upgrade(value, 1)
			elif value is int:
				for i in range(value):
					_give_random_upgrade()


func _show_reward_result(lines: Array[String]) -> void:
	if not is_instance_valid(content_container):
		_complete_event()
		return
	_clear_content()
	var result_label := Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.text = "本次结果：\n" + ("\n".join(lines) if not lines.is_empty() else "（无）")
	content_container.add_child(result_label)
	var confirm_button := Button.new()
	confirm_button.text = "确认"
	confirm_button.custom_minimum_size = Vector2(200, 50)
	confirm_button.pressed.connect(_complete_event)
	content_container.add_child(confirm_button)


func _get_reward_preview_text(event_data: EventData) -> String:
	if not event_data:
		return ""
	match event_data.reward_type:
		EventData.RewardType.GOLD:
			if event_data.reward_min > 0 and event_data.reward_max > 0:
				return "获得 %d-%d 摩拉" % [int(event_data.reward_min), int(event_data.reward_max)]
			return "获得 %d 摩拉" % int(event_data.reward_value)
		EventData.RewardType.HEALTH:
			return "恢复 %d 点生命值" % int(event_data.reward_value)
		EventData.RewardType.UPGRADE:
			if event_data.reward_value is int:
				return "获得 %d 个升级" % int(event_data.reward_value)
			return "获得升级"
		EventData.RewardType.MULTIPLE:
			if event_data.reward_value is Dictionary:
				var parts: Array[String] = []
				var d: Dictionary = event_data.reward_value
				if d.has("gold"):
					if event_data.reward_min > 0 and event_data.reward_max > 0:
						parts.append("摩拉 +%d-%d" % [int(event_data.reward_min), int(event_data.reward_max)])
					else:
						parts.append("摩拉 +%d" % int(d.get("gold", 0)))
				if d.has("upgrade"):
					parts.append("升级 x%d" % int(d.get("upgrade", 0)))
				if d.has("health"):
					var hv: Variant = d.get("health", 0)
					if hv is int or hv is float:
						var hi := int(hv)
						parts.append("生命值 %s%d" % ["+" if hi >= 0 else "", hi])
				if d.has("artifact"):
					parts.append("圣遗物 x%d" % int(d.get("artifact", 1)))
				if parts.is_empty():
					return "获得多种奖励"
				return "获得多种奖励：\n" + "\n".join(parts)
			return "获得多种奖励"
		_:
			return "获得奖励"

## 获取奖励文本
func _get_reward_text(reward_type: EventData.RewardType, reward_value: Variant) -> String:
	match reward_type:
		EventData.RewardType.GOLD:
			return "获得 %d 摩拉" % int(reward_value)
		EventData.RewardType.HEALTH:
			return "恢复 %d 点生命值" % int(reward_value)
		EventData.RewardType.UPGRADE:
			return "获得升级"
		EventData.RewardType.MULTIPLE:
			return "获得多种奖励"
		_:
			return "获得奖励"

# ========== 工具方法 ==========

## 完成事件
func _complete_event() -> void:
	_mark_event_triggered()
	emit_signal("event_completed", current_event_id)
	
	# 检查场景树是否存在（节点可能已经不在场景树中）
	var tree = get_tree()
	if tree:
		# 立刻返回地图：先播本界面退场动画，然后直接切回地图
		if GameManager:
			_close_and_do(func() -> void:
				GameManager.go_to_map_view()
			)
	else:
		# 如果节点不在场景树中，直接返回地图
		if GameManager:
			GameManager.go_to_map_view()

## 标记事件已触发
func _mark_event_triggered() -> void:
	if current_event_id.is_empty():
		return
	
	EventRegistry.mark_event_triggered(current_event_id)
