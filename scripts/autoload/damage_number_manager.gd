extends Node

## 伤害飘字管理器
## 统一管理所有伤害飘字的显示

# 伤害飘字场景
var damage_number_scene: PackedScene

# 对象池：复用飘字节点，降低战斗高频命中时 instantiate/queue_free 带来的尖峰
const _POOL_MAX_SIZE: int = 64
var _pool: Array[DamageNumber] = []

func _ready() -> void:
	# 预加载伤害飘字场景
	damage_number_scene = preload("res://scenes/ui/damage_number.tscn")
	if not damage_number_scene:
		push_error("DamageNumberManager: 无法加载伤害飘字场景")

## 显示伤害数字
## world_position: 世界坐标位置
## damage: 伤害值
## is_crit: 是否暴击
func show_damage(world_position: Vector2, damage: float, is_crit: bool = false) -> void:
	if not damage_number_scene:
		return
	
	var damage_number := _acquire_damage_number()
	if not damage_number:
		return
	
	# 添加到场景树（需要找到当前场景的根节点）
	var current_scene = get_tree().current_scene
	if not current_scene:
		return
	
	# 添加到场景根节点，确保在世界坐标中正确显示
	if damage_number.get_parent() == null:
		current_scene.add_child(damage_number)
	else:
		# 兜底：如果还在旧树上，先移到当前场景
		damage_number.get_parent().remove_child(damage_number)
		current_scene.add_child(damage_number)
	
	# 显示伤害
	damage_number.show_damage(world_position, damage, is_crit)

## 显示治疗数字
## world_position: 世界坐标位置
## heal_amount: 治疗量
func show_heal(world_position: Vector2, heal_amount: float) -> void:
	if not damage_number_scene:
		return
	
	var damage_number := _acquire_damage_number()
	if not damage_number:
		return
	
	# 添加到场景树
	var current_scene = get_tree().current_scene
	if not current_scene:
		return
	
	if damage_number.get_parent() == null:
		current_scene.add_child(damage_number)
	else:
		damage_number.get_parent().remove_child(damage_number)
		current_scene.add_child(damage_number)
	
	# 显示治疗
	damage_number.show_heal(world_position, heal_amount)

func recycle_damage_number(node: DamageNumber) -> void:
	if not is_instance_valid(node):
		return
	if node.get_parent():
		node.get_parent().remove_child(node)
	if _pool.size() >= _POOL_MAX_SIZE:
		node.queue_free()
		return
	_pool.append(node)

func _acquire_damage_number() -> DamageNumber:
	if not _pool.is_empty():
		return _pool.pop_back()
	return damage_number_scene.instantiate() as DamageNumber
