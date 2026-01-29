extends Node3D

## 3D 展示场景控制脚本
## - 仅负责“返回主界面”入口
## - 不做预加载，切换场景后由引擎自动回收当前场景资源

@export var return_to_main_menu_on_esc: bool = true

## 右侧 UI 的交互入口：由外部系统监听这两个信号来实现“切换角色/对话”的实际逻辑。
signal request_switch_character
signal request_dialogue

@onready var _back_button: Button = %BackButton
@onready var _character_name_label: Label = %CharacterName
@onready var _favor_value_label: Label = %FavorValue
@onready var _switch_character_button: Button = %SwitchCharacterButton
@onready var _dialogue_button: Button = %DialogueButton

# base 场景仅做展示：这里维护一个“当前展示角色”的列表，用于右侧面板显示好感度。
# 注意：这不影响战斗内的实际出战角色；好感增长由结算时写入存档。
var _display_character_ids: PackedStringArray = PackedStringArray(["kamisato_ayaka", "nahida"])
var _display_character_index: int = 0


func _ready() -> void:
	# 这些节点来自 base.tscn（通过 unique_name_in_owner + % 访问）。
	# 若后续你调整了节点名，这里会在运行时报错，方便尽快发现问题。
	_back_button.pressed.connect(_return_to_main_menu)
	_back_button.grab_focus()

	_switch_character_button.pressed.connect(_on_switch_character_pressed)
	_dialogue_button.pressed.connect(_on_dialogue_pressed)

	_refresh_character_display()

func _unhandled_input(event: InputEvent) -> void:
	if not return_to_main_menu_on_esc:
		return
	if event.is_action_pressed("esc"):
		_return_to_main_menu()
		get_viewport().set_input_as_handled()


## 外部调用接口：设置右侧显示的角色名字。
func set_character_name(character_name: String) -> void:
	_character_name_label.text = character_name


## 外部调用接口：设置好感度显示（占位实现；好感度具体规则由外部系统决定）。
func set_favor_text(favor_text: String) -> void:
	_favor_value_label.text = favor_text


func _on_switch_character_pressed() -> void:
	_display_character_index += 1
	if _display_character_index >= _display_character_ids.size():
		_display_character_index = 0
	_refresh_character_display()
	request_switch_character.emit()


func _on_dialogue_pressed() -> void:
	request_dialogue.emit()

func _return_to_main_menu() -> void:
	# 优先走 GameManager（统一处理BGM/状态/UIOverlay清理等），失败再兜底切回主菜单场景
	if GameManager and GameManager.has_method("go_to_main_menu"):
		GameManager.go_to_main_menu()
		return
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _refresh_character_display() -> void:
	# 从 DataManager 读取角色显示名，从 GameManager 读取跨局持久化好感度。
	if _display_character_ids.is_empty():
		set_character_name("角色名")
		set_favor_text("-")
		return
	var character_id: String = str(_display_character_ids[_display_character_index])
	var display_name: String = character_id
	if DataManager and DataManager.has_method("get_character"):
		var cd := DataManager.get_character(character_id)
		if cd:
			display_name = str(cd.display_name)
	set_character_name(display_name)
	if GameManager and GameManager.has_method("get_character_favor"):
		var favor: int = int(GameManager.get_character_favor(character_id))
		set_favor_text("%d/100" % favor)
	else:
		set_favor_text("-")
