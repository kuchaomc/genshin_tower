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
	var file_name: String = dir.get_next()
	var loaded_count = 0
	
	while file_name != "":
		if not dir.current_is_dir():
			var is_tres := file_name.ends_with(".tres") or file_name.ends_with(".tres.remap")
			var is_res := file_name.ends_with(".res") or file_name.ends_with(".res.remap")
			if not (is_tres or is_res):
				file_name = dir.get_next() as String
				continue
			var actual_file: String = file_name
			if actual_file.ends_with(".remap"):
				actual_file = actual_file.substr(0, actual_file.length() - 6)
			var file_path = upgrades_dir + actual_file
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
		
		file_name = dir.get_next() as String
	
	dir.list_dir_end()
	
	if loaded_count > 0:
		if DebugLogger:
			DebugLogger.log_info("共加载 %d 个自定义升级" % loaded_count, "UpgradeRegistry")

## 注册所有内置升级
func _register_builtin_upgrades() -> void:
	# ========== 通用升级（大多可重复获取；部分有上限） ==========
	_register_upgrade(_create_stat_upgrade(
		"common_max_health", "提升最大生命值", "最大生命值提高 {value}",
		UpgradeData.TargetStat.MAX_HEALTH, UpgradeData.UpgradeType.STAT_PERCENT,
		0.10, 0, UpgradeData.Rarity.UNCOMMON, ["common", "stat"]
	))
	_register_upgrade(_create_stat_upgrade(
		"common_attack", "提升攻击力", "攻击力提高 {value}",
		UpgradeData.TargetStat.ATTACK, UpgradeData.UpgradeType.STAT_PERCENT,
		0.10, 0, UpgradeData.Rarity.UNCOMMON, ["common", "stat"]
	))
	_register_upgrade(_create_stat_upgrade(
		"common_damage_reduction", "百分比减伤", "减伤提高 {value}",
		UpgradeData.TargetStat.DEFENSE_PERCENT, UpgradeData.UpgradeType.STAT_FLAT,
		0.10, 8, UpgradeData.Rarity.UNCOMMON, ["common", "defensive"]
	))
	_register_upgrade(_create_stat_upgrade(
		"common_move_speed", "移动速度提升", "移动速度提高 {value}",
		UpgradeData.TargetStat.MOVE_SPEED, UpgradeData.UpgradeType.STAT_PERCENT,
		0.10, 0, UpgradeData.Rarity.UNCOMMON, ["common", "mobility"]
	))
	_register_upgrade(_create_stat_upgrade(
		"common_attack_speed", "普攻速度提升", "攻击速度提高 {value}",
		UpgradeData.TargetStat.ATTACK_SPEED, UpgradeData.UpgradeType.STAT_PERCENT,
		0.10, 0, UpgradeData.Rarity.UNCOMMON, ["common", "offensive"]
	))
	_register_upgrade(_create_stat_upgrade(
		"common_weapon_range", "武器变大", "武器/近战范围提高 {value}",
		UpgradeData.TargetStat.WEAPON_RANGE, UpgradeData.UpgradeType.STAT_PERCENT,
		0.10, 0, UpgradeData.Rarity.UNCOMMON, ["common", "offensive"]
	))
	_register_upgrade(_create_stat_upgrade(
		"common_crit_rate", "提升暴击率", "暴击率提高 {value}",
		UpgradeData.TargetStat.CRIT_RATE, UpgradeData.UpgradeType.STAT_FLAT,
		0.10, 0, UpgradeData.Rarity.UNCOMMON, ["common", "crit"]
	))
	_register_upgrade(_create_stat_upgrade(
		"common_crit_damage", "提升暴击伤害", "暴击伤害提高 {value}",
		UpgradeData.TargetStat.CRIT_DAMAGE, UpgradeData.UpgradeType.STAT_FLAT,
		0.10, 0, UpgradeData.Rarity.UNCOMMON, ["common", "crit"]
	))
	_register_upgrade(_create_stat_upgrade(
		"common_dodge_distance", "闪避距离提升", "闪避距离提高 {value}",
		UpgradeData.TargetStat.DODGE_DISTANCE, UpgradeData.UpgradeType.STAT_PERCENT,
		0.10, 0, UpgradeData.Rarity.UNCOMMON, ["common", "dodge"]
	))
	_register_upgrade(_create_stat_upgrade(
		"common_dodge_cooldown", "闪避冷却降低", "闪避冷却降低 {value}",
		UpgradeData.TargetStat.DODGE_COOLDOWN, UpgradeData.UpgradeType.STAT_PERCENT,
		-0.10, 0, UpgradeData.Rarity.UNCOMMON, ["common", "dodge"]
	))
	_register_upgrade(_create_stat_upgrade(
		"common_invincibility", "增加受伤后无敌时间", "受伤无敌时间增加 {value} 秒",
		UpgradeData.TargetStat.INVINCIBILITY_DURATION, UpgradeData.UpgradeType.STAT_FLAT,
		0.10, 0, UpgradeData.Rarity.UNCOMMON, ["common", "defensive"]
	))
	_register_upgrade(_create_stat_upgrade(
		"common_skill_damage", "提高技能伤害", "技能伤害提高 {value}",
		UpgradeData.TargetStat.SKILL_DAMAGE, UpgradeData.UpgradeType.STAT_PERCENT,
		0.10, 0, UpgradeData.Rarity.UNCOMMON, ["common", "ability"]
	))
	_register_upgrade(_create_stat_upgrade(
		"common_skill_cooldown", "减少技能冷却", "技能冷却降低 {value}",
		UpgradeData.TargetStat.SKILL_COOLDOWN, UpgradeData.UpgradeType.STAT_PERCENT,
		-0.10, 0, UpgradeData.Rarity.UNCOMMON, ["common", "ability"]
	))
	_register_upgrade(_create_stat_upgrade(
		"common_skill_radius", "增加技能范围", "技能范围提高 {value}",
		UpgradeData.TargetStat.SKILL_RADIUS, UpgradeData.UpgradeType.STAT_PERCENT,
		0.10, 0, UpgradeData.Rarity.UNCOMMON, ["common", "ability"]
	))
	_register_upgrade(_create_stat_upgrade(
		"common_burst_damage", "增加大招伤害", "大招伤害提高 {value}",
		UpgradeData.TargetStat.BURST_DAMAGE, UpgradeData.UpgradeType.STAT_PERCENT,
		0.10, 0, UpgradeData.Rarity.UNCOMMON, ["common", "ability"]
	))
	_register_upgrade(_create_stat_upgrade(
		"common_energy_gain", "提升充能效率", "充能效率提高 {value}",
		UpgradeData.TargetStat.ENERGY_GAIN, UpgradeData.UpgradeType.STAT_PERCENT,
		0.10, 0, UpgradeData.Rarity.UNCOMMON, ["common", "ability"]
	))
	_register_upgrade(_create_stat_upgrade(
		"common_pickup_range", "扩大拾取范围", "拾取范围提高 {value}",
		UpgradeData.TargetStat.PICKUP_RANGE, UpgradeData.UpgradeType.STAT_PERCENT,
		0.10, 0, UpgradeData.Rarity.UNCOMMON, ["common", "utility"]
	))
	_register_upgrade(_create_stat_upgrade(
		"common_pickup_multiplier", "提升拾取倍率", "拾取获得的摩拉/原石数量提高 {value}",
		UpgradeData.TargetStat.PICKUP_MULTIPLIER, UpgradeData.UpgradeType.STAT_PERCENT,
		0.10, 10, UpgradeData.Rarity.UNCOMMON, ["common", "utility"]
	))
	_register_upgrade(_create_stat_upgrade(
		"common_knockback_force", "增加击退力度", "击退力度提高 {value}",
		UpgradeData.TargetStat.KNOCKBACK_FORCE, UpgradeData.UpgradeType.STAT_PERCENT,
		0.10, 0, UpgradeData.Rarity.UNCOMMON, ["common", "offensive"]
	))

	# ========== 绫华专属升级（全部只能拿一次） ==========
	var ayaka_1 := UpgradeData.new()
	ayaka_1.id = "ayaka_skill_cd_reduce_on_hit"
	ayaka_1.display_name = "冰华余势"
	ayaka_1.description = "普攻及重击命中敌人时，有50%的几率使神里流·冰华的冷却时间缩减0.3秒。该效果每0.1秒只能触发一次。"
	ayaka_1.upgrade_type = UpgradeData.UpgradeType.CUSTOM
	ayaka_1.target_stat = UpgradeData.TargetStat.CUSTOM
	ayaka_1.max_level = 1
	ayaka_1.value_per_level = 1.0
	ayaka_1.rarity = UpgradeData.Rarity.EPIC
	ayaka_1.tags = ["character_specific", "ayaka"]
	ayaka_1.required_character_ids.append("kamisato_ayaka")
	_register_upgrade(ayaka_1)

	var ayaka_2 := UpgradeData.new()
	ayaka_2.id = "ayaka_burst_extra_projectiles"
	ayaka_2.display_name = "霜灭·散射"
	ayaka_2.description = "施放大招时，会额外释放两个投射物（扇形散射）。"
	ayaka_2.upgrade_type = UpgradeData.UpgradeType.CUSTOM
	ayaka_2.target_stat = UpgradeData.TargetStat.CUSTOM
	ayaka_2.max_level = 1
	ayaka_2.value_per_level = 1.0
	ayaka_2.rarity = UpgradeData.Rarity.EPIC
	ayaka_2.tags = ["character_specific", "ayaka"]
	ayaka_2.required_character_ids.append("kamisato_ayaka")
	_register_upgrade(ayaka_2)

	var ayaka_3 := UpgradeData.new()
	ayaka_3.id = "ayaka_burst_defense_shred"
	ayaka_3.display_name = "霜见雪关扉"
	ayaka_3.description = "敌人受到神里流·霜灭造成的伤害后，防御力降低30%，持续6秒。"
	ayaka_3.upgrade_type = UpgradeData.UpgradeType.CUSTOM
	ayaka_3.target_stat = UpgradeData.TargetStat.CUSTOM
	ayaka_3.max_level = 1
	ayaka_3.value_per_level = 1.0
	ayaka_3.rarity = UpgradeData.Rarity.LEGENDARY
	ayaka_3.tags = ["character_specific", "ayaka"]
	ayaka_3.required_character_ids.append("kamisato_ayaka")
	_register_upgrade(ayaka_3)

	var ayaka_4 := UpgradeData.new()
	ayaka_4.id = "ayaka_thin_ice_dance"
	ayaka_4.display_name = "薄冰舞踏"
	ayaka_4.description = "每过10秒，神里绫华会获得「薄冰舞踏」，使重击造成的伤害提高100%。薄冰舞踏效果将在重击命中敌人的0.5秒后清除，并重新开始计算时间。"
	ayaka_4.upgrade_type = UpgradeData.UpgradeType.CUSTOM
	ayaka_4.target_stat = UpgradeData.TargetStat.CUSTOM
	ayaka_4.max_level = 1
	ayaka_4.value_per_level = 1.0
	ayaka_4.rarity = UpgradeData.Rarity.LEGENDARY
	ayaka_4.tags = ["character_specific", "ayaka"]
	ayaka_4.required_character_ids.append("kamisato_ayaka")
	_register_upgrade(ayaka_4)

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
	var rng: RandomNumberGenerator = null
	if RunManager:
		rng = RunManager.get_rng()
	if not rng:
		push_warning("UpgradeRegistry: RunManager 不可用，创建临时 RNG")
		rng = RandomNumberGenerator.new()
		rng.randomize()
	
	for i in range(count):
		if available_copy.size() == 0:
			break
		
		var random_value: float = rng.randf() * total_weight_copy
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
