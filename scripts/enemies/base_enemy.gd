extends CharacterBody2D
class_name BaseEnemy

## 敌人基类
## 包含所有敌人的通用逻辑（移动、血量、AI行为等）

# ========== 敌人数据 ==========
var enemy_data: EnemyData = null

# ========== 属性系统 ==========
## 基础属性（来自 EnemyData，不可修改）
var base_stats: EnemyStats = null
## 当前属性（运行时可被 buff/debuff 修改）
var current_stats: EnemyStats = null

# ========== 抗性/减伤变更（debuff） ==========
# 说明：当前项目将 EnemyStats.defense_percent 作为“伤害减免/抗性”。
# 纳西妲 Q 会降低该值，从而让敌人受到更多伤害。
var _resistance_reduction_by_source_id: Dictionary = {}
var _original_defense_percent: float = 0.0

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
var sprite_2d: Sprite2D  # 静态贴图精灵（用于BOSS等）
var warning_sprite: Sprite2D
var collision_shape: CollisionShape2D
var knockback_tween: Tween
var is_knockback_active: bool = false

# 警告贴图缓存：避免每个敌人生成时重复取资源
static var _cached_warning_texture: Texture2D = null

# ========== 僵直系统 ==========
var is_stunned: bool = false
var stun_timer: float = 0.0
@export var stun_duration: float = 0.3  # 僵直持续时间（秒）

# ========== 冻结系统 ==========
var is_frozen: bool = false
var freeze_timer: float = 0.0
@export var freeze_tint: Color = Color(0.55, 0.8, 1.0, 1.0)
var _original_modulate_animated: Color = Color.WHITE
var _original_modulate_sprite: Color = Color.WHITE
var _freeze_paused_animation: bool = false
var _anim_speed_scale_before_freeze: float = 1.0

# 碰撞/接触伤害节流，避免连续帧内多次结算
@export var contact_damage_cooldown: float = 0.6
var _recently_damaged_bodies: Dictionary = {}
# 反射方法签名缓存：避免频繁 get_method_list() 带来的开销
var _method_param_count_cache: Dictionary = {}

# ========== 状态 ==========
var is_spawned: bool = false
var is_dead: bool = false

# 首次入树标记：用于对象池（预热实例第一次入树时避免重复启动生成流程）
var _has_ready_run: bool = false

# 玩家引用缓存：避免每帧 get_node/get_tree 的全树查找
var _cached_player: CharacterBody2D = null
var _player_lookup_timer: float = 0.0
const _PLAYER_LOOKUP_INTERVAL: float = 0.5

## 初始化敌人
func initialize(data: EnemyData) -> void:
	enemy_data = data
	
	# 初始化属性系统
	base_stats = data.get_stats()
	current_stats = base_stats.duplicate_stats()
	_original_defense_percent = current_stats.defense_percent if current_stats else 0.0
	_resistance_reduction_by_source_id.clear()
	_reapply_resistance_reduction()
	
	# 应用属性到敌人
	_apply_stats_to_enemy()
	warning_duration = data.warning_duration
	
	if OS.is_debug_build():
		print("敌人初始化：", data.display_name, " | ", current_stats.get_summary())

## 从当前属性应用到敌人实际数值
func _apply_stats_to_enemy() -> void:
	if not current_stats:
		return
	max_health = current_stats.max_health
	current_health = max_health

func _ready() -> void:
	# 统一敌人分组：供 UI/战斗逻辑识别
	add_to_group("enemies")
	
	# 碰撞层约定（bitmask）：
	# - 1: Walls   => 1
	# - 2: Enemies => 2
	# - 4: Player  => 8
	# 敌人本体放到“敌人层”，避免和墙层混用，方便玩家在闪避时只碰墙
	collision_layer = 2
	# 敌人需要：
	# - 与墙碰撞（不穿出空气墙）=> +1
	# - 与敌人碰撞（避免挤在一起）=> +2（敌人层）
	# - 与玩家碰撞（用于接触伤害/阻挡）=> +8（玩家层，bitmask）
	# 合计：1 + 2 + 8 = 11
	collision_mask = 11
	
	# 如果没有通过 initialize 初始化，创建默认属性
	if current_stats == null:
		current_stats = EnemyStats.new()
		current_stats.max_health = max_health
		base_stats = current_stats.duplicate_stats()
		_original_defense_percent = current_stats.defense_percent
		_resistance_reduction_by_source_id.clear()
		_reapply_resistance_reduction()
	
	current_health = max_health
	
	# 获取组件引用
	hp_bar = get_node_or_null("HPBar/ProgressBar") as ProgressBar
	hp_label = get_node_or_null("HPBar/Label") as Label
	hp_bar_container = get_node_or_null("HPBar") as Node2D
	animated_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	sprite_2d = get_node_or_null("Sprite2D") as Sprite2D
	collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	
	# 记录初始颜色：用于冻结“变蓝”指示，解冻后能正确恢复
	if animated_sprite:
		_original_modulate_animated = animated_sprite.modulate
	if sprite_2d:
		_original_modulate_sprite = sprite_2d.modulate
	
	# 创建警告图标
	_create_warning_sprite()
	
	# 隐藏敌人本体
	_set_enemy_visible(false)
	
	# 启动警告计时器
	var timer = get_tree().create_timer(warning_duration)
	timer.timeout.connect(_on_warning_finished)
	_has_ready_run = true

## 创建警告图标
func _create_warning_sprite() -> void:
	warning_sprite = Sprite2D.new()
	var warning_texture: Texture2D = _get_warning_texture()
	
	if warning_texture:
		warning_sprite.texture = warning_texture
		warning_sprite.z_index = 10
		add_child(warning_sprite)
	else:
		push_warning("警告：无法加载 warning.png")

func _get_warning_texture() -> Texture2D:
	if _cached_warning_texture:
		return _cached_warning_texture
	if DataManager:
		_cached_warning_texture = DataManager.get_texture("res://textures/effects/warning.png")
	else:
		_cached_warning_texture = load("res://textures/effects/warning.png") as Texture2D
	return _cached_warning_texture

## 设置敌人本体可见性
func _set_enemy_visible(visible_state: bool) -> void:
	if animated_sprite:
		animated_sprite.visible = visible_state
	if sprite_2d:
		sprite_2d.visible = visible_state
	if hp_bar_container:
		hp_bar_container.visible = visible_state
	if collision_shape:
		# 可能在物理查询刷新期间（flushing queries）被调用，必须使用 set_deferred
		collision_shape.set_deferred("disabled", not visible_state)

## 警告结束回调
func _on_warning_finished() -> void:
	is_spawned = true
	
	if warning_sprite:
		warning_sprite.queue_free()
		warning_sprite = null
	
	_set_enemy_visible(true)
	update_hp_display()
	
	if OS.is_debug_build():
		print("敌人生成，生命值: ", current_health, "/", max_health)

func _physics_process(delta: float) -> void:
	if not is_spawned or is_dead:
		velocity = Vector2.ZERO
		return
	
	# 更新僵直计时器
	if is_stunned:
		stun_timer -= delta
		if stun_timer <= 0.0:
			is_stunned = false
			stun_timer = 0.0
	
	# 更新冻结计时器
	if is_frozen:
		freeze_timer -= delta
		if freeze_timer <= 0.0:
			is_frozen = false
			freeze_timer = 0.0
			_clear_freeze_animation()
			_clear_freeze_visual()
		else:
			_apply_freeze_visual()
			# 冻结期间：不执行AI、不移动（确保冻结确实“控住敌人”）
			velocity = Vector2.ZERO
			_process_collisions(delta)
			return
	
	# 执行AI行为（子类可重写）
	perform_ai_behavior(delta)
	
	if is_knockback_active or is_stunned or is_frozen:
		velocity = Vector2.ZERO
	else:
		move_and_slide()
	_process_collisions(delta)

## 处理移动后的碰撞结果（用于对玩家造成碰撞伤害）
func _process_collisions(delta: float) -> void:
	# 更新伤害冷却计时
	var expired: Array = []
	for body in _recently_damaged_bodies.keys():
		if not is_instance_valid(body):
			expired.append(body)
			continue
		_recently_damaged_bodies[body] -= delta
		if _recently_damaged_bodies[body] <= 0.0:
			expired.append(body)
	for key in expired:
		_recently_damaged_bodies.erase(key)
	
	# 处理本帧碰撞
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if not collision:
			continue
		var collider = collision.get_collider()
		
		# 如果撞到空气墙/静态障碍，给一个反弹力
		if collider is StaticBody2D:
			var n: Vector2 = collision.get_normal()
			if n != Vector2.ZERO:
				# 反弹力：沿着法向量方向反弹，力度为当前速度的反弹系数
				var bounce_strength: float = 1  # 反弹系数，0-1之间
				var bounce_velocity: Vector2 = -velocity.project(n) * bounce_strength
				velocity = velocity.slide(n) + bounce_velocity
				# 轻微推离边界，避免卡住
				global_position += n * 2.0
			continue
		
		_handle_body_collision(collider)

## 执行AI行为（子类实现）
func perform_ai_behavior(delta: float) -> void:
	# 默认行为：追逐玩家
	chase_player(delta)

## 追逐玩家（默认行为）
func chase_player(delta: float) -> void:
	if is_knockback_active or is_stunned or is_frozen:
		velocity = Vector2.ZERO
		return
	
	# 玩家引用缓存：降低敌人数量较多时的树查找开销
	_player_lookup_timer -= delta
	if not is_instance_valid(_cached_player) or _player_lookup_timer <= 0.0:
		_cached_player = _find_player()
		_player_lookup_timer = _PLAYER_LOOKUP_INTERVAL

	if _cached_player:
		var direction = (_cached_player.global_position - global_position).normalized()
		var speed = get_move_speed()
		
		# 根据移动方向翻转精灵图
		if animated_sprite:
			if direction.x < 0:
				animated_sprite.flip_h = false
			else:
				animated_sprite.flip_h = true
		elif sprite_2d:
			if direction.x < 0:
				sprite_2d.flip_h = false
			else:
				sprite_2d.flip_h = true
		
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO

func _find_player() -> CharacterBody2D:
	# 优先使用相对路径（敌人通常与 player 同级）
	var p := get_node_or_null("../player") as CharacterBody2D
	if p:
		return p
	
	# 兜底：从当前场景根查找（避免每帧调用，外层有间隔）
	var tree := get_tree()
	if tree and tree.current_scene:
		p = tree.current_scene.get_node_or_null("player") as CharacterBody2D
		if p:
			return p
	
	# 最后兜底：通过 BattleManager 获取
	if tree:
		var battle_manager = tree.get_first_node_in_group("battle_manager")
		if battle_manager and battle_manager.has_method("get_player"):
			return battle_manager.get_player() as CharacterBody2D
	return null

## 碰撞到玩家时造成伤害（带冷却，避免每帧重复结算）
func _handle_body_collision(body: Node) -> void:
	if not is_instance_valid(body):
		return
	if not (body is CharacterBody2D):
		return
	# 只对玩家造成接触伤害，避免敌人之间互相碰撞掉血
	if (body as Node).name != "player":
		return
	if not body.has_method("take_damage"):
		return
	
	# 记录最后伤害来源：用于玩家死亡后展示“被某某击败”CG
	if RunManager and enemy_data:
		RunManager.set_last_defeated_by_enemy(enemy_data.id, enemy_data.display_name)
	
	if _recently_damaged_bodies.has(body):
		return
	
	var damage = get_damage()
	# 计算击退方向（从敌人指向玩家）
	var knockback_direction = (body.global_position - global_position).normalized()
	# 击退距离（像素，可按需调大/调小）
	var knockback_force_value = 50.0
	
	# 检查take_damage方法是否支持击退参数
	if _can_call_with_params(body, "take_damage", 3):
		body.take_damage(damage, knockback_direction, knockback_force_value)
	else:
		body.take_damage(damage)
	
	_recently_damaged_bodies[body] = contact_damage_cooldown

## 检查方法是否支持指定数量的参数
func _can_call_with_params(obj: Object, method_name: String, param_count: int) -> bool:
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

## 获取移动速度（子类可重写）
func get_move_speed() -> float:
	if current_stats:
		return current_stats.move_speed
	return 100.0

## 更新HP显示
func update_hp_display() -> void:
	if hp_bar:
		hp_bar.max_value = max_health
		hp_bar.value = current_health
	if hp_label:
		hp_label.text = str(int(current_health)) + "/" + str(int(max_health))

## 受到伤害（应用自身减伤）
## knockback: 击退方向向量（如果为 Vector2.ZERO 则不击退）
## apply_stun: 是否应用僵直效果（默认 false）
func take_damage(damage_amount: float, knockback: Vector2 = Vector2.ZERO, apply_stun: bool = false) -> void:
	if not is_spawned or is_dead:
		return
	
	# 应用减伤计算
	var actual_damage = damage_amount
	if current_stats:
		actual_damage = current_stats.calculate_damage_taken(damage_amount)
	
	current_health -= actual_damage
	current_health = maxf(0.0, current_health)
	
	update_hp_display()
	
	if OS.is_debug_build():
		print("敌人受到伤害: ", actual_damage, "点（原始: ", damage_amount, "），剩余生命值: ", current_health, "/", max_health)
	
	# 应用击退效果（如果提供）
	if knockback != Vector2.ZERO:
		apply_knockback(knockback)
	
	# 应用僵直效果（如果请求）
	if apply_stun:
		apply_stun_effect()
	
	if current_health <= 0:
		on_death()

## 获取减伤比例（供攻击者调用）
func get_defense_percent() -> float:
	if current_stats:
		return current_stats.defense_percent
	return 0.0


## 施加“抗性降低/减伤降低”（可叠加，多来源共存）
## source_id: 来源唯一ID（例如领域节点 instance_id）
## amount: 0~1，表示降低多少 defense_percent
func apply_resistance_reduction(source_id: int, amount: float) -> void:
	if source_id == 0:
		return
	if amount <= 0.0:
		return
	_resistance_reduction_by_source_id[source_id] = clampf(amount, 0.0, 1.0)
	_reapply_resistance_reduction()


## 移除某个来源的“抗性降低/减伤降低”
func remove_resistance_reduction(source_id: int) -> void:
	if source_id == 0:
		return
	if not _resistance_reduction_by_source_id.has(source_id):
		return
	_resistance_reduction_by_source_id.erase(source_id)
	_reapply_resistance_reduction()


func _reapply_resistance_reduction() -> void:
	if current_stats == null:
		return
	var total: float = 0.0
	for v in _resistance_reduction_by_source_id.values():
		total += float(v)
	# 最低保底：不让 defense_percent 变成负数；总降低也做上限避免极端值
	total = clampf(total, 0.0, 0.95)
	current_stats.defense_percent = maxf(0.0, _original_defense_percent - total)

## 施加击退效果
func apply_knockback(knockback_offset: Vector2, duration: float = 0.12) -> void:
	if is_dead or knockback_offset == Vector2.ZERO:
		return
	
	# 结束旧的击退
	if knockback_tween:
		knockback_tween.kill()
	
	is_knockback_active = true
	knockback_tween = create_tween()
	knockback_tween.set_ease(Tween.EASE_OUT)
	knockback_tween.set_trans(Tween.TRANS_SINE)
	knockback_tween.tween_property(self, "global_position", global_position + knockback_offset, duration)
	knockback_tween.tween_callback(func ():
		is_knockback_active = false
	)

## 施加僵直效果
func apply_stun_effect(duration: float = -1.0) -> void:
	if is_dead:
		return
	
	# 如果未指定持续时间，使用默认值
	if duration < 0.0:
		duration = stun_duration
	
	is_stunned = true
	stun_timer = duration
	if OS.is_debug_build():
		print("敌人被僵直，持续时间: ", duration, "秒")


func apply_freeze(duration: float = 1.0) -> void:
	if is_dead:
		return
	if duration <= 0.0:
		return
	var was_frozen: bool = is_frozen
	is_frozen = true
	freeze_timer = maxf(freeze_timer, duration)
	if not was_frozen:
		_apply_freeze_animation()
	_apply_freeze_visual()
	if OS.is_debug_build():
		print("敌人被冻结，持续时间: ", duration, "秒")


func _apply_freeze_visual() -> void:
	# 冻结指示：让敌人整体偏蓝（仅做颜色调制，不改贴图资源）
	if animated_sprite:
		animated_sprite.modulate = _original_modulate_animated * freeze_tint
	if sprite_2d:
		sprite_2d.modulate = _original_modulate_sprite * freeze_tint


func _clear_freeze_visual() -> void:
	# 解冻/回收：恢复初始颜色，避免对象池复用后仍保持蓝色
	if animated_sprite:
		animated_sprite.modulate = _original_modulate_animated
	if sprite_2d:
		sprite_2d.modulate = _original_modulate_sprite


func _apply_freeze_animation() -> void:
	# 冻结时暂停动画：保持当前帧不动
	if not animated_sprite:
		return
	if _freeze_paused_animation:
		return
	_anim_speed_scale_before_freeze = animated_sprite.speed_scale
	animated_sprite.speed_scale = 0.0
	_freeze_paused_animation = true


func _clear_freeze_animation() -> void:
	# 解冻/回收：恢复动画播放速度
	if not _freeze_paused_animation:
		return
	_freeze_paused_animation = false
	if not animated_sprite:
		return
	animated_sprite.speed_scale = _anim_speed_scale_before_freeze


func is_frozen_state() -> bool:
	return is_frozen

## 死亡处理
func on_death() -> void:
	if is_dead:
		return
	
	is_dead = true
	_clear_freeze_animation()
	_clear_freeze_visual()
	if DebugLogger:
		DebugLogger.log_debug("敌人死亡", "BaseEnemy")
	
	# 记录击杀
	if RunManager:
		RunManager.record_enemy_kill()
	
	# 通知战斗管理器敌人被击杀（传递分值）
	var score: int = 1  # 默认1分
	if enemy_data:
		score = enemy_data.score_value
	
	var battle_manager: Node = null
	var tree := get_tree()
	if tree:
		var battle_managers = tree.get_nodes_in_group("battle_manager")
		if not battle_managers.is_empty():
			battle_manager = battle_managers[0]
	
	# 掉落摩拉（必须在 on_enemy_killed 之前：胜利时可能清场导致本节点先被移出树）
	if enemy_data and enemy_data.drop_gold > 0:
		_drop_gold(enemy_data.drop_gold)
	
	if enemy_data and enemy_data.enemy_type == "boss":
		_drop_boss_primogems(300, 30)
	else:
		# 掉落原石（10%概率）
		_try_drop_primogems(0.10, 10)
	
	# 通知战斗管理器计分/胜利逻辑
	if battle_manager and battle_manager.has_method("on_enemy_killed"):
		battle_manager.call("on_enemy_killed", score)
	
	# 对象池回收：使用 call_deferred，避免在物理回调中立刻改碰撞/移除节点
	if battle_manager and battle_manager.has_method("recycle_enemy"):
		battle_manager.call_deferred("recycle_enemy", self)
		return
	
	# 兜底：未接入对象池时按原逻辑释放
	queue_free()


## BOSS 固定掉落原石（喷出多个拾取物）
func _drop_boss_primogems(total_amount: int, pieces: int) -> void:
	if total_amount <= 0:
		return
	if pieces <= 0:
		return
	
	# 如果节点已不在场景树中（例如胜利清场/对象池回收），无法实例化掉落，直接给原石
	if not is_inside_tree() or get_tree() == null:
		if RunManager:
			RunManager.add_primogems(total_amount)
		return
	
	# 加载原石场景（使用DataManager缓存）
	var primogem_pickup_scene: PackedScene = null
	if DataManager:
		primogem_pickup_scene = DataManager.get_packed_scene("res://scenes/items/primogem_pickup.tscn")
	else:
		primogem_pickup_scene = load("res://scenes/items/primogem_pickup.tscn") as PackedScene
	
	if not primogem_pickup_scene:
		if RunManager:
			RunManager.add_primogems(total_amount)
		return
	
	var current_scene := get_tree().current_scene
	if not current_scene:
		if RunManager:
			RunManager.add_primogems(total_amount)
		return
	
	# 固定为“每个10原石”，满足 300=30*10 的需求
	var amount_per_piece: int = int(total_amount / pieces)
	if amount_per_piece <= 0:
		amount_per_piece = 1
	
	# 统一随机入口
	var rng: RandomNumberGenerator = null
	if RunManager:
		rng = RunManager.get_rng()
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	
	for i in range(pieces):
		var primogem_pickup = primogem_pickup_scene.instantiate()
		if primogem_pickup and primogem_pickup.has_method("set_primogem_amount"):
			primogem_pickup.set_primogem_amount(amount_per_piece)
			primogem_pickup.global_position = global_position
			current_scene.add_child(primogem_pickup)
			if primogem_pickup.has_method("apply_spawn_spray"):
				var angle := rng.randf_range(0.0, TAU)
				var dist := rng.randf_range(40.0, 160.0)
				var offset := Vector2.RIGHT.rotated(angle) * dist
				primogem_pickup.apply_spawn_spray(offset, 0.18)
		else:
			if RunManager:
				RunManager.add_primogems(amount_per_piece)

## 对象池：准备回收（从树上移除前调用）
func prepare_for_pool() -> void:
	# 彻底禁用本体
	is_spawned = false
	is_dead = true
	velocity = Vector2.ZERO
	
	# 结束击退 tween，避免复用后残留
	if knockback_tween:
		knockback_tween.kill()
		knockback_tween = null
	is_knockback_active = false
	
	# 复位僵直/碰撞伤害状态
	is_stunned = false
	stun_timer = 0.0
	is_frozen = false
	freeze_timer = 0.0
	_clear_freeze_animation()
	_clear_freeze_visual()
	_recently_damaged_bodies.clear()

	# 清理减抗：避免对象池复用后残留
	_resistance_reduction_by_source_id.clear()
	if current_stats:
		current_stats.defense_percent = _original_defense_percent
	
	# 清理警告图标（复用时会重新创建）
	if warning_sprite:
		warning_sprite.queue_free()
		warning_sprite = null

	var seed_mark := get_node_or_null("NahidaSeedMark") as Node
	if seed_mark:
		seed_mark.queue_free()
	
	_set_enemy_visible(false)

## 对象池：复用重置（从池中取出并 add_child 后调用）
func reset_for_reuse() -> void:
	# 预热实例首次入树时 _ready 会负责启动“警告-生成”流程
	if not _has_ready_run:
		return
	
	# 标记为“未生成”，重新走警告流程
	is_dead = false
	is_spawned = false
	velocity = Vector2.ZERO
	_clear_freeze_animation()
	_clear_freeze_visual()
	
	# 复位状态
	is_stunned = false
	stun_timer = 0.0
	is_frozen = false
	freeze_timer = 0.0
	_recently_damaged_bodies.clear()

	# 复位减抗
	_resistance_reduction_by_source_id.clear()
	if current_stats:
		_original_defense_percent = current_stats.defense_percent
	_reapply_resistance_reduction()
	
	# 复位血量（initialize 可能刚刚改过 stats/max_health）
	if current_stats:
		max_health = current_stats.max_health
	current_health = max_health
	update_hp_display()
	
	# 重建警告图标并启动警告计时器
	if warning_sprite:
		warning_sprite.queue_free()
		warning_sprite = null

	var seed_mark := get_node_or_null("NahidaSeedMark") as Node
	if seed_mark:
		seed_mark.queue_free()
	_create_warning_sprite()
	_set_enemy_visible(false)
	var timer = get_tree().create_timer(warning_duration)
	timer.timeout.connect(_on_warning_finished)

## 掉落摩拉
func _drop_gold(amount: int) -> void:
	# 如果节点已不在场景树中（例如胜利清场/对象池回收），无法实例化掉落，直接给金币
	if not is_inside_tree() or get_tree() == null:
		if RunManager:
			RunManager.add_gold(amount)
		return
	
	# 加载摩拉场景（使用DataManager缓存）
	var gold_pickup_scene: PackedScene = null
	if DataManager:
		gold_pickup_scene = DataManager.get_packed_scene("res://scenes/items/gold_pickup.tscn")
	else:
		gold_pickup_scene = load("res://scenes/items/gold_pickup.tscn") as PackedScene
	
	if not gold_pickup_scene:
		# 如果场景不存在，直接添加到RunManager（兼容性处理）
		if RunManager:
			RunManager.add_gold(amount)
		return
	
	# 创建摩拉实例
	var gold_pickup = gold_pickup_scene.instantiate()
	if gold_pickup and gold_pickup.has_method("set_gold_amount"):
		gold_pickup.set_gold_amount(amount)
		gold_pickup.global_position = global_position
		# 添加到场景树
		var current_scene = get_tree().current_scene
		if current_scene:
			current_scene.add_child(gold_pickup)
		else:
			if RunManager:
				RunManager.add_gold(amount)
	else:
		# 如果实例化失败，直接添加到RunManager
		if RunManager:
			RunManager.add_gold(amount)


## 尝试掉落原石
func _try_drop_primogems(drop_chance: float, amount: int) -> void:
	if amount <= 0:
		return
	if drop_chance <= 0.0:
		return

	# 统一随机入口
	var rng: RandomNumberGenerator = null
	if RunManager:
		rng = RunManager.get_rng()
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	if rng.randf() > drop_chance:
		return

	# 如果节点已不在场景树中（例如胜利清场/对象池回收），无法实例化掉落，直接给原石
	if not is_inside_tree() or get_tree() == null:
		if RunManager:
			RunManager.add_primogems(amount)
		return

	# 加载原石场景（使用DataManager缓存）
	var primogem_pickup_scene: PackedScene = null
	if DataManager:
		primogem_pickup_scene = DataManager.get_packed_scene("res://scenes/items/primogem_pickup.tscn")
	else:
		primogem_pickup_scene = load("res://scenes/items/primogem_pickup.tscn") as PackedScene

	if not primogem_pickup_scene:
		if RunManager:
			RunManager.add_primogems(amount)
		return

	var primogem_pickup = primogem_pickup_scene.instantiate()
	if primogem_pickup and primogem_pickup.has_method("set_primogem_amount"):
		primogem_pickup.set_primogem_amount(amount)
		primogem_pickup.global_position = global_position
		var current_scene = get_tree().current_scene
		if current_scene:
			current_scene.add_child(primogem_pickup)
		else:
			if RunManager:
				RunManager.add_primogems(amount)
	else:
		if RunManager:
			RunManager.add_primogems(amount)

## 身体进入回调函数（检测与玩家的碰撞）
func _on_body_entered(body: Node2D) -> void:
	if not is_spawned or is_dead:
		return
	
	if body is CharacterBody2D:
		print("敌人撞到玩家")
		if body.has_method("take_damage"):
			var damage = get_damage()
			# 兼容旧版碰撞伤害入口：同样记录最后伤害来源
			if RunManager and enemy_data:
				RunManager.set_last_defeated_by_enemy(enemy_data.id, enemy_data.display_name)
			body.take_damage(damage)

## 获取伤害值（子类可重写）
func get_damage() -> float:
	if current_stats:
		return current_stats.attack
	return 25.0
