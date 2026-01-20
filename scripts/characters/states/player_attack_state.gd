extends PlayerState
class_name PlayerAttackState

## 玩家攻击状态
## 子类需要重写 perform_attack() 来实现具体攻击逻辑

## 攻击是否完成
var attack_finished: bool = false

func _init() -> void:
	state_name = "Attack"

func enter() -> void:
	attack_finished = false
	var player = get_player()
	if player:
		player.velocity = Vector2.ZERO
		# 调用角色的攻击方法
		player.perform_attack()

func exit() -> void:
	attack_finished = false

func physics_update(_delta: float) -> void:
	var player = get_player()
	if player:
		# 攻击时停止移动（除非有特殊位移）
		if not player.is_knockback_active:
			player.velocity = Vector2.ZERO

## 标记攻击完成（由角色调用）
func finish_attack() -> void:
	attack_finished = true

func get_transition() -> String:
	var player = get_player()
	if not player:
		return ""
	
	# 检查死亡
	if player.is_game_over:
		return "Dead"
	
	# 检查击退（攻击可能被打断）
	if player.is_knockback_active:
		return "Knockback"
	
	# 攻击完成后根据输入决定下一个状态
	if attack_finished:
		var input_dir = get_input_direction()
		if input_dir != Vector2.ZERO:
			return "Move"
		return "Idle"
	
	return ""
