extends PlayerState
class_name PlayerDeadState

## 玩家死亡状态

func _init() -> void:
	state_name = "Dead"

func enter() -> void:
	var player = get_player()
	if player:
		player.velocity = Vector2.ZERO
		# 可以播放死亡动画
		# if player.animator and player.animator.sprite_frames.has_animation("dead"):
		#     player.animator.play("dead")

func physics_update(_delta: float) -> void:
	var player = get_player()
	if player:
		player.velocity = Vector2.ZERO

func get_transition() -> String:
	# 死亡状态不会自动转换到其他状态
	return ""
