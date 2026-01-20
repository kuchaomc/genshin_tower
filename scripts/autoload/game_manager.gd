extends Node

## 游戏管理器
## 负责游戏状态管理、场景切换、存档等全局功能

signal scene_changed(scene_name: String)

# 游戏状态
enum GameState {
	MAIN_MENU,
	CHARACTER_SELECT,
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

# 结算记录
var run_records: Array = []

func _ready() -> void:
	load_save_data()
	print("游戏管理器初始化完成")

## 切换场景
func change_scene_to(scene_path: String) -> void:
	# 优先通过 DataManager 的缓存加载，减少反复 load 造成的卡顿
	var scene: PackedScene = null
	if DataManager and DataManager.has_method("get_packed_scene"):
		scene = DataManager.get_packed_scene(scene_path)
	else:
		scene = load(scene_path) as PackedScene
	
	if scene:
		get_tree().change_scene_to_packed(scene)
		emit_signal("scene_changed", scene_path)
		print("切换到场景：", scene_path)
	else:
		print("错误：无法加载场景 ", scene_path)
		# 如果场景加载失败，返回主菜单
		if scene_path != SCENE_MAIN_MENU:
			go_to_main_menu()

## 通用场景切换方法（根据状态切换）
func _change_scene_by_state(state: GameState) -> void:
	current_state = state
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

## 切换到地图界面
func go_to_map_view() -> void:
	_change_scene_by_state(GameState.MAP_VIEW)

## 开始战斗
func start_battle(_enemy_data: EnemyData = null) -> void:
	_change_scene_by_state(GameState.BATTLE)

## 打开宝箱
func open_treasure() -> void:
	current_state = GameState.TREASURE
	# 显示圣遗物选择界面
	show_artifact_selection()

## 进入商店
func enter_shop() -> void:
	_change_scene_by_state(GameState.SHOP)

## 进入休息处
func enter_rest() -> void:
	_change_scene_by_state(GameState.REST)

## 进入奇遇事件
func enter_event() -> void:
	_change_scene_by_state(GameState.EVENT)

## 开始BOSS战
func start_boss_battle() -> void:
	_change_scene_by_state(GameState.BOSS_BATTLE)

## 显示结算界面
func show_result(_victory: bool = false) -> void:
	_change_scene_by_state(GameState.RESULT)

## 显示升级选择界面
func show_upgrade_selection() -> void:
	current_state = GameState.MAP_VIEW
	change_scene_to(SCENE_UPGRADE_SELECTION)

## 显示圣遗物选择界面
func show_artifact_selection() -> void:
	current_state = GameState.TREASURE
	change_scene_to(SCENE_ARTIFACT_SELECTION)

## 游戏结束
func game_over() -> void:
	current_state = GameState.GAME_OVER
	# 延迟后显示结算
	await get_tree().create_timer(2.0).timeout
	show_result(false)

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
		"version": "1.0"
	}
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_dict)
		file.store_string(json_string)
		file.close()
		print("存档保存成功")
	else:
		print("错误：无法保存存档")

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
			run_records = data.get("run_records", [])
			print("存档加载成功，记录数：", run_records.size())
		else:
			print("错误：无法解析存档JSON")
			run_records = []
	else:
		print("存档文件不存在，使用默认值")
		run_records = []
