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

func _ready() -> void:
	load_all_data()

## 加载所有游戏数据
func load_all_data() -> void:
	load_characters()
	load_enemies()
	load_map_config()
	emit_signal("data_loaded")
	print("数据管理器：所有数据加载完成")

## 加载角色数据
func load_characters() -> void:
	characters.clear()
	
	# 从data/characters目录加载所有.tres文件
	var dir_path = "res://data/characters"
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var resource_path = dir_path + "/" + file_name
				var resource = load(resource_path)
				if resource:
					# 尝试访问id属性
					var char_id = resource.get("id")
					if char_id and char_id != "":
						characters[char_id] = resource
						var char_name = resource.get("display_name")
						print("加载角色：", char_name if char_name else "未知")
					else:
						print("警告：角色资源缺少id属性 ", resource_path)
				else:
					print("警告：无法加载资源文件 ", resource_path)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("警告：无法打开data/characters目录")

## 加载敌人数据
func load_enemies() -> void:
	enemies.clear()
	
	# 从data/enemies目录加载所有.tres文件
	var dir_path = "res://data/enemies"
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var resource_path = dir_path + "/" + file_name
				var resource = load(resource_path)
				if resource:
					# 尝试访问id属性
					var enemy_id = resource.get("id")
					if enemy_id and enemy_id != "":
						enemies[enemy_id] = resource
						var enemy_name = resource.get("display_name")
						print("加载敌人：", enemy_name if enemy_name else "未知")
					else:
						print("警告：敌人资源缺少id属性 ", resource_path)
				else:
					print("警告：无法加载资源文件 ", resource_path)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("警告：无法打开data/enemies目录")

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
			print("地图配置加载成功")
		else:
			print("错误：无法解析地图配置JSON")
			create_default_map_config()
	else:
		print("警告：地图配置文件不存在，创建默认配置")
		create_default_map_config()

## 创建默认地图配置
func create_default_map_config() -> void:
	map_config = {
		"floors": 15,
		"nodes_per_floor": [2, 4],
		"node_types": {
			"enemy": {"weight": 50},
			"elite": {"weight": 15, "min_floor": 5},
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
