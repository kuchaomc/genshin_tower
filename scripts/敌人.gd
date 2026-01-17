extends Area2D

@export var anime_speed : float = -100
# 敌人最大生命值（默认100点）
@export var max_health : float = 100
# 敌人当前生命值
var current_health : float = 100
# 超出屏幕销毁的阈值（屏幕左侧外200像素）
var destroy_threshold : float = -200

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 初始化当前生命值为最大生命值
	current_health = max_health
	
	# 打印初始生命值信息（调试用）
	print("敌人生成，生命值: ", current_health, "/", max_health)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# 向左移动敌人
	position += Vector2(anime_speed, 0) * delta
	
	# 检查是否超出屏幕左侧（超出视野）
	if position.x < destroy_threshold:
		print("敌人超出视野，自动销毁")
		queue_free()

# 受到伤害方法
func take_damage(damage_amount: float) -> void:
	# 减少生命值
	current_health -= damage_amount
	
	# 打印伤害信息（调试用）
	print("敌人受到伤害: ", damage_amount, "点，剩余生命值: ", current_health, "/", max_health)
	
	# 检查生命值是否归零
	if current_health <= 0:
		on_death()

# 死亡处理函数
func on_death() -> void:
	print("敌人死亡")
	
	# 尝试获取游戏管理器并增加分数
	# 注意：这里假设游戏管理器是场景的根节点
	var game_manager = get_parent()
	if game_manager and game_manager.has_method("add_score"):
		game_manager.add_score(10)  # 每个敌人10分
	else:
		# 如果直接获取失败，尝试通过路径获取
		var root_manager = get_node("/root/Node2D")
		if root_manager and root_manager.has_method("add_score"):
			root_manager.add_score(10)
		else:
			print("警告：无法找到游戏管理器添加分数")
	
	# 删除敌人节点
	queue_free()

# 身体进入回调函数（检测与玩家的碰撞）
func _on_body_entered(body: Node2D) -> void:
	# 碰撞体积检测，触发游戏结束方法
	if body is CharacterBody2D:
		print("敌人撞到玩家")
		body.game_over()
