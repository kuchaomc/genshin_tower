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

# 场景路径
const SCENE_MAIN_MENU = "res://scenes/ui/main_menu.tscn"
const SCENE_CHARACTER_SELECT = "res://scenes/ui/character_select.tscn"
const SCENE_MAP_VIEW = "res://scenes/ui/map_view.tscn"
const SCENE_BATTLE = "res://scenes/battle/battle_scene.tscn"
const SCENE_SHOP = "res://scenes/ui/shop.tscn"
const SCENE_REST = "res://scenes/ui/rest_area.tscn"
const SCENE_EVENT = "res://scenes/ui/event.tscn"
const SCENE_BOSS = "res://scenes/battle/boss_battle.tscn"
const SCENE_RESULT = "res://scenes/ui/result_screen.tscn"
const SCENE_UPGRADE_SELECTION = "res://scenes/ui/upgrade_selection.tscn"

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
		# 兼容：如果 EventBus 存在，同步广播
		if Engine.has_singleton("EventBus") or has_node("/root/EventBus"):
			var bus = get_node_or_null("/root/EventBus")
			if bus and bus.has_signal("scene_changed"):
				bus.emit_signal("scene_changed", scene_path)
		print("切换到场景：", scene_path)
	else:
		print("错误：无法加载场景 ", scene_path)
		# 如果场景加载失败，返回主菜单
		if scene_path != SCENE_MAIN_MENU:
			go_to_main_menu()

## 切换到主菜单
func go_to_main_menu() -> void:
	current_state = GameState.MAIN_MENU
	change_scene_to(SCENE_MAIN_MENU)

## 切换到角色选择
func go_to_character_select() -> void:
	current_state = GameState.CHARACTER_SELECT
	change_scene_to(SCENE_CHARACTER_SELECT)

## 切换到地图界面
func go_to_map_view() -> void:
	current_state = GameState.MAP_VIEW
	change_scene_to(SCENE_MAP_VIEW)

## 开始战斗
func start_battle(_enemy_data: EnemyData = null) -> void:
	current_state = GameState.BATTLE
	change_scene_to(SCENE_BATTLE)

## 打开宝箱
func open_treasure() -> void:
	current_state = GameState.TREASURE
	# 宝箱直接给予奖励，然后返回地图
	# TODO: 实现宝箱奖励逻辑
	print("打开宝箱！获得奖励")
	# 暂时直接返回地图
	await get_tree().create_timer(1.0).timeout
	go_to_map_view()

## 进入商店
func enter_shop() -> void:
	current_state = GameState.SHOP
	change_scene_to(SCENE_SHOP)

## 进入休息处
func enter_rest() -> void:
	current_state = GameState.REST
	change_scene_to(SCENE_REST)

## 进入奇遇事件
func enter_event() -> void:
	current_state = GameState.EVENT
	change_scene_to(SCENE_EVENT)

## 开始BOSS战
func start_boss_battle() -> void:
	current_state = GameState.BOSS_BATTLE
	change_scene_to(SCENE_BOSS)

## 显示结算界面
func show_result(_victory: bool = false) -> void:
	current_state = GameState.RESULT
	change_scene_to(SCENE_RESULT)

## 显示升级选择界面
func show_upgrade_selection() -> void:
	current_state = GameState.MAP_VIEW
	change_scene_to(SCENE_UPGRADE_SELECTION)

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
