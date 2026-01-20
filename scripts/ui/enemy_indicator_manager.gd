extends Control
class_name EnemyIndicatorManager

## 敌人指示器管理器
## 管理所有敌人方向指示器，为视野外的敌人创建指示器

# 指示器场景（可选，如果为空则使用代码创建）
@export var indicator_scene: PackedScene = null

# 摄像机引用
var camera: Camera2D = null
# 当前活跃的指示器字典：敌人节点 -> 指示器节点
var active_indicators: Dictionary = {}
# 指示器池（用于复用）
var indicator_pool: Array[EnemyIndicator] = []

func _ready() -> void:
	# 等待一帧，确保场景树完全初始化
	await get_tree().process_frame
	_find_camera()
	
	# 如果还没找到，再等待一帧
	if not camera:
		await get_tree().process_frame
		_find_camera()

func _process(_delta: float) -> void:
	if not camera:
		_find_camera()
		return
	
	_update_indicators()

## 查找摄像机
func _find_camera() -> void:
	if camera and is_instance_valid(camera):
		return
	
	# 方法1: 尝试从场景树中查找摄像机组
	var cameras = get_tree().get_nodes_in_group("camera")
	if not cameras.is_empty():
		camera = cameras[0] as Camera2D
		return
	
	# 方法2: 尝试查找名为Camera2D的节点（在战斗场景中）
	var battle_manager = get_tree().get_first_node_in_group("battle_manager")
	if battle_manager:
		# 尝试直接路径查找
		camera = battle_manager.get_node_or_null("Camera2D") as Camera2D
		if camera:
			return
		# 尝试通过相对路径查找（如果管理器在CanvasLayer下）
		var canvas_layer = get_parent()
		if canvas_layer:
			var root = canvas_layer.get_parent()
			if root:
				camera = root.get_node_or_null("Camera2D") as Camera2D
				if camera:
					return
	
	# 方法3: 尝试在整个场景树中查找当前激活的Camera2D
	var root = get_tree().root
	var found_camera = _find_camera_recursive(root)
	if found_camera:
		camera = found_camera
		return
	
	# 方法4: 尝试从父节点向上查找
	if not camera:
		var parent = get_parent()
		while parent:
			if parent is Camera2D:
				camera = parent as Camera2D
				break
			parent = parent.get_parent()

## 递归查找摄像机
func _find_camera_recursive(node: Node) -> Camera2D:
	if node is Camera2D:
		var cam = node as Camera2D
		if cam.is_current() or cam.enabled:
			return cam
	
	for child in node.get_children():
		var result = _find_camera_recursive(child)
		if result:
			return result
	
	return null

## 更新所有指示器
func _update_indicators() -> void:
	# 获取所有敌人
	var enemies: Array = []
	var battle_manager = get_tree().get_first_node_in_group("battle_manager")
	if battle_manager and battle_manager.has_method("get_active_enemies"):
		enemies = battle_manager.get_active_enemies()
	else:
		enemies = get_tree().get_nodes_in_group("enemies")
	var current_enemies: Dictionary = {}
	
	# 收集当前所有有效的敌人
	for enemy in enemies:
		if is_instance_valid(enemy):
			current_enemies[enemy] = true
			
			# 检查敌人是否在视野外
			if _is_enemy_off_screen(enemy):
				# 如果还没有指示器，创建一个
				if not active_indicators.has(enemy):
					_create_indicator_for_enemy(enemy)
			else:
				# 如果敌人在视野内，移除指示器
				if active_indicators.has(enemy):
					_remove_indicator_for_enemy(enemy)
	
	# 清理已死亡敌人的指示器
	var enemies_to_remove = []
	for enemy in active_indicators.keys():
		# 检查敌人是否有效且仍在当前敌人列表中
		if not is_instance_valid(enemy) or not current_enemies.has(enemy):
			enemies_to_remove.append(enemy)
	
	# 移除无效的指示器（直接操作字典，避免传入已释放的对象）
	for enemy in enemies_to_remove:
		if active_indicators.has(enemy):
			var indicator = active_indicators.get(enemy) as EnemyIndicator
			if indicator and is_instance_valid(indicator):
				indicator.visible = false
				indicator.set_target(null)
				# 将指示器放回池中（最多保留10个）
				if indicator_pool.size() < 10:
					indicator_pool.append(indicator)
				else:
					indicator.queue_free()
			active_indicators.erase(enemy)

## 检查敌人是否在屏幕外
func _is_enemy_off_screen(enemy: Node2D) -> bool:
	if not camera or not enemy:
		return false
	
	var viewport = get_viewport()
	if not viewport:
		return false
	
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
	
	# 检查敌人位置是否在视野内
	var enemy_pos = enemy.global_position
	return not view_rect.has_point(enemy_pos)

## 为敌人创建指示器
func _create_indicator_for_enemy(enemy: Node2D) -> void:
	if not enemy or not is_instance_valid(enemy):
		return
	
	# 尝试从池中获取指示器
	var indicator: EnemyIndicator = null
	if not indicator_pool.is_empty():
		indicator = indicator_pool.pop_back()
		indicator.visible = true
	else:
		# 创建新指示器
		if indicator_scene:
			var instance = indicator_scene.instantiate()
			indicator = instance as EnemyIndicator
		else:
			# 使用代码创建
			indicator = EnemyIndicator.new()
		
		if indicator:
			add_child(indicator)
	
	if indicator:
		indicator.set_target(enemy)
		indicator.set_camera(camera)
		active_indicators[enemy] = indicator

## 移除敌人的指示器
func _remove_indicator_for_enemy(enemy: Node2D) -> void:
	# 检查敌人是否有效
	if not enemy:
		return
	
	# 如果敌人已释放，尝试通过引用查找（可能失败，但不报错）
	if not is_instance_valid(enemy):
		# 尝试移除（可能失败，但不影响）
		if active_indicators.has(enemy):
			var indicator = active_indicators.get(enemy) as EnemyIndicator
			if indicator and is_instance_valid(indicator):
				indicator.visible = false
				indicator.set_target(null)
				if indicator_pool.size() < 10:
					indicator_pool.append(indicator)
				else:
					indicator.queue_free()
			active_indicators.erase(enemy)
		return
	
	# 正常情况：敌人有效
	if not active_indicators.has(enemy):
		return
	
	var indicator = active_indicators[enemy] as EnemyIndicator
	if indicator and is_instance_valid(indicator):
		indicator.visible = false
		indicator.set_target(null)
		# 将指示器放回池中（最多保留10个）
		if indicator_pool.size() < 10:
			indicator_pool.append(indicator)
		else:
			indicator.queue_free()
	
	active_indicators.erase(enemy)

## 清理所有指示器
func clear_all_indicators() -> void:
	for enemy in active_indicators.keys().duplicate():
		_remove_indicator_for_enemy(enemy)
