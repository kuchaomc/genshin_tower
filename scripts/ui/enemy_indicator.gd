extends Control
class_name EnemyIndicator

## 敌人方向指示器
## 显示在屏幕边缘，指向摄像机外的敌人

var arrow: Sprite2D = null

# 目标敌人引用
var target_enemy: Node2D = null
# 摄像机引用
var camera: Camera2D = null
# 屏幕边距（指示器距离屏幕边缘的距离）
# 需要足够大以容纳箭头（箭头大小48x48，长度36，所以至少需要18像素边距）
var screen_margin: float = 35.0

func _ready() -> void:
	# 如果没有箭头节点，创建一个
	if not arrow:
		arrow = get_node_or_null("Arrow") as Sprite2D
		if not arrow:
			arrow = Sprite2D.new()
			arrow.name = "Arrow"
			add_child(arrow)
	
	# 创建箭头纹理（如果还没有）
	if arrow and not arrow.texture:
		_create_arrow_texture()

func _process(_delta: float) -> void:
	if not target_enemy or not is_instance_valid(target_enemy):
		visible = false
		return
	
	if not camera:
		visible = false
		return
	
	_update_indicator_position()

## 设置目标敌人
func set_target(enemy: Node2D) -> void:
	target_enemy = enemy
	visible = true

## 设置摄像机引用
func set_camera(cam: Camera2D) -> void:
	camera = cam

## 更新指示器位置
func _update_indicator_position() -> void:
	if not target_enemy or not camera:
		return
	
	# 获取摄像机视野范围
	var viewport = get_viewport()
	if not viewport:
		return
	
	var viewport_size = viewport.get_visible_rect().size
	var camera_pos = camera.global_position
	var camera_zoom = camera.zoom
	
	# 计算摄像机视野的边界（世界坐标）
	var view_half_size = viewport_size / (2.0 * camera_zoom)
	var view_rect = Rect2(
		camera_pos.x - view_half_size.x,
		camera_pos.y - view_half_size.y,
		view_half_size.x * 2.0,
		view_half_size.y * 2.0
	)
	
	# 获取敌人位置
	var enemy_pos = target_enemy.global_position
	
	# 检查敌人是否在视野内
	if view_rect.has_point(enemy_pos):
		visible = false
		return
	
	visible = true
	
	# 将世界坐标转换为屏幕坐标
	# CanvasLayer使用屏幕坐标系统，左上角为(0,0)
	var screen_center = viewport_size / 2.0
	# 将敌人世界坐标转换为屏幕坐标
	# 公式：屏幕坐标 = (世界坐标 - 摄像机世界坐标) * 缩放 + 屏幕中心
	var screen_enemy_pos = (enemy_pos - camera_pos) * camera_zoom + screen_center
	
	# 计算屏幕边缘的交点（使用CanvasLayer的屏幕坐标系统）
	var edge_pos = _get_screen_edge_position(screen_enemy_pos, screen_center, viewport_size)
	
	# 设置指示器位置（CanvasLayer使用屏幕坐标，左上角为原点）
	position = edge_pos
	
	# 计算箭头旋转角度（指向敌人方向）
	# 箭头在边缘位置，应该指向从边缘到屏幕中心的方向（即指向敌人）
	var direction_to_center = (screen_center - edge_pos).normalized()
	if direction_to_center.length_squared() > 0.0001:
		# 计算从边缘指向中心的角度
		# 在Godot中，Sprite2D的rotation=0时，纹理默认向上（负Y方向，即(0,-1)）
		# angle()返回的是从x轴正方向（向右）的角度，范围是-PI到PI
		# 如果箭头默认向上（rotation=0对应方向(0,-1)），那么：
		# - 要指向右(1,0): angle=0, 需要旋转 -PI/2
		# - 要指向下(0,1): angle=PI/2, 需要旋转 0
		# - 要指向左(-1,0): angle=PI, 需要旋转 PI/2
		# - 要指向上(0,-1): angle=-PI/2, 需要旋转 PI
		# 所以公式是：rotation = angle - PI/2
		var angle = direction_to_center.angle() - PI / 2.0
		arrow.rotation = angle
	else:
		arrow.rotation = 0.0

## 获取屏幕边缘位置
## 在CanvasLayer坐标系统中，左上角为(0,0)，右下角为(screen_size.x, screen_size.y)
func _get_screen_edge_position(screen_pos: Vector2, screen_center: Vector2, screen_size: Vector2) -> Vector2:
	# 计算从屏幕中心到目标点的方向
	var dir = (screen_pos - screen_center).normalized()
	
	# 如果方向为零向量，返回屏幕中心
	if dir.length_squared() < 0.0001:
		return screen_center
	
	# 获取箭头大小，确保箭头完全在屏幕内
	# 箭头纹理大小是48x48，箭头长度是36像素
	# 箭头中心到尖端的距离大约是18像素，所以需要至少18像素的边距
	# 为了安全，使用更大的边距（箭头对角线的一半约为34像素）
	var arrow_size = 48.0  # 箭头纹理大小
	var arrow_half_diagonal = arrow_size * 0.707  # 对角线的一半（sqrt(2)/2）
	# 边距需要至少是箭头对角线的一半，确保箭头旋转后也不会超出屏幕
	var effective_margin = max(screen_margin, arrow_half_diagonal + 5.0)
	
	# 定义屏幕边缘（考虑边距和箭头大小）
	# CanvasLayer坐标：左上角(0,0)，右下角(screen_size.x, screen_size.y)
	var left_edge = effective_margin
	var right_edge = screen_size.x - effective_margin
	var top_edge = effective_margin
	var bottom_edge = screen_size.y - effective_margin
	
	# 计算与各边缘的交点参数t
	var t_left: float = INF
	var t_right: float = INF
	var t_top: float = INF
	var t_bottom: float = INF
	
	# 计算与左右边缘的交点
	if dir.x != 0:
		if dir.x > 0:
			# 向右，与右边缘相交
			t_right = (right_edge - screen_center.x) / dir.x
		else:
			# 向左，与左边缘相交
			t_left = (left_edge - screen_center.x) / dir.x
	
	# 计算与上下边缘的交点
	if dir.y != 0:
		if dir.y > 0:
			# 向下，与下边缘相交
			t_bottom = (bottom_edge - screen_center.y) / dir.y
		else:
			# 向上，与上边缘相交
			t_top = (top_edge - screen_center.y) / dir.y
	
	# 选择最小的正t值（先到达的边缘）
	var t = INF
	if t_left > 0 and t_left < t:
		t = t_left
	if t_right > 0 and t_right < t:
		t = t_right
	if t_top > 0 and t_top < t:
		t = t_top
	if t_bottom > 0 and t_bottom < t:
		t = t_bottom
	
	# 如果所有t都是无效的，使用屏幕中心
	if t == INF or t <= 0:
		return screen_center
	
	# 计算交点位置（CanvasLayer坐标系统）
	var edge_point = screen_center + dir * t
	
	# 确保点在屏幕范围内（使用effective_margin确保箭头完全在屏幕内）
	edge_point.x = clamp(edge_point.x, left_edge, right_edge)
	edge_point.y = clamp(edge_point.y, top_edge, bottom_edge)
	
	# 额外检查：确保箭头中心不会太靠近边缘
	# 箭头大小是48x48，所以中心距离边缘至少需要24像素
	var min_distance_from_edge = 24.0
	edge_point.x = clamp(edge_point.x, min_distance_from_edge, screen_size.x - min_distance_from_edge)
	edge_point.y = clamp(edge_point.y, min_distance_from_edge, screen_size.y - min_distance_from_edge)
	
	return edge_point

## 创建箭头纹理
func _create_arrow_texture() -> void:
	# 创建一个更大的箭头图像，使其更明显
	var size = 48
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var center_x = size / 2.0
	
	# 箭头颜色：亮红色，带黑色边框
	var arrow_color = Color(1.0, 0.25, 0.25, 1.0)  # 主色（红色）
	var border_color = Color(0.0, 0.0, 0.0, 1.0)  # 黑色边框
	
	# 箭头参数
	var arrow_length = 36.0  # 箭头总长度
	var arrow_head_height = 14.0  # 箭头头部高度
	var arrow_head_width = 18.0  # 箭头头部最大宽度
	var arrow_body_width = 7.0  # 箭头身体宽度
	var border_thickness = 2.0  # 边框厚度
	
	# 箭头方向：向上（0度），旋转由rotation属性控制
	var tip_y = 2.0  # 箭头尖端Y位置
	var head_bottom_y = tip_y + arrow_head_height
	var body_end_y = tip_y + arrow_length
	
	# 绘制箭头（从尖端到尾部）
	for y in range(size):
		for x in range(size):
			var px = float(x)
			var py = float(y)
			var color_to_use: Color = Color.TRANSPARENT
			
			# 计算到中心X的距离
			var dist_to_center_x = abs(px - center_x)
			
			# 箭头头部（三角形部分）
			if py >= tip_y and py < head_bottom_y:
				# 计算当前Y位置的头部宽度（从尖端到头部底部逐渐变宽）
				var head_progress = (py - tip_y) / arrow_head_height
				var current_head_width = arrow_head_width * head_progress
				var half_width = current_head_width / 2.0
				
				if dist_to_center_x <= half_width:
					# 检查是否在边框区域
					var dist_to_edge = half_width - dist_to_center_x
					if dist_to_edge < border_thickness:
						color_to_use = border_color
					else:
						color_to_use = arrow_color
			
			# 箭头身体（矩形部分）
			elif py >= head_bottom_y and py <= body_end_y:
				var half_body_width = arrow_body_width / 2.0
				
				if dist_to_center_x <= half_body_width:
					# 检查是否在边框区域
					var dist_to_edge = half_body_width - dist_to_center_x
					if dist_to_edge < border_thickness:
						color_to_use = border_color
					else:
						color_to_use = arrow_color
			
			# 绘制像素
			if color_to_use != Color.TRANSPARENT:
				image.set_pixel(x, y, color_to_use)
	
	# 创建纹理
	var texture = ImageTexture.create_from_image(image)
	arrow.texture = texture
	arrow.offset = Vector2(-size / 2.0, -size / 2.0)  # 居中
	arrow.scale = Vector2(1.0, 1.0)
