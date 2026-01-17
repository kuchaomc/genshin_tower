extends CharacterBody2D

# 基础速度
@export var move_speed : float = 100
# 动画状态
@export var animator : AnimatedSprite2D
# 子弹场景引用
@export var bullet_scene : PackedScene

var is_game_over : bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 如果没有手动分配子弹场景，则预加载默认子弹场景
	if bullet_scene == null:
		bullet_scene = preload("res://scenes/子弹.tscn")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if not is_game_over:
		# 监听键盘并乘以移动速度，赋予玩家速度
		velocity = Input.get_vector("left", "right", "up", "down") * move_speed
		
		# 检测鼠标左键按下（发射子弹）
		if Input.is_action_just_pressed("mouse1"):
			spawn_bullet()
		
		# 当玩家速度变为0时，开始播放动画
		if velocity == Vector2.ZERO:
			animator.play("idle")
		else:
			animator.play("run")
		
		# 按照速度开始移动
		move_and_slide()

# 生成子弹函数
func spawn_bullet() -> void:
	if bullet_scene == null:
		return
	
	# 实例化子弹场景
	var bullet_instance = bullet_scene.instantiate()
	
	# 计算鼠标方向
	var mouse_position = get_global_mouse_position()
	var direction = (mouse_position - global_position).normalized()
	
	# 设置子弹位置为玩家的全局位置
	bullet_instance.global_position = global_position
	# 设置子弹的发射方向
	bullet_instance.direction = direction
	
	# 将子弹添加到场景树中（添加到当前场景的根节点）
	get_parent().add_child(bullet_instance)

# 游戏结束方法
# 游戏结束方法
func game_over():
	is_game_over = true
	# 调用游戏管理器的游戏结束方法
	# 方法1：直接通过父节点（场景根节点）访问
	var game_manager = get_parent()
	if game_manager and game_manager.has_method("game_over"):
		game_manager.game_over()
	else:
		# 方法2：通过绝对路径访问
		var root_manager = get_node("/root/Node2D")
		if root_manager and root_manager.has_method("game_over"):
			root_manager.game_over()
		else:
			print("错误：无法找到游戏管理器")
