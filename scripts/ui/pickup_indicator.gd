extends Control
class_name PickupIndicator

## 掉落物方向指示器
## 显示在屏幕边缘，指向摄像机外的掉落物（原石）

var arrow: Sprite2D = null

# 目标掉落物引用
var target: Node2D = null
# 摄像机引用
var camera: Camera2D = null
# 屏幕边距（指示器距离屏幕边缘的距离）
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
	if not target or not is_instance_valid(target):
		visible = false
		return

	if not camera:
		visible = false
		return

	_update_indicator_position()

## 设置目标
func set_target(node: Node2D) -> void:
	target = node
	visible = true

## 设置摄像机引用
func set_camera(cam: Camera2D) -> void:
	camera = cam

## 更新指示器位置
func _update_indicator_position() -> void:
	if not target or not camera:
		return

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

	var target_pos = target.global_position
	if view_rect.has_point(target_pos):
		visible = false
		return

	visible = true

	# 将世界坐标转换为屏幕坐标
	var screen_center = viewport_size / 2.0
	var screen_target_pos = (target_pos - camera_pos) * camera_zoom + screen_center

	var edge_pos = _get_screen_edge_position(screen_target_pos, screen_center, viewport_size)
	position = edge_pos

	var direction_to_center = (screen_center - edge_pos).normalized()
	if direction_to_center.length_squared() > 0.0001:
		var angle = direction_to_center.angle() - PI / 2.0
		arrow.rotation = angle
	else:
		arrow.rotation = 0.0

## 获取屏幕边缘位置
func _get_screen_edge_position(screen_pos: Vector2, screen_center: Vector2, screen_size: Vector2) -> Vector2:
	var dir = (screen_pos - screen_center).normalized()
	if dir.length_squared() < 0.0001:
		return screen_center

	var arrow_size = 48.0
	var arrow_half_diagonal = arrow_size * 0.707
	var effective_margin = maxf(screen_margin, arrow_half_diagonal + 5.0)

	var left_edge = effective_margin
	var right_edge = screen_size.x - effective_margin
	var top_edge = effective_margin
	var bottom_edge = screen_size.y - effective_margin

	var t_left: float = INF
	var t_right: float = INF
	var t_top: float = INF
	var t_bottom: float = INF

	if dir.x != 0.0:
		if dir.x > 0.0:
			t_right = (right_edge - screen_center.x) / dir.x
		else:
			t_left = (left_edge - screen_center.x) / dir.x

	if dir.y != 0.0:
		if dir.y > 0.0:
			t_bottom = (bottom_edge - screen_center.y) / dir.y
		else:
			t_top = (top_edge - screen_center.y) / dir.y

	var t = INF
	if t_left > 0.0 and t_left < t:
		t = t_left
	if t_right > 0.0 and t_right < t:
		t = t_right
	if t_top > 0.0 and t_top < t:
		t = t_top
	if t_bottom > 0.0 and t_bottom < t:
		t = t_bottom

	if t == INF or t <= 0.0:
		return screen_center

	var edge_point = screen_center + dir * t
	edge_point.x = clampf(edge_point.x, left_edge, right_edge)
	edge_point.y = clampf(edge_point.y, top_edge, bottom_edge)

	var min_distance_from_edge = 24.0
	edge_point.x = clampf(edge_point.x, min_distance_from_edge, screen_size.x - min_distance_from_edge)
	edge_point.y = clampf(edge_point.y, min_distance_from_edge, screen_size.y - min_distance_from_edge)

	return edge_point

## 创建箭头纹理（淡蓝色）
func _create_arrow_texture() -> void:
	var size = 48
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)

	var center_x = size / 2.0

	# 箭头颜色：淡蓝色，带黑色边框
	var arrow_color = Color(0.55, 0.85, 1.0, 1.0)
	var border_color = Color(0.0, 0.0, 0.0, 1.0)

	var arrow_length = 36.0
	var arrow_head_height = 14.0
	var arrow_head_width = 18.0
	var arrow_body_width = 7.0
	var border_thickness = 2.0

	var tip_y = 2.0
	var head_bottom_y = tip_y + arrow_head_height
	var body_end_y = tip_y + arrow_length

	for y in range(size):
		for x in range(size):
			var px = float(x)
			var py = float(y)
			var color_to_use: Color = Color.TRANSPARENT

			var dist_to_center_x = abs(px - center_x)

			if py >= tip_y and py < head_bottom_y:
				var head_progress = (py - tip_y) / arrow_head_height
				var current_head_width = arrow_head_width * head_progress
				var half_width = current_head_width / 2.0

				if dist_to_center_x <= half_width:
					var dist_to_edge = half_width - dist_to_center_x
					if dist_to_edge < border_thickness:
						color_to_use = border_color
					else:
						color_to_use = arrow_color

			elif py >= head_bottom_y and py <= body_end_y:
				var half_body_width = arrow_body_width / 2.0
				if dist_to_center_x <= half_body_width:
					var dist_to_edge = half_body_width - dist_to_center_x
					if dist_to_edge < border_thickness:
						color_to_use = border_color
					else:
						color_to_use = arrow_color

			if color_to_use != Color.TRANSPARENT:
				image.set_pixel(x, y, color_to_use)

	var texture = ImageTexture.create_from_image(image)
	arrow.texture = texture
	arrow.offset = Vector2(-size / 2.0, -size / 2.0)
	arrow.scale = Vector2(1.0, 1.0)
