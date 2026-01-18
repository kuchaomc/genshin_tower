extends Node2D

## 地图界面脚本

@onready var map_container: Node2D = $MapContainer
@onready var floor_label: Label = $CanvasLayer/VBoxContainer/FloorLabel
@onready var camera: Camera2D = $Camera2D

var map_generator: MapGenerator
var current_map: Dictionary = {}
var node_spacing: Vector2 = Vector2(250, 200)  # 节点之间的间距
var map_offset: Vector2 = Vector2(400, 100)  # 地图起始偏移（居中显示）

func _ready() -> void:
	# 检查必要的单例是否存在
	if not DataManager:
		print("错误：DataManager未找到")
		return
	
	if not RunManager:
		print("错误：RunManager未找到")
		return
	
	# 设置相机位置
	var camera = get_node_or_null("Camera2D")
	if camera:
		var viewport_size = get_viewport().get_visible_rect().size
		camera.position = Vector2(viewport_size.x / 2.0, viewport_size.y / 2.0)
	
	generate_and_display_map()
	
	# 更新楼层显示
	if floor_label:
		floor_label.text = "当前楼层: %d" % RunManager.current_floor

## 生成并显示地图
func generate_and_display_map() -> void:
	# 创建地图生成器
	map_generator = MapGenerator.new()
	add_child(map_generator)
	
	# 获取地图配置
	var config = DataManager.get_map_config()
	if config.is_empty():
		print("警告：地图配置为空，使用默认配置")
		config = {
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
	
	# 生成地图
	current_map = map_generator.generate_map(config)
	
	# 显示地图
	display_map()

## 显示地图
func display_map() -> void:
	if not map_container:
		print("错误：map_container未找到")
		return
	
	# 清空现有节点
	for child in map_container.get_children():
		child.queue_free()
	
	var floors = current_map.get("floors", [])
	if floors.is_empty():
		print("警告：没有生成任何楼层")
		return
	
	# 计算地图总宽度（用于居中）
	var max_nodes_per_floor = 0
	for floor_idx in range(floors.size()):
		var floor_nodes = floors[floor_idx]
		if floor_nodes.size() > max_nodes_per_floor:
			max_nodes_per_floor = floor_nodes.size()
	
	var map_width = max_nodes_per_floor * node_spacing.x
	var start_x = (get_viewport().get_visible_rect().size.x - map_width) / 2.0
	if start_x < 0:
		start_x = map_offset.x
	
	# 为每一层创建节点
	for floor_idx in range(floors.size()):
		var floor_nodes = floors[floor_idx]
		if floor_nodes.is_empty():
			continue
			
		var floor_y = map_offset.y + floor_idx * node_spacing.y
		
		# 计算这一层节点的起始X位置（居中）
		var floor_width = floor_nodes.size() * node_spacing.x
		var floor_start_x = start_x + (map_width - floor_width) / 2.0
		
		for node_idx in range(floor_nodes.size()):
			var node_data = floor_nodes[node_idx]
			if not node_data:
				continue
				
			var node_x = floor_start_x + node_idx * node_spacing.x
			
			# 创建新的节点实例
			var node_instance = MapNode.new()
			node_instance.node_id = node_data.node_id
			node_instance.node_type = node_data.node_type
			node_instance.floor_number = node_data.floor_number
			node_instance.position_in_floor = node_data.position_in_floor
			
			# 复制连接的节点（确保类型正确）
			if node_data.connected_nodes:
				for conn_id in node_data.connected_nodes:
					if conn_id is String:
						node_instance.connected_nodes.append(conn_id)
			
			node_instance.position = Vector2(node_x, floor_y)
			node_instance.node_selected.connect(_on_node_selected)
			map_container.add_child(node_instance)
	
	# 绘制所有连接线
	draw_all_connections(floors, start_x, map_width)

## 绘制所有连接线
func draw_all_connections(floors: Array, start_x: float, map_width: float) -> void:
	for floor_idx in range(floors.size() - 1):
		var current_floor = floors[floor_idx]
		var next_floor = floors[floor_idx + 1]
		
		if current_floor.is_empty() or next_floor.is_empty():
			continue
		
		var current_y = map_offset.y + floor_idx * node_spacing.y
		var next_y = map_offset.y + (floor_idx + 1) * node_spacing.y
		
		# 计算每层的节点位置
		for current_node in current_floor:
			if not current_node:
				continue
				
			var current_floor_width = current_floor.size() * node_spacing.x
			var current_floor_start_x = start_x + (map_width - current_floor_width) / 2.0
			var current_x = current_floor_start_x + current_node.position_in_floor * node_spacing.x
			var current_pos = Vector2(current_x, current_y)
			
			# 连接到下一层的所有节点
			for next_node in next_floor:
				if not next_node:
					continue
					
				var next_floor_width = next_floor.size() * node_spacing.x
				var next_floor_start_x = start_x + (map_width - next_floor_width) / 2.0
				var next_x = next_floor_start_x + next_node.position_in_floor * node_spacing.x
				var next_pos = Vector2(next_x, next_y)
				
				# 创建连接线
				var line = Line2D.new()
				line.width = 2.0
				line.default_color = Color(0.5, 0.5, 0.5, 0.3)
				line.add_point(current_pos)
				line.add_point(next_pos)
				line.z_index = -1  # 确保线条在节点下方
				map_container.add_child(line)

## 节点被选中
func _on_node_selected(node: MapNode) -> void:
	print("选择节点：", node.node_id, " 类型：", node.get_type_name())
	
	# 访问节点
	node.visit()
	
	# 根据节点类型执行相应操作
	match node.node_type:
		MapNode.NodeType.ENEMY, MapNode.NodeType.ELITE:
			start_battle(node)
		MapNode.NodeType.SHOP:
			enter_shop()
		MapNode.NodeType.REST:
			enter_rest()
		MapNode.NodeType.EVENT:
			enter_event()
		MapNode.NodeType.BOSS:
			start_boss_battle()

## 开始战斗
func start_battle(node: MapNode) -> void:
	if RunManager:
		RunManager.set_floor(node.floor_number)
	
	if GameManager:
		GameManager.start_battle()

## 进入商店
func enter_shop() -> void:
	if GameManager:
		GameManager.enter_shop()

## 进入休息处
func enter_rest() -> void:
	if GameManager:
		GameManager.enter_rest()

## 进入奇遇事件
func enter_event() -> void:
	if GameManager:
		GameManager.enter_event()

## 开始BOSS战
func start_boss_battle() -> void:
	if RunManager:
		RunManager.set_floor(RunManager.current_floor + 1)
	
	if GameManager:
		GameManager.start_boss_battle()
