extends Node2D
class_name BattleManager

## 战斗管理器
## 管理战斗场景的状态和逻辑

# 胜利提示与转场参数
const LEVEL_GOAL_COMPLETED_TEXT: String = "已完成当前层级目标"
const VICTORY_NOTIFY_SECONDS: float = 1.2
const VICTORY_TRANSITION_SECONDS: float = 0.6

# 战斗场景准星贴图
const CROSSHAIR_TEXTURE := preload("res://textures/effects/mouse.png")

const SETTINGS_FILE_PATH = "user://settings.cfg"
const CONFIG_SECTION_POSTPROCESS = "postprocess"
const CONFIG_KEY_BLOOM_ENABLED = "bloom_enabled"

const CONFIG_SECTION_UI = "ui"
const CONFIG_KEY_NSFW_ENABLED = "nsfw_enabled"

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

# BOSS战模式
var is_boss_battle: bool = false  # 是否为BOSS战模式

var _bloom_enabled: bool = true

# 玩家血量UI引用
var player_hp_bar: ProgressBar
var player_hp_label: Label
# 敌人击杀计数器UI引用
var enemy_kill_counter: Control
var enemy_kill_counter_label: Label
# 摩拉显示UI引用
var gold_label: Label
var gold_icon: TextureRect
# 原石显示UI引用
var primogem_label: Label
var primogem_icon: TextureRect
# 技能UI引用
var skill_ui: SkillUI
# 大招UI引用
var burst_ui: SkillUI
# NSFW表情展示UI引用
var face_display: TextureRect

const _FACE_SUBFOLDER: String = "face"
const _FACE_NORMAL_FILE: String = "正常.png"
const _FACE_SCARED_FILE: String = "害怕.png"
const _FACE_CRYING_FILE: String = "哭泣.png"
const _FACE_ORGASM_FILE: String = "高潮.png"

var _nsfw_enabled: bool = false
var _face_hit_override_active: bool = false
var _face_hit_override_timer: Timer
var _last_hp_ratio: float = 1.0
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
# 普通敌人数据缓存：避免每次生成都遍历 DataManager.enemies
var _normal_enemy_types: Array = []
# 敌人生成队列：分帧实例化，降低同帧尖峰
var _pending_enemy_spawns: int = 0
var _is_processing_enemy_spawn_queue: bool = false

# 敌人对象池：复用已实例化的敌人，减少刷怪时 instantiate 卡顿
const ENEMY_POOL_PREWARM_COUNT: int = 6
const ENEMY_POOL_MAX_SIZE: int = 24
var _enemy_pool: Array[Node] = []

func _ready() -> void:
	# 检查是否为BOSS战场景
	_check_boss_battle_mode()
	_initialize_ui_components()
	_initialize_player()
	_initialize_battle_conditions()
	_initialize_enemy_spawning()
	_initialize_timers()
	_connect_signals()
	_initialize_pause_menu()
	_apply_crosshair_cursor()
	_apply_bloom_enabled_from_settings()
	_apply_nsfw_enabled_from_settings()
	
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

func _apply_bloom_enabled_from_settings() -> void:
	var config := ConfigFile.new()
	var err: Error = config.load(SETTINGS_FILE_PATH)
	var enabled: bool = true
	if err == OK:
		enabled = bool(config.get_value(CONFIG_SECTION_POSTPROCESS, CONFIG_KEY_BLOOM_ENABLED, true))
	set_bloom_enabled(enabled)

func _apply_nsfw_enabled_from_settings() -> void:
	var config := ConfigFile.new()
	var err: Error = config.load(SETTINGS_FILE_PATH)
	var enabled: bool = false
	if err == OK:
		enabled = bool(config.get_value(CONFIG_SECTION_UI, CONFIG_KEY_NSFW_ENABLED, false))
	set_nsfw_enabled(enabled)

func set_bloom_enabled(is_enabled: bool) -> void:
	_bloom_enabled = is_enabled
	var bloom_layer := get_node_or_null("BloomLayer") as CanvasLayer
	if bloom_layer:
		bloom_layer.visible = is_enabled

## 初始化UI组件
func _initialize_ui_components() -> void:
	player_hp_bar = get_node_or_null("CanvasLayer/PlayerHPBar/ProgressBar") as ProgressBar
	player_hp_label = get_node_or_null("CanvasLayer/PlayerHPBar/Label") as Label
	enemy_kill_counter = get_node_or_null("CanvasLayer/EnemyKillCounter") as Control
	enemy_kill_counter_label = get_node_or_null("CanvasLayer/EnemyKillCounter/Label") as Label
	skill_ui = get_node_or_null("CanvasLayer/SkillUIContainer/SkillUI") as SkillUI
	burst_ui = get_node_or_null("CanvasLayer/BurstUIContainer/BurstUI") as SkillUI
	face_display = get_node_or_null("CanvasLayer/FaceDisplay") as TextureRect
	gold_label = get_node_or_null("CanvasLayer/GoldDisplay/Label") as Label
	gold_icon = get_node_or_null("CanvasLayer/GoldDisplay/Icon") as TextureRect
	primogem_label = get_node_or_null("CanvasLayer/PrimogemDisplay/Label") as Label
	primogem_icon = get_node_or_null("CanvasLayer/PrimogemDisplay/Icon") as TextureRect
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

## 检查是否为BOSS战模式
func _check_boss_battle_mode() -> void:
	var scene_name = get_tree().current_scene.scene_file_path
	is_boss_battle = scene_name.ends_with("boss_battle.tscn")
	if is_boss_battle:
		print("BOSS战模式已激活")

## 初始化战斗条件
func _initialize_battle_conditions() -> void:
	current_score = 0
	if is_boss_battle:
		# BOSS战：只需要击杀1个BOSS即可胜利
		required_score = 1
	else:
		var current_floor = RunManager.current_floor
		required_score = 5 + (current_floor - 1) * 5
	update_enemy_kill_counter_display()
	_update_gold_display()
	_update_primogem_display()

## 初始化敌人生成系统
func _initialize_enemy_spawning() -> void:
	if enemy_scene == null:
		enemy_scene = preload("res://scenes/enemies/enemy.tscn")
	_refresh_enemy_type_cache()
	# 方案A：普通敌人按 EnemyData.scene_path 实例化，单一对象池会导致不同敌人场景混用复用，先禁用预热。
	if DataManager and DataManager.has_signal("data_loaded"):
		if not DataManager.data_loaded.is_connected(_on_data_loaded):
			DataManager.data_loaded.connect(_on_data_loaded)

func _on_data_loaded() -> void:
	_refresh_enemy_type_cache()

func _refresh_enemy_type_cache() -> void:
	if not DataManager:
		return
	_normal_enemy_types = DataManager.get_enemies_by_type("normal")

func _prewarm_enemy_pool(count: int) -> void:
	if count <= 0:
		return
	if enemy_scene == null:
		return
	# 预热阶段只 instantiate，不入树，避免触发 _ready/计时器
	while _enemy_pool.size() < min(ENEMY_POOL_MAX_SIZE, count):
		var inst := enemy_scene.instantiate() as Node
		if inst:
			_enemy_pool.append(inst)
		else:
			break

func _acquire_enemy_instance() -> Node:
	if not _enemy_pool.is_empty():
		return _enemy_pool.pop_back() as Node
	if enemy_scene == null:
		return null
	return enemy_scene.instantiate() as Node

func recycle_enemy(enemy) -> void:
	if not is_instance_valid(enemy):
		return
	# 方案A：禁用普通敌人对象池回收（普通敌人可能来自不同 scene_path）。
	# 这里保留 prepare_for_pool 的调用，用于停止残留状态，随后直接释放。
	if enemy.has_method("prepare_for_pool"):
		enemy.call("prepare_for_pool")
	enemy.queue_free()

## 初始化计时器
func _initialize_timers() -> void:
	# 创建游戏结束计时器
	game_over_timer = Timer.new()
	game_over_timer.one_shot = true
	game_over_timer.timeout.connect(_on_game_over_timer_timeout)
	add_child(game_over_timer)
	
	# BOSS战模式：不启动计时器，直接生成BOSS
	if is_boss_battle:
		# 延迟一小段时间后生成BOSS，确保场景已完全加载
		await get_tree().create_timer(0.5).timeout
		spawn_boss()
		return
	
	# 普通战斗模式：创建敌人生成计时器
	enemy_spawn_timer = Timer.new()
	var current_floor = RunManager.current_floor
	enemy_spawn_timer.wait_time = _calculate_enemy_spawn_time(current_floor)
	var spawn_count = _calculate_enemy_spawn_count(current_floor)
	var multipliers = _calculate_enemy_stat_multipliers(current_floor)
	if OS.is_debug_build():
		print("当前楼层：", current_floor)
		print("  - 怪物生成间隔：", enemy_spawn_timer.wait_time, "秒")
		print("  - 每波生成数量：", spawn_count, "个")
		print("  - 血量倍率：x%.2f，攻击倍率：x%.2f" % [multipliers[0], multipliers[1]])
	enemy_spawn_timer.timeout.connect(_on_enemy_spawn_timer_timeout)
	add_child(enemy_spawn_timer)
	enemy_spawn_timer.start()

## 计算敌人生成时间（固定间隔）
func _calculate_enemy_spawn_time(_current_floor: int) -> float:
	# 固定生成间隔，通过增加每波敌人数量来提升难度
	return 3.0

## 计算每波生成的敌人数量（根据楼层）
func _calculate_enemy_spawn_count(current_floor: int) -> int:
	# 第1层生成1个，每2层增加1个，最多5个
	const BASE_COUNT = 1
	const INCREASE_PER_TWO_FLOORS = 1
	const MAX_COUNT = 5
	
	var floors_up = int((current_floor - 1) / 2)  # 每两层算一次提升（向下取整）
	var calculated_count = BASE_COUNT + floors_up * INCREASE_PER_TWO_FLOORS
	return min(MAX_COUNT, calculated_count)

## 计算敌人属性缩放倍率（根据楼层）
## 返回 [血量倍率, 攻击力倍率]
func _calculate_enemy_stat_multipliers(current_floor: int) -> Array:
	# 基础倍率为1.0，每层增加一定比例
	const HEALTH_INCREASE_PER_FLOOR = 0.15  # 每层血量增加15%
	const ATTACK_INCREASE_PER_FLOOR = 0.10  # 每层攻击力增加10%
	
	var health_multiplier = 1.0 + (current_floor - 1) * HEALTH_INCREASE_PER_FLOOR
	var attack_multiplier = 1.0 + (current_floor - 1) * ATTACK_INCREASE_PER_FLOOR
	
	return [health_multiplier, attack_multiplier]

## 连接信号
func _connect_signals() -> void:
	RunManager.health_changed.connect(_on_player_health_changed)
	RunManager.gold_changed.connect(_on_gold_changed)
	if GameManager and GameManager.has_signal("primogems_total_changed"):
		GameManager.primogems_total_changed.connect(_on_primogems_total_changed)

func _exit_tree() -> void:
	_restore_floor_notification_from_transition_layer()
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
	var pause_menu_scene = DataManager.get_packed_scene("res://scenes/ui/pause_menu.tscn")
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
	if pause_menu.has_signal("open_settings"):
		pause_menu.open_settings.connect(_on_pause_menu_open_settings)
	
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

## 暂停菜单打开设置
func _on_pause_menu_open_settings() -> void:
	# 设置界面由暂停菜单自己管理
	pass

## 获取玩家实例（供暂停菜单使用）
func get_player() -> BaseCharacter:
	return player

## 初始化玩家
func initialize_player() -> void:
	if not RunManager.current_character:
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
	var character_scene: PackedScene = null
	character_scene = DataManager.get_packed_scene(character_data.scene_path)
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
		
		# 连接受击事件（用于NSFW表情：害怕1秒）
		if player.has_signal("damaged"):
			player.damaged.connect(_on_player_damaged)
		
		# 初始化技能UI（根据角色ID动态加载图标）
		if skill_ui and RunManager.current_character:
			var skill_icon_path = _get_skill_icon_path(RunManager.current_character.id)
			if skill_icon_path:
				var skill_icon = _load_texture(skill_icon_path)
				if skill_icon:
					skill_ui.set_skill_icon(skill_icon)
		
		# 初始化大招UI（根据角色ID动态加载图标）
		if burst_ui and RunManager.current_character:
			var burst_icon_path = _get_burst_icon_path(RunManager.current_character.id)
			if burst_icon_path:
				var burst_icon = _load_texture(burst_icon_path)
				if burst_icon:
					burst_ui.set_skill_icon(burst_icon)

## 敌人生成计时器回调
func _on_enemy_spawn_timer_timeout() -> void:
	if current_state == GameState.PLAYING and not is_boss_battle:
		var current_floor = RunManager.current_floor
		var spawn_count = _calculate_enemy_spawn_count(current_floor)
		_enqueue_enemy_spawns(spawn_count)
		if OS.is_debug_build():
			print("本波生成敌人数量：", spawn_count)

func _enqueue_enemy_spawns(count: int) -> void:
	if count <= 0:
		return
	_pending_enemy_spawns += count
	if not _is_processing_enemy_spawn_queue:
		_process_enemy_spawn_queue()

func _process_enemy_spawn_queue() -> void:
	_is_processing_enemy_spawn_queue = true
	while _pending_enemy_spawns > 0:
		if current_state != GameState.PLAYING or is_boss_battle:
			break
		_pending_enemy_spawns -= 1
		spawn_enemy()
		# 每帧最多生成 1 个，避免 instantiate/add_child 同帧尖峰
		await get_tree().process_frame
	_is_processing_enemy_spawn_queue = false

## 生成BOSS（BOSS战模式专用）
func spawn_boss() -> void:
	# 获取BOSS数据
	var boss_enemies = DataManager.get_enemies_by_type("boss")
	if boss_enemies.is_empty():
		print("错误：未找到BOSS类型敌人")
		return
	
	# 使用第一个BOSS（boss1）
	var boss_data = boss_enemies[0] as EnemyData
	if not boss_data:
		print("错误：BOSS数据无效")
		return
	
	# 加载BOSS场景
	var boss_scene_path = boss_data.scene_path
	var boss_scene: PackedScene = null
	boss_scene = DataManager.get_packed_scene(boss_scene_path)
	
	if not boss_scene:
		print("错误：无法加载BOSS场景：", boss_scene_path)
		return
	
	# 实例化BOSS
	var boss_instance = boss_scene.instantiate()
	if not boss_instance:
		print("错误：无法实例化BOSS场景")
		return
	
	# 初始化BOSS
	if boss_instance.has_method("initialize"):
		boss_instance.initialize(boss_data)
	
	# BOSS战不应用楼层缩放（使用BOSS原始属性）
	# 如果需要，可以在这里应用特殊的BOSS属性缩放
	
	# 在椭圆空气墙中心生成BOSS
	var spawn_pos: Vector2
	var boundary := get_node_or_null("EllipseBoundary") as EllipseBoundary
	if boundary:
		spawn_pos = boundary.global_position
	else:
		# 兜底：使用屏幕中心
		var screen_size = get_viewport().get_visible_rect().size
		spawn_pos = screen_size / 2.0
	
	boss_instance.global_position = spawn_pos
	
	# 添加到场景树中
	add_child(boss_instance)
	_register_enemy(boss_instance)
	_apply_hitbox_visibility_to_enemy(boss_instance)
	
	print("生成BOSS：", boss_data.display_name, "，位置：", boss_instance.position)

## 生成敌人函数
func spawn_enemy() -> void:
	# 随机选择一个敌人类型（权重随机）
	if _normal_enemy_types.is_empty():
		_refresh_enemy_type_cache()
	var enemy_types = _normal_enemy_types
	if OS.is_debug_build():
		print("获取敌人类型列表，数量：", enemy_types.size())
	if enemy_types.is_empty():
		print("警告：没有找到敌人类型数据，敌人可能无法正常掉落摩拉")
		return
	
	var rng := RunManager.get_rng()
	var enemy_data: EnemyData = null
	var total_weight: float = 0.0
	for e in enemy_types:
		var data := e as EnemyData
		if data == null:
			continue
		total_weight += max(0.0, data.spawn_weight)
	if total_weight <= 0.0:
		enemy_data = enemy_types[0] as EnemyData
	else:
		var pick: float = rng.randf() * total_weight
		for e in enemy_types:
			var data := e as EnemyData
			if data == null:
				continue
			pick -= max(0.0, data.spawn_weight)
			if pick <= 0.0:
				enemy_data = data
				break
		if enemy_data == null:
			enemy_data = enemy_types.back() as EnemyData
	
	# 方案A：按 EnemyData.scene_path 实例化对应敌人场景
	var enemy_scene_path: String = enemy_data.scene_path
	var enemy_packed: PackedScene = null
	if DataManager:
		enemy_packed = DataManager.get_packed_scene(enemy_scene_path)
	else:
		enemy_packed = load(enemy_scene_path) as PackedScene
	if not enemy_packed:
		print("错误：无法加载敌人场景：", enemy_scene_path)
		return
	var enemy_instance := enemy_packed.instantiate()
	if not enemy_instance:
		print("错误：无法实例化敌人场景：", enemy_scene_path)
		return
	
	if enemy_instance.has_method("initialize"):
		if OS.is_debug_build():
			print("初始化敌人，类型：", enemy_data.display_name, "，drop_gold：", enemy_data.drop_gold)
		enemy_instance.initialize(enemy_data)
	
	# 应用楼层属性缩放
	var current_floor = RunManager.current_floor
	var multipliers = _calculate_enemy_stat_multipliers(current_floor)
	_apply_floor_scaling_to_enemy(enemy_instance, multipliers[0], multipliers[1])
	
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
		var angle: float = rng.randf() * TAU
		var r: float = sqrt(rng.randf())  # 保证在圆内均匀分布
		var local: Vector2 = Vector2(cos(angle) * a * r, sin(angle) * b * r)
		spawn_pos = center + local
	else:
		# 兜底：如果没有找到空气墙，就按屏幕范围随机生成
		var screen_size = get_viewport().get_visible_rect().size
		var spawn_x = rng.randf_range(100.0, screen_size.x - 100.0)
		var spawn_y = rng.randf_range(100.0, screen_size.y - 100.0)
		spawn_pos = Vector2(spawn_x, spawn_y)
	
	# 设置敌人位置（使用全局坐标，保证与空气墙一致）
	enemy_instance.global_position = spawn_pos
	
	# 添加到场景树中
	if enemy_instance.get_parent() == null:
		add_child(enemy_instance)
	_register_enemy(enemy_instance)
	_apply_hitbox_visibility_to_enemy(enemy_instance)
	
	if OS.is_debug_build():
		print("生成新敌人，位置：", enemy_instance.position)

## 更新敌人击杀计数器显示
func update_enemy_kill_counter_display() -> void:
	if enemy_kill_counter_label:
		var remaining = max(0, required_score - current_score)
		enemy_kill_counter_label.text = str(remaining)

## 更新摩拉显示
func _update_gold_display() -> void:
	if gold_label:
		gold_label.text = str(RunManager.gold)


## 更新原石显示
func _update_primogem_display() -> void:
	if not primogem_label:
		return
	if not GameManager:
		primogem_label.text = "0"
		return
	primogem_label.text = str(GameManager.get_primogems_total())

## 敌人被击杀回调（由敌人死亡时调用）
## score: 该敌人的分值
func on_enemy_killed(score: int = 1) -> void:
	if current_state != GameState.PLAYING:
		return
	
	current_score += score  # 累加敌人的分值
	if OS.is_debug_build():
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
	
	_show_level_goal_completed_notification()
	
	# BOSS战胜利：结束游戏并标记为胜利
	if is_boss_battle:
		print("BOSS战胜利！游戏完成！")
		# 结束游戏并标记为胜利
		RunManager.end_run(true)
	else:
		print("战斗胜利！当前得分：", current_score, "。即将进入升级选择...")
	
	# 先短暂显示“层级目标完成”提示，再转场进入升级选择
	game_over_timer.wait_time = VICTORY_NOTIFY_SECONDS
	game_over_timer.start()

## 清除场上所有敌人
func clear_all_enemies() -> void:
	var enemies := _active_enemies.duplicate()
	for enemy in enemies:
		if is_instance_valid(enemy):
			recycle_enemy(enemy)
	_active_enemies.clear()
	if OS.is_debug_build():
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
		# BOSS战胜利：转场 -> 结算界面（胜利）
		if is_boss_battle:
			_restore_floor_notification_from_transition_layer()
			if TransitionManager:
				await TransitionManager.fade_out(VICTORY_TRANSITION_SECONDS)
			if GameManager:
				GameManager.show_result(true)
		else:
			# 普通战斗胜利：转场 -> 升级选择界面
			_restore_floor_notification_from_transition_layer()
			if TransitionManager:
				await TransitionManager.fade_out(VICTORY_TRANSITION_SECONDS)
			if GameManager:
				GameManager.show_upgrade_selection()
	else:
		# 战斗失败，直接返回地图
		_restore_floor_notification_from_transition_layer()
		RunManager.end_run(false)
		GameManager.go_to_map_view()

## 显示“已完成当前层级目标”提示（复用 FloorNotification）
func _show_level_goal_completed_notification() -> void:
	if not floor_notification or not floor_notification_label:
		return
	
	# 如果存在转场层，保证提示始终可见
	if TransitionManager:
		_move_floor_notification_to_transition_layer()
	
	floor_notification_label.text = LEVEL_GOAL_COMPLETED_TEXT
	floor_notification.visible = true
	floor_notification.modulate.a = 1.0
	floor_notification.scale = Vector2.ONE

## 归还 FloorNotification 到原父节点，避免转场层持有导致跨场景残留
func _restore_floor_notification_from_transition_layer() -> void:
	if not floor_notification:
		return
	if not floor_notification.has_meta("original_parent_path"):
		return
	
	var original_parent_path: Variant = floor_notification.get_meta("original_parent_path")
	var original_parent: Node = null
	if original_parent_path is NodePath:
		original_parent = get_node_or_null(original_parent_path as NodePath)
	elif original_parent_path is String:
		original_parent = get_node_or_null(NodePath(original_parent_path as String))
	
	if not original_parent:
		return
	
	# 已经在原父节点下则无需处理
	if floor_notification.get_parent() == original_parent:
		return
	
	# 保留全局位置/缩放，避免闪动（即便即将切场也更稳）
	var global_pos := floor_notification.global_position
	var s := floor_notification.scale
	
	var current_parent := floor_notification.get_parent()
	if current_parent:
		current_parent.remove_child(floor_notification)
	original_parent.add_child(floor_notification)
	
	floor_notification.global_position = global_pos
	floor_notification.scale = s
	floor_notification.visible = false

## 玩家血量变化回调
func _on_player_health_changed(current: float, maximum: float) -> void:
	update_player_hp_display(current, maximum)
	_update_face_by_health(current, maximum)

func _on_player_damaged(_damage: float) -> void:
	if not _nsfw_enabled:
		return
	if not face_display:
		return
	_face_hit_override_active = true
	_set_face_texture_by_name(_FACE_SCARED_FILE)
	if _face_hit_override_timer == null:
		_face_hit_override_timer = Timer.new()
		_face_hit_override_timer.one_shot = true
		add_child(_face_hit_override_timer)
		_face_hit_override_timer.timeout.connect(_on_face_hit_override_timeout)
	_face_hit_override_timer.stop()
	_face_hit_override_timer.wait_time = 1.0
	_face_hit_override_timer.start()

func _on_face_hit_override_timeout() -> void:
	_face_hit_override_active = false
	if player and is_instance_valid(player):
		_update_face_by_health(player.current_health, player.max_health)
	else:
		_update_face_by_health(1.0, 1.0)

func set_nsfw_enabled(is_enabled: bool) -> void:
	_nsfw_enabled = is_enabled
	if face_display:
		face_display.visible = is_enabled
	if not is_enabled:
		_face_hit_override_active = false
		if _face_hit_override_timer:
			_face_hit_override_timer.stop()
		return
	# 立即刷新一次表情
	if player:
		_update_face_by_health(player.current_health, player.max_health)

func _update_face_by_health(current: float, maximum: float) -> void:
	if not _nsfw_enabled:
		return
	if not face_display:
		return
	if maximum <= 0.0:
		return
	var ratio := clampf(current / maximum, 0.0, 1.0)
	_last_hp_ratio = ratio
	if _face_hit_override_active:
		_set_face_texture_by_name(_FACE_SCARED_FILE)
		return
	# 规则优先级：受击害怕（1秒） -> 25%以下高潮 -> 50%以下哭泣（血量恢复前不回正常） -> 正常
	if ratio < 0.25:
		_set_face_texture_by_name(_FACE_ORGASM_FILE)
		return
	if ratio < 0.5:
		_set_face_texture_by_name(_FACE_CRYING_FILE)
		return
	_set_face_texture_by_name(_FACE_NORMAL_FILE)

func _set_face_texture_by_name(file_name: String) -> void:
	if not face_display:
		return
	if not RunManager or not RunManager.current_character:
		return
	var character_id: String = str(RunManager.current_character.id)
	if character_id.is_empty():
		return
	var path := "res://textures/characters/%s/%s/%s" % [character_id, _FACE_SUBFOLDER, file_name]
	var tex := _load_texture(path)
	if tex:
		face_display.texture = tex

## 更新玩家血量UI显示
func update_player_hp_display(current: float, maximum: float) -> void:
	if player_hp_bar:
		player_hp_bar.max_value = maximum
		player_hp_bar.value = current
	if player_hp_label:
		player_hp_label.text = str(int(current)) + "/" + str(int(maximum))

## 玩家死亡回调
func _on_player_died() -> void:
	# 注意：玩家死亡后的场景跳转由 GameManager.game_over() 统一处理（CG展示 -> 结算）。
	# BattleManager 这里只负责战斗内收尾，避免与全局流程冲突。
	_on_player_death_cleanup()


func _on_player_death_cleanup() -> void:
	if current_state == GameState.GAME_OVER:
		return
	current_state = GameState.GAME_OVER
	# 停止敌人生成计时器
	if enemy_spawn_timer:
		enemy_spawn_timer.stop()
	# 停止队列生成
	_pending_enemy_spawns = 0
	_is_processing_enemy_spawn_queue = false
	# 避免继续触发本地 game_over_timer 回调
	if game_over_timer:
		game_over_timer.stop()


## 供 GameManager 在死亡转场后调用：淡出战斗HUD
## 注意：这里只做视觉收尾，不负责场景切换。
func fade_out_hud(duration: float = 0.35) -> void:
	var hud_layer := get_node_or_null("CanvasLayer") as Node
	if not hud_layer:
		return
	
	var items: Array[CanvasItem] = []
	var seen: Dictionary = {}
	
	# 先收集 HUD CanvasLayer 下所有 CanvasItem
	for child in hud_layer.get_children():
		if child is CanvasItem:
			var ci := child as CanvasItem
			if not seen.has(ci.get_instance_id()):
				seen[ci.get_instance_id()] = true
				items.append(ci)
	
	# 再补充可能被临时移走的UI节点（例如 FloorNotification 可能被移动到 TransitionLayer）
	if is_instance_valid(floor_notification) and floor_notification is CanvasItem:
		var fn := floor_notification as CanvasItem
		if not seen.has(fn.get_instance_id()):
			seen[fn.get_instance_id()] = true
			items.append(fn)
	if is_instance_valid(enemy_kill_counter) and enemy_kill_counter is CanvasItem:
		var ek := enemy_kill_counter as CanvasItem
		if not seen.has(ek.get_instance_id()):
			seen[ek.get_instance_id()] = true
			items.append(ek)

	if items.is_empty():
		return

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	for ci in items:
		if not is_instance_valid(ci):
			continue
		# 如果本来就不可见，则跳过
		if not ci.visible:
			continue
		tween.parallel().tween_property(ci, "modulate:a", 0.0, duration)
	await tween.finished
	for ci in items:
		if is_instance_valid(ci):
			ci.visible = false

## 金币变化回调
func _on_gold_changed(gold: int) -> void:
	# 更新摩拉显示
	if gold_label:
		gold_label.text = str(gold)
	
	# 初始化时也更新一次
	_update_gold_display()


## 原石总数变化回调
func _on_primogems_total_changed(_total: int) -> void:
	_update_primogem_display()

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
		var cb: Callable
		if enemy.has_meta("_bm_tree_exited_cb"):
			cb = enemy.get_meta("_bm_tree_exited_cb") as Callable
		else:
			cb = Callable(self, "_on_enemy_tree_exited").bind(enemy)
			enemy.set_meta("_bm_tree_exited_cb", cb)
		if not enemy.tree_exited.is_connected(cb):
			enemy.tree_exited.connect(cb)

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

## 应用楼层属性缩放到敌人
func _apply_floor_scaling_to_enemy(enemy_node: Node, health_multiplier: float, attack_multiplier: float) -> void:
	if not enemy_node:
		return
	
	# Node/Object 不能用 `"x" in obj` 判断属性；使用 get() + 空值检查更稳
	var stats = enemy_node.get("current_stats")
	if stats:
		# 缩放血量
		stats.max_health *= health_multiplier
		# 缩放攻击力
		stats.attack *= attack_multiplier
		# 移动速度保持不变
		
		# 同步更新敌人的实际血量
		# 这里用 set()/get_property_list() 兜底，避免对不存在字段的直接访问导致报错
		var has_max := false
		var has_current := false
		for prop in enemy_node.get_property_list():
			if prop.name == "max_health":
				has_max = true
			elif prop.name == "current_health":
				has_current = true
		if has_max:
			enemy_node.set("max_health", stats.max_health)
		if has_current:
			enemy_node.set("current_health", stats.max_health)
		
		if OS.is_debug_build():
			print("敌人属性缩放：HP x%.2f -> %.0f, ATK x%.2f -> %.0f" % [
				health_multiplier, stats.max_health,
				attack_multiplier, stats.attack
			])

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
	
	# BOSS战模式显示特殊文本
	if is_boss_battle:
		floor_notification_label.text = "BOSS战"
	else:
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
