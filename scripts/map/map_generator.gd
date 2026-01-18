extends Node
class_name MapGenerator

## 地图生成器
## 生成类杀戮尖塔风格的垂直地图

# 地图节点场景
const MAP_NODE_SCENE = preload("res://scenes/map/map_node.tscn")

# 生成的地图节点
var map_nodes: Dictionary = {}  # node_id -> MapNode
var floor_nodes: Array[Array] = []  # 每层的节点数组

## 生成地图
func generate_map(config: Dictionary) -> Dictionary:
	map_nodes.clear()
	floor_nodes.clear()
	
	var floors = config.get("floors", 15)
	var nodes_per_floor_range = config.get("nodes_per_floor", [2, 4])
	var node_types_config = config.get("node_types", {})
	var boss_floor = config.get("boss_floor", floors)
	
	# 生成每一层的节点
	for floor_num in range(1, floors + 1):
		var floor_node_list: Array[MapNode] = []
		
		# 确定这一层的节点数量
		var node_count = randi_range(nodes_per_floor_range[0], nodes_per_floor_range[1])
		
		# 最后一层是BOSS
		if floor_num == boss_floor:
			var boss_node = create_node("boss_" + str(floor_num), MapNode.NodeType.BOSS, floor_num, 0)
			if boss_node:
				floor_node_list.append(boss_node)
		else:
			# 生成普通节点
			for i in range(node_count):
				var node_type = select_node_type(floor_num, node_types_config)
				var node_id = "node_f" + str(floor_num) + "_" + str(i)
				var node = create_node(node_id, node_type, floor_num, i)
				if node:
					floor_node_list.append(node)
		
		floor_nodes.append(floor_node_list)
	
	# 连接节点（每个节点连接到下一层的所有节点）
	connect_nodes()
	
	return {
		"nodes": map_nodes,
		"floors": floor_nodes
	}

## 创建节点
func create_node(node_id: String, node_type: MapNode.NodeType, floor: int, position: int) -> MapNode:
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

## 选择节点类型
func select_node_type(floor_num: int, node_types_config: Dictionary) -> MapNode.NodeType:
	# 构建权重列表
	var weights: Array = []
	var types: Array = []
	
	for type_name in node_types_config.keys():
		var type_config = node_types_config[type_name]
		var weight = type_config.get("weight", 10)
		var min_floor = type_config.get("min_floor", 0)
		
		# 确保权重是整数
		weight = int(weight)
		
		# 检查楼层限制
		if floor_num >= min_floor:
			weights.append(weight)
			types.append(type_name)
	
	# 根据权重随机选择
	var total_weight: int = 0
	for w in weights:
		total_weight += int(w)
	
	if total_weight <= 0:
		print("警告：总权重为0，使用默认节点类型")
		return MapNode.NodeType.ENEMY
	
	var random_value = randi() % total_weight
	var current_weight: int = 0
	
	for i in range(weights.size()):
		current_weight += int(weights[i])
		if random_value < current_weight:
			return type_name_to_enum(types[i])
	
	# 默认返回普通战斗
	return MapNode.NodeType.ENEMY

## 类型名称转枚举
func type_name_to_enum(type_name: String) -> MapNode.NodeType:
	match type_name:
		"enemy":
			return MapNode.NodeType.ENEMY
		"elite":
			return MapNode.NodeType.ELITE
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

## 连接节点
func connect_nodes() -> void:
	# 每一层的节点连接到下一层的所有节点
	for floor_idx in range(floor_nodes.size() - 1):
		var current_floor = floor_nodes[floor_idx]
		var next_floor = floor_nodes[floor_idx + 1]
		
		for current_node in current_floor:
			for next_node in next_floor:
				current_node.add_connection(next_node.node_id)

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
