extends CharacterBody2D
class_name BaseCharacter

## 角色基类
## 包含所有角色的通用逻辑（移动、血量、基础攻击等）
## 统一伤害计算公式：最终伤害 = 攻击力 × 攻击倍率 × 暴击倍率 × (1 - 目标减伤比例)

# ========== 角色数据 ==========
var character_data: CharacterData = null

# ========== 属性系统 ==========
## 基础属性（来自 CharacterData，不可修改）
var base_stats: CharacterStats = null
## 当前属性（运行时可被 buff/debuff 修改）
var current_stats: CharacterStats = null

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

# ========== 碰撞掩码（数字版，便于读） ==========
# 约定：第1层=墙(Walls)，第2层=敌人(Enemies)，第3层未用，第4层=玩家(Player)
# - 正常：与墙+敌人碰撞 => 1 + 2 = 3
# - 闪避：只与墙碰撞（可穿过敌人）=> 1
const _NORMAL_COLLISION_MASK: int = 3
const _DODGE_COLLISION_MASK: int = 1
const _PLAYER_COLLISION_LAYER: int = 4
const _DODGE_PLAYER_COLLISION_LAYER: int = 8 # 闪避专用层：让敌人不再“顶开/挡住”玩家

# 血量变化信号
signal health_changed(current: float, maximum: float)
signal character_died
# 伤害事件信号（用于伤害数字显示等）
signal damage_dealt(damage: float, is_crit: bool, target: Node)

# ========== 移动属性 ==========
@export var move_speed: float = 100.0
@export var animator: AnimatedSprite2D
@export var knockback_force: float = 150.0  # 对敌人造成击退的力度，可在角色数据中配置

# ========== 碰撞箱引用 ==========
var collision_shape: CollisionShape2D

# ========== 击退效果 ==========
@export var knockback_resistance: float = 0.5  # 击退抗性（0-1，1表示完全抵抗）
var knockback_velocity: Vector2 = Vector2.ZERO
var is_knockback_active: bool = false

# ========== 状态 ==========
var is_game_over: bool = false

## 初始化角色
func initialize(data: CharacterData) -> void:
	character_data = data
	
	# 初始化属性系统
	base_stats = data.get_stats()
	current_stats = base_stats.duplicate_stats()
	
	# 应用属性到角色
	_apply_stats_to_character()
	
	emit_signal("health_changed", current_health, max_health)
	print("角色初始化：", data.display_name, " | ", current_stats.get_summary())

## 从当前属性应用到角色实际数值
func _apply_stats_to_character() -> void:
	if not current_stats:
		return
	max_health = current_stats.max_health
	current_health = max_health
	base_move_speed = current_stats.move_speed
	move_speed = base_move_speed
	knockback_force = current_stats.knockback_force

func _ready() -> void:
	# 如果没有手动分配动画器，则自动查找
	if animator == null:
		animator = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	
	# 获取碰撞箱引用
	collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	
	# 没有通过initialize赋值时，创建默认属性并使用当前速度作为基准
	if current_stats == null:
		current_stats = CharacterStats.new()
		current_stats.max_health = max_health
		current_stats.move_speed = move_speed
		current_stats.knockback_force = knockback_force
		base_stats = current_stats.duplicate_stats()
	
	if base_move_speed == 0:
		base_move_speed = move_speed
	
	# 初始化血量
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)
	
	# 将玩家本体放到“玩家层”，避免与墙层/敌人层混用
	collision_layer = _PLAYER_COLLISION_LAYER
	
	# 初始化碰撞掩码：默认与墙+敌人发生碰撞
	collision_mask = _NORMAL_COLLISION_MASK

func _physics_process(delta: float) -> void:
	if is_game_over:
		return
	
	# 闪避输入/更新（放在移动前，确保覆盖本帧速度）
	handle_dodge_input()
	_update_dodge(delta)
	
	# 处理击退效果
	_update_knockback(delta)
	
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
	
	# 击退时优先应用击退速度
	if is_knockback_active:
		velocity = knockback_velocity
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

# ========== 统一伤害计算系统 ==========

## 计算并造成伤害（核心方法）
## target: 目标节点（必须有 take_damage 方法和可选的 get_defense_percent 方法）
## damage_multiplier: 伤害倍率（普攻 1.0，技能可能 1.5、2.0 等）
## force_crit: 强制暴击
## force_no_crit: 强制不暴击
## 返回值: [实际造成的伤害, 是否暴击]
func deal_damage_to(target: Node, damage_multiplier: float = 1.0, force_crit: bool = false, force_no_crit: bool = false) -> Array:
	if not current_stats:
		return [0.0, false]
	
	# 获取目标的减伤比例
	var target_defense: float = 0.0
	if target.has_method("get_defense_percent"):
		target_defense = target.get_defense_percent()
	
	# 使用统一的伤害计算公式
	var result = current_stats.calculate_damage(damage_multiplier, target_defense, force_crit, force_no_crit)
	var final_damage: float = result[0]
	var is_crit: bool = result[1]
	
	# 应用升级加成（如果有 RunManager）
	if RunManager:
		var damage_upgrade = RunManager.get_upgrade_level("damage")
		final_damage *= (1.0 + damage_upgrade * 0.1)  # 每级 +10% 伤害
	
	# 对目标造成伤害
	if target.has_method("take_damage"):
		var knockback_dir = Vector2.ZERO
		if target is Node2D:
			knockback_dir = (target.global_position - global_position).normalized()
		
		# 检查目标的 take_damage 方法签名
		if target.has_method("take_damage"):
			# 尝试带击退调用
			var params = [final_damage, knockback_dir * current_stats.knockback_force]
			if _can_call_with_params(target, "take_damage", 2):
				target.take_damage(final_damage, knockback_dir * current_stats.knockback_force)
			else:
				target.take_damage(final_damage)
	
	# 记录伤害统计
	if RunManager:
		RunManager.record_damage_dealt(final_damage)
	
	# 发射伤害事件信号
	emit_signal("damage_dealt", final_damage, is_crit, target)
	
	return [final_damage, is_crit]

## 检查方法是否支持指定数量的参数
func _can_call_with_params(obj: Object, method_name: String, param_count: int) -> bool:
	for method in obj.get_method_list():
		if method["name"] == method_name:
			return method["args"].size() >= param_count
	return false

## 获取当前攻击力
func get_attack() -> float:
	if current_stats:
		return current_stats.attack
	return 25.0

## 获取当前暴击率
func get_crit_rate() -> float:
	if current_stats:
		return current_stats.crit_rate
	return 0.05

## 获取当前暴击伤害
func get_crit_damage() -> float:
	if current_stats:
		return current_stats.crit_damage
	return 0.5

## 获取当前减伤比例
func get_defense_percent() -> float:
	if current_stats:
		return current_stats.defense_percent
	return 0.0

## 获取当前攻击速度
func get_attack_speed() -> float:
	if current_stats:
		return current_stats.attack_speed
	return 1.0

## 获取当前击退力度
func get_knockback_force() -> float:
	if current_stats:
		return current_stats.knockback_force
	return knockback_force

# ========== 血量相关方法 ==========

## 受到伤害（应用自身减伤）
## knockback_direction: 击退方向（可选，如果提供则应用击退效果）
## knockback_force: 击退力度（可选，默认值）
func take_damage(damage_amount: float, knockback_direction: Vector2 = Vector2.ZERO, knockback_force_value: float = 100.0) -> void:
	if is_game_over or _is_currently_invincible():
		return
	
	# 应用减伤计算
	var actual_damage = damage_amount
	if current_stats:
		actual_damage = current_stats.calculate_damage_taken(damage_amount)
	
	current_health -= actual_damage
	current_health = max(0, current_health)
	
	# 更新RunManager
	if RunManager:
		RunManager.take_damage(actual_damage)
	
	emit_signal("health_changed", current_health, max_health)
	print("角色受到伤害: ", actual_damage, "点（原始: ", damage_amount, "），剩余血量: ", current_health, "/", max_health)
	
	# 应用击退效果
	if knockback_direction != Vector2.ZERO:
		apply_knockback(knockback_direction, knockback_force_value)
	
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
	# 重要：闪避无敌不应关闭碰撞（否则会穿出空气墙/边界）
	# 伤害免疫由 _dodge_invincible 控制，碰撞仍保持开启以便被墙体阻挡
	# 同时：闪避期间可选择“穿过敌人”，只保留与墙的碰撞
	collision_mask = _DODGE_COLLISION_MASK
	# 注意：物理碰撞过滤对“移动的敌人”是单向的（敌人 mask 包含玩家层即可顶开玩家）
	# 为确保闪避能真正穿怪，这里把玩家临时切到一个“闪避层”，敌人 mask(5) 不包含该层
	collision_layer = _DODGE_PLAYER_COLLISION_LAYER

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
		# 碰撞在闪避期间始终保持开启，无需恢复
		# 恢复正常碰撞：墙+敌人
		collision_mask = _NORMAL_COLLISION_MASK
		# 恢复玩家层
		collision_layer = _PLAYER_COLLISION_LAYER

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

@export var knockback_duration: float = 0.12  # 击退持续时间（秒）
var _knockback_end_ms: int = 0

## 应用击退效果（按“击退距离”计算）
## distance: 本次希望推开的距离（像素）
func apply_knockback(direction: Vector2, distance: float) -> void:
	if direction == Vector2.ZERO or distance <= 0.0:
		return
	
	# 应用击退抗性
	var effective_distance = distance * (1.0 - knockback_resistance)
	var knockback_dir = direction.normalized()
	
	# 设置击退速度：在 knockback_duration 内推开指定距离
	var dur: float = max(0.01, knockback_duration)
	knockback_velocity = knockback_dir * (effective_distance / dur)
	is_knockback_active = true
	_knockback_end_ms = Time.get_ticks_msec() + int(dur * 1000.0)

## 更新击退效果
func _update_knockback(delta: float) -> void:
	if not is_knockback_active:
		return
	if Time.get_ticks_msec() >= _knockback_end_ms:
		_end_knockback()

## 结束击退效果
func _end_knockback() -> void:
	is_knockback_active = false
	knockback_velocity = Vector2.ZERO

## 设置碰撞箱启用/禁用
func _set_collision_enabled(enabled: bool) -> void:
	if collision_shape:
		collision_shape.disabled = not enabled

# ========== 属性修改方法（用于 buff/debuff） ==========

## 增加攻击力
func add_attack(amount: float) -> void:
	if current_stats:
		current_stats.attack += amount

## 增加暴击率
func add_crit_rate(amount: float) -> void:
	if current_stats:
		current_stats.crit_rate = clamp(current_stats.crit_rate + amount, 0.0, 1.0)

## 增加暴击伤害
func add_crit_damage(amount: float) -> void:
	if current_stats:
		current_stats.crit_damage += amount

## 增加减伤比例
func add_defense_percent(amount: float) -> void:
	if current_stats:
		current_stats.defense_percent = clamp(current_stats.defense_percent + amount, 0.0, 1.0)

## 增加移动速度
func add_move_speed(amount: float) -> void:
	if current_stats:
		current_stats.move_speed += amount
		base_move_speed = current_stats.move_speed
		move_speed = base_move_speed

## 增加攻击速度
func add_attack_speed(amount: float) -> void:
	if current_stats:
		current_stats.attack_speed += amount

## 重置属性到基础值
func reset_stats_to_base() -> void:
	if base_stats:
		current_stats = base_stats.duplicate_stats()
		_apply_stats_to_character()
