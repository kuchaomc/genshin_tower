extends Node2D

## 地图界面脚本
## 地图从下往上显示，玩家从底部开始向上攀升

@onready var map_container: Node2D = $MapContainer
@onready var floor_label: Label = $CanvasLayer/VBoxContainer/FloorLabel
@onready var camera: Camera2D = $Camera2D

var map_generator: MapGenerator
var current_map: Dictionary = {}

# 布局参数
var node_spacing_x: float = 180.0  # 节点水平间距
var node_spacing_y: float = 150.0  # 节点垂直间距
var map_bottom_margin: float = 100.0  # 地图底部边距
var map_width: float = 1000.0  # 地图宽度

# 节点实例字典，用于绘制连接线
var node_instances: Dictionary = {}  # node_id -> MapNode instance

# 连接线字典，用于更新视觉状态
var connection_lines: Dictionary = {}  # "from_node_id_to_node_id" -> Line2D

# 当前可选择的节点（从起点出发或从已访问节点出发可达的节点）
var selectable_nodes: Array = []

# 所有可达节点（从起点开始）
var reachable_nodes: Dictionary = {}  # node_id -> bool

# 滚动和拖拽
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var camera_start_pos: Vector2 = Vector2.ZERO

# 缩放
var zoom_level: float = 1.0
var min_zoom: float = 0.5
var max_zoom: float = 2.0
var zoom_step: float = 0.1

func _ready() -> void:
	# 检查必要的单例是否存在
	if not DataManager:
		print("错误：DataManager未找到")
		return
	
	if not RunManager:
		print("错误：RunManager未找到")
		return
	
	# 如果是新游戏（current_node_id为空且没有地图种子），生成新地图种子
	# 否则重用现有地图（通过固定种子）
	if RunManager.current_node_id.is_empty() and RunManager.map_seed == -1:
		RunManager.map_seed = randi()
		print("生成新地图，种子：", RunManager.map_seed)
	else:
		print("重用现有地图，种子：", RunManager.map_seed)
	
	generate_and_display_map()
	
	# 更新楼层显示
	if floor_label:
		floor_label.text = "当前楼层: %d / 16" % RunManager.current_floor

func _input(event: InputEvent) -> void:
	# 处理鼠标拖拽滚动地图
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_start_pos = event.position
				camera_start_pos = camera.position
			else:
				is_dragging = false
		# 鼠标滚轮缩放
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(zoom_step, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(-zoom_step, event.position)
	
	elif event is InputEventMouseMotion and is_dragging:
		var delta = event.position - drag_start_pos
		camera.position = camera_start_pos - delta

## 缩放相机
func _zoom_camera(delta: float, mouse_screen_pos: Vector2) -> void:
	if not camera:
		return
	
	var viewport = get_viewport()
	var viewport_size = viewport.get_visible_rect().size
	
	# 计算鼠标相对于屏幕中心的位置
	var screen_center = viewport_size / 2.0
	var mouse_offset_from_center = mouse_screen_pos - screen_center
	
	# 计算鼠标指向的世界坐标（缩放前）
	# 世界坐标 = 相机位置 + (屏幕坐标 - 屏幕中心) / 缩放
	var mouse_world_before = camera.position + mouse_offset_from_center / camera.zoom.x
	
	# 更新缩放级别
	zoom_level = clampf(zoom_level + delta, min_zoom, max_zoom)
	camera.zoom = Vector2(zoom_level, zoom_level)
	
	# 计算缩放后鼠标应该指向的世界坐标
	var mouse_world_after = camera.position + mouse_offset_from_center / camera.zoom.x
	
	# 调整相机位置，使鼠标指向的世界坐标保持不变
	camera.position += mouse_world_before - mouse_world_after

## 生成并显示地图
func generate_and_display_map() -> void:
	# 创建地图生成器
	map_generator = MapGenerator.new()
	add_child(map_generator)
	
	# 如果已有地图种子，使用固定种子生成相同地图
	if RunManager and RunManager.map_seed != -1:
		seed(RunManager.map_seed)
	
	# 获取地图配置
	var config = DataManager.get_map_config()
	if config.is_empty():
		print("使用默认地图配置")
		config = {}
	
	# 生成地图
	current_map = map_generator.generate_map(config)
	
	# 显示地图
	display_map()
	
	# 设置初始相机位置（显示底部起点）
	_setup_camera()

## 设置相机初始位置
func _setup_camera() -> void:
	if camera:
		var viewport_size = get_viewport().get_visible_rect().size
		# 相机初始位置在底部，显示第一层
		camera.position = Vector2(viewport_size.x / 2.0, viewport_size.y - 200)
		# 设置初始缩放
		camera.zoom = Vector2(zoom_level, zoom_level)

## 显示地图
func display_map() -> void:
	if not map_container:
		print("错误：map_container未找到")
		return
	
	# 清空现有节点
	for child in map_container.get_children():
		if child.name != "Background":
			child.queue_free()
	
	node_instances.clear()
	connection_lines.clear()
	reachable_nodes.clear()
	
	var floors = current_map.get("floors", [])
	if floors.is_empty():
		print("警告：没有生成任何楼层")
		return
	
	var viewport_size = get_viewport().get_visible_rect().size
	var center_x = viewport_size.x / 2.0
	
	# 计算地图总高度
	var total_height = floors.size() * node_spacing_y
	
	# 从下往上绘制每一层
	# floor_idx = 0 是第1层（最底层），应该显示在屏幕底部
	for floor_idx in range(floors.size()):
		var floor_nodes_data = floors[floor_idx]
		if floor_nodes_data.is_empty():
			continue
		
		var node_count = floor_nodes_data.size()
		
		# 计算Y坐标：第1层在底部，第16层在顶部
		# 使用viewport高度作为参考，第1层在viewport_height - margin
		var floor_y = viewport_size.y - map_bottom_margin - (floor_idx * node_spacing_y)
		
		# 计算这一层节点的X位置（居中分布）
		var floor_width = (node_count - 1) * node_spacing_x
		var floor_start_x = center_x - floor_width / 2.0
		
		for node_idx in range(node_count):
			var node_data = floor_nodes_data[node_idx]
			if not node_data:
				continue
			
			var node_x = floor_start_x + node_idx * node_spacing_x
			
			# 创建新的节点实例
			var node_instance = MapNode.new()
			node_instance.node_id = node_data.node_id
			node_instance.node_type = node_data.node_type
			node_instance.floor_number = node_data.floor_number
			node_instance.position_in_floor = node_data.position_in_floor
			
			# 复制连接的节点
			if node_data.connected_nodes:
				for conn_id in node_data.connected_nodes:
					if conn_id is String:
						node_instance.connected_nodes.append(conn_id)
			
			node_instance.position = Vector2(node_x, floor_y)
			node_instance.node_selected.connect(_on_node_selected)
			map_container.add_child(node_instance)
			
			# 保存实例引用
			node_instances[node_data.node_id] = node_instance
			
			# 恢复已访问节点的状态
			if RunManager and RunManager.is_node_visited(node_data.node_id):
				node_instance.is_visited = true
				node_instance.update_visual_state(false)  # 已访问节点不可选择
	
	# 绘制所有连接线
	_draw_all_connections(floors)
	
	# 更新可选择的节点状态
	_update_selectable_nodes()
	
	# 如果已经选择了初始节点，计算可达节点并淡化不可达节点
	# 注意：初始时所有节点都应该是可达的，只有选择初始节点后才计算可达性
	var current_node_id = RunManager.current_node_id if RunManager else ""
	var current_floor = RunManager.current_floor if RunManager else 1
	
	# 只有当玩家已经选择了初始节点（第1层）时，才计算可达性
	# 初始状态下，reachable_nodes 为空，所有节点和连接线都正常显示
	if not current_node_id.is_empty() and current_floor >= 1:
		# 玩家已经选择了初始节点，计算从该节点开始的所有可达节点
		_calculate_reachable_nodes(current_node_id)
		# 更新不可达节点和连接线的视觉状态
		_update_unreachable_nodes_visual()
	# 初始状态：reachable_nodes 为空，_update_node_visual_state 会使用默认视觉状态

## 绘制所有连接线
func _draw_all_connections(floors: Array) -> void:
	var connections = current_map.get("connections", [])
	
	for floor_idx in range(connections.size()):
		var floor_conns = connections[floor_idx]
		
		for conn in floor_conns:
			var out_idx = conn[0]
			var in_idx = conn[1]
			
			# 获取连接的节点实例
			var from_node_data = floors[floor_idx][out_idx]
			var to_node_data = floors[floor_idx + 1][in_idx]
			
			if not from_node_data or not to_node_data:
				continue
			
			var from_node_instance = node_instances.get(from_node_data.node_id)
			var to_node_instance = node_instances.get(to_node_data.node_id)
			
			if not from_node_instance or not to_node_instance:
				continue
			
			# 获取按钮的中心位置
			# 按钮大小是 64x64，按钮在 VBoxContainer 顶部，所以中心偏移是 (32, 32)
			var button_size = Vector2(64, 64)
			var button_center_offset = button_size / 2.0
			
			# MapNode 的 position 就是它在 map_container 中的位置
			# 按钮在 VBoxContainer 中，VBoxContainer 在 MapNode 中，默认位置都是 (0, 0)
			# 所以按钮的中心位置 = MapNode.position + button_center_offset
			var from_pos = from_node_instance.position + button_center_offset
			var to_pos = to_node_instance.position + button_center_offset
			
			# 创建连接线
			var line = Line2D.new()
			line.width = 5.0  # 加粗线条（从3.0改为5.0）
			line.default_color = Color(0.4, 0.4, 0.5, 0.6)
			line.add_point(from_pos)
			line.add_point(to_pos)
			line.z_index = -1  # 确保线条在节点下方
			map_container.add_child(line)
			
			# 保存连接线引用，用于后续更新视觉状态
			# 使用特殊分隔符避免node_id中包含下划线时的问题
			var line_key = "%s|%s" % [from_node_data.node_id, to_node_data.node_id]
			connection_lines[line_key] = {
				"line": line,
				"from_node_id": from_node_data.node_id,
				"to_node_id": to_node_data.node_id
			}

## 更新可选择的节点状态
func _update_selectable_nodes() -> void:
	selectable_nodes.clear()
	
	var current_floor = RunManager.current_floor if RunManager else 1
	var current_node_id = RunManager.current_node_id if RunManager else ""
	
	# 如果当前楼层 <= 1 且没有当前节点，所有第一层节点都可选
	if current_floor <= 1 and current_node_id.is_empty():
		for node_id in node_instances:
			var node_instance = node_instances[node_id]
			if node_instance and node_instance.floor_number == 1 and not node_instance.is_visited:
				selectable_nodes.append(node_id)
	else:
		# 找到当前所在节点，只有它连接的节点可选
		if not current_node_id.is_empty():
			var current_node_instance = node_instances.get(current_node_id)
			if current_node_instance:
				for conn_id in current_node_instance.connected_nodes:
					var target_node_instance = node_instances.get(conn_id)
					if target_node_instance and not target_node_instance.is_visited:
						selectable_nodes.append(conn_id)
	
	# 更新节点的可点击状态和视觉状态
	for node_id in node_instances:
		var node_instance = node_instances[node_id]
		if node_instance and node_instance.node_button:
			var is_selectable = false
			if current_floor <= 1 and current_node_id.is_empty() and node_instance.floor_number == 1:
				is_selectable = not node_instance.is_visited
			else:
				is_selectable = node_id in selectable_nodes
			
			# 如果已经计算了可达节点，确保不可达节点不会被标记为可选择
			if not reachable_nodes.is_empty() and not reachable_nodes.has(node_id):
				is_selectable = false
			
			# 更新视觉状态（区分已访问、可选择、不可选择）
			# 初始状态下，所有节点都不淡化
			_update_node_visual_state(node_instance, is_selectable)

## 节点被选中
func _on_node_selected(node: MapNode) -> void:
	# 首先检查节点是否已访问
	if node.is_visited:
		return
	
	# 检查节点是否可选
	var current_floor = RunManager.current_floor if RunManager else 1
	var current_node_id = RunManager.current_node_id if RunManager else ""
	var is_selectable = false
	
	if current_floor <= 1 and current_node_id.is_empty() and node.floor_number == 1:
		is_selectable = not node.is_visited
	elif node.node_id in selectable_nodes:
		is_selectable = true
	
	if not is_selectable:
		return
	
	# 访问节点
	node.visit()
	
	# 更新楼层和当前节点
	if RunManager:
		RunManager.set_floor(node.floor_number)
		RunManager.current_node_id = node.node_id
		if floor_label:
			floor_label.text = "当前楼层: %d / 16" % node.floor_number
	
	# 滚动相机跟随
	_scroll_to_floor(node.floor_number)
	
	# 更新可选择状态
	_update_selectable_nodes()
	
	# 如果这是初始节点选择（第1层），计算所有可达节点并淡化不可达节点
	if node.floor_number == 1 and not node.is_visited:
		# 选择初始节点后，计算从该节点开始的所有可达节点
		_calculate_reachable_nodes(node.node_id)
		# 更新不可达节点和连接线的视觉状态
		_update_unreachable_nodes_visual()
	
	# 根据节点类型执行相应操作
	match node.node_type:
		MapNode.NodeType.ENEMY:
			start_battle(node)
		# TODO: 以下节点类型为占位符，暂时不跳转场景，允许直接选择下一节点
		# 后期需要实现这些场景时，取消注释对应的函数调用即可
		MapNode.NodeType.TREASURE:
			# open_treasure()  # 占位符：宝箱场景，暂不跳转
			pass
		MapNode.NodeType.SHOP:
			# enter_shop()  # 占位符：商店场景，暂不跳转
			pass
		MapNode.NodeType.REST:
			# enter_rest()  # 占位符：休息处场景，暂不跳转
			pass
		MapNode.NodeType.EVENT:
			enter_event()
		MapNode.NodeType.BOSS:
			# start_boss_battle()  # 占位符：BOSS战场景，暂不跳转
			pass

## 滚动到指定楼层
func _scroll_to_floor(floor_num: int) -> void:
	if not camera:
		return
	
	var viewport_size = get_viewport().get_visible_rect().size
	var target_y = viewport_size.y - map_bottom_margin - ((floor_num - 1) * node_spacing_y)
	
	# 创建缓动动画
	var tween = create_tween()
	tween.tween_property(camera, "position:y", target_y, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

## 打开宝箱
func open_treasure() -> void:
	if GameManager:
		GameManager.open_treasure()

## 开始战斗
func start_battle(node: MapNode) -> void:
	if GameManager:
		GameManager.start_battle()
	else:
		var battle_scene = load("res://scenes/battle/battle_scene.tscn") as PackedScene
		if battle_scene:
			get_tree().change_scene_to_packed(battle_scene)

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
	if GameManager:
		GameManager.start_boss_battle()

## 计算从起点开始所有可达的节点（使用BFS）
func _calculate_reachable_nodes(start_node_id: String) -> void:
	reachable_nodes.clear()
	if start_node_id.is_empty() or not node_instances.has(start_node_id):
		return
	
	# 使用BFS遍历所有可达节点
	var queue: Array = [start_node_id]
	var visited: Dictionary = {}
	visited[start_node_id] = true
	reachable_nodes[start_node_id] = true
	
	while not queue.is_empty():
		var current_id = queue.pop_front()
		var current_node = node_instances.get(current_id)
		
		if not current_node:
			continue
		
		# 遍历当前节点的所有连接
		for connected_id in current_node.connected_nodes:
			if not visited.has(connected_id):
				visited[connected_id] = true
				reachable_nodes[connected_id] = true
				queue.append(connected_id)

## 更新不可达节点和连接线的视觉状态（淡化）
func _update_unreachable_nodes_visual() -> void:
	if reachable_nodes.is_empty():
		# 如果没有计算可达节点，所有连接线都正常显示
		for line_key in connection_lines:
			var line_data = connection_lines[line_key]
			if line_data and line_data.has("line"):
				var line = line_data["line"]
				line.default_color = Color(0.4, 0.4, 0.5, 0.6)
		return
	
	# 更新所有节点的视觉状态
	for node_id in node_instances:
		var node_instance = node_instances[node_id]
		if not node_instance:
			continue
		
		var is_selectable = node_id in selectable_nodes
		_update_node_visual_state(node_instance, is_selectable)
	
	# 更新连接线的视觉状态
	for line_key in connection_lines:
		var line_data = connection_lines[line_key]
		if not line_data or not line_data.has("line"):
			continue
		
		var line = line_data["line"]
		var from_node_id = line_data["from_node_id"]
		var to_node_id = line_data["to_node_id"]
		
		# 检查连接线的两个端点是否都可达
		var from_reachable = reachable_nodes.has(from_node_id)
		var to_reachable = reachable_nodes.has(to_node_id)
		
		if from_reachable and to_reachable:
			# 可达的连接线：正常显示
			line.default_color = Color(0.4, 0.4, 0.5, 0.6)
		else:
			# 不可达的连接线：淡化
			line.default_color = Color(0.4, 0.4, 0.5, 0.15)

## 更新节点视觉状态（考虑可达性）
func _update_node_visual_state(node_instance: MapNode, is_selectable: bool) -> void:
	if not node_instance or not node_instance.node_button:
		return
	
	# 如果已经计算了可达节点
	if not reachable_nodes.is_empty():
		var node_id = node_instance.node_id
		var is_reachable = reachable_nodes.has(node_id)
		
		if node_instance.is_visited:
			# 已访问的节点：灰色，禁用
			node_instance.node_button.modulate = Color(0.5, 0.5, 0.5, 1.0)
			node_instance.node_button.disabled = true
		elif not is_reachable:
			# 不可达节点：严重淡化
			var base_color = _get_node_base_color(node_instance)
			node_instance.node_button.modulate = Color(base_color.r * 0.2, base_color.g * 0.2, base_color.b * 0.2, 0.3)
			node_instance.node_button.disabled = true
		elif not is_selectable:
			# 可达但还未到达的节点：轻微淡化，增强可读性
			var base_color = _get_node_base_color(node_instance)
			# 使用更高的亮度和透明度，让节点更清晰可见
			node_instance.node_button.modulate = Color(base_color.r * 0.7, base_color.g * 0.7, base_color.b * 0.7, 0.75)
			node_instance.node_button.disabled = true
		else:
			# 可达且可选择：正常颜色
			node_instance.node_button.modulate = _get_node_base_color(node_instance)
			node_instance.node_button.disabled = false
	else:
		# 初始状态：所有节点都不淡化，正常显示
		node_instance.update_visual_state(is_selectable)

## 获取节点基础颜色（辅助函数）
func _get_node_base_color(node_instance: MapNode) -> Color:
	match node_instance.node_type:
		MapNode.NodeType.ENEMY:
			return Color(1.0, 0.8, 0.8, 1.0)  # 淡红色
		MapNode.NodeType.TREASURE:
			return Color(1.0, 0.9, 0.6, 1.0)  # 金色
		MapNode.NodeType.SHOP:
			return Color(0.8, 0.8, 1.0, 1.0)  # 淡蓝色
		MapNode.NodeType.REST:
			return Color(0.8, 1.0, 0.8, 1.0)  # 淡绿色
		MapNode.NodeType.EVENT:
			return Color(1.0, 1.0, 0.8, 1.0)  # 淡黄色
		MapNode.NodeType.BOSS:
			return Color(1.0, 0.4, 0.4, 1.0)  # 深红色
		_:
			return Color.WHITE
	
	# 更新连接线的视觉状态
	for line_key in connection_lines:
		var line_data = connection_lines[line_key]
		if not line_data or not line_data.has("line"):
			continue
		
		var line = line_data["line"]
		var from_node_id = line_data["from_node_id"]
		var to_node_id = line_data["to_node_id"]
		
		# 检查连接线的两个端点是否都可达
		var from_reachable = reachable_nodes.has(from_node_id)
		var to_reachable = reachable_nodes.has(to_node_id)
		
		if from_reachable and to_reachable:
			# 可达的连接线：正常显示
			line.default_color = Color(0.4, 0.4, 0.5, 0.6)
		else:
			# 不可达的连接线：淡化
			line.default_color = Color(0.4, 0.4, 0.5, 0.15)
