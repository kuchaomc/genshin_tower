extends BaseCharacter
class_name KamisatoAyakaCharacter

## 神里绫华角色（Kamisato Ayaka）
## 实现两段攻击：第一段位移挥剑，第二段原地剑花

# ========== 普攻特效（第一段刀光） ==========
@export var sword_tip: Node2D
@export var phase1_trail_enabled: bool = true
@export var phase1_trail_width: float = 16.0
@export var phase1_trail_max_points: int = 12
@export var phase1_trail_min_distance: float = 6.0
@export var phase1_trail_fade_time: float = 0.12
@export var phase1_trail_start_color: Color = Color(0.75, 0.92, 1.0, 0.9)
@export var phase1_trail_end_color: Color = Color(0.75, 0.92, 1.0, 0.0)
var _phase1_trail: SwordTrail

# ========== 攻击属性 ==========
@export var sword_area: Area2D
## 普攻伤害倍率（基于攻击力计算）
@export var normal_attack_multiplier: float = 1.0
## 第二段攻击伤害倍率
@export var phase2_attack_multiplier: float = 0.8
@export var swing_duration: float = 0.3
@export var flower_attack_duration: float = 0.4
@export var dash_distance: float = 40.0
@export var swing_angle: float = PI * 1.2  # 约216度
@export var phase2_hit_count: int = 3
## 兼容旧版：固定伤害值（当属性系统不可用时使用）
@export var sword_damage: float = 25.0

# ========== 攻击状态 ==========
var attack_state: int = 0  # 0=无攻击, 1=第一段, 2=第二段
var phase2_current_hit: int = 0
var swing_tween: Tween
var position_tween: Tween
var target_position: Vector2
var hit_enemies_phase1: Array[Node2D] = []
var hit_enemies_phase2: Array[Node2D] = []
var original_position: Vector2
# 重击动画状态管理
var _charged_effect_should_visible: bool = false  # 重击动画是否应该显示
var _charged_effect_hide_timer: float = -1.0  # 隐藏动画的倒计时（秒），-1表示不隐藏

# ========== 重击属性 ==========
@export var charged_effect: AnimatedSprite2D  # 重击特效动画
@export var charged_area: Area2D  # 重击范围伤害区域
@export var charged_radius: float = 100.0  # 重击范围半径
@export var charged_hit_count: int = 3  # 重击伤害次数
@export var charged_hit_interval: float = 0.15  # 每次伤害的间隔（秒）

# ========== E技能属性 ==========
@export var skill_area: Area2D  # 技能范围伤害区域
@export var skill_effect: AnimatedSprite2D  # 技能特效动画
## E技能伤害倍率（基于攻击力计算）
@export var skill_damage_multiplier: float = 2.0
@export var skill_radius: float = 150.0  # 技能范围半径
@export var skill_cooldown: float = 10.0  # 技能冷却时间（秒）
var skill_next_ready_ms: int = 0  # 技能下次可用时间（毫秒）
var skill_hit_enemies: Array[Node2D] = []  # 本次技能已命中的敌人
## 兼容旧版：固定伤害值
@export var skill_damage: float = 50.0

# 技能冷却时间变化信号（用于UI更新）
signal skill_cooldown_changed(remaining_time: float, cooldown_time: float)

# ========== 大招（Q技能）属性 ==========
@export var burst_scene: PackedScene  # 大招特效投射物场景
## 大招伤害倍率（基于攻击力计算）
@export var burst_damage_multiplier: float = 4.0
@export var burst_speed: float = 300.0  # 大招投射物速度
@export var burst_max_energy: float = 100.0  # 大招最大充能值
var burst_current_energy: float = 0.0  # 当前充能值
@export var energy_per_hit: float = 10.0  # 每次命中敌人获得的充能值
## 兼容旧版：固定伤害值
@export var burst_damage: float = 100.0

# 大招充能进度变化信号（用于UI更新）
signal burst_energy_changed(current_energy: float, max_energy: float)

func _ready() -> void:
	super._ready()
	
	# 如果没有手动分配剑区域，则自动查找
	if sword_area == null:
		sword_area = get_node_or_null("SwordArea") as Area2D
	
	if sword_area:
		# 约定：第2层=敌人(Enemies)。剑的 Area2D 只需要检测敌人层即可。
		sword_area.collision_mask = 2
		sword_area.area_entered.connect(_on_sword_area_entered)
		sword_area.body_entered.connect(_on_sword_body_entered)
		sword_area.monitoring = false

	# 剑尖采样点（用于刀光轨迹）
	if sword_tip == null:
		sword_tip = get_node_or_null("SwordArea/SwordTip") as Node2D
	
	# 初始化技能区域和特效
	if skill_area == null:
		skill_area = get_node_or_null("SkillArea") as Area2D
	
	if skill_area:
		# 约定：第2层=敌人(Enemies)。技能范围 Area2D 只需要检测敌人层即可。
		skill_area.collision_mask = 2
		skill_area.area_entered.connect(_on_skill_area_entered)
		skill_area.body_entered.connect(_on_skill_body_entered)
		skill_area.monitoring = false
		# 设置技能范围
		var collision_shape = skill_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision_shape and collision_shape.shape is CircleShape2D:
			(collision_shape.shape as CircleShape2D).radius = skill_radius
	
	if skill_effect == null:
		skill_effect = get_node_or_null("SkillEffect") as AnimatedSprite2D
	
	if skill_effect:
		skill_effect.visible = false
	
	# 初始化重击区域和特效
	if charged_area == null:
		charged_area = get_node_or_null("ChargedArea") as Area2D
	
	if charged_area:
		# 约定：第2层=敌人(Enemies)。重击范围 Area2D 只需要检测敌人层即可。
		charged_area.collision_mask = 2
		charged_area.area_entered.connect(_on_charged_area_entered)
		charged_area.body_entered.connect(_on_charged_body_entered)
		charged_area.monitoring = false
		# 设置重击范围
		var collision_shape = charged_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision_shape and collision_shape.shape is CircleShape2D:
			(collision_shape.shape as CircleShape2D).radius = charged_radius
	
	if charged_effect == null:
		charged_effect = get_node_or_null("ChargedEffect") as AnimatedSprite2D
	
	if charged_effect:
		charged_effect.visible = false

func _physics_process(delta: float) -> void:
	if not is_game_over:
		# 处理攻击输入
		handle_attack_input()
		
		# 处理E键技能输入
		handle_skill_input()
		
		# 处理Q键大招输入
		handle_burst_input()
		
		# 更新技能冷却时间显示
		_update_skill_cooldown_display()
		
		# 更新大招充能显示
		_update_burst_energy_display()
		
		# 更新重击动画状态
		_update_charged_effect()
		
		# 攻击时强制检查覆盖，减少漏判
		if attack_state == 1 and sword_area and sword_area.monitoring:
			_force_check_sword_overlaps()
		
		# 只在非攻击状态下更新剑的朝向
		if attack_state == 0:
			update_sword_direction()
	
	super._physics_process(delta)

func handle_movement() -> void:
	# 攻击状态下阻止移动
	if attack_state == 0:
		super.handle_movement()
	else:
		velocity = Vector2.ZERO

func can_move() -> bool:
	return attack_state == 0

func can_dodge() -> bool:
	# 攻击期间禁止闪避，避免与攻击状态/判定冲突；需要的话以后可放开
	return attack_state == 0 and super.can_dodge()

## 更新剑的朝向（朝向鼠标）
func update_sword_direction() -> void:
	if not sword_area or attack_state != 0:
		return
	
	var sword_pivot_global = sword_area.global_position
	var mouse_position = get_global_mouse_position()
	var direction = (mouse_position - sword_pivot_global).normalized()
	sword_area.rotation = direction.angle() + PI / 2

## 执行攻击
func perform_attack() -> void:
	if not sword_area or attack_state != 0:
		return
	
	var mouse_position = get_global_mouse_position()
	var mouse_direction = mouse_position - global_position
	if mouse_direction == Vector2.ZERO:
		mouse_direction = Vector2.RIGHT  # 鼠标重合时使用默认方向，避免零向量
	var input_direction = mouse_direction.normalized()
	
	target_position = global_position  # 取消位移，保持原地攻击
	original_position = global_position
	
	hit_enemies_phase1.clear()
	hit_enemies_phase2.clear()
	
	attack_state = 1
	start_phase1_attack(mouse_position)

## 第一段攻击：向鼠标方向位移并挥剑
func start_phase1_attack(mouse_target: Vector2) -> void:
	sword_area.monitoring = true
	sword_area.monitorable = true
	_start_phase1_trail()
	
	var direction = (mouse_target - global_position).normalized()
	var base_angle = direction.angle() + PI / 2
	
	if swing_tween:
		swing_tween.kill()
	if position_tween:
		position_tween.kill()
	
	sword_area.rotation = base_angle - swing_angle / 2
	
	swing_tween = create_tween()
	swing_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	swing_tween.set_ease(Tween.EASE_OUT)
	swing_tween.set_trans(Tween.TRANS_BACK)
	swing_tween.tween_property(sword_area, "rotation", base_angle + swing_angle / 2, swing_duration)
	swing_tween.tween_callback(finish_phase1)

## 完成第一段攻击
func finish_phase1() -> void:
	_stop_phase1_trail()
	if sword_area:
		sword_area.monitoring = false
	
	if Input.is_action_pressed("mouse1"):
		attack_state = 2
		start_phase2_attack()
	else:
		finish_attack()

## 结束攻击
func finish_attack() -> void:
	_stop_phase1_trail()
	if sword_area:
		sword_area.monitoring = false
	
	# 如果重击动画正在显示，标记为应该隐藏
	# 实际隐藏会在_update_charged_effect()中处理
	if attack_state == 2:
		_charged_effect_should_visible = false
		_charged_effect_hide_timer = -1.0
		# 如果游戏未暂停，立即隐藏
		if not get_tree().paused and charged_effect:
			charged_effect.visible = false
			charged_effect.stop()
	
	attack_state = 0
	
	hit_enemies_phase1.clear()
	hit_enemies_phase2.clear()

## 第二段攻击：向准星位置生成剑花
func start_phase2_attack() -> void:
	if attack_state != 2:
		return
	
	phase2_current_hit = 0
	
	# 获取准星位置（鼠标位置）
	var mouse_position = get_global_mouse_position()
	
	# 在准星位置生成重击特效
	if charged_effect:
		_charged_effect_should_visible = true
		charged_effect.visible = true
		charged_effect.global_position = mouse_position
		if charged_effect.sprite_frames:
			charged_effect.play("default")
			# 不再依赖动画完成信号，而是使用基于时间的隐藏逻辑
			# 动画会循环播放，直到攻击状态改变
		else:
			# 如果没有sprite_frames，设置隐藏倒计时
			_charged_effect_hide_timer = 0.7
	
	# 设置重击伤害区域位置
	if charged_area:
		charged_area.global_position = mouse_position
	
	# 开始伤害序列
	trigger_phase2_damage_sequence()

## 触发第二段多次伤害序列
func trigger_phase2_damage_sequence() -> void:
	if attack_state != 2 or phase2_current_hit >= charged_hit_count:
		return
	
	# 清空本次伤害的已命中敌人列表
	hit_enemies_phase2.clear()
	
	# 获取准星位置
	var mouse_position = get_global_mouse_position()
	
	# 启用伤害区域检测
	if charged_area:
		charged_area.monitoring = true
		charged_area.global_position = mouse_position
		# 强制检查范围内的敌人
		_force_check_charged_overlaps()
		# 短暂启用后关闭（单次伤害检测）
		var timer = get_tree().create_timer(0.1)
		timer.timeout.connect(_on_charged_damage_finished)
	
	phase2_current_hit += 1
	
	# 如果还有剩余伤害次数，继续触发
	if phase2_current_hit < charged_hit_count and attack_state == 2:
		var timer = get_tree().create_timer(charged_hit_interval)
		timer.timeout.connect(trigger_phase2_damage_sequence)
	else:
		# 所有伤害完成，等待特效播放完成后结束
		var finish_timer = get_tree().create_timer(0.5)
		finish_timer.timeout.connect(finish_phase2)

## 重击伤害检测完成
func _on_charged_damage_finished() -> void:
	if charged_area:
		charged_area.monitoring = false

## 更新重击动画状态（每帧调用）
func _update_charged_effect() -> void:
	if not charged_effect:
		return
	
	# 如果游戏暂停，保持当前状态不变（不执行任何操作）
	# 这样动画会保持当前帧和可见状态
	if get_tree().paused:
		return
	
	# 根据攻击状态和倒计时决定是否显示
	var should_show = _charged_effect_should_visible and attack_state == 2
	
	# 如果有隐藏倒计时，更新它
	if _charged_effect_hide_timer > 0:
		_charged_effect_hide_timer -= get_physics_process_delta_time()
		if _charged_effect_hide_timer <= 0:
			should_show = false
	
	# 更新可见性
	if should_show:
		# 应该显示：确保可见并播放
		if not charged_effect.visible:
			charged_effect.visible = true
		if not charged_effect.is_playing():
			charged_effect.play("default")
	else:
		# 应该隐藏：隐藏并停止
		if charged_effect.visible:
			charged_effect.visible = false
			charged_effect.stop()
		_charged_effect_should_visible = false
		_charged_effect_hide_timer = -1.0

## 获取重击特效（供暂停菜单使用）
func get_charged_effect() -> AnimatedSprite2D:
	return charged_effect

## 重击区域碰撞回调
func _on_charged_area_entered(area: Area2D) -> void:
	_handle_charged_hit(area)

func _on_charged_body_entered(body: Node2D) -> void:
	_handle_charged_hit(body)

func _handle_charged_hit(target: Node2D) -> void:
	if not target or not target.is_in_group("enemies"):
		return
	
	# 检查是否已经命中过（本次伤害序列中）
	if target in hit_enemies_phase2:
		return
	
	hit_enemies_phase2.append(target)
	
	# 造成伤害
	if target.has_method("take_damage"):
		# 使用统一伤害计算系统
		var damage_result = deal_damage_to(target, phase2_attack_multiplier)
		var damage = damage_result[0]
		var is_crit = damage_result[1]
		
		if is_crit:
			print("重击 暴击！伤害: ", damage)
		else:
			print("重击命中敌人，造成伤害: ", damage)
		
		# 重击命中敌人时充能大招
		_add_burst_energy(energy_per_hit)

## 强制检查重击范围内的敌人
func _force_check_charged_overlaps() -> void:
	if not charged_area:
		return
	
	# 获取范围内的所有敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		var enemy_body = enemy as Node2D
		if not enemy_body:
			continue
		
		# 计算距离
		var distance = (enemy_body.global_position - charged_area.global_position).length()
		if distance <= charged_radius:
			# 在范围内，触发碰撞
			_on_charged_body_entered(enemy_body)

## 完成第二段攻击
func finish_phase2() -> void:
	if charged_area:
		charged_area.monitoring = false
	
	# 标记重击动画应该隐藏
	_charged_effect_should_visible = false
	_charged_effect_hide_timer = -1.0
	
	# 如果游戏未暂停，立即隐藏动画
	# 如果游戏已暂停，动画会在恢复时通过_update_charged_effect()隐藏
	if not get_tree().paused:
		if charged_effect:
			charged_effect.visible = false
			charged_effect.stop()
	
	attack_state = 0
	
	hit_enemies_phase1.clear()
	hit_enemies_phase2.clear()

func _start_phase1_trail() -> void:
	if not phase1_trail_enabled:
		return
	if not is_instance_valid(sword_tip):
		return
	# 如果上一条还没销毁，先清理
	_stop_phase1_trail(true)
	_phase1_trail = SwordTrail.new()
	_phase1_trail.width = phase1_trail_width
	_phase1_trail.max_points = phase1_trail_max_points
	_phase1_trail.min_distance = phase1_trail_min_distance
	_phase1_trail.fade_time = phase1_trail_fade_time
	_phase1_trail.start_color = phase1_trail_start_color
	_phase1_trail.end_color = phase1_trail_end_color
	_phase1_trail.z = 60
	get_parent().add_child(_phase1_trail)
	_phase1_trail.setup(sword_tip)

func _stop_phase1_trail(immediate: bool = false) -> void:
	if not is_instance_valid(_phase1_trail):
		_phase1_trail = null
		return
	if immediate:
		_phase1_trail.queue_free()
	else:
		_phase1_trail.stop()
	_phase1_trail = null

## 剑碰撞到敌人时的回调
func _on_sword_area_entered(area: Area2D) -> void:
	_handle_sword_hit(area)

func _on_sword_body_entered(body: Node2D) -> void:
	_handle_sword_hit(body)

func _handle_sword_hit(target: Node2D) -> void:
	if not target or not target.is_in_group("enemies"):
		return
	var already_hit = false
	if attack_state == 1:
		if target in hit_enemies_phase1:
			already_hit = true
		else:
			hit_enemies_phase1.append(target)
	elif attack_state == 2:
		if target in hit_enemies_phase2:
			already_hit = true
		else:
			hit_enemies_phase2.append(target)
	
	if not already_hit and target.has_method("take_damage"):
		# 使用统一伤害计算系统
		var damage_result = deal_damage_to(target, normal_attack_multiplier)
		var damage = damage_result[0]
		var is_crit = damage_result[1]
		
		if is_crit:
			print("普攻 暴击！伤害: ", damage)
		
		# 普攻命中敌人时充能大招
		_add_burst_energy(energy_per_hit)

## 主动检查覆盖，避免物理帧遗漏
func _force_check_sword_overlaps() -> void:
	if not sword_area:
		return
	for area in sword_area.get_overlapping_areas():
		_on_sword_area_entered(area)
	for body in sword_area.get_overlapping_bodies():
		_on_sword_body_entered(body)

# ========== E技能相关方法 ==========

## 处理E键技能输入
var _last_e_pressed: bool = false

func handle_skill_input() -> void:
	# 检测E键按下（使用is_physical_key_pressed并检查状态变化）
	var e_pressed = Input.is_physical_key_pressed(KEY_E)
	if (Input.is_action_just_pressed("ui_select") or (e_pressed and not _last_e_pressed)):
		if _is_skill_ready():
			use_skill()
	_last_e_pressed = e_pressed

## 检查技能是否可用
func _is_skill_ready() -> bool:
	return Time.get_ticks_msec() >= skill_next_ready_ms

## 使用E技能：围绕角色造成范围伤害
func use_skill() -> void:
	if not _is_skill_ready():
		return
	
	# 设置冷却时间
	skill_next_ready_ms = Time.get_ticks_msec() + int(skill_cooldown * 1000.0)
	
	# 清空已命中敌人列表
	skill_hit_enemies.clear()
	
	# 启用技能区域检测
	if skill_area:
		skill_area.monitoring = true
		skill_area.global_position = global_position
		# 强制检查范围内的敌人
		_force_check_skill_overlaps()
		# 短暂启用后关闭（单段伤害）
		var timer = get_tree().create_timer(0.1)
		timer.timeout.connect(_on_skill_damage_finished)
	
	# 播放技能特效
	if skill_effect:
		skill_effect.visible = true
		skill_effect.global_position = global_position
		if skill_effect.sprite_frames:
			skill_effect.play("default")
			# 监听动画完成信号
			if not skill_effect.animation_finished.is_connected(_on_skill_effect_finished):
				skill_effect.animation_finished.connect(_on_skill_effect_finished)
		else:
			# 如果没有sprite_frames，使用简单的定时器
			var hide_timer = get_tree().create_timer(0.5)
			hide_timer.timeout.connect(_on_skill_effect_finished)
	
	print("使用E技能：范围伤害")

## 技能伤害检测完成
func _on_skill_damage_finished() -> void:
	if skill_area:
		skill_area.monitoring = false

## 技能特效播放完成
func _on_skill_effect_finished() -> void:
	if skill_effect:
		skill_effect.visible = false
		skill_effect.stop()
		# 断开信号连接（避免重复连接）
		if skill_effect.animation_finished.is_connected(_on_skill_effect_finished):
			skill_effect.animation_finished.disconnect(_on_skill_effect_finished)

## 技能区域碰撞回调
func _on_skill_area_entered(area: Area2D) -> void:
	_handle_skill_hit(area)

func _on_skill_body_entered(body: Node2D) -> void:
	_handle_skill_hit(body)

func _handle_skill_hit(target: Node2D) -> void:
	if not target or not target.is_in_group("enemies"):
		return
	
	# 检查是否已经命中过
	if target in skill_hit_enemies:
		return
	
	skill_hit_enemies.append(target)
	
	# 造成伤害
	if target.has_method("take_damage"):
		# 使用统一伤害计算系统
		var damage_result = deal_damage_to(target, skill_damage_multiplier)
		var damage = damage_result[0]
		var is_crit = damage_result[1]
		
		if is_crit:
			print("E技能 暴击！伤害: ", damage)
		else:
			print("E技能命中敌人，造成伤害: ", damage)
		
		# E技能命中敌人时充能大招
		_add_burst_energy(energy_per_hit)

## 强制检查技能范围内的敌人
func _force_check_skill_overlaps() -> void:
	if not skill_area:
		return
	
	# 获取范围内的所有敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		var enemy_body = enemy as Node2D
		if not enemy_body:
			continue
		
		# 计算距离
		var distance = (enemy_body.global_position - global_position).length()
		if distance <= skill_radius:
			# 在范围内，触发碰撞
			_on_skill_body_entered(enemy_body)

## 更新技能冷却时间显示
func _update_skill_cooldown_display() -> void:
	var current_time_ms = Time.get_ticks_msec()
	if current_time_ms < skill_next_ready_ms:
		var remaining_time = (skill_next_ready_ms - current_time_ms) / 1000.0
		emit_signal("skill_cooldown_changed", remaining_time, skill_cooldown)
	else:
		emit_signal("skill_cooldown_changed", 0.0, skill_cooldown)

# ========== 大招（Q技能）相关方法 ==========

## 处理Q键大招输入
var _last_q_pressed: bool = false

func handle_burst_input() -> void:
	# 检测Q键按下
	var q_pressed = Input.is_physical_key_pressed(KEY_Q)
	if q_pressed and not _last_q_pressed:
		if _is_burst_ready():
			use_burst()
	_last_q_pressed = q_pressed

## 检查大招是否可用
func _is_burst_ready() -> bool:
	return burst_current_energy >= burst_max_energy

## 使用大招：向鼠标方向发射特效
func use_burst() -> void:
	if not _is_burst_ready():
		return
	
	# 消耗所有充能
	burst_current_energy = 0.0
	_update_burst_energy_display()
	
	# 如果没有加载场景，尝试加载
	if burst_scene == null:
		burst_scene = load("res://scenes/projectiles/burst_projectile.tscn") as PackedScene
	
	if not burst_scene:
		print("错误：大招投射物场景未加载")
		return
	
	# 创建大招投射物实例
	var burst_instance = burst_scene.instantiate()
	if not burst_instance:
		print("错误：无法实例化大招投射物")
		return
	
	# 设置投射物位置和方向
	var mouse_position = get_global_mouse_position()
	var direction = (mouse_position - global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT  # 默认向右
	
	burst_instance.global_position = global_position
	burst_instance.direction = direction
	burst_instance.speed = burst_speed
	
	# 使用统一伤害计算系统计算大招伤害
	if current_stats:
		var damage_result = current_stats.calculate_damage(burst_damage_multiplier, 0.0, false, false)
		burst_instance.damage = damage_result[0]
		burst_instance.is_crit = damage_result[1]
		# 应用升级加成
		if RunManager:
			var damage_upgrade = RunManager.get_upgrade_level("damage")
			burst_instance.damage *= (1.0 + damage_upgrade * 0.1)
	else:
		burst_instance.damage = burst_damage
		burst_instance.is_crit = false
	
	# 添加到场景树（添加到当前节点的父节点或根节点）
	var parent = get_parent()
	if parent:
		parent.add_child(burst_instance)
	else:
		get_tree().root.add_child(burst_instance)
	
	print("使用大招：向鼠标方向发射")

## 增加大招充能
func _add_burst_energy(amount: float) -> void:
	if burst_current_energy < burst_max_energy:
		burst_current_energy = min(burst_current_energy + amount, burst_max_energy)
		_update_burst_energy_display()

## 更新大招充能显示
func _update_burst_energy_display() -> void:
	emit_signal("burst_energy_changed", burst_current_energy, burst_max_energy)
