extends Node

## 升级注册表
## 管理所有可用升级的注册、查询和随机选取
## 作为自动加载单例使用

# ========== 信号 ==========
signal upgrades_registered
signal upgrade_added(upgrade_id: String)

# ========== 存储 ==========
## 所有已注册的升级 {id: UpgradeData}
var _upgrades: Dictionary = {}

## 按类型分类的升级ID列表
var _upgrades_by_type: Dictionary = {}

## 按标签分类的升级ID列表
var _upgrades_by_tag: Dictionary = {}

## 按稀有度分类的升级ID列表
var _upgrades_by_rarity: Dictionary = {}

# ========== 初始化 ==========

func _ready() -> void:
	# 注册所有内置升级
	_register_builtin_upgrades()
	
	# 加载自定义升级（从文件）
	_load_custom_upgrades()
	
	emit_signal("upgrades_registered")

## 加载自定义升级文件
func _load_custom_upgrades() -> void:
	var upgrades_dir = "res://data/upgrades/"
	var dir = DirAccess.open(upgrades_dir)
	
	if dir == null:
		if DebugLogger:
			DebugLogger.log_info("未找到自定义升级目录 %s" % upgrades_dir, "UpgradeRegistry")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var loaded_count = 0
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var file_path = upgrades_dir + file_name
			var upgrade: UpgradeData = null
			if DataManager:
				var res := DataManager.load_cached(file_path)
				upgrade = res as UpgradeData if res is UpgradeData else null
			else:
				upgrade = load(file_path) as UpgradeData
			
			if upgrade and not upgrade.id.is_empty():
				# 避免覆盖内置升级
				if not _upgrades.has(upgrade.id):
					_register_upgrade(upgrade)
					loaded_count += 1
					if DebugLogger:
						DebugLogger.log_debug("加载自定义升级 '%s'（%s）" % [upgrade.id, file_name], "UpgradeRegistry")
				else:
					if DebugLogger:
						DebugLogger.log_warning("跳过重复的升级ID '%s'" % upgrade.id, "UpgradeRegistry")
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	if loaded_count > 0:
		if DebugLogger:
			DebugLogger.log_info("共加载 %d 个自定义升级" % loaded_count, "UpgradeRegistry")

## 注册所有内置升级
func _register_builtin_upgrades() -> void:
	# ========== 基础属性升级 ==========
	
	# 生命值升级
	_register_upgrade(_create_stat_upgrade(
		"health_flat", "生命强化", "增加 {value} 点最大生命值",
		UpgradeData.TargetStat.MAX_HEALTH, UpgradeData.UpgradeType.STAT_FLAT,
		20.0, 10, UpgradeData.Rarity.COMMON, ["stat", "defensive"]
	))
	
	_register_upgrade(_create_stat_upgrade(
		"health_percent", "生命提升", "增加 {value} 最大生命值",
		UpgradeData.TargetStat.MAX_HEALTH, UpgradeData.UpgradeType.STAT_PERCENT,
		0.10, 5, UpgradeData.Rarity.UNCOMMON, ["stat", "defensive"]
	))
	
	# 攻击力升级
	_register_upgrade(_create_stat_upgrade(
		"attack_flat", "攻击强化", "增加 {value} 点攻击力",
		UpgradeData.TargetStat.ATTACK, UpgradeData.UpgradeType.STAT_FLAT,
		5.0, 10, UpgradeData.Rarity.COMMON, ["stat", "offensive"]
	))
	
	_register_upgrade(_create_stat_upgrade(
		"attack_percent", "攻击提升", "增加 {value} 攻击力",
		UpgradeData.TargetStat.ATTACK, UpgradeData.UpgradeType.STAT_PERCENT,
		0.10, 5, UpgradeData.Rarity.UNCOMMON, ["stat", "offensive"]
	))
	
	# 防御升级
	_register_upgrade(_create_stat_upgrade(
		"defense", "防御提升", "增加 {value} 减伤比例",
		UpgradeData.TargetStat.DEFENSE_PERCENT, UpgradeData.UpgradeType.STAT_FLAT,
		0.05, 5, UpgradeData.Rarity.UNCOMMON, ["stat", "defensive"]
	))
	
	# 移动速度升级
	_register_upgrade(_create_stat_upgrade(
		"move_speed_flat", "迅捷", "增加 {value} 点移动速度",
		UpgradeData.TargetStat.MOVE_SPEED, UpgradeData.UpgradeType.STAT_FLAT,
		15.0, 5, UpgradeData.Rarity.COMMON, ["stat", "mobility"]
	))
	
	_register_upgrade(_create_stat_upgrade(
		"move_speed_percent", "疾风", "增加 {value} 移动速度",
		UpgradeData.TargetStat.MOVE_SPEED, UpgradeData.UpgradeType.STAT_PERCENT,
		0.10, 3, UpgradeData.Rarity.RARE, ["stat", "mobility"]
	))
	
	# 攻击速度升级
	_register_upgrade(_create_stat_upgrade(
		"attack_speed", "攻速提升", "增加 {value} 攻击速度",
		UpgradeData.TargetStat.ATTACK_SPEED, UpgradeData.UpgradeType.STAT_PERCENT,
		0.10, 5, UpgradeData.Rarity.UNCOMMON, ["stat", "offensive"]
	))
	
	# ========== 暴击属性升级 ==========
	
	_register_upgrade(_create_stat_upgrade(
		"crit_rate", "暴击率提升", "增加 {value} 暴击率",
		UpgradeData.TargetStat.CRIT_RATE, UpgradeData.UpgradeType.STAT_FLAT,
		0.05, 10, UpgradeData.Rarity.UNCOMMON, ["stat", "offensive", "crit"]
	))
	
	_register_upgrade(_create_stat_upgrade(
		"crit_damage", "暴击伤害提升", "增加 {value} 暴击伤害",
		UpgradeData.TargetStat.CRIT_DAMAGE, UpgradeData.UpgradeType.STAT_FLAT,
		0.15, 10, UpgradeData.Rarity.UNCOMMON, ["stat", "offensive", "crit"]
	))
	
	# ========== 闪避属性升级 ==========
	
	_register_upgrade(_create_stat_upgrade(
		"dodge_distance", "闪避距离", "增加 {value} 点闪避距离",
		UpgradeData.TargetStat.DODGE_DISTANCE, UpgradeData.UpgradeType.STAT_FLAT,
		20.0, 5, UpgradeData.Rarity.UNCOMMON, ["special", "mobility", "dodge"]
	))
	
	_register_upgrade(_create_stat_upgrade(
		"dodge_cooldown", "闪避冷却", "减少 {value} 秒闪避冷却时间",
		UpgradeData.TargetStat.DODGE_COOLDOWN, UpgradeData.UpgradeType.STAT_FLAT,
		-0.1, 5, UpgradeData.Rarity.RARE, ["special", "mobility", "dodge"]
	))
	
	_register_upgrade(_create_stat_upgrade(
		"invincibility", "无敌延长", "增加 {value} 秒受伤无敌时间",
		UpgradeData.TargetStat.INVINCIBILITY_DURATION, UpgradeData.UpgradeType.STAT_FLAT,
		0.2, 3, UpgradeData.Rarity.RARE, ["special", "defensive"]
	))
	
	# ========== 技能属性升级 ==========
	
	_register_upgrade(_create_stat_upgrade(
		"skill_damage", "技能伤害", "增加 {value} 技能伤害",
		UpgradeData.TargetStat.SKILL_DAMAGE, UpgradeData.UpgradeType.STAT_PERCENT,
		0.15, 5, UpgradeData.Rarity.RARE, ["ability", "offensive"]
	))
	
	_register_upgrade(_create_stat_upgrade(
		"skill_cooldown", "技能冷却", "减少 {value} 技能冷却时间",
		UpgradeData.TargetStat.SKILL_COOLDOWN, UpgradeData.UpgradeType.STAT_PERCENT,
		-0.10, 5, UpgradeData.Rarity.RARE, ["ability"]
	))
	
	_register_upgrade(_create_stat_upgrade(
		"skill_radius", "技能范围", "增加 {value} 技能范围",
		UpgradeData.TargetStat.SKILL_RADIUS, UpgradeData.UpgradeType.STAT_PERCENT,
		0.15, 5, UpgradeData.Rarity.RARE, ["ability"]
	))
	
	# ========== 大招属性升级 ==========
	
	_register_upgrade(_create_stat_upgrade(
		"burst_damage", "大招伤害", "增加 {value} 大招伤害",
		UpgradeData.TargetStat.BURST_DAMAGE, UpgradeData.UpgradeType.STAT_PERCENT,
		0.20, 5, UpgradeData.Rarity.EPIC, ["ability", "offensive"]
	))
	
	_register_upgrade(_create_stat_upgrade(
		"energy_gain", "充能效率", "增加 {value} 充能获取量",
		UpgradeData.TargetStat.ENERGY_GAIN, UpgradeData.UpgradeType.STAT_PERCENT,
		0.20, 5, UpgradeData.Rarity.RARE, ["ability"]
	))
	
	# 拾取范围升级
	_register_upgrade(_create_stat_upgrade(
		"pickup_range_flat", "拾取范围", "增加 {value} 点拾取范围",
		UpgradeData.TargetStat.PICKUP_RANGE, UpgradeData.UpgradeType.STAT_FLAT,
		20.0, 5, UpgradeData.Rarity.COMMON, ["stat", "utility"]
	))
	
	_register_upgrade(_create_stat_upgrade(
		"pickup_range_percent", "拾取强化", "增加 {value} 拾取范围",
		UpgradeData.TargetStat.PICKUP_RANGE, UpgradeData.UpgradeType.STAT_PERCENT,
		0.10, 5, UpgradeData.Rarity.UNCOMMON, ["stat", "utility"]
	))
	
	# ========== 特殊升级 ==========
	
	_register_upgrade(_create_stat_upgrade(
		"knockback_force", "击退强化", "增加 {value} 击退力度",
		UpgradeData.TargetStat.KNOCKBACK_FORCE, UpgradeData.UpgradeType.STAT_PERCENT,
		0.40, 5, UpgradeData.Rarity.UNCOMMON, ["special", "offensive"]
	))
	
	# ========== 角色专属升级示例（神里绫华） ==========
	
	# 霜华绽放 - 增加重击范围
	var ayaka_charged = _create_stat_upgrade(
		"ayaka_charged_radius", "霜华绽放", "增加 {value} 重击范围",
		UpgradeData.TargetStat.SKILL_RADIUS, UpgradeData.UpgradeType.STAT_PERCENT,
		0.20, 3, UpgradeData.Rarity.RARE, ["ability", "character_specific", "ayaka"]
	)
	ayaka_charged.required_character_ids.append("kamisato_ayaka")
	_register_upgrade(ayaka_charged)
	
	# 神里流·冰华 - E技能额外伤害
	var ayaka_skill = _create_stat_upgrade(
		"ayaka_skill_damage", "神里流·冰华", "增加 {value} E技能伤害",
		UpgradeData.TargetStat.SKILL_DAMAGE, UpgradeData.UpgradeType.STAT_PERCENT,
		0.25, 3, UpgradeData.Rarity.EPIC, ["ability", "character_specific", "ayaka"]
	)
	ayaka_skill.required_character_ids.append("kamisato_ayaka")
	_register_upgrade(ayaka_skill)
	
	# 寒天宣命祝词 - 大招伤害和充能效率
	var ayaka_burst = _create_stat_upgrade(
		"ayaka_burst_enhance", "寒天宣命祝词", "增加 {value} 大招伤害",
		UpgradeData.TargetStat.BURST_DAMAGE, UpgradeData.UpgradeType.STAT_PERCENT,
		0.30, 3, UpgradeData.Rarity.LEGENDARY, ["ability", "character_specific", "ayaka"]
	)
	ayaka_burst.required_character_ids.append("kamisato_ayaka")
	_register_upgrade(ayaka_burst)
	
	print("UpgradeRegistry: 已注册 %d 个升级" % _upgrades.size())

## 创建属性升级的辅助方法
func _create_stat_upgrade(
	id: String,
	name: String,
	desc: String,
	target: UpgradeData.TargetStat,
	type: UpgradeData.UpgradeType,
	value: float,
	max_lvl: int,
	rarity: UpgradeData.Rarity,
	tags: Array
) -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = id
	upgrade.display_name = name
	upgrade.description = desc
	upgrade.target_stat = target
	upgrade.upgrade_type = type
	upgrade.value_per_level = value
	upgrade.max_level = max_lvl
	upgrade.rarity = rarity
	for tag in tags:
		upgrade.tags.append(tag)
	return upgrade

# ========== 注册方法 ==========

## 注册单个升级
func _register_upgrade(upgrade: UpgradeData) -> void:
	if upgrade.id.is_empty():
		push_error("UpgradeRegistry: 升级ID不能为空")
		return
	
	if _upgrades.has(upgrade.id):
		push_warning("UpgradeRegistry: 升级 '%s' 已存在，将被覆盖" % upgrade.id)
	
	_upgrades[upgrade.id] = upgrade
	
	# 按类型分类
	var type_key = str(upgrade.upgrade_type)
	if not _upgrades_by_type.has(type_key):
		_upgrades_by_type[type_key] = []
	_upgrades_by_type[type_key].append(upgrade.id)
	
	# 按标签分类
	for tag in upgrade.tags:
		if not _upgrades_by_tag.has(tag):
			_upgrades_by_tag[tag] = []
		_upgrades_by_tag[tag].append(upgrade.id)
	
	# 按稀有度分类
	var rarity_key = str(upgrade.rarity)
	if not _upgrades_by_rarity.has(rarity_key):
		_upgrades_by_rarity[rarity_key] = []
	_upgrades_by_rarity[rarity_key].append(upgrade.id)
	
	emit_signal("upgrade_added", upgrade.id)

## 注册自定义升级（供外部使用）
func register_upgrade(upgrade: UpgradeData) -> void:
	_register_upgrade(upgrade)

## 批量注册升级
func register_upgrades(upgrades: Array[UpgradeData]) -> void:
	for upgrade in upgrades:
		_register_upgrade(upgrade)

# ========== 查询方法 ==========

## 获取所有升级
func get_all_upgrades() -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	for upgrade in _upgrades.values():
		result.append(upgrade)
	return result

## 根据ID获取升级
func get_upgrade(id: String) -> UpgradeData:
	return _upgrades.get(id, null)

## 获取指定类型的升级
func get_upgrades_by_type(type: UpgradeData.UpgradeType) -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	var type_key = str(type)
	if _upgrades_by_type.has(type_key):
		for id in _upgrades_by_type[type_key]:
			result.append(_upgrades[id])
	return result

## 获取指定标签的升级
func get_upgrades_by_tag(tag: String) -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	if _upgrades_by_tag.has(tag):
		for id in _upgrades_by_tag[tag]:
			result.append(_upgrades[id])
	return result

## 获取指定稀有度的升级
func get_upgrades_by_rarity(rarity: UpgradeData.Rarity) -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	var rarity_key = str(rarity)
	if _upgrades_by_rarity.has(rarity_key):
		for id in _upgrades_by_rarity[rarity_key]:
			result.append(_upgrades[id])
	return result

# ========== 随机选取方法 ==========

## 获取可用的升级列表（过滤不符合条件的）
func get_available_upgrades(
	character_id: String,
	current_upgrades: Dictionary,
	current_floor: int,
	filter_tags: Array[String] = []
) -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	
	for upgrade in _upgrades.values():
		# 检查是否满足获取条件
		if not upgrade.can_character_acquire(character_id, current_upgrades, current_floor):
			continue
		
		# 检查标签过滤
		if filter_tags.size() > 0:
			var has_tag = false
			for tag in filter_tags:
				if tag in upgrade.tags:
					has_tag = true
					break
			if not has_tag:
				continue
		
		result.append(upgrade)
	
	return result

## 随机选取指定数量的升级（带权重）
func pick_random_upgrades(
	character_id: String,
	current_upgrades: Dictionary,
	current_floor: int,
	count: int = 3,
	filter_tags: Array[String] = []
) -> Array[UpgradeData]:
	var available = get_available_upgrades(character_id, current_upgrades, current_floor, filter_tags)
	
	if available.size() <= count:
		return available
	
	# 计算权重
	var weights: Array[float] = []
	var total_weight: float = 0.0
	
	for upgrade in available:
		var weight = upgrade.calculate_weight(current_upgrades, current_floor)
		weights.append(weight)
		total_weight += weight
	
	# 权重随机选取
	var result: Array[UpgradeData] = []
	var available_copy = available.duplicate()
	var weights_copy = weights.duplicate()
	var total_weight_copy = total_weight
	var rng := RunManager.get_rng() if RunManager else null
	
	for i in range(count):
		if available_copy.size() == 0:
			break
		
		var random_value: float = (rng.randf() if rng else randf()) * total_weight_copy
		var cumulative_weight: float = 0.0
		var selected_index: int = 0
		
		for j in range(available_copy.size()):
			cumulative_weight += weights_copy[j]
			if random_value <= cumulative_weight:
				selected_index = j
				break
		
		# 添加选中的升级
		result.append(available_copy[selected_index])
		
		# 更新权重和列表
		total_weight_copy -= weights_copy[selected_index]
		available_copy.remove_at(selected_index)
		weights_copy.remove_at(selected_index)
	
	return result

## 获取升级数量
func get_upgrade_count() -> int:
	return _upgrades.size()

## 检查升级是否存在
func has_upgrade(id: String) -> bool:
	return _upgrades.has(id)
