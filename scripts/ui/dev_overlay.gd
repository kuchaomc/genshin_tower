extends CanvasLayer

## 开发者覆盖层（常驻顶层 UI）
## - 左上角按钮 -> 密码校验 -> 开发者面板
## - 支持：修改 RunManager 资源/属性、玩家实时属性、升级、圣遗物、快速跳转与战斗内传送

const DEV_PASSWORD: String = "kuchao"

var _unlocked: bool = false

var _root: Control
var _dev_button: Button

var _pwd_window: Window
var _pwd_edit: LineEdit
var _pwd_error: Label

var _panel_window: Window
var _tabs: TabContainer

# ---- Stats tab widgets ----
var _rm_gold: SpinBox
var _rm_health: SpinBox
var _rm_max_health: SpinBox
var _rm_floor: SpinBox
var _rm_node_id: LineEdit

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

	_build_password_window()
	_build_panel_window()

func _build_password_window() -> void:
	_pwd_window = Window.new()
	_pwd_window.title = "开发者验证"
	_pwd_window.visible = false
	_pwd_window.transient = true
	_pwd_window.exclusive = true
	_pwd_window.unresizable = true
	_pwd_window.size = Vector2i(420, 170)
	_pwd_window.close_requested.connect(func(): _pwd_window.hide())
	_root.add_child(_pwd_window)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_top = 12
	v.offset_right = -12
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 8)
	_pwd_window.add_child(v)

	var tip := Label.new()
	tip.text = "请输入密码："
	v.add_child(tip)

	_pwd_edit = LineEdit.new()
	_pwd_edit.placeholder_text = "密码"
	_pwd_edit.secret = true
	_pwd_edit.text_submitted.connect(func(_t: String): _submit_password())
	v.add_child(_pwd_edit)

	_pwd_error = Label.new()
	_pwd_error.text = ""
	_pwd_error.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	v.add_child(_pwd_error)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)

	var ok := Button.new()
	ok.text = "进入"
	ok.pressed.connect(_submit_password)
	h.add_child(ok)

	var cancel := Button.new()
	cancel.text = "取消"
	cancel.pressed.connect(func(): _pwd_window.hide())
	h.add_child(cancel)

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

	var lock := Button.new()
	lock.text = "锁定（下次需密码）"
	lock.pressed.connect(func():
		_unlocked = false
		_panel_window.hide()
	)
	top_bar.add_child(lock)

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
	_tabs.add_child(_build_tab_teleport())

func _on_dev_button_pressed() -> void:
	if _unlocked:
		_open_panel()
	else:
		_open_password_prompt()

func _open_password_prompt() -> void:
	_pwd_error.text = ""
	_pwd_edit.text = ""
	_pwd_window.popup_centered()
	await get_tree().process_frame
	_pwd_edit.grab_focus()

func _submit_password() -> void:
	var input := _pwd_edit.text.strip_edges()
	if input == DEV_PASSWORD:
		_unlocked = true
		_pwd_window.hide()
		_open_panel()
	else:
		_pwd_error.text = "密码错误"
		_pwd_edit.select_all()
		_pwd_edit.grab_focus()

func _open_panel() -> void:
	_refresh_all_views()
	_panel_window.popup_centered()

func _refresh_all_views() -> void:
	_refresh_runmanager_fields()
	_refresh_player_stat_fields()

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
	_rm_node_id = LineEdit.new()
	_rm_node_id.placeholder_text = "当前地图节点ID（可空）"

	content.add_child(_build_kv_row("摩拉", _rm_gold))
	content.add_child(_build_kv_row("当前生命", _rm_health))
	content.add_child(_build_kv_row("最大生命", _rm_max_health))
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

func _refresh_runmanager_fields() -> void:
	if not RunManager:
		return
	_rm_gold.value = RunManager.gold
	_rm_health.value = RunManager.health
	_rm_max_health.value = RunManager.max_health
	_rm_floor.value = max(1, RunManager.current_floor)
	_rm_node_id.text = RunManager.current_node_id

func _apply_runmanager_fields() -> void:
	if not RunManager:
		return
	RunManager.gold = int(_rm_gold.value)
	if RunManager.has_signal("gold_changed"):
		RunManager.emit_signal("gold_changed", RunManager.gold)

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
	level = max(0, level)
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

	var equip0 := Button.new()
	equip0.text = "装备专属(50%)"
	row.add_child(equip0)

	var equip1 := Button.new()
	equip1.text = "升到100%"
	row.add_child(equip1)

	var unequip := Button.new()
	unequip.text = "卸下槽位"
	row.add_child(unequip)

	var equip_all := Button.new()
	equip_all.text = "装备全部五件(100%)"
	row.add_child(equip_all)

	var hint := Label.new()
	hint.text = "说明：同一圣遗物装备第二次会自动升到 100%（系统规则）。"
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	tab.add_child(hint)

	var get_slot := func() -> int:
		return int(slot_select.get_selected_metadata())

	var equip_slot := func(slot: int, target_level: int) -> void:
		if not RunManager:
			return
		var art: ArtifactData = RunManager.get_artifact_from_character_set(slot)
		if not art:
			return
		# 确保进入库存（即便当前不在战斗，后续创建角色节点会自动装备）
		RunManager.add_artifact_to_inventory(art, slot)
		# 装备一次：0级(50%)
		RunManager.equip_artifact_to_character(art, slot)
		# 再装备一次：升到1级(100%)
		if target_level >= 1:
			RunManager.equip_artifact_to_character(art, slot)

	equip0.pressed.connect(func():
		equip_slot.call(get_slot.call(), 0)
	)

	equip1.pressed.connect(func():
		equip_slot.call(get_slot.call(), 1)
	)

	unequip.pressed.connect(func():
		var p := _get_player()
		if p:
			p.unequip_artifact(get_slot.call())
	)

	equip_all.pressed.connect(func():
		for s in ArtifactSlot.get_all_slots():
			equip_slot.call(int(s), 1)
	)

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
