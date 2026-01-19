extends Node2D
class_name MapNode

## 地图节点
## 代表地图上的一个节点（战斗、商店、休息处等）

enum NodeType {
	ENEMY,      # 普通战斗
	TREASURE,   # 宝箱
	REST,       # 休息处
	SHOP,       # 商店
	EVENT,      # 奇遇事件
	BOSS        # BOSS战
}

@export var node_id: String = ""
@export var node_type: NodeType = NodeType.ENEMY
@export var floor_number: int = 0
@export var position_in_floor: int = 0  # 在当前楼层的位置索引

# 连接的节点ID（可到达的节点）
var connected_nodes: Array = []

# 是否已访问
var is_visited: bool = false

# 节点UI引用
var node_button: Button = null
var node_icon: TextureRect = null

signal node_selected(node: MapNode)

func _ready() -> void:
	# 创建节点UI
	if is_inside_tree():
		create_node_ui()
	else:
		# 如果不在场景树中，延迟创建
		call_deferred("create_node_ui")

## 创建节点UI
func create_node_ui() -> void:
	# 如果UI已经创建，跳过
	if node_button:
		return
		
	# 创建按钮容器
	var container = VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(container)
	
	# 创建按钮
	node_button = Button.new()
	node_button.custom_minimum_size = Vector2(100, 100)
	node_button.pressed.connect(_on_node_pressed)
	container.add_child(node_button)
	
	# 创建图标
	node_icon = TextureRect.new()
	node_icon.custom_minimum_size = Vector2(80, 80)
	node_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	node_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node_button.add_child(node_icon)
	
	# 创建标签显示节点类型
	var label = Label.new()
	label.text = get_type_name()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(label)
	
	# 设置图标
	update_node_icon()
	
	# 更新状态显示
	update_visual_state()

## 更新节点图标
func update_node_icon() -> void:
	if not node_icon:
		return
	
	var icon_path = ""
	match node_type:
		NodeType.ENEMY:
			icon_path = "res://textures/icons/普通战斗房间图标.png"
		NodeType.TREASURE:
			icon_path = "res://textures/icons/商店图标.png"  # 宝箱暂用商店图标
		NodeType.SHOP:
			icon_path = "res://textures/icons/商店图标.png"
		NodeType.REST:
			icon_path = "res://textures/icons/普通战斗房间图标.png"  # 暂时使用相同图标
		NodeType.EVENT:
			icon_path = "res://textures/icons/奇遇图标.png"
		NodeType.BOSS:
			icon_path = "res://textures/icons/普通战斗房间图标.png"  # 暂时使用相同图标
	
	var texture = load(icon_path)
	if texture:
		node_icon.texture = texture
	else:
		print("警告：无法加载节点图标 ", icon_path, " (节点类型: ", node_type, ")")

## 更新视觉状态
func update_visual_state() -> void:
	if not node_button:
		return
	
	if is_visited:
		node_button.modulate = Color(0.5, 0.5, 0.5, 1.0)  # 灰色表示已访问
		node_button.disabled = true
	else:
		# 根据节点类型设置不同颜色
		match node_type:
			NodeType.ENEMY:
				node_button.modulate = Color(1.0, 0.8, 0.8, 1.0)  # 淡红色
			NodeType.TREASURE:
				node_button.modulate = Color(1.0, 0.9, 0.6, 1.0)  # 金色
			NodeType.SHOP:
				node_button.modulate = Color(0.8, 0.8, 1.0, 1.0)  # 淡蓝色
			NodeType.REST:
				node_button.modulate = Color(0.8, 1.0, 0.8, 1.0)  # 淡绿色
			NodeType.EVENT:
				node_button.modulate = Color(1.0, 1.0, 0.8, 1.0)  # 淡黄色
			NodeType.BOSS:
				node_button.modulate = Color(1.0, 0.4, 0.4, 1.0)  # 深红色
			_:
				node_button.modulate = Color.WHITE
		node_button.disabled = false

## 节点被点击
func _on_node_pressed() -> void:
	if not is_visited:
		emit_signal("node_selected", self)

## 访问节点
func visit() -> void:
	is_visited = true
	update_visual_state()
	
	if RunManager:
		RunManager.visit_node(node_id)

## 添加连接的节点
func add_connection(connected_node_id: String) -> void:
	if connected_node_id not in connected_nodes:
		connected_nodes.append(connected_node_id)

## 获取节点类型名称
func get_type_name() -> String:
	match node_type:
		NodeType.ENEMY:
			return "普通战斗"
		NodeType.TREASURE:
			return "宝箱"
		NodeType.SHOP:
			return "商店"
		NodeType.REST:
			return "休息处"
		NodeType.EVENT:
			return "奇遇事件"
		NodeType.BOSS:
			return "BOSS战"
		_:
			return "未知"
