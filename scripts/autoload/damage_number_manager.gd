extends Node

## 伤害飘字管理器
## 统一管理所有伤害飘字的显示

# 伤害飘字场景
var damage_number_scene: PackedScene

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
	
	# 实例化伤害飘字
	var damage_number = damage_number_scene.instantiate() as DamageNumber
	if not damage_number:
		return
	
	# 添加到场景树（需要找到当前场景的根节点）
	var current_scene = get_tree().current_scene
	if not current_scene:
		return
	
	# 添加到场景根节点，确保在世界坐标中正确显示
	current_scene.add_child(damage_number)
	
	# 显示伤害
	damage_number.show_damage(world_position, damage, is_crit)

## 显示治疗数字
## world_position: 世界坐标位置
## heal_amount: 治疗量
func show_heal(world_position: Vector2, heal_amount: float) -> void:
	if not damage_number_scene:
		return
	
	# 实例化伤害飘字
	var damage_number = damage_number_scene.instantiate() as DamageNumber
	if not damage_number:
		return
	
	# 添加到场景树
	var current_scene = get_tree().current_scene
	if not current_scene:
		return
	
	current_scene.add_child(damage_number)
	
	# 显示治疗
	damage_number.show_heal(world_position, heal_amount)
