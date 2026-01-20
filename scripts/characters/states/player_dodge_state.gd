extends PlayerState
class_name PlayerDodgeState

## 玩家闪避状态

## 闪避方向
var dodge_direction: Vector2 = Vector2.ZERO
## 闪避已经过时间
var dodge_elapsed: float = 0.0
## 闪避是否完成
var dodge_finished: bool = false

func _init() -> void:
	state_name = "Dodge"

func enter() -> void:
	var player = get_player()
	if not player:
		return
	
	dodge_finished = false
	dodge_elapsed = 0.0
	
	# 记录闪避开始时间
	player._dodge_next_ready_ms = Time.get_ticks_msec() + int(player.dodge_cooldown * 1000.0)
	
	# 计算闪避方向（朝鼠标方向）
	var mouse_pos = player.get_global_mouse_position()
	var dir = mouse_pos - player.global_position
	if dir == Vector2.ZERO:
		dir = player._last_nonzero_move_dir
	dodge_direction = dir.normalized()
	
	# 设置闪避无敌
	player._set_dodge_invincible(true)
	
	# 修改碰撞层（可穿过敌人）
	player.collision_mask = player._DODGE_COLLISION_MASK
	player.collision_layer = player._DODGE_PLAYER_COLLISION_LAYER

func exit() -> void:
	var player = get_player()
	if not player:
		return
	
	# 取消闪避无敌
	player._set_dodge_invincible(false)
	
	# 恢复正常碰撞
	player.collision_mask = player._NORMAL_COLLISION_MASK
	player.collision_layer = player._PLAYER_COLLISION_LAYER
	
	dodge_finished = false
	dodge_elapsed = 0.0

func physics_update(delta: float) -> void:
	var player = get_player()
	if not player:
		return
	
	dodge_elapsed += delta
	
	var t: float = 0.0
	if player.dodge_duration > 0.0:
		t = clamp(dodge_elapsed / player.dodge_duration, 0.0, 1.0)
	
	# 计算基础速度
	var base_speed: float = player.base_move_speed
	if player.dodge_duration > 0.0:
		base_speed = player.dodge_distance / player.dodge_duration
	
	# 速度曲线：初始很快，逐渐回落
	var start_speed: float = base_speed * player.dodge_speed_multiplier
	var end_speed: float = base_speed * 0.8
	var ease_out: float = 1.0 - pow(1.0 - t, 2.0)
	var speed: float = lerp(start_speed, end_speed, ease_out)
	
	player.velocity = dodge_direction * speed
	
	# 检查闪避是否完成
	if t >= 1.0:
		dodge_finished = true

func get_transition() -> String:
	var player = get_player()
	if not player:
		return ""
	
	# 检查死亡
	if player.is_game_over:
		return "Dead"
	
	# 闪避完成后根据输入决定下一个状态
	if dodge_finished:
		var input_dir = get_input_direction()
		if input_dir != Vector2.ZERO:
			return "Move"
		return "Idle"
	
	return ""
