extends Area2D

@export var anime_speed : float = 100
# 敌人最大生命值（默认100点）
@export var max_health : float = 100
# 敌人当前生命值
var current_health : float = 100

# HP显示组件引用
var hp_bar : ProgressBar
var hp_label : Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 初始化当前生命值为最大生命值
	current_health = max_health
	
	# 获取HP显示组件
	hp_bar = get_node("HPBar/ProgressBar") as ProgressBar
	hp_label = get_node("HPBar/Label") as Label
	
	# 初始化HP显示
	update_hp_display()
	
	# 打印初始生命值信息（调试用）
	print("敌人生成，生命值: ", current_health, "/", max_health)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# 获取玩家节点（通过场景根节点或父节点查找）
	var player = get_tree().current_scene.get_node_or_null("player") as CharacterBody2D
	if not player:
		player = get_node_or_null("../player") as CharacterBody2D
	
	if player:
		# 计算朝向玩家的方向
		var direction = (player.global_position - global_position).normalized()
		# 向玩家方向移动
		position += direction * anime_speed * delta
	else:
		# 如果找不到玩家，保持原有移动逻辑（向后兼容）
		print("警告：未找到玩家节点")

# 更新HP显示
func update_hp_display() -> void:
	if hp_bar:
		hp_bar.max_value = max_health
		hp_bar.value = current_health
	if hp_label:
		hp_label.text = str(int(current_health)) + "/" + str(int(max_health))

# 受到伤害方法
func take_damage(damage_amount: float) -> void:
	# 减少生命值
	current_health -= damage_amount
	
	# 更新HP显示
	update_hp_display()
	
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
