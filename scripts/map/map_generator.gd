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

# 生成的地图数据
var map_nodes: Dictionary = {}  # node_id -> MapNodeData
var floor_nodes: Array = []  # 每层的节点数组，索引0是第1层（最底层）

# 连接数据：connections[floor_idx] = Array of connections
# 每个connection是 [from_node_idx, to_node_idx]
var connections: Array = []

# 地图生成专用 RNG：必须只由 map_seed 决定，避免被全局/战斗等随机消耗影响
var _map_rng: RandomNumberGenerator = RandomNumberGenerator.new()

## 获取地图 RNG（保证每次 generate_map() 都已正确设种子）
func _get_map_rng() -> RandomNumberGenerator:
	return _map_rng

## 生成地图
## 说明：地图随机只应由 map_seed 决定。
## - 如果传入 seed_override != -1，则使用该 seed。
## - 否则优先使用 RunManager.map_seed。
## - 若仍为 -1，则随机化一次（不保证可复现）。
func generate_map(config: Dictionary = {}, seed_override: int = -1) -> Dictionary:
	map_nodes.clear()
	floor_nodes.clear()
	connections.clear()
	
	var effective_seed: int = seed_override
	if effective_seed == -1 and RunManager and RunManager.map_seed != -1:
		effective_seed = RunManager.map_seed
	
	if effective_seed != -1:
		_map_rng.seed = effective_seed
	else:
		_map_rng.randomize()
	
	# 步骤1：生成每一阶的节点数量
	var nodes_per_floor = _generate_floor_node_counts()
	
	# 步骤2：创建所有节点
	_create_all_nodes(nodes_per_floor, config)
	
	# 步骤3：生成连接（核心算法）
	_generate_connections(nodes_per_floor)
	
	# 步骤4：将连接信息写入节点
	_apply_connections_to_nodes()
	
	# 步骤5：分配节点类型（在连接生成之后，避免路径上出现连续的特殊房间）
	_assign_node_types(config)
	
	return {
		"nodes": map_nodes,
		"floors": floor_nodes,
		"connections": connections
	}

## 步骤1：生成每一阶的节点数量
func _generate_floor_node_counts() -> Array:
	var counts: Array = []
	var rng: RandomNumberGenerator = _get_map_rng()
	
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
			count = rng.randi_range(MIN_NODES_PER_FLOOR, MAX_NODES_PER_FLOOR)
		
		counts.append(count)
	
	return counts

## 步骤2：创建所有节点
func _create_all_nodes(nodes_per_floor: Array, _config: Dictionary) -> void:
	for floor_idx in range(nodes_per_floor.size()):
		var floor_num = floor_idx + 1  # 阶层从1开始
		var node_count = nodes_per_floor[floor_idx]
		var floor_node_list: Array = []
		
		for node_idx in range(node_count):
			var node_id = "node_f%d_%d" % [floor_num, node_idx]
			var node = _create_node(node_id, MapNodeData.NodeType.ENEMY, floor_num, node_idx)
			if node:
				floor_node_list.append(node)
		
		floor_nodes.append(floor_node_list)

## 创建单个节点
func _create_node(node_id: String, node_type: MapNodeData.NodeType, floor: int, position: int) -> MapNodeData:
	var node := MapNodeData.new()
	if not node:
		print("错误：无法创建MapNodeData")
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
func _select_node_type(floor_num: int, node_types_config: Dictionary) -> MapNodeData.NodeType:
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
		return MapNodeData.NodeType.ENEMY
	
	var rng: RandomNumberGenerator = _get_map_rng()
	var random_value: int = rng.randi_range(0, total_weight - 1)
	var current_weight: int = 0
	
	for i in range(weights.size()):
		current_weight += weights[i]
		if random_value < current_weight:
			return _type_name_to_enum(types[i])
	
	return MapNodeData.NodeType.ENEMY

## 类型名称转枚举
func _type_name_to_enum(type_name: String) -> MapNodeData.NodeType:
	match type_name:
		"enemy":
			return MapNodeData.NodeType.ENEMY
		"treasure":
			return MapNodeData.NodeType.TREASURE
		"shop":
			return MapNodeData.NodeType.SHOP
		"rest":
			return MapNodeData.NodeType.REST
		"event":
			return MapNodeData.NodeType.EVENT
		"boss":
			return MapNodeData.NodeType.BOSS
		_:
			return MapNodeData.NodeType.ENEMY


func _is_restricted_type(node_type: int) -> bool:
	return node_type == MapNodeData.NodeType.SHOP \
		or node_type == MapNodeData.NodeType.TREASURE \
		or node_type == MapNodeData.NodeType.REST


func _get_boss_floor_from_config(config: Dictionary) -> int:
	var boss_floor: int = int(config.get("boss_floor", TOTAL_FLOORS))
	boss_floor = clampi(boss_floor, 1, TOTAL_FLOORS)
	return boss_floor


func _get_forced_node_type_for_floor(floor_num: int, boss_floor: int) -> int:
	if floor_num == boss_floor:
		return MapNodeData.NodeType.BOSS
	if floor_num == boss_floor - 1:
		return MapNodeData.NodeType.REST
	if floor_num == 6:
		return MapNodeData.NodeType.REST
	if floor_num == 1:
		return MapNodeData.NodeType.ENEMY
	return -1


func _build_incoming_node_map() -> Dictionary:
	var incoming: Dictionary = {}
	for floor_idx in range(connections.size()):
		var floor_conns: Array = connections[floor_idx]
		var current_floor: Array = floor_nodes[floor_idx]
		var next_floor: Array = floor_nodes[floor_idx + 1]
		for conn in floor_conns:
			var out_idx: int = conn[0]
			var in_idx: int = conn[1]
			if out_idx < 0 or out_idx >= current_floor.size():
				continue
			if in_idx < 0 or in_idx >= next_floor.size():
				continue
			var from_node: MapNodeData = current_floor[out_idx]
			var to_node: MapNodeData = next_floor[in_idx]
			var list: Array = incoming.get(to_node.node_id, [])
			list.append(from_node.node_id)
			incoming[to_node.node_id] = list
	return incoming


func _select_node_type_with_constraints(floor_num: int, node_types_config: Dictionary, forbidden_types: Dictionary) -> MapNodeData.NodeType:
	var weights: Array = []
	var types: Array = []
	for type_name in node_types_config.keys():
		var type_config: Dictionary = node_types_config[type_name]
		var weight: int = int(type_config.get("weight", 10))
		var min_floor: int = int(type_config.get("min_floor", 0))
		if floor_num < min_floor:
			continue
		var enum_type: MapNodeData.NodeType = _type_name_to_enum(type_name)
		if forbidden_types.has(enum_type):
			continue
		weights.append(weight)
		types.append(type_name)
	
	var total_weight: int = 0
	for w in weights:
		total_weight += w
	if total_weight <= 0:
		return MapNodeData.NodeType.ENEMY
	
	var rng: RandomNumberGenerator = _get_map_rng()
	var random_value: int = rng.randi_range(0, total_weight - 1)
	var current_weight: int = 0
	for i in range(weights.size()):
		current_weight += weights[i]
		if random_value < current_weight:
			return _type_name_to_enum(types[i])
	return MapNodeData.NodeType.ENEMY


func _node_type_to_display_name(node_type: int) -> String:
	match node_type:
		MapNodeData.NodeType.ENEMY:
			return "普通战斗"
		MapNodeData.NodeType.TREASURE:
			return "宝箱"
		MapNodeData.NodeType.SHOP:
			return "商店"
		MapNodeData.NodeType.REST:
			return "休息处"
		MapNodeData.NodeType.EVENT:
			return "奇遇事件"
		MapNodeData.NodeType.BOSS:
			return "BOSS战"
		_:
			return "未知"


func _assign_node_types(config: Dictionary) -> void:
	var boss_floor: int = _get_boss_floor_from_config(config)
	var node_types_config: Dictionary = config.get("node_types", _get_default_node_types_config())
	var incoming_map: Dictionary = _build_incoming_node_map()
	
	for floor_idx in range(floor_nodes.size()):
		var floor_num: int = floor_idx + 1
		var forced_type: int = _get_forced_node_type_for_floor(floor_num, boss_floor)
		var floor_list: Array = floor_nodes[floor_idx]
		for node in floor_list:
			var map_node: MapNodeData = node
			if forced_type != -1:
				map_node.node_type = forced_type
				continue
			
			var forbidden: Dictionary = _get_forbidden_types_for_node(map_node, boss_floor, incoming_map)
			map_node.node_type = _select_node_type_with_constraints(floor_num, node_types_config, forbidden)
	
	_fix_consecutive_restricted_types(boss_floor, node_types_config, incoming_map)
	_validate_node_type_constraints(boss_floor)


func _get_forbidden_types_for_node(map_node: MapNodeData, boss_floor: int, incoming_map: Dictionary) -> Dictionary:
	var forbidden: Dictionary = {}
	var parents: Array = incoming_map.get(map_node.node_id, [])
	for parent_id in parents:
		var parent_node: MapNodeData = map_nodes.get(parent_id)
		if parent_node and _is_restricted_type(parent_node.node_type):
			forbidden[parent_node.node_type] = true
	
	for child_id in map_node.connected_nodes:
		var child_node: MapNodeData = map_nodes.get(child_id)
		if not child_node:
			continue
		var child_forced_type: int = _get_forced_node_type_for_floor(child_node.floor_number, boss_floor)
		if child_forced_type != -1 and _is_restricted_type(child_forced_type):
			forbidden[child_forced_type] = true
	
	return forbidden


func _try_change_node_type(target_node: MapNodeData, boss_floor: int, node_types_config: Dictionary, incoming_map: Dictionary, conflict_type: int) -> bool:
	var forced_type: int = _get_forced_node_type_for_floor(target_node.floor_number, boss_floor)
	if forced_type != -1:
		return false

	var forbidden: Dictionary = _get_forbidden_types_for_node(target_node, boss_floor, incoming_map)
	if _is_restricted_type(conflict_type):
		forbidden[conflict_type] = true

	var new_type: MapNodeData.NodeType = _select_node_type_with_constraints(target_node.floor_number, node_types_config, forbidden)
	if new_type == target_node.node_type:
		return false

	target_node.node_type = new_type
	return true


func _fix_consecutive_restricted_types(boss_floor: int, node_types_config: Dictionary, incoming_map: Dictionary) -> void:
	var max_passes: int = 20
	for _pass_idx in range(max_passes):
		var changed: bool = false
		for floor_idx in range(connections.size()):
			var current_floor: Array = floor_nodes[floor_idx]
			var next_floor: Array = floor_nodes[floor_idx + 1]
			for conn in connections[floor_idx]:
				var out_idx: int = conn[0]
				var in_idx: int = conn[1]
				if out_idx < 0 or out_idx >= current_floor.size():
					continue
				if in_idx < 0 or in_idx >= next_floor.size():
					continue
				var from_node: MapNodeData = current_floor[out_idx]
				var to_node: MapNodeData = next_floor[in_idx]
				if _is_restricted_type(from_node.node_type) and from_node.node_type == to_node.node_type:
					if _try_change_node_type(to_node, boss_floor, node_types_config, incoming_map, from_node.node_type):
						changed = true
					elif _try_change_node_type(from_node, boss_floor, node_types_config, incoming_map, to_node.node_type):
						changed = true
		if not changed:
			break


func _validate_node_type_constraints(boss_floor: int) -> void:
	# 强制层校验
	for floor_idx in range(floor_nodes.size()):
		var floor_num: int = floor_idx + 1
		var forced_type: int = _get_forced_node_type_for_floor(floor_num, boss_floor)
		if forced_type == -1:
			continue
		for node in floor_nodes[floor_idx]:
			var map_node: MapNodeData = node
			if map_node.node_type != forced_type:
				push_warning("地图生成校验失败：第%d层节点%s类型=%s，期望=%s" % [
					floor_num,
					map_node.node_id,
					map_node.get_type_name(),
					_node_type_to_display_name(forced_type)
				])
				break
	
	# 相邻限制类型校验（任意连接）
	for floor_idx in range(connections.size()):
		var current_floor: Array = floor_nodes[floor_idx]
		var next_floor: Array = floor_nodes[floor_idx + 1]
		for conn in connections[floor_idx]:
			var out_idx: int = conn[0]
			var in_idx: int = conn[1]
			if out_idx < 0 or out_idx >= current_floor.size():
				continue
			if in_idx < 0 or in_idx >= next_floor.size():
				continue
			var from_node: MapNodeData = current_floor[out_idx]
			var to_node: MapNodeData = next_floor[in_idx]
			if _is_restricted_type(from_node.node_type) and from_node.node_type == to_node.node_type:
				push_warning("地图生成校验失败：出现连续同类房间 %s(%s)->%s(%s)" % [
					from_node.node_id,
					from_node.get_type_name(),
					to_node.node_id,
					to_node.get_type_name()
				])

## 步骤3：生成连接（核心算法）
## 自下而上生成，从终点（最后一层）开始向前生成连接
## 确保：
## - 每个输出点连接1-3个输入点
## - 每个输入点至少有一个连接（除了起点）
## - 线不能交叉
## - 限制连接范围，避免跨度过大的连接
func _generate_connections(nodes_per_floor: Array) -> void:
	connections.clear()
	
	# 预先分配connections数组大小
	var total_floors = nodes_per_floor.size()
	for i in range(total_floors - 1):
		connections.append([])
	
	# 自下而上生成：从最后一层开始向前生成连接
	# connections数组按从下到上的顺序存储
	# 即 connections[0] 是第1层到第2层的连接
	# connections[14] 是第15层到第16层的连接
	for floor_idx in range(total_floors - 1, 0, -1):
		var upper_count = nodes_per_floor[floor_idx - 1]  # 上层（更接近起点）
		var lower_count = nodes_per_floor[floor_idx]      # 下层（更接近终点）
		
		# 生成上层到下层（自下而上视角：下层连接到上层）的连接
		# 存储时按照 [上层索引, 下层索引] 的格式
		var floor_connections = _generate_floor_connections(upper_count, lower_count, floor_idx - 1)
		# 存储到正确的位置（floor_idx - 1 对应从下到上的索引）
		connections[floor_idx - 1] = floor_connections

## 生成单层到下一层的连接
## 自下而上生成，限制连接范围避免跨度过大
## current_count: 上层节点数（更接近起点）
## next_count: 下层节点数（更接近终点）
## floor_idx: 当前楼层索引（用于调试）
func _generate_floor_connections(current_count: int, next_count: int, floor_idx: int = 0) -> Array:
	# 先生成所有单个输出点到多个输入点的可能连接
	# 限制连接范围，避免跨度过大
	var all_single_output_possibilities: Array = []
	
	for out_idx in range(current_count):
		var possibilities = _get_single_output_connections_limited(out_idx, current_count, next_count)
		all_single_output_possibilities.append(possibilities)
	
	# 递归生成所有组合
	var all_combinations: Array = []
	_generate_all_combinations(all_single_output_possibilities, 0, [], all_combinations)
	
	# 过滤有效的组合
	var valid_combinations = _filter_valid_combinations(all_combinations, current_count, next_count)
	
	# 如果没有有效组合，使用回退方案
	if valid_combinations.is_empty():
		return _generate_fallback_connections_limited(current_count, next_count)
	
	# 随机选择一个有效组合
	var rng: RandomNumberGenerator = _get_map_rng()
	var selected_idx: int = rng.randi_range(0, valid_combinations.size() - 1)
	var selected = valid_combinations[selected_idx]
	return selected

## 获取单个输出点到多个输入点的所有可能连接（限制范围版本）
## 每个输出点可以连接1-3个输入点
## 限制连接范围，避免跨度过大的连接
func _get_single_output_connections_limited(out_idx: int, current_count: int, next_count: int) -> Array:
	var possibilities: Array = []
	
	# 计算该输出点的理想连接位置（基于位置比例）
	var out_ratio = float(out_idx) / float(maxi(current_count - 1, 1))
	var ideal_in_idx = int(out_ratio * (next_count - 1))
	
	# 限制连接范围：允许连接到理想位置附近的节点
	# 最大跨度：根据节点数量动态调整
	var max_span: int
	if next_count <= 3:
		max_span = 1  # 节点少时，跨度小
	elif next_count <= 5:
		max_span = 2  # 节点中等时，跨度中等
	else:
		max_span = 2  # 节点多时，跨度仍然限制
	
	# 获取允许连接的输入点索引范围
	var allowed_input_indices: Array = []
	for in_idx in range(next_count):
		var distance = abs(in_idx - ideal_in_idx)
		if distance <= max_span:
			allowed_input_indices.append(in_idx)
	
	# 如果没有允许的连接，至少连接最近的节点
	if allowed_input_indices.is_empty():
		allowed_input_indices.append(clampi(ideal_in_idx, 0, next_count - 1))
	
	# 生成1到MIN(MAX_CONNECTIONS, allowed_input_indices.size())个连接的所有子集
	var max_conn = mini(MAX_CONNECTIONS, allowed_input_indices.size())
	max_conn = maxi(max_conn, MIN_CONNECTIONS)  # 至少MIN_CONNECTIONS个
	
	for conn_count in range(MIN_CONNECTIONS, max_conn + 1):
		var subsets = _get_subsets_of_size(allowed_input_indices, conn_count)
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
	# 检查每个输出点连接的数量（1-3个）
	var output_connection_count: Array = []
	for i in range(current_count):
		output_connection_count.append(0)
	
	# 检查每个输入点是否至少有一个连接
	var input_connected: Array = []
	for i in range(next_count):
		input_connected.append(false)
	
	for conn in combination:
		var out_idx = conn[0]
		var in_idx = conn[1]
		output_connection_count[out_idx] += 1
		input_connected[in_idx] = true
	
	# 检查每个输出点连接数量是否在1-3之间
	for count in output_connection_count:
		if count < MIN_CONNECTIONS or count > MAX_CONNECTIONS:
			return false
	
	# 检查每个输入点是否至少有一个连接
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

## 回退方案：简单连接保证每个点都有输入输出（限制范围版本）
func _generate_fallback_connections_limited(current_count: int, next_count: int) -> Array:
	var result: Array = []
	
	# 策略：每个输出点连接到附近的输入点，并确保所有输入点都被覆盖
	# 同时确保每个输出点连接1-3个输入点
	var input_connected: Array = []
	for i in range(next_count):
		input_connected.append(false)
	
	var output_connection_count: Array = []
	for i in range(current_count):
		output_connection_count.append(0)
	
	# 计算最大连接跨度
	var max_span: int
	if next_count <= 3:
		max_span = 1
	elif next_count <= 5:
		max_span = 2
	else:
		max_span = 2
	
	# 首先，每个输出点至少连接到其对应比例位置的输入点（限制在范围内）
	for out_idx in range(current_count):
		# 计算对应的输入点位置
		var ratio = float(out_idx) / float(maxi(current_count - 1, 1))
		var ideal_in_idx = int(ratio * (next_count - 1))
		ideal_in_idx = clampi(ideal_in_idx, 0, next_count - 1)
		
		# 找到最近的允许连接的输入点
		var best_in_idx = ideal_in_idx
		var min_distance = abs(best_in_idx - ideal_in_idx)
		
		for in_idx in range(next_count):
			var distance = abs(in_idx - ideal_in_idx)
			if distance <= max_span and distance < min_distance:
				best_in_idx = in_idx
				min_distance = distance
		
		result.append([out_idx, best_in_idx])
		input_connected[best_in_idx] = true
		output_connection_count[out_idx] += 1
		
		# 如果输出点连接数还少于MIN_CONNECTIONS，尝试添加更多附近的连接
		while output_connection_count[out_idx] < MIN_CONNECTIONS:
			var added = false
			# 优先连接附近的输入点
			for offset in range(1, max_span + 1):
				for direction in [-1, 1]:
					var test_in_idx = best_in_idx + offset * direction
					if test_in_idx < 0 or test_in_idx >= next_count:
						continue
					
					var test_conn = [out_idx, test_in_idx]
					var test_result = result.duplicate()
					test_result.append(test_conn)
					
					# 检查是否会产生交叉
					if not _has_crossing_lines(test_result):
						if output_connection_count[out_idx] < MAX_CONNECTIONS:
							result.append(test_conn)
							output_connection_count[out_idx] += 1
							if not input_connected[test_in_idx]:
								input_connected[test_in_idx] = true
							added = true
							break
				if added:
					break
			
			if not added:
				break
	
	# 确保所有输入点都被连接
	for in_idx in range(next_count):
		if not input_connected[in_idx]:
			# 找最近的输出点来连接，但要确保该输出点连接数不超过MAX_CONNECTIONS
			var best_out_idx = _find_nearest_output_with_limit_limited(in_idx, current_count, next_count, result, output_connection_count, max_span)
			if best_out_idx >= 0:
				result.append([best_out_idx, in_idx])
				input_connected[in_idx] = true
				output_connection_count[best_out_idx] += 1
	
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

## 找到最近的输出点（不产生交叉，且考虑连接数限制和范围限制）
func _find_nearest_output_with_limit(in_idx: int, current_count: int, next_count: int, existing_connections: Array, output_connection_count: Array) -> int:
	var ratio = float(in_idx) / float(maxi(next_count - 1, 1))
	var ideal_out_idx = int(ratio * (current_count - 1))
	ideal_out_idx = clampi(ideal_out_idx, 0, current_count - 1)
	
	# 检查是否会产生交叉，如果是就找相邻的
	# 同时确保输出点连接数不超过MAX_CONNECTIONS
	for offset in range(current_count):
		for direction in [0, 1, -1]:
			var out_idx = ideal_out_idx + offset * direction
			if out_idx < 0 or out_idx >= current_count:
				continue
			
			# 检查该输出点是否已达到最大连接数
			if output_connection_count[out_idx] >= MAX_CONNECTIONS:
				continue
			
			var test_conn = [out_idx, in_idx]
			var test_result = existing_connections.duplicate()
			test_result.append(test_conn)
			
			if not _has_crossing_lines(test_result):
				return out_idx
	
	return -1  # 如果找不到合适的输出点，返回-1

## 找到最近的输出点（限制范围版本）
func _find_nearest_output_with_limit_limited(in_idx: int, current_count: int, next_count: int, existing_connections: Array, output_connection_count: Array, max_span: int) -> int:
	var ratio = float(in_idx) / float(maxi(next_count - 1, 1))
	var ideal_out_idx = int(ratio * (current_count - 1))
	ideal_out_idx = clampi(ideal_out_idx, 0, current_count - 1)
	
	# 计算输出点的最大跨度
	var out_max_span: int
	if current_count <= 3:
		out_max_span = 1
	elif current_count <= 5:
		out_max_span = 2
	else:
		out_max_span = 2
	
	# 检查是否会产生交叉，如果是就找相邻的
	# 同时确保输出点连接数不超过MAX_CONNECTIONS，且距离在允许范围内
	for offset in range(mini(out_max_span + 1, current_count)):
		for direction in [0, 1, -1]:
			var out_idx = ideal_out_idx + offset * direction
			if out_idx < 0 or out_idx >= current_count:
				continue
			
			# 检查距离是否在允许范围内
			var distance = abs(out_idx - ideal_out_idx)
			if distance > out_max_span:
				continue
			
			# 检查该输出点是否已达到最大连接数
			if output_connection_count[out_idx] >= MAX_CONNECTIONS:
				continue
			
			var test_conn = [out_idx, in_idx]
			var test_result = existing_connections.duplicate()
			test_result.append(test_conn)
			
			if not _has_crossing_lines(test_result):
				return out_idx
	
	return -1  # 如果找不到合适的输出点，返回-1

## 步骤4：将连接信息写入节点
func _apply_connections_to_nodes() -> void:
	for floor_idx in range(connections.size()):
		var floor_conns = connections[floor_idx]
		var current_floor = floor_nodes[floor_idx]
		var next_floor = floor_nodes[floor_idx + 1]
		
		# 统计每个输出点的连接数
		var output_connection_count: Dictionary = {}
		for out_idx in range(current_floor.size()):
			output_connection_count[out_idx] = 0
		
		for conn in floor_conns:
			var out_idx = conn[0]
			var in_idx = conn[1]
			
			if out_idx < current_floor.size() and in_idx < next_floor.size():
				var from_node = current_floor[out_idx]
				var to_node = next_floor[in_idx]
				from_node.add_connection(to_node.node_id)
				output_connection_count[out_idx] = output_connection_count.get(out_idx, 0) + 1
		
		# 验证每个输出点的连接数（除了最后一层，因为最后一层没有输出）
		if floor_idx < connections.size() - 1:
			for out_idx in range(current_floor.size()):
				var conn_count = output_connection_count.get(out_idx, 0)
				if conn_count < MIN_CONNECTIONS or conn_count > MAX_CONNECTIONS:
					print("警告：节点 %s 的连接数为 %d，不符合要求（应为 %d-%d）" % [
						current_floor[out_idx].node_id, 
						conn_count, 
						MIN_CONNECTIONS, 
						MAX_CONNECTIONS
					])
		
		# 验证每个输入点的连接数（除了第一层，因为第一层没有输入）
		if floor_idx > 0:
			var input_connection_count: Dictionary = {}
			for in_idx in range(next_floor.size()):
				input_connection_count[in_idx] = 0
			
			for conn in floor_conns:
				var in_idx = conn[1]
				if in_idx < next_floor.size():
					input_connection_count[in_idx] = input_connection_count.get(in_idx, 0) + 1
			
			for in_idx in range(next_floor.size()):
				var conn_count = input_connection_count.get(in_idx, 0)
				if conn_count < MIN_CONNECTIONS:
					print("警告：节点 %s 的输入连接数为 %d，不符合要求（至少应为 %d）" % [
						next_floor[in_idx].node_id, 
						conn_count, 
						MIN_CONNECTIONS
					])

## 获取起始节点（第一层的所有节点）
func get_start_nodes() -> Array:
	if floor_nodes.is_empty():
		return []
	return floor_nodes[0]

## 获取地图节点
func get_map_node(node_id: String) -> MapNodeData:
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
