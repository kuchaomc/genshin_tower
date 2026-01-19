extends CharacterBody2D

## @deprecated 此脚本已废弃，请使用 BaseCharacter 及其子类（如 KamisatoAyakaCharacter）
## 保留此文件仅用于向后兼容，新角色请继承 BaseCharacter

# ========== 血量属性 ==========
# 最大血量
@export var max_health : float = 100.0
# 当前血量
var current_health : float = 100.0
# 受伤无敌时间（秒）
@export var invincibility_duration : float = 1.0
# 是否处于无敌状态（兼容字段：由“受伤无敌/闪避无敌”合并而来）
var is_invincible : bool = false
var _hurt_invincible: bool = false
var _dodge_invincible: bool = false

# ========== 闪避属性 ==========
@export var dodge_duration: float = 0.18
@export var dodge_cooldown: float = 0.6
@export var dodge_distance: float = 120.0
@export var dodge_speed_multiplier: float = 3.0
@export var dodge_alpha: float = 0.7

var _is_dodging: bool = false
var _dodge_elapsed: float = 0.0
var _dodge_dir: Vector2 = Vector2.ZERO
var _dodge_next_ready_ms: int = 0
var _last_nonzero_move_dir: Vector2 = Vector2.RIGHT

# 血量变化信号（用于UI更新）
signal health_changed(current: float, maximum: float)
signal player_died

# ========== 移动属性 ==========
# 基础速度
@export var move_speed : float = 100
# 动画状态
@export var animator : AnimatedSprite2D
# 剑的Area2D节点
@export var sword_area : Area2D
# 剑的伤害值
@export var sword_damage : float = 25.0
# 第一段挥剑持续时间
@export var swing_duration : float = 0.3
# 第二段剑花攻击持续时间
@export var flower_attack_duration : float = 0.4
# 第一段位移距离
@export var dash_distance : float = 40.0
# 挥剑角度（增加攻击幅度）
@export var swing_angle : float = PI * 1.2  # 约216度
# 第二段攻击伤害次数
@export var phase2_hit_count : int = 3
# 触发重击（第二段）的最小按住时长（秒），防止连点误触
# 提高阈值以进一步降低快速连点误触概率
const PHASE2_HOLD_THRESHOLD: float = 0.5

var is_game_over : bool = false
var phase2_current_hit : int = 0  # 当前第二段已造成的伤害次数
var attack_state : int = 0  # 0=无攻击, 1=第一段, 2=第二段
var swing_tween : Tween
var position_tween : Tween
var target_position : Vector2  # 第一段的目标位置
var hit_enemies_phase1 : Array[Area2D] = []  # 第一段已受伤的敌人
var hit_enemies_phase2 : Array[Area2D] = []  # 第二段已受伤的敌人
var original_position : Vector2  # 原始位置（用于第二段）
var phase1_press_timestamp_ms : int = 0  # 记录第一段开始时的按下时间
var phase1_had_release : bool = false  # 第一段过程中是否松开过鼠标

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 初始化血量
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)
	
	# 如果没有手动分配剑区域，则自动查找
	if sword_area == null:
		sword_area = get_node_or_null("SwordArea") as Area2D
	
	if sword_area:
		# 连接碰撞信号
		sword_area.area_entered.connect(_on_sword_area_entered)
		# 初始时隐藏剑的碰撞区域
		sword_area.monitoring = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if not is_game_over:
		# 闪避输入/更新（放在移动前，确保覆盖本帧速度）
		_handle_dodge_input()
		_update_dodge(delta)
		
		# 攻击状态下阻止移动
		if attack_state == 0 and not _is_dodging:
			# 监听键盘并乘以移动速度，赋予玩家速度
			velocity = Input.get_vector("left", "right", "up", "down") * move_speed
			if velocity != Vector2.ZERO:
				_last_nonzero_move_dir = velocity.normalized()
		else:
			# 闪避时速度由闪避逻辑控制；攻击时速度为0
			if attack_state != 0:
				velocity = Vector2.ZERO
		
		# 记录第一段攻击中是否出现过松开事件，避免连点触发重击
		if attack_state == 1 and Input.is_action_just_released("mouse1"):
			phase1_had_release = true
		
		# 检测鼠标左键按下（挥剑攻击）
		if Input.is_action_just_pressed("mouse1") and attack_state == 0 and not _is_dodging:
			start_attack()
		
		# 只在非攻击状态下更新剑的朝向
		if attack_state == 0:
			update_sword_direction()
		
		# 根据鼠标位置翻转精灵图
		var mouse_position = get_global_mouse_position()
		if mouse_position.x > global_position.x:
			# 鼠标在右边，翻转精灵图
			animator.flip_h = true
		else:
			# 鼠标在左边，保持原样（不翻转）
			animator.flip_h = false
		
		# 当玩家速度变为0时，开始播放动画
		if velocity == Vector2.ZERO:
			animator.play("idle")
		else:
			animator.play("run")
		
		# 按照速度开始移动
		move_and_slide()

func _handle_dodge_input() -> void:
	if is_game_over:
		return
	# 旧玩家脚本：攻击期间不允许闪避，避免与位移/判定冲突
	if attack_state != 0:
		return
	if Input.is_action_just_pressed("mouse2") and _is_dodge_ready() and not _is_dodging:
		_start_dodge()

func _is_dodge_ready() -> bool:
	return Time.get_ticks_msec() >= _dodge_next_ready_ms

func _start_dodge() -> void:
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
	var base_speed: float = float(move_speed)
	if dodge_duration > 0.0:
		base_speed = dodge_distance / dodge_duration
	
	# 速度曲线：初始很快，逐渐回落（平滑）；平均速度约为 base_speed
	var start_speed: float = base_speed * dodge_speed_multiplier
	var end_speed: float = base_speed * 0.8
	var ease_out: float = 1.0 - pow(1.0 - t, 2.0)
	var speed: float = lerp(start_speed, end_speed, ease_out)
	velocity = _dodge_dir * speed
	
	if t >= 1.0:
		_is_dodging = false
		_set_dodge_invincible(false)

# 更新剑的朝向（朝向鼠标）
func update_sword_direction() -> void:
	if not sword_area or attack_state != 0:
		return
	
	# 计算剑柄位置（SwordArea的原点位置）
	var sword_pivot_global = sword_area.global_position
	
	var mouse_position = get_global_mouse_position()
	# 从剑柄位置到鼠标位置的方向
	var direction = (mouse_position - sword_pivot_global).normalized()
	# 计算角度并旋转剑（调整为正确的朝向）
	sword_area.rotation = direction.angle() + PI / 2

# 开始攻击（两段攻击）
func start_attack() -> void:
	if not sword_area or attack_state != 0:
		return
	
	# 记录鼠标位置（用于挥剑方向）
	var mouse_position = get_global_mouse_position()
	# 记录按键按下时间，用于判定是否按住触发第二段
	phase1_press_timestamp_ms = Time.get_ticks_msec()
	phase1_had_release = false
	
	# 获取操控方向（键盘输入方向）用于位移
	var input_direction = Input.get_vector("left", "right", "up", "down")
	if input_direction == Vector2.ZERO:
		# 如果没有输入方向，则使用鼠标方向作为位移方向
		input_direction = (mouse_position - global_position).normalized()
	else:
		input_direction = input_direction.normalized()
	
	# 位移目标位置使用操控方向
	target_position = global_position + input_direction * dash_distance
	original_position = global_position
	
	# 清空已受伤敌人列表
	hit_enemies_phase1.clear()
	hit_enemies_phase2.clear()
	
	# 开始第一段攻击
	attack_state = 1
	start_phase1_attack(mouse_position)

# 第一段攻击：向鼠标方向位移并挥剑
func start_phase1_attack(mouse_target: Vector2) -> void:
	# 启用碰撞检测
	sword_area.monitoring = true
	
	# 计算挥剑角度
	var direction = (mouse_target - global_position).normalized()
	var base_angle = direction.angle() + PI / 2
	
	# 取消之前的Tween
	if swing_tween:
		swing_tween.kill()
	if position_tween:
		position_tween.kill()
	
	# 设置起始角度（大幅增加攻击幅度）
	sword_area.rotation = base_angle - swing_angle / 2
	
	# 同时进行位移和旋转
	position_tween = create_tween()
	position_tween.set_parallel(true)
	position_tween.tween_property(self, "global_position", target_position, swing_duration)
	
	swing_tween = create_tween()
	swing_tween.set_ease(Tween.EASE_OUT)
	swing_tween.set_trans(Tween.TRANS_BACK)
	swing_tween.tween_property(sword_area, "rotation", base_angle + swing_angle / 2, swing_duration)
	swing_tween.tween_callback(finish_phase1)

# 完成第一段攻击，检查是否需要开始第二段
func finish_phase1() -> void:
	if sword_area:
		sword_area.monitoring = false
	
	# 检查鼠标是否持续按住且按住时长超过阈值，防止连点误触第二段
	var continuous_hold: bool = Input.is_action_pressed("mouse1") and not phase1_had_release
	var held_long_enough: bool = continuous_hold and (Time.get_ticks_msec() - phase1_press_timestamp_ms) / 1000.0 >= PHASE2_HOLD_THRESHOLD
	if held_long_enough:
		# 鼠标仍然按住，开始第二段
		attack_state = 2
		start_phase2_attack()
	else:
		# 鼠标已释放，直接结束攻击
		finish_attack()

# 结束攻击（用于第一段后鼠标已释放的情况）
func finish_attack() -> void:
	if sword_area:
		sword_area.monitoring = false
	attack_state = 0
	phase1_press_timestamp_ms = 0
	phase1_had_release = false
	
	# 清空已受伤敌人列表
	hit_enemies_phase1.clear()
	hit_enemies_phase2.clear()

# 第二段攻击：原地剑花攻击（使用射线检测）
func start_phase2_attack() -> void:
	if attack_state != 2:  # 防止状态已改变
		return
	
	# 重置第二段伤害计数
	phase2_current_hit = 0
	
	# 计算鼠标方向
	var mouse_position = get_global_mouse_position()
	var direction = (mouse_position - global_position).normalized()
	var target_angle = direction.angle() + PI / 2
	
	# 取消之前的Tween
	if swing_tween:
		swing_tween.kill()
	
	# 剑花攻击：快速旋转2圈（720度）
	sword_area.rotation = target_angle
	
	swing_tween = create_tween()
	swing_tween.set_ease(Tween.EASE_IN_OUT)
	swing_tween.set_trans(Tween.TRANS_SINE)
	# 从当前位置旋转2圈（4*PI）回到目标角度
	swing_tween.tween_property(sword_area, "rotation", target_angle + PI * 4, flower_attack_duration)
	swing_tween.tween_callback(finish_phase2)
	
	# 在动画期间多次触发伤害
	trigger_phase2_damage_sequence()

# 触发第二段多次伤害序列
func trigger_phase2_damage_sequence() -> void:
	if attack_state != 2 or phase2_current_hit >= phase2_hit_count:
		return
	
	# 清空已受伤敌人列表（每次伤害是独立的）
	hit_enemies_phase2.clear()
	
	# 使用射线检测攻击敌人
	var mouse_position = get_global_mouse_position()
	perform_raycast_attack(mouse_position)
	
	# 增加伤害计数
	phase2_current_hit += 1
	
	# 如果还有剩余伤害次数，延迟后继续触发
	if phase2_current_hit < phase2_hit_count and attack_state == 2:
		var delay = flower_attack_duration / phase2_hit_count
		var timer = get_tree().create_timer(delay)
		timer.timeout.connect(trigger_phase2_damage_sequence)

# 执行射线攻击（检测射线路径上的所有敌人，无距离限制）
func perform_raycast_attack(target_position: Vector2) -> void:
	# 获取所有敌人节点
	var enemies = get_tree().get_nodes_in_group("enemies")
	var ray_start = global_position
	var direction = (target_position - global_position).normalized()
	
	# 射线长度（设置一个很大的值以实现无距离限制）
	var max_ray_length = 10000.0
	var ray_end = ray_start + direction * max_ray_length
	
	# 对每个敌人进行检查
	for enemy in enemies:
		var enemy_area = enemy as Area2D
		if not enemy_area:
			continue
		
		# 检查敌人是否已在此次攻击中受伤
		if enemy_area in hit_enemies_phase2:
			continue
		
		# 计算敌人位置
		var enemy_pos = enemy_area.global_position
		
		# 计算点到直线的距离（敌人到射线的距离）
		var to_enemy = enemy_pos - ray_start
		var projection_length = to_enemy.dot(direction)
		
		# 如果敌人在射线后方（投影为负），跳过
		if projection_length < 0:
			continue
		
		# 计算敌人在射线上的投影点
		var projection_point = ray_start + direction * projection_length
		
		# 计算敌人到射线的垂直距离
		var distance_to_ray = (enemy_pos - projection_point).length()
		
		# 如果敌人在射线路径上（距离小于容差值，例如50像素）
		var hit_tolerance = 50.0
		if distance_to_ray <= hit_tolerance:
			# 执行射线检测，确保路径上没有阻挡物
			var space_state = get_world_2d().direct_space_state
			var query = PhysicsRayQueryParameters2D.create(ray_start, enemy_pos)
			# 排除玩家自身
			query.exclude = [self]
			
			var result = space_state.intersect_ray(query)
			
			# 如果没有碰撞，或者碰撞的就是这个敌人，造成伤害
			if not result or result.get("collider") == enemy_area:
				hit_enemies_phase2.append(enemy_area)
				if enemy_area.has_method("take_damage"):
					enemy_area.take_damage(sword_damage)

# 完成第二段攻击
func finish_phase2() -> void:
	if sword_area:
		sword_area.monitoring = false
	attack_state = 0
	phase1_press_timestamp_ms = 0
	phase1_had_release = false
	
	# 清空已受伤敌人列表
	hit_enemies_phase1.clear()
	hit_enemies_phase2.clear()

# 剑碰撞到敌人时的回调
func _on_sword_area_entered(area: Area2D) -> void:
	# 检查碰撞的对象是否为敌人（通过组名判断）
	if area.is_in_group("enemies"):
		# 根据攻击阶段判断是否已经造成过伤害
		var already_hit = false
		if attack_state == 1:
			if area in hit_enemies_phase1:
				already_hit = true
			else:
				hit_enemies_phase1.append(area)
		elif attack_state == 2:
			if area in hit_enemies_phase2:
				already_hit = true
			else:
				hit_enemies_phase2.append(area)
		
		# 如果还没有造成过伤害，则造成伤害
		if not already_hit and area.has_method("take_damage"):
			area.take_damage(sword_damage)

# ========== 血量相关方法 ==========

# 受到伤害方法
func take_damage(damage_amount: float) -> void:
	# 如果已经游戏结束或处于无敌状态，不受伤害
	if is_game_over or _is_currently_invincible():
		return
	
	# 减少血量
	current_health -= damage_amount
	current_health = max(0, current_health)  # 确保血量不为负数
	
	# 发送血量变化信号
	emit_signal("health_changed", current_health, max_health)
	
	print("玩家受到伤害: ", damage_amount, "点，剩余血量: ", current_health, "/", max_health)
	
	# 检查是否死亡
	if current_health <= 0:
		on_death()
	else:
		# 进入无敌状态
		start_invincibility()

# 开始无敌状态
func start_invincibility() -> void:
	_set_hurt_invincible(true)
	
	# 创建计时器结束无敌状态
	var timer = get_tree().create_timer(invincibility_duration)
	timer.timeout.connect(end_invincibility)

# 结束无敌状态
func end_invincibility() -> void:
	_set_hurt_invincible(false)

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
	# 优先展示受伤无敌，其次闪避无敌
	if _hurt_invincible:
		animator.modulate.a = 0.5
	elif _dodge_invincible:
		animator.modulate.a = dodge_alpha
	else:
		animator.modulate.a = 1.0

# 回复血量方法
func heal(heal_amount: float) -> void:
	if is_game_over:
		return
	
	current_health += heal_amount
	current_health = min(current_health, max_health)  # 不超过最大血量
	
	# 发送血量变化信号
	emit_signal("health_changed", current_health, max_health)
	
	print("玩家回复血量: ", heal_amount, "点，当前血量: ", current_health, "/", max_health)

# 获取当前血量
func get_current_health() -> float:
	return current_health

# 获取最大血量
func get_max_health() -> float:
	return max_health

# 死亡处理
func on_death() -> void:
	print("玩家死亡")
	emit_signal("player_died")
	game_over()

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
