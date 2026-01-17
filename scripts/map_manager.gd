extends Node
class_name MapManager

# 地图管理器 - 负责生成和管理杀戮尖塔式地图

# 常量定义
const LAYER_COUNT: int = 3              # 总层数
const NODES_PER_LAYER: int = 8          # 每层节点数
const START_NODES_COUNT: int = 3        # 起始节点数量
const START_NODE_INDICES: Array[int] = [0, 3, 6]  # 起始节点位置（第一层）
const BOSS_NODE_POSITION: Vector2i = Vector2i(2, 7)  # BOSS节点位置（层2，索引7）

# 房间类型分布比例（百分比）
const ROOM_DISTRIBUTION: Dictionary = {
	RoomTypes.RoomType.BATTLE_NORMAL: 50,   # 普通战斗 50%
	RoomTypes.RoomType.BATTLE_ELITE: 15,    # 精英战斗 15%
	RoomTypes.RoomType.SHOP: 10,            # 商店 10%
	RoomTypes.RoomType.REST: 10,            # 休息处 10%
	RoomTypes.RoomType.EVENT: 15,           # 随机事件 15%
	# BOSS 单独处理
}

# 节点连接配置
const MIN_CONNECTIONS: int = 1            # 最小连接数
const MAX_CONNECTIONS: int = 3            # 最大连接数

# 地图数据
var map_data: Array[Array] = []           # 二维数组：[层][位置] = RoomData
var connections: Dictionary = {}          # 连接关系：Vector2i起点 -> Array[Vector2i]终点列表
var available_rooms: Array[Vector2i] = [] # 当前可访问的房间位置
var visited_rooms: Array[Vector2i] = []   # 已访问的房间位置
var completed_rooms: Array[Vector2i] = [] # 已完成的房间位置
var current_position: Vector2i = Vector2i(-1, -1)  # 当前所在房间位置

# 初始化
func _ready() -> void:
	# 连接全局事件总线
	GameEventBus.room_completed.connect(_on_room_completed)
	GameEventBus.game_over.connect(_on_game_over)
	print("地图管理器已初始化")

# 生成新地图
func generate_new_map() -> void:
	print("开始生成新地图...")
	
	# 重置状态
	reset_map_state()
	
	# 创建空的层结构
	initialize_layers()
	
	# 分配房间类型
	assign_room_types()
	
	# 生成节点连接
	generate_connections()
	
	# 设置起始节点为可访问
	set_start_nodes_available()
	
	# 更新当前可访问房间列表
	update_available_rooms()
	
	# 发送地图数据到事件总线
	GameEventBus.set_map_data({
		"map_data": map_data,
		"connections": connections,
		"available_rooms": available_rooms
	})
	
	print("地图生成完成！")
	print("起始节点位置: ", get_start_node_positions())
	print("BOSS节点位置: ", BOSS_NODE_POSITION)

# 重置地图状态
func reset_map_state() -> void:
	map_data.clear()
	connections.clear()
	available_rooms.clear()
	visited_rooms.clear()
	completed_rooms.clear()
	current_position = Vector2i(-1, -1)

# 初始化层结构
func initialize_layers() -> void:
	for layer in range(LAYER_COUNT):
		var layer_nodes: Array = []
		for pos in range(NODES_PER_LAYER):
			# 先创建空位置，稍后分配房间类型
			layer_nodes.append(null)
		map_data.append(layer_nodes)

# 分配房间类型
func assign_room_types() -> void:
	# 计算每个类型需要的数量（不包括BOSS）
	var total_nodes = LAYER_COUNT * NODES_PER_LAYER - 1  # 减去BOSS节点
	var room_counts: Dictionary = {}
	
	# 根据比例计算每种房间的数量
	for room_type in ROOM_DISTRIBUTION:
		var percentage = ROOM_DISTRIBUTION[room_type]
		var count = int(total_nodes * percentage / 100.0)
		room_counts[room_type] = count
	
	# 调整数量以确保总和等于total_nodes
	var total_assigned = 0
	for count in room_counts.values():
		total_assigned += count
	
	# 如果总数不匹配，调整普通战斗数量
	if total_assigned != total_nodes:
		var diff = total_nodes - total_assigned
		room_counts[RoomTypes.RoomType.BATTLE_NORMAL] += diff
	
	# 创建房间类型列表
	var room_type_list: Array = []
	for room_type in room_counts:
		var count = room_counts[room_type]
		for i in range(count):
			room_type_list.append(room_type)
	
	# 打乱列表
	room_type_list.shuffle()
	
	# 分配房间类型到每个位置（除了BOSS节点）
	var type_index = 0
	for layer in range(LAYER_COUNT):
		for pos in range(NODES_PER_LAYER):
			# 跳过BOSS位置
			if Vector2i(layer, pos) == BOSS_NODE_POSITION:
				continue
			
			if type_index < room_type_list.size():
				var room_type = room_type_list[type_index]
				map_data[layer][pos] = RoomTypes.RoomData.new(room_type, Vector2i(layer, pos))
				type_index += 1
	
	# 创建BOSS房间
	map_data[BOSS_NODE_POSITION.x][BOSS_NODE_POSITION.y] = RoomTypes.RoomData.new(
		RoomTypes.RoomType.BOSS, BOSS_NODE_POSITION
	)

# 生成节点连接
func generate_connections() -> void:
	# 第一层到第二层连接
	for start_index in START_NODE_INDICES:
		var start_pos = Vector2i(0, start_index)
		connect_to_next_layer(start_pos, 1)
	
	# 第二层到第三层连接
	for layer in range(1, LAYER_COUNT - 1):
		for pos in range(NODES_PER_LAYER):
			var current_pos = Vector2i(layer, pos)
			# 如果这个位置有房间（不为null）
			if map_data[layer][pos] != null:
				connect_to_next_layer(current_pos, layer + 1)
	
	# 第三层所有节点连接到BOSS
	for pos in range(NODES_PER_LAYER):
		var current_pos = Vector2i(LAYER_COUNT - 1, pos)
		if map_data[LAYER_COUNT - 1][pos] != null:
			add_connection(current_pos, BOSS_NODE_POSITION)

# 连接节点到下一层
func connect_to_next_layer(from_pos: Vector2i, to_layer: int) -> void:
	# 随机选择1-3个目标位置
	var connection_count = randi_range(MIN_CONNECTIONS, MAX_CONNECTIONS)
	var available_positions = range(NODES_PER_LAYER)
	available_positions.shuffle()
	
	for i in range(min(connection_count, available_positions.size())):
		var to_pos = Vector2i(to_layer, available_positions[i])
		add_connection(from_pos, to_pos)

# 添加连接
func add_connection(from_pos: Vector2i, to_pos: Vector2i) -> void:
	if not connections.has(from_pos):
		connections[from_pos] = []
	
	if not connections[from_pos].has(to_pos):
		connections[from_pos].append(to_pos)
		print("添加连接: ", from_pos, " -> ", to_pos)

# 设置起始节点为可访问
func set_start_nodes_available() -> void:
	for start_index in START_NODE_INDICES:
		var pos = Vector2i(0, start_index)
		if map_data[0][start_index] != null:
			map_data[0][start_index].unlock()
			print("起始节点解锁: ", pos)

# 更新可访问房间列表
func update_available_rooms() -> void:
	available_rooms.clear()
	
	# 如果是首次进入地图，所有起始节点都可访问
	if current_position == Vector2i(-1, -1):
		for start_index in START_NODE_INDICES:
			var pos = Vector2i(0, start_index)
			if map_data[0][start_index] != null and map_data[0][start_index].is_accessible():
				available_rooms.append(pos)
	else:
		# 否则，当前房间连接的下一个房间可访问
		if connections.has(current_position):
			for next_pos in connections[current_position]:
				if is_valid_position(next_pos) and map_data[next_pos.x][next_pos.y].is_accessible():
					available_rooms.append(next_pos)

# 检查位置是否有效
func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < LAYER_COUNT and pos.y >= 0 and pos.y < NODES_PER_LAYER

# 获取起始节点位置列表
func get_start_node_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for index in START_NODE_INDICES:
		positions.append(Vector2i(0, index))
	return positions

# 选择房间
func select_room(room_position: Vector2i) -> bool:
	if not available_rooms.has(room_position):
		print("错误：房间不可访问 ", room_position)
		return false
	
	# 标记当前房间为已访问
	if current_position != Vector2i(-1, -1):
		visited_rooms.append(current_position)
	
	# 更新当前位置
	current_position = room_position
	
	# 标记新房间为已访问
	if not visited_rooms.has(room_position):
		visited_rooms.append(room_position)
	
	# 解锁连接的下一个房间
	if connections.has(room_position):
		for next_pos in connections[room_position]:
			if is_valid_position(next_pos) and map_data[next_pos.x][next_pos.y] != null:
				map_data[next_pos.x][next_pos.y].unlock()
	
	# 更新可访问房间列表
	update_available_rooms()
	
	# 更新事件总线
	GameEventBus.set_current_room_position(room_position)
	
	print("房间选择: ", room_position, " 类型: ", map_data[room_position.x][room_position.y].name)
	return true

# 完成当前房间
func complete_current_room() -> void:
	if current_position == Vector2i(-1, -1):
		return
	
	if is_valid_position(current_position) and map_data[current_position.x][current_position.y] != null:
		map_data[current_position.x][current_position.y].complete()
		completed_rooms.append(current_position)
		print("房间完成: ", current_position)

# 获取当前房间数据
func get_current_room() -> RoomTypes.RoomData:
	if current_position == Vector2i(-1, -1) or not is_valid_position(current_position):
		return null
	
	return map_data[current_position.x][current_position.y]

# 获取房间数据
func get_room_data(position: Vector2i) -> RoomTypes.RoomData:
	if not is_valid_position(position):
		return null
	
	return map_data[position.x][position.y]

# 获取房间连接
func get_room_connections(position: Vector2i) -> Array[Vector2i]:
	if connections.has(position):
		return connections[position].duplicate()
	return []

# 检查房间是否可访问
func is_room_available(position: Vector2i) -> bool:
	return available_rooms.has(position)

# 检查房间是否已完成
func is_room_completed(position: Vector2i) -> bool:
	return completed_rooms.has(position)

# 检查是否为战斗房间
func is_battle_room(position: Vector2i) -> bool:
	var room_data = get_room_data(position)
	if room_data == null:
		return false
	
	return room_data.is_battle_room()

# 事件处理
func _on_room_completed(room_position: Vector2i) -> void:
	print("收到房间完成事件: ", room_position)
	complete_current_room()

func _on_game_over() -> void:
	print("游戏结束，重置地图状态")
	reset_map_state()

# 获取整个地图数据（用于UI显示）
func get_full_map_data() -> Dictionary:
	return {
		"map_data": map_data,
		"connections": connections,
		"available_rooms": available_rooms,
		"visited_rooms": visited_rooms,
		"completed_rooms": completed_rooms,
		"current_position": current_position,
		"start_positions": get_start_node_positions(),
		"boss_position": BOSS_NODE_POSITION
	}