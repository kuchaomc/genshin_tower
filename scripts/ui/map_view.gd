extends Node2D

## 地图界面脚本
## 地图从下往上显示，玩家从底部开始向上攀升

@onready var map_container: Node2D = $MapContainer
@onready var floor_label: Label = $CanvasLayer/VBoxContainer/FloorLabel
@onready var camera: Camera2D = $Camera2D

var map_generator: MapGenerator
var current_map: Dictionary = {}
var map_seed: int = -1  # 地图随机种子，用于保持地图一致性

# 布局参数
var node_spacing_x: float = 180.0  # 节点水平间距
var node_spacing_y: float = 150.0  # 节点垂直间距
var map_bottom_margin: float = 100.0  # 地图底部边距
var map_width: float = 1000.0  # 地图宽度

# 节点实例字典，用于绘制连接线
var node_instances: Dictionary = {}  # node_id -> MapNode instance

# 当前可选择的节点（从起点出发或从已访问节点出发可达的节点）
var selectable_nodes: Array = []

# 滚动和拖拽
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var camera_start_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	# 检查必要的单例是否存在
	if not DataManager:
		print("错误：DataManager未找到")
		return
	
	if not RunManager:
		print("错误：RunManager未找到")
		return
	
	# 如果是新游戏（current_node_id为空），生成新地图
	# 否则重用现有地图（通过固定种子）
	if RunManager.current_node_id.is_empty() and map_seed == -1:
		map_seed = randi()
	
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
			_scroll_map(-100)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_map(100)
	
	elif event is InputEventMouseMotion and is_dragging:
		var delta = event.position - drag_start_pos
		camera.position = camera_start_pos - delta

## 滚动地图
func _scroll_map(amount: float) -> void:
	camera.position.y += amount
	# 限制相机位置
	var min_y = 200.0
	var max_y = 16 * node_spacing_y + map_bottom_margin
	camera.position.y = clampf(camera.position.y, min_y, max_y)

## 生成并显示地图
func generate_and_display_map() -> void:
	# 创建地图生成器
	map_generator = MapGenerator.new()
	add_child(map_generator)
	
	# 如果已有地图种子，使用固定种子生成相同地图
	if map_seed != -1:
		seed(map_seed)
	
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

## 绘制所有连接线
func _draw_all_connections(floors: Array) -> void:
	var connections = current_map.get("connections", [])
	var viewport_size = get_viewport().get_visible_rect().size
	var center_x = viewport_size.x / 2.0
	
	for floor_idx in range(connections.size()):
		var floor_conns = connections[floor_idx]
		var current_floor_data = floors[floor_idx]
		var next_floor_data = floors[floor_idx + 1]
		
		var current_count = current_floor_data.size()
		var next_count = next_floor_data.size()
		
		# 计算当前层和下一层的Y坐标
		var current_y = viewport_size.y - map_bottom_margin - (floor_idx * node_spacing_y)
		var next_y = viewport_size.y - map_bottom_margin - ((floor_idx + 1) * node_spacing_y)
		
		# 计算当前层节点的X起始位置
		var current_floor_width = (current_count - 1) * node_spacing_x
		var current_start_x = center_x - current_floor_width / 2.0
		
		# 计算下一层节点的X起始位置
		var next_floor_width = (next_count - 1) * node_spacing_x
		var next_start_x = center_x - next_floor_width / 2.0
		
		for conn in floor_conns:
			var out_idx = conn[0]
			var in_idx = conn[1]
			
			var from_x = current_start_x + out_idx * node_spacing_x
			var to_x = next_start_x + in_idx * node_spacing_x
			
			var from_pos = Vector2(from_x, current_y)
			var to_pos = Vector2(to_x, next_y)
			
			# 创建连接线
			var line = Line2D.new()
			line.width = 3.0
			line.default_color = Color(0.4, 0.4, 0.5, 0.6)
			line.add_point(from_pos)
			line.add_point(to_pos)
			line.z_index = -1  # 确保线条在节点下方
			map_container.add_child(line)

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
			
			# 更新视觉状态（区分已访问、可选择、不可选择）
			node_instance.update_visual_state(is_selectable)

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
	
	# 根据节点类型执行相应操作
	match node.node_type:
		MapNode.NodeType.ENEMY:
			start_battle(node)
		MapNode.NodeType.TREASURE:
			open_treasure()
		MapNode.NodeType.SHOP:
			enter_shop()
		MapNode.NodeType.REST:
			enter_rest()
		MapNode.NodeType.EVENT:
			enter_event()
		MapNode.NodeType.BOSS:
			start_boss_battle()

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
