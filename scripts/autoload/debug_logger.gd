extends Node
## 调试日志管理器
## 按下 Y 键时收集并保存调试信息到游戏 exe 同层目录

# 日志保存路径
var log_directory: String = ""
var use_exe_directory: bool = false
var initialization_log: PackedStringArray = []

func _ready() -> void:
	initialization_log.append("[调试日志] 开始初始化...")
	
	# 设置日志目录
	if OS.has_feature("editor"):
		# 编辑器模式下使用 user:// 目录
		log_directory = "user://logs/"
		use_exe_directory = false
		initialization_log.append("[调试日志] 编辑器模式，使用 user:// 目录")
	else:
		# 打包后尝试使用 exe 同层目录
		initialization_log.append("[调试日志] 打包模式，尝试使用 exe 目录...")
		var exe_path = OS.get_executable_path()
		initialization_log.append("[调试日志] exe 路径: " + exe_path)
		
		var exe_dir = exe_path.get_base_dir()
		initialization_log.append("[调试日志] exe 目录: " + exe_dir)
		
		# 尝试在 exe 目录创建 logs 文件夹
		var target_log_dir = exe_dir.path_join("logs")
		initialization_log.append("[调试日志] 目标日志目录: " + target_log_dir)
		
		if _try_create_directory(target_log_dir):
			log_directory = target_log_dir + "/"
			use_exe_directory = true
			initialization_log.append("[调试日志] ✓ 成功使用 exe 目录")
		else:
			# 如果失败，回退到 user:// 目录
			log_directory = "user://logs/"
			use_exe_directory = false
			initialization_log.append("[调试日志] ✗ exe 目录无法访问，回退到 user:// 目录")
	
	# 确保日志目录存在
	_ensure_log_directory()
	
	# 输出所有初始化日志
	for log_line in initialization_log:
		print(log_line)
	
	print("[调试日志] 日志管理器已启动，按 Y 键保存调试日志")
	print("[调试日志] 最终日志保存路径: ", log_directory)
	if not use_exe_directory and not OS.has_feature("editor"):
		var real_path = ProjectSettings.globalize_path(log_directory)
		print("[调试日志] 实际物理路径: ", real_path)

func _process(_delta: float) -> void:
	# 监听 Y 键
	if Input.is_action_just_pressed("y"):
		save_debug_log()

func _try_create_directory(dir_path: String) -> bool:
	"""尝试创建目录并测试写入权限"""
	# 尝试打开父目录
	var parent_dir = dir_path.get_base_dir()
	var dir = DirAccess.open(parent_dir)
	
	if not dir:
		initialization_log.append("[调试日志] 无法打开父目录: " + parent_dir)
		return false
	
	# 创建目录
	if not dir.dir_exists(dir_path):
		var error = dir.make_dir(dir_path)
		if error != OK:
			initialization_log.append("[调试日志] 无法创建目录，错误码: " + str(error))
			return false
	
	# 测试写入权限 - 尝试创建一个测试文件
	var test_file_path = dir_path.path_join("test_write.tmp")
	var test_file = FileAccess.open(test_file_path, FileAccess.WRITE)
	
	if not test_file:
		initialization_log.append("[调试日志] 无法在目录中创建测试文件，错误码: " + str(FileAccess.get_open_error()))
		return false
	
	test_file.store_string("test")
	test_file.close()
	
	# 删除测试文件
	dir.remove(test_file_path)
	
	initialization_log.append("[调试日志] 目录创建成功并可写入")
	return true

func _ensure_log_directory() -> void:
	"""确保日志目录存在"""
	if use_exe_directory:
		# 已经在初始化时处理过了
		return
	
	# 使用 user:// 目录
	var dir = DirAccess.open("user://")
	if dir:
		if not dir.dir_exists("logs"):
			var error = dir.make_dir("logs")
			if error != OK:
				push_error("[调试日志] 无法创建 user://logs 目录，错误码: " + str(error))
	else:
		push_error("[调试日志] 无法打开 user:// 目录")

func save_debug_log() -> void:
	"""保存调试日志"""
	print("[调试日志] 正在保存调试信息...")
	print("[调试日志] 当前日志目录: ", log_directory)
	
	# 生成日志文件名（包含时间戳）
	var datetime = Time.get_datetime_dict_from_system()
	var timestamp = "%04d%02d%02d_%02d%02d%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]
	var log_filename = "debug_log_%s.txt" % timestamp
	
	# 构建完整路径
	var log_path: String
	if use_exe_directory:
		log_path = log_directory + log_filename
	else:
		log_path = log_directory + log_filename
	
	print("[调试日志] 尝试保存到: ", log_path)
	
	# 如果不是编辑器模式且使用 user:// 目录，显示实际路径
	if not OS.has_feature("editor") and not use_exe_directory:
		var real_path = ProjectSettings.globalize_path(log_path)
		print("[调试日志] 实际物理路径: ", real_path)
	
	# 收集调试信息
	var log_content = _collect_debug_info()
	
	# 保存到文件
	var file = FileAccess.open(log_path, FileAccess.WRITE)
	if file:
		file.store_string(log_content)
		file.close()
		
		var success_msg = "✓ 日志已保存到: " + log_path
		print("[调试日志] " + success_msg)
		
		# 显示实际路径
		if not use_exe_directory:
			var real_path = ProjectSettings.globalize_path(log_path)
			print("[调试日志] 实际物理路径: " + real_path)
			_show_notification("调试日志已保存\n路径: " + real_path)
		else:
			_show_notification("调试日志已保存: " + log_filename)
	else:
		var error_code = FileAccess.get_open_error()
		push_error("[调试日志] ✗ 无法保存日志文件: " + log_path)
		push_error("[调试日志] 错误代码: " + str(error_code))
		
		# 如果使用 exe 目录失败，尝试备选方案
		if use_exe_directory:
			print("[调试日志] 尝试备选方案：使用 user:// 目录...")
			var fallback_path = "user://logs/" + log_filename
			
			# 确保 user://logs 目录存在
			var dir = DirAccess.open("user://")
			if dir and not dir.dir_exists("logs"):
				dir.make_dir("logs")
			
			file = FileAccess.open(fallback_path, FileAccess.WRITE)
			if file:
				file.store_string(log_content)
				file.close()
				var real_path = ProjectSettings.globalize_path(fallback_path)
				print("[调试日志] ✓ 使用备选路径保存成功: " + real_path)
				_show_notification("调试日志已保存（备选路径）\n" + real_path)
			else:
				push_error("[调试日志] ✗ 备选路径也失败，错误代码: " + str(FileAccess.get_open_error()))
				_show_notification("❌ 日志保存失败！")

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
	info.append("是否为编辑器模式: " + str(OS.has_feature("editor")))
	info.append("")
	
	# 日志系统信息
	info.append("-".repeat(80))
	info.append("日志系统诊断")
	info.append("-".repeat(80))
	info.append("日志目录: " + log_directory)
	info.append("使用 exe 目录: " + str(use_exe_directory))
	if not use_exe_directory:
		var real_path = ProjectSettings.globalize_path(log_directory)
		info.append("实际物理路径: " + real_path)
	info.append("")
	info.append("初始化日志:")
	for log_line in initialization_log:
		info.append("  " + log_line)
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
	
	# 在游戏中显示 UI 通知
	if not get_tree():
		return
	
	# 创建 CanvasLayer 确保通知在最上层
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # 设置为很高的层级
	
	# 创建通知面板
	var panel = PanelContainer.new()
	panel.position = Vector2(20, 20)
	
	# 创建文本标签
	var label = Label.new()
	label.text = message
	label.add_theme_color_override("font_color", Color.WHITE)
	
	# 设置最小尺寸和内边距
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	
	panel.add_child(margin)
	margin.add_child(label)
	
	# 添加背景色
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	style_box.border_color = Color(0.3, 0.6, 1.0, 1.0)
	style_box.border_width_left = 3
	style_box.border_width_right = 3
	style_box.border_width_top = 3
	style_box.border_width_bottom = 3
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style_box)
	
	# 添加到层级结构
	canvas_layer.add_child(panel)
	add_child(canvas_layer)  # 添加到 autoload 节点，不受场景切换影响
	
	# 淡入动画
	panel.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	
	# 5 秒后淡出并移除
	tween.tween_interval(5.0)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(canvas_layer.queue_free)
