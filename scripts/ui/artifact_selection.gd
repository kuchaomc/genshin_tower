extends Node2D

## 圣遗物选择界面脚本
## 类似升级选择界面，用于让玩家选择获得的圣遗物

signal artifact_selected(artifact: ArtifactData, slot: ArtifactSlot.SlotType)

@onready var _ui_root: Control = $CanvasLayer/UIRoot
@onready var _main_margin: MarginContainer = $CanvasLayer/UIRoot/MainMargin
@onready var _artifact_panel: PanelContainer = $CanvasLayer/UIRoot/MainMargin/MainVBox/ArtifactPanel

@onready var title_label: Label = $CanvasLayer/UIRoot/MainMargin/MainVBox/HeaderHBox/TitleLabel
@onready var gold_label: Label = $CanvasLayer/UIRoot/MainMargin/MainVBox/HeaderHBox/GoldLabel
@onready var rule_label: Label = $CanvasLayer/UIRoot/MainMargin/MainVBox/ArtifactPanel/ArtifactMargin/ArtifactVBox/RuleLabel
@onready var artifact_container: VBoxContainer = $CanvasLayer/UIRoot/MainMargin/MainVBox/ArtifactPanel/ArtifactMargin/ArtifactVBox/ArtifactScroll/ArtifactContainer
@onready var skip_button: Button = $CanvasLayer/UIRoot/MainMargin/MainVBox/SkipButton

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

# 可选的圣遗物列表（ArtifactData 类型）
var available_artifacts: Array[ArtifactData] = []

# 圣遗物选项数量
@export var artifact_count: int = 3

const DUPLICATE_ARTIFACT_GOLD_REWARD: int = 500

func _ready() -> void:
	_process_ui_style()
	_setup_container_auto_style()
	call_deferred("_cache_layout")
	call_deferred("_play_open_animation")
	_update_gold_label()

	if title_label:
		title_label.text = "选择圣遗物"
	if rule_label:
		rule_label.add_theme_color_override("font_color", Color(0.80, 0.84, 0.90, 1.0))
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)
	generate_artifact_options()
	display_artifacts()

func _setup_container_auto_style() -> void:
	if is_instance_valid(artifact_container) and not artifact_container.child_entered_tree.is_connected(_on_container_child_entered):
		artifact_container.child_entered_tree.connect(_on_container_child_entered)

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

	if is_instance_valid(_artifact_panel):
		_artifact_panel.add_theme_stylebox_override("panel", _panel_style)
		_artifact_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		_ensure_center_pivot(_artifact_panel)

	if title_label:
		title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65, 1.0))
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

	_apply_button_theme(skip_button)

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
	if is_instance_valid(skip_button):
		skip_button.disabled = true
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

## 生成圣遗物选项
func generate_artifact_options() -> void:
	available_artifacts.clear()
	
	if not RunManager or not RunManager.current_character:
		push_error("ArtifactSelection: RunManager 或当前角色未找到")
		if DebugLogger:
			DebugLogger.log_error("RunManager 或 current_character 为 null，无法生成圣遗物选项", "ArtifactSelection")
			DebugLogger.save_debug_log()
		return
	
	# 当前版本：圣遗物获得即满效果
	# 生成逻辑：优先刷出“尚未获得过的槽位”；若 5 个槽位都已获得过，则允许再次出现（避免界面只剩跳过）
	var unobtained_slots: Dictionary = {}
	if RunManager.has_method("has_artifact_in_inventory") and RunManager.current_character.artifact_set:
		for s in ArtifactSlot.get_all_slots():
			var set_artifact: ArtifactData = RunManager.current_character.artifact_set.get_artifact(s)
			if set_artifact == null:
				continue
			if not RunManager.has_artifact_in_inventory(set_artifact.name, s):
				unobtained_slots[s] = true
	
	if DebugLogger:
		var c := RunManager.current_character
		DebugLogger.log_info("current_character=%s(%s)" % [c.display_name, c.id], "ArtifactSelection")
		DebugLogger.log_info("artifact_set=%s" % ["null" if c.artifact_set == null else "ok"], "ArtifactSelection")
		if c.artifact_set:
			for slot in ArtifactSlot.get_all_slots():
				var a: ArtifactData = c.artifact_set.get_artifact(slot)
				DebugLogger.log_debug("slot=%s artifact=%s" % [ArtifactSlot.get_slot_name(slot), ("null" if a == null else a.name)], "ArtifactSelection")
	
	# 从角色专属圣遗物套装中随机选择（每次打开宝箱都重新随机）
	# 随机数统一由 RunManager 管理（避免到处 randomize）
	# 同一次生成中尽量不出现重复选项：按槽位去重（每个槽位对应一个圣遗物）
	var picked_slots: Dictionary = {}
	var attempts: int = 0
	var max_attempts: int = maxi(artifact_count * 10, 10)
	while available_artifacts.size() < artifact_count and attempts < max_attempts:
		attempts += 1
		var result: Dictionary = RunManager.get_random_artifact_with_slot_from_character_set()
		if result.is_empty():
			break
		var artifact: ArtifactData = result.get("artifact", null)
		var slot: ArtifactSlot.SlotType = result.get("slot", ArtifactSlot.SlotType.FLOWER)
		if artifact == null:
			continue
		# 若存在未获得的槽位：只允许从这些槽位里出
		if unobtained_slots.size() > 0 and not unobtained_slots.has(slot):
			continue
		if picked_slots.has(slot):
			continue
		# 若还有未获得的槽位：避免刷出已获得过的同槽位圣遗物
		if unobtained_slots.size() > 0 and RunManager.has_method("has_artifact_in_inventory") and RunManager.has_artifact_in_inventory(artifact.name, slot):
			continue
		picked_slots[slot] = true
		available_artifacts.append(artifact)
	
	if available_artifacts.size() == 0:
		push_warning("ArtifactSelection: 没有可用的圣遗物选项")
		if DebugLogger:
			DebugLogger.log_warning("available_artifacts 为 0（界面将只剩跳过）", "ArtifactSelection")
			DebugLogger.save_debug_log()
	elif available_artifacts.size() < artifact_count:
		# 可用槽位数量不足时，避免强行塞入重复项，允许显示更少的选项
		if DebugLogger:
			DebugLogger.log_info("可用圣遗物数量不足：期望=%d 实际=%d" % [artifact_count, available_artifacts.size()], "ArtifactSelection")

## 显示圣遗物选项
func display_artifacts() -> void:
	if not artifact_container:
		return
	
	# 清空现有按钮
	for child in artifact_container.get_children():
		child.queue_free()
	
	# 为每个圣遗物创建按钮
	for artifact in available_artifacts:
		_create_artifact_button(artifact)

## 创建圣遗物按钮
func _create_artifact_button(artifact: ArtifactData) -> void:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(450, 160)
	
	# 确定圣遗物槽位（从角色套装中查找）
	var slot = _find_artifact_slot(artifact)
	button.pressed.connect(_on_artifact_selected.bind(artifact, slot))
	
	# 创建容器
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	
	var hbox: HBoxContainer = HBoxContainer.new()
	margin.add_child(hbox)
	
	# 左侧：图标、名称和描述
	var vbox_left: VBoxContainer = VBoxContainer.new()
	vbox_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox_left)
	
	# 图标和名称的容器
	var icon_name_hbox: HBoxContainer = HBoxContainer.new()
	vbox_left.add_child(icon_name_hbox)
	
	# 圣遗物图标
	var icon_texture: TextureRect = TextureRect.new()
	icon_texture.custom_minimum_size = Vector2(64, 64)
	icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	var icon_path = _get_artifact_icon_path(artifact.name)
	if icon_path:
		var icon: Texture2D = null
		if DataManager:
			icon = DataManager.get_texture(icon_path)
		else:
			icon = load(icon_path) as Texture2D
		if icon:
			icon_texture.texture = icon
	icon_name_hbox.add_child(icon_texture)
	
	# 名称
	var name_label: Label = Label.new()
	name_label.text = artifact.name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_name_hbox.add_child(name_label)
	
	# 右侧：属性加成
	var vbox_right: VBoxContainer = VBoxContainer.new()
	vbox_right.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_child(vbox_right)
	
	# 属性加成显示
	var bonus_label: Label = Label.new()
	bonus_label.text = artifact.get_bonus_summary(1)
	bonus_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox_right.add_child(bonus_label)
	
	# 提示：当前版本圣遗物获得即满效果
	var level_hint: Label = Label.new()
	var is_duplicate: bool = false
	if RunManager and RunManager.has_method("has_artifact_in_inventory"):
		is_duplicate = RunManager.has_artifact_in_inventory(artifact.name, slot)
	if is_duplicate:
		level_hint.text = "（已拥有：可换 %d 摩拉）" % DUPLICATE_ARTIFACT_GOLD_REWARD
	else:
		level_hint.text = "（获得即生效）"
	level_hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
	level_hint.add_theme_font_size_override("font_size", 12)
	vbox_right.add_child(level_hint)
	
	button.add_child(margin)
	artifact_container.add_child(button)
	_bind_button_fx(button)

## 查找圣遗物在角色套装中的槽位
func _find_artifact_slot(artifact: ArtifactData) -> ArtifactSlot.SlotType:
	if not RunManager or not RunManager.current_character or not RunManager.current_character.artifact_set:
		return ArtifactSlot.SlotType.FLOWER
	
	var set_data = RunManager.current_character.artifact_set
	for slot in ArtifactSlot.get_all_slots():
		var set_artifact = set_data.get_artifact(slot)
		if set_artifact and set_artifact.name == artifact.name:
			return slot
	
	# 如果找不到，默认返回第一个槽位
	return ArtifactSlot.SlotType.FLOWER

## 圣遗物选择回调
func _on_artifact_selected(artifact: ArtifactData, slot: ArtifactSlot.SlotType) -> void:
	# 已拥有：允许改为获得摩拉
	if RunManager and RunManager.has_method("has_artifact_in_inventory") and RunManager.has_artifact_in_inventory(artifact.name, slot):
		RunManager.add_gold(DUPLICATE_ARTIFACT_GOLD_REWARD)
		_update_gold_label()
		_return_to_map()
		return
	
	emit_signal("artifact_selected", artifact, slot)
	
	# 添加到库存
	if RunManager:
		RunManager.add_artifact_to_inventory(artifact, slot)
		
		# 自动装备到角色
		RunManager.equip_artifact_to_character(artifact, slot)
	
	# 关闭界面并返回地图
	_return_to_map()

## 跳过按钮回调
func _on_skip_pressed() -> void:
	print("跳过圣遗物选择")
	_return_to_map()

## 获取圣遗物图标路径
func _get_artifact_icon_path(artifact_name: String) -> String:
	# 根据圣遗物名称返回图标路径
	match artifact_name:
		"历经风雪的思念":
			return "res://textures/ui/历经风雪的思念.png"
		"摧冰而行的执望":
			return "res://textures/ui/摧冰而行的执望.png"
		"冰雪故园的终期":
			return "res://textures/ui/冰雪故园的终期.png"
		"遍结寒霜的傲骨":
			return "res://textures/ui/遍结寒霜的傲骨.png"
		"破冰踏雪的回音":
			return "res://textures/ui/破冰踏雪的回音.png"
		"迷宫的游人":
			return "res://textures/ui/深林的记忆/迷宫的游人.png"
		"翠蔓的智者":
			return "res://textures/ui/深林的记忆/翠蔓的智者.png"
		"贤智的定期":
			return "res://textures/ui/深林的记忆/贤智的定期.png"
		"迷误者之灯":
			return "res://textures/ui/深林的记忆/迷误者之灯.png"
		"月桂的宝冠":
			return "res://textures/ui/深林的记忆/月桂的宝冠.png"
		"理之冠":
			return "res://textures/ui/理之冠.png"
		_:
			return ""

## 返回地图
func _return_to_map() -> void:
	if GameManager:
		_close_and_do(func() -> void:
			GameManager.go_to_map_view()
		)
	else:
		queue_free()
