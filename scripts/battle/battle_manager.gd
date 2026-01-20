extends Node2D
class_name BattleManager

## 战斗管理器
## 管理战斗场景的状态和逻辑

# 战斗场景准星贴图
const CROSSHAIR_TEXTURE := preload("res://textures/effects/mouse.png")

enum GameState {
	PLAYING,
	GAME_OVER
}

# 导出的敌人场景引用
@export var enemy_scene: PackedScene

# 当前游戏状态
var current_state: GameState = GameState.PLAYING

# 敌人生成计时器
var enemy_spawn_timer: Timer
# 游戏结束计时器
var game_over_timer: Timer

# 战斗胜利条件
var required_score: int = 5  # 需要达到的分数（初始值=5，每往上走一个节点层就+5）
var current_score: int = 0  # 当前得分（每击杀一个敌人+1分）
var is_battle_victory: bool = false  # 标记是否通过得分获得胜利（而非玩家死亡）

# 玩家血量UI引用
var player_hp_bar: ProgressBar
var player_hp_label: Label
# 敌人击杀计数器UI引用
var enemy_kill_counter: Control
var enemy_kill_counter_label: Label
# 摩拉显示UI引用
var gold_label: Label
var gold_icon: TextureRect
# 技能UI引用
var skill_ui: SkillUI
# 大招UI引用
var burst_ui: SkillUI
# 调试：显示判定/碰撞箱开关
var debug_toggle_button: Button
var debug_show_hitboxes: bool = false
# 玩家引用
var player: BaseCharacter
# 暂停菜单引用
var pause_menu: Control
# 层数提示UI引用
var floor_notification: Control
var floor_notification_label: Label
var floor_notification_timer: Timer

# 敌人注册表：避免 get_nodes_in_group("enemies") 全树扫描
var _active_enemies: Array[Node] = []

func _ready() -> void:
	_initialize_ui_components()
	_initialize_player()
	_initialize_battle_conditions()
	_initialize_enemy_spawning()
	_initialize_timers()
	_connect_signals()
	_initialize_pause_menu()
	_apply_crosshair_cursor()
	
	# 播放转场淡入动画（如果TransitionManager存在）
	# 同时在转场期间显示“正在进入第N层”提示（居中显示）
	if TransitionManager:
		# 确保转场层已准备好并先完全遮挡
		TransitionManager.set_opaque()
		# 等待一帧让场景与UI完成布局，然后显示楼层提示
		await get_tree().process_frame
		# 将楼层提示移动到转场层，确保显示在黑屏之上
		_move_floor_notification_to_transition_layer()
		show_floor_notification()
		# 使用 2 秒淡入，楼层提示会随黑屏一同淡出
		TransitionManager.fade_in_with_node(2.0, floor_notification)
	else:
		# 无转场管理器时，直接显示楼层提示
		await get_tree().process_frame
		show_floor_notification()
	
	print("战斗管理器已初始化")

## 初始化UI组件
func _initialize_ui_components() -> void:
	player_hp_bar = get_node_or_null("CanvasLayer/PlayerHPBar/ProgressBar") as ProgressBar
	player_hp_label = get_node_or_null("CanvasLayer/PlayerHPBar/Label") as Label
	enemy_kill_counter = get_node_or_null("CanvasLayer/EnemyKillCounter") as Control
	enemy_kill_counter_label = get_node_or_null("CanvasLayer/EnemyKillCounter/Label") as Label
	skill_ui = get_node_or_null("CanvasLayer/SkillUIContainer/SkillUI") as SkillUI
	burst_ui = get_node_or_null("CanvasLayer/BurstUIContainer/BurstUI") as SkillUI
	gold_label = get_node_or_null("CanvasLayer/GoldDisplay/Label") as Label
	gold_icon = get_node_or_null("CanvasLayer/GoldDisplay/Icon") as TextureRect
	debug_toggle_button = get_node_or_null("CanvasLayer/DebugToggle") as Button
	if debug_toggle_button:
		debug_toggle_button.pressed.connect(_on_debug_toggle_pressed)
	
	floor_notification = get_node_or_null("CanvasLayer/FloorNotification") as Control
	floor_notification_label = get_node_or_null("CanvasLayer/FloorNotification/Label") as Label
	
	# 初始化UI的初始状态（隐藏并设置动画起始值）
	if enemy_kill_counter:
		enemy_kill_counter.visible = false
		enemy_kill_counter.modulate.a = 0.0
		enemy_kill_counter.scale = Vector2(0.9, 0.9)
	
	if floor_notification:
		floor_notification.visible = false
		floor_notification.modulate.a = 0.0
		floor_notification.scale = Vector2(0.9, 0.9)

## 初始化玩家
func _initialize_player() -> void:
	initialize_player()
	_update_all_hitbox_visibility()

## 初始化战斗条件
func _initialize_battle_conditions() -> void:
	current_score = 0
	var current_floor = RunManager.current_floor if RunManager else 1
	required_score = 5 + (current_floor - 1) * 5
	update_enemy_kill_counter_display()
	_update_gold_display()

## 初始化敌人生成系统
func _initialize_enemy_spawning() -> void:
	if enemy_scene == null:
		enemy_scene = preload("res://scenes/enemies/enemy.tscn")

## 初始化计时器
func _initialize_timers() -> void:
	# 创建敌人生成计时器
	enemy_spawn_timer = Timer.new()
	var current_floor = RunManager.current_floor if RunManager else 1
	enemy_spawn_timer.wait_time = _calculate_enemy_spawn_time(current_floor)
	print("当前楼层：", current_floor, "，怪物生成间隔：", enemy_spawn_timer.wait_time, "秒")
	enemy_spawn_timer.timeout.connect(_on_enemy_spawn_timer_timeout)
	add_child(enemy_spawn_timer)
	enemy_spawn_timer.start()
	
	# 创建游戏结束计时器
	game_over_timer = Timer.new()
	game_over_timer.one_shot = true
	game_over_timer.timeout.connect(_on_game_over_timer_timeout)
	add_child(game_over_timer)

## 计算敌人生成时间（根据楼层）
func _calculate_enemy_spawn_time(current_floor: int) -> float:
	const BASE_SPAWN_TIME = 3.0
	const SPEED_INCREASE_PER_TWO_FLOORS = 0.5
	const MIN_SPAWN_TIME = 0.5
	
	var floors_up = int((current_floor - 1) / 2)  # 每两层算一次提升（向下取整）
	var calculated_spawn_time = BASE_SPAWN_TIME - floors_up * SPEED_INCREASE_PER_TWO_FLOORS
	return max(MIN_SPAWN_TIME, calculated_spawn_time)

## 连接信号
func _connect_signals() -> void:
	if RunManager:
		RunManager.health_changed.connect(_on_player_health_changed)
		RunManager.gold_changed.connect(_on_gold_changed)

func _exit_tree() -> void:
	_restore_default_cursor()

func _input(event: InputEvent) -> void:
	# 处理ESC键打开/关闭暂停菜单
	# 注意：暂停时此方法不会执行，由暂停菜单自己处理ESC键
	if event.is_action_pressed("esc") and not get_tree().paused:
		if pause_menu:
			pause_menu.handle_esc_key()

## 初始化暂停菜单
func _initialize_pause_menu() -> void:
	# 加载暂停菜单场景
	var pause_menu_scene = DataManager.get_packed_scene("res://scenes/ui/pause_menu.tscn") if DataManager else preload("res://scenes/ui/pause_menu.tscn")
	if not pause_menu_scene:
		push_error("BattleManager: 无法加载暂停菜单场景")
		return
	
	pause_menu = pause_menu_scene.instantiate() as Control
	if not pause_menu:
		push_error("BattleManager: 无法实例化暂停菜单")
		return
	
	# 添加到CanvasLayer下，确保在最上层
	var canvas_layer = get_node_or_null("CanvasLayer")
	if canvas_layer:
		canvas_layer.add_child(pause_menu)
	else:
		# 如果没有CanvasLayer，直接添加到场景根节点
		add_child(pause_menu)
	
	# 连接暂停菜单信号
	if pause_menu.has_signal("resume_game"):
		pause_menu.resume_game.connect(_on_pause_menu_resume)
	if pause_menu.has_signal("return_to_main_menu"):
		pause_menu.return_to_main_menu.connect(_on_pause_menu_return_to_main_menu)
	
	# 添加到battle_manager组，方便暂停菜单查找
	add_to_group("battle_manager")
	print("暂停菜单已初始化")

## 暂停菜单继续游戏
func _on_pause_menu_resume() -> void:
	# 恢复游戏逻辑
	pass

## 暂停菜单返回主菜单
func _on_pause_menu_return_to_main_menu() -> void:
	# 返回主菜单前的清理工作
	pass

## 获取玩家实例（供暂停菜单使用）
func get_player() -> BaseCharacter:
	return player

## 初始化玩家
func initialize_player() -> void:
	if not RunManager or not RunManager.current_character:
		print("错误：没有选择角色，无法初始化玩家")
		return
	
	var character_data = RunManager.current_character
	
	# 如果场景中已有玩家节点，先移除它
	var existing_player = get_node_or_null("player")
	if existing_player:
		existing_player.queue_free()
		# 等待一帧确保节点被移除
		await get_tree().process_frame
	
	# 加载角色场景
	var character_scene = load(character_data.scene_path) as PackedScene
	if not character_scene:
		print("错误：无法加载角色场景 ", character_data.scene_path)
		return
	
	# 实例化角色场景
	var player_instance = character_scene.instantiate()
	if not player_instance:
		print("错误：无法实例化角色场景")
		return
	
	player_instance.name = "player"
	
	# 获取摄像机位置，将角色放置在摄像机中心
	var camera = get_node_or_null("Camera2D") as Camera2D
	if camera:
		# 使用摄像机的全局位置作为角色位置
		player_instance.global_position = camera.global_position
	else:
		# 如果找不到摄像机，使用原点作为默认位置
		player_instance.position = Vector2.ZERO
		print("警告：未找到摄像机，角色将放置在原点")
	
	add_child(player_instance)
	player = player_instance as BaseCharacter
	
	if not player:
		print("错误：角色场景根节点不是 BaseCharacter 类型")
		return
	
	# 初始化角色
	player.initialize(character_data)
	connect_player_signals()
	
	# 同步血量到RunManager，并注册角色节点以应用升级
	if RunManager:
		RunManager.set_health(player.current_health, player.max_health)
		RunManager.set_character_node(player)
		# 自动装备库存中的所有圣遗物
		RunManager.equip_all_inventory_artifacts()
	
	# 通知相机更新目标（如果相机存在）
	_update_camera_target()

## 连接玩家信号
func connect_player_signals() -> void:
	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
		if player.has_signal("character_died"):
			player.character_died.connect(_on_player_died)
		
		# 连接技能冷却时间信号
		if player.has_signal("skill_cooldown_changed"):
			player.skill_cooldown_changed.connect(_on_skill_cooldown_changed)
		
		# 连接大招充能信号
		if player.has_signal("burst_energy_changed"):
			player.burst_energy_changed.connect(_on_burst_energy_changed)
		
		# 初始化血量UI显示
		if player.has_method("get_current_health") and player.has_method("get_max_health"):
			_on_player_health_changed(player.get_current_health(), player.get_max_health())
		
		# 初始化技能UI（根据角色ID动态加载图标）
		if skill_ui and RunManager and RunManager.current_character:
			var skill_icon_path = _get_skill_icon_path(RunManager.current_character.id)
			if skill_icon_path:
				var skill_icon = _load_texture(skill_icon_path)
				if skill_icon:
					skill_ui.set_skill_icon(skill_icon)
		
		# 初始化大招UI（根据角色ID动态加载图标）
		if burst_ui and RunManager and RunManager.current_character:
			var burst_icon_path = _get_burst_icon_path(RunManager.current_character.id)
			if burst_icon_path:
				var burst_icon = _load_texture(burst_icon_path)
				if burst_icon:
					burst_ui.set_skill_icon(burst_icon)

## 敌人生成计时器回调
func _on_enemy_spawn_timer_timeout() -> void:
	if current_state == GameState.PLAYING:
		spawn_enemy()

## 生成敌人函数
func spawn_enemy() -> void:
	if enemy_scene == null:
		print("错误：敌人场景未加载")
		return
	
	# 实例化敌人场景
	var enemy_instance = enemy_scene.instantiate()
	
	# 如果敌人有initialize方法，使用RunManager的数据初始化
	if enemy_instance.has_method("initialize"):
		# 随机选择一个敌人类型
		var enemy_types = DataManager.get_enemies_by_type("normal")
		
		if not enemy_types.is_empty():
			var enemy_data = enemy_types[randi() % enemy_types.size()]
			enemy_instance.initialize(enemy_data)
	
	# 在椭圆空气墙内部随机生成位置
	var spawn_pos: Vector2
	var boundary := get_node_or_null("EllipseBoundary") as EllipseBoundary
	if boundary:
		var center: Vector2 = boundary.global_position
		var a: float = boundary.ellipse_radius_x
		var b: float = boundary.ellipse_radius_y
		# 留出边界厚度与安全距离，避免生成贴边卡墙
		var margin: float = max(20.0, boundary.boundary_thickness)
		a = max(0.0, a - margin)
		b = max(0.0, b - margin)
		
		# 采样均匀分布在椭圆内部的随机点
		var angle: float = randf() * TAU
		var r: float = sqrt(randf())  # 保证在圆内均匀分布
		var local: Vector2 = Vector2(cos(angle) * a * r, sin(angle) * b * r)
		spawn_pos = center + local
	else:
		# 兜底：如果没有找到空气墙，就按屏幕范围随机生成
		var screen_size = get_viewport().get_visible_rect().size
		var spawn_x = randf_range(100, screen_size.x - 100)
		var spawn_y = randf_range(100, screen_size.y - 100)
		spawn_pos = Vector2(spawn_x, spawn_y)
	
	# 设置敌人位置（使用全局坐标，保证与空气墙一致）
	enemy_instance.global_position = spawn_pos
	
	# 添加到场景树中
	add_child(enemy_instance)
	_register_enemy(enemy_instance)
	_apply_hitbox_visibility_to_enemy(enemy_instance)
	
	print("生成新敌人，位置：", enemy_instance.position)

## 更新敌人击杀计数器显示
func update_enemy_kill_counter_display() -> void:
	if enemy_kill_counter_label:
		var remaining = max(0, required_score - current_score)
		enemy_kill_counter_label.text = str(remaining)

## 更新摩拉显示
func _update_gold_display() -> void:
	if gold_label and RunManager:
		gold_label.text = str(RunManager.gold)

## 敌人被击杀回调（由敌人死亡时调用）
## score: 该敌人的分值
func on_enemy_killed(score: int = 1) -> void:
	if current_state != GameState.PLAYING:
		return
	
	current_score += score  # 累加敌人的分值
	print("敌人被击杀！获得 ", score, " 分，当前得分：", current_score, "/", required_score)
	
	# 更新得分显示
	update_enemy_kill_counter_display()
	
	# 检查是否达到胜利条件
	if current_score >= required_score:
		battle_victory()

## 战斗胜利方法
func battle_victory() -> void:
	if current_state == GameState.GAME_OVER:
		return
	
	current_state = GameState.GAME_OVER
	is_battle_victory = true  # 标记为真正的战斗胜利
	
	# 停止敌人生成计时器
	if enemy_spawn_timer:
		enemy_spawn_timer.stop()
	
	# 立刻清除场上所有敌人
	clear_all_enemies()
	
	print("战斗胜利！当前得分：", current_score, "。3秒后返回地图...")
	
	# 设置3秒后返回地图
	game_over_timer.wait_time = 3.0
	game_over_timer.start()

## 清除场上所有敌人
func clear_all_enemies() -> void:
	var enemies := _active_enemies.duplicate()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_active_enemies.clear()
	print("已清除场上所有敌人，共 ", enemies.size(), " 个")

## 游戏结束方法（玩家死亡）
func game_over() -> void:
	if current_state == GameState.GAME_OVER:
		return
	
	current_state = GameState.GAME_OVER
	
	# 停止敌人生成计时器
	if enemy_spawn_timer:
		enemy_spawn_timer.stop()
	
	print("游戏结束！3秒后返回地图...")
	
	# 设置3秒后返回地图
	game_over_timer.wait_time = 3.0
	game_over_timer.start()

## 游戏结束计时器回调
func _on_game_over_timer_timeout() -> void:
	# 使用明确的胜利标志判断是胜利还是失败
	# 只有通过击杀足够数量的敌人正常结束战斗才算胜利
	# 玩家死亡则无论击杀数多少都算失败
	if is_battle_victory:
		# 战斗胜利，显示升级选择界面
		if GameManager:
			GameManager.show_upgrade_selection()
	else:
		# 战斗失败，直接返回地图
		if RunManager:
			RunManager.end_run(false)
		if GameManager:
			GameManager.go_to_map_view()

## 玩家血量变化回调
func _on_player_health_changed(current: float, maximum: float) -> void:
	update_player_hp_display(current, maximum)

## 更新玩家血量UI显示
func update_player_hp_display(current: float, maximum: float) -> void:
	if player_hp_bar:
		player_hp_bar.max_value = maximum
		player_hp_bar.value = current
	if player_hp_label:
		player_hp_label.text = str(int(current)) + "/" + str(int(maximum))

## 玩家死亡回调
func _on_player_died() -> void:
	game_over()

## 金币变化回调
func _on_gold_changed(gold: int) -> void:
	# 更新摩拉显示
	if gold_label:
		gold_label.text = str(gold)
	
	# 初始化时也更新一次
	if RunManager:
		_update_gold_display()

## 调试开关：显示/隐藏判定与碰撞箱
func _on_debug_toggle_pressed() -> void:
	debug_show_hitboxes = not debug_show_hitboxes
	_update_all_hitbox_visibility()
	if debug_toggle_button:
		debug_toggle_button.text = "隐藏判定" if debug_show_hitboxes else "显示判定"

## 更新所有相关碰撞/攻击判定的可见性
func _update_all_hitbox_visibility() -> void:
	_apply_hitbox_visibility_to_player()
	for enemy in _active_enemies:
		if is_instance_valid(enemy):
			_apply_hitbox_visibility_to_enemy(enemy)

## 注册敌人（用于清场/指示器/调试显示）
func _register_enemy(enemy: Node) -> void:
	if not enemy:
		return
	if enemy not in _active_enemies:
		_active_enemies.append(enemy)
	# 敌人退出树时自动移除
	if enemy is Node:
		if not enemy.tree_exited.is_connected(_on_enemy_tree_exited):
			enemy.tree_exited.connect(_on_enemy_tree_exited.bind(enemy))

func _on_enemy_tree_exited(enemy: Node) -> void:
	_active_enemies.erase(enemy)

## 对外提供当前活跃敌人列表（只读副本）
func get_active_enemies() -> Array:
	return _active_enemies.duplicate()

func _apply_hitbox_visibility_to_player() -> void:
	if not player:
		return
	var body_shape = player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var sword_shape = player.get_node_or_null("SwordArea/CollisionShape2D") as CollisionShape2D
	_set_shape_visible(body_shape, debug_show_hitboxes, Color(0, 0.8, 1, 0.3))
	_set_shape_visible(sword_shape, debug_show_hitboxes, Color(1, 0.6, 0, 0.3))

func _apply_hitbox_visibility_to_enemy(enemy_node: Node) -> void:
	var enemy_shape = enemy_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_set_shape_visible(enemy_shape, debug_show_hitboxes, Color(1, 0, 0, 0.3))

## 技能冷却时间变化回调
func _on_skill_cooldown_changed(remaining_time: float, cooldown_time: float) -> void:
	if skill_ui:
		skill_ui.update_cooldown(remaining_time, cooldown_time)

## 大招充能进度变化回调
func _on_burst_energy_changed(current_energy: float, max_energy: float) -> void:
	if burst_ui:
		burst_ui.update_energy(current_energy, max_energy)

## 统一设置碰撞形状的可见性与颜色（Godot 4可直接显示CollisionShape2D）
func _set_shape_visible(shape: CollisionShape2D, visible_state: bool, debug_color: Color) -> void:
	if not shape:
		return
	var overlay: Node2D = null
	if shape.has_meta("debug_overlay"):
		overlay = shape.get_meta("debug_overlay") as Node2D
	if visible_state:
		if overlay == null:
			overlay = _create_shape_overlay(shape, debug_color)
			if overlay:
				shape.add_child(overlay)
				shape.set_meta("debug_overlay", overlay)
		if overlay:
			overlay.visible = true
	else:
		if overlay:
			overlay.visible = false

## 为给定CollisionShape2D创建可视化Polygon2D覆盖
func _create_shape_overlay(shape: CollisionShape2D, color: Color) -> Node2D:
	if not shape or not shape.shape:
		return null
	var poly := Polygon2D.new()
	poly.color = color
	poly.z_index = 999
	
	if shape.shape is RectangleShape2D:
		var extents: Vector2 = (shape.shape as RectangleShape2D).size * 0.5
		poly.polygon = PackedVector2Array([
			Vector2(-extents.x, -extents.y),
			Vector2(extents.x, -extents.y),
			Vector2(extents.x, extents.y),
			Vector2(-extents.x, extents.y),
		])
	elif shape.shape is CircleShape2D:
		var radius: float = (shape.shape as CircleShape2D).radius
		var points: Array[Vector2] = []
		var segments := 28
		for i in range(segments):
			var angle = TAU * float(i) / float(segments)
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		poly.polygon = PackedVector2Array(points)
	elif shape.shape is CapsuleShape2D:
		var capsule := shape.shape as CapsuleShape2D
		var radius: float = capsule.radius
		var height: float = capsule.height
		var points: Array[Vector2] = []
		var segments := 20
		# 上半圆
		for i in range(segments / 2 + 1):
			var angle = PI * float(i) / float(segments / 2)
			points.append(Vector2(cos(angle) * radius, -height * 0.5 + sin(angle) * radius))
		# 下半圆
		for i in range(segments / 2, -1, -1):
			var angle = PI * float(i) / float(segments / 2)
			points.append(Vector2(cos(angle) * radius, height * 0.5 + sin(angle) * radius))
		poly.polygon = PackedVector2Array(points)
	else:
		# 其他形状暂不处理
		return null
	
	return poly

## 统一加载纹理（使用DataManager缓存）
func _load_texture(path: String) -> Texture2D:
	if DataManager:
		return DataManager.get_texture(path)
	return load(path) as Texture2D

## 根据角色ID获取技能图标路径
func _get_skill_icon_path(character_id: String) -> String:
	match character_id:
		"kamisato_ayaka":
			return "res://textures/icons/神里技能图标.png"
		_:
			# 默认尝试根据角色ID构建路径
			return "res://textures/icons/%s技能图标.png" % character_id

## 根据角色ID获取大招图标路径
func _get_burst_icon_path(character_id: String) -> String:
	match character_id:
		"kamisato_ayaka":
			return "res://textures/icons/ayaka大招图标.png"
		_:
			# 默认尝试根据角色ID构建路径
			return "res://textures/icons/%s大招图标.png" % character_id

## 更新相机目标（玩家创建后调用）
func _update_camera_target() -> void:
	if not player:
		return
	
	# 查找场景中的相机
	var camera = get_node_or_null("Camera2D") as Camera2D
	if camera and camera.has_method("_update_target"):
		camera._update_target()
		print("已通知相机更新目标")

## 设置自定义鼠标准星
func _apply_crosshair_cursor() -> void:
	if CROSSHAIR_TEXTURE:
		var hotspot := CROSSHAIR_TEXTURE.get_size() * 0.5
		Input.set_custom_mouse_cursor(CROSSHAIR_TEXTURE, Input.CURSOR_ARROW, hotspot)

## 离开战斗场景时还原鼠标
func _restore_default_cursor() -> void:
	Input.set_custom_mouse_cursor(null)

## 将楼层提示移动到转场层（确保显示在黑屏之上）
func _move_floor_notification_to_transition_layer() -> void:
	if not floor_notification or not TransitionManager:
		return
	
	# 确保转场层已创建
	TransitionManager._ensure_transition_layer()
	
	# 直接访问 transition_layer 变量（GDScript 中没有真正的私有变量）
	var transition_layer = TransitionManager.transition_layer
	if not transition_layer:
		return
	
	# 如果楼层提示已经在转场层中，只需要确保 z_index 正确
	if floor_notification.get_parent() == transition_layer:
		floor_notification.z_index = 1
		return
	
	# 保存原始父节点路径（如果需要恢复）
	if not floor_notification.has_meta("original_parent_path"):
		var original_parent = floor_notification.get_parent()
		if original_parent:
			floor_notification.set_meta("original_parent_path", original_parent.get_path())
	
	# 获取全局位置和缩放
	var global_pos = floor_notification.global_position
	var scale = floor_notification.scale
	
	# 从原父节点移除
	var original_parent = floor_notification.get_parent()
	if original_parent:
		original_parent.remove_child(floor_notification)
	
	# 添加到转场层
	transition_layer.add_child(floor_notification)
	
	# 恢复全局位置和缩放
	floor_notification.global_position = global_pos
	floor_notification.scale = scale
	
	# 设置 z_index，确保在转场遮罩之上（遮罩的 z_index 默认是 0）
	floor_notification.z_index = 1

## 显示层数提示
func show_floor_notification() -> void:
	if not floor_notification or not floor_notification_label:
		return
	
	# 获取当前层数
	var current_floor = RunManager.current_floor if RunManager else 1
	
	# 设置提示文本
	floor_notification_label.text = "正在进入第%d层" % current_floor

	# 将提示框位置调整为屏幕中心
	var viewport_size := get_viewport().get_visible_rect().size
	# 先确保已经有正确的尺寸信息
	await get_tree().process_frame
	var notif_size: Vector2 = floor_notification.size
	# 使提示框居于屏幕中心（基于自身尺寸做偏移）
	floor_notification.position = viewport_size * 0.5 - notif_size * 0.5

	# 与“还需得分”一起播放出现动画（得分UI不消失）
	# 设置楼层提示初始状态：完全可见（在黑屏上显示）
	floor_notification.visible = true
	floor_notification.modulate.a = 1.0
	floor_notification.scale = Vector2.ONE
	
	# 楼层提示会随黑屏一同淡出，不需要单独的淡出动画和定时器
	# 与"还需得分"一起播放出现动画（得分UI不消失）
	_play_enemy_kill_counter_intro()

## 敌人击杀计数器出现动画
## - "还需得分"只做出现动画，不会被隐藏
func _play_enemy_kill_counter_intro() -> void:
	# 还需得分：出现动画
	if enemy_kill_counter:
		enemy_kill_counter.visible = true
		# 保存目标位置
		var target_pos_score := enemy_kill_counter.position
		# 设置起始位置（从上方）
		enemy_kill_counter.position = target_pos_score + Vector2(0, -40)
		enemy_kill_counter.modulate.a = 0.0
		enemy_kill_counter.scale = Vector2(0.85, 0.85)
		
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(enemy_kill_counter, "modulate:a", 1.0, 0.5)
		tween.parallel().tween_property(enemy_kill_counter, "scale", Vector2.ONE, 0.5)
		tween.parallel().tween_property(enemy_kill_counter, "position", target_pos_score, 0.5)
## - 层数提示仍会按原逻辑淡出隐藏
## - “还需得分”只做出现动画，不会被隐藏
func _play_top_ui_intro() -> void:
	# 层数提示：从上方滑入 + 淡入 + 缩放出现
	if floor_notification:
		floor_notification.visible = true
		# 保存目标位置
		var target_pos := floor_notification.position
		# 设置起始位置（从上方）
		floor_notification.position = target_pos + Vector2(0, -40)
		floor_notification.modulate.a = 0.0
		floor_notification.scale = Vector2(0.85, 0.85)
		
		var t1 = create_tween()
		t1.set_ease(Tween.EASE_OUT)
		t1.set_trans(Tween.TRANS_BACK)
		t1.tween_property(floor_notification, "modulate:a", 1.0, 0.5)
		t1.parallel().tween_property(floor_notification, "scale", Vector2.ONE, 0.5)
		t1.parallel().tween_property(floor_notification, "position", target_pos, 0.5)
	
	# 还需得分：同样出现，但不安排消失
	if enemy_kill_counter:
		enemy_kill_counter.visible = true
		# 保存目标位置
		var target_pos_score := enemy_kill_counter.position
		# 设置起始位置（从上方）
		enemy_kill_counter.position = target_pos_score + Vector2(0, -40)
		enemy_kill_counter.modulate.a = 0.0
		enemy_kill_counter.scale = Vector2(0.85, 0.85)
		
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(enemy_kill_counter, "modulate:a", 1.0, 0.5)
		tween.parallel().tween_property(enemy_kill_counter, "scale", Vector2.ONE, 0.5)
		tween.parallel().tween_property(enemy_kill_counter, "position", target_pos_score, 0.5)
