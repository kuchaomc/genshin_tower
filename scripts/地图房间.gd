extends Control
class_name MapRoom

# 地图房间UI组件 - 用于在地图界面中显示单个房间

# 节点引用
@onready var room_button: Button = $RoomButton
@onready var room_icon: TextureRect = $RoomButton/RoomContainer/RoomIcon
@onready var room_label: Label = $RoomButton/RoomContainer/RoomLabel

# 房间数据
var room_data: RoomTypes.RoomData = null
var room_position: Vector2i = Vector2i.ZERO

# 状态颜色定义
const COLOR_AVAILABLE: Color = Color.WHITE
const COLOR_CURRENT: Color = Color.CYAN
const COLOR_COMPLETED: Color = Color.GRAY
const COLOR_LOCKED: Color = Color(0.3, 0.3, 0.3, 0.5)
const COLOR_HOVER: Color = Color.YELLOW

# 初始化
func _ready() -> void:
	# 连接按钮信号
	if room_button:
		room_button.pressed.connect(_on_room_button_pressed)
		room_button.mouse_entered.connect(_on_room_button_mouse_entered)
		room_button.mouse_exited.connect(_on_room_button_mouse_exited)
	
	# 初始状态
	update_appearance()

# 设置房间数据
func setup(room: RoomTypes.RoomData, pos: Vector2i) -> void:
	room_data = room
	room_position = pos
	
	# 更新UI
	update_ui()

# 更新UI显示
func update_ui() -> void:
	if not room_data:
		return
	
	# 设置图标
	var icon_path = room_data.icon_path
	if ResourceLoader.exists(icon_path):
		var icon_texture = load(icon_path)
		if icon_texture:
			room_icon.texture = icon_texture
	else:
		# 使用占位符图标
		var placeholder = load("res://textures/暂不使用.png")
		if placeholder:
			room_icon.texture = placeholder
	
	# 设置标签文本
	room_label.text = room_data.name
	
	# 设置房间颜色
	var room_color = RoomTypes.get_room_color(room_data.type)
	room_label.add_theme_color_override("font_color", room_color)
	
	# 更新外观（状态相关）
	update_appearance()

# 更新外观（根据状态）
func update_appearance() -> void:
	if not room_data:
		return
	
	# 根据房间状态设置不同的外观
	match room_data.state:
		RoomTypes.RoomState.LOCKED:
			set_locked_appearance()
		RoomTypes.RoomState.AVAILABLE:
			set_available_appearance()
		RoomTypes.RoomState.COMPLETED:
			set_completed_appearance()
	
	# 检查是否为当前房间
	var map_manager = get_map_manager()
	if map_manager and map_manager.current_position == room_position:
		set_current_appearance()

# 设置锁定状态外观
func set_locked_appearance() -> void:
	modulate = COLOR_LOCKED
	room_button.disabled = true
	room_button.tooltip_text = "锁定"

# 设置可访问状态外观
func set_available_appearance() -> void:
	modulate = COLOR_AVAILABLE
	room_button.disabled = false
	room_button.tooltip_text = "点击进入"
	
	# 添加轻微发光效果
	var shader_material = ShaderMaterial.new()
	# 这里可以添加简单的着色器效果，暂时省略

# 设置已完成状态外观
func set_completed_appearance() -> void:
	modulate = COLOR_COMPLETED
	room_button.disabled = true
	room_button.tooltip_text = "已完成"
	
	# 可以在图标上添加完成标记
	room_label.add_theme_color_override("font_color", COLOR_COMPLETED)

# 设置当前房间外观
func set_current_appearance() -> void:
	modulate = COLOR_CURRENT
	room_button.tooltip_text = "当前位置"

# 按钮事件处理
func _on_room_button_pressed() -> void:
	if not room_data or room_data.state != RoomTypes.RoomState.AVAILABLE:
		return
	
	print("地图房间被点击: ", room_position, " 类型: ", room_data.name)
	
	# 触发房间选择事件
	GameEventBus.room_selected.emit(room_position)

func _on_room_button_mouse_entered() -> void:
	if room_data and room_data.state == RoomTypes.RoomState.AVAILABLE:
		modulate = COLOR_HOVER

func _on_room_button_mouse_exited() -> void:
	update_appearance()

# 获取地图管理器（通过场景树查找）
func get_map_manager() -> MapManager:
	# 向上查找场景树中的地图管理器
	var parent_node = get_parent()
	while parent_node:
		if parent_node is MapManager:
			return parent_node as MapManager
		parent_node = parent_node.get_parent()
	
	# 如果没找到，尝试通过自动加载获取
	if has_node("/root/MapManager"):
		return get_node("/root/MapManager") as MapManager
	
	return null

# 设置房间状态
func set_room_state(state: RoomTypes.RoomState) -> void:
	if room_data:
		room_data.state = state
		update_appearance()

# 检查是否可访问
func is_available() -> bool:
	return room_data and room_data.state == RoomTypes.RoomState.AVAILABLE

# 检查是否已完成
func is_completed() -> bool:
	return room_data and room_data.state == RoomTypes.RoomState.COMPLETED

# 获取房间位置
func get_room_position() -> Vector2i:
	return room_position

# 获取房间类型
func get_room_type() -> RoomTypes.RoomType:
	if room_data:
		return room_data.type
	return RoomTypes.RoomType.BATTLE_NORMAL

# 刷新显示
func refresh() -> void:
	update_ui()