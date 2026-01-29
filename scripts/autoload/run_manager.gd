extends Node

## 单局游戏状态管理器
## 管理当前一局游戏的状态（角色、楼层、金币、升级等）

signal floor_changed(floor: int)
signal gold_changed(gold: int)
signal health_changed(current: float, maximum: float)
signal upgrade_added(upgrade_id: String)
signal upgrades_applied  # 升级应用完成信号
signal primogems_earned_changed(amount: int)

# ========== 随机数（统一入口，避免到处 randomize/seed） ==========
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

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

# 原石：本局获得数量（跨局总数由 GameManager 持久化）
var primogems_earned: int = 0

# 升级和状态
var upgrades: Dictionary = {}  # upgrade_id -> level
var visited_nodes: Array[String] = []  # 已访问的地图节点ID

# ========== 圣遗物系统 ==========
## 已获得的圣遗物库存（按槽位类型存储）
## 格式: {ArtifactSlot.SlotType: Array[ArtifactData]}
var artifact_inventory: Dictionary = {}

# ========== 武器系统 ==========
## 武器注册表：weapon_id -> data
## data 格式：{ display_name, description, icon(Texture2D), world_texture(Texture2D) }
var _weapon_registry: Dictionary = {}
## 当前装备：character_id -> weapon_id
var _equipped_weapon: Dictionary = {}

# ========== 升级加成缓存 ==========
## 存储各属性的总加成值（每次升级后重新计算）
var _stat_bonuses: Dictionary = {}

# ========== 常量定义 ==========
## 加成键后缀
const BONUS_KEY_FLAT_SUFFIX = "_flat"
const BONUS_KEY_PERCENT_SUFFIX = "_percent"

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

# ========== CG系统：击败者记录 ==========
## 记录最后一次对玩家造成伤害的敌人（用于死亡CG解锁/展示）
var last_defeated_by_enemy_id: String = ""
var last_defeated_by_enemy_name: String = ""

# 防止重复结算标志
var _run_ended: bool = false

func _ready() -> void:
	# Autoload 初始化时随机化一次即可；后续所有随机都走 _rng
	_rng.randomize()
	_initialize_weapon_registry()


## 初始化武器注册表（显式 preload，确保导出打包）
func _initialize_weapon_registry() -> void:
	if not _weapon_registry.is_empty():
		return

	var icon_wufeng: Texture2D = preload("res://textures/ui/武器/单手剑/无锋剑.png")
	var icon_mistsplitter: Texture2D = preload("res://textures/ui/武器/单手剑/雾切之回光.png")
	var icon_apprentice_notes: Texture2D = preload("res://textures/ui/武器/法器/学徒笔记.png")
	var icon_thousand_floating_dreams: Texture2D = preload("res://textures/ui/武器/法器/千夜浮梦.png")
	# 手持世界贴图：使用 effects 目录（用于角色手里显示）
	var world_wufeng: Texture2D = preload("res://textures/effects/无锋剑.png")
	var world_mistsplitter: Texture2D = preload("res://textures/effects/雾切之回光.png")
	var world_apprentice_notes: Texture2D = preload("res://textures/effects/学徒笔记.png")
	var world_thousand_floating_dreams: Texture2D = preload("res://textures/effects/千夜浮梦.png")

	_weapon_registry["wufeng_sword"] = {
		"display_name": "无锋剑",
		"description": "无锋剑\n\n无任何效果。",
		"icon": icon_wufeng,
		"world_texture": world_wufeng,
		"weapon_type": CharacterData.WeaponType.SWORD,
	}

	_weapon_registry["mistsplitter"] = {
		"display_name": "雾切之回光",
		"description": "雾切之回光\n\n常驻：造成的伤害提高10%。\n雾切之巴印：持有1/2/3层时，造成的伤害提高10%/20%/30%。\n\n获得巴印：\n- 普通攻击造成伤害时：获得1层，持续5秒。\n- 施放元素爆发时：获得1层，持续10秒。\n- 元素能量低于100%时：获得1层，能量充满时消失。\n\n每层持续时间独立计算。",
		"icon": icon_mistsplitter,
		"world_texture": world_mistsplitter,
		"weapon_type": CharacterData.WeaponType.SWORD,
	}

	_weapon_registry["apprentice_notes"] = {
		"display_name": "学徒笔记",
		"description": "学徒笔记\n\n无任何效果。",
		"icon": icon_apprentice_notes,
		"world_texture": world_apprentice_notes,
		"weapon_type": CharacterData.WeaponType.CATALYST,
	}

	_weapon_registry["thousand_floating_dreams"] = {
		"display_name": "千夜浮梦",
		"description": "千夜浮梦\n\n攻击力+30。\n技能和大招伤害提高20%。",
		"icon": icon_thousand_floating_dreams,
		"world_texture": world_thousand_floating_dreams,
		"weapon_type": CharacterData.WeaponType.CATALYST,
		"attack_flat_bonus": 30.0,
		"skill_burst_damage_mult": 1.2,
	}

## 获取 RNG（统一随机入口）
func get_rng() -> RandomNumberGenerator:
	return _rng

## 开始新的一局游戏
func start_new_run(character: CharacterData) -> void:
	current_character = character
	current_floor = 0
	current_node_id = ""
	last_defeated_by_enemy_id = ""
	last_defeated_by_enemy_name = ""
	
	# 清空圣遗物库存
	artifact_inventory.clear()
	# 初始化本局武器装备：按角色武器类型选择默认武器
	_initialize_weapon_equip_for_character(character)
	map_seed = -1  # 重置地图种子，新游戏会生成新地图
	gold = 0
	primogems_earned = 0
	
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
	_run_ended = false  # 重置结算标志
	# 每局重新随机化一次，确保 run 间差异；如需可复现可改为固定 seed
	_rng.randomize()
	
	# 清除已触发的事件记录
	if EventRegistry:
		EventRegistry.clear_triggered_events()
	
	emit_signal("health_changed", health, max_health)
	emit_signal("gold_changed", gold)
	emit_signal("primogems_earned_changed", primogems_earned)
	if DebugLogger:
		DebugLogger.log_info("开始新的一局游戏，角色：%s" % character.display_name, "RunManager")



## 初始化某角色的默认装备
func _initialize_weapon_equip_for_character(character: CharacterData) -> void:
	if not character:
		return
	var character_id := character.id
	if character_id.is_empty():
		return
	if _equipped_weapon.has(character_id):
		return
	_equipped_weapon[character_id] = _get_default_weapon_id_for_character(character)


## 获取当前角色已拥有武器ID列表
func get_owned_weapon_ids() -> Array[String]:
	if not current_character:
		return []
	var out: Array[String] = []
	# 根据角色武器类型发放“初始基础武器”
	var default_weapon_id := _get_default_weapon_id_for_character(current_character)
	if not default_weapon_id.is_empty():
		out.append(default_weapon_id)
	# 其它武器由跨局存档解锁决定
	if GameManager and GameManager.has_method("get_unlocked_shop_weapon_ids"):
		var unlocked_any: Variant = GameManager.call("get_unlocked_shop_weapon_ids")
		if unlocked_any is Array:
			for wid in unlocked_any:
				var s := str(wid)
				if s.is_empty():
					continue
				if not _is_weapon_compatible_with_character(s, current_character):
					continue
				if not (s in out):
					out.append(s)
	return out


## 获取所有武器ID（用于商店展示）
func get_all_weapon_ids() -> Array[String]:
	var out: Array[String] = []
	for k in _weapon_registry.keys():
		out.append(str(k))
	out.sort()
	return out


## 装备武器（对当前角色生效）
func equip_weapon(weapon_id: String) -> void:
	if not current_character:
		return
	if weapon_id.is_empty():
		return
	if not _weapon_registry.has(weapon_id):
		return
	# 武器类型必须与角色匹配
	if not _is_weapon_compatible_with_character(weapon_id, current_character):
		return
	# 必须已解锁/已拥有
	var owned := get_owned_weapon_ids()
	if not (weapon_id in owned):
		return
	_equipped_weapon[current_character.id] = weapon_id
	# 武器可能带属性加成：若角色节点已生成，立即重新应用一次升级/属性
	if current_character_node:
		apply_upgrades_to_character(current_character_node)


## 获取武器类型
func get_weapon_type(weapon_id: String) -> CharacterData.WeaponType:
	if weapon_id.is_empty():
		return CharacterData.WeaponType.SWORD
	var data: Dictionary = _weapon_registry.get(weapon_id, {})
	return int(data.get("weapon_type", int(CharacterData.WeaponType.SWORD)))


func _get_default_weapon_id_for_character(character: CharacterData) -> String:
	if not character:
		return ""
	match character.weapon_type:
		CharacterData.WeaponType.CATALYST:
			return "apprentice_notes"
		_:
			return "wufeng_sword"


func _is_weapon_compatible_with_character(weapon_id: String, character: CharacterData) -> bool:
	if weapon_id.is_empty() or not character:
		return true
	if not _weapon_registry.has(weapon_id):
		return true
	return int(get_weapon_type(weapon_id)) == int(character.weapon_type)


## 提供给 UI/其它系统的兼容性判断
func is_weapon_compatible_with_current_character(weapon_id: String) -> bool:
	return _is_weapon_compatible_with_character(weapon_id, current_character)


## 获取当前角色装备的武器ID
func get_equipped_weapon_id() -> String:
	if not current_character:
		return ""
	return str(_equipped_weapon.get(current_character.id, ""))


## 获取武器显示名
func get_weapon_display_name(weapon_id: String) -> String:
	if weapon_id.is_empty():
		return ""
	var data: Dictionary = _weapon_registry.get(weapon_id, {})
	return str(data.get("display_name", weapon_id))


## 获取武器描述
func get_weapon_description(weapon_id: String) -> String:
	if weapon_id.is_empty():
		return ""
	var data: Dictionary = _weapon_registry.get(weapon_id, {})
	return str(data.get("description", ""))


## 获取武器UI图标
func get_weapon_icon(weapon_id: String) -> Texture2D:
	if weapon_id.is_empty():
		return null
	var data: Dictionary = _weapon_registry.get(weapon_id, {})
	var t: Variant = data.get("icon", null)
	return t as Texture2D


## 获取武器世界贴图（角色手持显示）
func get_weapon_world_texture(weapon_id: String) -> Texture2D:
	if weapon_id.is_empty():
		return null
	var data: Dictionary = _weapon_registry.get(weapon_id, {})
	var t: Variant = data.get("world_texture", null)
	return t as Texture2D


func get_weapon_attack_flat_bonus(weapon_id: String) -> float:
	if weapon_id.is_empty():
		return 0.0
	var data: Dictionary = _weapon_registry.get(weapon_id, {})
	return float(data.get("attack_flat_bonus", 0.0))


func get_weapon_skill_burst_damage_multiplier(weapon_id: String) -> float:
	if weapon_id.is_empty():
		return 1.0
	var data: Dictionary = _weapon_registry.get(weapon_id, {})
	return float(data.get("skill_burst_damage_mult", 1.0))


## 设置击败者（最后伤害来源）
func set_last_defeated_by_enemy(enemy_id: String, enemy_name: String) -> void:
	last_defeated_by_enemy_id = enemy_id
	last_defeated_by_enemy_name = enemy_name

## 结束当前局
func end_run(victory: bool = false) -> void:
	# 防止重复结算
	if _run_ended:
		if DebugLogger:
			DebugLogger.log_warning("end_run() 被重复调用，已忽略", "RunManager")
		return
	_run_ended = true
	
	var run_time = (Time.get_ticks_msec() / 1000.0) - start_time
	
	var run_record = {
		"character_id": current_character.id if current_character else "",
		"character_name": current_character.display_name if current_character else "",
		"floors_cleared": current_floor,
		"enemies_killed": enemies_killed,
		"gold_earned": gold,
		"primogems_earned": primogems_earned,
		"damage_dealt": damage_dealt,
		"damage_taken": damage_taken,
		"time_elapsed": run_time,
		"victory": victory,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# 保存结算记录
	GameManager.save_run_record(run_record)
	
	if DebugLogger:
		DebugLogger.log_info("游戏结束，胜利：%s，楼层：%d" % [str(victory), current_floor], "RunManager")

## 设置当前楼层
func set_floor(floor_num: int) -> void:
	current_floor = floor_num
	emit_signal("floor_changed", floor_num)

## 增加金币
func add_gold(amount: int) -> void:
	var final_amount := amount
	var mult := 1.0 + get_stat_percent_bonus(UpgradeData.TargetStat.PICKUP_MULTIPLIER)
	if mult != 1.0:
		final_amount = maxi(0, roundi(float(amount) * mult))
	gold += final_amount
	emit_signal("gold_changed", gold)


## 增加原石（本局统计 + 跨局持久化累计）
func add_primogems(amount: int) -> void:
	if amount <= 0:
		return
	var final_amount := amount
	var mult := 1.0 + get_stat_percent_bonus(UpgradeData.TargetStat.PICKUP_MULTIPLIER)
	if mult != 1.0:
		final_amount = maxi(0, roundi(float(amount) * mult))
	primogems_earned += final_amount
	emit_signal("primogems_earned_changed", primogems_earned)
	if GameManager:
		GameManager.add_primogems(final_amount)

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
	# 应用已有升级/武器加成（即使 upgrades 为空也需要应用武器属性）
	if current_character_node:
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
		
		_apply_upgrade_bonus(upgrade_data, level)

## 应用单个升级的加成
func _apply_upgrade_bonus(upgrade_data: UpgradeData, level: int) -> void:
	var target_stat = upgrade_data.target_stat
	var value = upgrade_data.get_value_at_level(level)
	var upgrade_type = upgrade_data.upgrade_type
	
	# 构建加成键
	var stat_key = str(target_stat)
	var flat_key = stat_key + BONUS_KEY_FLAT_SUFFIX
	var percent_key = stat_key + BONUS_KEY_PERCENT_SUFFIX
	
	# 根据升级类型应用加成
	if upgrade_type == UpgradeData.UpgradeType.STAT_FLAT or upgrade_type == UpgradeData.UpgradeType.SPECIAL:
		_add_bonus(flat_key, value)
	elif upgrade_type == UpgradeData.UpgradeType.STAT_PERCENT:
		_add_bonus(percent_key, value)

## 添加加成值（如果键不存在则初始化为0）
func _add_bonus(key: String, value: float) -> void:
	if not _stat_bonuses.has(key):
		_stat_bonuses[key] = 0.0
	_stat_bonuses[key] += value

## 获取指定属性的固定值加成
func get_stat_flat_bonus(target_stat: int) -> float:
	var key = str(target_stat) + BONUS_KEY_FLAT_SUFFIX
	return _stat_bonuses.get(key, 0.0)

## 获取指定属性的百分比加成
func get_stat_percent_bonus(target_stat: int) -> float:
	var key = str(target_stat) + BONUS_KEY_PERCENT_SUFFIX
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
	# Resource/Script 属性不能用 `"x" in obj` 判断；改用属性列表枚举（Godot 4.x 兼容）
	var has_prop := false
	for prop in base_stats.get_property_list():
		if prop.name == property_name:
			has_prop = true
			break
	if not has_prop:
		return
	
	var base_value = base_stats.get(property_name)
	var final_value = calculate_final_stat(base_value, target_stat)
	if property_name == "defense_percent":
		final_value = clamp(final_value, 0.0, 0.80)
	current_stats.set(property_name, final_value)
	
	# 特殊处理：同步到角色节点
	if property_name == "max_health":
		var char_has_max := false
		var char_has_current := false
		for prop in character.get_property_list():
			if prop.name == "max_health":
				char_has_max = true
			elif prop.name == "current_health":
				char_has_current = true
		if char_has_max:
			var old_max: float = float(character.get("max_health"))
			character.set("max_health", final_value)
			
			# 按比例调整当前血量
			if old_max > 0.0 and char_has_current and character.has_method("get_current_health"):
				var health_ratio = character.get_current_health() / old_max
				character.set("current_health", final_value * health_ratio)
		# 按比例调整当前血量
	if property_name == "move_speed":
		var char_has_base := false
		var char_has_move := false
		for prop in character.get_property_list():
			if prop.name == "base_move_speed":
				char_has_base = true
			elif prop.name == "move_speed":
				char_has_move = true
		if char_has_base:
			character.set("base_move_speed", final_value)
		if char_has_move:
			character.set("move_speed", final_value)

## 检查是否有 UpgradeRegistry
func _has_upgrade_registry() -> bool:
	# UpgradeRegistry 是 Autoload（见 project.godot），不应通过 Engine.has_singleton() 判断。
	# 直接使用全局 Autoload 名更稳、更符合 Godot 4.x/4.5 的用法。
	return is_instance_valid(UpgradeRegistry)

## 获取 UpgradeRegistry
func _get_upgrade_registry() -> Node:
	return UpgradeRegistry if is_instance_valid(UpgradeRegistry) else null

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

## 检查某个槽位是否已获得过指定名称的圣遗物
func has_artifact_in_inventory(artifact_name: String, slot: ArtifactSlot.SlotType) -> bool:
	var list: Array = artifact_inventory.get(slot, [])
	for a in list:
		if a and a is ArtifactData and a.name == artifact_name:
			return true
	return false

func get_artifact_obtained_count(artifact_name: String, slot: ArtifactSlot.SlotType) -> int:
	var count: int = 0
	var list: Array = artifact_inventory.get(slot, [])
	for a in list:
		if a and a is ArtifactData and a.name == artifact_name:
			count += 1
	return count

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
	var random_slot = available_slots[_rng.randi_range(0, available_slots.size() - 1)]
	return current_character.artifact_set.get_artifact(random_slot)

## 从角色专属圣遗物套装中随机获取一个圣遗物及其槽位
## 返回: Dictionary { "artifact": ArtifactData, "slot": ArtifactSlot.SlotType } 或空字典
func get_random_artifact_with_slot_from_character_set() -> Dictionary:
	if not current_character or not current_character.artifact_set:
		return {}
	
	# 获取所有可用的圣遗物槽位
	var available_slots: Array[ArtifactSlot.SlotType] = []
	for slot in ArtifactSlot.get_all_slots():
		var artifact = current_character.artifact_set.get_artifact(slot)
		if artifact:
			available_slots.append(slot)
	
	if available_slots.is_empty():
		return {}
	
	# 随机选择一个槽位
	var random_slot = available_slots[_rng.randi_range(0, available_slots.size() - 1)]
	var artifact = current_character.artifact_set.get_artifact(random_slot)
	
	return {
		"artifact": artifact,
		"slot": random_slot
	}

## 从角色专属圣遗物套装中获取指定槽位的圣遗物
func get_artifact_from_character_set(slot: ArtifactSlot.SlotType) -> ArtifactData:
	if not current_character or not current_character.artifact_set:
		return null
	return current_character.artifact_set.get_artifact(slot)
