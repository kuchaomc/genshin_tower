extends Node

## 数据管理器
## 负责加载和管理游戏数据（角色、敌人、配置等）

# 预加载Resource类
const CharacterDataClass = preload("res://scripts/characters/character_data.gd")
const EnemyDataClass = preload("res://scripts/enemies/enemy_data.gd")

signal data_loaded

# 数据缓存
var characters: Dictionary = {}
var enemies: Dictionary = {}
var map_config: Dictionary = {}

## 资源缓存（避免重复 load 引发卡顿/GC）
## key: res:// 路径，value: 已加载 Resource（PackedScene/Texture2D/Script/Resource 等）
var _resource_cache: Dictionary = {}

func _ready() -> void:
	load_all_data()

## 加载所有游戏数据
func load_all_data() -> void:
	load_characters()
	load_enemies()
	load_map_config()
	if DebugLogger and not OS.has_feature("editor"):
		DebugLogger.log_info("Data loaded: characters=%d enemies=%d" % [characters.size(), enemies.size()], "DataManager")
		if characters.is_empty() or enemies.is_empty():
			DebugLogger.log_error("Data missing after export load (characters/enemies is empty)", "DataManager")
			DebugLogger.save_debug_log()
	emit_signal("data_loaded")
	if DebugLogger:
		DebugLogger.log_info("所有数据加载完成", "DataManager")

## 加载角色数据
func load_characters() -> void:
	characters.clear()
	_load_resources_from_directory("res://data/characters", CharacterDataClass, characters, "角色")

## 加载敌人数据
func load_enemies() -> void:
	enemies.clear()
	_load_resources_from_directory("res://data/enemies", EnemyDataClass, enemies, "敌人")

## 通用资源加载方法（消除重复代码）
## dir_path: 目录路径
## expected_script: 期望的资源脚本（Script对象）
## target_dict: 目标字典（用于存储加载的资源）
## resource_type_name: 资源类型名称（用于日志输出）
func _load_resources_from_directory(dir_path: String, expected_script: Script, target_dict: Dictionary, resource_type_name: String) -> void:
	var dir = DirAccess.open(dir_path)
	if not dir:
		print("警告：无法打开", dir_path, "目录")
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir():
			# 导出版本中可能会枚举到 *.tres.remap / *.res.remap；
			# 如果只匹配 .tres，会导致整个目录资源都无法加载。
			var is_tres := file_name.ends_with(".tres") or file_name.ends_with(".tres.remap")
			var is_res := file_name.ends_with(".res") or file_name.ends_with(".res.remap")
			if not (is_tres or is_res):
				file_name = dir.get_next() as String
				continue
			
			var actual_file: String = file_name
			if actual_file.ends_with(".remap"):
				actual_file = actual_file.substr(0, actual_file.length() - 6)
			var resource_path = dir_path + "/" + actual_file
			var resource = load_cached(resource_path)
			
			if resource:
				# 只处理指定类型的资源：导出后 Script 可能不是同一个实例，
				# 直接用对象相判断会导致误过滤；改为比较脚本路径更稳。
				var res_script: Script = resource.get_script()
				if res_script == null:
					file_name = dir.get_next()
					continue
				if res_script.resource_path != expected_script.resource_path:
					file_name = dir.get_next()
					continue
				
				# 尝试访问id属性
				var resource_id = resource.get("id")
				if resource_id and resource_id != "":
					target_dict[resource_id] = resource
					var display_name = resource.get("display_name")
					if DebugLogger:
						DebugLogger.log_debug("加载%s：%s" % [resource_type_name, (display_name if display_name else "未知")], "DataManager")
				else:
					if DebugLogger:
						DebugLogger.log_warning("%s资源缺少id属性：%s" % [resource_type_name, resource_path], "DataManager")
			else:
				if DebugLogger:
					DebugLogger.log_warning("无法加载资源文件：%s" % resource_path, "DataManager")
		
		file_name = dir.get_next() as String
	
	dir.list_dir_end()

## 加载地图配置
func load_map_config() -> void:
	var file = FileAccess.open("res://data/config/map_config.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			map_config = json.data
			if DebugLogger:
				DebugLogger.log_info("地图配置加载成功", "DataManager")
		else:
			if DebugLogger:
				DebugLogger.log_error("无法解析地图配置JSON", "DataManager")
			create_default_map_config()
	else:
		if DebugLogger:
			DebugLogger.log_warning("地图配置文件不存在，创建默认配置", "DataManager")
		create_default_map_config()

## 创建默认地图配置
func create_default_map_config() -> void:
	map_config = {
		"floors": 15,
		"nodes_per_floor": [2, 4],
		"node_types": {
			"enemy": {"weight": 50},
			"shop": {"weight": 10},
			"rest": {"weight": 10},
			"event": {"weight": 15}
		},
		"boss_floor": 15
	}

## 获取角色数据
func get_character(id: String) -> CharacterData:
	return characters.get(id)

## 获取所有角色
func get_all_characters() -> Array:
	return characters.values()

## 获取敌人数据
func get_enemy(id: String) -> EnemyData:
	return enemies.get(id)

## 根据类型获取敌人
func get_enemies_by_type(type: String) -> Array:
	var result = []
	for enemy in enemies.values():
		if enemy.enemy_type == type:
			result.append(enemy)
	return result

## 获取地图配置
func get_map_config() -> Dictionary:
	return map_config

# ==============================
# Resource Cache API（对外统一入口）
# ==============================

## 统一资源加载（带缓存）
## - 返回值可能为 null（加载失败）
func load_cached(path: String) -> Resource:
	if path.is_empty():
		return null
	if _resource_cache.has(path):
		return _resource_cache[path] as Resource
	if not ResourceLoader.exists(path):
		return null
	var res := load(path)
	if res:
		_resource_cache[path] = res
	return res as Resource

## 获取 PackedScene（带缓存）
func get_packed_scene(path: String) -> PackedScene:
	var res := load_cached(path)
	if res is PackedScene:
		return res as PackedScene
	return null

## 获取 Texture2D（带缓存）
func get_texture(path: String) -> Texture2D:
	var res := load_cached(path)
	if res is Texture2D:
		return res as Texture2D
	return null

## 清空资源缓存（调试/热重载用）
func clear_resource_cache() -> void:
	_resource_cache.clear()
