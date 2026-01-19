extends Node2D
class_name EllipseBoundary

## 椭圆边界碰撞体
## 使用多个小碰撞体围绕椭圆外部形成边界墙，阻止玩家离开地图

# 椭圆参数（可在Inspector中调整）
@export var ellipse_center: Vector2 = Vector2.ZERO
@export var ellipse_radius_x: float = 400.0
@export var ellipse_radius_y: float = 300.0
@export var boundary_thickness: float = 20.0  # 边界墙的厚度
@export var boundary_segments: int = 32  # 边界分段数，越多越平滑

# 存储所有边界碰撞体的数组
var boundary_walls: Array[StaticBody2D] = []

func _ready() -> void:
	# 如果未设置中心点，使用节点位置
	if ellipse_center == Vector2.ZERO:
		ellipse_center = global_position
	
	# 生成椭圆边界
	_update_ellipse_boundary()

func _update_ellipse_boundary() -> void:
	# 清除旧的边界
	for wall in boundary_walls:
		if is_instance_valid(wall):
			wall.queue_free()
	boundary_walls.clear()
	
	if ellipse_radius_x <= 0.0 or ellipse_radius_y <= 0.0:
		print("警告：椭圆半径必须大于0")
		return
	
	# 生成椭圆边界片段
	for i in range(boundary_segments):
		var angle: float = (float(i) / float(boundary_segments)) * PI * 2.0
		var next_angle: float = (float(i + 1) / float(boundary_segments)) * PI * 2.0
		
		# 计算椭圆上的点
		var point: Vector2 = Vector2(cos(angle) * ellipse_radius_x, sin(angle) * ellipse_radius_y)
		var next_point: Vector2 = Vector2(cos(next_angle) * ellipse_radius_x, sin(next_angle) * ellipse_radius_y)
		
		# 计算椭圆在该点的切线方向（用于确定边界墙的方向）
		# 椭圆参数方程: x = a*cos(t), y = b*sin(t)
		# 导数: dx/dt = -a*sin(t), dy/dt = b*cos(t)
		# 切线方向向量: (-a*sin(t), b*cos(t))
		var tangent_dir: Vector2 = Vector2(-ellipse_radius_x * sin(angle), ellipse_radius_y * cos(angle)).normalized()
		
		# 法向量（指向椭圆外部）
		var normal: Vector2 = Vector2(-tangent_dir.y, tangent_dir.x)
		
		# 计算两个点之间的距离
		var segment_length: float = (next_point - point).length()
		
		# 边界墙的位置（在椭圆外部）
		var wall_center: Vector2 = (point + next_point) / 2.0 + normal * (boundary_thickness / 2.0)
		
		# 创建边界墙片段
		var wall: StaticBody2D = StaticBody2D.new()
		wall.name = "BoundaryWall_" + str(i)
		wall.position = wall_center
		
		# 创建碰撞形状（矩形）
		var collision_shape: CollisionShape2D = CollisionShape2D.new()
		var rectangle_shape: RectangleShape2D = RectangleShape2D.new()
		rectangle_shape.size = Vector2(segment_length + 5.0, boundary_thickness)  # 稍微重叠以确保连续性
		collision_shape.shape = rectangle_shape
		
		# 旋转矩形使其垂直于椭圆表面
		collision_shape.rotation = normal.angle() + PI / 2.0
		
		wall.add_child(collision_shape)
		add_child(wall)
		boundary_walls.append(wall)
		
		# 设置碰撞层，确保玩家可以碰撞
		wall.collision_layer = 1  # 默认碰撞层
		wall.collision_mask = 0   # 不检测碰撞

# 当参数在编辑器中改变时更新形状
func _set(property: StringName, value: Variant) -> bool:
	if property == "ellipse_radius_x" or property == "ellipse_radius_y" or property == "boundary_thickness" or property == "boundary_segments":
		_update_ellipse_boundary()
		return true
	return false
