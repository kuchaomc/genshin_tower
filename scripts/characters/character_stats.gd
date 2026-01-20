extends Resource
class_name CharacterStats

## 角色属性资源类
## 统一存储角色的所有战斗相关属性

# ========== 基础生存属性 ==========
## 最大生命值
@export var max_health: float = 100.0
## 减伤比例（0.0 ~ 1.0，例如 0.2 表示减少 20% 伤害）
@export_range(0.0, 1.0) var defense_percent: float = 0.0

# ========== 攻击属性 ==========
## 基础攻击力
@export var attack: float = 25.0
## 攻击速度倍率（1.0 为基准，越高攻击越快）
@export var attack_speed: float = 1.0
## 击退能力（对敌人造成击退的力度）
@export var knockback_force: float = 150.0

# ========== 暴击属性 ==========
## 暴击率（0.0 ~ 1.0，例如 0.1 表示 10% 暴击率）
@export_range(0.0, 1.0) var crit_rate: float = 0.05
## 暴击伤害倍率（例如 0.5 表示暴击时额外增加 50% 伤害，即 1.5 倍）
@export var crit_damage: float = 0.5

# ========== 移动属性 ==========
## 移动速度
@export var move_speed: float = 100.0

# ========== 伤害计算方法 ==========

## 计算最终伤害
## base_multiplier: 技能/攻击的伤害倍率（例如普攻 1.0，技能 2.0）
## target_defense: 目标的减伤比例（0.0 ~ 1.0）
## force_crit: 是否强制暴击（某些技能可能必定暴击）
## force_no_crit: 是否强制不暴击
## 返回值: [最终伤害, 是否暴击]
func calculate_damage(base_multiplier: float = 1.0, target_defense: float = 0.0, force_crit: bool = false, force_no_crit: bool = false) -> Array:
	# 基础伤害 = 攻击力 × 攻击倍率
	var base_damage = attack * base_multiplier
	
	# 判断是否暴击
	var is_crit = false
	if force_crit:
		is_crit = true
	elif not force_no_crit:
		is_crit = randf() < crit_rate
	
	# 暴击倍率
	var crit_multiplier = 1.0
	if is_crit:
		crit_multiplier = 1.0 + crit_damage
	
	# 减伤计算（目标减伤）
	var defense_multiplier = 1.0 - clamp(target_defense, 0.0, 1.0)
	
	# 最终伤害 = 基础伤害 × 暴击倍率 × (1 - 目标减伤)
	var final_damage = base_damage * crit_multiplier * defense_multiplier
	
	return [final_damage, is_crit]

## 判断是否触发暴击
func is_critical_hit() -> bool:
	return randf() < crit_rate

## 计算受到的伤害（应用自身减伤）
## raw_damage: 原始伤害值
## 返回值: 实际受到的伤害
func calculate_damage_taken(raw_damage: float) -> float:
	var defense_multiplier = 1.0 - clamp(defense_percent, 0.0, 1.0)
	return raw_damage * defense_multiplier

## 创建属性的副本（用于运行时修改，不影响原始数据）
func duplicate_stats() -> CharacterStats:
	var new_stats = CharacterStats.new()
	new_stats.max_health = max_health
	new_stats.defense_percent = defense_percent
	new_stats.attack = attack
	new_stats.attack_speed = attack_speed
	new_stats.knockback_force = knockback_force
	new_stats.crit_rate = crit_rate
	new_stats.crit_damage = crit_damage
	new_stats.move_speed = move_speed
	return new_stats

# ========== 运行时加成应用（升级 / 圣遗物 / buff 都可复用） ==========

## 将一批“平铺的加成字典”应用到当前属性。
## 约定：
## - 大多数 key 直接对应 CharacterStats 字段名（如 "attack"、"max_health"）
## - 特殊 key: "attack_percent" 表示对当前 attack 进行百分比加成（可叠加）
## - "defense_percent" / "crit_rate" 会自动 clamp 到 [0, 1]
func apply_bonuses(bonuses: Dictionary) -> void:
	if bonuses.is_empty():
		return

	var attack_percent_total := 0.0

	for stat_name in bonuses:
		var bonus_value: float = float(bonuses[stat_name])

		# 特殊处理：attack_percent 作用于 attack
		if stat_name == "attack_percent":
			attack_percent_total += bonus_value
			continue

		# 忽略不存在的字段（保持兼容，避免硬崩）
		if not stat_name in self:
			push_warning("CharacterStats: 属性 '%s' 不存在，已忽略加成" % stat_name)
			continue

		var new_value: float = float(get(stat_name)) + bonus_value

		# clamp 范围类属性
		if stat_name == "defense_percent" or stat_name == "crit_rate":
			new_value = clamp(new_value, 0.0, 1.0)

		set(stat_name, new_value)

	# 应用攻击力百分比加成（基于“已叠加完固定攻击力后的 attack”）
	if attack_percent_total != 0.0:
		attack = attack * (1.0 + attack_percent_total)

## 获取属性摘要（调试用）
func get_summary() -> String:
	return "HP:%.0f ATK:%.0f DEF:%.0f%% SPD:%.0f CR:%.0f%% CD:%.0f%% AS:%.1f KB:%.0f" % [
		max_health,
		attack,
		defense_percent * 100,
		move_speed,
		crit_rate * 100,
		crit_damage * 100,
		attack_speed,
		knockback_force
	]
