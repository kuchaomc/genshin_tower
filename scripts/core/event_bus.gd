extends Node

## 轻量事件总线（用于跨模块通信）
## 场景脚本通过 emit 事件与 GameManager/RunManager 通信

signal scene_change_requested(scene_path: String)
signal scene_changed(scene_path: String)

signal run_started(character_id: String)
signal run_ended(victory: bool)

func request_scene_change(scene_path: String) -> void:
	emit_signal("scene_change_requested", scene_path)
