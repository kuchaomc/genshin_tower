extends Node

## 轻量事件总线（用于逐步替代跨模块直接互调）
## 说明：现阶段以“兼容方式”引入——旧代码仍可直接调用 GameManager/RunManager。
## 后续重构可以改为：场景脚本 emit 事件 → App/GameManager 统一响应。

signal scene_change_requested(scene_path: String)
signal scene_changed(scene_path: String)

signal run_started(character_id: String)
signal run_ended(victory: bool)

func request_scene_change(scene_path: String) -> void:
	emit_signal("scene_change_requested", scene_path)
