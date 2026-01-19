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
var is_invincible: bool = false # 兼容字段：由“受伤无敌/闪避无敌”合并而来
var base_move_speed: float = 100.0
@export var hurt_speed_boost_multiplier: float = 1.1  # 受伤后移动速度倍率（略微提升）
@export var hurt_speed_boost_duration: float = 2.0   # 提升持续时间（秒）
var _hurt_speed_timer: Timer

# ========== 闪避（通用能力） ==========
@export var dodge_duration: float = 0.18        # 闪避持续时间（秒）
@export var dodge_cooldown: float = 0.6         # 闪避冷却（秒）
@export var dodge_distance: float = 120.0       # 闪避期望距离（像素，可在面板调节）
@export var dodge_speed_multiplier: float = 3.0 # 闪避初始速度倍率（基于基础速度）
@export var dodge_alpha: float = 0.7            # 闪避时透明度（视觉反馈）

var _is_dodging: bool = false
var _dodge_elapsed: float = 0.0
var _dodge_dir: Vector2 = Vector2.ZERO
var _dodge_next_ready_ms: int = 0
var _last_nonzero_move_dir: Vector2 = Vector2.RIGHT

var _hurt_invincible: bool = false
var _dodge_invincible: bool = false

# 血量变化信号
signal health_changed(current: float, maximum: float)
signal character_died

# ========== 移动属性 ==========
@export var move_speed: float = 100.0
@export var animator: AnimatedSprite2D
@export var knockback_force: float = 150.0  # 对敌人造成击退的力度，可在角色数据中配置

# ========== 状态 ==========
var is_game_over: bool = false

## 初始化角色
func initialize(data: CharacterData) -> void:
	character_data = data
	max_health = data.max_health
	current_health = max_health
	base_move_speed = data.move_speed
	move_speed = base_move_speed
	knockback_force = data.knockback_force
	
	emit_signal("health_changed", current_health, max_health)
	print("角色初始化：", data.display_name)

func _ready() -> void:
	# 如果没有手动分配动画器，则自动查找
	if animator == null:
		animator = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	
	# 没有通过initialize赋值时，使用当前速度作为基准
	if base_move_speed == 0:
		base_move_speed = move_speed
	
	# 初始化血量
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)

func _physics_process(delta: float) -> void:
	if is_game_over:
		return
	
	# 闪避输入/更新（放在移动前，确保覆盖本帧速度）
	handle_dodge_input()
	_update_dodge(delta)
	
	# 处理移动
	handle_movement()
	
	# 处理动画
	handle_animation()
	
	# 执行移动
	move_and_slide()

## 处理移动（子类可重写）
func handle_movement() -> void:
	# 闪避时由闪避逻辑直接控制速度
	if _is_dodging:
		return
	if can_move():
		velocity = Input.get_vector("left", "right", "up", "down") * move_speed
		if velocity != Vector2.ZERO:
			_last_nonzero_move_dir = velocity.normalized()
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
	if is_game_over or _is_currently_invincible():
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
		apply_hurt_speed_boost()

## 开始无敌状态
func start_invincibility() -> void:
	_set_hurt_invincible(true)
	
	var timer = get_tree().create_timer(invincibility_duration)
	timer.timeout.connect(end_invincibility)

## 结束无敌状态
func end_invincibility() -> void:
	_set_hurt_invincible(false)

## 处理闪避输入（右键）
func handle_dodge_input() -> void:
	if is_game_over:
		return
	# 子类可通过重写 can_dodge 控制可否闪避（例如攻击中禁止）
	if Input.is_action_just_pressed("mouse2") and can_dodge():
		_try_start_dodge()

## 是否可以闪避（子类可重写）
func can_dodge() -> bool:
	return (not _is_dodging) and _is_dodge_ready()

func _is_dodge_ready() -> bool:
	return Time.get_ticks_msec() >= _dodge_next_ready_ms

func _try_start_dodge() -> void:
	if _is_dodging or not _is_dodge_ready():
		return
	start_dodge()

## 开始闪避（向鼠标方向）
func start_dodge() -> void:
	_is_dodging = true
	_dodge_elapsed = 0.0
	_dodge_next_ready_ms = Time.get_ticks_msec() + int(dodge_cooldown * 1000.0)
	
	var mouse_pos: Vector2 = get_global_mouse_position()
	var dir: Vector2 = mouse_pos - global_position
	if dir == Vector2.ZERO:
		dir = _last_nonzero_move_dir
	_dodge_dir = dir.normalized()
	
	_set_dodge_invincible(true)

func _update_dodge(delta: float) -> void:
	if not _is_dodging:
		return
	
	_dodge_elapsed += delta
	var t: float = 0.0
	if dodge_duration > 0.0:
		t = clamp(_dodge_elapsed / dodge_duration, 0.0, 1.0)
	
	# 基础速度取决于“目标闪避距离 / 持续时间”
	var base_speed: float = base_move_speed
	if dodge_duration > 0.0:
		base_speed = dodge_distance / dodge_duration
	
	# 速度曲线：初始很快，逐渐回落（平滑）
	# 保证平均速度仍约等于 base_speed，从而距离可控
	var start_speed: float = base_speed * dodge_speed_multiplier
	var end_speed: float = base_speed * 0.8
	var ease_out: float = 1.0 - pow(1.0 - t, 2.0)
	var speed: float = lerp(start_speed, end_speed, ease_out)
	velocity = _dodge_dir * speed
	
	if t >= 1.0:
		_is_dodging = false
		_set_dodge_invincible(false)

func _is_currently_invincible() -> bool:
	return _hurt_invincible or _dodge_invincible

func _set_hurt_invincible(active: bool) -> void:
	_hurt_invincible = active
	_refresh_invincible_state()

func _set_dodge_invincible(active: bool) -> void:
	_dodge_invincible = active
	_refresh_invincible_state()

func _refresh_invincible_state() -> void:
	is_invincible = _is_currently_invincible()
	if not animator:
		return
	# 优先展示受伤无敌的更强提示，其次是闪避无敌
	if _hurt_invincible:
		animator.modulate.a = 0.5
	elif _dodge_invincible:
		animator.modulate.a = dodge_alpha
	else:
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

## 受伤后临时提高移动速度
func apply_hurt_speed_boost() -> void:
	# 设置提升后的移动速度
	move_speed = base_move_speed * hurt_speed_boost_multiplier
	
	# 如果已有计时器，重置时间；否则创建新计时器
	if _hurt_speed_timer == null:
		_hurt_speed_timer = Timer.new()
		_hurt_speed_timer.one_shot = true
		add_child(_hurt_speed_timer)
		_hurt_speed_timer.timeout.connect(_reset_hurt_speed_boost)
	
	_hurt_speed_timer.wait_time = hurt_speed_boost_duration
	_hurt_speed_timer.start()

## 恢复受伤前的基础速度
func _reset_hurt_speed_boost() -> void:
	move_speed = base_move_speed
