extends State
class_name PlayerState

## 玩家状态基类
## 提供对 BaseCharacter 的类型安全访问

## 获取玩家角色（类型安全）
func get_player() -> BaseCharacter:
	return character as BaseCharacter

## 获取移动输入方向
func get_input_direction() -> Vector2:
	return Input.get_vector("left", "right", "up", "down")

## 获取鼠标方向（从角色位置指向鼠标）
func get_mouse_direction() -> Vector2:
	var player = get_player()
	if player:
		var mouse_pos = player.get_global_mouse_position()
		var direction = mouse_pos - player.global_position
		if direction != Vector2.ZERO:
			return direction.normalized()
	return Vector2.RIGHT

## 检查是否按下攻击键
func is_attack_pressed() -> bool:
	return Input.is_action_just_pressed("mouse1")

## 检查是否按下闪避键
func is_dodge_pressed() -> bool:
	return Input.is_action_just_pressed("mouse2")

## 检查是否按下技能键
func is_skill_pressed() -> bool:
	return Input.is_action_just_pressed("skill") or Input.is_physical_key_pressed(KEY_E)

## 检查是否按下大招键
func is_burst_pressed() -> bool:
	return Input.is_physical_key_pressed(KEY_Q)
