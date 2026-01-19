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
var warning_sprite: Sprite2D
var collision_shape: CollisionShape2D
var knockback_tween: Tween
var is_knockback_active: bool = false

# 碰撞/接触伤害节流，避免连续帧内多次结算
@export var contact_damage_cooldown: float = 0.6
var _recently_damaged_bodies: Dictionary = {}

# ========== 状态 ==========
var is_spawned: bool = false
var is_dead: bool = false

## 初始化敌人
func initialize(data: EnemyData) -> void:
	enemy_data = data
	
	# 初始化属性系统
	if data.stats:
		base_stats = data.stats
		current_stats = data.stats.duplicate_stats()
	else:
		# 兼容旧版数据：从旧字段创建属性
		base_stats = EnemyStats.new()
		base_stats.max_health = data.max_health
		base_stats.move_speed = data.move_speed
		base_stats.attack = data.damage
		current_stats = base_stats.duplicate_stats()
	
	# 应用属性到敌人
	_apply_stats_to_enemy()
	warning_duration = data.warning_duration
	
	print("敌人初始化：", data.display_name, " | ", current_stats.get_summary())

## 从当前属性应用到敌人实际数值
func _apply_stats_to_enemy() -> void:
	if not current_stats:
		return
	max_health = current_stats.max_health
	current_health = max_health

func _ready() -> void:
	# 碰撞层约定：第1层=墙(Walls)，第2层=敌人(Enemies)
	# 敌人本体放到“敌人层”，避免和墙层混用，方便玩家在闪避时只碰墙
	collision_layer = 2
	# 敌人需要：
	# - 与墙碰撞（不穿出空气墙）=> +1
	# - 与玩家碰撞（用于接触伤害/阻挡）=> +4（玩家层）
	# 合计：1 + 4 = 5
	collision_mask = 5
	
	# 如果没有通过 initialize 初始化，创建默认属性
	if current_stats == null:
		current_stats = EnemyStats.new()
		current_stats.max_health = max_health
		base_stats = current_stats.duplicate_stats()
	
	current_health = max_health
	
	# 获取组件引用
	hp_bar = get_node_or_null("HPBar/ProgressBar") as ProgressBar
	hp_label = get_node_or_null("HPBar/Label") as Label
	hp_bar_container = get_node_or_null("HPBar") as Node2D
	animated_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	
	# 创建警告图标
	_create_warning_sprite()
	
	# 隐藏敌人本体
	_set_enemy_visible(false)
	
	# 启动警告计时器
	var timer = get_tree().create_timer(warning_duration)
	timer.timeout.connect(_on_warning_finished)

## 创建警告图标
func _create_warning_sprite() -> void:
	warning_sprite = Sprite2D.new()
	var warning_texture = load("res://textures/warning.png")
	if warning_texture:
		warning_sprite.texture = warning_texture
		warning_sprite.z_index = 10
		add_child(warning_sprite)
	else:
		print("警告：无法加载warning.png")

## 设置敌人本体可见性
func _set_enemy_visible(visible_state: bool) -> void:
	if animated_sprite:
		animated_sprite.visible = visible_state
	if hp_bar_container:
		hp_bar_container.visible = visible_state
	if collision_shape:
		collision_shape.disabled = not visible_state

## 警告结束回调
func _on_warning_finished() -> void:
	is_spawned = true
	
	if warning_sprite:
		warning_sprite.queue_free()
		warning_sprite = null
	
	_set_enemy_visible(true)
	update_hp_display()
	
	print("敌人生成，生命值: ", current_health, "/", max_health)

func _physics_process(delta: float) -> void:
	if not is_spawned or is_dead:
		velocity = Vector2.ZERO
		return
	
	# 执行AI行为（子类可重写）
	perform_ai_behavior(delta)
	
	if is_knockback_active:
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
		
		# 如果撞到空气墙/静态障碍，滑动并轻推离开，避免卡住
		if collider is StaticBody2D:
			var n: Vector2 = collision.get_normal()
			if n != Vector2.ZERO:
				velocity = velocity.slide(n)
				global_position += n * 2.0
			continue
		
		_handle_body_collision(collider)

## 执行AI行为（子类实现）
func perform_ai_behavior(delta: float) -> void:
	# 默认行为：追逐玩家
	chase_player(delta)

## 追逐玩家（默认行为）
func chase_player(delta: float) -> void:
	if is_knockback_active:
		velocity = Vector2.ZERO
		return
	
	var player = get_tree().current_scene.get_node_or_null("player") as CharacterBody2D
	if not player:
		player = get_node_or_null("../player") as CharacterBody2D
	
	if player:
		var direction = (player.global_position - global_position).normalized()
		var speed = get_move_speed()
		
		# 根据移动方向翻转精灵图
		if animated_sprite:
			if direction.x < 0:
				animated_sprite.flip_h = true
			else:
				animated_sprite.flip_h = false
		
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO

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
	for method in obj.get_method_list():
		if method["name"] == method_name:
			return method["args"].size() >= param_count
	return false

## 获取移动速度（子类可重写）
func get_move_speed() -> float:
	if enemy_data:
		return enemy_data.move_speed
	return 100.0

## 更新HP显示
func update_hp_display() -> void:
	if hp_bar:
		hp_bar.max_value = max_health
		hp_bar.value = current_health
	if hp_label:
		hp_label.text = str(int(current_health)) + "/" + str(int(max_health))

## 受到伤害（应用自身减伤）
func take_damage(damage_amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if not is_spawned or is_dead:
		return
	
	# 应用减伤计算
	var actual_damage = damage_amount
	if current_stats:
		actual_damage = current_stats.calculate_damage_taken(damage_amount)
	
	current_health -= actual_damage
	current_health = max(0, current_health)
	
	update_hp_display()
	
	print("敌人受到伤害: ", actual_damage, "点（原始: ", damage_amount, "），剩余生命值: ", current_health, "/", max_health)
	
	if knockback != Vector2.ZERO:
		apply_knockback(knockback)
	
	if current_health <= 0:
		on_death()

## 获取减伤比例（供攻击者调用）
func get_defense_percent() -> float:
	if current_stats:
		return current_stats.defense_percent
	return 0.0

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

## 死亡处理
func on_death() -> void:
	if is_dead:
		return
	
	is_dead = true
	print("敌人死亡")
	
	# 记录击杀
	if RunManager:
		RunManager.record_enemy_kill()
	
	# 掉落金币
	if enemy_data:
		var gold = enemy_data.drop_gold
		if RunManager:
			RunManager.add_gold(gold)
	
	# 删除敌人节点
	queue_free()

## 身体进入回调函数（检测与玩家的碰撞）
func _on_body_entered(body: Node2D) -> void:
	if not is_spawned or is_dead:
		return
	
	if body is CharacterBody2D:
		print("敌人撞到玩家")
		if body.has_method("take_damage"):
			var damage = get_damage()
			body.take_damage(damage)

## 获取伤害值（子类可重写）
func get_damage() -> float:
	if enemy_data:
		return enemy_data.damage
	return 25.0
