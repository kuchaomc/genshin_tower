extends Node
class_name MapGenerator

## 地图生成器
## 生成类杀戮尖塔风格的垂直地图
## 
## 规则：
## - 16阶，玩家可以行动15步
## - 每阶最多5个点，最少3个点
## - 6种房间：战斗、宝箱、休息、商店、奇遇、boss
## - 终点（第16阶）总是1个点（boss）
## - 倒数第二阶（第15阶）总是3个点（休息）
## - 每个点最多连接3个点，最少1个点
## - 线不能交叉
## - 每个点必须有输入和输出（除了起点和终点）

const TOTAL_FLOORS: int = 16
const MIN_NODES_PER_FLOOR: int = 3
const MAX_NODES_PER_FLOOR: int = 5
const MIN_CONNECTIONS: int = 1
const MAX_CONNECTIONS: int = 3

# 地图节点场景
const MAP_NODE_SCENE = preload("res://scenes/map/map_node.tscn")

# 生成的地图数据
var map_nodes: Dictionary = {}  # node_id -> MapNode
var floor_nodes: Array = []  # 每层的节点数组，索引0是第1层（最底层）

# 连接数据：connections[floor_idx] = Array of connections
# 每个connection是 [from_node_idx, to_node_idx]
var connections: Array = []

## 生成地图
func generate_map(config: Dictionary = {}) -> Dictionary:
	map_nodes.clear()
	floor_nodes.clear()
	connections.clear()
	
	# 步骤1：生成每一阶的节点数量
	var nodes_per_floor = _generate_floor_node_counts()
	
	# 步骤2：创建所有节点
	_create_all_nodes(nodes_per_floor, config)
	
	# 步骤3：生成连接（核心算法）
	_generate_connections(nodes_per_floor)
	
	# 步骤4：将连接信息写入节点
	_apply_connections_to_nodes()
	
	return {
		"nodes": map_nodes,
		"floors": floor_nodes,
		"connections": connections
	}

## 步骤1：生成每一阶的节点数量
func _generate_floor_node_counts() -> Array:
	var counts: Array = []
	
	for floor_num in range(1, TOTAL_FLOORS + 1):
		var count: int
		
		if floor_num == TOTAL_FLOORS:
			# 第16阶（终点）：1个BOSS节点
			count = 1
		elif floor_num == TOTAL_FLOORS - 1:
			# 第15阶（倒数第二）：3个休息节点
			count = 3
		else:
			# 其他阶层：3-5个节点
			count = randi_range(MIN_NODES_PER_FLOOR, MAX_NODES_PER_FLOOR)
		
		counts.append(count)
	
	return counts

## 步骤2：创建所有节点
func _create_all_nodes(nodes_per_floor: Array, config: Dictionary) -> void:
	var node_types_config = config.get("node_types", _get_default_node_types_config())
	
	for floor_idx in range(nodes_per_floor.size()):
		var floor_num = floor_idx + 1  # 阶层从1开始
		var node_count = nodes_per_floor[floor_idx]
		var floor_node_list: Array = []
		
		for node_idx in range(node_count):
			var node_type: MapNode.NodeType
			
			if floor_num == TOTAL_FLOORS:
				# 最后一阶是BOSS
				node_type = MapNode.NodeType.BOSS
			elif floor_num == TOTAL_FLOORS - 1:
				# 倒数第二阶是休息
				node_type = MapNode.NodeType.REST
			elif floor_num == 1:
				# 第一阶通常是战斗
				node_type = MapNode.NodeType.ENEMY
			else:
				# 根据权重随机选择类型
				node_type = _select_node_type(floor_num, node_types_config)
			
			var node_id = "node_f%d_%d" % [floor_num, node_idx]
			var node = _create_node(node_id, node_type, floor_num, node_idx)
			if node:
				floor_node_list.append(node)
		
		floor_nodes.append(floor_node_list)

## 创建单个节点
func _create_node(node_id: String, node_type: MapNode.NodeType, floor: int, position: int) -> MapNode:
	var node = MapNode.new()
	if not node:
		print("错误：无法创建MapNode")
		return null
	
	node.node_id = node_id
	node.node_type = node_type
	node.floor_number = floor
	node.position_in_floor = position
	
	map_nodes[node_id] = node
	return node

## 获取默认节点类型配置
func _get_default_node_types_config() -> Dictionary:
	return {
		"enemy": {"weight": 45, "min_floor": 1},
		"treasure": {"weight": 12, "min_floor": 2},
		"shop": {"weight": 10, "min_floor": 3},
		"rest": {"weight": 12, "min_floor": 4},
		"event": {"weight": 21, "min_floor": 2}
	}

## 选择节点类型
func _select_node_type(floor_num: int, node_types_config: Dictionary) -> MapNode.NodeType:
	var weights: Array = []
	var types: Array = []
	
	for type_name in node_types_config.keys():
		var type_config = node_types_config[type_name]
		var weight = int(type_config.get("weight", 10))
		var min_floor = int(type_config.get("min_floor", 0))
		
		if floor_num >= min_floor:
			weights.append(weight)
			types.append(type_name)
	
	var total_weight: int = 0
	for w in weights:
		total_weight += w
	
	if total_weight <= 0:
		return MapNode.NodeType.ENEMY
	
	var random_value = randi() % total_weight
	var current_weight: int = 0
	
	for i in range(weights.size()):
		current_weight += weights[i]
		if random_value < current_weight:
			return _type_name_to_enum(types[i])
	
	return MapNode.NodeType.ENEMY

## 类型名称转枚举
func _type_name_to_enum(type_name: String) -> MapNode.NodeType:
	match type_name:
		"enemy":
			return MapNode.NodeType.ENEMY
		"treasure":
			return MapNode.NodeType.TREASURE
		"shop":
			return MapNode.NodeType.SHOP
		"rest":
			return MapNode.NodeType.REST
		"event":
			return MapNode.NodeType.EVENT
		"boss":
			return MapNode.NodeType.BOSS
		_:
			return MapNode.NodeType.ENEMY

## 步骤3：生成连接（核心算法）
## 确保：
## - 每个输出点连接1-3个输入点
## - 每个输入点至少有一个连接（除了起点）
## - 线不能交叉
func _generate_connections(nodes_per_floor: Array) -> void:
	connections.clear()
	
	# 为每一层到下一层生成连接
	for floor_idx in range(nodes_per_floor.size() - 1):
		var current_count = nodes_per_floor[floor_idx]
		var next_count = nodes_per_floor[floor_idx + 1]
		
		# 生成这一层到下一层的所有有效连接
		var floor_connections = _generate_floor_connections(current_count, next_count)
		connections.append(floor_connections)

## 生成单层到下一层的连接
## 使用递归算法生成所有可能的连接组合，然后过滤
func _generate_floor_connections(current_count: int, next_count: int) -> Array:
	# 先生成所有单个输出点到多个输入点的可能连接
	var all_single_output_possibilities: Array = []
	
	for out_idx in range(current_count):
		var possibilities = _get_single_output_connections(out_idx, next_count)
		all_single_output_possibilities.append(possibilities)
	
	# 递归生成所有组合
	var all_combinations: Array = []
	_generate_all_combinations(all_single_output_possibilities, 0, [], all_combinations)
	
	# 过滤有效的组合
	var valid_combinations = _filter_valid_combinations(all_combinations, current_count, next_count)
	
	# 如果没有有效组合，使用回退方案
	if valid_combinations.is_empty():
		return _generate_fallback_connections(current_count, next_count)
	
	# 随机选择一个有效组合
	var selected = valid_combinations[randi() % valid_combinations.size()]
	return selected

## 获取单个输出点到多个输入点的所有可能连接
## 每个输出点可以连接1-3个输入点
func _get_single_output_connections(out_idx: int, next_count: int) -> Array:
	var possibilities: Array = []
	var input_indices: Array = []
	
	for i in range(next_count):
		input_indices.append(i)
	
	# 生成1到MIN(MAX_CONNECTIONS, next_count)个连接的所有子集
	var max_conn = mini(MAX_CONNECTIONS, next_count)
	
	for conn_count in range(MIN_CONNECTIONS, max_conn + 1):
		var subsets = _get_subsets_of_size(input_indices, conn_count)
		for subset in subsets:
			var conns: Array = []
			for in_idx in subset:
				conns.append([out_idx, in_idx])
			possibilities.append(conns)
	
	return possibilities

## 获取指定大小的所有子集
func _get_subsets_of_size(arr: Array, size: int) -> Array:
	var result: Array = []
	_generate_subsets(arr, size, 0, [], result)
	return result

## 递归生成子集
func _generate_subsets(arr: Array, size: int, start: int, current: Array, result: Array) -> void:
	if current.size() == size:
		result.append(current.duplicate())
		return
	
	for i in range(start, arr.size()):
		current.append(arr[i])
		_generate_subsets(arr, size, i + 1, current, result)
		current.pop_back()

## 递归生成所有输出点连接的组合
func _generate_all_combinations(
	all_possibilities: Array,
	current_out_idx: int,
	current_combination: Array,
	all_combinations: Array
) -> void:
	# 限制组合数量，防止指数爆炸
	if all_combinations.size() > 1000:
		return
	
	if current_out_idx >= all_possibilities.size():
		all_combinations.append(current_combination.duplicate())
		return
	
	var possibilities_for_this_output = all_possibilities[current_out_idx]
	for possibility in possibilities_for_this_output:
		var new_combination = current_combination.duplicate()
		new_combination.append_array(possibility)
		_generate_all_combinations(all_possibilities, current_out_idx + 1, new_combination, all_combinations)

## 过滤有效的连接组合
## 规则：
## 1. 每个输入点至少有一个连接
## 2. 没有交叉线
func _filter_valid_combinations(all_combinations: Array, current_count: int, next_count: int) -> Array:
	var valid: Array = []
	
	for combination in all_combinations:
		if _is_valid_combination(combination, current_count, next_count):
			valid.append(combination)
	
	return valid

## 检查组合是否有效
func _is_valid_combination(combination: Array, current_count: int, next_count: int) -> bool:
	# 检查每个输入点是否至少有一个连接
	var input_connected: Array = []
	for i in range(next_count):
		input_connected.append(false)
	
	for conn in combination:
		var in_idx = conn[1]
		input_connected[in_idx] = true
	
	for connected in input_connected:
		if not connected:
			return false
	
	# 检查是否有交叉线
	if _has_crossing_lines(combination):
		return false
	
	return true

## 检查是否有交叉线
## 两条线交叉的条件：
## 如果线A是(out1, in1)，线B是(out2, in2)
## 如果 (out1 < out2 且 in1 > in2) 或 (out1 > out2 且 in1 < in2)，则交叉
func _has_crossing_lines(combination: Array) -> bool:
	for i in range(combination.size()):
		for j in range(i + 1, combination.size()):
			var conn1 = combination[i]
			var conn2 = combination[j]
			
			var out1 = conn1[0]
			var in1 = conn1[1]
			var out2 = conn2[0]
			var in2 = conn2[1]
			
			# 检查是否交叉
			if (out1 < out2 and in1 > in2) or (out1 > out2 and in1 < in2):
				return true
	
	return false

## 回退方案：简单连接保证每个点都有输入输出
func _generate_fallback_connections(current_count: int, next_count: int) -> Array:
	var result: Array = []
	
	# 策略：每个输出点连接到最近的输入点，并确保所有输入点都被覆盖
	var input_connected: Array = []
	for i in range(next_count):
		input_connected.append(false)
	
	# 首先，每个输出点连接到其对应比例位置的输入点
	for out_idx in range(current_count):
		# 计算对应的输入点位置
		var ratio = float(out_idx) / float(maxi(current_count - 1, 1))
		var in_idx = int(ratio * (next_count - 1))
		in_idx = clampi(in_idx, 0, next_count - 1)
		
		result.append([out_idx, in_idx])
		input_connected[in_idx] = true
	
	# 确保所有输入点都被连接
	for in_idx in range(next_count):
		if not input_connected[in_idx]:
			# 找最近的输出点来连接
			var best_out_idx = _find_nearest_output(in_idx, current_count, next_count, result)
			result.append([best_out_idx, in_idx])
	
	return result

## 找到最近的输出点（不产生交叉）
func _find_nearest_output(in_idx: int, current_count: int, next_count: int, existing_connections: Array) -> int:
	var ratio = float(in_idx) / float(maxi(next_count - 1, 1))
	var ideal_out_idx = int(ratio * (current_count - 1))
	ideal_out_idx = clampi(ideal_out_idx, 0, current_count - 1)
	
	# 检查是否会产生交叉，如果是就找相邻的
	for offset in range(current_count):
		for direction in [0, 1, -1]:
			var out_idx = ideal_out_idx + offset * direction
			if out_idx < 0 or out_idx >= current_count:
				continue
			
			var test_conn = [out_idx, in_idx]
			var test_result = existing_connections.duplicate()
			test_result.append(test_conn)
			
			if not _has_crossing_lines(test_result):
				return out_idx
	
	return ideal_out_idx

## 步骤4：将连接信息写入节点
func _apply_connections_to_nodes() -> void:
	for floor_idx in range(connections.size()):
		var floor_conns = connections[floor_idx]
		var current_floor = floor_nodes[floor_idx]
		var next_floor = floor_nodes[floor_idx + 1]
		
		for conn in floor_conns:
			var out_idx = conn[0]
			var in_idx = conn[1]
			
			if out_idx < current_floor.size() and in_idx < next_floor.size():
				var from_node = current_floor[out_idx]
				var to_node = next_floor[in_idx]
				from_node.add_connection(to_node.node_id)

## 获取起始节点（第一层的所有节点）
func get_start_nodes() -> Array:
	if floor_nodes.is_empty():
		return []
	return floor_nodes[0]

## 获取地图节点
func get_map_node(node_id: String) -> MapNode:
	return map_nodes.get(node_id)

## 获取当前楼层的节点
func get_current_floor_nodes(floor_num: int) -> Array:
	if floor_num < 1 or floor_num > floor_nodes.size():
		return []
	return floor_nodes[floor_num - 1]

## 获取两层之间的连接
func get_connections_between_floors(floor_idx: int) -> Array:
	if floor_idx < 0 or floor_idx >= connections.size():
		return []
	return connections[floor_idx]
