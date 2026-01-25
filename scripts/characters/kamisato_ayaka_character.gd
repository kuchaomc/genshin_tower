extends BaseCharacter
class_name KamisatoAyakaCharacter

## 神里绫华角色（Kamisato Ayaka）
## 实现两段攻击：第一段位移挥剑，第二段原地剑花

# ========== 普攻特效（第一段刀光） ==========
## 剑尖节点（用于刀光轨迹采样）
@export var sword_tip: Node2D
## 启用第一段刀光特效
@export var phase1_trail_enabled: bool = true
## 刀光轨迹宽度
@export var phase1_trail_width: float = 16.0
## 刀光轨迹最大点数
@export var phase1_trail_max_points: int = 12
## 刀光采样最小距离
@export var phase1_trail_min_distance: float = 6.0
## 刀光淡出时间（秒）
@export var phase1_trail_fade_time: float = 0.12
## 刀光起始颜色
@export var phase1_trail_start_color: Color = Color(0.75, 0.92, 1.0, 0.9)
## 刀光结束颜色
@export var phase1_trail_end_color: Color = Color(0.75, 0.92, 1.0, 0.0)
var _phase1_trail: SwordTrail

# ========== 攻击属性 ==========
## 剑的碰撞检测区域
@export var sword_area: Area2D
## 剑的显示Sprite（用于蓄力发光与呼吸缩放）
var _sword_sprite: Sprite2D
var _sword_sprite_base_scale: Vector2 = Vector2.ONE
## 剑的枢轴偏移位置（相对于角色中心，用于正确的旋转中心）
@export var sword_pivot_offset: Vector2 = Vector2(15, -5)
## 蓄力发光Sprite（运行时创建，叠加Add混合）
var _charged_glow_sprite: Sprite2D
## 蓄力发光颜色（alpha会在运行时动态调整）
@export var charged_glow_color: Color = Color(0.65, 0.92, 1.0, 1.0)
## 蓄力发光最大透明度（0~1）
@export var charged_glow_max_alpha: float = 0.9
## 蓄力发光额外放大倍数（相对剑Sprite的scale）
@export var charged_glow_extra_scale: float = 1.28
## 蓄力呼吸缩放强度（0.05表示最大+5%）
@export var charged_breathe_scale_strength: float = 0.05
## 蓄力呼吸频率（Hz）
@export var charged_breathe_frequency: float = 2.2
## 蓄力颤抖强度倍率（1=使用weapon_shake_amplitude原值；建议0.3~0.7）
@export var charged_shake_strength: float = 0.45
var _charged_ready_last_frame: bool = false
var _charged_ready_pulse_tween: Tween
var _charged_ready_pulse_scale_mul: float = 1.0

var _weapon_glow_shader: Shader
var _weapon_glow_material: ShaderMaterial
var _sword_sprite_original_material: Material
## 普攻伤害倍率（基于攻击力计算）
@export var normal_attack_multiplier: float = 1.0
## 第二段攻击伤害倍率（已弃用，使用 charged_attack_multiplier）
@export var phase2_attack_multiplier: float = 0.8
## 挥剑动画持续时间（秒）
@export var swing_duration: float = 0.3
## 剑花攻击持续时间（秒）
@export var flower_attack_duration: float = 0.4
## 第一段冲刺距离
@export var dash_distance: float = 40.0
## 挥剑角度范围（弧度，约216度）
@export var swing_angle: float = PI * 1.2  # 约216度
## 第二段攻击伤害次数
@export var phase2_hit_count: int = 3
## 固定伤害值（备用，当属性系统不可用时使用）
@export var sword_damage: float = 25.0

# ========== 攻击状态 ==========
## 攻击阶段：0=未攻击, 1=第一段, 2=第二段
var attack_phase: int = 0
## 第二段伤害当前命中次数
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
## 重击特效动画节点
@export var charged_effect: AnimatedSprite2D
## 重击范围伤害检测区域
@export var charged_area: Area2D
## 重击范围半径
@export var charged_radius: float = 100.0
## 重击伤害触发次数
@export var charged_hit_count: int = 3
## 每次伤害间隔时间（秒）
@export var charged_hit_interval: float = 0.15
## 重击伤害倍率（每次75%攻击力）
@export var charged_attack_multiplier: float = 0.75
## 武器颤抖幅度（蓄力时）
@export var weapon_shake_amplitude: float = 3.0
## 武器颤抖频率（Hz）
@export var weapon_shake_frequency: float = 15.0

# ========== E技能属性 ==========
## E技能范围伤害检测区域
@export var skill_area: Area2D
## E技能特效动画节点
@export var skill_effect: AnimatedSprite2D
## E技能伤害倍率（基于攻击力计算）
@export var skill_damage_multiplier: float = 2.0
## E技能范围半径
@export var skill_radius: float = 150.0
## E技能冷却时间（秒）
@export var skill_cooldown: float = 10.0
var skill_next_ready_ms: int = 0  # 技能下次可用时间（毫秒）
var skill_hit_enemies: Array[Node2D] = []  # 本次技能已命中的敌人
## 固定伤害值（备用，当属性系统不可用时使用）
@export var skill_damage: float = 50.0

# 技能冷却时间变化信号（用于UI更新）
signal skill_cooldown_changed(remaining_time: float, cooldown_time: float)

# ========== 大招（Q技能）属性 ==========
## 大招特效投射物场景（PackedScene）
@export var burst_scene: PackedScene = preload("res://scenes/projectiles/burst_projectile.tscn")
## 大招伤害倍率（基于攻击力计算）
@export var burst_damage_multiplier: float = 4.0
## 大招投射物飞行速度
@export var burst_speed: float = 300.0
## 大招最大充能值
@export var burst_max_energy: float = 100.0
var burst_current_energy: float = 0.0  # 当前充能值
## 每次命中敌人获得的充能值
@export var energy_per_hit: float = 10.0
## 固定伤害值（备用，当属性系统不可用时使用）
@export var burst_damage: float = 100.0

# 大招充能进度变化信号（用于UI更新）
signal burst_energy_changed(current_energy: float, max_energy: float)
# 大招释放信号（用于UI播放大招动画等）
signal burst_used(character_id: String)

# E键按下状态追踪
var _last_e_pressed: bool = false
# Q键按下状态追踪
var _last_q_pressed: bool = false

# ========== 武器：雾切之回光 ==========
var _mistsplitter_timed_stack_expire: Array[float] = []
var _mistsplitter_energy_stack_active: bool = false

func _ready() -> void:
	super._ready()
	
	# 如果没有手动分配剑区域，则自动查找
	if sword_area == null:
		sword_area = get_node_or_null("SwordArea") as Area2D
	
	if sword_area:
		# 缓存剑显示Sprite（用于蓄力发光/呼吸缩放）
		_sword_sprite = sword_area.get_node_or_null("Sprite2D") as Sprite2D
		if _sword_sprite:
			_sword_sprite_base_scale = _sword_sprite.scale
			_ensure_weapon_glow_material()
			_apply_equipped_weapon_visual()
		
		# 设置剑的枢轴偏移位置
		sword_area.position = sword_pivot_offset
		
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
		_update_mistsplitter_runtime()
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
		
		# 更新重击蓄力提示
		_update_charged_charge_indicator()
		
		# 只在攻击状态下更新剑相关逻辑
		if is_attacking():
			# 攻击时强制检查覆盖，减少漏判
			if sword_area and sword_area.monitoring:
				_force_check_sword_overlaps()
		else:
			# 只在非攻击状态下更新剑的朝向
			update_sword_direction()
	
	super._physics_process(delta)


func _is_mistsplitter_equipped() -> bool:
	if not RunManager:
		return false
	if not RunManager.has_method("get_equipped_weapon_id"):
		return false
	return str(RunManager.get_equipped_weapon_id()) == "mistsplitter"


func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _prune_mistsplitter_timed_stacks(now: float) -> void:
	for i in range(_mistsplitter_timed_stack_expire.size() - 1, -1, -1):
		if now >= _mistsplitter_timed_stack_expire[i]:
			_mistsplitter_timed_stack_expire.remove_at(i)


func _get_mistsplitter_stack_count() -> int:
	var now := _now_seconds()
	_prune_mistsplitter_timed_stacks(now)
	var timed_count: int = _mistsplitter_timed_stack_expire.size()
	var energy_count: int = 1 if _mistsplitter_energy_stack_active else 0
	return mini(3, timed_count + energy_count)


func _try_gain_mistsplitter_energy_stack() -> void:
	if not _is_mistsplitter_equipped():
		_mistsplitter_energy_stack_active = false
		return

	# 能量充满时立刻消失
	if burst_current_energy >= burst_max_energy - 0.01:
		_mistsplitter_energy_stack_active = false
		return

	# 能量未满：只有在“还没拥有该层”且总层数未满3时，才获得1层
	if _mistsplitter_energy_stack_active:
		return

	var now := _now_seconds()
	_prune_mistsplitter_timed_stacks(now)
	if _mistsplitter_timed_stack_expire.size() < 3:
		_mistsplitter_energy_stack_active = true


func _add_mistsplitter_timed_stack(duration: float) -> void:
	if not _is_mistsplitter_equipped():
		return
	var now := _now_seconds()
	_prune_mistsplitter_timed_stacks(now)
	var expire := now + duration
	if _mistsplitter_timed_stack_expire.size() < 3:
		_mistsplitter_timed_stack_expire.append(expire)
	else:
		# 已满时：替换剩余时间最短的那一层（等价于刷新一层）
		var min_idx := 0
		var min_val := _mistsplitter_timed_stack_expire[0]
		for i in range(1, _mistsplitter_timed_stack_expire.size()):
			if _mistsplitter_timed_stack_expire[i] < min_val:
				min_val = _mistsplitter_timed_stack_expire[i]
				min_idx = i
		_mistsplitter_timed_stack_expire[min_idx] = expire
	_try_gain_mistsplitter_energy_stack()


func _update_mistsplitter_runtime() -> void:
	if not _is_mistsplitter_equipped():
		_mistsplitter_timed_stack_expire.clear()
		_mistsplitter_energy_stack_active = false
		return
	_prune_mistsplitter_timed_stacks(_now_seconds())
	_try_gain_mistsplitter_energy_stack()


func _apply_equipped_weapon_visual() -> void:
	if not is_instance_valid(_sword_sprite):
		return
	if not RunManager:
		return
	if not RunManager.has_method("get_equipped_weapon_id"):
		return
	var weapon_id := str(RunManager.get_equipped_weapon_id())
	if weapon_id.is_empty():
		return
	if not RunManager.has_method("get_weapon_world_texture"):
		return
	var tex: Texture2D = RunManager.get_weapon_world_texture(weapon_id)
	if tex:
		_sword_sprite.texture = tex


func get_weapon_damage_multiplier() -> float:
	if not _is_mistsplitter_equipped():
		return 1.0
	_update_mistsplitter_runtime()
	var stacks := _get_mistsplitter_stack_count()
	# 常驻 +10%，再按层数 +10/20/30%
	return 1.0 + 0.10 + 0.10 * float(stacks)

## 重写攻击状态处理（神里绫华的双段攻击）
func _process_attack_state() -> void:
	velocity = Vector2.ZERO
	# 攻击逻辑由 Tween 动画和回调函数处理

## 更新剑的朝向（朝向鼠标）
func update_sword_direction() -> void:
	if not sword_area or is_attacking():
		return
	
	# 使用剑的全局位置作为旋转中心
	var sword_pivot_global = sword_area.global_position
	var mouse_position = get_global_mouse_position()
	var direction = (mouse_position - sword_pivot_global).normalized()
	sword_area.rotation = direction.angle() + PI / 2

## 重写基类的普攻触发方法
func _start_normal_attack() -> void:
	# 进入攻击时立刻清理蓄力提示视觉（避免发光/缩放残留到攻击阶段）
	if sword_area:
		sword_area.position = sword_pivot_offset
	_reset_charged_charge_visuals()
	attack_phase = 1
	phase2_current_hit = 0
	_change_state(CharacterState.ATTACKING)

## 重写基类的重击触发方法
func _start_charged_attack() -> void:
	# 进入攻击时立刻清理蓄力提示视觉（避免发光/缩放残留到攻击阶段）
	if sword_area:
		sword_area.position = sword_pivot_offset
	_reset_charged_charge_visuals()
	attack_phase = 2
	phase2_current_hit = 0
	_change_state(CharacterState.ATTACKING)

## 执行攻击（由状态机调用）
func perform_attack() -> void:
	# 根据攻击阶段执行不同的攻击逻辑
	if attack_phase == 1:
		_execute_phase1_attack()
	elif attack_phase == 2:
		_execute_phase2_attack()
	else:
		# 默认执行普攻
		attack_phase = 1
		phase2_current_hit = 0
		_execute_phase1_attack()

## 执行第一阶段攻击
func _execute_phase1_attack() -> void:
	attack_phase = 1
	if not sword_area:
		finish_attack()
		return
	
	var mouse_position = get_global_mouse_position()
	
	target_position = global_position  # 取消位移，保持原地攻击
	original_position = global_position
	
	hit_enemies_phase1.clear()
	hit_enemies_phase2.clear()
	
	_start_phase1_swing(mouse_position)

## 第一段攻击：向鼠标方向位移并挥剑
func _start_phase1_swing(mouse_target: Vector2) -> void:
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
	swing_tween.tween_callback(_on_phase1_swing_finished)

## 第一阶段挥剑动画完成
func _on_phase1_swing_finished() -> void:
	_stop_phase1_trail()
	if sword_area:
		sword_area.monitoring = false
	
	# 普攻完成，直接结束攻击状态
	attack_phase = 0
	finish_attack()

## 执行第二阶段攻击
func _execute_phase2_attack() -> void:
	attack_phase = 2
	phase2_current_hit = 0
	
	# 获取准星位置（鼠标位置）
	var mouse_position = get_global_mouse_position()
	
	# 剑执行收刀动作（回到初始朝向）
	if sword_area:
		# 停止之前的 Tween
		if swing_tween:
			swing_tween.kill()
		
		# 计算收刀的目标角度（朝向鼠标的方向）
		var sheath_direction = (mouse_position - global_position).normalized()
		var sheath_angle = sheath_direction.angle() + PI / 2
		
		# 创建收刀动画
		swing_tween = create_tween()
		swing_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		swing_tween.set_ease(Tween.EASE_IN_OUT)
		swing_tween.set_trans(Tween.TRANS_QUAD)
		swing_tween.tween_property(sword_area, "rotation", sheath_angle, 0.2)
	
	# 在准星位置生成重击特效
	if charged_effect:
		_charged_effect_should_visible = true
		charged_effect.visible = true
		charged_effect.global_position = mouse_position
		if charged_effect.sprite_frames:
			charged_effect.play("default")
		else:
			_charged_effect_hide_timer = 0.7
	
	# 设置重击伤害区域位置
	if charged_area:
		charged_area.global_position = mouse_position
	
	# 开始伤害序列
	_trigger_phase2_damage_sequence()

## 触发第二段多次伤害序列
func _trigger_phase2_damage_sequence() -> void:
	if attack_phase != 2:
		return
	
	if phase2_current_hit >= charged_hit_count:
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
	if phase2_current_hit < charged_hit_count and attack_phase == 2:
		var timer = get_tree().create_timer(charged_hit_interval)
		timer.timeout.connect(_trigger_phase2_damage_sequence)
	else:
		# 所有伤害完成，等待特效播放完成后结束
		var finish_timer = get_tree().create_timer(0.5)
		finish_timer.timeout.connect(_on_phase2_finished)

## 重击伤害检测完成
func _on_charged_damage_finished() -> void:
	if charged_area:
		charged_area.monitoring = false

## 第二阶段完成
func _on_phase2_finished() -> void:
	if charged_area:
		charged_area.monitoring = false
	
	# 标记重击动画应该隐藏
	_charged_effect_should_visible = false
	_charged_effect_hide_timer = -1.0
	
	# 如果游戏未暂停，立即隐藏动画
	if not get_tree().paused:
		if charged_effect:
			charged_effect.visible = false
			charged_effect.stop()
	
	hit_enemies_phase1.clear()
	hit_enemies_phase2.clear()
	
	# 攻击完成
	attack_phase = 0
	finish_attack()

## 清理攻击状态
func _cleanup_attack() -> void:
	attack_phase = 0
	phase2_current_hit = 0
	_stop_phase1_trail()
	if sword_area:
		sword_area.monitoring = false
		# 清理攻击状态时恢复剑位置/缩放/发光
		sword_area.position = sword_pivot_offset
		_reset_charged_charge_visuals()
	if charged_area:
		charged_area.monitoring = false
	
	# 标记重击动画应该隐藏
	_charged_effect_should_visible = false
	_charged_effect_hide_timer = -1.0
	
	# 如果游戏未暂停，立即隐藏动画
	if not get_tree().paused and charged_effect:
		charged_effect.visible = false
		charged_effect.stop()
	
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

## 确保蓄力发光Sprite存在（在SwordArea下运行时创建）
func _ensure_charged_glow_sprite() -> void:
	if not sword_area:
		return
	if not is_instance_valid(_sword_sprite):
		_sword_sprite = sword_area.get_node_or_null("Sprite2D") as Sprite2D
		if _sword_sprite:
			_sword_sprite_base_scale = _sword_sprite.scale
	if is_instance_valid(_charged_glow_sprite):
		return
	if not is_instance_valid(_sword_sprite):
		return
	
	_charged_glow_sprite = Sprite2D.new()
	_charged_glow_sprite.name = "ChargedGlow"
	_charged_glow_sprite.texture = _sword_sprite.texture
	_charged_glow_sprite.centered = _sword_sprite.centered
	_charged_glow_sprite.offset = _sword_sprite.offset
	_charged_glow_sprite.position = _sword_sprite.position
	_charged_glow_sprite.flip_h = _sword_sprite.flip_h
	_charged_glow_sprite.flip_v = _sword_sprite.flip_v
	_charged_glow_sprite.visible = false

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_charged_glow_sprite.material = mat
	
	# 确保发光在剑Sprite之上
	_charged_glow_sprite.z_index = _sword_sprite.z_index + 1
	_charged_glow_sprite.z_as_relative = _sword_sprite.z_as_relative

	sword_area.add_child(_charged_glow_sprite)


func _ensure_weapon_glow_material() -> void:
	if not is_instance_valid(_sword_sprite):
		return
	if _sword_sprite_original_material == null:
		_sword_sprite_original_material = _sword_sprite.material
	if not is_instance_valid(_weapon_glow_shader):
		_weapon_glow_shader = Shader.new()
		_weapon_glow_shader.code = """shader_type canvas_item;
uniform vec4 glow_color : source_color = vec4(0.65, 0.92, 1.0, 1.0);
uniform float glow_strength = 0.0;
uniform float glow_size = 2.0;
void fragment(){
	vec4 tex = texture(TEXTURE, UV);
	float a = tex.a;
	vec2 px = TEXTURE_PIXEL_SIZE * glow_size;
	float g = 0.0;
	g = max(g, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	g = max(g, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
	g = max(g, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	g = max(g, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
	g = max(g, texture(TEXTURE, UV + vec2(px.x, px.y)).a);
	g = max(g, texture(TEXTURE, UV + vec2(-px.x, px.y)).a);
	g = max(g, texture(TEXTURE, UV + vec2(px.x, -px.y)).a);
	g = max(g, texture(TEXTURE, UV + vec2(-px.x, -px.y)).a);
	float outline = max(0.0, g - a);
	vec3 add = glow_color.rgb * (outline + a) * glow_strength * glow_color.a;
	COLOR = tex;
	COLOR.rgb += add;
}
"""
	if not is_instance_valid(_weapon_glow_material):
		_weapon_glow_material = ShaderMaterial.new()
		_weapon_glow_material.shader = _weapon_glow_shader

	_weapon_glow_material.set_shader_parameter("glow_color", charged_glow_color)
	_weapon_glow_material.set_shader_parameter("glow_strength", 0.0)
	# 使用 charged_glow_extra_scale 作为发光尺寸的间接控制（越大越“厚”）
	var size: float = clampf(1.0 + (charged_glow_extra_scale - 1.0) * 6.0, 1.0, 6.0)
	_weapon_glow_material.set_shader_parameter("glow_size", size)

## 恢复蓄力提示相关视觉状态（用于释放按键/进入攻击/清理状态）
func _reset_charged_charge_visuals() -> void:
	_charged_ready_last_frame = false
	_charged_ready_pulse_scale_mul = 1.0
	if is_instance_valid(_charged_ready_pulse_tween):
		_charged_ready_pulse_tween.kill()
		_charged_ready_pulse_tween = null
	if is_instance_valid(_sword_sprite):
		_sword_sprite.scale = _sword_sprite_base_scale
		# 清理蓄力自发光
		if _sword_sprite.material == _weapon_glow_material and _sword_sprite_original_material != null:
			_sword_sprite.material = _sword_sprite_original_material
		if is_instance_valid(_weapon_glow_material):
			_weapon_glow_material.set_shader_parameter("glow_strength", 0.0)
	if is_instance_valid(_charged_glow_sprite):
		_charged_glow_sprite.visible = false
		_charged_glow_sprite.scale = _sword_sprite_base_scale * charged_glow_extra_scale
		var c := charged_glow_color
		c.a = 0.0
		_charged_glow_sprite.modulate = c

## 更新重击蓄力提示（武器颤抖）
func _update_charged_charge_indicator() -> void:
	if not sword_area:
		return
	_ensure_weapon_glow_material()
	
	# 如果游戏暂停，保持当前状态不变
	if get_tree().paused:
		return
	
	# 只在按住攻击键且未进入攻击状态时显示蓄力提示
	if _attack_button_pressed and not is_attacking():
		var hold_duration = get_attack_hold_duration()
		var time: float = Time.get_ticks_msec() / 1000.0
		
		# 蓄力进度（0~1），用于控制抖动/发光/呼吸缩放强度
		var progress: float = clampf(hold_duration / charged_attack_threshold, 0.0, 1.0)
		# smoothstep，让强度更平滑
		var strength: float = progress * progress * (3.0 - 2.0 * progress)
		
		# 抖动：从轻微到强烈（达到阈值时最强）
		var shake_amp: float = weapon_shake_amplitude * charged_shake_strength * strength
		var shake_offset: float = sin(time * weapon_shake_frequency * TAU) * shake_amp
		sword_area.position = sword_pivot_offset + Vector2(shake_offset, shake_offset * 0.5)
		
		# 呼吸缩放：只缩放视觉Sprite，不缩放碰撞
		if is_instance_valid(_sword_sprite):
			var breathe: float = 0.5 + 0.5 * sin(time * charged_breathe_frequency * TAU)
			var s: float = 1.0 + charged_breathe_scale_strength * strength * (0.65 + 0.35 * breathe)
			_sword_sprite.scale = _sword_sprite_base_scale * s
		
		# 发光：改为直接作用在武器Sprite上的自发光后处理（不依赖额外子节点）
		if is_instance_valid(_sword_sprite) and is_instance_valid(_weapon_glow_material):
			if _sword_sprite.material != _weapon_glow_material:
				_sword_sprite.material = _weapon_glow_material
			_weapon_glow_material.set_shader_parameter("glow_color", charged_glow_color)
			var glow_pulse: float = 0.5 + 0.5 * sin(time * (charged_breathe_frequency * 1.6) * TAU)
			var glow_strength: float = charged_glow_max_alpha * (0.10 + 0.90 * strength) * (0.55 + 0.45 * glow_pulse) * _charged_ready_pulse_scale_mul
			_weapon_glow_material.set_shader_parameter("glow_strength", clampf(glow_strength, 0.0, 1.0))
		
		# 达到阈值的“就绪提示”：触发一次短促闪烁/放大
		var is_ready: bool = hold_duration >= charged_attack_threshold
		if is_ready and not _charged_ready_last_frame:
			if is_instance_valid(_charged_ready_pulse_tween):
				_charged_ready_pulse_tween.kill()
			_charged_ready_pulse_tween = create_tween()
			_charged_ready_pulse_tween.set_trans(Tween.TRANS_QUAD)
			_charged_ready_pulse_tween.set_ease(Tween.EASE_OUT)
			_charged_ready_pulse_scale_mul = 1.0
			_charged_ready_pulse_tween.tween_property(self, "_charged_ready_pulse_scale_mul", 1.08, 0.10)
			_charged_ready_pulse_tween.tween_property(self, "_charged_ready_pulse_scale_mul", 1.0, 0.12)
		_charged_ready_last_frame = is_ready
	else:
		# 未按住攻击键，恢复武器位置
		if not is_attacking():
			sword_area.position = sword_pivot_offset
			# 释放按键时清理自发光
			if is_instance_valid(_sword_sprite) and _sword_sprite.material == _weapon_glow_material and _sword_sprite_original_material != null:
				_sword_sprite.material = _sword_sprite_original_material
			if is_instance_valid(_weapon_glow_material):
				_weapon_glow_material.set_shader_parameter("glow_strength", 0.0)
		_reset_charged_charge_visuals()

## 更新重击动画状态（每帧调用）
func _update_charged_effect() -> void:
	if not charged_effect:
		return
	
	# 如果游戏暂停，保持当前状态不变
	if get_tree().paused:
		return
	
	var in_phase2 = attack_phase == 2
	
	# 根据攻击状态和倒计时决定是否显示
	var should_show = _charged_effect_should_visible and in_phase2
	
	# 如果有隐藏倒计时，更新它
	if _charged_effect_hide_timer > 0:
		_charged_effect_hide_timer -= get_physics_process_delta_time()
		if _charged_effect_hide_timer <= 0:
			should_show = false
	
	# 更新可见性
	if should_show:
		if not charged_effect.visible:
			charged_effect.visible = true
			charged_effect.modulate.a = 1.0  # 完全不透明
		if not charged_effect.is_playing():
			charged_effect.play("default")
	else:
		if charged_effect.visible and not _attack_button_pressed:
			charged_effect.visible = false
			charged_effect.stop()
		_charged_effect_should_visible = false
		_charged_effect_hide_timer = -1.0

## 获取重击特效（供暂停菜单使用）
func get_charged_effect() -> AnimatedSprite2D:
	return charged_effect

## 剑碰撞到敌人时的回调
func _on_sword_area_entered(area: Area2D) -> void:
	_handle_sword_hit(area)

func _on_sword_body_entered(body: Node2D) -> void:
	_handle_sword_hit(body)

func _handle_sword_hit(target: Node2D) -> void:
	if not target or not target.is_in_group("enemies"):
		return
	
	var already_hit = false
	if attack_phase == 1:
		if target in hit_enemies_phase1:
			already_hit = true
		else:
			hit_enemies_phase1.append(target)
	elif attack_phase == 2:
		if target in hit_enemies_phase2:
			already_hit = true
		else:
			hit_enemies_phase2.append(target)
	
	if not already_hit and target.has_method("take_damage"):
		# 使用统一伤害计算系统
		# 普通攻击不击退，而是使敌人僵直
		var damage_result = deal_damage_to(target, normal_attack_multiplier, false, false, false, true)
		var damage = damage_result[0]
		var is_crit = damage_result[1]
		
		if is_crit:
			print("普攻 暴击！伤害: ", damage)
		
		# 普攻命中敌人时充能大招（应用充能效率加成）
		var actual_energy = energy_per_hit * get_energy_gain_multiplier()
		_add_burst_energy(actual_energy)
		# 雾切：普攻造成伤害时获得1层，持续5秒
		_add_mistsplitter_timed_stack(5.0)

## 主动检查覆盖，避免物理帧遗漏
func _force_check_sword_overlaps() -> void:
	if not sword_area:
		return
	for area in sword_area.get_overlapping_areas():
		_on_sword_area_entered(area)
	for body in sword_area.get_overlapping_bodies():
		_on_sword_body_entered(body)

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
		# 判断是否为最后一击（因为 phase2_current_hit 在伤害检测后才增加，所以需要 +1）
		var is_final_hit = (phase2_current_hit + 1 >= charged_hit_count)
		
		# 前两次造成僵直，最后一次造成击退
		var apply_knockback = is_final_hit
		var apply_stun = not is_final_hit
		
		# 使用统一伤害计算系统（75%攻击力）
		var damage_result = deal_damage_to(target, charged_attack_multiplier, false, false, apply_knockback, apply_stun)
		var damage = damage_result[0]
		var is_crit = damage_result[1]
		
		if is_crit:
			print("重击 暴击！伤害: ", damage, " (第", phase2_current_hit, "/", charged_hit_count, "击)")
		else:
			print("重击命中敌人，造成伤害: ", damage, " (第", phase2_current_hit, "/", charged_hit_count, "击)")
		
		# 重击命中敌人时充能大招（应用充能效率加成）
		var actual_energy = energy_per_hit * get_energy_gain_multiplier()
		_add_burst_energy(actual_energy)
		# 雾切：普攻造成伤害时获得1层，持续5秒
		_add_mistsplitter_timed_stack(5.0)

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

# ========== E技能相关方法 ==========

## 处理E键技能输入
func handle_skill_input() -> void:
	# 检测E键按下（使用is_physical_key_pressed并检查状态变化）
	var e_pressed = Input.is_physical_key_pressed(KEY_E)
	if (Input.is_action_just_pressed("ui_select") or (e_pressed and not _last_e_pressed)):
		if _is_skill_ready() and can_move():
			use_skill()
	_last_e_pressed = e_pressed

## 检查技能是否可用
func _is_skill_ready() -> bool:
	return Time.get_ticks_msec() >= skill_next_ready_ms

## 使用E技能：围绕角色造成范围伤害
func use_skill() -> void:
	if not _is_skill_ready():
		return
	
	# 播放技能语音
	if BGMManager and character_data and not character_data.id.is_empty():
		BGMManager.play_character_voice(character_data.id, "技能", 0.0, 0.2)
	
	# 计算实际冷却时间（应用升级加成）
	var actual_cooldown = skill_cooldown * get_skill_cooldown_multiplier()
	
	# 设置冷却时间
	skill_next_ready_ms = Time.get_ticks_msec() + int(actual_cooldown * 1000.0)
	
	# 清空已命中敌人列表
	skill_hit_enemies.clear()
	
	# 启用技能区域检测
	if skill_area:
		skill_area.monitoring = true
		skill_area.global_position = global_position
		
		# 更新技能范围（应用升级加成）
		var actual_radius = skill_radius * get_skill_radius_multiplier()
		var collision_shape = skill_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision_shape and collision_shape.shape is CircleShape2D:
			(collision_shape.shape as CircleShape2D).radius = actual_radius
		
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
		# 使用统一伤害计算系统（技能伤害通过攻击力提升）
		var damage_result = deal_damage_to(target, skill_damage_multiplier * get_weapon_skill_burst_damage_multiplier())
		var damage = damage_result[0]
		var is_crit = damage_result[1]
		
		if is_crit:
			print("E技能 暴击！伤害: ", damage)
		else:
			print("E技能命中敌人，造成伤害: ", damage)
		
		# E技能命中敌人时充能大招（应用充能效率加成）
		var actual_energy = energy_per_hit * get_energy_gain_multiplier()
		_add_burst_energy(actual_energy)

## 强制检查技能范围内的敌人
func _force_check_skill_overlaps() -> void:
	if not skill_area:
		return
	
	# 计算实际技能范围（应用升级加成）
	var actual_radius = skill_radius * get_skill_radius_multiplier()
	
	# 获取范围内的所有敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		var enemy_body = enemy as Node2D
		if not enemy_body:
			continue
		
		# 计算距离
		var distance = (enemy_body.global_position - global_position).length()
		if distance <= actual_radius:
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
func handle_burst_input() -> void:
	# 检测Q键按下
	var q_pressed = Input.is_physical_key_pressed(KEY_Q)
	if q_pressed and not _last_q_pressed:
		if _is_burst_ready() and can_move():
			use_burst()
	_last_q_pressed = q_pressed

## 检查大招是否可用
func _is_burst_ready() -> bool:
	return burst_current_energy >= burst_max_energy

## 使用大招：向鼠标方向发射特效
func use_burst() -> void:
	if not _is_burst_ready():
		return
	
	# 播放大招语音
	if BGMManager and character_data and not character_data.id.is_empty():
		BGMManager.play_character_voice(character_data.id, "大招", 0.0, 0.2)
	
	# 消耗所有充能
	burst_current_energy = 0.0
	_update_burst_energy_display()
	# 雾切：施放元素爆发时获得1层，持续10秒
	_add_mistsplitter_timed_stack(10.0)
	# 雾切：能量未满时的层数逻辑
	_try_gain_mistsplitter_energy_stack()
	
	# 通知UI播放大招动画（不要依赖投射物是否成功创建）
	if character_data and not character_data.id.is_empty():
		emit_signal("burst_used", character_data.id)
	
	# 如果没有加载场景，尝试加载
	if burst_scene == null:
		if DataManager:
			burst_scene = DataManager.get_packed_scene("res://scenes/projectiles/burst_projectile.tscn")
		else:
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
	
	# 设置角色引用和伤害倍率（用于deal_damage_to）
	burst_instance.owner_character = self
	burst_instance.damage_multiplier = burst_damage_multiplier * get_weapon_skill_burst_damage_multiplier()
	
	# 预计算伤害用于显示（可选，用于调试）
	if current_stats:
		var damage_result = current_stats.calculate_damage(burst_instance.damage_multiplier, 0.0, false, false)
		burst_instance.damage = damage_result[0]
		burst_instance.is_crit = damage_result[1]
	else:
		burst_instance.damage = burst_damage
		burst_instance.is_crit = false
	
	# 添加到场景树（添加到当前节点的父节点或根节点）
	var parent_node = get_parent()
	if parent_node:
		parent_node.add_child(burst_instance)
	else:
		get_tree().root.add_child(burst_instance)
	
	print("使用大招：向鼠标方向发射")

## 增加大招充能
func _add_burst_energy(amount: float) -> void:
	if burst_current_energy < burst_max_energy:
		burst_current_energy = min(burst_current_energy + amount, burst_max_energy)
		_try_gain_mistsplitter_energy_stack()
		_update_burst_energy_display()

## 更新大招充能显示
func _update_burst_energy_display() -> void:
	emit_signal("burst_energy_changed", burst_current_energy, burst_max_energy)
