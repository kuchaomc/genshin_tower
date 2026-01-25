extends Node

## 游戏管理器
## 负责游戏状态管理、场景切换、存档等全局功能

signal scene_changed(scene_name: String)
signal primogems_total_changed(total: int)
signal death_cg_choice_made(view_cg: bool)

# 游戏对外显示名（用于窗口标题等不影响 user:// 数据目录的展示）
const GAME_DISPLAY_NAME: String = "杀原戮神尖塔"

# 开发者覆盖层（常驻顶层UI）
var _dev_overlay: CanvasLayer = null

var _ui_overlay_layer: CanvasLayer = null
var _ui_overlay_node: Node = null
var _map_prev_process_mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT
var _map_process_mode_cached: bool = false

const MAP_VIEW_SCRIPT: Script = preload("res://scripts/ui/map_view.gd")

# BGM曲目key（与 BGMManager.TRACK_* 保持一致）
const BGM_TRACK_MAIN_MENU: StringName = &"main_menu"
const BGM_TRACK_MAP: StringName = &"map"
const BGM_TRACK_BATTLE: StringName = &"battle"

var _pending_bgm_track: StringName = &""

# 游戏状态
enum GameState {
	MAIN_MENU,
	CHARACTER_SELECT,
	WEAPON_SELECT,
	MAP_VIEW,
	BATTLE,
	TREASURE,
	SHOP,
	REST,
	EVENT,
	BOSS_BATTLE,
	GAME_OVER,
	RESULT
}

var current_state: GameState = GameState.MAIN_MENU

# 场景路径映射（统一管理，便于维护）
const SCENE_PATHS: Dictionary = {
	GameState.MAIN_MENU: "res://scenes/ui/main_menu.tscn",
	GameState.CHARACTER_SELECT: "res://scenes/ui/character_select.tscn",
	GameState.WEAPON_SELECT: "res://scenes/ui/weapon_select.tscn",
	GameState.MAP_VIEW: "res://scenes/ui/map_view.tscn",
	GameState.BATTLE: "res://scenes/battle/battle_scene.tscn",
	GameState.SHOP: "res://scenes/ui/shop.tscn",
	GameState.REST: "res://scenes/ui/rest_area.tscn",
	GameState.EVENT: "res://scenes/ui/event.tscn",
	GameState.BOSS_BATTLE: "res://scenes/battle/boss_battle.tscn",
	GameState.RESULT: "res://scenes/ui/result_screen.tscn",
	GameState.TREASURE: "res://scenes/ui/artifact_selection.tscn",  # 宝箱使用圣遗物选择界面
}

# 特殊场景路径（不在状态映射中的场景）
const SCENE_UPGRADE_SELECTION = "res://scenes/ui/upgrade_selection.tscn"
const SCENE_ARTIFACT_SELECTION = "res://scenes/ui/artifact_selection.tscn"

# 向后兼容的常量（保持API兼容性）
const SCENE_MAIN_MENU = SCENE_PATHS[GameState.MAIN_MENU]
const SCENE_CHARACTER_SELECT = SCENE_PATHS[GameState.CHARACTER_SELECT]
const SCENE_MAP_VIEW = SCENE_PATHS[GameState.MAP_VIEW]
const SCENE_BATTLE = SCENE_PATHS[GameState.BATTLE]
const SCENE_SHOP = SCENE_PATHS[GameState.SHOP]
const SCENE_REST = SCENE_PATHS[GameState.REST]
const SCENE_EVENT = SCENE_PATHS[GameState.EVENT]
const SCENE_BOSS = SCENE_PATHS[GameState.BOSS_BATTLE]
const SCENE_RESULT = SCENE_PATHS[GameState.RESULT]

# 存档路径
const SAVE_FILE_PATH = "user://save_data.json"
const SAVE_DATA_VERSION: String = "v2.2"

# 结算记录
var run_records: Array = []
# CG解锁记录：enemy_id -> true
var cg_unlocks: Dictionary = {}
# 主界面商店CG解锁记录：cg_resource_path -> true
var shop_cg_unlocks: Dictionary = {}

# 主界面商店武器解锁记录：weapon_id -> true
var shop_weapon_unlocks: Dictionary = {}

# 原石总数（跨局持久化）
var primogems_total: int = 0

var _cg_unlock_overlay: CanvasLayer = null
const CG_UNLOCK_OVERLAY_SCRIPT: Script = preload("res://scripts/ui/cg_unlock_overlay.gd")
const _CG_TEXTURE_DIR: String = "res://textures/cg"
const _CHARACTER_DEATH_CG_DIR: String = "res://textures/characters"

var _death_cg_prompt: ConfirmationDialog = null
var _prompt_layer: CanvasLayer = null

const _SETTINGS_FILE_PATH: String = "user://settings.cfg"
const _SETTINGS_SECTION_UI: String = "ui"
const _SETTINGS_KEY_NSFW_ENABLED: String = "nsfw_enabled"

func _ready() -> void:
	# 设置窗口标题（不修改 project.godot 的 config/name，避免影响 user:// 数据目录/日志路径）
	# 注意：启动阶段窗口可能尚未完成初始化，这里延迟到下一帧应用更稳定。
	call_deferred("_apply_window_title")
	load_save_data()
	if OS.has_feature("editor"):
		_ensure_dev_overlay()
	_ensure_ui_overlay_layer()
	_ensure_cg_unlock_overlay()
	_ensure_death_cg_prompt()
	if DebugLogger:
		DebugLogger.log_info("初始化完成", "GameManager")


func _ensure_cg_unlock_overlay() -> void:
	if is_instance_valid(_cg_unlock_overlay):
		if _cg_unlock_overlay.is_inside_tree():
			return
		return
	_cg_unlock_overlay = CG_UNLOCK_OVERLAY_SCRIPT.new() as CanvasLayer
	if not _cg_unlock_overlay:
		return
	_cg_unlock_overlay.name = "CGUnlockOverlay"
	get_tree().root.add_child.call_deferred(_cg_unlock_overlay)


func show_death_cg_fullscreen(character_id: String, character_name: String, enemy_id: String, enemy_name: String) -> void:
	if not is_instance_valid(_cg_unlock_overlay):
		_ensure_cg_unlock_overlay()
	if not is_instance_valid(_cg_unlock_overlay):
		return
	if not _cg_unlock_overlay.is_inside_tree():
		await get_tree().process_frame
	if _cg_unlock_overlay.has_method("set_exit_button_text"):
		_cg_unlock_overlay.call("set_exit_button_text", "返回")
	if _cg_unlock_overlay.has_method("show_cg"):
		_cg_unlock_overlay.call("show_cg", character_id, character_name, enemy_id, enemy_name)
	if _cg_unlock_overlay.has_signal("exit_to_result_requested"):
		await _cg_unlock_overlay.exit_to_result_requested

## 应用窗口标题（兼容编辑器运行/导出运行）
func _apply_window_title() -> void:
	DisplayServer.window_set_title(GAME_DISPLAY_NAME)
	var root_window := get_tree().root
	if root_window is Window:
		(root_window as Window).title = GAME_DISPLAY_NAME

func _ensure_dev_overlay() -> void:
	# 只创建一次，跨场景常驻
	if not OS.has_feature("editor"):
		return
	if is_instance_valid(_dev_overlay):
		# 已经在树上就不重复挂载
		if _dev_overlay.is_inside_tree():
			return
		return
	var scene_path := "res://scenes/ui/dev_overlay.tscn"
	var packed: PackedScene = null
	if DataManager and DataManager.has_method("get_packed_scene"):
		packed = DataManager.get_packed_scene(scene_path)
	else:
		packed = load(scene_path) as PackedScene
	if not packed:
		return
	_dev_overlay = packed.instantiate() as CanvasLayer
	if not _dev_overlay:
		return
	_dev_overlay.name = "DevOverlay"
	# 加到根节点，保证跨 change_scene 持久存在
	# 注意：_ready() 阶段 root 可能仍在搭建子节点，直接 add_child 会报 “Parent node is busy…”
	# 用 call_deferred 延迟到下一帧更稳。
	get_tree().root.add_child.call_deferred(_dev_overlay)

func _ensure_ui_overlay_layer() -> void:
	if is_instance_valid(_ui_overlay_layer):
		if _ui_overlay_layer.is_inside_tree():
			return
		return
	_ui_overlay_layer = CanvasLayer.new()
	_ui_overlay_layer.name = "UIOverlay"
	_ui_overlay_layer.layer = 40
	get_tree().root.add_child.call_deferred(_ui_overlay_layer)


func _ensure_prompt_layer() -> void:
	if is_instance_valid(_prompt_layer):
		if _prompt_layer.is_inside_tree():
			return
		return
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "PromptLayer"
	# 必须高于 TransitionManager(100)，否则会被黑屏遮挡
	_prompt_layer.layer = 180
	get_tree().root.add_child.call_deferred(_prompt_layer)


func _ensure_death_cg_prompt() -> void:
	if is_instance_valid(_death_cg_prompt):
		if _death_cg_prompt.is_inside_tree():
			return
		return
	_ensure_prompt_layer()
	_death_cg_prompt = ConfirmationDialog.new()
	_death_cg_prompt.name = "DeathCGPrompt"
	_death_cg_prompt.title = "提示"
	_death_cg_prompt.dialog_text = "是否查看CG？"
	_death_cg_prompt.ok_button_text = "查看"
	_death_cg_prompt.cancel_button_text = "不看"
	_death_cg_prompt.process_mode = Node.PROCESS_MODE_ALWAYS
	_death_cg_prompt.visible = false
	_death_cg_prompt.confirmed.connect(func() -> void: death_cg_choice_made.emit(true))
	_death_cg_prompt.canceled.connect(func() -> void: death_cg_choice_made.emit(false))
	_death_cg_prompt.close_requested.connect(func() -> void: death_cg_choice_made.emit(false))
	if is_instance_valid(_prompt_layer):
		_prompt_layer.add_child.call_deferred(_death_cg_prompt)
	else:
		get_tree().root.add_child.call_deferred(_death_cg_prompt)


func _fade_out_current_scene_ui(duration: float = 0.35) -> void:
	var current := get_tree().current_scene
	if not current:
		return
	if current.has_method("fade_out_hud"):
		await current.call("fade_out_hud", duration)


func _ask_death_cg() -> bool:
	_ensure_death_cg_prompt()
	if not is_instance_valid(_death_cg_prompt):
		return false
	# 弹窗阶段视为死亡结算的一部分：切换到结算/地图BGM
	if BGMManager:
		BGMManager.play_track(BGM_TRACK_MAP)
	# 弹窗交互阶段：恢复默认鼠标（战斗场景可能设置了自定义准星）
	var current := get_tree().current_scene
	if current and current.has_method("_restore_default_cursor"):
		current.call("_restore_default_cursor")
	else:
		Input.set_custom_mouse_cursor(null)
	_death_cg_prompt.popup_centered(Vector2i(480, 180))
	var awaited = await death_cg_choice_made
	var res: bool = false
	if awaited is Array:
		var arr := awaited as Array
		if arr.size() > 0:
			res = bool(arr[0])
	else:
		res = bool(awaited)
	if is_instance_valid(_death_cg_prompt):
		_death_cg_prompt.hide()
	# 兜底再恢复一次，避免窗口关闭后仍残留自定义鼠标
	if current and current.has_method("_restore_default_cursor"):
		current.call("_restore_default_cursor")
	else:
		Input.set_custom_mouse_cursor(null)
	return res

func _is_map_scene_loaded() -> bool:
	var current := get_tree().current_scene
	if current == null:
		return false
	var target_path := str(SCENE_PATHS.get(GameState.MAP_VIEW, ""))
	if not target_path.is_empty() and current.scene_file_path == target_path:
		return true
	if not current.scene_file_path.is_empty() and current.scene_file_path.ends_with("/map_view.tscn"):
		return true
	if current.get_script() == MAP_VIEW_SCRIPT:
		return true
	return false

func _close_ui_overlay() -> void:
	if is_instance_valid(_ui_overlay_node):
		_ui_overlay_node.queue_free()
	_ui_overlay_node = null
	if _map_process_mode_cached and _is_map_scene_loaded():
		var current := get_tree().current_scene
		if current:
			current.process_mode = _map_prev_process_mode
	_map_process_mode_cached = false
	current_state = GameState.MAP_VIEW
	_pending_bgm_track = _get_bgm_track_for_state(GameState.MAP_VIEW)
	_apply_pending_bgm()

func _clear_ui_overlay_for_scene_change() -> void:
	# 注意：这里仅清理 UIOverlay 的节点/缓存，不修改 current_state/BGM。
	# 用于“切换主场景”前的兜底清理：避免叠加UI跨场景残留遮挡，表现为无法跳转。
	if is_instance_valid(_ui_overlay_node):
		_ui_overlay_node.queue_free()
	_ui_overlay_node = null
	_map_process_mode_cached = false
	_map_prev_process_mode = Node.PROCESS_MODE_INHERIT

func _raise_overlay_canvas_layers(root_node: Node) -> void:
	if root_node == null:
		return
	if not is_instance_valid(_ui_overlay_layer):
		return
	var target_layer: int = int(_ui_overlay_layer.layer) + 1
	var layers: Array[Node] = root_node.find_children("*", "CanvasLayer", true, false)
	for n in layers:
		if n is CanvasLayer:
			var cl := n as CanvasLayer
			cl.layer = maxi(int(cl.layer), target_layer)

func _open_ui_overlay(scene_path: String, overlay_state: GameState) -> void:
	_ensure_ui_overlay_layer()
	_close_ui_overlay()
	if _is_map_scene_loaded():
		var current := get_tree().current_scene
		if current:
			_map_prev_process_mode = current.process_mode
			_map_process_mode_cached = true
			current.process_mode = Node.PROCESS_MODE_DISABLED
	current_state = overlay_state
	_pending_bgm_track = _get_bgm_track_for_state(overlay_state)
	_apply_pending_bgm()
	var scene: PackedScene = null
	if DataManager and DataManager.has_method("get_packed_scene"):
		scene = DataManager.get_packed_scene(scene_path) as PackedScene
	else:
		scene = load(scene_path) as PackedScene
	if scene == null:
		push_error("GameManager: 无法加载叠加UI场景：%s" % scene_path)
		return
	_ui_overlay_node = scene.instantiate()
	if _ui_overlay_node == null:
		push_error("GameManager: 无法实例化叠加UI场景：%s" % scene_path)
		return
	_raise_overlay_canvas_layers(_ui_overlay_node)
	if is_instance_valid(_ui_overlay_layer):
		_ui_overlay_layer.add_child(_ui_overlay_node)

func _get_bgm_track_for_state(state: GameState) -> StringName:
	match state:
		GameState.MAIN_MENU, GameState.CHARACTER_SELECT, GameState.WEAPON_SELECT:
			return BGM_TRACK_MAIN_MENU
		GameState.BATTLE, GameState.BOSS_BATTLE, GameState.GAME_OVER:
			return BGM_TRACK_BATTLE
		_:
			# 地图相关/跑图中的各类UI（地图、商店、休息、事件、宝箱、结算等）统一使用地图BGM
			return BGM_TRACK_MAP

func _apply_pending_bgm() -> void:
	if _pending_bgm_track.is_empty():
		return
	if BGMManager:
		BGMManager.play_track(_pending_bgm_track)
	_pending_bgm_track = &""

## 切换场景
func change_scene_to(scene_path: String, use_transition: bool = false) -> void:
	# 统一兜底：任何主场景切换前都先清理叠加UI。
	# 否则从事件/商店/休息等 Overlay 内触发跳转时，会因为 UIOverlay 跨场景保留而遮挡新场景。
	_clear_ui_overlay_for_scene_change()
	# 如果需要转场动画（仅用于战斗场景）
	if use_transition and TransitionManager:
		# 播放淡出动画
		await TransitionManager.fade_out(0.8)
	
	# 优先通过 DataManager 的缓存加载，减少反复 load 造成的卡顿
	var scene: PackedScene = null
	if DataManager and DataManager.has_method("get_packed_scene"):
		scene = DataManager.get_packed_scene(scene_path)
	else:
		scene = load(scene_path) as PackedScene
	
	if scene:
		get_tree().change_scene_to_packed(scene)
		emit_signal("scene_changed", scene_path)
		if OS.is_debug_build():
			call_deferred("_debug_after_scene_change", scene_path)
		# 场景切换后可能出现标题被恢复为 project.godot 的 config/name 的情况，延迟补一次更稳。
		call_deferred("_apply_window_title")
		if DebugLogger:
			DebugLogger.log_info("切换到场景：%s" % scene_path, "GameManager")
		
		# 场景切换完成后切换BGM（同时保存/恢复各曲目的播放进度）
		if _pending_bgm_track.is_empty():
			_pending_bgm_track = _get_bgm_track_for_state(current_state)
		_apply_pending_bgm()
	else:
		if DebugLogger:
			DebugLogger.log_error("无法加载场景：%s" % scene_path, "GameManager")
		# 如果场景加载失败，返回主菜单
		if scene_path != SCENE_MAIN_MENU:
			go_to_main_menu()

func _debug_after_scene_change(scene_path: String) -> void:
	# 等一帧，确保 change_scene 后 current_scene/节点树已稳定
	await get_tree().process_frame
	var root := get_tree().root
	var current := get_tree().current_scene
	var current_path := ""
	if current:
		current_path = current.scene_file_path
	print("[SceneDebug] change_scene_to: ", scene_path)
	print("[SceneDebug] current_scene: ", (current.name if current else "<null>"), " | ", current_path)
	print("[SceneDebug] root children:")
	for n in root.get_children():
		var pm := ""
		if n is Node:
			pm = str((n as Node).process_mode)
		var vis := ""
		if n is CanvasItem:
			vis = " visible=" + str((n as CanvasItem).visible)
		print("  - ", n.name, " (", n.get_class(), ") process_mode=", pm, vis)
	print("[SceneDebug] node_count(current_scene)=", _count_nodes(current))

func _count_nodes(node: Node) -> int:
	if not node:
		return 0
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count

## 通用场景切换方法（根据状态切换）
func _change_scene_by_state(state: GameState) -> void:
	current_state = state
	_pending_bgm_track = _get_bgm_track_for_state(state)
	var scene_path = SCENE_PATHS.get(state)
	if scene_path:
		change_scene_to(scene_path)
	else:
		push_error("GameManager: 状态 %d 没有对应的场景路径" % state)

## 切换到主菜单
func go_to_main_menu() -> void:
	_change_scene_by_state(GameState.MAIN_MENU)

## 切换到角色选择
func go_to_character_select() -> void:
	_change_scene_by_state(GameState.CHARACTER_SELECT)

## 切换到武器选择
func go_to_weapon_select() -> void:
	_change_scene_by_state(GameState.WEAPON_SELECT)

## 切换到地图界面
func go_to_map_view() -> void:
	_close_ui_overlay()
	if _is_map_scene_loaded():
		return
	_change_scene_by_state(GameState.MAP_VIEW)

## 开始战斗
func start_battle(_enemy_data: EnemyData = null) -> void:
 	# 事件/商店等界面通过 UIOverlay(CanvsaLayer) 叠加在 root 上，会跨场景保留。
 	# 进入战斗属于“切换主场景”，因此这里必须先关闭叠加UI，否则会覆盖战斗场景，表现为“进不了场景”。
	_close_ui_overlay()
	# 使用转场动画切换到战斗场景
	current_state = GameState.BATTLE
	_pending_bgm_track = _get_bgm_track_for_state(GameState.BATTLE)
	var scene_path = SCENE_PATHS.get(GameState.BATTLE)
	if scene_path:
		change_scene_to(scene_path, true)  # 启用转场动画
	else:
		push_error("GameManager: 状态 %d 没有对应的场景路径" % GameState.BATTLE)

## 打开宝箱
func open_treasure() -> void:
	current_state = GameState.TREASURE
	# 显示圣遗物选择界面
	show_artifact_selection()

## 进入商店
func enter_shop() -> void:
	if _is_map_scene_loaded():
		_open_ui_overlay(str(SCENE_PATHS.get(GameState.SHOP, "")), GameState.SHOP)
		return
	_change_scene_by_state(GameState.SHOP)

## 进入休息处
func enter_rest() -> void:
	if _is_map_scene_loaded():
		_open_ui_overlay(str(SCENE_PATHS.get(GameState.REST, "")), GameState.REST)
		return
	_change_scene_by_state(GameState.REST)

## 进入奇遇事件
func enter_event() -> void:
	if _is_map_scene_loaded():
		_open_ui_overlay(str(SCENE_PATHS.get(GameState.EVENT, "")), GameState.EVENT)
		return
	_change_scene_by_state(GameState.EVENT)

## 开始BOSS战
func start_boss_battle() -> void:
	# 同 start_battle：进入BOSS战为主场景切换，先关闭叠加UI。
	_close_ui_overlay()
	_change_scene_by_state(GameState.BOSS_BATTLE)

## 显示结算界面
func show_result(_victory: bool = false) -> void:
	_change_scene_by_state(GameState.RESULT)

## 显示升级选择界面
func show_upgrade_selection() -> void:
	current_state = GameState.MAP_VIEW
	_pending_bgm_track = _get_bgm_track_for_state(GameState.MAP_VIEW)
	change_scene_to(SCENE_UPGRADE_SELECTION)

## 显示圣遗物选择界面
func show_artifact_selection() -> void:
	if _is_map_scene_loaded():
		_open_ui_overlay(SCENE_ARTIFACT_SELECTION, GameState.TREASURE)
		return
	current_state = GameState.TREASURE
	_pending_bgm_track = _get_bgm_track_for_state(GameState.TREASURE)
	change_scene_to(SCENE_ARTIFACT_SELECTION)

## 游戏结束（玩家死亡）
func game_over() -> void:
	current_state = GameState.GAME_OVER
	
	# 保存失败记录到 RunManager
	if RunManager:
		RunManager.end_run(false)
	
	# 死亡过渡：黑色出现并向中心汇聚（保持黑屏，交由目标场景 fade_in 撤黑）
	if TransitionManager and TransitionManager.has_method("iris_close_to_center"):
		await TransitionManager.iris_close_to_center(2.0)
	elif TransitionManager:
		await TransitionManager.fade_out(2.0)
	
	# 注意：按需求，汇聚动画播放完后再淡出死亡时的UI
	await _fade_out_current_scene_ui(0.35)
	
	# NSFW开启时：若存在对应CG，先询问是否查看；无CG则直接进入结算
	if _is_nsfw_enabled_from_settings() and RunManager:
		var enemy_id: String = str(RunManager.last_defeated_by_enemy_id)
		var enemy_name: String = str(RunManager.last_defeated_by_enemy_name)
		var character_id: String = ""
		var character_name: String = ""
		if RunManager.current_character:
			character_id = str(RunManager.current_character.id)
			character_name = str(RunManager.current_character.display_name)
		if not character_id.is_empty() and not enemy_id.is_empty():
			var tex: Texture2D = get_death_cg_texture(character_id, enemy_id, enemy_name)
			if tex != null:
				unlock_death_cg(character_id, enemy_id)
				var want_view: bool = await _ask_death_cg()
				if want_view:
					if not is_instance_valid(_cg_unlock_overlay):
						_ensure_cg_unlock_overlay()
					if is_instance_valid(_cg_unlock_overlay):
						if not _cg_unlock_overlay.is_inside_tree():
							await get_tree().process_frame
						if _cg_unlock_overlay.has_method("show_cg"):
							_cg_unlock_overlay.call("show_cg", character_id, character_name, enemy_id, enemy_name)
						if _cg_unlock_overlay.has_signal("exit_to_result_requested"):
							await _cg_unlock_overlay.exit_to_result_requested
						show_result(false)
						return
	
	# 延迟后显示结算
	await get_tree().create_timer(0.25).timeout
	show_result(false)


func _try_show_death_cg_unlock_overlay() -> bool:
	if not RunManager:
		if OS.is_debug_build():
			print("[DeathCG] skip: RunManager is null")
		return false
	var enemy_id: String = str(RunManager.last_defeated_by_enemy_id)
	if enemy_id.is_empty():
		if OS.is_debug_build():
			print("[DeathCG] skip: last_defeated_by_enemy_id is empty")
		return false
	var enemy_name: String = str(RunManager.last_defeated_by_enemy_name)
	var character_id: String = ""
	var character_name: String = ""
	if RunManager.current_character:
		character_id = str(RunManager.current_character.id)
		character_name = str(RunManager.current_character.display_name)
	if character_id.is_empty():
		if OS.is_debug_build():
			print("[DeathCG] skip: character_id is empty")
		return false
	if enemy_name.is_empty() and DataManager and DataManager.has_method("get_enemy"):
		var ed = DataManager.get_enemy(enemy_id)
		if ed:
			enemy_name = ed.display_name
	
	var tex: Texture2D = get_death_cg_texture(character_id, enemy_id, enemy_name)
	if tex == null:
		if OS.is_debug_build():
			print("[DeathCG] skip: texture is null. character_id=", character_id, " enemy_id=", enemy_id, " enemy_name=", enemy_name)
		return false
	
	unlock_death_cg(character_id, enemy_id)
	
	if not is_instance_valid(_cg_unlock_overlay):
		_ensure_cg_unlock_overlay()
	if not is_instance_valid(_cg_unlock_overlay):
		return false
	# overlay 可能通过 call_deferred 挂载，等一帧确保已入树再显示
	if not _cg_unlock_overlay.is_inside_tree():
		await get_tree().process_frame
	
	if _cg_unlock_overlay.has_method("show_cg"):
		_cg_unlock_overlay.call("show_cg", character_id, character_name, enemy_id, enemy_name)
	
	if _cg_unlock_overlay.has_signal("exit_to_result_requested"):
		await _cg_unlock_overlay.exit_to_result_requested
		return true
	return false


func _is_nsfw_enabled_from_settings() -> bool:
	var config := ConfigFile.new()
	var err: Error = config.load(_SETTINGS_FILE_PATH)
	if err != OK:
		return false
	return bool(config.get_value(_SETTINGS_SECTION_UI, _SETTINGS_KEY_NSFW_ENABLED, false))


func is_cg_unlocked(enemy_id: String) -> bool:
	return cg_unlocks.has(enemy_id)


func is_death_cg_unlocked(character_id: String, enemy_id: String) -> bool:
	if character_id.is_empty() or enemy_id.is_empty():
		return false
	var key := _make_death_cg_key(character_id, enemy_id)
	# 兼容旧存档：只按 enemy_id 存过一次
	return cg_unlocks.has(key) or cg_unlocks.has(enemy_id)


func unlock_cg(enemy_id: String) -> void:
	if enemy_id.is_empty():
		return
	if cg_unlocks.has(enemy_id):
		return
	cg_unlocks[enemy_id] = true
	save_data()


func unlock_death_cg(character_id: String, enemy_id: String) -> void:
	if character_id.is_empty() or enemy_id.is_empty():
		return
	var key := _make_death_cg_key(character_id, enemy_id)
	if cg_unlocks.has(key):
		return
	cg_unlocks[key] = true
	save_data()


func get_unlocked_cg_ids() -> Array:
	var ids: Array = cg_unlocks.keys()
	ids.sort()
	return ids

func get_unlocked_death_cg_entries() -> Array:
	var entries: Array = []
	var stale_keys: Array[String] = []
	for k in cg_unlocks.keys():
		var key_str := str(k)
		var character_id := ""
		var enemy_id := ""
		if key_str.contains(":"):
			var parts := key_str.split(":", false)
			if parts.size() >= 2:
				character_id = str(parts[0])
				enemy_id = str(parts[1])
		else:
			# 旧存档条目：只有 enemy_id
			enemy_id = key_str
		var character_name := ""
		if not character_id.is_empty() and DataManager and DataManager.has_method("get_character"):
			var cd = DataManager.get_character(character_id)
			if cd:
				character_name = cd.display_name
		var enemy_name := ""
		if not enemy_id.is_empty() and DataManager and DataManager.has_method("get_enemy"):
			var ed = DataManager.get_enemy(enemy_id)
			if ed:
				enemy_name = ed.display_name
		if not _has_death_cg_texture(character_id, enemy_id, enemy_name):
			stale_keys.append(key_str)
			continue
		entries.append({
			"key": key_str,
			"character_id": character_id,
			"character_name": character_name,
			"enemy_id": enemy_id,
			"enemy_name": enemy_name,
		})
	if not stale_keys.is_empty():
		for sk in stale_keys:
			cg_unlocks.erase(sk)
		save_data()
	return entries


func _has_death_cg_texture(character_id: String, enemy_id: String, enemy_name: String) -> bool:
	var candidates := _get_death_cg_candidate_paths(character_id, enemy_id, enemy_name)
	for path in candidates:
		# 回想入口只认“具体死亡CG”，不把 default / 全局兜底图当作已存在。
		if path.ends_with("/death/default.png"):
			continue
		if path.begins_with(_CG_TEXTURE_DIR + "/"):
			continue
		if ResourceLoader.exists(path):
			return true
	return false


func get_death_cg_texture(character_id: String, enemy_id: String, enemy_name: String) -> Texture2D:
	var candidates := _get_death_cg_candidate_paths(character_id, enemy_id, enemy_name)
	for path in candidates:
		var tex: Texture2D = null
		if DataManager:
			tex = DataManager.get_texture(path)
		else:
			tex = load(path) as Texture2D
		if tex:
			return tex
	if OS.is_debug_build():
		print("[DeathCG] texture not found. character_id=", character_id, " enemy_id=", enemy_id, " enemy_name=", enemy_name, " candidates=", candidates)
	return null


func _make_death_cg_key(character_id: String, enemy_id: String) -> String:
	return "%s:%s" % [character_id, enemy_id]


func _get_death_cg_candidate_paths(character_id: String, enemy_id: String, enemy_name: String) -> Array[String]:
	var paths: Array[String] = []
	if not character_id.is_empty():
		# 角色目录名兜底：历史资源可能使用了不同大小写。
		# - 目前纳西妲资源目录为 Nahida（大写），但角色id为 nahida（小写）。
		var character_dir_names: Array[String] = [character_id]
		if character_id == "nahida":
			character_dir_names.append("Nahida")

		for dir_name in character_dir_names:
			# 1) 你当前的命名规则：被<敌人名>击败.png
			if not enemy_name.is_empty():
				paths.append("%s/%s/death/被%s击败.png" % [_CHARACTER_DEATH_CG_DIR, dir_name, enemy_name])
			# 1.1) 备用：被<enemy_id>击败.png（当 display_name 与文件命名不一致时可用）
			if not enemy_id.is_empty():
				paths.append("%s/%s/death/被%s击败.png" % [_CHARACTER_DEATH_CG_DIR, dir_name, enemy_id])
			# 2) 备用：按 enemy_id
			if not enemy_id.is_empty():
				paths.append("%s/%s/death/%s.png" % [_CHARACTER_DEATH_CG_DIR, dir_name, enemy_id])
			# 3) 默认图
			paths.append("%s/%s/death/default.png" % [_CHARACTER_DEATH_CG_DIR, dir_name])
	# 4) 兼容旧全局CG
	if not enemy_id.is_empty():
		paths.append("%s/%s.png" % [_CG_TEXTURE_DIR, enemy_id])
	return paths

## 保存结算记录
func save_run_record(record: Dictionary) -> void:
	run_records.append(record)
	
	# 只保留最近50条记录
	if run_records.size() > 50:
		run_records = run_records.slice(-50)
	
	save_data()

## 获取所有结算记录
func get_run_records() -> Array:
	return run_records

## 获取最近的结算记录
func get_latest_record() -> Dictionary:
	if run_records.is_empty():
		return {}
	return run_records[-1]

## 保存数据
func save_data() -> void:
	var save_dict = {
		"run_records": run_records,
		"cg_unlocks": cg_unlocks.keys(),
		"shop_cg_unlocks": shop_cg_unlocks.keys(),
		"shop_weapon_unlocks": shop_weapon_unlocks.keys(),
		"primogems_total": primogems_total,
		"version": SAVE_DATA_VERSION
	}
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_dict)
		file.store_string(json_string)
		file.close()
		if DebugLogger:
			DebugLogger.log_info("存档保存成功", "GameManager")
	else:
		if DebugLogger:
			DebugLogger.log_error("无法保存存档", "GameManager")

## 加载数据
func load_save_data() -> void:
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			var data = json.data
			var has_version: bool = false
			var save_version: String = ""
			if data is Dictionary:
				has_version = (data as Dictionary).has("version")
				save_version = str((data as Dictionary).get("version", ""))
			run_records = data.get("run_records", [])
			cg_unlocks.clear()
			var unlocked: Array = data.get("cg_unlocks", [])
			for k in unlocked:
				cg_unlocks[str(k)] = true
			shop_cg_unlocks.clear()
			var shop_unlocked: Array = data.get("shop_cg_unlocks", [])
			for k2 in shop_unlocked:
				shop_cg_unlocks[str(k2)] = true
			shop_weapon_unlocks.clear()
			var weapon_unlocked: Array = data.get("shop_weapon_unlocks", [])
			for w in weapon_unlocked:
				shop_weapon_unlocks[str(w)] = true
			primogems_total = int(data.get("primogems_total", 0))
			emit_signal("primogems_total_changed", primogems_total)
			if not has_version:
				# 旧存档兼容：没有 version 字段则按当前版本覆盖写回，避免后续版本核查/升级逻辑缺字段。
				save_data()
				if DebugLogger:
					DebugLogger.log_warning("检测到旧存档缺少版本号，已按当前版本覆盖写回", "GameManager")
			elif (not save_version.is_empty()) and save_version != SAVE_DATA_VERSION:
				if DebugLogger:
					DebugLogger.log_warning("存档版本不匹配：%s（当前：%s）" % [save_version, SAVE_DATA_VERSION], "GameManager")
			if DebugLogger:
				DebugLogger.log_info("存档加载成功，记录数：%d" % run_records.size(), "GameManager")
		else:
			if DebugLogger:
				DebugLogger.log_error("无法解析存档JSON", "GameManager")
			run_records = []
			cg_unlocks.clear()
			shop_cg_unlocks.clear()
			shop_weapon_unlocks.clear()
			primogems_total = 0
			emit_signal("primogems_total_changed", primogems_total)
	else:
		if DebugLogger:
			DebugLogger.log_info("存档文件不存在，使用默认值", "GameManager")
		run_records = []
		cg_unlocks.clear()
		shop_cg_unlocks.clear()
		shop_weapon_unlocks.clear()
		primogems_total = 0
		emit_signal("primogems_total_changed", primogems_total)


## 获取原石总数
func get_primogems_total() -> int:
	return primogems_total


## 增加原石（跨局持久化）
func add_primogems(amount: int) -> void:
	if amount <= 0:
		return
	primogems_total += amount
	emit_signal("primogems_total_changed", primogems_total)
	save_data()


## 消耗原石（跨局持久化）
func spend_primogems(amount: int) -> bool:
	if amount <= 0:
		return true
	if primogems_total < amount:
		return false
	primogems_total -= amount
	emit_signal("primogems_total_changed", primogems_total)
	save_data()
	return true


## 主界面商店：解锁指定CG（用资源路径作为ID）
func unlock_shop_cg(cg_id: String) -> void:
	if cg_id.is_empty():
		return
	shop_cg_unlocks[cg_id] = true
	save_data()


## 主界面商店：是否已解锁指定CG
func is_shop_cg_unlocked(cg_id: String) -> bool:
	if cg_id.is_empty():
		return false
	return shop_cg_unlocks.has(cg_id)


## 主界面商店：解锁指定武器（用 weapon_id 作为ID）
func unlock_shop_weapon(weapon_id: String) -> void:
	if weapon_id.is_empty():
		return
	if shop_weapon_unlocks.has(weapon_id):
		return
	shop_weapon_unlocks[weapon_id] = true
	save_data()


## 主界面商店：是否已解锁指定武器
func is_shop_weapon_unlocked(weapon_id: String) -> bool:
	if weapon_id.is_empty():
		return false
	return shop_weapon_unlocks.has(weapon_id)


## 获取已解锁的武器ID列表
func get_unlocked_shop_weapon_ids() -> Array[String]:
	var out: Array[String] = []
	for k in shop_weapon_unlocks.keys():
		out.append(str(k))
	out.sort()
	return out


func get_unlocked_shop_cg_entries() -> Array:
	var entries: Array = []
	var stale: Array[String] = []
	for k in shop_cg_unlocks.keys():
		var path := str(k)
		if path.is_empty():
			continue
		if not ResourceLoader.exists(path):
			stale.append(path)
			continue
		var name := path.get_file().get_basename()
		entries.append({
			"cg_id": path,
			"display_name": name,
		})
	if not stale.is_empty():
		for s in stale:
			shop_cg_unlocks.erase(s)
		save_data()
	return entries


func show_shop_cg_fullscreen(cg_path: String) -> void:
	if cg_path.is_empty():
		return
	if not ResourceLoader.exists(cg_path):
		return
	if not is_instance_valid(_cg_unlock_overlay):
		_ensure_cg_unlock_overlay()
	if not is_instance_valid(_cg_unlock_overlay):
		return
	if not _cg_unlock_overlay.is_inside_tree():
		await get_tree().process_frame
	var tex: Texture2D = null
	if DataManager and DataManager.has_method("get_texture"):
		tex = DataManager.get_texture(cg_path)
	else:
		tex = load(cg_path) as Texture2D
	var title := cg_path.get_file().get_basename()
	if _cg_unlock_overlay.has_method("set_exit_button_text"):
		_cg_unlock_overlay.call("set_exit_button_text", "返回")
	if _cg_unlock_overlay.has_method("show_custom_texture"):
		_cg_unlock_overlay.call("show_custom_texture", title, tex)
	if _cg_unlock_overlay.has_signal("exit_to_result_requested"):
		await _cg_unlock_overlay.exit_to_result_requested
