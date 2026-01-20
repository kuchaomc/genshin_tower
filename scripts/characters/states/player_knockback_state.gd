extends PlayerState
class_name PlayerKnockbackState

## 玩家击退状态

func _init() -> void:
	state_name = "Knockback"

func enter() -> void:
	pass

func physics_update(_delta: float) -> void:
	var player = get_player()
	if not player:
		return
	
	# 应用击退速度
	player.velocity = player.knockback_velocity

func get_transition() -> String:
	var player = get_player()
	if not player:
		return ""
	
	# 检查死亡
	if player.is_game_over:
		return "Dead"
	
	# 击退结束后根据输入决定下一个状态
	if not player.is_knockback_active:
		var input_dir = get_input_direction()
		if input_dir != Vector2.ZERO:
			return "Move"
		return "Idle"
	
	return ""
