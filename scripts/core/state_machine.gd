extends Node
class_name StateMachine

## 有限状态机
## 管理状态的切换和更新

## 当前状态
var current_state: State = null

## 所有状态字典 {状态名: 状态节点}
var states: Dictionary = {}

## 角色引用
var character: CharacterBody2D

## 是否启用调试输出
@export var debug_mode: bool = false

## 状态切换信号
signal state_changed(old_state: String, new_state: String)

## 初始化状态机
func setup(owner: CharacterBody2D) -> void:
	character = owner
	
	# 收集所有子节点中的状态
	for child in get_children():
		if child is State:
			var state = child as State
			states[state.state_name] = state
			state.state_machine = self
			state.character = character
			if debug_mode:
				print("[StateMachine] 注册状态: ", state.state_name)

## 设置初始状态
func set_initial_state(state_name: String) -> void:
	if states.has(state_name):
		current_state = states[state_name]
		current_state.enter()
		if debug_mode:
			print("[StateMachine] 初始状态: ", state_name)
	else:
		push_error("[StateMachine] 找不到初始状态: " + state_name)

## 切换状态
func change_state(new_state_name: String) -> void:
	if not states.has(new_state_name):
		push_error("[StateMachine] 找不到状态: " + new_state_name)
		return
	
	var old_state_name = current_state.state_name if current_state else ""
	
	# 如果已经在目标状态，不执行切换
	if current_state and current_state.state_name == new_state_name:
		return
	
	# 退出当前状态
	if current_state:
		current_state.exit()
	
	# 进入新状态
	current_state = states[new_state_name]
	current_state.enter()
	
	if debug_mode:
		print("[StateMachine] 状态切换: ", old_state_name, " -> ", new_state_name)
	
	emit_signal("state_changed", old_state_name, new_state_name)

## 每帧更新
func update(delta: float) -> void:
	if current_state:
		current_state.update(delta)
		
		# 检查状态转换
		var transition = current_state.get_transition()
		if transition != "":
			change_state(transition)

## 物理更新
func physics_update(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)
		
		# 检查状态转换
		var transition = current_state.get_transition()
		if transition != "":
			change_state(transition)

## 处理输入
func handle_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

## 获取当前状态名称
func get_current_state_name() -> String:
	if current_state:
		return current_state.state_name
	return ""

## 检查是否处于指定状态
func is_in_state(state_name: String) -> bool:
	return current_state and current_state.state_name == state_name

## 强制切换状态（跳过检查）
func force_change_state(new_state_name: String) -> void:
	if not states.has(new_state_name):
		push_error("[StateMachine] 找不到状态: " + new_state_name)
		return
	
	var old_state_name = current_state.state_name if current_state else ""
	
	# 退出当前状态
	if current_state:
		current_state.exit()
	
	# 进入新状态
	current_state = states[new_state_name]
	current_state.enter()
	
	if debug_mode:
		print("[StateMachine] 强制状态切换: ", old_state_name, " -> ", new_state_name)
	
	emit_signal("state_changed", old_state_name, new_state_name)
