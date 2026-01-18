extends CharacterBody2D
class_name BaseCharacter

## 角色基类
## 包含所有角色的通用逻辑（移动、血量、基础攻击等）

# ========== 角色数据 ==========
var character_data: CharacterData = null

# ========== 血量属性 ==========
var current_health: float = 100.0
var max_health: float = 100.0
@export var invincibility_duration: float = 1.0
var is_invincible: bool = false

# 血量变化信号
signal health_changed(current: float, maximum: float)
signal character_died

# ========== 移动属性 ==========
@export var move_speed: float = 100.0
@export var animator: AnimatedSprite2D

# ========== 状态 ==========
var is_game_over: bool = false

## 初始化角色
func initialize(data: CharacterData) -> void:
	character_data = data
	max_health = data.max_health
	current_health = max_health
	move_speed = data.move_speed
	
	emit_signal("health_changed", current_health, max_health)
	print("角色初始化：", data.display_name)

func _ready() -> void:
	# 如果没有手动分配动画器，则自动查找
	if animator == null:
		animator = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	
	# 初始化血量
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)

func _physics_process(delta: float) -> void:
	if is_game_over:
		return
	
	# 处理移动
	handle_movement()
	
	# 处理动画
	handle_animation()
	
	# 执行移动
	move_and_slide()

## 处理移动（子类可重写）
func handle_movement() -> void:
	if can_move():
		velocity = Input.get_vector("left", "right", "up", "down") * move_speed
	else:
		velocity = Vector2.ZERO

## 是否可以移动（子类可重写，例如攻击时不能移动）
func can_move() -> bool:
	return true

## 处理动画（子类可重写）
func handle_animation() -> void:
	if not animator:
		return
	
	# 根据鼠标位置翻转精灵图
	var mouse_position = get_global_mouse_position()
	if mouse_position.x > global_position.x:
		animator.flip_h = true
	else:
		animator.flip_h = false
	
	# 根据速度播放动画
	if velocity == Vector2.ZERO:
		animator.play("idle")
	else:
		animator.play("run")

## 处理攻击输入（子类实现）
func handle_attack_input() -> void:
	if Input.is_action_just_pressed("mouse1"):
		perform_attack()

## 执行攻击（子类必须实现）
func perform_attack() -> void:
	pass

# ========== 血量相关方法 ==========

## 受到伤害
func take_damage(damage_amount: float) -> void:
	if is_game_over or is_invincible:
		return
	
	current_health -= damage_amount
	current_health = max(0, current_health)
	
	# 更新RunManager
	if RunManager:
		RunManager.take_damage(damage_amount)
	
	emit_signal("health_changed", current_health, max_health)
	print("角色受到伤害: ", damage_amount, "点，剩余血量: ", current_health, "/", max_health)
	
	if current_health <= 0:
		on_death()
	else:
		start_invincibility()

## 开始无敌状态
func start_invincibility() -> void:
	is_invincible = true
	
	if animator:
		animator.modulate.a = 0.5
	
	var timer = get_tree().create_timer(invincibility_duration)
	timer.timeout.connect(end_invincibility)

## 结束无敌状态
func end_invincibility() -> void:
	is_invincible = false
	
	if animator:
		animator.modulate.a = 1.0

## 回复血量
func heal(heal_amount: float) -> void:
	if is_game_over:
		return
	
	current_health += heal_amount
	current_health = min(current_health, max_health)
	
	# 更新RunManager
	if RunManager:
		RunManager.heal(heal_amount)
	
	emit_signal("health_changed", current_health, max_health)
	print("角色回复血量: ", heal_amount, "点，当前血量: ", current_health, "/", max_health)

## 获取当前血量
func get_current_health() -> float:
	return current_health

## 获取最大血量
func get_max_health() -> float:
	return max_health

## 死亡处理
func on_death() -> void:
	print("角色死亡")
	is_game_over = true
	emit_signal("character_died")
	
	# 通知游戏管理器
	if GameManager:
		GameManager.game_over()

## 游戏结束
func game_over() -> void:
	is_game_over = true
