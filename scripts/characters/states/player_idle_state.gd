extends PlayerState
class_name PlayerIdleState

## 玩家待机状态

func _init() -> void:
	state_name = "Idle"

func enter() -> void:
	var player = get_player()
	if player and player.animator:
		player.animator.play("idle")

func physics_update(_delta: float) -> void:
	var player = get_player()
	if player:
		player.velocity = Vector2.ZERO

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
	
	# 检查移动
	var input_dir = get_input_direction()
	if input_dir != Vector2.ZERO:
		return "Move"
	
	return ""
