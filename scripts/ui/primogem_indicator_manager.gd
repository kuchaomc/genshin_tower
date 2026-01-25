extends Control
class_name PrimogemIndicatorManager

## 原石掉落物指示器管理器
## 管理所有原石方向指示器，为视野外的原石掉落物创建指示器

@export var indicator_scene: PackedScene = null

var camera: Camera2D = null
var active_indicators: Dictionary = {}
var indicator_pool: Array[PickupIndicator] = []

func _ready() -> void:
	await get_tree().process_frame
	_find_camera()

	if not camera:
		await get_tree().process_frame
		_find_camera()

func _process(_delta: float) -> void:
	if not camera:
		_find_camera()
		return

	_update_indicators()

func _find_camera() -> void:
	if camera and is_instance_valid(camera):
		return

	var cameras = get_tree().get_nodes_in_group("camera")
	if not cameras.is_empty():
		camera = cameras[0] as Camera2D
		return

	var battle_manager = get_tree().get_first_node_in_group("battle_manager")
	if battle_manager:
		camera = battle_manager.get_node_or_null("Camera2D") as Camera2D
		if camera:
			return
		var canvas_layer = get_parent()
		if canvas_layer:
			var root = canvas_layer.get_parent()
			if root:
				camera = root.get_node_or_null("Camera2D") as Camera2D
				if camera:
					return

	var root = get_tree().root
	var found_camera = _find_camera_recursive(root)
	if found_camera:
		camera = found_camera
		return

	if not camera:
		var parent = get_parent()
		while parent:
			if parent is Camera2D:
				camera = parent as Camera2D
				break
			parent = parent.get_parent()

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

func _update_indicators() -> void:
	var pickups = get_tree().get_nodes_in_group("primogem_pickups")
	var current_targets: Dictionary = {}

	for p in pickups:
		if is_instance_valid(p) and p is Node2D:
			var pickup := p as Node2D
			current_targets[pickup] = true

			if _is_target_off_screen(pickup):
				if not active_indicators.has(pickup):
					_create_indicator_for_target(pickup)
			else:
				if active_indicators.has(pickup):
					_remove_indicator_for_target(pickup)

	var targets_to_remove = []
	for t in active_indicators.keys():
		if not is_instance_valid(t) or not current_targets.has(t):
			targets_to_remove.append(t)

	for t in targets_to_remove:
		if active_indicators.has(t):
			var indicator = active_indicators.get(t) as PickupIndicator
			if indicator and is_instance_valid(indicator):
				indicator.visible = false
				indicator.set_target(null)
				if indicator_pool.size() < 10:
					indicator_pool.append(indicator)
				else:
					indicator.queue_free()
			active_indicators.erase(t)

func _is_target_off_screen(target: Node2D) -> bool:
	if not camera or not target:
		return false

	var viewport = get_viewport()
	if not viewport:
		return false

	var viewport_size = viewport.get_visible_rect().size
	var camera_pos = camera.global_position
	var camera_zoom = camera.zoom

	var view_half_size = viewport_size / (2.0 * camera_zoom)
	var view_rect = Rect2(
		camera_pos.x - view_half_size.x,
		camera_pos.y - view_half_size.y,
		view_half_size.x * 2.0,
		view_half_size.y * 2.0
	)

	return not view_rect.has_point(target.global_position)

func _create_indicator_for_target(target: Node2D) -> void:
	if not target or not is_instance_valid(target):
		return

	var indicator: PickupIndicator = null
	if not indicator_pool.is_empty():
		indicator = indicator_pool.pop_back()
		indicator.visible = true
	else:
		if indicator_scene:
			var instance = indicator_scene.instantiate()
			indicator = instance as PickupIndicator
		else:
			indicator = PickupIndicator.new()

		if indicator:
			add_child(indicator)

	if indicator:
		indicator.set_target(target)
		indicator.set_camera(camera)
		active_indicators[target] = indicator

func _remove_indicator_for_target(target: Node2D) -> void:
	if not target:
		return

	if not is_instance_valid(target):
		if active_indicators.has(target):
			var indicator = active_indicators.get(target) as PickupIndicator
			if indicator and is_instance_valid(indicator):
				indicator.visible = false
				indicator.set_target(null)
				if indicator_pool.size() < 10:
					indicator_pool.append(indicator)
				else:
					indicator.queue_free()
			active_indicators.erase(target)
		return

	if not active_indicators.has(target):
		return

	var indicator = active_indicators[target] as PickupIndicator
	if indicator and is_instance_valid(indicator):
		indicator.visible = false
		indicator.set_target(null)
		if indicator_pool.size() < 10:
			indicator_pool.append(indicator)
		else:
			indicator.queue_free()

	active_indicators.erase(target)

func clear_all_indicators() -> void:
	for t in active_indicators.keys().duplicate():
		_remove_indicator_for_target(t)
