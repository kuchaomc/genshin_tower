extends Node2D
var main_menu_scene: PackedScene


enum GameState {
	PLAYING,
	GAME_OVER
}

# 导出的敌人场景引用
@export var enemy_scene: PackedScene

# 当前游戏状态
var current_state: GameState = GameState.PLAYING
# 分数
var score: int = 0
# 敌人生成计时器
var enemy_spawn_timer: Timer
# 游戏结束计时器
var game_over_timer: Timer
# UI Label引用
var score_label: Label
# 玩家血量UI引用
var player_hp_bar: ProgressBar
var player_hp_label: Label
# 玩家引用
var player: CharacterBody2D

# 当节点第一次进入场景树时调用
func _ready() -> void:
	main_menu_scene = load("res://scenes/主界面.tscn")
	if main_menu_scene == null:
		print("错误：无法加载主界面场景")
	
	score_label = get_node("CanvasLayer/Label")
	if score_label:
		update_score_display()
	
	# 获取玩家血量UI组件
	player_hp_bar = get_node_or_null("CanvasLayer/PlayerHPBar/ProgressBar") as ProgressBar
	player_hp_label = get_node_or_null("CanvasLayer/PlayerHPBar/Label") as Label
	
	# 获取玩家引用并连接血量变化信号
	player = get_node_or_null("player") as CharacterBody2D
	if player:
		# 连接血量变化信号
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
		# 初始化血量UI显示
		if player.has_method("get_current_health") and player.has_method("get_max_health"):
			_on_player_health_changed(player.get_current_health(), player.get_max_health())
	
	# 如果没有手动分配敌人场景，则预加载默认敌人场景
	if enemy_scene == null:
		enemy_scene = preload("res://scenes/敌人.tscn")
	
	# 创建敌人生成计时器
	enemy_spawn_timer = Timer.new()
	enemy_spawn_timer.wait_time = 3.0  # 每3秒生成一个敌人
	enemy_spawn_timer.timeout.connect(_on_enemy_spawn_timer_timeout)
	add_child(enemy_spawn_timer)
	enemy_spawn_timer.start()
	
	# 创建游戏结束计时器（用于延迟重新加载）
	game_over_timer = Timer.new()
	game_over_timer.one_shot = true
	game_over_timer.timeout.connect(_on_game_over_timer_timeout)
	add_child(game_over_timer)
	
	print("游戏管理器已初始化，开始自动生成敌人")

# 敌人生成计时器回调
func _on_enemy_spawn_timer_timeout() -> void:
	if current_state == GameState.PLAYING:
		spawn_enemy()

# 生成敌人函数
func spawn_enemy() -> void:
	if enemy_scene == null:
		print("错误：敌人场景未加载")
		return
	
	# 实例化敌人场景
	var enemy_instance = enemy_scene.instantiate()
	
	# 在椭圆空气墙内部随机生成位置（如果存在）
	var spawn_pos: Vector2
	var boundary := get_node_or_null("EllipseBoundary") as EllipseBoundary
	if boundary:
		var center: Vector2 = boundary.global_position
		var a: float = boundary.ellipse_radius_x
		var b: float = boundary.ellipse_radius_y
		
		# 采样均匀分布在椭圆内部的随机点
		var angle: float = randf() * TAU
		var r: float = sqrt(randf())  # 保证在圆内均匀分布
		var local: Vector2 = Vector2(cos(angle) * a * r, sin(angle) * b * r)
		spawn_pos = center + local
	else:
		# 兜底：如果没有空气墙，就按屏幕范围随机生成
		var screen_size = get_viewport().get_visible_rect().size
		var spawn_x = randf_range(0, screen_size.x)
		var spawn_y = randf_range(0, screen_size.y)
		spawn_pos = Vector2(spawn_x, spawn_y)
	
	# 设置敌人位置
	enemy_instance.global_position = spawn_pos
	
	# 添加到场景树中
	get_tree().current_scene.add_child(enemy_instance)
	
	print("生成新敌人，位置：", enemy_instance.position)

# 游戏结束方法
func game_over() -> void:
	if current_state == GameState.GAME_OVER:
		return
	
	current_state = GameState.GAME_OVER
	
	# 停止敌人生成计时器
	if enemy_spawn_timer:
		enemy_spawn_timer.stop()
	
	print("游戏结束！3秒后返回主界面...")
	
	# 设置3秒后返回主界面
	game_over_timer.wait_time = 3.0
	game_over_timer.start()

# 修改游戏结束计时器回调
func _on_game_over_timer_timeout() -> void:
	print("返回主界面...")
	# 修改这里：从重新加载场景改为切换到主界面
	get_tree().change_scene_to_packed(main_menu_scene)

# 增加分数
func add_score(points: int) -> void:
	score += points
	print("增加", points, "分，当前总分：", score)
	update_score_display()

# 更新分数显示
func update_score_display() -> void:
	if score_label:
		score_label.text = "得分: " + str(score)

# 获取当前分数
func get_score() -> int:
	return score

# 获取游戏状态
func get_game_state() -> GameState:
	return current_state

# 开始新游戏（重置状态）
func start_new_game() -> void:
	current_state = GameState.PLAYING
	score = 0
	update_score_display()
	
	# 重新启动敌人生成计时器
	if enemy_spawn_timer:
		enemy_spawn_timer.start()
	
	print("开始新游戏")

# ========== 玩家血量UI相关 ==========

# 玩家血量变化回调
func _on_player_health_changed(current: float, maximum: float) -> void:
	update_player_hp_display(current, maximum)

# 更新玩家血量UI显示
func update_player_hp_display(current: float, maximum: float) -> void:
	if player_hp_bar:
		player_hp_bar.max_value = maximum
		player_hp_bar.value = current
	if player_hp_label:
		player_hp_label.text = "HP: " + str(int(current)) + "/" + str(int(maximum))
