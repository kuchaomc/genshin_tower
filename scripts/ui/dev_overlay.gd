extends CanvasLayer

## 开发者覆盖层（常驻顶层 UI）
## - 左上角按钮 -> 密码校验 -> 开发者面板
## - 支持：修改 RunManager 资源/属性、玩家实时属性、升级、圣遗物、快速跳转与战斗内传送

var _unlocked: bool = false

var _root: Control
var _dev_button: Button

var _panel_window: Window
var _tabs: TabContainer

# ---- Stats tab widgets ----
var _rm_gold: SpinBox
var _rm_health: SpinBox
var _rm_max_health: SpinBox
var _rm_floor: SpinBox
var _rm_node_id: LineEdit
var _rm_primogems_earned: SpinBox

# ---- Persistent tab widgets ----
var _gm_primogems_total: SpinBox
var _clear_save_confirm: ConfirmationDialog

var _player_stat_inputs: Dictionary = {} # name -> Control (SpinBox)
var _teleport_x: SpinBox
var _teleport_y: SpinBox

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_connect_singletons()
	_refresh_visibility()

func _connect_singletons() -> void:
	if GameManager and GameManager.has_signal("scene_changed"):
		if not GameManager.scene_changed.is_connected(_on_scene_changed):
			GameManager.scene_changed.connect(_on_scene_changed)

func _on_scene_changed(_scene_path: String) -> void:
	_refresh_visibility()

func _refresh_visibility() -> void:
	if not GameManager:
		visible = true
		return
	visible = not _should_hide_in_current_state()

func _should_hide_in_current_state() -> bool:
	# 主菜单、角色选择不显示
	if not GameManager:
		return false
	return GameManager.current_state == GameManager.GameState.MAIN_MENU \
		or GameManager.current_state == GameManager.GameState.CHARACTER_SELECT

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_dev_button = Button.new()
	_dev_button.name = "DevButton"
	_dev_button.text = "开发者"
	_dev_button.position = Vector2(12, 12)
	_dev_button.custom_minimum_size = Vector2(96, 36)
	_dev_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_dev_button.pressed.connect(_on_dev_button_pressed)
	_root.add_child(_dev_button)
	_build_panel_window()
	_build_clear_save_confirm()

func _build_panel_window() -> void:
	_panel_window = Window.new()
	_panel_window.title = "开发者选项"
	_panel_window.visible = false
	_panel_window.transient = true
	_panel_window.exclusive = false
	_panel_window.size = Vector2i(980, 620)
	_panel_window.close_requested.connect(func(): _panel_window.hide())
	_root.add_child(_panel_window)

	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 10
	outer.offset_top = 10
	outer.offset_right = -10
	outer.offset_bottom = -10
	outer.add_theme_constant_override("separation", 10)
	_panel_window.add_child(outer)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	outer.add_child(top_bar)

	var refresh := Button.new()
	refresh.text = "刷新数据"
	refresh.pressed.connect(_refresh_all_views)
	top_bar.add_child(refresh)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(func(): _panel_window.hide())
	top_bar.add_child(close_btn)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(_tabs)

	_tabs.add_child(_build_tab_stats())
	_tabs.add_child(_build_tab_upgrades())
	_tabs.add_child(_build_tab_artifacts())
	_tabs.add_child(_build_tab_events())
	_tabs.add_child(_build_tab_teleport())
	_tabs.add_child(_build_tab_persistent())

func _on_dev_button_pressed() -> void:
	_unlocked = true
	_open_panel()

func _open_panel() -> void:
	_refresh_all_views()
	_panel_window.popup_centered()

func _refresh_all_views() -> void:
	_refresh_runmanager_fields()
	_refresh_player_stat_fields()
	_refresh_persistent_fields()

func _get_player() -> BaseCharacter:
	# 优先：RunManager.current_character_node
	if RunManager and RunManager.current_character_node and RunManager.current_character_node is BaseCharacter:
		return RunManager.current_character_node as BaseCharacter
	# 兜底：战斗场景里的 battle_manager 组
	var bm := get_tree().get_first_node_in_group("battle_manager")
	if bm and bm.has_method("get_player"):
		var p = bm.get_player()
		return p as BaseCharacter
	return null

func _build_section_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	return l

func _build_kv_row(label_text: String, editor: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(180, 0)
	row.add_child(l)
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(editor)
	return row

func _spin(min_v: float, max_v: float, step: float, is_int: bool = false) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.allow_greater = true
	s.allow_lesser = true
	s.rounded = is_int
	return s

# =========================
# Tab: 属性
# =========================
func _build_tab_stats() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "属性"
	tab.add_theme_constant_override("separation", 10)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	content.add_child(_build_section_title("RunManager（对局数据）"))

	_rm_gold = _spin(0, 999999, 1, true)
	_rm_health = _spin(0, 999999, 1, false)
	_rm_max_health = _spin(1, 999999, 1, false)
	_rm_floor = _spin(1, 999, 1, true)
	_rm_primogems_earned = _spin(0, 999999999, 1, true)
	_rm_node_id = LineEdit.new()
	_rm_node_id.placeholder_text = "当前地图节点ID（可空）"

	content.add_child(_build_kv_row("摩拉", _rm_gold))
	content.add_child(_build_kv_row("当前生命", _rm_health))
	content.add_child(_build_kv_row("最大生命", _rm_max_health))
	content.add_child(_build_kv_row("本局原石", _rm_primogems_earned))
	content.add_child(_build_kv_row("当前楼层", _rm_floor))
	content.add_child(_build_kv_row("当前节点ID", _rm_node_id))

	var rm_btns := HBoxContainer.new()
	rm_btns.add_theme_constant_override("separation", 8)
	content.add_child(rm_btns)

	var apply_rm := Button.new()
	apply_rm.text = "应用对局数据"
	apply_rm.pressed.connect(_apply_runmanager_fields)
	rm_btns.add_child(apply_rm)

	var full_hp := Button.new()
	full_hp.text = "满血"
	full_hp.pressed.connect(func():
		_rm_health.value = _rm_max_health.value
		_apply_runmanager_fields()
	)
	rm_btns.add_child(full_hp)

	content.add_child(_build_section_title("玩家实时属性（战斗内最直接）"))

	# 预置常用字段，避免动态枚举带来太多噪音
	var stat_defs := [
		{"key": "max_health", "label": "最大生命", "min": 1.0, "max": 999999.0, "step": 1.0, "percent": false},
		{"key": "attack", "label": "攻击力", "min": 0.0, "max": 999999.0, "step": 1.0, "percent": false},
		{"key": "defense_percent", "label": "减伤(%)", "min": 0.0, "max": 100.0, "step": 1.0, "percent": true},
		{"key": "move_speed", "label": "移动速度", "min": 0.0, "max": 9999.0, "step": 1.0, "percent": false},
		{"key": "attack_speed", "label": "攻击速度倍率", "min": 0.1, "max": 50.0, "step": 0.1, "percent": false},
		{"key": "crit_rate", "label": "暴击率(%)", "min": 0.0, "max": 100.0, "step": 1.0, "percent": true},
		{"key": "crit_damage", "label": "暴击伤害(%)", "min": 0.0, "max": 500.0, "step": 5.0, "percent": true},
		{"key": "knockback_force", "label": "击退力度", "min": 0.0, "max": 99999.0, "step": 10.0, "percent": false},
		{"key": "pickup_range", "label": "拾取范围", "min": 0.0, "max": 9999.0, "step": 5.0, "percent": false},
	]

	_player_stat_inputs.clear()
	for d in stat_defs:
		var sb := _spin(d["min"], d["max"], d["step"], false)
		_player_stat_inputs[d["key"]] = {"spin": sb, "percent": d["percent"]}
		content.add_child(_build_kv_row(d["label"], sb))

	var p_btns := HBoxContainer.new()
	p_btns.add_theme_constant_override("separation", 8)
	content.add_child(p_btns)

	var apply_p := Button.new()
	apply_p.text = "应用到玩家"
	apply_p.pressed.connect(_apply_player_stats)
	p_btns.add_child(apply_p)

	var reset_p := Button.new()
	reset_p.text = "重置到基础属性"
	reset_p.pressed.connect(func():
		var p := _get_player()
		if p:
			p.reset_stats_to_base()
			if RunManager:
				RunManager.set_health(p.current_health, p.max_health)
		_refresh_player_stat_fields()
	)
	p_btns.add_child(reset_p)

	return tab


# =========================
# Tab: 存档
# =========================
func _build_tab_persistent() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "存档"
	tab.add_theme_constant_override("separation", 10)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	content.add_child(_build_section_title("跨局数据（GameManager）"))

	_gm_primogems_total = _spin(0, 999999999, 1, true)
	content.add_child(_build_kv_row("原石总数", _gm_primogems_total))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)

	var apply_btn := Button.new()
	apply_btn.text = "应用原石"
	apply_btn.pressed.connect(_apply_primogems_total)
	row.add_child(apply_btn)

	var add160 := Button.new()
	add160.text = "+160"
	add160.pressed.connect(func():
		if not _gm_primogems_total:
			return
		_gm_primogems_total.value = int(_gm_primogems_total.value) + 160
		_apply_primogems_total()
	)
	row.add_child(add160)

	var sub160 := Button.new()
	sub160.text = "-160"
	sub160.pressed.connect(func():
		if not _gm_primogems_total:
			return
		_gm_primogems_total.value = maxi(0, int(_gm_primogems_total.value) - 160)
		_apply_primogems_total()
	)
	row.add_child(sub160)

	var zero := Button.new()
	zero.text = "清零"
	zero.pressed.connect(func():
		if not _gm_primogems_total:
			return
		_gm_primogems_total.value = 0
		_apply_primogems_total()
	)
	row.add_child(zero)

	content.add_child(_build_section_title("存档管理"))

	var warn := Label.new()
	warn.text = "警告：清理后会回到主菜单，且不可撤销。"
	warn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
	content.add_child(warn)

	var clear_btn := Button.new()
	clear_btn.text = "清理全部存档"
	clear_btn.pressed.connect(func():
		if _clear_save_confirm:
			_clear_save_confirm.popup_centered()
	)
	content.add_child(clear_btn)

	return tab

func _refresh_runmanager_fields() -> void:
	if not RunManager:
		return
	_rm_gold.value = RunManager.gold
	_rm_health.value = RunManager.health
	_rm_max_health.value = RunManager.max_health
	_rm_primogems_earned.value = RunManager.primogems_earned
	_rm_floor.value = maxi(1, RunManager.current_floor)
	_rm_node_id.text = RunManager.current_node_id

func _apply_runmanager_fields() -> void:
	if not RunManager:
		return
	RunManager.gold = int(_rm_gold.value)
	if RunManager.has_signal("gold_changed"):
		RunManager.emit_signal("gold_changed", RunManager.gold)

	RunManager.primogems_earned = maxi(0, int(_rm_primogems_earned.value))
	if RunManager.has_signal("primogems_earned_changed"):
		RunManager.emit_signal("primogems_earned_changed", RunManager.primogems_earned)

	RunManager.current_node_id = _rm_node_id.text.strip_edges()
	RunManager.set_floor(int(_rm_floor.value))

	var cur: float = float(_rm_health.value)
	var mx: float = maxf(1.0, float(_rm_max_health.value))
	cur = clampf(cur, 0.0, mx)
	RunManager.set_health(cur, mx)

	# 同步到玩家实例（如果存在）
	var p := _get_player()
	if p:
		p.max_health = mx
		p.current_health = cur
		if p.has_signal("health_changed"):
			p.emit_signal("health_changed", p.current_health, p.max_health)

func _refresh_player_stat_fields() -> void:
	var p := _get_player()
	if not p or not p.current_stats:
		return
	for key in _player_stat_inputs.keys():
		var info = _player_stat_inputs[key]
		var sb: SpinBox = info["spin"]
		var is_percent: bool = info["percent"]
		var v := float(p.current_stats.get(StringName(key)))
		if is_percent:
			# defense_percent/crit_rate: 0..1 ; crit_damage: 0.5 表示 +50%
			sb.value = v * 100.0
		else:
			sb.value = v

func _apply_player_stats() -> void:
	var p := _get_player()
	if not p or not p.current_stats:
		return

	for key in _player_stat_inputs.keys():
		var info = _player_stat_inputs[key]
		var sb: SpinBox = info["spin"]
		var is_percent: bool = info["percent"]
		var v := float(sb.value)
		if is_percent:
			v = v / 100.0
		# clamp 范围类字段
		if key == "defense_percent" or key == "crit_rate":
			v = clampf(v, 0.0, 1.0)
		p.current_stats.set(StringName(key), v)

	# 同步到角色本体（使用其内部同步方法，保持血量比例/移动速度等一致）
	if p.has_method("_sync_stats_to_character"):
		p._sync_stats_to_character()
	else:
		# 兜底：至少同步一些关键字段
		p.max_health = p.current_stats.max_health
		p.base_move_speed = p.current_stats.move_speed
		p.move_speed = p.base_move_speed

	if RunManager:
		RunManager.set_health(p.current_health, p.max_health)

	_refresh_player_stat_fields()

func _refresh_persistent_fields() -> void:
	if not GameManager:
		return
	if _gm_primogems_total:
		_gm_primogems_total.value = GameManager.get_primogems_total()

func _apply_primogems_total() -> void:
	if not GameManager or not _gm_primogems_total:
		return
	var total := maxi(0, int(_gm_primogems_total.value))
	GameManager.primogems_total = total
	if GameManager.has_signal("primogems_total_changed"):
		GameManager.emit_signal("primogems_total_changed", total)
	GameManager.save_data()
	_refresh_persistent_fields()

func _build_clear_save_confirm() -> void:
	_clear_save_confirm = ConfirmationDialog.new()
	_clear_save_confirm.title = "确认清理存档"
	_clear_save_confirm.ok_button_text = "确认清理"
	_clear_save_confirm.cancel_button_text = "取消"
	_clear_save_confirm.dialog_text = "此操作会删除 user:// 下的存档与配置文件（save_data.json / settings.cfg / main_menu_bg.cfg），不可撤销。\n\n是否继续？"
	_clear_save_confirm.visible = false
	_clear_save_confirm.process_mode = Node.PROCESS_MODE_ALWAYS
	_clear_save_confirm.confirmed.connect(_on_clear_save_confirmed)
	_root.add_child(_clear_save_confirm)

func _on_clear_save_confirmed() -> void:
	_clear_all_saves()

func _try_remove_user_file(file_name: String) -> bool:
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	if not dir.file_exists(file_name):
		return true
	var err: Error = dir.remove(file_name)
	return err == OK

func _clear_all_saves() -> void:
	var ok_save := _try_remove_user_file("save_data.json")
	var ok_settings := _try_remove_user_file("settings.cfg")
	var ok_bg := _try_remove_user_file("main_menu_bg.cfg")
	if DebugLogger:
		DebugLogger.log_info("清理存档完成：save=%s settings=%s bg=%s" % [str(ok_save), str(ok_settings), str(ok_bg)], "DevOverlay")
	if GameManager:
		GameManager.load_save_data()
		GameManager.go_to_main_menu()
	if _panel_window:
		_panel_window.hide()

# =========================
# Tab: 升级
# =========================
func _build_tab_upgrades() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "升级"
	tab.add_theme_constant_override("separation", 10)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	tab.add_child(top)

	var upgrade_select := OptionButton.new()
	upgrade_select.custom_minimum_size = Vector2(380, 0)
	top.add_child(upgrade_select)

	var lvl := _spin(0, 999, 1, true)
	lvl.custom_minimum_size = Vector2(120, 0)
	top.add_child(lvl)

	var set_btn := Button.new()
	set_btn.text = "设置等级"
	top.add_child(set_btn)

	var add_btn := Button.new()
	add_btn.text = "+1 级"
	top.add_child(add_btn)

	var clear_btn := Button.new()
	clear_btn.text = "清空升级"
	top.add_child(clear_btn)

	var list_title := Label.new()
	list_title.text = "当前已选升级："
	tab.add_child(list_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)

	var list := VBoxContainer.new()
	list.name = "UpgradeList"
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var refresh_upgrade_list := func() -> void:
		for c in list.get_children():
			c.queue_free()
		if not RunManager or RunManager.upgrades.is_empty():
			var empty := Label.new()
			empty.text = "暂无升级"
			list.add_child(empty)
			return
		for id in RunManager.upgrades.keys():
			var lv: int = int(RunManager.upgrades[id])
			var label := Label.new()
			label.text = "%s  Lv.%d" % [str(id), lv]
			list.add_child(label)

	# 填充 upgrade 下拉（优先用 UpgradeRegistry 显示名）
	if UpgradeRegistry and UpgradeRegistry.has_method("get_all_upgrades"):
		var all_upg: Array = UpgradeRegistry.get_all_upgrades()
		all_upg.sort_custom(func(a, b):
			return (a.display_name if a else "") < (b.display_name if b else "")
		)
		for u in all_upg:
			if not u:
				continue
			upgrade_select.add_item("%s (%s)" % [u.display_name, u.id])
			upgrade_select.set_item_metadata(upgrade_select.item_count - 1, u.id)

	var selected_id := func() -> String:
		var md: Variant = upgrade_select.get_selected_metadata()
		return str(md) if md != null else ""

	set_btn.pressed.connect(func():
		var id: String = str(selected_id.call())
		if id.is_empty():
			return
		_set_upgrade_level(id, int(lvl.value))
		refresh_upgrade_list.call()
	)

	add_btn.pressed.connect(func():
		var id: String = str(selected_id.call())
		if id.is_empty() or not RunManager:
			return
		RunManager.add_upgrade(id, 1)
		refresh_upgrade_list.call()
	)

	clear_btn.pressed.connect(func():
		if not RunManager:
			return
		RunManager.upgrades.clear()
		if RunManager.has_method("_recalculate_stat_bonuses"):
			RunManager._recalculate_stat_bonuses()
		if RunManager.current_character_node:
			RunManager.apply_upgrades_to_character(RunManager.current_character_node)
		refresh_upgrade_list.call()
	)

	# 初次刷新
	refresh_upgrade_list.call()
	return tab

func _set_upgrade_level(upgrade_id: String, level: int) -> void:
	if not RunManager:
		return
	level = maxi(0, level)
	RunManager.upgrades[upgrade_id] = level
	# 重新计算并应用（开发者面板允许调用“约定私有”方法）
	if RunManager.has_method("_recalculate_stat_bonuses"):
		RunManager._recalculate_stat_bonuses()
	if RunManager.current_character_node:
		RunManager.apply_upgrades_to_character(RunManager.current_character_node)
	if RunManager.has_signal("upgrade_added"):
		RunManager.emit_signal("upgrade_added", upgrade_id)

# =========================
# Tab: 圣遗物
# =========================
func _build_tab_artifacts() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "圣遗物"
	tab.add_theme_constant_override("separation", 10)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	tab.add_child(row)

	var slot_select := OptionButton.new()
	for slot in ArtifactSlot.get_all_slots():
		slot_select.add_item(ArtifactSlot.get_slot_name(slot))
		slot_select.set_item_metadata(slot_select.item_count - 1, int(slot))
	row.add_child(slot_select)
	
	var equip := Button.new()
	equip.text = "获得并装备槽位(100%)"
	row.add_child(equip)

	var unequip := Button.new()
	unequip.text = "卸下槽位"
	row.add_child(unequip)
	
	var equip_all := Button.new()
	equip_all.text = "获得并装备全部五件(100%)"
	row.add_child(equip_all)
	
	var hint := Label.new()
	hint.text = "说明：当前版本圣遗物获得即 100% 效果，不再存在 50%/100% 等级机制。"
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	tab.add_child(hint)

	var get_slot := func() -> int:
		return int(slot_select.get_selected_metadata())

	var equip_slot := func(slot: int) -> void:
		if not RunManager:
			return
		var art: ArtifactData = RunManager.get_artifact_from_character_set(slot)
		if not art:
			return
		# 确保进入库存（即便当前不在战斗，后续创建角色节点会自动装备）
		RunManager.add_artifact_to_inventory(art, slot)
		# 装备一次：获得即 100%
		RunManager.equip_artifact_to_character(art, slot)

	equip.pressed.connect(func():
		equip_slot.call(get_slot.call())
	)

	unequip.pressed.connect(func():
		var p := _get_player()
		if p:
			p.unequip_artifact(get_slot.call())
	)

	equip_all.pressed.connect(func():
		for s in ArtifactSlot.get_all_slots():
			equip_slot.call(int(s))
	)

	return tab


# =========================
# Tab: 事件
# =========================
func _build_tab_events() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "事件"
	tab.add_theme_constant_override("separation", 10)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	tab.add_child(row)

	var event_select := OptionButton.new()
	event_select.custom_minimum_size = Vector2(460, 0)
	row.add_child(event_select)

	var refresh_btn := Button.new()
	refresh_btn.text = "刷新列表"
	row.add_child(refresh_btn)

	var enter_btn := Button.new()
	enter_btn.text = "进入事件"
	row.add_child(enter_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)

	var info := RichTextLabel.new()
	info.bbcode_enabled = false
	info.scroll_active = false
	info.selection_enabled = true
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(info)

	var _get_selected_event_id := func() -> String:
		var md: Variant = event_select.get_selected_metadata()
		return str(md) if md != null else ""

	var _event_type_name := func(t: int) -> String:
		match t:
			EventData.EventType.REWARD:
				return "奖励"
			EventData.EventType.CHOICE:
				return "选择"
			EventData.EventType.BATTLE:
				return "战斗"
			EventData.EventType.SHOP:
				return "商店"
			EventData.EventType.REST:
				return "休息"
			EventData.EventType.UPGRADE:
				return "升级"
			EventData.EventType.RANDOM:
				return "随机"
			EventData.EventType.CUSTOM:
				return "自定义"
			_:
				return "未知"

	var _update_info := func() -> void:
		var id := str(_get_selected_event_id.call())
		if id.is_empty():
			info.text = "未选择事件"
			return
		var e: EventData = null
		if EventRegistry and EventRegistry.has_method("get_event"):
			e = EventRegistry.get_event(id) as EventData
		if e == null:
			info.text = "找不到事件：%s" % id
			return
		var tags_text := ""
		if e.tags.size() > 0:
			tags_text = ", ".join(e.tags)
		var header := "名称：%s\nID：%s\n类型：%s\n稀有度：%s\n标签：%s\n\n" % [
			e.display_name,
			e.id,
			str(_event_type_name.call(int(e.event_type))),
			e.get_rarity_name(),
			tags_text,
		]
		info.text = header + str(e.description)

	var _refresh_list := func() -> void:
		event_select.clear()
		var all_events: Array = []
		if EventRegistry and EventRegistry.has_method("get_all_events"):
			all_events = EventRegistry.get_all_events()
		all_events.sort_custom(func(a, b):
			var an: String = str(a.display_name) if a else ""
			var bn: String = str(b.display_name) if b else ""
			return an < bn
		)
		for e in all_events:
			if not e:
				continue
			event_select.add_item("%s (%s)" % [e.display_name, e.id])
			event_select.set_item_metadata(event_select.item_count - 1, e.id)
		if event_select.item_count <= 0:
			event_select.add_item("（无事件）")
			event_select.set_item_metadata(0, "")
		_update_info.call()

	event_select.item_selected.connect(func(_i: int) -> void:
		_update_info.call()
	)
	refresh_btn.pressed.connect(func() -> void:
		_refresh_list.call()
	)
	enter_btn.pressed.connect(func() -> void:
		var id := str(_get_selected_event_id.call())
		if id.is_empty():
			return
		if EventRegistry and EventRegistry.has_method("force_next_event"):
			EventRegistry.force_next_event(id)
		if GameManager:
			GameManager.enter_event()
		if _panel_window:
			_panel_window.hide()
	)

	_refresh_list.call()
	return tab

# =========================
# Tab: 传送 / 跳转
# =========================
func _build_tab_teleport() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "传送"
	tab.add_theme_constant_override("separation", 10)

	tab.add_child(_build_section_title("快速跳转到功能界面（切场景）"))

	var jumps := HBoxContainer.new()
	jumps.add_theme_constant_override("separation", 8)
	tab.add_child(jumps)

	var jump_btn := func(text: String, fn: Callable) -> void:
		var b := Button.new()
		b.text = text
		b.pressed.connect(fn)
		jumps.add_child(b)

	jump_btn.call("地图", func(): if GameManager: GameManager.go_to_map_view())
	jump_btn.call("战斗", func(): if GameManager: GameManager.start_battle())
	jump_btn.call("商店", func(): if GameManager: GameManager.enter_shop())
	jump_btn.call("休息", func(): if GameManager: GameManager.enter_rest())
	jump_btn.call("事件", func(): if GameManager: GameManager.enter_event())
	jump_btn.call("宝箱(圣遗物)", func(): if GameManager: GameManager.open_treasure())
	jump_btn.call("BOSS战", func(): if GameManager: GameManager.start_boss_battle())

	tab.add_child(_build_section_title("战斗内传送（移动玩家坐标）"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	tab.add_child(row)

	_teleport_x = _spin(-999999, 999999, 10, false)
	_teleport_y = _spin(-999999, 999999, 10, false)
	_teleport_x.custom_minimum_size = Vector2(180, 0)
	_teleport_y.custom_minimum_size = Vector2(180, 0)
	row.add_child(Label.new())
	row.get_child(0).text = "X"
	row.add_child(_teleport_x)
	row.add_child(Label.new())
	row.get_child(2).text = "Y"
	row.add_child(_teleport_y)

	var tp := Button.new()
	tp.text = "传送玩家"
	row.add_child(tp)

	var tp_center := Button.new()
	tp_center.text = "传送到场地中心"
	row.add_child(tp_center)

	tp.pressed.connect(func():
		var p := _get_player()
		if not p:
			return
		p.global_position = Vector2(float(_teleport_x.value), float(_teleport_y.value))
	)

	tp_center.pressed.connect(func():
		var p := _get_player()
		if not p:
			return
		var boundary := get_tree().current_scene.get_node_or_null("EllipseBoundary")
		if boundary and boundary is Node2D:
			p.global_position = (boundary as Node2D).global_position
		else:
			# 兜底：屏幕中心
			var screen := get_viewport().get_visible_rect().size
			p.global_position = screen * 0.5
	)

	return tab
