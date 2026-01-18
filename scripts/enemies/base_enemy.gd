extends Area2D
class_name BaseEnemy

## 敌人基类
## 包含所有敌人的通用逻辑（移动、血量、AI行为等）

# ========== 敌人数据 ==========
var enemy_data: EnemyData = null

# ========== 血量属性 ==========
var current_health: float = 100.0
var max_health: float = 100.0
@export var warning_duration: float = 2.0

# HP显示组件引用
var hp_bar: ProgressBar
var hp_label: Label
var hp_bar_container: Node2D

# 动画精灵引用
var animated_sprite: AnimatedSprite2D
var warning_sprite: Sprite2D
var collision_shape: CollisionShape2D

# ========== 状态 ==========
var is_spawned: bool = false
var is_dead: bool = false

## 初始化敌人
func initialize(data: EnemyData) -> void:
	enemy_data = data
	max_health = data.max_health
	current_health = max_health
	warning_duration = data.warning_duration
	
	print("敌人初始化：", data.display_name)

func _ready() -> void:
	current_health = max_health
	
	# 获取组件引用
	hp_bar = get_node_or_null("HPBar/ProgressBar") as ProgressBar
	hp_label = get_node_or_null("HPBar/Label") as Label
	hp_bar_container = get_node_or_null("HPBar") as Node2D
	animated_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	
	# 创建警告图标
	_create_warning_sprite()
	
	# 隐藏敌人本体
	_set_enemy_visible(false)
	
	# 启动警告计时器
	var timer = get_tree().create_timer(warning_duration)
	timer.timeout.connect(_on_warning_finished)

## 创建警告图标
func _create_warning_sprite() -> void:
	warning_sprite = Sprite2D.new()
	var warning_texture = load("res://textures/warning.png")
	if warning_texture:
		warning_sprite.texture = warning_texture
		warning_sprite.z_index = 10
		add_child(warning_sprite)
	else:
		print("警告：无法加载warning.png")

## 设置敌人本体可见性
func _set_enemy_visible(visible_state: bool) -> void:
	if animated_sprite:
		animated_sprite.visible = visible_state
	if hp_bar_container:
		hp_bar_container.visible = visible_state
	if collision_shape:
		collision_shape.disabled = not visible_state

## 警告结束回调
func _on_warning_finished() -> void:
	is_spawned = true
	
	if warning_sprite:
		warning_sprite.queue_free()
		warning_sprite = null
	
	_set_enemy_visible(true)
	update_hp_display()
	
	print("敌人生成，生命值: ", current_health, "/", max_health)

func _physics_process(delta: float) -> void:
	if not is_spawned or is_dead:
		return
	
	# 执行AI行为（子类可重写）
	perform_ai_behavior(delta)

## 执行AI行为（子类实现）
func perform_ai_behavior(delta: float) -> void:
	# 默认行为：追逐玩家
	chase_player(delta)

## 追逐玩家（默认行为）
func chase_player(delta: float) -> void:
	var player = get_tree().current_scene.get_node_or_null("player") as CharacterBody2D
	if not player:
		player = get_node_or_null("../player") as CharacterBody2D
	
	if player:
		var direction = (player.global_position - global_position).normalized()
		var speed = get_move_speed()
		
		# 根据移动方向翻转精灵图
		if animated_sprite:
			if direction.x < 0:
				animated_sprite.flip_h = true
			else:
				animated_sprite.flip_h = false
		
		position += direction * speed * delta

## 获取移动速度（子类可重写）
func get_move_speed() -> float:
	if enemy_data:
		return enemy_data.move_speed
	return 100.0

## 更新HP显示
func update_hp_display() -> void:
	if hp_bar:
		hp_bar.max_value = max_health
		hp_bar.value = current_health
	if hp_label:
		hp_label.text = str(int(current_health)) + "/" + str(int(max_health))

## 受到伤害
func take_damage(damage_amount: float) -> void:
	if not is_spawned or is_dead:
		return
	
	current_health -= damage_amount
	current_health = max(0, current_health)
	
	update_hp_display()
	
	print("敌人受到伤害: ", damage_amount, "点，剩余生命值: ", current_health, "/", max_health)
	
	if current_health <= 0:
		on_death()

## 死亡处理
func on_death() -> void:
	if is_dead:
		return
	
	is_dead = true
	print("敌人死亡")
	
	# 记录击杀
	if RunManager:
		RunManager.record_enemy_kill()
	
	# 掉落金币
	if enemy_data:
		var gold = enemy_data.drop_gold
		if RunManager:
			RunManager.add_gold(gold)
	
	# 删除敌人节点
	queue_free()

## 身体进入回调函数（检测与玩家的碰撞）
func _on_body_entered(body: Node2D) -> void:
	if not is_spawned or is_dead:
		return
	
	if body is CharacterBody2D:
		print("敌人撞到玩家")
		if body.has_method("take_damage"):
			var damage = get_damage()
			body.take_damage(damage)

## 获取伤害值（子类可重写）
func get_damage() -> float:
	if enemy_data:
		return enemy_data.damage
	return 25.0
