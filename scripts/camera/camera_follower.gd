extends Camera2D

# 跟随目标节点路径
@export var target_path: NodePath
# 阻尼系数（0-1之间，越小越平滑）
@export var damping_factor: float = 0.1
# 最小移动距离，避免微小抖动
@export var min_move_distance: float = 0.5

# 目标节点引用
var target: Node2D = null

func _ready() -> void:
	# 获取目标节点
	if target_path:
		target = get_node_or_null(target_path)
	
	# 如果未设置目标路径或路径无效，尝试自动查找名为"player"的节点
	if not target:
		target = get_node_or_null("../player") as Node2D
	
	# 如果还没找到，等待一帧后重试（因为玩家可能是动态创建的）
	if not target:
		await get_tree().process_frame
		_update_target()
	
	if not target:
		print("警告：相机跟随脚本未找到目标节点")

## 更新目标节点（供外部调用，例如玩家创建后）
func _update_target() -> void:
	if target and is_instance_valid(target):
		return
	
	# 重新尝试获取目标节点
	if target_path:
		target = get_node_or_null(target_path)
	
	if not target:
		target = get_node_or_null("../player") as Node2D
	
	if target:
		print("相机已找到目标节点：", target.name)

func _physics_process(delta: float) -> void:
	# 如果没有目标节点，则不更新
	if not target:
		return
	
	# 获取目标位置
	var target_position: Vector2 = target.global_position
	
	# 计算当前位置与目标位置的距离
	var current_position: Vector2 = global_position
	var distance: float = current_position.distance_to(target_position)
	
	# 如果距离小于最小移动距离，不进行移动（避免微小抖动）
	if distance < min_move_distance:
		return
	
	# 使用阻尼平滑插值更新相机位置
	# lerp的第三个参数是插值系数，这里使用阻尼系数乘以delta来保持帧率无关
	# 注意：阻尼系数需要根据实际效果调整
	var new_position: Vector2 = current_position.lerp(target_position, damping_factor * delta * 60)
	
	# 更新相机位置
	global_position = new_position