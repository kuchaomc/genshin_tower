extends CharacterBody2D
class_name BaseCharacter

## 角色基类
## 包含所有角色的通用逻辑（移动、血量、基础攻击等）
## 使用简单的状态标志管理角色行为
## 统一伤害计算公式：最终伤害 = 攻击力 × 攻击倍率 × 暴击倍率 × (1 - 目标减伤比例)

# ========== 状态标志 ==========
enum CharacterState {
	IDLE,
	MOVING,
	ATTACKING,
	DODGING,
	KNOCKBACK,
	DEAD
}
var current_state: CharacterState = CharacterState.IDLE

# ========== 角色数据 ==========
var character_data: CharacterData = null

# ========== 属性系统 ==========
## 基础属性（来自 CharacterData，不可修改）
var base_stats: CharacterStats = null
## 当前属性（运行时可被 buff/debuff 修改）
var current_stats: CharacterStats = null

# ========== 圣遗物系统 ==========
## 圣遗物管理器
var artifact_manager: ArtifactManager = null

# ========== 血量属性 ==========
var current_health: float = 100.0
var max_health: float = 100.0
@export var invincibility_duration: float = 1.0
var is_invincible: bool = false # 无敌状态：由"受伤无敌/闪避无敌"合并而来
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

var _dodge_next_ready_ms: int = 0
var _last_nonzero_move_dir: Vector2 = Vector2.RIGHT
var _dodge_direction: Vector2 = Vector2.ZERO
var _dodge_elapsed: float = 0.0

var _hurt_invincible: bool = false
var _dodge_invincible: bool = false

# ========== 碰撞层/掩码（Godot 4 使用 bitmask，不是“层号”） ==========
# 约定（与 project.godot 的 layer_names 对齐）：
# - 1: Walls   => bit 1 << 0 == 1
# - 2: Enemies => bit 1 << 1 == 2
# - 4: Player  => bit 1 << 3 == 8
# - 5: DodgePlayer（闪避专用层）=> bit 1 << 4 == 16
# - 正常：与墙+敌人碰撞 => 1 | 2 = 3
# - 闪避：只与墙碰撞（可穿过敌人）=> 1
const _NORMAL_COLLISION_MASK: int = 1 | 2
const _DODGE_COLLISION_MASK: int = 1
const _PLAYER_COLLISION_LAYER: int = 1 << 3
const _DODGE_PLAYER_COLLISION_LAYER: int = 1 << 4

# 血量变化信号
signal health_changed(current: float, maximum: float)
# 角色受击信号（用于UI表现等）
signal damaged(damage: float)
signal character_died
# 伤害事件信号（用于伤害数字显示等）
signal damage_dealt(damage: float, is_crit: bool, target: Node)

# ========== 移动属性 ==========
@export var move_speed: float = 100.0
@export var animator: AnimatedSprite2D
@export var knockback_force: float = 150.0  # 对敌人造成击退的力度，可在角色数据中配置

# ========== 闪避残影特效 ==========
@export_group("闪避残影特效")
@export var dodge_afterimage_enabled: bool = true
@export var dodge_afterimage_count: int = 4
@export var dodge_afterimage_interval: float = 0.04
@export var dodge_afterimage_lifetime: float = 0.18
@export var dodge_afterimage_color: Color = Color(0.75, 0.92, 1.0, 0.65)
@export var dodge_afterimage_z: int = 40
@export_group("")
const _SETTINGS_FILE_PATH: String = "user://settings.cfg"
const _SETTINGS_SECTION_VFX: String = "vfx"
const _SETTINGS_KEY_MOVEMENT_TRAIL_ENABLED: String = "movement_trail_enabled"
var _dodge_afterimage_timer: float = 0.0
var _dodge_afterimage_spawned: int = 0

# ========== 攻击按键追踪 ==========
## 鼠标左键按下的时间戳（毫秒）
var _attack_button_press_time: int = 0
## 鼠标左键是否正在按下
var _attack_button_pressed: bool = false
## 重击触发阈值（秒）
@export var charged_attack_threshold: float = 1.0
## 重击蓄力时移动速度倍率（0.5 = 50%速度）
@export var charged_attack_move_speed_multiplier: float = 0.5

# ========== 碰撞箱引用 ==========
var collision_shape: CollisionShape2D

# ========== 击退效果 ==========
var knockback_velocity: Vector2 = Vector2.ZERO
var is_knockback_active: bool = false
@export var knockback_duration: float = 0.12  # 击退持续时间（秒）
var _knockback_end_ms: int = 0

# ========== 状态 ==========
var is_game_over: bool = false
## 充能效率倍率（通用升级，所有角色共享）
var energy_gain_multiplier: float = 1.0

# ========== 通用升级属性 ==========
## 所有角色都拥有的通用属性升级列表
## 子类可以通过重写 _apply_custom_upgrades() 方法来实现非通用属性的升级
const COMMON_UPGRADE_STATS: Array[Dictionary] = [
	{"property": "max_health", "target_stat": UpgradeData.TargetStat.MAX_HEALTH},
	{"property": "attack", "target_stat": UpgradeData.TargetStat.ATTACK},
	{"property": "defense_percent", "target_stat": UpgradeData.TargetStat.DEFENSE_PERCENT},
	{"property": "move_speed", "target_stat": UpgradeData.TargetStat.MOVE_SPEED},
	{"property": "attack_speed", "target_stat": UpgradeData.TargetStat.ATTACK_SPEED},
	{"property": "crit_rate", "target_stat": UpgradeData.TargetStat.CRIT_RATE},
	{"property": "crit_damage", "target_stat": UpgradeData.TargetStat.CRIT_DAMAGE},
	{"property": "knockback_force", "target_stat": UpgradeData.TargetStat.KNOCKBACK_FORCE},
	{"property": "pickup_range", "target_stat": UpgradeData.TargetStat.PICKUP_RANGE}
]

## 初始化角色
func initialize(data: CharacterData) -> void:
	character_data = data
	
	# 初始化属性系统
	base_stats = data.get_stats()
	current_stats = base_stats.duplicate_stats()
	
	# 初始化圣遗物系统
	_initialize_artifacts(data)
	
	# 在应用属性前，保存RunManager中的当前血量（如果存在）
	var saved_health: float = -1.0
	var saved_max_health: float = -1.0
	if RunManager:
		saved_health = RunManager.health
		saved_max_health = RunManager.max_health
	
	# 应用属性到角色
	_apply_stats_to_character()
	
	# 如果RunManager中有保存的血量，且最大血量匹配，则恢复保存的血量
	if RunManager and saved_health >= 0 and saved_max_health > 0:
		# 如果最大血量发生变化（例如升级），按比例调整当前血量
		if abs(saved_max_health - max_health) > 0.01:
			var health_ratio = saved_health / saved_max_health
			current_health = max_health * health_ratio
		else:
			# 最大血量没变，直接恢复当前血量
			current_health = saved_health
		# 确保血量不超过最大值
		current_health = min(current_health, max_health)
	
	emit_signal("health_changed", current_health, max_health)
	print("角色初始化：", data.display_name, " | ", current_stats.get_summary())
	
	# 注意：圣遗物加成在装备时才会应用，初始化时不应用

## 初始化圣遗物系统
## 注意：角色默认不装备任何圣遗物，需要在对局中获取
func _initialize_artifacts(data: CharacterData) -> void:
	if data.artifact_set:
		artifact_manager = ArtifactManager.new()
		# 创建空的圣遗物套装（不装备任何圣遗物）
		var set_copy = ArtifactSetData.new()
		set_copy.character_id = data.artifact_set.character_id
		set_copy.set_name = data.artifact_set.set_name
		set_copy.set_description = data.artifact_set.set_description
		# 不自动装备圣遗物，所有槽位初始为空
		set_copy.flower = null
		set_copy.plume = null
		set_copy.sands = null
		set_copy.goblet = null
		set_copy.circlet = null
		artifact_manager.initialize(set_copy)
		print("圣遗物系统已初始化（未装备）：", set_copy.set_name)
	else:
		artifact_manager = null

## 从当前属性应用到角色实际数值
func _apply_stats_to_character() -> void:
	if not current_stats:
		return
	max_health = current_stats.max_health
	current_health = max_health
	base_move_speed = current_stats.move_speed
	move_speed = base_move_speed
	knockback_force = current_stats.knockback_force
	# 拾取范围不需要在这里设置，因为它不是运行时属性

func _ready() -> void:
	# 如果没有手动分配动画器，则自动查找
	if animator == null:
		animator = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	
	# 获取碰撞箱引用
	collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	
	add_to_group("characters")
	_dodge_afterimage_enabled_from_settings()
	set_movement_trail_enabled(dodge_afterimage_enabled)
	
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
	
	# 将玩家本体放到"玩家层"，避免与墙层/敌人层混用
	collision_layer = _PLAYER_COLLISION_LAYER
	
	# 初始化碰撞掩码：默认与墙+敌人发生碰撞
	collision_mask = _NORMAL_COLLISION_MASK

func _physics_process(delta: float) -> void:
	if is_game_over:
		return
	
	# 更新击退计时器
	_update_knockback(delta)
	
	# 处理状态逻辑
	_process_state_logic(delta)
	
	# 处理动画
	handle_animation()
	
	# 执行移动
	move_and_slide()

func set_movement_trail_enabled(is_enabled: bool) -> void:
	dodge_afterimage_enabled = is_enabled

func _dodge_afterimage_enabled_from_settings() -> void:
	var config := ConfigFile.new()
	var err: Error = config.load(_SETTINGS_FILE_PATH)
	if err != OK:
		return
	var enabled: bool = bool(config.get_value(_SETTINGS_SECTION_VFX, _SETTINGS_KEY_MOVEMENT_TRAIL_ENABLED, dodge_afterimage_enabled))
	dodge_afterimage_enabled = enabled

func _start_dodge_afterimage() -> void:
	_dodge_afterimage_timer = 0.0
	_dodge_afterimage_spawned = 0
	_spawn_dodge_afterimage()

func _update_dodge_afterimage(delta: float) -> void:
	if not dodge_afterimage_enabled:
		return
	if dodge_afterimage_count <= 0:
		return
	if dodge_afterimage_interval <= 0.0:
		return
	if _dodge_afterimage_spawned >= dodge_afterimage_count:
		return

	_dodge_afterimage_timer -= delta
	var safe_loops: int = 0
	while _dodge_afterimage_timer <= 0.0 and _dodge_afterimage_spawned < dodge_afterimage_count:
		_spawn_dodge_afterimage()
		_dodge_afterimage_timer += dodge_afterimage_interval
		safe_loops += 1
		if safe_loops >= 16:
			break

func _spawn_dodge_afterimage() -> void:
	if not is_instance_valid(animator):
		return
	if animator.sprite_frames == null:
		return

	var ghost := AnimatedSprite2D.new()
	ghost.top_level = true
	ghost.sprite_frames = animator.sprite_frames
	ghost.animation = animator.animation
	ghost.frame = animator.frame
	ghost.flip_h = animator.flip_h
	ghost.flip_v = animator.flip_v
	ghost.z_index = dodge_afterimage_z
	ghost.z_as_relative = false
	ghost.modulate = dodge_afterimage_color
	ghost.global_transform = animator.global_transform
	ghost.speed_scale = 0.0
	ghost.stop()

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ghost.material = mat

	var p := get_parent()
	if p:
		p.add_child(ghost)
	else:
		add_child(ghost)

	_dodge_afterimage_spawned += 1

	var life: float = maxf(0.01, dodge_afterimage_lifetime)
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_SINE)
	t.tween_property(ghost, "modulate:a", 0.0, life)
	t.tween_callback(ghost.queue_free)

## 处理状态逻辑（主要控制循环）
func _process_state_logic(delta: float) -> void:
	# 检查状态转换（优先级从高到低）
	if current_state != CharacterState.DEAD and is_game_over:
		_change_state(CharacterState.DEAD)
	elif current_state != CharacterState.DEAD and current_state != CharacterState.KNOCKBACK and is_knockback_active:
		_change_state(CharacterState.KNOCKBACK)
	
	# 根据当前状态执行逻辑
	match current_state:
		CharacterState.IDLE:
			_process_idle_state()
		CharacterState.MOVING:
			_process_move_state()
		CharacterState.ATTACKING:
			_process_attack_state()
		CharacterState.DODGING:
			_process_dodge_state(delta)
		CharacterState.KNOCKBACK:
			_process_knockback_state()
		CharacterState.DEAD:
			_process_dead_state()

## 空闲状态逻辑
func _process_idle_state() -> void:
	velocity = Vector2.ZERO
	
	# 处理攻击按键追踪
	_process_attack_input()
	
	# 检查状态转换
	if _is_dodge_pressed() and _is_dodge_ready() and not _is_dodge_blocked_by_charging():
		_start_dodge()
	elif _get_input_direction() != Vector2.ZERO:
		_change_state(CharacterState.MOVING)

## 移动状态逻辑
func _process_move_state() -> void:
	var input_dir = _get_input_direction()
	
	# 计算移动速度（如果正在蓄力重击，减慢速度）
	var current_move_speed = move_speed
	if _attack_button_pressed:
		# 正在蓄力重击，应用速度减慢
		current_move_speed = move_speed * charged_attack_move_speed_multiplier
	
	velocity = input_dir * current_move_speed
	
	# 记录最后非零移动方向
	if input_dir != Vector2.ZERO:
		_last_nonzero_move_dir = input_dir.normalized()
	
	# 处理攻击按键追踪
	_process_attack_input()
	
	# 检查状态转换
	if _is_dodge_pressed() and _is_dodge_ready() and not _is_dodge_blocked_by_charging():
		_start_dodge()
	elif input_dir == Vector2.ZERO:
		_change_state(CharacterState.IDLE)

## 攻击状态逻辑（子类重写）
func _process_attack_state() -> void:
	velocity = Vector2.ZERO
	# 子类实现具体攻击逻辑

## 闪避状态逻辑
func _process_dodge_state(delta: float) -> void:
	_dodge_elapsed += delta
	
	var t: float = 0.0
	if dodge_duration > 0.0:
		t = clamp(_dodge_elapsed / dodge_duration, 0.0, 1.0)
	
	# 计算基础速度
	var base_speed: float = base_move_speed
	if dodge_duration > 0.0:
		base_speed = dodge_distance / dodge_duration
	
	# 速度曲线：初始很快，逐渐回落
	var start_speed: float = base_speed * dodge_speed_multiplier
	var end_speed: float = base_speed * 0.8
	var ease_out: float = 1.0 - pow(1.0 - t, 2.0)
	var speed: float = lerp(start_speed, end_speed, ease_out)
	
	velocity = _dodge_direction * speed
	_update_dodge_afterimage(delta)
	
	# 检查闪避是否完成
	if t >= 1.0:
		_end_dodge()

## 击退状态逻辑
func _process_knockback_state() -> void:
	velocity = knockback_velocity
	
	# 击退结束检查在 _update_knockback 中处理

## 死亡状态逻辑
func _process_dead_state() -> void:
	velocity = Vector2.ZERO

## 改变状态
func _change_state(new_state: CharacterState) -> void:
	if current_state == new_state:
		return
	
	# 退出旧状态
	_exit_state(current_state)
	
	# 进入新状态
	current_state = new_state
	_enter_state(new_state)

## 进入状态
func _enter_state(state: CharacterState) -> void:
	match state:
		CharacterState.IDLE:
			if animator:
				animator.play("idle")
		CharacterState.MOVING:
			if animator:
				animator.play("run")
		CharacterState.ATTACKING:
			velocity = Vector2.ZERO
			# 攻击时播放idle动画（停止move动画）
			if animator:
				animator.play("idle")
			perform_attack()
		CharacterState.DODGING:
			_dodge_elapsed = 0.0
			_dodge_next_ready_ms = Time.get_ticks_msec() + int(dodge_cooldown * 1000.0)
			
			# 计算闪避方向（使用方向键）
			var dir = _get_input_direction()
			if dir == Vector2.ZERO:
				dir = _last_nonzero_move_dir
			_dodge_direction = dir.normalized()
			_start_dodge_afterimage()
			
			# 设置闪避无敌
			_set_dodge_invincible(true)
			
			# 修改碰撞层（可穿过敌人）
			collision_mask = _DODGE_COLLISION_MASK
			collision_layer = _DODGE_PLAYER_COLLISION_LAYER
		CharacterState.KNOCKBACK:
			pass  # 击退逻辑已在 apply_knockback 中设置
		CharacterState.DEAD:
			velocity = Vector2.ZERO
			_set_collision_enabled(false)

## 退出状态
func _exit_state(state: CharacterState) -> void:
	match state:
		CharacterState.DODGING:
			# 取消闪避无敌
			_set_dodge_invincible(false)
			
			# 恢复正常碰撞
			collision_mask = _NORMAL_COLLISION_MASK
			collision_layer = _PLAYER_COLLISION_LAYER
		CharacterState.ATTACKING:
			_cleanup_attack()

## 开始闪避
func _start_dodge() -> void:
	_change_state(CharacterState.DODGING)

## 结束闪避
func _end_dodge() -> void:
	var input_dir = _get_input_direction()
	if input_dir != Vector2.ZERO:
		_change_state(CharacterState.MOVING)
	else:
		_change_state(CharacterState.IDLE)

## 开始攻击
func _start_attack() -> void:
	_change_state(CharacterState.ATTACKING)

## 清理攻击状态（子类可重写）
func _cleanup_attack() -> void:
	pass

## 获取输入方向
func _get_input_direction() -> Vector2:
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	input_dir.y = Input.get_action_strength("down") - Input.get_action_strength("up")
	return input_dir.normalized()

## 处理攻击输入逻辑（新系统：按住1秒触发重击）
func _process_attack_input() -> void:
	var is_pressing = Input.is_action_pressed("mouse1")
	
	# 检测按键按下
	if is_pressing and not _attack_button_pressed:
		_attack_button_pressed = true
		_attack_button_press_time = Time.get_ticks_msec()
	
	# 检测按键释放
	elif not is_pressing and _attack_button_pressed:
		_attack_button_pressed = false
		var hold_duration = (Time.get_ticks_msec() - _attack_button_press_time) / 1000.0
		
		# 根据按住时间判断触发普攻还是重击
		if hold_duration < charged_attack_threshold:
			# 按住时间小于阈值，触发普攻
			_start_normal_attack()
		else:
			# 按住时间超过阈值，触发重击
			_start_charged_attack()

## 开始普攻（子类可重写）
func _start_normal_attack() -> void:
	_change_state(CharacterState.ATTACKING)

## 开始重击（子类可重写）
func _start_charged_attack() -> void:
	# 默认行为：与普攻相同
	_change_state(CharacterState.ATTACKING)

## 获取当前按住攻击键的时间（秒）
func get_attack_hold_duration() -> float:
	if _attack_button_pressed:
		return (Time.get_ticks_msec() - _attack_button_press_time) / 1000.0
	return 0.0

## 检查是否达到重击阈值
func is_charged_attack_ready() -> bool:
	return _attack_button_pressed and get_attack_hold_duration() >= charged_attack_threshold

## 蓄力重击中是否禁止闪避
## 说明：当前系统使用 _attack_button_pressed 作为“按住普攻键蓄力”的状态标志。
func _is_dodge_blocked_by_charging() -> bool:
	return _attack_button_pressed

## 检查是否按下闪避键
func _is_dodge_pressed() -> bool:
	return Input.is_action_just_pressed("mouse2") or Input.is_action_just_pressed("shift")

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
	
	# 动画由状态控制，这里不再播放

## 执行攻击（子类必须实现）
func perform_attack() -> void:
	pass

## 攻击完成时调用
func finish_attack() -> void:
	if current_state == CharacterState.ATTACKING:
		var input_dir = _get_input_direction()
		if input_dir != Vector2.ZERO:
			_change_state(CharacterState.MOVING)
		else:
			_change_state(CharacterState.IDLE)

## 检查闪避是否就绪
func _is_dodge_ready() -> bool:
	return Time.get_ticks_msec() >= _dodge_next_ready_ms

## 设置闪避无敌状态
func _set_dodge_invincible(active: bool) -> void:
	_dodge_invincible = active
	_refresh_invincible_state()

## 设置受伤无敌状态
func _set_hurt_invincible(active: bool) -> void:
	_hurt_invincible = active
	_refresh_invincible_state()

func _is_currently_invincible() -> bool:
	return _hurt_invincible or _dodge_invincible

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

# ========== 统一伤害计算系统 ==========

## 计算并造成伤害（核心方法）
## target: 目标节点（必须有 take_damage 方法和可选的 get_defense_percent 方法）
## damage_multiplier: 伤害倍率（普攻 1.0，技能可能 1.5、2.0 等）
## force_crit: 强制暴击
## force_no_crit: 强制不暴击
## apply_knockback: 是否应用击退效果（默认 true）
## apply_stun: 是否应用僵直效果（默认 false）
## 返回值: [实际造成的伤害, 是否暴击]
func deal_damage_to(target: Node, damage_multiplier: float = 1.0, force_crit: bool = false, force_no_crit: bool = false, apply_knockback: bool = true, apply_stun: bool = false) -> Array:
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
	var damage_dealt: bool = false
	if target.has_method("take_damage"):
		var knockback_dir = Vector2.ZERO
		if target is Node2D:
			knockback_dir = (target.global_position - global_position).normalized()
		
		# 检查目标的 take_damage 方法签名，支持不同的参数组合
		if target.has_method("take_damage"):
			# 检查是否支持僵直参数（3个参数：damage, knockback, apply_stun）
			if apply_stun and _can_call_with_params(target, "take_damage", 3):
				var knockback_force_value = knockback_dir * current_stats.knockback_force if apply_knockback else Vector2.ZERO
				target.take_damage(final_damage, knockback_force_value, apply_stun)
				damage_dealt = true
			# 检查是否支持击退参数（2个参数：damage, knockback）
			elif apply_knockback and _can_call_with_params(target, "take_damage", 2):
				target.take_damage(final_damage, knockback_dir * current_stats.knockback_force)
				damage_dealt = true
			# 只传递伤害
			else:
				target.take_damage(final_damage)
				damage_dealt = true
	
	# 如果成功造成伤害，播放命中音效
	if damage_dealt and BGMManager:
		BGMManager.play_hit_sound()
	
	# 显示伤害飘字（在目标位置）
	if damage_dealt and DamageNumberManager and target is Node2D:
		DamageNumberManager.show_damage(target.global_position, final_damage, is_crit)
	
	# 记录伤害统计
	if RunManager:
		RunManager.record_damage_dealt(final_damage)
	
	# 发射伤害事件信号
	emit_signal("damage_dealt", final_damage, is_crit, target)
	
	return [final_damage, is_crit]

## 检查方法是否支持指定数量的参数
func _can_call_with_params(obj: Object, method_name: String, param_count: int) -> bool:
	# 性能：get_method_list() 会构造完整的方法信息数组，在战斗高频命中时容易造成掉帧尖峰。
	# 这里按“脚本资源路径/类名 + 方法名”缓存一次参数数量（最大参数个数），后续直接 O(1) 查询。
	if obj == null:
		return false
	
	var script := obj.get_script() as Script
	var owner_key: String
	if script and script.resource_path != "":
		owner_key = script.resource_path
	else:
		owner_key = obj.get_class()
	
	var cache_key := owner_key + ":" + method_name
	if _method_param_count_cache.has(cache_key):
		return int(_method_param_count_cache[cache_key]) >= param_count
	
	var max_args := -1
	for method in obj.get_method_list():
		if method["name"] == method_name:
			max_args = int(method["args"].size())
			break
	_method_param_count_cache[cache_key] = max_args
	return max_args >= param_count

static var _method_param_count_cache: Dictionary = {}

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

## 获取拾取范围
func get_pickup_range() -> float:
	if current_stats:
		return current_stats.pickup_range
	return 80.0  # 默认值

# ========== 血量相关方法 ==========

## 受到伤害（应用自身减伤）
## knockback_direction: 击退方向（可选，如果提供则应用击退效果）
## knockback_force_value: 击退力度（可选，默认值）
func take_damage(damage_amount: float, knockback_direction: Vector2 = Vector2.ZERO, knockback_force_value: float = 100.0) -> void:
	if is_game_over or _is_currently_invincible():
		return
	
	# 应用减伤计算
	var actual_damage = damage_amount
	if current_stats:
		actual_damage = current_stats.calculate_damage_taken(damage_amount)
	
	# 播放受伤语音（带节流，避免连续受伤时刷屏）
	if BGMManager and character_data and not character_data.id.is_empty():
		BGMManager.play_character_voice(character_data.id, "受伤", 0.0, 0.8)
	
	current_health -= actual_damage
	current_health = max(0, current_health)
	
	# 显示伤害飘字（在角色位置）
	if DamageNumberManager:
		DamageNumberManager.show_damage(global_position, actual_damage, false)
	
	# 更新RunManager
	if RunManager:
		RunManager.take_damage(actual_damage)
	
	damaged.emit(actual_damage)
	
	emit_signal("health_changed", current_health, max_health)
	print("角色受到伤害: ", actual_damage, "点（原始: ", damage_amount, "），剩余血量: ", current_health, "/", max_health)
	
	# 播放受伤屏幕效果
	if PostProcessManager:
		# 根据伤害占最大血量的比例调整效果强度（最低0.3，最高0.6）
		var damage_ratio = clamp(actual_damage / max_health, 0.0, 0.3)
		var effect_intensity = 0.3 + damage_ratio
		PostProcessManager.play_hurt_effect(effect_intensity, 1.0)
	
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

## 回复血量
func heal(heal_amount: float) -> void:
	if is_game_over:
		return
	
	current_health += heal_amount
	current_health = min(current_health, max_health)
	
	# 显示治疗飘字
	if DamageNumberManager:
		DamageNumberManager.show_heal(global_position, heal_amount)
	
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
	# 播放死亡语音
	if BGMManager and character_data and not character_data.id.is_empty():
		BGMManager.play_character_voice(character_data.id, "死亡")
	is_game_over = true
	emit_signal("character_died")
	
	# 切换到死亡状态
	_change_state(CharacterState.DEAD)
	
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

## 应用击退效果（按"击退距离"计算）
## distance: 本次希望推开的距离（像素）
func apply_knockback(direction: Vector2, distance: float) -> void:
	if direction == Vector2.ZERO or distance <= 0.0:
		return
	
	var knockback_dir = direction.normalized()
	
	# 设置击退速度：在 knockback_duration 内推开指定距离
	var dur: float = max(0.01, knockback_duration)
	knockback_velocity = knockback_dir * (distance / dur)
	is_knockback_active = true
	_knockback_end_ms = Time.get_ticks_msec() + int(dur * 1000.0)
	
	# 切换到击退状态
	if current_state != CharacterState.DEAD:
		_change_state(CharacterState.KNOCKBACK)

## 更新击退效果
func _update_knockback(_delta: float) -> void:
	if not is_knockback_active:
		return
	if Time.get_ticks_msec() >= _knockback_end_ms:
		_end_knockback()

## 结束击退效果
func _end_knockback() -> void:
	is_knockback_active = false
	knockback_velocity = Vector2.ZERO
	
	# 返回到移动或空闲状态
	if current_state == CharacterState.KNOCKBACK:
		var input_dir = _get_input_direction()
		if input_dir != Vector2.ZERO:
			_change_state(CharacterState.MOVING)
		else:
			_change_state(CharacterState.IDLE)

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

# ========== 升级系统 ==========

## 获取基础属性（供 RunManager 使用）
func get_base_stats() -> CharacterStats:
	return base_stats

## 获取当前属性（供 RunManager 使用）
func get_current_stats() -> CharacterStats:
	return current_stats

## 应用升级（由 RunManager 调用）
func apply_upgrades(run_manager: Node) -> void:
	if not base_stats or not current_stats:
		return
	
	# 先重置到基础值
	current_stats = base_stats.duplicate_stats()
	
	# 应用通用属性升级（所有角色都拥有的基础属性）
	_apply_common_upgrades(run_manager)
	
	# 应用闪避属性升级
	_apply_dodge_upgrades(run_manager)
	
	# 应用特殊属性升级
	_apply_special_upgrades(run_manager)
	
	# 应用非通用属性升级（由子类重写实现）
	_apply_custom_upgrades(run_manager)
	
	# 应用圣遗物属性加成
	_apply_artifact_bonuses()
	
	# 同步属性到角色
	_sync_stats_to_character()
	
	print("角色升级已应用：", current_stats.get_summary())

## 应用通用属性升级（所有角色都拥有的基础属性）
func _apply_common_upgrades(run_manager: Node) -> void:
	for stat_config in COMMON_UPGRADE_STATS:
		var property_name = stat_config.get("property")
		var target_stat = stat_config.get("target_stat")
		_apply_stat_upgrade(run_manager, property_name, target_stat)

## 应用非通用属性升级（由子类重写实现）
## 子类可以重写此方法来实现角色专属的升级逻辑
## 例如：技能伤害、大招充能、特殊效果等
func _apply_custom_upgrades(_run_manager: Node) -> void:
	pass  # 默认不处理，由子类重写

## 应用单个属性升级
func _apply_stat_upgrade(run_manager: Node, property_name: String, target_stat: int) -> void:
	# Resource/Script 的属性不能用 `"x" in obj` 判断；改用属性列表枚举（Godot 4.x 推荐做法）
	var has_prop := false
	for prop in base_stats.get_property_list():
		if prop.name == property_name:
			has_prop = true
			break
	if not has_prop:
		return
	
	var base_value = base_stats.get(property_name)
	var final_value = run_manager.calculate_final_stat(base_value, target_stat)
	
	# 特殊处理：防御和暴击率需要限制范围
	if property_name == "defense_percent" or property_name == "crit_rate":
		final_value = clamp(final_value, 0.0, 1.0)
	
	current_stats.set(property_name, final_value)

## 应用闪避属性升级
func _apply_dodge_upgrades(run_manager: Node) -> void:
	# 闪避距离
	var dodge_dist_flat = run_manager.get_stat_flat_bonus(UpgradeData.TargetStat.DODGE_DISTANCE)
	var dodge_dist_percent = run_manager.get_stat_percent_bonus(UpgradeData.TargetStat.DODGE_DISTANCE)
	# 以当前配置值作为“基础值”，避免对 CharacterData 做不存在字段的字典式访问
	var base_dodge_distance := dodge_distance
	dodge_distance = (base_dodge_distance + dodge_dist_flat) * (1.0 + dodge_dist_percent)
	
	# 闪避冷却
	var dodge_cd_flat = run_manager.get_stat_flat_bonus(UpgradeData.TargetStat.DODGE_COOLDOWN)
	var dodge_cd_percent = run_manager.get_stat_percent_bonus(UpgradeData.TargetStat.DODGE_COOLDOWN)
	var base_dodge_cooldown := dodge_cooldown
	dodge_cooldown = max(0.1, (base_dodge_cooldown + dodge_cd_flat) * (1.0 + dodge_cd_percent))
	
	# 无敌时间
	var invincibility_flat = run_manager.get_stat_flat_bonus(UpgradeData.TargetStat.INVINCIBILITY_DURATION)
	var base_invincibility := invincibility_duration
	invincibility_duration = base_invincibility + invincibility_flat

## 应用特殊属性升级
func _apply_special_upgrades(run_manager: Node) -> void:
	# 充能效率（通用升级）
	var energy_gain_bonus = run_manager.get_stat_percent_bonus(UpgradeData.TargetStat.ENERGY_GAIN)
	energy_gain_multiplier = 1.0 + energy_gain_bonus

## 同步属性到角色实际数值
func _sync_stats_to_character() -> void:
	if not current_stats:
		return
	
	# 计算生命值变化比例
	var old_max_health = max_health
	var health_ratio = 1.0
	if old_max_health > 0:
		health_ratio = current_health / old_max_health
	
	# 更新最大生命值
	max_health = current_stats.max_health
	
	# 按比例调整当前血量
	current_health = max_health * health_ratio
	
	# 更新移动速度
	base_move_speed = current_stats.move_speed
	move_speed = base_move_speed
	
	# 更新击退力度
	knockback_force = current_stats.knockback_force
	
	# 发出血量变化信号
	emit_signal("health_changed", current_health, max_health)

## 获取技能冷却倍率（1.0 - 减少比例）
func get_skill_cooldown_multiplier() -> float:
	if RunManager:
		var bonus = RunManager.get_stat_percent_bonus(UpgradeData.TargetStat.SKILL_COOLDOWN)
		return max(0.1, 1.0 + bonus)  # bonus 是负数
	return 1.0

## 获取技能范围倍率
func get_skill_radius_multiplier() -> float:
	if RunManager:
		var bonus = RunManager.get_stat_percent_bonus(UpgradeData.TargetStat.SKILL_RADIUS)
		return 1.0 + bonus
	return 1.0

## 获取充能效率倍率（通用升级）
func get_energy_gain_multiplier() -> float:
	return energy_gain_multiplier

# ========== 状态查询方法（供外部使用） ==========

## 获取当前状态名称
func get_current_state() -> String:
	match current_state:
		CharacterState.IDLE:
			return "Idle"
		CharacterState.MOVING:
			return "Move"
		CharacterState.ATTACKING:
			return "Attack"
		CharacterState.DODGING:
			return "Dodge"
		CharacterState.KNOCKBACK:
			return "Knockback"
		CharacterState.DEAD:
			return "Dead"
	return ""

## 检查是否处于指定状态
func is_in_state(state_name: String) -> bool:
	return get_current_state() == state_name

## 检查是否正在攻击
func is_attacking() -> bool:
	return current_state == CharacterState.ATTACKING

## 检查是否正在闪避
func is_dodging() -> bool:
	return current_state == CharacterState.DODGING

## 检查是否可以移动
func can_move() -> bool:
	return current_state == CharacterState.IDLE or current_state == CharacterState.MOVING

## 检查是否可以闪避
func can_dodge() -> bool:
	return can_move() and _is_dodge_ready()

# ========== 圣遗物系统 ==========

## 应用圣遗物属性加成
func _apply_artifact_bonuses() -> void:
	if not artifact_manager or not current_stats:
		return
	
	var bonuses: Dictionary = artifact_manager.apply_stat_bonuses()
	if bonuses.is_empty():
		return
	
	# 统一交给 CharacterStats 处理，避免在角色脚本里维护“加成规则”
	current_stats.apply_bonuses(bonuses)
	
	# 打印圣遗物加成信息（调试用）
	if not bonuses.is_empty():
		var bonus_summary = []
		for stat_name in bonuses:
			if stat_name == "attack_percent":
				bonus_summary.append("攻击力百分比: +%.1f%%" % (bonuses[stat_name] * 100.0))
			else:
				bonus_summary.append("%s: %+.1f" % [stat_name, bonuses[stat_name]])
		print("圣遗物加成已应用：", ", ".join(bonus_summary))

## 获取圣遗物管理器
func get_artifact_manager() -> ArtifactManager:
	return artifact_manager

## 装备圣遗物到指定槽位
func equip_artifact(slot: ArtifactSlot.SlotType, artifact: ArtifactData) -> bool:
	if not artifact_manager:
		return false
	
	var success = artifact_manager.equip_artifact(slot, artifact)
	if success:
		# 通过RunManager重新应用所有升级（包括圣遗物）
		if RunManager:
			apply_upgrades(RunManager)
		else:
			# 如果没有RunManager，直接重新应用圣遗物加成
			_apply_artifact_bonuses()
			_sync_stats_to_character()
	return success

## 卸载指定槽位的圣遗物
func unequip_artifact(slot: ArtifactSlot.SlotType) -> bool:
	if not artifact_manager:
		return false
	
	var success = artifact_manager.unequip_artifact(slot)
	if success:
		# 通过RunManager重新应用所有升级（包括圣遗物）
		if RunManager:
			apply_upgrades(RunManager)
		else:
			# 如果没有RunManager，直接重新应用圣遗物加成
			if base_stats:
				current_stats = base_stats.duplicate_stats()
			_apply_artifact_bonuses()
			_sync_stats_to_character()
	return success
