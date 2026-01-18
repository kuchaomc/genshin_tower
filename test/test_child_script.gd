extends Sprite2D

func _ready():
	print("Child script attached!")
func _process(delta: float) -> void:
	# 测试update_script_file_content工具
	print("Process running: ", delta)
