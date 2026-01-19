extends BaseCharacter
class_name SwordCharacter

## 剑士角色
## 实现两段攻击：第一段位移挥剑，第二段原地剑花

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

func _ready() -> void:
	super._ready()
	
	# 如果没有手动分配剑区域，则自动查找
	if sword_area == null:
		sword_area = get_node_or_null("SwordArea") as Area2D
	
	if sword_area:
		sword_area.area_entered.connect(_on_sword_area_entered)
		sword_area.monitoring = false

func _physics_process(delta: float) -> void:
	if not is_game_over:
		# 处理攻击输入
		handle_attack_input()
		
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
	if sword_area:
		sword_area.monitoring = false
	
	if Input.is_action_pressed("mouse1"):
		attack_state = 2
		start_phase2_attack()
	else:
		finish_attack()

## 结束攻击
func finish_attack() -> void:
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

## 完成第二段攻击
func finish_phase2() -> void:
	if sword_area:
		sword_area.monitoring = false
	attack_state = 0
	
	hit_enemies_phase1.clear()
	hit_enemies_phase2.clear()

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

## 主动检查覆盖，避免物理帧遗漏
func _force_check_sword_overlaps() -> void:
	if not sword_area:
		return
	for area in sword_area.get_overlapping_areas():
		_on_sword_area_entered(area)
