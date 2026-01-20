extends Node
class_name State

## 状态基类
## 所有具体状态都应继承此类

## 状态机引用
var state_machine: StateMachine

## 角色引用（方便访问）
var character: CharacterBody2D

## 状态名称（用于调试）
@export var state_name: String = "State"

## 进入状态时调用
func enter() -> void:
	pass

## 退出状态时调用
func exit() -> void:
	pass

## 每帧更新（在 _process 中调用）
func update(_delta: float) -> void:
	pass

## 物理更新（在 _physics_process 中调用）
func physics_update(_delta: float) -> void:
	pass

## 处理输入
func handle_input(_event: InputEvent) -> void:
	pass

## 检查是否可以转换到其他状态
## 返回目标状态名称，如果不需要转换则返回空字符串
func get_transition() -> String:
	return ""
