extends Node
## 调试日志管理器
## 按下 Y 键时收集并保存调试信息到游戏 exe 同层目录

# 日志保存路径
var log_directory: String = "user://logs/"
var exe_log_directory: String = ""

func _ready() -> void:
	# 设置日志目录
	# 在打包后，使用 res:// 的父目录（即 exe 所在目录）
	if OS.has_feature("editor"):
		# 编辑器模式下使用 user:// 目录
		log_directory = "user://logs/"
	else:
		# 打包后使用 exe 同层目录
		var executable_path = OS.get_executable_path()
		var exe_dir = executable_path.get_base_dir()
		log_directory = exe_dir + "/logs/"
		exe_log_directory = log_directory
	
	# 确保日志目录存在
	_ensure_log_directory()
	
	print("[调试日志] 日志管理器已启动，按 Y 键保存调试日志")
	print("[调试日志] 日志保存路径: ", log_directory)

func _process(_delta: float) -> void:
	# 监听 Y 键
	if Input.is_action_just_pressed("y"):
		save_debug_log()

func _ensure_log_directory() -> void:
	"""确保日志目录存在"""
	if not OS.has_feature("editor"):
		# 打包模式下，使用 DirAccess 创建目录
		var dir = DirAccess.open(log_directory.get_base_dir())
		if dir:
			if not dir.dir_exists(log_directory):
				var error = dir.make_dir_recursive(log_directory)
				if error != OK:
					push_error("[调试日志] 无法创建日志目录: " + log_directory)
	else:
		# 编辑器模式
		var dir = DirAccess.open("user://")
		if dir:
			if not dir.dir_exists("logs"):
				dir.make_dir("logs")

func save_debug_log() -> void:
	"""保存调试日志"""
	print("[调试日志] 正在保存调试信息...")
	
	# 生成日志文件名（包含时间戳）
	var datetime = Time.get_datetime_dict_from_system()
	var timestamp = "%04d%02d%02d_%02d%02d%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]
	var log_filename = "debug_log_%s.txt" % timestamp
	var log_path = log_directory + log_filename
	
	# 收集调试信息
	var log_content = _collect_debug_info()
	
	# 保存到文件
	var file = FileAccess.open(log_path, FileAccess.WRITE)
	if file:
		file.store_string(log_content)
		file.close()
		print("[调试日志] ✓ 日志已保存到: ", log_path)
		
		# 在游戏中显示通知（如果有 UI 系统）
		_show_notification("调试日志已保存: " + log_filename)
	else:
		push_error("[调试日志] ✗ 无法保存日志文件: " + log_path)
		push_error("[调试日志] 错误代码: " + str(FileAccess.get_open_error()))

func _collect_debug_info() -> String:
	"""收集各种调试信息"""
	var info = PackedStringArray()
	
	# 标题和时间戳
	info.append("=".repeat(80))
	info.append("游戏调试日志")
	info.append("=".repeat(80))
	info.append("")
	
	var datetime = Time.get_datetime_dict_from_system()
	info.append("生成时间: %04d-%02d-%02d %02d:%02d:%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	])
	info.append("")
	
	# 系统信息
	info.append("-".repeat(80))
	info.append("系统信息")
	info.append("-".repeat(80))
	info.append("操作系统: " + OS.get_name())
	info.append("Godot 版本: " + Engine.get_version_info().string)
	info.append("可执行文件路径: " + OS.get_executable_path())
	info.append("用户数据目录: " + OS.get_user_data_dir())
	info.append("是否为调试版本: " + str(OS.is_debug_build()))
	info.append("")
	
	# 性能信息
	info.append("-".repeat(80))
	info.append("性能信息")
	info.append("-".repeat(80))
	info.append("FPS: " + str(Engine.get_frames_per_second()))
	info.append("渲染时间: %.2f ms" % (Performance.get_monitor(Performance.TIME_PROCESS) * 1000))
	info.append("物理时间: %.2f ms" % (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000))
	info.append("内存使用: %.2f MB" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0))
	info.append("节点数量: " + str(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	info.append("")
	
	# 当前场景信息
	info.append("-".repeat(80))
	info.append("当前场景信息")
	info.append("-".repeat(80))
	var current_scene = get_tree().current_scene
	if current_scene:
		info.append("场景名称: " + current_scene.name)
		info.append("场景路径: " + current_scene.scene_file_path)
		info.append("场景节点数: " + str(_count_nodes(current_scene)))
		info.append("")
		info.append("场景树结构:")
		_append_scene_tree(info, current_scene, 0)
	else:
		info.append("无当前场景")
	info.append("")
	
	# 游戏管理器状态
	info.append("-".repeat(80))
	info.append("游戏管理器状态")
	info.append("-".repeat(80))
	
	# GameManager
	if has_node("/root/GameManager"):
		var game_manager = get_node("/root/GameManager")
		info.append("GameManager: 已加载")
		_append_object_properties(info, game_manager, "  ")
	else:
		info.append("GameManager: 未找到")
	info.append("")
	
	# RunManager
	if has_node("/root/RunManager"):
		var run_manager = get_node("/root/RunManager")
		info.append("RunManager: 已加载")
		_append_object_properties(info, run_manager, "  ")
	else:
		info.append("RunManager: 未找到")
	info.append("")
	
	# DataManager
	if has_node("/root/DataManager"):
		var data_manager = get_node("/root/DataManager")
		info.append("DataManager: 已加载")
		_append_object_properties(info, data_manager, "  ")
	else:
		info.append("DataManager: 未找到")
	info.append("")
	
	# 输入状态
	info.append("-".repeat(80))
	info.append("输入状态")
	info.append("-".repeat(80))
	info.append("鼠标位置: " + str(get_viewport().get_mouse_position()))
	var actions = ["left", "right", "up", "down", "mouse1", "mouse2", "e", "q", "esc", "shift"]
	for action in actions:
		if InputMap.has_action(action):
			info.append("  %s: %s" % [action, "按下" if Input.is_action_pressed(action) else "未按下"])
	info.append("")
	
	# 最近的错误/警告
	info.append("-".repeat(80))
	info.append("调试输出")
	info.append("-".repeat(80))
	info.append("注意: Godot 导出版本中完整的控制台输出可能不可用")
	info.append("建议在开发时使用编辑器查看完整日志")
	info.append("")
	
	# 结束
	info.append("=".repeat(80))
	info.append("日志结束")
	info.append("=".repeat(80))
	
	return "\n".join(info)

func _count_nodes(node: Node) -> int:
	"""递归计算节点数量"""
	var count = 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count

func _append_scene_tree(info: PackedStringArray, node: Node, depth: int) -> void:
	"""递归添加场景树结构"""
	var indent = "  ".repeat(depth)
	var node_info = indent + "- " + node.name + " (" + node.get_class() + ")"
	
	# 添加额外的有用信息
	if node is Node2D:
		node_info += " [位置: " + str(node.position) + "]"
	elif node is Control:
		node_info += " [尺寸: " + str(node.size) + "]"
	
	info.append(node_info)
	
	# 只显示前几层，避免日志过大
	if depth < 3:
		for child in node.get_children():
			_append_scene_tree(info, child, depth + 1)
	elif node.get_child_count() > 0:
		info.append(indent + "  ... (%d 个子节点)" % node.get_child_count())

func _append_object_properties(info: PackedStringArray, obj: Object, indent: String) -> void:
	"""添加对象的主要属性"""
	var property_list = obj.get_property_list()
	var custom_properties = []
	
	for prop in property_list:
		# 只显示自定义属性（跳过内置的）
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			custom_properties.append(prop.name)
	
	if custom_properties.is_empty():
		info.append(indent + "(无自定义属性)")
	else:
		for prop_name in custom_properties:
			var value = obj.get(prop_name)
			# 限制值的长度，避免日志过大
			var value_str = str(value)
			if value_str.length() > 100:
				value_str = value_str.substr(0, 100) + "..."
			info.append(indent + "%s: %s" % [prop_name, value_str])

func _show_notification(message: String) -> void:
	"""显示通知消息"""
	# 简单地打印到控制台
	print("[通知] " + message)
	
	# 如果需要，可以在这里添加 UI 通知
	# 例如：创建一个临时的 Label 节点显示消息
	if get_tree().current_scene:
		var label = Label.new()
		label.text = message
		label.position = Vector2(20, 20)
		label.z_index = 100
		get_tree().current_scene.add_child(label)
		
		# 3 秒后自动移除
		var tween = create_tween()
		tween.tween_interval(3.0)
		tween.tween_callback(label.queue_free)
