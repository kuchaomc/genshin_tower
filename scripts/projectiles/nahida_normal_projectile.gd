extends Area2D
class_name NahidaNormalProjectile

# 纳西妲普攻投射物：绿色光点（不依赖贴图），朝指定方向飞行。
# 命中敌人后：由 owner_character 统一结算伤害，并请求敌人进入僵直，然后自身销毁。

@export var speed: float = 520.0
@export var lifetime: float = 3.0

# 视觉参数（后续可用于升级：更大光点/更亮光晕/更改颜色等）
@export var dot_radius: float = 4.5
@export var glow_radius: float = 14.0
@export var dot_color: Color = Color(0.15, 1.0, 0.25, 1.0)
@export var glow_color: Color = Color(0.15, 1.0, 0.25, 0.22)

# 尾迹：飞行时“飘洒”的绿色小粒子（不依赖贴图）
@export var trail_enabled: bool = true
@export var trail_spawn_rate: float = 28.0
@export var trail_max_particles: int = 90
@export var trail_lifetime: float = 0.20
@export var trail_radius_min: float = 0.7
@export var trail_radius_max: float = 1.4
@export var trail_speed_min: float = 55.0
@export var trail_speed_max: float = 140.0
@export var trail_spread_degrees: float = 56.0
@export var trail_drift_speed: float = 26.0
@export var trail_damping: float = 9.0
@export var trail_dot_color: Color = Color(0.35, 1.0, 0.45, 0.70)
@export var trail_glow_color: Color = Color(0.35, 1.0, 0.45, 0.12)
@export var trail_glow_scale: float = 1.8

# 伤害倍率（走 BaseCharacter.deal_damage_to）
@export var damage_multiplier: float = 1.0

# 由发射者在实例化后设置（通常为“鼠标方向”的单位向量）
var direction: Vector2 = Vector2.RIGHT
# 发射者角色（用于统一伤害计算、飘字、命中音效等）
var owner_character: BaseCharacter = null

# 命中去重：避免同一帧多次触发（Area + Body 回调等）
var _hit_enemies: Array[Node2D] = []

class TrailParticle:
	var global_pos: Vector2
	var velocity: Vector2
	var age: float
	var lifetime: float
	var radius: float

var _trail_particles: Array[TrailParticle] = []
var _trail_spawn_accum: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	# 约定：第2层=敌人(Enemies)。投射物只检测敌人层。
	collision_mask = 2
	monitoring = true
	monitorable = true

	_rng.randomize()

	# 立即刷新一次绘制
	queue_redraw()

	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)


func _draw() -> void:
	# 尾迹粒子（先画，避免盖住核心光点）
	if trail_enabled and not _trail_particles.is_empty():
		for p in _trail_particles:
			var t: float = 0.0
			if p.lifetime > 0.0:
				t = clampf(p.age / p.lifetime, 0.0, 1.0)
			var a := 1.0 - t
			var local_pos := to_local(p.global_pos)
			var gcol := Color(trail_glow_color.r, trail_glow_color.g, trail_glow_color.b, trail_glow_color.a * a)
			var dcol := Color(trail_dot_color.r, trail_dot_color.g, trail_dot_color.b, trail_dot_color.a * a)
			if trail_glow_scale > 0.0 and gcol.a > 0.0:
				draw_circle(local_pos, p.radius * trail_glow_scale, gcol)
			if p.radius > 0.0 and dcol.a > 0.0:
				draw_circle(local_pos, p.radius, dcol)

	if glow_radius > 0.0 and glow_color.a > 0.0:
		draw_circle(Vector2.ZERO, glow_radius, glow_color)
	if dot_radius > 0.0:
		draw_circle(Vector2.ZERO, dot_radius, dot_color)

func _physics_process(delta: float) -> void:
	if direction == Vector2.ZERO:
		return

	_update_trail(delta)
	global_position += direction * speed * delta
	if trail_enabled:
		queue_redraw()


func _update_trail(delta: float) -> void:
	if not trail_enabled:
		if not _trail_particles.is_empty():
			_trail_particles.clear()
		return

	if trail_spawn_rate > 0.0:
		_trail_spawn_accum += delta
		var interval := 1.0 / trail_spawn_rate
		while _trail_spawn_accum >= interval:
			_trail_spawn_accum -= interval
			_spawn_trail_particle()

	# 更新粒子（倒序便于删除）
	for i in range(_trail_particles.size() - 1, -1, -1):
		var p := _trail_particles[i]
		p.age += delta
		if p.age >= p.lifetime:
			_trail_particles.remove_at(i)
			continue

		p.global_pos += p.velocity * delta
		# 简单阻尼：逐渐慢下来，模拟“飘洒”
		p.velocity = p.velocity.move_toward(Vector2.ZERO, trail_damping * delta)

	# 上限控制：避免粒子过多
	while _trail_particles.size() > trail_max_particles:
		_trail_particles.pop_front()


func _spawn_trail_particle() -> void:
	var p := TrailParticle.new()
	p.age = 0.0
	p.lifetime = maxf(0.01, trail_lifetime)
	p.radius = _rng.randf_range(trail_radius_min, trail_radius_max)

	# 生成点略落后于核心光点，形成尾迹
	var back_dir := -direction
	if back_dir == Vector2.ZERO:
		back_dir = Vector2.LEFT
	var spread := deg_to_rad(trail_spread_degrees)
	var ang := _rng.randf_range(-spread, spread)
	var vel_dir := back_dir.rotated(ang)
	var base_speed := _rng.randf_range(trail_speed_min, trail_speed_max)
	var drift := Vector2(_rng.randf_range(-trail_drift_speed, trail_drift_speed), _rng.randf_range(-trail_drift_speed, trail_drift_speed))

	p.global_pos = global_position + back_dir * _rng.randf_range(2.0, 6.0)
	p.velocity = vel_dir * base_speed + drift

	_trail_particles.append(p)

func _on_area_entered(area: Area2D) -> void:
	_handle_enemy_collision(area)

func _on_body_entered(body: Node2D) -> void:
	_handle_enemy_collision(body)

func _handle_enemy_collision(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	if not enemy.is_in_group("enemies"):
		return
	if enemy in _hit_enemies:
		return
	_hit_enemies.append(enemy)

	if is_instance_valid(owner_character):
		# 普攻：不击退，仅请求僵直（由敌人自身 take_damage / apply_stun_effect 处理）
		owner_character.deal_damage_to(enemy, damage_multiplier, false, false, false, true)

	# 普攻大粒子：命中后销毁（视觉更符合“一个大粒子”）
	queue_free()
