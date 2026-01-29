extends CanvasLayer

## 3D 场景通用返回入口（UI Overlay）
## - 作为子节点挂到任意 3D 场景（Node3D）下即可显示
## - 点击左上角“返回”按钮返回主菜单
## - 可选支持按 Esc 返回

@export var enable_esc_back: bool = true

@onready var back_button: Button = $Root/BackButton


func _ready() -> void:
	if is_instance_valid(back_button):
		back_button.pressed.connect(_on_back_pressed)
		back_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not enable_esc_back:
		return
	if event.is_action_pressed("esc"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _on_back_pressed() -> void:
	# 优先走项目统一的场景切换入口，确保 Overlay 清理、BGM、兜底逻辑一致。
	if GameManager and GameManager.has_method("go_to_main_menu"):
		GameManager.go_to_main_menu()
		return
	
	# 兜底：如果自动加载不存在/未初始化，直接切主菜单场景。
	var main_menu_path := "res://scenes/ui/main_menu.tscn"
	if GameManager and GameManager.has_method("change_scene_to"):
		GameManager.change_scene_to(main_menu_path)
		return
	get_tree().change_scene_to_file(main_menu_path)
