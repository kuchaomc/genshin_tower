extends PlayerState
class_name PlayerMoveState

## 玩家移动状态

func _init() -> void:
	state_name = "Move"

func enter() -> void:
	var player = get_player()
	if player and player.animator:
		player.animator.play("run")

func physics_update(_delta: float) -> void:
	var player = get_player()
	if not player:
		return
	
	var input_dir = get_input_direction()
	
	# 计算移动速度（如果正在蓄力重击，减慢速度）
	var current_move_speed = player.move_speed
	if player._attack_button_pressed:
		# 正在蓄力重击，应用速度减慢
		current_move_speed = player.move_speed * player.charged_attack_move_speed_multiplier
	
	player.velocity = input_dir * current_move_speed
	
	# 记录最后非零移动方向
	if input_dir != Vector2.ZERO:
		player._last_nonzero_move_dir = input_dir.normalized()

func get_transition() -> String:
	var player = get_player()
	if not player:
		return ""
	
	# 检查死亡
	if player.is_game_over:
		return "Dead"
	
	# 检查击退
	if player.is_knockback_active:
		return "Knockback"
	
	# 检查闪避
	if is_dodge_pressed() and player._is_dodge_ready():
		return "Dodge"
	
	# 检查攻击
	if is_attack_pressed():
		return "Attack"
	
	# 检查停止移动
	var input_dir = get_input_direction()
	if input_dir == Vector2.ZERO:
		return "Idle"
	
	return ""
