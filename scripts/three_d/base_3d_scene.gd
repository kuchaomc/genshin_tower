extends Node3D

## 3D 展示场景控制脚本
## - 仅负责“返回主界面”入口
## - 不做预加载，切换场景后由引擎自动回收当前场景资源

@export var return_to_main_menu_on_esc: bool = true

var _back_layer: CanvasLayer = null
var _back_button: Button = null


func _ready() -> void:
	_back_layer = CanvasLayer.new()
	_back_layer.name = "BackLayer"
	_back_layer.layer = 10
	add_child(_back_layer)

	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.text = "返回"
	_back_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_back_button.offset_left = 16.0
	_back_button.offset_top = 16.0
	_back_button.offset_right = 136.0
	_back_button.offset_bottom = 56.0
	_back_layer.add_child(_back_button)
	_back_button.pressed.connect(_return_to_main_menu)
	_back_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not return_to_main_menu_on_esc:
		return
	if event.is_action_pressed("esc"):
		_return_to_main_menu()
		get_viewport().set_input_as_handled()

func _return_to_main_menu() -> void:
	# 优先走 GameManager（统一处理BGM/状态/UIOverlay清理等），失败再兜底切回主菜单场景
	if GameManager and GameManager.has_method("go_to_main_menu"):
		GameManager.go_to_main_menu()
		return
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
