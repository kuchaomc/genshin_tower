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
@export var sword_damage: float = 25.0
@export var swing_duration: float = 0.3
@export var flower_attack_duration: float = 0.4
@export var dash_distance: float = 40.0
@export var swing_angle: float = PI * 1.2  # 约216度
@export var phase2_hit_count: int = 3

# ========== 攻击状态 ==========
var attack_state: int = 0  # 0=无攻击, 1=第一段, 2=第二段
var phase2_current_hit: int = 0
var swing_tween: Tween
var position_tween: Tween
var target_position: Vector2
var hit_enemies_phase1: Array[Area2D] = []
var hit_enemies_phase2: Array[Area2D] = []
var original_position: Vector2

# ========== E技能属性 ==========
@export var skill_area: Area2D  # 技能范围伤害区域
@export var skill_effect: AnimatedSprite2D  # 技能特效动画
@export var skill_damage: float = 50.0  # 技能伤害
@export var skill_radius: float = 150.0  # 技能范围半径
@export var skill_cooldown: float = 10.0  # 技能冷却时间（秒）
var skill_next_ready_ms: int = 0  # 技能下次可用时间（毫秒）
var skill_hit_enemies: Array[Area2D] = []  # 本次技能已命中的敌人

# 技能冷却时间变化信号（用于UI更新）
signal skill_cooldown_changed(remaining_time: float, cooldown_time: float)

# ========== 大招（Q技能）属性 ==========
@export var burst_scene: PackedScene  # 大招特效投射物场景
@export var burst_damage: float = 100.0  # 大招伤害
@export var burst_speed: float = 300.0  # 大招投射物速度
@export var burst_max_energy: float = 100.0  # 大招最大充能值
var burst_current_energy: float = 0.0  # 当前充能值
@export var energy_per_hit: float = 10.0  # 每次命中敌人获得的充能值

# 大招充能进度变化信号（用于UI更新）
signal burst_energy_changed(current_energy: float, max_energy: float)

func _ready() -> void:
	super._ready()
	
	# 如果没有手动分配剑区域，则自动查找
	if sword_area == null:
		sword_area = get_node_or_null("SwordArea") as Area2D
	
	if sword_area:
		sword_area.area_entered.connect(_on_sword_area_entered)
		sword_area.monitoring = false

	# 剑尖采样点（用于刀光轨迹）
	if sword_tip == null:
		sword_tip = get_node_or_null("SwordArea/SwordTip") as Node2D
	
	# 初始化技能区域和特效
	if skill_area == null:
		skill_area = get_node_or_null("SkillArea") as Area2D
	
	if skill_area:
		skill_area.area_entered.connect(_on_skill_area_entered)
		skill_area.monitoring = false
		# 设置技能范围
		var collision_shape = skill_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision_shape and collision_shape.shape is CircleShape2D:
			(collision_shape.shape as CircleShape2D).radius = skill_radius
	
	if skill_effect == null:
		skill_effect = get_node_or_null("SkillEffect") as AnimatedSprite2D
	
	if skill_effect:
		skill_effect.visible = false

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
	attack_state = 0
	
	hit_enemies_phase1.clear()
	hit_enemies_phase2.clear()

## 第二段攻击：原地剑花攻击
func start_phase2_attack() -> void:
	if attack_state != 2:
		return
	
	phase2_current_hit = 0
	
	var mouse_position = get_global_mouse_position()
	var direction = (mouse_position - global_position).normalized()
	var target_angle = direction.angle() + PI / 2
	
	if swing_tween:
		swing_tween.kill()
	
	sword_area.rotation = target_angle
	
	swing_tween = create_tween()
	swing_tween.set_ease(Tween.EASE_IN_OUT)
	swing_tween.set_trans(Tween.TRANS_SINE)
	swing_tween.tween_property(sword_area, "rotation", target_angle + PI * 4, flower_attack_duration)
	swing_tween.tween_callback(finish_phase2)
	
	trigger_phase2_damage_sequence()

## 触发第二段多次伤害序列
func trigger_phase2_damage_sequence() -> void:
	if attack_state != 2 or phase2_current_hit >= phase2_hit_count:
		return
	
	hit_enemies_phase2.clear()
	
	var mouse_position = get_global_mouse_position()
	perform_raycast_attack(mouse_position)
	
	phase2_current_hit += 1
	
	if phase2_current_hit < phase2_hit_count and attack_state == 2:
		var delay = flower_attack_duration / phase2_hit_count
		var timer = get_tree().create_timer(delay)
		timer.timeout.connect(trigger_phase2_damage_sequence)

## 执行射线攻击
func perform_raycast_attack(attack_target: Vector2) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var ray_start = global_position
	var direction = (attack_target - global_position).normalized()
	
	for enemy in enemies:
		var enemy_area = enemy as Area2D
		if not enemy_area:
			continue
		
		if enemy_area in hit_enemies_phase2:
			continue
		
		var enemy_pos = enemy_area.global_position
		var to_enemy = enemy_pos - ray_start
		var projection_length = to_enemy.dot(direction)
		
		if projection_length < 0:
			continue
		
		var projection_point = ray_start + direction * projection_length
		var distance_to_ray = (enemy_pos - projection_point).length()
		
		var hit_tolerance = 50.0
		if distance_to_ray <= hit_tolerance:
			var space_state = get_world_2d().direct_space_state
			var query = PhysicsRayQueryParameters2D.create(ray_start, enemy_pos)
			query.exclude = [self]
			
			var result = space_state.intersect_ray(query)
			
			if not result or result.get("collider") == enemy_area:
				hit_enemies_phase2.append(enemy_area)
				if enemy_area.has_method("take_damage"):
					var damage = sword_damage
					# 应用升级加成
					if RunManager:
						var damage_upgrade = RunManager.get_upgrade_level("damage")
						damage *= (1.0 + damage_upgrade * 0.1)  # 每级+10%伤害
					var knockback_dir = (enemy_pos - global_position).normalized()
					enemy_area.take_damage(damage, knockback_dir * knockback_force)
					if RunManager:
						RunManager.record_damage_dealt(damage)
					
					# 第二段攻击命中敌人时充能大招
					_add_burst_energy(energy_per_hit)

## 完成第二段攻击
func finish_phase2() -> void:
	if sword_area:
		sword_area.monitoring = false
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
	if area.is_in_group("enemies"):
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
		
		if not already_hit and area.has_method("take_damage"):
			var damage = sword_damage
			# 应用升级加成
			if RunManager:
				var damage_upgrade = RunManager.get_upgrade_level("damage")
				damage *= (1.0 + damage_upgrade * 0.1)
			var knockback_dir = (area.global_position - global_position).normalized()
			area.take_damage(damage, knockback_dir * knockback_force)
			if RunManager:
				RunManager.record_damage_dealt(damage)
			
			# 普攻命中敌人时充能大招
			_add_burst_energy(energy_per_hit)

## 主动检查覆盖，避免物理帧遗漏
func _force_check_sword_overlaps() -> void:
	if not sword_area:
		return
	for area in sword_area.get_overlapping_areas():
		_on_sword_area_entered(area)

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
	if area.is_in_group("enemies"):
		# 检查是否已经命中过
		if area in skill_hit_enemies:
			return
		
		skill_hit_enemies.append(area)
		
		# 造成伤害
		if area.has_method("take_damage"):
			var damage = skill_damage
			# 应用升级加成
			if RunManager:
				var damage_upgrade = RunManager.get_upgrade_level("damage")
				damage *= (1.0 + damage_upgrade * 0.1)
			var knockback_dir = (area.global_position - global_position).normalized()
			area.take_damage(damage, knockback_dir * knockback_force)
			if RunManager:
				RunManager.record_damage_dealt(damage)
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
		var enemy_area = enemy as Area2D
		if not enemy_area:
			continue
		
		# 计算距离
		var distance = (enemy_area.global_position - global_position).length()
		if distance <= skill_radius:
			# 在范围内，触发碰撞
			_on_skill_area_entered(enemy_area)

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
		burst_scene = load("res://scenes/burst_projectile.tscn") as PackedScene
	
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
	burst_instance.damage = burst_damage
	burst_instance.speed = burst_speed
	
	# 应用升级加成
	if RunManager:
		var damage_upgrade = RunManager.get_upgrade_level("damage")
		burst_instance.damage *= (1.0 + damage_upgrade * 0.1)
	
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
