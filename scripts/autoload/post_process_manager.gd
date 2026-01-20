extends Node

## 后处理管理器（AutoLoad）
## 说明：当前项目配置里启用了该单例，但脚本缺失会导致启动报错。
## 这里提供一个最小实现，避免启动失败；后续如需Bloom/色调映射等效果可在此扩展。

func _ready() -> void:
	# 占位：保持与现有 AutoLoad 配置兼容
	pass
