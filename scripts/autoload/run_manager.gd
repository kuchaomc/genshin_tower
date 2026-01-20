extends Node

## 单局游戏状态管理器
## 管理当前一局游戏的状态（角色、楼层、金币、升级等）

signal floor_changed(floor: int)
signal gold_changed(gold: int)
signal health_changed(current: float, maximum: float)
signal upgrade_added(upgrade_id: String)
signal upgrades_applied  # 升级应用完成信号

# 当前角色
var current_character: CharacterData = null
var current_character_node: Node = null  # 当前角色的场景节点引用

# 游戏进度
var current_floor: int = 0
var current_node_id: String = ""  # 当前所在的地图节点ID
var map_seed: int = -1  # 地图随机种子，用于保持地图一致性

# 资源
var gold: int = 0
var health: float = 100.0
var max_health: float = 100.0

# 升级和状态
var upgrades: Dictionary = {}  # upgrade_id -> level
var visited_nodes: Array[String] = []  # 已访问的地图节点ID

# ========== 圣遗物系统 ==========
## 已获得的圣遗物库存（按槽位类型存储）
## 格式: {ArtifactSlot.SlotType: Array[ArtifactData]}
var artifact_inventory: Dictionary = {}

# ========== 升级加成缓存 ==========
## 存储各属性的总加成值（每次升级后重新计算）
var _stat_bonuses: Dictionary = {}

# ========== 通用升级属性 ==========
## 所有角色都拥有的通用属性升级列表
const COMMON_UPGRADE_STATS: Array[Dictionary] = [
	{"property": "max_health", "target_stat": UpgradeData.TargetStat.MAX_HEALTH},
	{"property": "attack", "target_stat": UpgradeData.TargetStat.ATTACK},
	{"property": "defense_percent", "target_stat": UpgradeData.TargetStat.DEFENSE_PERCENT},
	{"property": "move_speed", "target_stat": UpgradeData.TargetStat.MOVE_SPEED},
	{"property": "attack_speed", "target_stat": UpgradeData.TargetStat.ATTACK_SPEED},
	{"property": "crit_rate", "target_stat": UpgradeData.TargetStat.CRIT_RATE},
	{"property": "crit_damage", "target_stat": UpgradeData.TargetStat.CRIT_DAMAGE},
	{"property": "knockback_force", "target_stat": UpgradeData.TargetStat.KNOCKBACK_FORCE},
	{"property": "pickup_range", "target_stat": UpgradeData.TargetStat.PICKUP_RANGE}
]

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
	
	# 清空圣遗物库存
	artifact_inventory.clear()
	map_seed = -1  # 重置地图种子，新游戏会生成新地图
	gold = 0
	
	# 从角色属性获取最大生命值
	var char_stats = character.get_stats()
	max_health = char_stats.max_health
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
	
	# 重新计算升级加成
	_recalculate_stat_bonuses()
	
	# 应用升级到当前角色
	if current_character_node:
		apply_upgrades_to_character(current_character_node)
	
	emit_signal("upgrade_added", upgrade_id)

## 获取升级等级
func get_upgrade_level(upgrade_id: String) -> int:
	return upgrades.get(upgrade_id, 0)

## 设置当前角色节点引用
func set_character_node(character: Node) -> void:
	current_character_node = character
	# 应用已有升级
	if current_character_node and upgrades.size() > 0:
		apply_upgrades_to_character(current_character_node)

# ========== 升级计算系统 ==========

## 重新计算所有升级加成
func _recalculate_stat_bonuses() -> void:
	_stat_bonuses.clear()
	
	var registry = _get_upgrade_registry()
	if registry == null:
		push_error("RunManager: UpgradeRegistry 未找到，无法计算升级加成")
		return
	
	for upgrade_id in upgrades:
		var level = upgrades[upgrade_id]
		var upgrade_data = registry.get_upgrade(upgrade_id)
		
		if upgrade_data == null:
			continue
		
		var target_stat = upgrade_data.target_stat
		var value = upgrade_data.get_value_at_level(level)
		var upgrade_type = upgrade_data.upgrade_type
		
		# 区分固定值和百分比加成
		var stat_key = str(target_stat)
		var flat_key = stat_key + "_flat"
		var percent_key = stat_key + "_percent"
		
		if upgrade_type == UpgradeData.UpgradeType.STAT_FLAT or upgrade_type == UpgradeData.UpgradeType.SPECIAL:
			if not _stat_bonuses.has(flat_key):
				_stat_bonuses[flat_key] = 0.0
			_stat_bonuses[flat_key] += value
		elif upgrade_type == UpgradeData.UpgradeType.STAT_PERCENT:
			if not _stat_bonuses.has(percent_key):
				_stat_bonuses[percent_key] = 0.0
			_stat_bonuses[percent_key] += value

## 获取指定属性的固定值加成
func get_stat_flat_bonus(target_stat: int) -> float:
	var key = str(target_stat) + "_flat"
	return _stat_bonuses.get(key, 0.0)

## 获取指定属性的百分比加成
func get_stat_percent_bonus(target_stat: int) -> float:
	var key = str(target_stat) + "_percent"
	return _stat_bonuses.get(key, 0.0)

## 计算最终属性值 = (基础值 + 固定加成) * (1 + 百分比加成)
func calculate_final_stat(base_value: float, target_stat: int) -> float:
	var flat_bonus = get_stat_flat_bonus(target_stat)
	var percent_bonus = get_stat_percent_bonus(target_stat)
	return (base_value + flat_bonus) * (1.0 + percent_bonus)

## 应用升级到角色
func apply_upgrades_to_character(character: Node) -> void:
	if character == null:
		return
	
	# 检查角色是否有应用升级的方法（优先使用角色的方法）
	if character.has_method("apply_upgrades"):
		character.apply_upgrades(self)
		emit_signal("upgrades_applied")
		return
	
	# 如果角色没有专用方法，尝试直接应用到 current_stats
	if not character.has_method("get_base_stats") or not character.has_method("get_current_stats"):
		return
	
	var base_stats = character.get_base_stats()
	var current_stats = character.get_current_stats()
	
	if base_stats == null or current_stats == null:
		return
	
	# 应用通用属性升级
	_apply_common_stats_to_character(character, current_stats, base_stats)
	
	emit_signal("upgrades_applied")

## 应用通用属性升级到角色
func _apply_common_stats_to_character(character: Node, current_stats: Resource, base_stats: Resource) -> void:
	for stat_config in COMMON_UPGRADE_STATS:
		var property_name = stat_config.get("property")
		var target_stat = stat_config.get("target_stat")
		_apply_stat_to_character(character, current_stats, base_stats, property_name, target_stat)

## 应用单个属性升级
func _apply_stat_to_character(character: Node, current_stats: Resource, base_stats: Resource, property_name: String, target_stat: int) -> void:
	if not property_name in base_stats:
		return
	
	var base_value = base_stats.get(property_name)
	var final_value = calculate_final_stat(base_value, target_stat)
	current_stats.set(property_name, final_value)
	
	# 特殊处理：同步到角色节点
	if property_name == "max_health" and "max_health" in character:
		var old_max = character.max_health
		character.max_health = final_value
		# 按比例调整当前血量
		if old_max > 0 and character.has_method("get_current_health"):
			var health_ratio = character.get_current_health() / old_max
			character.current_health = final_value * health_ratio
	
	if property_name == "move_speed" and "base_move_speed" in character:
		character.base_move_speed = final_value
		character.move_speed = final_value

## 检查是否有 UpgradeRegistry
func _has_upgrade_registry() -> bool:
	return Engine.has_singleton("UpgradeRegistry") or has_node("/root/UpgradeRegistry")

## 获取 UpgradeRegistry
func _get_upgrade_registry() -> Node:
	if has_node("/root/UpgradeRegistry"):
		return get_node("/root/UpgradeRegistry")
	return null

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

# ========== 圣遗物系统 ==========

## 添加圣遗物到库存
func add_artifact_to_inventory(artifact: ArtifactData, slot: ArtifactSlot.SlotType) -> void:
	if not artifact_inventory.has(slot):
		artifact_inventory[slot] = []
	artifact_inventory[slot].append(artifact)
	print("获得圣遗物：%s（%s）" % [artifact.name, ArtifactSlot.get_slot_name(slot)])

## 获取指定槽位的所有圣遗物
func get_artifacts_by_slot(slot: ArtifactSlot.SlotType) -> Array[ArtifactData]:
	return artifact_inventory.get(slot, [])

## 获取所有已获得的圣遗物
func get_all_artifacts() -> Dictionary:
	return artifact_inventory.duplicate()

## 装备圣遗物到角色
## 如果角色节点不存在，返回false但不报错（圣遗物已添加到库存，会在角色创建后自动装备）
func equip_artifact_to_character(artifact: ArtifactData, slot: ArtifactSlot.SlotType) -> bool:
	if not current_character_node:
		# 角色节点不存在时，不报错，只返回false
		# 圣遗物已添加到库存，会在角色节点创建后自动装备
		return false
	
	if not current_character_node.has_method("equip_artifact"):
		push_error("RunManager: 角色节点不支持装备圣遗物")
		return false
	
	var success = current_character_node.equip_artifact(slot, artifact)
	if success:
		print("装备圣遗物：%s 到 %s" % [artifact.name, ArtifactSlot.get_slot_name(slot)])
	return success

## 装备库存中的所有圣遗物到角色
## 在角色节点创建后调用，自动装备库存中的圣遗物
func equip_all_inventory_artifacts() -> void:
	if not current_character_node:
		return
	
	if not current_character_node.has_method("equip_artifact"):
		return
	
	var artifact_manager = current_character_node.get_artifact_manager()
	if not artifact_manager:
		return
	
	# 遍历库存中的所有圣遗物
	for slot in artifact_inventory:
		var artifacts = artifact_inventory[slot]
		if artifacts.size() > 0:
			# 遍历该槽位的所有圣遗物，依次装备（这样可以触发升级）
			for artifact in artifacts:
				var success = current_character_node.equip_artifact(slot, artifact)
				if success:
					print("自动装备库存圣遗物：%s 到 %s" % [artifact.name, ArtifactSlot.get_slot_name(slot)])

## 从角色专属圣遗物套装中随机获取一个圣遗物
## 返回: ArtifactData 或 null
func get_random_artifact_from_character_set() -> ArtifactData:
	if not current_character or not current_character.artifact_set:
		return null
	
	# 获取所有可用的圣遗物槽位
	var available_slots: Array[ArtifactSlot.SlotType] = []
	for slot in ArtifactSlot.get_all_slots():
		var artifact = current_character.artifact_set.get_artifact(slot)
		if artifact:
			available_slots.append(slot)
	
	if available_slots.is_empty():
		return null
	
	# 随机选择一个槽位
	var random_slot = available_slots[randi() % available_slots.size()]
	return current_character.artifact_set.get_artifact(random_slot)

## 从角色专属圣遗物套装中获取指定槽位的圣遗物
func get_artifact_from_character_set(slot: ArtifactSlot.SlotType) -> ArtifactData:
	if not current_character or not current_character.artifact_set:
		return null
	return current_character.artifact_set.get_artifact(slot)
