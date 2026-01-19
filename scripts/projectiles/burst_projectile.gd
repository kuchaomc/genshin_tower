extends Area2D
class_name BurstProjectile

## 大招特效投射物
## 向指定方向发射，对碰撞到的敌人造成伤害

@export var speed: float = 300.0
@export var damage: float = 100.0
var direction: Vector2 = Vector2.RIGHT
## 是否暴击（用于显示暴击伤害效果）
var is_crit: bool = false

# 已命中的敌人列表（避免重复伤害）
var hit_enemies: Array[Node2D] = []

func _ready() -> void:
	# 连接碰撞信号
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	# 约定：第2层=敌人(Enemies)。投射物只需要检测敌人层即可。
	collision_mask = 2
	
	# 设置旋转以面向移动方向（注意：Godot的rotation是弧度，angle()返回的也是弧度）
	if direction != Vector2.ZERO:
		rotation = direction.angle()
	
	# 设置5秒后自动删除以优化性能
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(_on_lifetime_timeout)
	
	# 启用监控
	monitoring = true
	monitorable = true

func _physics_process(delta: float) -> void:
	# 根据方向移动投射物
	if direction != Vector2.ZERO:
		position += direction * speed * delta

## 区域进入回调函数（检测与敌人的碰撞）
func _on_area_entered(area: Area2D) -> void:
	_handle_enemy_collision(area)

## 物体进入回调函数（检测与敌人的碰撞）
func _on_body_entered(body: Node2D) -> void:
	_handle_enemy_collision(body)

## 处理敌人碰撞
func _handle_enemy_collision(enemy: Node2D) -> void:
	# 检查碰撞的对象是否为敌人
	if not enemy.is_in_group("enemies"):
		return
	
	# 检查是否已经命中过
	if enemy in hit_enemies:
		return
	
	hit_enemies.append(enemy)
	
	# 对敌人造成伤害
	if enemy.has_method("take_damage"):
		var knockback_dir = direction.normalized()
		enemy.take_damage(damage, knockback_dir * 150.0)  # 击退力度
		
		# 记录伤害
		if RunManager:
			RunManager.record_damage_dealt(damage)
		
		if is_crit:
			print("大招 暴击！命中敌人，造成伤害: ", damage)
		else:
			print("大招命中敌人，造成伤害: ", damage)
	
	# 命中敌人后不删除投射物，继续前进（可以穿透多个敌人）

## 生命周期结束回调函数
func _on_lifetime_timeout() -> void:
	queue_free()
