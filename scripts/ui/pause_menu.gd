extends Control

## 暂停菜单脚本
## 显示暂停菜单，包含功能按钮和角色信息展示

# UI节点引用
@onready var continue_button: Button = get_node_or_null("LeftLayout/VBox/MenuBox/ContinueRow/ContinueButton") as Button
@onready var settings_button: Button = get_node_or_null("LeftLayout/VBox/MenuBox/SettingsRow/SettingsButton") as Button
@onready var main_menu_button: Button = get_node_or_null("LeftLayout/VBox/MenuBox/QuitRow/MainMenuButton") as Button

# 入场/退场动画相关节点引用（与主界面同款：offset滑入）
@onready var _left_layout: Control = get_node_or_null("LeftLayout") as Control
@onready var _left_background: ColorRect = get_node_or_null("LeftBackground") as ColorRect
@onready var _left_divider_line: ColorRect = get_node_or_null("LeftDividerLine") as ColorRect
@onready var _right_area: Control = get_node_or_null("RightArea") as Control
@onready var _right_background: ColorRect = get_node_or_null("RightBackground") as ColorRect

# 兼容旧版本暂停菜单（已改为主菜单同款风格后默认不会再有右侧角色信息面板）
@onready var character_portrait: TextureRect = get_node_or_null("RightArea/RightMargin/VBox/TopRow/CharacterPanel/HBox/PortraitColumn/PortraitPanel/Margin/VBox/CharacterPortrait") as TextureRect
@onready var character_name_label: Label = get_node_or_null("RightArea/RightMargin/VBox/TopRow/CharacterPanel/HBox/StatsColumn/CharacterName") as Label
@onready var gold_label: Label = get_node_or_null("RightArea/RightMargin/VBox/TopRow/CharacterPanel/HBox/StatsColumn/GoldDisplay/GoldLabel") as Label
@onready var stats_container: VBoxContainer = get_node_or_null("RightArea/RightMargin/VBox/TopRow/CharacterPanel/HBox/StatsColumn/StatsContainer") as VBoxContainer
@onready var upgrades_container: VBoxContainer = get_node_or_null("RightArea/RightMargin/VBox/TopRow/UpgradesPanel/Margin/VBox/UpgradesScrollContainer/UpgradesContainer") as VBoxContainer
@onready var artifacts_container: HBoxContainer = get_node_or_null("RightArea/RightMargin/VBox/TopRow/CharacterPanel/HBox/StatsColumn/ArtifactsContainer") as HBoxContainer
@onready var artifacts_button: Button = get_node_or_null("RightArea/RightMargin/VBox/TopRow/CharacterPanel/HBox/PortraitColumn/ArtifactsButton") as Button

@onready var _stats_column: VBoxContainer = get_node_or_null("RightArea/RightMargin/VBox/TopRow/CharacterPanel/HBox/StatsColumn") as VBoxContainer

var _weapon_row: HBoxContainer = null
var _weapon_icon: TextureRect = null
var _weapon_name: Label = null
var _weapon_tooltip: PanelContainer = null
var _weapon_tooltip_label: Label = null

@onready var _portrait_column: VBoxContainer = get_node_or_null("RightArea/RightMargin/VBox/TopRow/CharacterPanel/HBox/PortraitColumn") as VBoxContainer

@onready var _minimap_viewport_container: SubViewportContainer = get_node_or_null("RightArea/RightMargin/VBox/MiniMapPanel/Margin/MiniMapViewportContainer") as SubViewportContainer
@onready var _minimap_viewport: SubViewport = get_node_or_null("RightArea/RightMargin/VBox/MiniMapPanel/Margin/MiniMapViewportContainer/MiniMapViewport") as SubViewport

var _minimap_map_view: Node = null

var _artifacts_title_label: Label = null
var _artifact_tooltip: PanelContainer = null
var _artifact_tooltip_label: RichTextLabel = null

# 设置界面引用
var settings_menu: Control = null

# 设置侧滑状态（暂停菜单内：从右侧滑入/滑出）
var _settings_overlay_open: bool = false

var _right_area_prev_visible: bool = true
var _right_background_prev_visible: bool = true

# 记录悬停Tween（与主界面保持一致的交互反馈）
var _hover_tweens: Dictionary = {}

# 入场/退场动画Tween
var _menu_tween: Tween = null

# 记录布局最终状态（用于反复打开/关闭时复位）
var _anim_cached: bool = false
var _final_modulate: Color = Color(1, 1, 1, 1)
var _left_layout_final_offsets: Vector2 = Vector2.ZERO
var _left_background_final_offsets: Vector2 = Vector2.ZERO
var _left_divider_final_offsets: Vector2 = Vector2.ZERO
var _right_area_final_offsets: Vector2 = Vector2.ZERO
var _right_background_final_offsets: Vector2 = Vector2.ZERO

# 关闭动画结束后是否需要发出resume_game信号（仅“继续游戏”使用）
var _pending_emit_resume: bool = false

# 关闭动画结束后是否需要返回主菜单
var _pending_go_to_main_menu: bool = false

# 信号
signal resume_game
signal open_settings
signal return_to_main_menu


func _get_battle_manager() -> Node:
	var bm := get_tree().get_first_node_in_group("battle_manager")
	if bm != null:
		return bm
	var scene_root := get_tree().current_scene
	if scene_root != null and scene_root is BattleManager:
		return scene_root
	return null


func _apply_default_cursor() -> void:
	var bm := _get_battle_manager()
	if bm != null and bm.has_method("_restore_default_cursor"):
		bm.call("_restore_default_cursor")
		return
	Input.set_custom_mouse_cursor(null)


func _apply_battle_cursor() -> void:
	var bm := _get_battle_manager()
	if bm != null and bm.has_method("_apply_crosshair_cursor"):
		bm.call("_apply_crosshair_cursor")
		return

func _has_property(obj: Object, prop: StringName) -> bool:
	if obj == null:
		return false
	for p in obj.get_property_list():
		if p.has("name") and StringName(p["name"]) == prop:
			return true
	return false

func _ready() -> void:
	# 设置process_mode为ALWAYS，确保暂停时仍能响应输入
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 连接按钮信号
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	# 右侧“至遗物”按钮已废弃：不显示也不占位
	if artifacts_button:
		artifacts_button.queue_free()
	
	# 悬停/焦点高亮（与主界面一致）
	_setup_menu_hover_effects()
	
	# 初始隐藏
	visible = false
	# 预缓存动画所需的最终布局（避免首次打开时出现偏移抖动）
	call_deferred("_cache_animation_layout")
	
	# 加载设置界面
	_load_settings_menu()
	# 小地图需要等待布局完成（size不为0）再初始化，否则会出现裁切/偏移
	# 预热：把小地图的实例化/地图生成提前做掉，避免第一次打开暂停菜单卡顿
	call_deferred("_prewarm_minimap")
	_relocate_artifacts_ui()
	_setup_weapon_ui()
	_setup_artifact_tooltip_ui()
	
	# 右侧角色信息面板在当前风格下默认不存在，这里不再主动刷新，避免空引用


func _process(_delta: float) -> void:
	# 武器详情面板跟随鼠标
	if is_instance_valid(_weapon_tooltip) and _weapon_tooltip.visible:
		var mouse := get_viewport().get_mouse_position()
		var pos := mouse + Vector2(18, 18)
		var vp_size := get_viewport_rect().size
		var tip_size := _weapon_tooltip.size
		pos.x = clampf(pos.x, 8.0, maxf(8.0, vp_size.x - tip_size.x - 8.0))
		pos.y = clampf(pos.y, 8.0, maxf(8.0, vp_size.y - tip_size.y - 8.0))
		_weapon_tooltip.position = pos
	if is_instance_valid(_artifact_tooltip) and _artifact_tooltip.visible:
		var mouse := get_viewport().get_mouse_position()
		var pos := mouse + Vector2(18, 18)
		var vp_size := get_viewport_rect().size
		var tip_size := _artifact_tooltip.size
		pos.x = clampf(pos.x, 8.0, maxf(8.0, vp_size.x - tip_size.x - 8.0))
		pos.y = clampf(pos.y, 8.0, maxf(8.0, vp_size.y - tip_size.y - 8.0))
		_artifact_tooltip.position = pos


func _setup_weapon_ui() -> void:
	if not is_instance_valid(_stats_column):
		return
	if is_instance_valid(_weapon_row):
		return

	_weapon_row = HBoxContainer.new()
	_weapon_row.name = "WeaponRow"
	_weapon_row.add_theme_constant_override("separation", 8)
	_weapon_row.mouse_filter = Control.MOUSE_FILTER_STOP

	_weapon_icon = TextureRect.new()
	_weapon_icon.custom_minimum_size = Vector2(28, 28)
	_weapon_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_weapon_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	_weapon_row.add_child(_weapon_icon)

	_weapon_name = Label.new()
	_weapon_name.text = "武器：-"
	_weapon_name.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_weapon_name.add_theme_font_size_override("font_size", 16)
	_weapon_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_weapon_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_row.add_child(_weapon_name)

	_stats_column.add_child(_weapon_row)

	_weapon_tooltip = PanelContainer.new()
	_weapon_tooltip.name = "WeaponTooltip"
	_weapon_tooltip.visible = false
	_weapon_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_weapon_tooltip)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_weapon_tooltip.add_child(margin)

	_weapon_tooltip_label = Label.new()
	_weapon_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_weapon_tooltip_label.custom_minimum_size = Vector2(360, 0)
	_weapon_tooltip_label.size_flags_horizontal = Control.SIZE_FILL
	_weapon_tooltip_label.add_theme_font_size_override("font_size", 18)
	margin.add_child(_weapon_tooltip_label)

	_weapon_icon.mouse_entered.connect(_on_weapon_icon_mouse_entered)
	_weapon_icon.mouse_exited.connect(_on_weapon_icon_mouse_exited)

	_update_weapon_display()


func _update_weapon_display() -> void:
	if not is_instance_valid(_weapon_row) or not is_instance_valid(_weapon_icon) or not is_instance_valid(_weapon_name):
		return
	if not RunManager or not RunManager.has_method("get_equipped_weapon_id"):
		_weapon_row.visible = false
		return
	var weapon_id := str(RunManager.get_equipped_weapon_id())
	if weapon_id.is_empty():
		_weapon_row.visible = false
		return
	_weapon_row.visible = true
	var display_name := RunManager.get_weapon_display_name(weapon_id) if RunManager.has_method("get_weapon_display_name") else weapon_id
	_weapon_name.text = "武器：%s" % display_name
	_weapon_icon.texture = RunManager.get_weapon_icon(weapon_id) if RunManager.has_method("get_weapon_icon") else null
	if is_instance_valid(_weapon_tooltip_label) and RunManager.has_method("get_weapon_description"):
		_weapon_tooltip_label.text = str(RunManager.get_weapon_description(weapon_id))


func _on_weapon_icon_mouse_entered() -> void:
	_update_weapon_display()
	if is_instance_valid(_weapon_tooltip):
		_weapon_tooltip.visible = true


func _on_weapon_icon_mouse_exited() -> void:
	if is_instance_valid(_weapon_tooltip):
		_weapon_tooltip.visible = false


func _setup_artifact_tooltip_ui() -> void:
	if is_instance_valid(_artifact_tooltip):
		return
	_artifact_tooltip = PanelContainer.new()
	_artifact_tooltip.name = "ArtifactTooltip"
	_artifact_tooltip.visible = false
	_artifact_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_artifact_tooltip)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_artifact_tooltip.add_child(margin)

	_artifact_tooltip_label = RichTextLabel.new()
	_artifact_tooltip_label.bbcode_enabled = true
	_artifact_tooltip_label.fit_content = true
	_artifact_tooltip_label.scroll_active = false
	_artifact_tooltip_label.custom_minimum_size = Vector2(420, 0)
	_artifact_tooltip_label.size_flags_horizontal = Control.SIZE_FILL
	_artifact_tooltip_label.add_theme_font_size_override("normal_font_size", 18)
	margin.add_child(_artifact_tooltip_label)


func _on_artifact_icon_mouse_entered(slot: ArtifactSlot.SlotType, artifact: ArtifactData) -> void:
	if not is_instance_valid(_artifact_tooltip) or not is_instance_valid(_artifact_tooltip_label):
		return
	_artifact_tooltip_label.text = _build_artifact_tooltip_bbcode(slot, artifact)
	_artifact_tooltip.visible = true


func _on_artifact_icon_mouse_exited() -> void:
	if is_instance_valid(_artifact_tooltip):
		_artifact_tooltip.visible = false


func _build_artifact_tooltip_bbcode(slot: ArtifactSlot.SlotType, artifact: ArtifactData) -> String:
	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % artifact.name)
	lines.append("槽位: %s" % ArtifactSlot.get_slot_name(slot))
	lines.append("")
	lines.append("[b]属性加成:[/b]")
	var bonuses = artifact.get_all_stat_bonuses()
	for stat_name in bonuses:
		var base_value: float = float(bonuses[stat_name])
		var stat_display_name = _get_stat_display_name(stat_name)
		var formatted_value = _format_stat_value(stat_name, base_value)
		lines.append("  %s: %s" % [stat_display_name, formatted_value])

	if RunManager and RunManager.current_character_node:
		var artifact_manager = RunManager.current_character_node.get_artifact_manager()
		if artifact_manager:
			var pieces: int = artifact_manager.get_equipped_count()
			var set_name: String = ""
			if RunManager.current_character and RunManager.current_character.artifact_set:
				set_name = RunManager.current_character.artifact_set.set_name
			lines.append("")
			if not set_name.is_empty():
				lines.append("[b]套装状态:[/b] %s（%d/5）" % [set_name, pieces])
			else:
				lines.append("[b]套装状态:[/b] （%d/5）" % pieces)
			if RunManager.current_character and RunManager.current_character.id == "kamisato_ayaka":
				var active := "[color=#ffcc66]"
				var inactive := "[color=#ffffff]"
				var endc := "[/color]"
				var two_prefix := active if pieces >= 2 else inactive
				var four_prefix := active if pieces >= 4 else inactive
				lines.append(two_prefix + "2件套：暴击率+15%，暴击冻结敌人1秒" + endc)
				lines.append(four_prefix + "4件套：暴击率+20%，冻结敌人伤害+20%" + endc)
	return "\n".join(lines)

func _setup_minimap() -> void:
	if _minimap_viewport == null or _minimap_viewport_container == null:
		return
	# 运行时强制开启交互（避免tscn属性不一致导致无法拖动/缩放）
	_minimap_viewport_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_minimap_viewport.gui_disable_input = false
	_minimap_viewport.handle_input_locally = true
	# 先确保SubViewport尺寸有效：隐藏状态下container可能为0，给一个默认尺寸便于预热生成
	_update_minimap_viewport_size()
	if _minimap_viewport.size.x < 4 or _minimap_viewport.size.y < 4:
		_minimap_viewport.size = Vector2i(640, 360)
	# 避免重复创建
	if is_instance_valid(_minimap_map_view):
		_update_minimap_viewport_size()
		return

	var packed: PackedScene = null
	if DataManager and DataManager.has_method("get_packed_scene"):
		packed = DataManager.get_packed_scene("res://scenes/ui/map_view.tscn")
	else:
		packed = load("res://scenes/ui/map_view.tscn") as PackedScene
	if packed == null:
		return

	_minimap_map_view = packed.instantiate()
	if _minimap_map_view == null:
		return
	# 缩略图模式：不允许MapView修改RunManager的地图种子/进度
	if _has_property(_minimap_map_view, &"minimap_mode"):
		_minimap_map_view.set("minimap_mode", true)
	# 暂停时也能初始化/显示
	_minimap_map_view.process_mode = Node.PROCESS_MODE_ALWAYS
	_minimap_viewport.add_child(_minimap_map_view)

	# 隐藏地图界面原本的UI（楼层、提示、顶部UI等）
	var map_canvas := _minimap_map_view.get_node_or_null("CanvasLayer") as CanvasLayer
	if map_canvas:
		map_canvas.visible = false

	# 调整缩放范围，让缩略图可以更小
	if _has_property(_minimap_map_view, &"min_zoom"):
		_minimap_map_view.set("min_zoom", 0.6)
	if _has_property(_minimap_map_view, &"max_zoom"):
		_minimap_map_view.set("max_zoom", 3.0)
	if _has_property(_minimap_map_view, &"zoom_level"):
		_minimap_map_view.set("zoom_level", 1.2)

	_update_minimap_viewport_size()
	if not _minimap_viewport_container.resized.is_connected(_update_minimap_viewport_size):
		_minimap_viewport_container.resized.connect(_update_minimap_viewport_size)
	# 等一帧让MapView跑完_ready后，再把相机设为当前并应用缩放
	call_deferred("_finish_minimap_setup")

func _relocate_artifacts_ui() -> void:
	if not is_instance_valid(artifacts_container) or not is_instance_valid(_portrait_column):
		return

	# 插入标题（只创建一次）
	if not is_instance_valid(_artifacts_title_label):
		_artifacts_title_label = Label.new()
		_artifacts_title_label.text = "圣遗物"
		_artifacts_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_artifacts_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 已经在目标列中则只调整顺序
	var target_parent: Node = _portrait_column
	if artifacts_container.get_parent() != target_parent:
		var old_parent := artifacts_container.get_parent()
		if old_parent:
			old_parent.remove_child(artifacts_container)
		target_parent.add_child(artifacts_container)
	if _artifacts_title_label.get_parent() != target_parent:
		var old_title_parent := _artifacts_title_label.get_parent()
		if old_title_parent:
			old_title_parent.remove_child(_artifacts_title_label)
		target_parent.add_child(_artifacts_title_label)

	# 放在立绘面板下方、按钮上方
	var portrait_panel := target_parent.get_node_or_null("PortraitPanel")
	var insert_idx := 0
	if portrait_panel:
		insert_idx = target_parent.get_children().find(portrait_panel) + 1
	if insert_idx < 0:
		insert_idx = 0
	# 标题在上，图标在下
	target_parent.move_child(_artifacts_title_label, clampi(insert_idx, 0, target_parent.get_child_count() - 1))
	# move_child 会改变子列表，因此图标插入点需要 +1
	var icons_idx := clampi(insert_idx + 1, 0, target_parent.get_child_count() - 1)
	target_parent.move_child(artifacts_container, icons_idx)
	# “至遗物”按钮已移除

func _finish_minimap_setup() -> void:
	if _minimap_map_view == null or _minimap_viewport == null:
		return
	var cam := _minimap_map_view.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.make_current()
		# 直接设置相机缩放，避免依赖_map_view.gd的输入缩放逻辑
		cam.zoom = Vector2(1.2, 1.2)

func _prewarm_minimap() -> void:
	# 预热只负责提前构建一次，避免首次打开菜单时才生成地图导致卡顿
	# 注意：此处不改变 paused 状态
	await get_tree().process_frame
	_setup_minimap()

func _update_minimap_viewport_size() -> void:
	if _minimap_viewport == null or _minimap_viewport_container == null:
		return
	var size := _minimap_viewport_container.size
	# 避免0尺寸时创建无效渲染目标
	if size.x < 4 or size.y < 4:
		return
	_minimap_viewport.size = Vector2i(int(size.x), int(size.y))

## 加载设置界面
func _load_settings_menu() -> void:
	var settings_scene = preload("res://scenes/ui/settings.tscn")
	if settings_scene:
		settings_menu = settings_scene.instantiate()
		if settings_menu:
			# 添加到与暂停菜单相同的父节点下（通常是CanvasLayer）
			var parent = get_parent()
			if parent:
				parent.add_child(settings_menu)
			else:
				# 如果没有父节点，添加到场景根节点
				get_tree().current_scene.add_child(settings_menu)
			# 暂停菜单内的设置界面：由暂停菜单接管返回/ESC，设置自身不处理ESC
			if settings_menu.has_method("set_esc_close_enabled"):
				settings_menu.call("set_esc_close_enabled", false)
			# 暂停菜单内不需要“返回”按钮
			if settings_menu.has_method("set_back_button_visible"):
				settings_menu.call("set_back_button_visible", false)
			# 背景使用暂停菜单右侧同款渐变面板
			if settings_menu.has_method("set_background_visible"):
				settings_menu.call("set_background_visible", true)
			var settings_bg := settings_menu.get_node_or_null("Background") as ColorRect
			if settings_bg:
				settings_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
				if is_instance_valid(_right_background):
					settings_bg.color = _right_background.color
					if _right_background.material:
						settings_bg.material = _right_background.material.duplicate()
			# 暂停菜单内：允许点击设置面板外区域穿透到暂停菜单（继续游戏等）
			# - 根节点忽略鼠标，避免全屏挡住左侧按钮
			# - 主面板本体仍需拦截鼠标，保证设置项可交互
			settings_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var main_container := settings_menu.get_node_or_null("MainContainer") as Control
			if main_container:
				main_container.mouse_filter = Control.MOUSE_FILTER_STOP
			# 连接设置界面关闭信号
			if settings_menu.has_signal("settings_closed"):
				settings_menu.settings_closed.connect(_on_settings_closed)
			print("设置界面已加载到暂停菜单")

func _open_settings_overlay() -> void:
	_settings_overlay_open = true
	if is_instance_valid(_right_area):
		_right_area_prev_visible = _right_area.visible
		_right_area.visible = false
	if is_instance_valid(_right_background):
		_right_background_prev_visible = _right_background.visible
		_right_background.visible = false
	if settings_menu == null:
		return
	if settings_menu.has_method("show_settings_slide_from_right"):
		settings_menu.call("show_settings_slide_from_right")
	elif settings_menu.has_method("show_settings"):
		settings_menu.call("show_settings")

func _close_settings_overlay() -> void:
	_settings_overlay_open = false
	if visible:
		if is_instance_valid(_right_area):
			_right_area.visible = _right_area_prev_visible
		if is_instance_valid(_right_background):
			_right_background.visible = _right_background_prev_visible
	if settings_menu == null:
		return
	if settings_menu.has_method("hide_settings_slide_to_right"):
		settings_menu.call("hide_settings_slide_to_right")
	elif settings_menu.has_method("hide_settings"):
		settings_menu.call("hide_settings")

## 显示暂停菜单
func show_menu() -> void:
	visible = true
	# 打开暂停菜单时，将战斗自定义准星恢复为默认鼠标，避免菜单交互不直观。
	_apply_default_cursor()
	# 暂停游戏树
	# 这会自动暂停所有使用默认PROCESS_MODE_INHERIT的节点，包括：
	# - 所有节点的 _process、_physics_process、_input 等函数
	# - Timer节点（敌人生成计时器等）
	# - get_tree().create_timer() 创建的计时器（warning动画、重击伤害序列等）
	# - AnimatedSprite2D的动画播放（包括重击动画）
	# - 角色的攻击、移动、伤害判定等所有逻辑
	# - 敌人的AI、移动、伤害判定等所有逻辑
	get_tree().paused = true
	# 播放入场动画（Tween设置为暂停时仍处理）
	call_deferred("_play_show_animation")
	# 显示时再初始化/刷新小地图（此时容器尺寸已稳定）
	call_deferred("_setup_minimap")
	# 确保重击动画在暂停时保持可见（不会被隐藏）
	_preserve_charged_effect_visibility()
	# 右侧信息面板为可选结构，仅在存在时才刷新
	if is_instance_valid(character_name_label) or is_instance_valid(stats_container) or is_instance_valid(upgrades_container) or is_instance_valid(artifacts_container):
		update_character_info()
	# 圣遗物槽位区域：无论是否有角色节点，都刷新一次（至少显示空槽位）
	if is_instance_valid(artifacts_container):
		_update_artifacts_display()

## 隐藏暂停菜单
func hide_menu(emit_resume: bool = false) -> void:
	if not visible:
		return
	# 如果设置侧滑仍处于打开态，关闭暂停菜单时必须先强制隐藏设置界面，避免残留在游戏中
	if _settings_overlay_open:
		_settings_overlay_open = false
		if is_instance_valid(_right_area):
			_right_area.visible = _right_area_prev_visible
		if is_instance_valid(_right_background):
			_right_background.visible = _right_background_prev_visible
		if settings_menu and settings_menu.has_method("hide_settings"):
			settings_menu.call("hide_settings")
	_pending_emit_resume = emit_resume
	# 播放退场动画；动画结束后再解除暂停并隐藏菜单
	_play_hide_animation()

func _cache_animation_layout() -> void:
	if _anim_cached:
		return
	await get_tree().process_frame
	_final_modulate = modulate
	if is_instance_valid(_left_layout):
		_left_layout_final_offsets = Vector2(_left_layout.offset_left, _left_layout.offset_right)
	if is_instance_valid(_left_background):
		_left_background_final_offsets = Vector2(_left_background.offset_left, _left_background.offset_right)
	if is_instance_valid(_left_divider_line):
		_left_divider_final_offsets = Vector2(_left_divider_line.offset_left, _left_divider_line.offset_right)
	if is_instance_valid(_right_area):
		_right_area_final_offsets = Vector2(_right_area.offset_left, _right_area.offset_right)
	if is_instance_valid(_right_background):
		_right_background_final_offsets = Vector2(_right_background.offset_left, _right_background.offset_right)
	_anim_cached = true

func _kill_menu_tween() -> void:
	if _menu_tween and _menu_tween.is_running():
		_menu_tween.kill()
	_menu_tween = null

func _restore_final_layout_for_animation() -> void:
	if not _anim_cached:
		return
	modulate = _final_modulate
	if is_instance_valid(_left_layout):
		_left_layout.offset_left = _left_layout_final_offsets.x
		_left_layout.offset_right = _left_layout_final_offsets.y
	if is_instance_valid(_left_background):
		_left_background.offset_left = _left_background_final_offsets.x
		_left_background.offset_right = _left_background_final_offsets.y
	if is_instance_valid(_left_divider_line):
		_left_divider_line.offset_left = _left_divider_final_offsets.x
		_left_divider_line.offset_right = _left_divider_final_offsets.y
	if is_instance_valid(_right_area):
		_right_area.offset_left = _right_area_final_offsets.x
		_right_area.offset_right = _right_area_final_offsets.y
	if is_instance_valid(_right_background):
		_right_background.offset_left = _right_background_final_offsets.x
		_right_background.offset_right = _right_background_final_offsets.y

func _get_left_group_shift() -> float:
	# 左侧整体滑入距离：优先用左背景宽度（与主界面逻辑一致）
	var shift := 0.0
	if is_instance_valid(_left_background):
		shift = _left_background.size.x
	if shift <= 0.0 and _left_background_final_offsets != Vector2.ZERO:
		shift = absf(_left_background_final_offsets.y - _left_background_final_offsets.x)
	if shift <= 0.0 and is_instance_valid(_left_layout):
		shift = _left_layout.size.x
	if shift <= 0.0:
		shift = 620.0
	return shift

func _play_show_animation() -> void:
	# 等一帧确保Control布局尺寸稳定
	await get_tree().process_frame
	if not _anim_cached:
		await _cache_animation_layout()
	if not visible:
		return

	_kill_menu_tween()
	_restore_final_layout_for_animation()

	# 初始状态：整体淡出+左侧整体移出屏幕
	modulate = Color(_final_modulate.r, _final_modulate.g, _final_modulate.b, 0.0)
	var left_shift := _get_left_group_shift()
	if is_instance_valid(_left_layout):
		_left_layout.offset_left = _left_layout_final_offsets.x - left_shift
		_left_layout.offset_right = _left_layout_final_offsets.y - left_shift
	if is_instance_valid(_left_background):
		_left_background.offset_left = _left_background_final_offsets.x - left_shift
		_left_background.offset_right = _left_background_final_offsets.y - left_shift
	if is_instance_valid(_left_divider_line):
		_left_divider_line.offset_left = _left_divider_final_offsets.x - left_shift
		_left_divider_line.offset_right = _left_divider_final_offsets.y - left_shift

	# 右侧给一个轻微的“回位”动效（不影响布局逻辑）
	var right_shift := 120.0
	if is_instance_valid(_right_area):
		_right_area.offset_left = _right_area_final_offsets.x + right_shift
		_right_area.offset_right = _right_area_final_offsets.y + right_shift
	if is_instance_valid(_right_background):
		_right_background.offset_left = _right_background_final_offsets.x + right_shift
		_right_background.offset_right = _right_background_final_offsets.y + right_shift

	_menu_tween = create_tween()
	_menu_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_menu_tween.set_trans(Tween.TRANS_CUBIC)
	_menu_tween.set_ease(Tween.EASE_OUT)
	# 透明度时长必须不短于右侧滑入时长，避免“还在滑动就先出现/先消失”
	_menu_tween.parallel().tween_property(self, "modulate", _final_modulate, 0.40)
	if is_instance_valid(_left_layout):
		_menu_tween.parallel().tween_property(_left_layout, "offset_left", _left_layout_final_offsets.x, 0.45)
		_menu_tween.parallel().tween_property(_left_layout, "offset_right", _left_layout_final_offsets.y, 0.45)
	if is_instance_valid(_left_background):
		_menu_tween.parallel().tween_property(_left_background, "offset_left", _left_background_final_offsets.x, 0.45)
		_menu_tween.parallel().tween_property(_left_background, "offset_right", _left_background_final_offsets.y, 0.45)
	if is_instance_valid(_left_divider_line):
		_menu_tween.parallel().tween_property(_left_divider_line, "offset_left", _left_divider_final_offsets.x, 0.45)
		_menu_tween.parallel().tween_property(_left_divider_line, "offset_right", _left_divider_final_offsets.y, 0.45)
	if is_instance_valid(_right_area):
		_menu_tween.parallel().tween_property(_right_area, "offset_left", _right_area_final_offsets.x, 0.40)
		_menu_tween.parallel().tween_property(_right_area, "offset_right", _right_area_final_offsets.y, 0.40)
	if is_instance_valid(_right_background):
		_menu_tween.parallel().tween_property(_right_background, "offset_left", _right_background_final_offsets.x, 0.40)
		_menu_tween.parallel().tween_property(_right_background, "offset_right", _right_background_final_offsets.y, 0.40)
	_menu_tween.finished.connect(func() -> void:
		if is_instance_valid(continue_button):
			continue_button.grab_focus()
	)

func _play_hide_animation() -> void:
	if not visible:
		return
	# 确保布局缓存已就绪，避免首次打开后立刻关闭导致offset为0的跳动
	await get_tree().process_frame
	if not _anim_cached:
		await _cache_animation_layout()

	_kill_menu_tween()
	_restore_final_layout_for_animation()

	var left_shift := _get_left_group_shift()
	var right_shift := 120.0
	_menu_tween = create_tween()
	_menu_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_menu_tween.set_trans(Tween.TRANS_CUBIC)
	_menu_tween.set_ease(Tween.EASE_IN)
	# 透明度时长必须不短于右侧滑出时长，避免滑动过程中提前消失
	_menu_tween.parallel().tween_property(self, "modulate", Color(_final_modulate.r, _final_modulate.g, _final_modulate.b, 0.0), 0.30)
	if is_instance_valid(_left_layout):
		_menu_tween.parallel().tween_property(_left_layout, "offset_left", _left_layout_final_offsets.x - left_shift, 0.24)
		_menu_tween.parallel().tween_property(_left_layout, "offset_right", _left_layout_final_offsets.y - left_shift, 0.24)
	if is_instance_valid(_left_background):
		_menu_tween.parallel().tween_property(_left_background, "offset_left", _left_background_final_offsets.x - left_shift, 0.24)
		_menu_tween.parallel().tween_property(_left_background, "offset_right", _left_background_final_offsets.y - left_shift, 0.24)
	if is_instance_valid(_left_divider_line):
		_menu_tween.parallel().tween_property(_left_divider_line, "offset_left", _left_divider_final_offsets.x - left_shift, 0.24)
		_menu_tween.parallel().tween_property(_left_divider_line, "offset_right", _left_divider_final_offsets.y - left_shift, 0.24)
	if is_instance_valid(_right_area):
		_menu_tween.parallel().tween_property(_right_area, "offset_left", _right_area_final_offsets.x + right_shift, 0.30)
		_menu_tween.parallel().tween_property(_right_area, "offset_right", _right_area_final_offsets.y + right_shift, 0.30)
	if is_instance_valid(_right_background):
		_menu_tween.parallel().tween_property(_right_background, "offset_left", _right_background_final_offsets.x + right_shift, 0.30)
		_menu_tween.parallel().tween_property(_right_background, "offset_right", _right_background_final_offsets.y + right_shift, 0.30)
	_menu_tween.finished.connect(func() -> void:
		visible = false
		# 恢复游戏树，所有暂停的内容会自动恢复
		get_tree().paused = false
		# 只有“继续游戏/关闭菜单回战斗”才恢复准星；返回主菜单则保持默认鼠标。
		if not _pending_go_to_main_menu:
			_apply_battle_cursor()
		_restore_final_layout_for_animation()
		if _pending_emit_resume:
			_pending_emit_resume = false
			resume_game.emit()
		if _pending_go_to_main_menu:
			_pending_go_to_main_menu = false
			return_to_main_menu.emit()
			if GameManager:
				GameManager.go_to_main_menu()
	)

## 确保重击动画在暂停时保持可见
func _preserve_charged_effect_visibility() -> void:
	# 查找场景中的玩家角色
	var battle_manager = get_tree().get_first_node_in_group("battle_manager")
	if not battle_manager:
		var scene_root = get_tree().current_scene
		if scene_root != null and scene_root is BattleManager:
			battle_manager = scene_root
	
	if battle_manager and battle_manager.has_method("get_player"):
		var player = battle_manager.get_player()
		if player and player.has_method("get_charged_effect"):
			var charged_effect = player.get_charged_effect()
			if charged_effect:
				# 如果动画正在播放且可见，确保它在暂停时保持可见
				# AnimatedSprite2D在暂停时会自动保持当前帧
				# 我们只需要确保它不会被动画完成信号隐藏
				if charged_effect.visible and charged_effect.is_playing():
					# 动画会保持当前帧，不需要额外操作
					pass

## 更新角色信息显示
func update_character_info() -> void:
	if not RunManager or not RunManager.current_character:
		return
	
	var character_data = RunManager.current_character
	
	# 更新角色名称
	if character_name_label:
		character_name_label.text = character_data.display_name
	
	# 更新角色立绘
	if character_portrait:
		# 尝试加载角色立绘
		var portrait_path = _get_character_portrait_path(character_data.id)
		if portrait_path:
			var portrait_texture: Texture2D = null
			if DataManager:
				portrait_texture = DataManager.get_texture(portrait_path)
			else:
				portrait_texture = load(portrait_path) as Texture2D
			if portrait_texture:
				character_portrait.texture = portrait_texture
				character_portrait.visible = true
				print("已加载角色立绘: ", portrait_path)
			else:
				print("警告：无法加载立绘文件: ", portrait_path)
				# 如果没有立绘，尝试使用icon
				if character_data.icon:
					character_portrait.texture = character_data.icon
					character_portrait.visible = true
				else:
					character_portrait.visible = false
		elif character_data.icon:
			character_portrait.texture = character_data.icon
			character_portrait.visible = true
		else:
			character_portrait.visible = false
			print("警告：角色没有立绘或图标")
	
	# 更新摩拉显示
	_update_gold_display()
	
	# 更新角色属性
	_update_stats_display()
	_update_weapon_display()
	
	# 更新已选择升级
	_update_upgrades_display()
	
	# 更新圣遗物显示
	_update_artifacts_display()

## 获取角色立绘路径
func _get_character_portrait_path(character_id: String) -> String:
	# 根据角色ID构建立绘路径
	match character_id:
		"kamisato_ayaka":
			return "res://textures/characters/kamisato_ayaka/portraits/ayaka角色立绘.png"
		"nahida":
			return "res://textures/characters/nahida/portraits/nahida角色立绘.png"
		_:
			return ""

## 更新摩拉显示
func _update_gold_display() -> void:
	if gold_label and RunManager:
		gold_label.text = "摩拉: %d" % RunManager.gold

## 更新属性显示
func _update_stats_display() -> void:
	if not is_instance_valid(stats_container):
		return
	if not RunManager or not RunManager.current_character:
		return
	
	var character_data = RunManager.current_character
	var stats = character_data.get_stats()
	
	# 获取当前玩家实例（如果存在）
	var current_hp = RunManager.health
	var max_hp = RunManager.max_health
	
	# 如果战斗场景中有玩家实例，使用实时数据
	var battle_manager = get_tree().get_first_node_in_group("battle_manager")
	if not battle_manager:
		# 查找场景根节点（通常是BattleManager）
		var scene_root = get_tree().current_scene
		if scene_root and scene_root is BattleManager:
			battle_manager = scene_root
	
	if battle_manager and battle_manager.has_method("get_player"):
		var player = battle_manager.get_player()
		if player:
			current_hp = player.current_health
			max_hp = player.max_health
			if player.current_stats:
				stats = player.current_stats
	
	# 更新各个属性标签
	var labels = stats_container.get_children()
	if labels.size() >= 7:
		labels[0].text = "生命值: %d/%d" % [int(current_hp), int(max_hp)]
		labels[1].text = "攻击力: %.0f" % stats.attack
		labels[2].text = "防御: %.0f%%" % (stats.defense_percent * 100)
		labels[3].text = "移动速度: %.0f" % stats.move_speed
		labels[4].text = "暴击率: %.0f%%" % (stats.crit_rate * 100)
		labels[5].text = "暴击伤害: +%.0f%%" % (stats.crit_damage * 100)
		labels[6].text = "攻击速度: %.1fx" % stats.attack_speed

## 更新已选择升级显示
func _update_upgrades_display() -> void:
	if not is_instance_valid(upgrades_container):
		return
	
	# 清空现有升级显示
	for child in upgrades_container.get_children():
		child.queue_free()
	
	# 如果没有 RunManager 或没有升级，显示提示
	if not RunManager or RunManager.upgrades.is_empty():
		var empty_label = Label.new()
		empty_label.text = "暂无升级"
		empty_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		upgrades_container.add_child(empty_label)
		return
	
	# 检查是否有 UpgradeRegistry
	var registry = UpgradeRegistry if is_instance_valid(UpgradeRegistry) else null
	
	# 遍历所有已选择的升级
	for upgrade_id in RunManager.upgrades:
		var level = RunManager.upgrades[upgrade_id]
		
		# 创建升级项容器
		var upgrade_item = PanelContainer.new()
		upgrade_item.custom_minimum_size = Vector2(0, 70)
		
		# 设置背景样式
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(1, 1, 1, 0.96)
		style_box.border_color = Color(0, 0, 0, 0.75)
		style_box.border_width_left = 2
		style_box.border_width_right = 2
		style_box.border_width_top = 2
		style_box.border_width_bottom = 2
		style_box.corner_radius_top_left = 12
		style_box.corner_radius_top_right = 12
		style_box.corner_radius_bottom_left = 12
		style_box.corner_radius_bottom_right = 12
		upgrade_item.add_theme_stylebox_override("panel", style_box)
		
		var vbox = VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.add_theme_constant_override("separation", 4)
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_bottom", 6)
		margin.add_child(vbox)
		upgrade_item.add_child(margin)
		
		# 创建名称和等级标签
		var name_hbox = HBoxContainer.new()
		vbox.add_child(name_hbox)
		
		var name_label = Label.new()
		name_label.text = upgrade_id
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
		name_hbox.add_child(name_label)
		
		# 如果有 UpgradeRegistry，获取详细信息
		if registry and registry.has_method("get_upgrade"):
			var upgrade_data = registry.get_upgrade(upgrade_id)
			if upgrade_data:
				# 使用升级数据的显示名称
				name_label.text = upgrade_data.display_name
				
				# 设置稀有度颜色
				var rarity_color = upgrade_data.get_rarity_color()
				name_label.add_theme_color_override("font_color", rarity_color)
				
				# 添加等级标签
				var level_label = Label.new()
				level_label.text = "Lv.%d" % level
				if upgrade_data.max_level > 0:
					level_label.text += "/%d" % upgrade_data.max_level
				level_label.add_theme_font_size_override("font_size", 16)
				level_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
				name_hbox.add_child(level_label)
				
				# 添加描述标签
				var desc_label = Label.new()
				desc_label.text = upgrade_data.get_formatted_description(level)
				desc_label.add_theme_font_size_override("font_size", 14)
				desc_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
				desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				vbox.add_child(desc_label)
			else:
				# 如果没有找到升级数据，显示ID和等级
				var level_label = Label.new()
				level_label.text = " (Lv.%d)" % level
				level_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
				name_hbox.add_child(level_label)
		else:
			# 如果没有 UpgradeRegistry，只显示ID和等级
			var level_label = Label.new()
			level_label.text = " (Lv.%d)" % level
			level_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
			name_hbox.add_child(level_label)
		
		# 添加间距
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 4)
		upgrades_container.add_child(upgrade_item)
		upgrades_container.add_child(spacer)

func _on_artifacts_pressed() -> void:
	# 进入其它界面前必须解除暂停，否则新场景会被 paused 卡住无法输入
	get_tree().paused = false
	visible = false
	if GameManager and GameManager.has_method("show_artifact_selection"):
		GameManager.show_artifact_selection()

## 更新圣遗物显示
func _update_artifacts_display() -> void:
	if not is_instance_valid(artifacts_container):
		return
	
	# 清空现有显示
	for child in artifacts_container.get_children():
		child.queue_free()
	
	# 如果没有角色节点，显示空槽位
	if not RunManager or not RunManager.current_character_node:
		_create_empty_artifact_slots()
		return
	
	var artifact_manager = RunManager.current_character_node.get_artifact_manager()
	if not artifact_manager:
		_create_empty_artifact_slots()
		return
	
	# 为每个槽位创建显示
	for slot in ArtifactSlot.get_all_slots():
		var artifact = artifact_manager.get_artifact(slot)
		var level = artifact_manager.get_artifact_level(slot) if artifact else -1
		_create_artifact_slot_display(slot, artifact, level)

## 创建空槽位显示
func _create_empty_artifact_slots() -> void:
	for slot in ArtifactSlot.get_all_slots():
		_create_artifact_slot_display(slot, null, -1)

## 创建圣遗物槽位显示
func _create_artifact_slot_display(slot: ArtifactSlot.SlotType, artifact: ArtifactData, level: int) -> void:
	# 创建槽位容器
	var slot_container = VBoxContainer.new()
	slot_container.custom_minimum_size = Vector2(80, 100)
	slot_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# 创建图标（只展示，不处理点击；跳转只通过右侧“至遗物”按钮）
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(64, 64)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 设置图标
	var icon_path = ""
	if artifact:
		# 已装备：显示圣遗物图标
		icon_path = _get_artifact_icon_path(artifact.name)
	else:
		# 未装备：显示槽位图标
		icon_path = _get_slot_icon_path(slot)
	# 已装备但没有专属图标时，回退显示槽位图标（避免空白）
	if artifact and icon_path.is_empty():
		icon_path = _get_slot_icon_path(slot)
	
	if icon_path:
		var icon: Texture2D = null
		if DataManager:
			icon = DataManager.get_texture(icon_path)
		else:
			icon = load(icon_path) as Texture2D
		if icon:
			icon_rect.texture = icon
	
	# 设置工具提示
	icon_rect.tooltip_text = ""
	if artifact:
		icon_rect.mouse_entered.connect(_on_artifact_icon_mouse_entered.bind(slot, artifact))
		icon_rect.mouse_exited.connect(_on_artifact_icon_mouse_exited)
	
	# 鼠标悬停时改变光标
	icon_rect.mouse_default_cursor_shape = Control.CURSOR_ARROW
	
	slot_container.add_child(icon_rect)
	
	# 添加等级指示（如果已装备）
	if artifact and level >= 0:
		var level_label = Label.new()
		level_label.text = "已装备"
		level_label.add_theme_font_size_override("font_size", 12)
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		slot_container.add_child(level_label)
	
	artifacts_container.add_child(slot_container)

## 创建圣遗物工具提示文本
func _create_artifact_tooltip(slot: ArtifactSlot.SlotType, artifact: ArtifactData, level: int) -> String:
	var tooltip_lines: Array[String] = []
	
	if artifact:
		# 已装备的圣遗物
		tooltip_lines.append(artifact.name)
		tooltip_lines.append("槽位: %s" % ArtifactSlot.get_slot_name(slot))
		tooltip_lines.append("")
		tooltip_lines.append("属性加成:")
		
		var bonuses = artifact.get_all_stat_bonuses()
		for stat_name in bonuses:
			var base_value = bonuses[stat_name]
			var actual_value = base_value
			var stat_display_name = _get_stat_display_name(stat_name)
			var formatted_value = _format_stat_value(stat_name, actual_value)
			tooltip_lines.append("  %s: %s" % [stat_display_name, formatted_value])
	else:
		# 未装备的槽位
		tooltip_lines.append(ArtifactSlot.get_slot_name(slot))
		tooltip_lines.append("未装备")
	
	return "\n".join(tooltip_lines)

## 获取圣遗物图标路径
func _get_artifact_icon_path(artifact_name: String) -> String:
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

## 获取槽位图标路径
func _get_slot_icon_path(slot: ArtifactSlot.SlotType) -> String:
	match slot:
		ArtifactSlot.SlotType.FLOWER:
			return "res://textures/ui/生之花.png"
		ArtifactSlot.SlotType.PLUME:
			return "res://textures/ui/死之羽.png"
		ArtifactSlot.SlotType.SANDS:
			return "res://textures/ui/时之沙.png"
		ArtifactSlot.SlotType.GOBLET:
			return "res://textures/ui/空之杯.png"
		ArtifactSlot.SlotType.CIRCLET:
			return "res://textures/ui/理之冠.png"
		_:
			return ""

## 获取属性显示名称
func _get_stat_display_name(stat_name: String) -> String:
	match stat_name:
		"max_health":
			return "生命值"
		"max_health_percent":
			return "生命值百分比"
		"defense_percent":
			return "减伤"
		"attack":
			return "攻击力"
		"damage_multiplier":
			return "总伤"
		"attack_percent":
			return "攻击力百分比"
		"attack_speed":
			return "攻击速度"
		"knockback_force":
			return "击退"
		"crit_rate":
			return "暴击率"
		"crit_damage":
			return "暴击伤害"
		"move_speed":
			return "移动速度"
		_:
			return stat_name

## 格式化属性值显示
func _format_stat_value(stat_name: String, value: float) -> String:
	# 百分比属性显示为百分比
	if stat_name == "defense_percent" or stat_name == "crit_rate" or stat_name == "attack_percent" or stat_name == "crit_damage" or stat_name == "damage_multiplier" or stat_name == "max_health_percent":
		return "%.1f%%" % (value * 100.0)
	# 其他属性显示为数值
	return "%.1f" % value

## 继续游戏按钮
func _on_continue_pressed() -> void:
	hide_menu(true)

## 设置按钮
func _on_settings_pressed() -> void:
	open_settings.emit()
	# 暂停菜单内：设置从右侧滑入/滑出（再次点击设置可关闭）
	if _settings_overlay_open:
		_close_settings_overlay()
		return
	_open_settings_overlay()

## 设置界面关闭回调
func _on_settings_closed() -> void:
	print("设置界面已关闭")
	_settings_overlay_open = false
	if is_instance_valid(settings_button):
		settings_button.grab_focus()

## 返回主菜单按钮
func _on_main_menu_pressed() -> void:
	_pending_go_to_main_menu = true
	hide_menu(false)

## 为菜单按钮添加鼠标悬停/键盘焦点动画（复用主界面交互风格）
func _setup_menu_hover_effects() -> void:
	if continue_button:
		_bind_hover_for_button(continue_button)
	if settings_button:
		_bind_hover_for_button(settings_button)
	if main_menu_button:
		_bind_hover_for_button(main_menu_button)

func _bind_hover_for_button(button: Button) -> void:
	var row := button.get_parent() as Node
	if row == null:
		return
	var indicator_space := row.get_node_or_null("IndicatorSpace") as Control
	if indicator_space == null:
		return
	var indicator := indicator_space.get_node_or_null("CenterContainer/Indicator") as ColorRect
	if indicator == null:
		return

	# 初始化为“未悬停”状态
	indicator.visible = false
	indicator.modulate = Color(1, 1, 1, 0)
	indicator_space.custom_minimum_size = Vector2(0, 0)

	if not button.mouse_entered.is_connected(_on_menu_button_mouse_entered.bind(row)):
		button.mouse_entered.connect(_on_menu_button_mouse_entered.bind(row))
	if not button.mouse_exited.is_connected(_on_menu_button_mouse_exited.bind(row)):
		button.mouse_exited.connect(_on_menu_button_mouse_exited.bind(row))
	if not button.focus_entered.is_connected(_on_menu_button_mouse_entered.bind(row)):
		button.focus_entered.connect(_on_menu_button_mouse_entered.bind(row))
	if not button.focus_exited.is_connected(_on_menu_button_mouse_exited.bind(row)):
		button.focus_exited.connect(_on_menu_button_mouse_exited.bind(row))

func _on_menu_button_mouse_entered(row: Node) -> void:
	_play_hover_animation(row, true)

func _on_menu_button_mouse_exited(row: Node) -> void:
	_play_hover_animation(row, false)

func _play_hover_animation(row: Node, hovered: bool) -> void:
	var indicator_space := row.get_node_or_null("IndicatorSpace") as Control
	if indicator_space == null:
		return
	var indicator := indicator_space.get_node_or_null("CenterContainer/Indicator") as ColorRect
	if indicator == null:
		return

	# 打断旧Tween，避免快速移入移出时抖动
	var old_tween: Tween = _hover_tweens.get(row)
	if old_tween and old_tween.is_running():
		old_tween.kill()

	var tween := create_tween()
	_hover_tweens[row] = tween
	if hovered:
		indicator.visible = true
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(indicator_space, "custom_minimum_size", Vector2(18, 0), 0.12)
		tween.parallel().tween_property(indicator, "modulate", Color(1, 1, 1, 1), 0.12)
	else:
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(indicator_space, "custom_minimum_size", Vector2(0, 0), 0.12)
		tween.parallel().tween_property(indicator, "modulate", Color(1, 1, 1, 0), 0.12)
		tween.finished.connect(func() -> void:
			# 退出后隐藏Indicator，避免遮挡点击/影响布局
			if is_instance_valid(indicator):
				indicator.visible = false
		)

## 处理ESC键（由外部调用或内部调用）
func handle_esc_key() -> void:
	if visible:
		# 如果设置侧滑已打开，先关闭设置
		if _settings_overlay_open:
			_close_settings_overlay()
			return
		# 如果菜单已显示，关闭它
		hide_menu()
	else:
		# 如果菜单未显示，打开它
		show_menu()

func _input(event: InputEvent) -> void:
	# 确保暂停菜单可以响应ESC键
	# 只有在菜单可见时才处理ESC键（关闭菜单）
	# 打开菜单由battle_manager处理
	if event.is_action_pressed("esc") and visible:
		# 设置界面打开时，ESC 先关闭设置（不直接关暂停菜单）
		if _settings_overlay_open:
			_close_settings_overlay()
		else:
			hide_menu()
		get_viewport().set_input_as_handled()
