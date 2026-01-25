extends BaseEnemy
class_name Boss1Enemy

## Boss1 行为：蓄力 -> 直线冲撞 -> 冷却；三次冲撞后力竭；半血强制追击

signal health_changed(current: float, maximum: float)
signal action_changed(action: String)

enum BossState {
	CHARGING,
	DASHING,
	RECOVERING,
	EXHAUSTED,
	CHASING,
}

@export var charge_duration: float = 1.5
@export var dash_speed: float = 900.0
@export var dash_max_distance: float = 1200.0
@export var dash_stop_distance: float = 24.0
@export var recover_duration: float = 1.0
@export var exhaust_duration: float = 10.0
@export var chase_duration: float = 5.0

@export var warning_width: float = 120.0

var _state: BossState = BossState.CHARGING
var _state_time_left: float = 0.0

var _dash_target: Vector2 = Vector2.ZERO
var _dash_dir: Vector2 = Vector2.ZERO
var _dash_start_pos: Vector2 = Vector2.ZERO
var _dash_count_in_cycle: int = 0

var _phase2_triggered: bool = false

var _dash_warning: Sprite2D = null
static var _dash_warning_texture: Texture2D = null

func _ready() -> void:
	super._ready()
	_create_dash_warning()

func _create_dash_warning() -> void:
	_dash_warning = Sprite2D.new()
	_dash_warning.top_level = true
	_dash_warning.z_as_relative = false
	_dash_warning.z_index = 30
	_dash_warning.texture = _get_dash_warning_texture()
	_dash_warning.visible = false
	add_child(_dash_warning)

func _get_dash_warning_texture() -> Texture2D:
	if _dash_warning_texture:
		return _dash_warning_texture

	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(1.0, 0.0, 0.0, 0.35),
		Color(1.0, 0.0, 0.0, 0.15),
		Color(1.0, 0.0, 0.0, 0.0),
	])
	grad.offsets = PackedFloat32Array([0.0, 0.65, 1.0])

	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 16

	_dash_warning_texture = tex
	return _dash_warning_texture

func _on_warning_finished() -> void:
	super._on_warning_finished()
	# 生成结束后开始蓄力
	_start_charging()
	health_changed.emit(current_health, max_health)

func take_damage(damage_amount: float, knockback: Vector2 = Vector2.ZERO, apply_stun: bool = false) -> void:
	# BOSS 不可被击退/僵直：忽略传入的击退向量与僵直请求
	super.take_damage(damage_amount, Vector2.ZERO, false)
	health_changed.emit(current_health, max_health)
	_try_trigger_phase2()

func _try_trigger_phase2() -> void:
	if _phase2_triggered:
		return
	if is_dead:
		return
	if max_health <= 0.0:
		return
	if current_health > max_health * 0.5:
		return

	_phase2_triggered = true
	_force_start_chasing()

func _force_start_chasing() -> void:
	_hide_dash_warning()
	velocity = Vector2.ZERO
	_dash_count_in_cycle = 0
	_set_state(BossState.CHASING, chase_duration)

func perform_ai_behavior(delta: float) -> void:
	# 这里不再直接追踪玩家：由状态机控制
	var p := _get_player_cached(delta)
	match _state:
		BossState.CHARGING:
			velocity = Vector2.ZERO
			_state_time_left -= delta
			if p:
				_update_dash_warning(p.global_position)
			if _state_time_left <= 0.0:
				_start_dashing(p)
		BossState.DASHING:
			if _dash_dir == Vector2.ZERO:
				_end_dashing()
				return
			velocity = _dash_dir * dash_speed
			# 冲撞结束条件：主要由 _process_collisions 中的“撞墙检测”触发
			# 兜底：避免异常情况下无限冲撞
			var traveled := global_position.distance_to(_dash_start_pos)
			if traveled >= dash_max_distance:
				_end_dashing()
		BossState.RECOVERING:
			velocity = Vector2.ZERO
			_state_time_left -= delta
			if _state_time_left <= 0.0:
				if _dash_count_in_cycle >= 3:
					_start_exhausted()
				else:
					_start_charging()
		BossState.EXHAUSTED:
			velocity = Vector2.ZERO
			_state_time_left -= delta
			if _state_time_left <= 0.0:
				_dash_count_in_cycle = 0
				_start_charging()
		BossState.CHASING:
			_state_time_left -= delta
			if p:
				var dir := (p.global_position - global_position).normalized()
				velocity = dir * get_move_speed()
			else:
				velocity = Vector2.ZERO
			if _state_time_left <= 0.0:
				_start_charging()

func _start_charging() -> void:
	_set_state(BossState.CHARGING, charge_duration)

func _start_dashing(p: CharacterBody2D) -> void:
	_hide_dash_warning()
	if p == null:
		_start_recovering()
		return

	_dash_target = p.global_position
	_dash_dir = (_dash_target - global_position).normalized()
	_dash_start_pos = global_position
	_set_state(BossState.DASHING, 9999.0)

func _end_dashing() -> void:
	velocity = Vector2.ZERO
	_dash_dir = Vector2.ZERO
	_dash_count_in_cycle += 1
	_start_recovering()

func _start_recovering() -> void:
	_set_state(BossState.RECOVERING, recover_duration)

func _start_exhausted() -> void:
	_hide_dash_warning()
	velocity = Vector2.ZERO
	_set_state(BossState.EXHAUSTED, exhaust_duration)

func _set_state(new_state: BossState, duration: float) -> void:
	_state = new_state
	_state_time_left = duration
	action_changed.emit(_get_state_text(new_state))

func _get_state_text(state: BossState) -> String:
	match state:
		BossState.CHARGING:
			return "蓄力"
		BossState.DASHING:
			return "冲撞"
		BossState.RECOVERING:
			return "冷却"
		BossState.EXHAUSTED:
			return "力竭"
		BossState.CHASING:
			return "追击"
	return ""

func _get_player_cached(delta: float) -> CharacterBody2D:
	_player_lookup_timer -= delta
	if not is_instance_valid(_cached_player) or _player_lookup_timer <= 0.0:
		_cached_player = _find_player()
		_player_lookup_timer = _PLAYER_LOOKUP_INTERVAL
	return _cached_player

func _update_dash_warning(player_pos: Vector2) -> void:
	if _dash_warning == null:
		return
	var dir := (player_pos - global_position).normalized()
	if dir == Vector2.ZERO:
		_hide_dash_warning()
		return

	var dist_to_player := global_position.distance_to(player_pos)
	var len := minf(dash_max_distance, dist_to_player)
	len = maxf(64.0, len)

	_dash_warning.visible = true
	_dash_warning.global_position = global_position + dir * (len * 0.5)
	_dash_warning.global_rotation = dir.angle()
	_dash_warning.scale = Vector2(len / 256.0, warning_width / 16.0)

func _hide_dash_warning() -> void:
	if _dash_warning:
		_dash_warning.visible = false

func apply_stun_effect(_duration: float = -1.0) -> void:
	is_stunned = false
	stun_timer = 0.0

func _process_collisions(delta: float) -> void:
	# 冲撞时：只要撞到墙壁/空气墙（StaticBody2D）就立刻结束冲撞
	if _state != BossState.DASHING:
		super._process_collisions(delta)
		return

	# 更新伤害冷却计时（复用 BaseEnemy 的碰撞伤害节流机制）
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

	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if not collision:
			continue
		var collider = collision.get_collider()
		if collider is StaticBody2D:
			_end_dashing()
			return
		_handle_body_collision(collider)
