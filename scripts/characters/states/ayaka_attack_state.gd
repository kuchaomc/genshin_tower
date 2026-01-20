extends PlayerAttackState
class_name AyakaAttackState

## 神里绫华专属攻击状态
## 支持两段攻击：第一段挥剑 + 第二段剑花

## 攻击阶段：0=未攻击, 1=第一段, 2=第二段
var attack_phase: int = 0

## 第二段伤害当前命中次数
var phase2_current_hit: int = 0

## 攻击计时器（用于追踪攻击动画完成）
var attack_timer: float = 0.0

func _init() -> void:
	state_name = "Attack"

func enter() -> void:
	attack_finished = false
	attack_phase = 0
	phase2_current_hit = 0
	attack_timer = 0.0
	
	var player = get_player()
	if player:
		player.velocity = Vector2.ZERO
		# 攻击时播放idle动画（停止move动画）
		if player.animator:
			player.animator.play("idle")
		# 开始第一阶段攻击
		_start_phase1()

func exit() -> void:
	attack_finished = false
	attack_phase = 0
	phase2_current_hit = 0
	attack_timer = 0.0
	
	# 清理攻击状态
	var ayaka = _get_ayaka()
	if ayaka:
		ayaka._cleanup_attack()

func physics_update(delta: float) -> void:
	var player = get_player()
	if player:
		player.velocity = Vector2.ZERO
	
	# 更新攻击计时器和状态由角色脚本处理
	# 这里只负责状态转换检查

## 开始第一阶段攻击
func _start_phase1() -> void:
	attack_phase = 1
	var ayaka = _get_ayaka()
	if ayaka:
		ayaka._execute_phase1_attack()

## 第一阶段完成，检查是否进入第二阶段
func on_phase1_finished() -> void:
	if Input.is_action_pressed("mouse1"):
		attack_phase = 2
		var ayaka = _get_ayaka()
		if ayaka:
			ayaka._execute_phase2_attack()
	else:
		attack_finished = true

## 第二阶段完成
func on_phase2_finished() -> void:
	attack_finished = true

## 获取神里绫华角色
func _get_ayaka() -> KamisatoAyakaCharacter:
	return character as KamisatoAyakaCharacter

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
