extends Node2D

# 主界面背景图目录（每次进入主界面随机抽取一张）
const MAIN_MENU_BACKGROUND_DIR: String = "res://textures/background"
const _MAIN_MENU_BG_EXTS: PackedStringArray = ["png", "jpg", "jpeg", "webp"]

const _MAIN_MENU_BG_FALLBACK_PATHS: PackedStringArray = [
	"res://textures/background/00131-3390311460.png",
	"res://textures/background/00161-1240093822.png",
	"res://textures/background/00183-1277078224.png",
]

const _MAIN_MENU_BG_FALLBACK_PRELOADS: Array[Texture2D] = [
	preload("res://textures/background/00131-3390311460.png"),
	preload("res://textures/background/00161-1240093822.png"),
	preload("res://textures/background/00183-1277078224.png"),
]

const _BG_HISTORY_FILE_PATH: String = "user://main_menu_bg.cfg"
const _BG_HISTORY_SECTION: String = "main_menu"
const _BG_HISTORY_KEY_LAST_BG: String = "last_background"

const _SETTINGS_SCENE: PackedScene = preload("res://scenes/ui/settings.tscn")
const _CHARACTER_SELECT_PANEL_SCENE: PackedScene = preload("res://scenes/ui/character_select_panel.tscn")

# 预加载游戏场景
var game_scene = preload("res://scenes/battle/battle_scene.tscn")

# 左侧菜单引用（用于进入主菜单时的滑入动画）
@onready var left_menu: Control = $CanvasLayer/LeftMenu

# 背景图节点引用
@onready var background_rect: TextureRect = $CanvasLayer/Background

# 左侧像素边缘（与右侧UI联动）
@onready var left_edge_fade: ColorRect = $CanvasLayer/LeftMenu/EdgeFade

# 左侧灰色面板本体（用于和右侧面板无缝拼接）
@onready var left_panel_bg: Panel = $CanvasLayer/LeftMenu/PanelBg

# 右侧遮罩抽屉引用
@onready var right_overlay: Control = $CanvasLayer/RightOverlay
@onready var right_drawer: Control = $CanvasLayer/RightOverlay/Drawer
@onready var right_mask: ColorRect = $CanvasLayer/RightOverlay/Drawer/Mask
@onready var right_content_holder: Control = $CanvasLayer/RightOverlay/Drawer/ContentHolder

# 游戏说明节点引用（已放入右侧抽屉内）
@onready var help_panel: Panel = $CanvasLayer/RightOverlay/Drawer/ContentHolder/Panel
@onready var close_button: Button = $CanvasLayer/RightOverlay/Drawer/ContentHolder/Panel/CloseButton

# 设置界面引用
var settings_menu: Control = null

# 角色选择面板引用（嵌入右侧抽屉，不切场景）
var character_select_panel: Control = null

# 菜单按钮引用（在_ready里赋值，避免场景结构变动导致的硬路径问题）
var _start_button: Button = null
var _help_button: Button = null
var _settings_button: Button = null
var _cg_button: Button = null
var _quit_button: Button = null

var cg_gallery_panel: CGGalleryPanel = null

const _SETTINGS_FILE_PATH: String = "user://settings.cfg"
const _SETTINGS_SECTION_UI: String = "ui"
const _SETTINGS_KEY_NSFW_ENABLED: String = "nsfw_enabled"

# 记录每个菜单项的悬停Tween，便于快速移入移出时打断/复用
var _hover_tweens: Dictionary = {}

# 进入主菜单滑入动画Tween
var _intro_tween: Tween = null

# 右侧抽屉动画Tween
var _overlay_tween: Tween = null

# 左侧边缘强度（1=显示像素边缘，0=完全隐藏）
var _left_edge_strength: float = 1.0

# 背景图候选缓存（目录内容运行期不会变化，缓存可减少IO/遍历）
var _background_candidates_cache: PackedStringArray = []

# 当场景加载完成时调用
func _ready() -> void:
	# 进入主界面时随机背景图
	_apply_random_background()

	# 连接按钮信号
	# 注意：主菜单UI节点已重构为左侧菜单结构，因此这里通过find_child按名称获取按钮
	_start_button = $CanvasLayer.find_child("Button", true, false) as Button
	_help_button = $CanvasLayer.find_child("Button2", true, false) as Button
	_settings_button = $CanvasLayer.find_child("Button4", true, false) as Button
	_cg_button = $CanvasLayer.find_child("Button5", true, false) as Button
	_quit_button = $CanvasLayer.find_child("Button3", true, false) as Button
	
	if _start_button:
		_start_button.pressed.connect(_on_start_button_pressed)
	if _help_button:
		_help_button.pressed.connect(_on_help_button_pressed)
	if _settings_button:
		_settings_button.pressed.connect(_on_settings_button_pressed)
	if _cg_button:
		_cg_button.pressed.connect(_on_cg_button_pressed)
	if _quit_button:
		_quit_button.pressed.connect(_on_quit_button_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	# 设置帮助弹窗初始状态为隐藏
	if help_panel:
		help_panel.hide()

	# 右侧抽屉初始隐藏
	_setup_right_overlay_initial_state()

	# 左侧像素边缘初始显示（右侧UI未打开）
	_set_left_edge_strength(1.0)

	# 播放左侧菜单滑入动画
	_play_intro_animation()

	# 绑定菜单项悬停效果：蓝色方块出现 + 推挤文字
	_setup_menu_hover_effects()
	
	# 加载设置界面
	_load_settings_menu()
	_load_character_select_panel()
	_load_cg_gallery_panel()
	_update_cg_button_enabled_state_from_settings()
	
	print("主界面脚本已加载，帮助弹窗已初始化")

func _apply_random_background() -> void:
	if not is_instance_valid(background_rect):
		return
	var candidates := _collect_background_candidates()
	if candidates.is_empty():
		return
	var last_bg_path: String = _load_last_background_path()
	var rng: RandomNumberGenerator = null
	if RunManager and RunManager.has_method("get_rng"):
		rng = RunManager.get_rng() as RandomNumberGenerator
	if not rng:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var max_attempts: int = maxi(6, candidates.size() * 2)
	for _i in range(max_attempts):
		var idx := rng.randi_range(0, candidates.size() - 1)
		var path: String = String(candidates[idx])
		if candidates.size() > 1 and not last_bg_path.is_empty() and path == last_bg_path:
			continue
		var tex := load(path) as Texture2D
		if tex:
			background_rect.texture = tex
			_save_last_background_path(path)
			return

	for path_any in candidates:
		var tex_any := load(String(path_any)) as Texture2D
		if tex_any:
			background_rect.texture = tex_any
			_save_last_background_path(String(path_any))
			return


func _load_last_background_path() -> String:
	var config := ConfigFile.new()
	var err: Error = config.load(_BG_HISTORY_FILE_PATH)
	if err != OK:
		return ""
	return String(config.get_value(_BG_HISTORY_SECTION, _BG_HISTORY_KEY_LAST_BG, ""))


func _save_last_background_path(path: String) -> void:
	var config := ConfigFile.new()
	config.set_value(_BG_HISTORY_SECTION, _BG_HISTORY_KEY_LAST_BG, path)
	config.save(_BG_HISTORY_FILE_PATH)

func _get_background_candidates_cached() -> PackedStringArray:
	if not _background_candidates_cache.is_empty():
		return _background_candidates_cache
	_background_candidates_cache = _collect_background_candidates()
	return _background_candidates_cache


func _collect_background_candidates() -> PackedStringArray:
	var result: PackedStringArray = []
	var dir := DirAccess.open(MAIN_MENU_BACKGROUND_DIR)
	if dir == null:
		return _MAIN_MENU_BG_FALLBACK_PATHS

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if dir.current_is_dir():
			continue
		var ext := name.get_extension().to_lower()
		if ext in _MAIN_MENU_BG_EXTS:
			result.append(MAIN_MENU_BACKGROUND_DIR.path_join(name))
	dir.list_dir_end()
	if result.is_empty():
		return _MAIN_MENU_BG_FALLBACK_PATHS
	return result

func _setup_right_overlay_initial_state() -> void:
	if not is_instance_valid(right_overlay) or not is_instance_valid(right_drawer):
		return
	right_overlay.visible = false
	# Drawer锚在右侧：隐藏态完全在屏幕外（右侧），显示态与左侧面板无缝拼接
	await get_tree().process_frame
	var w := _get_right_drawer_width()
	right_drawer.offset_left = 0.0
	right_drawer.offset_right = w

func _get_right_drawer_width() -> float:
	# 右侧抽屉宽度 = 屏幕宽度 - 左侧灰面板(PanelBg)右边缘X
	# 注意：LeftMenu 右侧还包含 EdgeFade 的占位区域（即使strength=0也会占位），
	# 所以这里必须用 PanelBg 的右边界作为拼接基准，否则会出现“透明缝”。
	var viewport_w := get_viewport().get_visible_rect().size.x
	var seam_x := 0.0
	if is_instance_valid(left_panel_bg):
		seam_x = left_panel_bg.get_global_rect().end.x
	elif is_instance_valid(left_menu):
		seam_x = left_menu.get_global_rect().end.x
	# 像素对齐，避免出现 1px 细缝
	var vw_i := float(floori(int(viewport_w)))
	var seam_i := float(floori(int(seam_x)))
	return maxf(0.0, vw_i - seam_i)

func _set_left_edge_strength(v: float) -> void:
	_left_edge_strength = v
	if not is_instance_valid(left_edge_fade):
		return
	var mat := left_edge_fade.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("strength", v)

func _show_right_overlay(show_help: bool, show_settings: bool, show_cg: bool) -> void:
	if not is_instance_valid(right_overlay) or not is_instance_valid(right_drawer):
		return
	var was_open := right_overlay.visible
	right_overlay.visible = true

	if is_instance_valid(help_panel):
		help_panel.visible = show_help
	if is_instance_valid(settings_menu):
		settings_menu.visible = show_settings
	if is_instance_valid(cg_gallery_panel):
		cg_gallery_panel.visible = show_cg
	if is_instance_valid(character_select_panel) and (show_help or show_settings or show_cg):
		character_select_panel.visible = false

	await get_tree().process_frame
	var w := _get_right_drawer_width()
	if w <= 0.0:
		return

	# 目标位置：抽屉在屏幕内（右边缘贴齐）
	var final_left := -w
	var final_right := 0.0

	# 如果已经打开（抽屉在位），直接切换内容即可，不重复播放滑入动画
	if was_open and absf(right_drawer.offset_left - final_left) < 0.5 and absf(right_drawer.offset_right - final_right) < 0.5:
		_set_left_edge_strength(0.0)
		return

	# 隐藏态：完全在屏幕右侧外
	right_drawer.offset_left = 0.0
	right_drawer.offset_right = w

	if _overlay_tween and _overlay_tween.is_running():
		_overlay_tween.kill()
	_overlay_tween = create_tween()
	_overlay_tween.set_trans(Tween.TRANS_CUBIC)
	_overlay_tween.set_ease(Tween.EASE_OUT)
	_overlay_tween.parallel().tween_property(right_drawer, "offset_left", final_left, 0.32)
	_overlay_tween.parallel().tween_property(right_drawer, "offset_right", final_right, 0.32)
	# 右侧UI出现时，让左侧像素边缘渐隐消失，形成“结合”视觉
	_overlay_tween.parallel().tween_method(_set_left_edge_strength, _left_edge_strength, 0.0, 0.32)

func _hide_right_overlay() -> void:
	if not is_instance_valid(right_overlay) or not is_instance_valid(right_drawer):
		return
	await get_tree().process_frame
	var w := _get_right_drawer_width()

	if _overlay_tween and _overlay_tween.is_running():
		_overlay_tween.kill()
	_overlay_tween = create_tween()
	_overlay_tween.set_trans(Tween.TRANS_CUBIC)
	_overlay_tween.set_ease(Tween.EASE_OUT)
	_overlay_tween.parallel().tween_property(right_drawer, "offset_left", 0.0, 0.24)
	_overlay_tween.parallel().tween_property(right_drawer, "offset_right", w, 0.24)
	# 右侧UI收回后，恢复左侧像素边缘
	_overlay_tween.parallel().tween_method(_set_left_edge_strength, _left_edge_strength, 1.0, 0.24)
	_overlay_tween.finished.connect(func() -> void:
		if is_instance_valid(right_overlay):
			right_overlay.visible = false
	)

## 播放进入主菜单时的滑入动画
func _play_intro_animation() -> void:
	if not is_instance_valid(left_menu):
		return
	# 等一帧确保Control布局尺寸已刷新（anchors/layout_mode变化时size可能在_ready时还未稳定）
	await get_tree().process_frame
	var w := left_menu.size.x
	if w <= 0.0:
		w = left_menu.get_rect().size.x
	# 用offset驱动比position更稳：将整个LeftMenu向左平移一个自身宽度，再Tween回原位
	var final_left := left_menu.offset_left
	var final_right := left_menu.offset_right
	left_menu.offset_left = final_left - w
	left_menu.offset_right = final_right - w
	if _intro_tween and _intro_tween.is_running():
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.set_trans(Tween.TRANS_CUBIC)
	_intro_tween.set_ease(Tween.EASE_OUT)
	_intro_tween.parallel().tween_property(left_menu, "offset_left", final_left, 0.45)
	_intro_tween.parallel().tween_property(left_menu, "offset_right", final_right, 0.45)

## 为菜单按钮添加鼠标悬停动画
func _setup_menu_hover_effects() -> void:
	if _start_button:
		_bind_hover_for_button(_start_button)
	if _help_button:
		_bind_hover_for_button(_help_button)
	if _settings_button:
		_bind_hover_for_button(_settings_button)
	if _cg_button:
		_bind_hover_for_button(_cg_button)
	if _quit_button:
		_bind_hover_for_button(_quit_button)


func _load_cg_gallery_panel() -> void:
	if cg_gallery_panel != null:
		return
	cg_gallery_panel = CGGalleryPanel.new()
	if not cg_gallery_panel:
		return
	if is_instance_valid(right_content_holder):
		right_content_holder.add_child(cg_gallery_panel)
		cg_gallery_panel.visible = false
		cg_gallery_panel.closed.connect(_on_cg_gallery_closed)

func _load_character_select_panel() -> void:
	if character_select_panel != null:
		return
	if not _CHARACTER_SELECT_PANEL_SCENE:
		return
	character_select_panel = _CHARACTER_SELECT_PANEL_SCENE.instantiate()
	if character_select_panel == null:
		return
	if is_instance_valid(right_content_holder):
		right_content_holder.add_child(character_select_panel)
		character_select_panel.visible = false
		if character_select_panel.has_signal("closed"):
			character_select_panel.closed.connect(_on_character_select_closed)

func _on_character_select_closed() -> void:
	_hide_right_overlay()

func _bind_hover_for_button(button: Button) -> void:
	# 通过按钮父节点(HBoxContainer)定位IndicatorSpace与Indicator
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

	# 鼠标进入/离开
	if not button.mouse_entered.is_connected(_on_menu_button_mouse_entered.bind(row)):
		button.mouse_entered.connect(_on_menu_button_mouse_entered.bind(row))
	if not button.mouse_exited.is_connected(_on_menu_button_mouse_exited.bind(row)):
		button.mouse_exited.connect(_on_menu_button_mouse_exited.bind(row))
	# 键盘焦点进入/离开（方向键/手柄导航时也有同款高亮反馈）
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

## 加载设置界面
func _load_settings_menu() -> void:
	if _SETTINGS_SCENE:
		settings_menu = _SETTINGS_SCENE.instantiate()
		if settings_menu:
			# 添加到右侧抽屉内容容器下
			if is_instance_valid(right_content_holder):
				right_content_holder.add_child(settings_menu)
				# 内嵌到抽屉时隐藏其自带的黑色背景，避免叠加遮罩
				var bg := settings_menu.get_node_or_null("Background") as CanvasItem
				if bg:
					bg.visible = false
				# 连接设置界面关闭信号
				if settings_menu.has_signal("settings_closed"):
					settings_menu.settings_closed.connect(_on_settings_closed)
				if settings_menu.has_signal("nsfw_changed"):
					settings_menu.nsfw_changed.connect(_on_nsfw_changed)
				print("设置界面已加载")
				_update_cg_button_enabled_state_from_settings()

# 开始游戏按钮回调
func _on_start_button_pressed() -> void:
	print("开始游戏按钮被点击")
	# 打开右侧抽屉显示角色选择（不切场景）
	if character_select_panel and character_select_panel.has_method("show_panel"):
		character_select_panel.show_panel()
	_show_right_overlay(false, false, false)
	if is_instance_valid(help_panel):
		help_panel.visible = false
	if is_instance_valid(settings_menu):
		settings_menu.visible = false
	if is_instance_valid(cg_gallery_panel):
		cg_gallery_panel.visible = false
	if is_instance_valid(character_select_panel):
		character_select_panel.visible = true
	# 复用同款抽屉动画
	await get_tree().process_frame
	_show_right_overlay(false, false, false)

# 游戏说明按钮回调
func _on_help_button_pressed() -> void:
	print("游戏说明按钮被点击")
	_show_right_overlay(true, false, false)

# 设置按钮回调
func _on_settings_button_pressed() -> void:
	print("设置按钮被点击")
	if settings_menu and settings_menu.has_method("show_settings"):
		settings_menu.show_settings()
	_show_right_overlay(false, true, false)


func _on_cg_button_pressed() -> void:
	print("CG回想按钮被点击")
	if _cg_button and _cg_button.disabled:
		return
	if cg_gallery_panel and cg_gallery_panel.has_method("show_panel"):
		cg_gallery_panel.show_panel()
	_show_right_overlay(false, false, true)


func _on_nsfw_changed(_is_enabled: bool) -> void:
	if not _cg_button:
		return
	_cg_button.disabled = not _is_enabled


func _update_cg_button_enabled_state_from_settings() -> void:
	if not _cg_button:
		return
	_cg_button.disabled = not _is_nsfw_enabled_from_settings()


func _is_nsfw_enabled_from_settings() -> bool:
	var config := ConfigFile.new()
	var err: Error = config.load(_SETTINGS_FILE_PATH)
	if err != OK:
		return false
	return bool(config.get_value(_SETTINGS_SECTION_UI, _SETTINGS_KEY_NSFW_ENABLED, false))

# 设置界面关闭回调
func _on_settings_closed() -> void:
	print("设置界面已关闭")
	_hide_right_overlay()
	_update_cg_button_enabled_state_from_settings()


func _on_cg_gallery_closed() -> void:
	_hide_right_overlay()

# 退出游戏按钮回调
func _on_quit_button_pressed() -> void:
	print("退出游戏按钮被点击")
	get_tree().quit()

# 关闭弹窗按钮回调
func _on_close_button_pressed() -> void:
	print("关闭帮助弹窗")
	if help_panel:
		help_panel.hide()
	_hide_right_overlay()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("esc") and is_instance_valid(right_overlay) and right_overlay.visible:
		_hide_right_overlay()
		get_viewport().set_input_as_handled()
