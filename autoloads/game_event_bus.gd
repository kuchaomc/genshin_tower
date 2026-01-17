extends Node
class_name GameEventBus

# 全局事件总线 - 用于场景间通信
# 设置为自动加载（singleton），可在任意脚本中通过 GameEventBus 访问

# 信号定义
signal room_completed(room_position: Vector2i)  # 房间完成时触发，参数：房间位置(layer, index)
signal return_to_map()                          # 返回地图界面
signal game_over()                              # 游戏结束（玩家死亡）
signal map_generated()                          # 地图生成完成
signal room_selected(room_position: Vector2i)   # 房间被选中
signal battle_started(room_position: Vector2i)  # 战斗开始

# 地图相关事件
signal map_initialized()                        # 地图初始化完成
signal player_position_changed(old_pos: Vector2i, new_pos: Vector2i)  # 玩家位置变化

# 游戏状态变量
var current_map_data: Dictionary = {}           # 当前地图数据
var current_room_position: Vector2i = Vector2i.ZERO  # 当前所在房间位置
var enemies_defeated_in_current_room: int = 0   # 当前房间已击败敌人数量
var total_enemies_defeated: int = 0             # 总击败敌人数量
var is_in_battle: bool = false                  # 是否在战斗中

func _ready() -> void:
	# 初始化时重置状态
	reset_game_state()
	print("GameEventBus 已加载")

# 重置游戏状态
func reset_game_state() -> void:
	current_map_data.clear()
	current_room_position = Vector2i.ZERO
	enemies_defeated_in_current_room = 0
	total_enemies_defeated = 0
	is_in_battle = false
	print("游戏状态已重置")

# 设置当前地图数据
func set_map_data(map_data: Dictionary) -> void:
	current_map_data = map_data
	map_generated.emit()

# 获取当前地图数据
func get_map_data() -> Dictionary:
	return current_map_data

# 设置当前房间位置
func set_current_room_position(position: Vector2i) -> void:
	var old_position = current_room_position
	current_room_position = position
	player_position_changed.emit(old_position, position)
	print("玩家位置已更新: ", position)

# 获取当前房间位置
func get_current_room_position() -> Vector2i:
	return current_room_position

# 增加击败敌人计数（当前房间）
func add_enemy_defeated() -> void:
	enemies_defeated_in_current_room += 1
	total_enemies_defeated += 1
	print("击败敌人: 当前房间 ", enemies_defeated_in_current_room, " / 总 ", total_enemies_defeated)
	
	# 检查是否达到5个敌人（战斗房间胜利条件）
	if enemies_defeated_in_current_room >= 5 and is_in_battle:
		complete_current_room()

# 重置当前房间敌人计数
func reset_room_enemy_count() -> void:
	enemies_defeated_in_current_room = 0
	print("房间敌人计数已重置")

# 完成当前房间
func complete_current_room() -> void:
	print("房间完成: ", current_room_position)
	room_completed.emit(current_room_position)
	is_in_battle = false
	reset_room_enemy_count()

# 开始战斗
func start_battle() -> void:
	is_in_battle = true
	reset_room_enemy_count()
	battle_started.emit(current_room_position)
	print("战斗开始于房间: ", current_room_position)

# 触发游戏结束
func trigger_game_over() -> void:
	game_over.emit()
	print("游戏结束触发")

# 触发返回地图
func trigger_return_to_map() -> void:
	return_to_map.emit()
	print("返回地图触发")