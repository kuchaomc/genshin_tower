extends Area2D

@export var bullet_speed : float = 100
# 子弹伤害值（默认25点）
@export var damage : float = 25
# 子弹发射方向，默认为向右
var direction : Vector2 = Vector2.RIGHT

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 设置子弹旋转以面向移动方向
	rotation = direction.angle()
	
	# 连接碰撞信号
	area_entered.connect(_on_area_entered)
	
	# 设置20秒后自动删除子弹以优化性能
	var timer = get_tree().create_timer(20.0)
	timer.timeout.connect(_on_lifetime_timeout)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# 根据方向移动子弹
	position += direction * bullet_speed * delta

# 区域进入回调函数（检测与敌人的碰撞）
func _on_area_entered(area: Area2D) -> void:
	# 检查碰撞的对象是否为敌人（通过组名判断）
	if area.is_in_group("enemies"):
		# 对敌人造成伤害
		if area.has_method("take_damage"):
			area.take_damage(damage)
		
		# 删除子弹自身（击中敌人后子弹消失）
		queue_free()

# 生命周期结束回调函数
func _on_lifetime_timeout() -> void:
	# 删除子弹节点
	queue_free()
