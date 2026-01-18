extends Node

## 单局游戏状态管理器
## 管理当前一局游戏的状态（角色、楼层、金币、升级等）

signal floor_changed(floor: int)
signal gold_changed(gold: int)
signal health_changed(current: float, maximum: float)
signal upgrade_added(upgrade_id: String)

# 当前角色
var current_character: CharacterData = null

# 游戏进度
var current_floor: int = 0
var current_node_id: String = ""  # 当前所在的地图节点ID

# 资源
var gold: int = 0
var health: float = 100.0
var max_health: float = 100.0

# 升级和状态
var upgrades: Dictionary = {}  # upgrade_id -> level
var visited_nodes: Array[String] = []  # 已访问的地图节点ID

# 统计数据
var enemies_killed: int = 0
var damage_dealt: float = 0.0
var damage_taken: float = 0.0
var start_time: float = 0.0

## 开始新的一局游戏
func start_new_run(character: CharacterData) -> void:
	current_character = character
	current_floor = 0
	current_node_id = ""
	gold = 0
	max_health = character.max_health
	health = max_health
	upgrades.clear()
	visited_nodes.clear()
	enemies_killed = 0
	damage_dealt = 0.0
	damage_taken = 0.0
	start_time = Time.get_ticks_msec() / 1000.0
	
	emit_signal("health_changed", health, max_health)
	emit_signal("gold_changed", gold)
	print("开始新的一局游戏，角色：", character.display_name)

## 结束当前局
func end_run(victory: bool = false) -> void:
	var run_time = (Time.get_ticks_msec() / 1000.0) - start_time
	
	var run_record = {
		"character_id": current_character.id if current_character else "",
		"character_name": current_character.display_name if current_character else "",
		"floors_cleared": current_floor,
		"enemies_killed": enemies_killed,
		"gold_earned": gold,
		"damage_dealt": damage_dealt,
		"damage_taken": damage_taken,
		"time_elapsed": run_time,
		"victory": victory,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# 保存结算记录
	GameManager.save_run_record(run_record)
	
	print("游戏结束，胜利：", victory, "，楼层：", current_floor)

## 设置当前楼层
func set_floor(floor_num: int) -> void:
	current_floor = floor_num
	emit_signal("floor_changed", floor_num)

## 增加金币
func add_gold(amount: int) -> void:
	gold += amount
	emit_signal("gold_changed", gold)

## 消耗金币
func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		emit_signal("gold_changed", gold)
		return true
	return false

## 受到伤害
func take_damage(amount: float) -> void:
	health -= amount
	health = max(0, health)
	damage_taken += amount
	emit_signal("health_changed", health, max_health)

## 回复血量
func heal(amount: float) -> void:
	health += amount
	health = min(health, max_health)
	emit_signal("health_changed", health, max_health)

## 设置血量
func set_health(current: float, maximum: float) -> void:
	health = current
	max_health = maximum
	emit_signal("health_changed", health, max_health)

## 添加升级
func add_upgrade(upgrade_id: String, level: int = 1) -> void:
	if upgrades.has(upgrade_id):
		upgrades[upgrade_id] += level
	else:
		upgrades[upgrade_id] = level
	emit_signal("upgrade_added", upgrade_id)

## 获取升级等级
func get_upgrade_level(upgrade_id: String) -> int:
	return upgrades.get(upgrade_id, 0)

## 记录击杀敌人
func record_enemy_kill() -> void:
	enemies_killed += 1

## 记录造成伤害
func record_damage_dealt(amount: float) -> void:
	damage_dealt += amount

## 访问节点
func visit_node(node_id: String) -> void:
	if node_id not in visited_nodes:
		visited_nodes.append(node_id)

## 检查节点是否已访问
func is_node_visited(node_id: String) -> bool:
	return node_id in visited_nodes
