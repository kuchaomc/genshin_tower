extends Resource
class_name UpgradeData

## 升级数据资源类
## 定义单个升级的所有属性和效果
## 支持基础属性、特殊属性和自定义效果升级

# ========== 升级类型枚举 ==========
enum UpgradeType {
	STAT_FLAT,      # 固定值加成（如 +20 生命）
	STAT_PERCENT,   # 百分比加成（如 +10% 攻击力）
	ABILITY,        # 技能相关（如技能范围、冷却时间）
	SPECIAL,        # 特殊效果（如闪避距离、击退抗性）
	CUSTOM          # 自定义效果（通过回调实现）
}

# ========== 升级稀有度枚举 ==========
enum Rarity {
	COMMON,         # 普通（白色）
	UNCOMMON,       # 稀有（绿色）
	RARE,           # 精良（蓝色）
	EPIC,           # 史诗（紫色）
	LEGENDARY       # 传说（橙色）
}

# ========== 目标属性枚举 ==========
## 可被升级的属性列表
enum TargetStat {
	# 基础属性
	MAX_HEALTH,         # 最大生命值
	ATTACK,             # 攻击力
	DEFENSE_PERCENT,    # 减伤比例
	MOVE_SPEED,         # 移动速度
	ATTACK_SPEED,       # 攻击速度
	CRIT_RATE,          # 暴击率
	CRIT_DAMAGE,        # 暴击伤害
	KNOCKBACK_FORCE,    # 击退力度
	
	# 闪避属性
	DODGE_DISTANCE,     # 闪避距离
	DODGE_COOLDOWN,     # 闪避冷却
	DODGE_DURATION,     # 闪避持续时间
	
	# 技能属性（通用）
	SKILL_DAMAGE,       # 技能伤害倍率
	SKILL_COOLDOWN,     # 技能冷却时间
	SKILL_RADIUS,       # 技能范围
	BURST_DAMAGE,       # 大招伤害倍率
	BURST_ENERGY_COST,  # 大招充能需求
	ENERGY_GAIN,        # 充能获取量
	
	# 特殊属性
	INVINCIBILITY_DURATION,  # 无敌时间
	KNOCKBACK_RESISTANCE,    # 击退抗性
	
	# 自定义（不直接映射到属性）
	CUSTOM
}

# ========== 基础信息 ==========
## 升级唯一标识符
@export var id: String = ""
## 升级显示名称
@export var display_name: String = ""
## 升级描述（支持 {value} 占位符）
@export_multiline var description: String = ""
## 升级图标
@export var icon: Texture2D

# ========== 升级配置 ==========
## 升级类型
@export var upgrade_type: UpgradeType = UpgradeType.STAT_FLAT
## 稀有度
@export var rarity: Rarity = Rarity.COMMON
## 目标属性
@export var target_stat: TargetStat = TargetStat.MAX_HEALTH
## 最大等级（0 表示无限）
@export var max_level: int = 5
## 每级提供的数值（固定值或百分比）
@export var value_per_level: float = 10.0
## 基础权重（影响出现概率，越高越容易出现）
@export var base_weight: float = 100.0

# ========== 条件和限制 ==========
## 需要的角色ID（空表示所有角色可用）
@export var required_character_ids: Array[String] = []
## 需要的前置升级ID（必须先拥有这些升级）
@export var required_upgrade_ids: Array[String] = []
## 互斥的升级ID（不能同时拥有）
@export var exclusive_upgrade_ids: Array[String] = []
## 最低楼层要求
@export var min_floor: int = 0

# ========== 标签系统（用于分类和筛选） ==========
## 升级标签
@export var tags: Array[String] = []

# ========== 动态数值计算 ==========

## 获取当前等级的实际数值
func get_value_at_level(level: int) -> float:
	return value_per_level * level

## 获取下一级的数值
func get_next_level_value(current_level: int) -> float:
	return value_per_level * (current_level + 1)

## 获取当前等级提供的增量（本次升级提供的数值）
func get_level_increment() -> float:
	return value_per_level

## 获取格式化的描述（替换占位符）
func get_formatted_description(current_level: int = 0) -> String:
	var formatted = description
	var current_value = get_value_at_level(current_level)
	var next_value = get_next_level_value(current_level)
	var increment = get_level_increment()
	
	# 替换占位符
	formatted = formatted.replace("{value}", _format_value(increment))
	formatted = formatted.replace("{current}", _format_value(current_value))
	formatted = formatted.replace("{next}", _format_value(next_value))
	formatted = formatted.replace("{level}", str(current_level))
	formatted = formatted.replace("{max_level}", str(max_level))
	
	return formatted

## 格式化数值显示
func _format_value(value: float) -> String:
	if upgrade_type == UpgradeType.STAT_PERCENT:
		return "%.0f%%" % (value * 100) if value < 1.0 else "%.0f%%" % value
	elif abs(value - floor(value)) < 0.001:
		return "%.0f" % value
	else:
		return "%.1f" % value

## 获取稀有度颜色
func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:
			return Color(0.9, 0.9, 0.9)  # 白色
		Rarity.UNCOMMON:
			return Color(0.4, 0.9, 0.4)  # 绿色
		Rarity.RARE:
			return Color(0.4, 0.6, 1.0)  # 蓝色
		Rarity.EPIC:
			return Color(0.7, 0.4, 0.9)  # 紫色
		Rarity.LEGENDARY:
			return Color(1.0, 0.6, 0.2)  # 橙色
		_:
			return Color.WHITE

## 获取稀有度名称
func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON:
			return "普通"
		Rarity.UNCOMMON:
			return "稀有"
		Rarity.RARE:
			return "精良"
		Rarity.EPIC:
			return "史诗"
		Rarity.LEGENDARY:
			return "传说"
		_:
			return "未知"

## 获取稀有度星星emoji
func get_rarity_stars() -> String:
	match rarity:
		Rarity.COMMON:
			return "⭐"
		Rarity.UNCOMMON:
			return "⭐⭐"
		Rarity.RARE:
			return "⭐⭐⭐"
		Rarity.EPIC:
			return "⭐⭐⭐⭐"
		Rarity.LEGENDARY:
			return "⭐⭐⭐⭐⭐"
		_:
			return "⭐"

# ========== 条件检查 ==========

## 检查角色是否可以获得此升级
func can_character_acquire(character_id: String, current_upgrades: Dictionary, current_floor: int) -> bool:
	# 检查角色限制
	if required_character_ids.size() > 0 and character_id not in required_character_ids:
		return false
	
	# 检查楼层限制
	if current_floor < min_floor:
		return false
	
	# 检查最大等级
	var current_level = current_upgrades.get(id, 0)
	if max_level > 0 and current_level >= max_level:
		return false
	
	# 检查前置升级
	for required_id in required_upgrade_ids:
		if not current_upgrades.has(required_id) or current_upgrades[required_id] <= 0:
			return false
	
	# 检查互斥升级
	for exclusive_id in exclusive_upgrade_ids:
		if current_upgrades.has(exclusive_id) and current_upgrades[exclusive_id] > 0:
			return false
	
	return true

## 计算当前权重（可被子类重写以实现动态权重）
func calculate_weight(current_upgrades: Dictionary, current_floor: int) -> float:
	var weight = base_weight
	
	# 根据稀有度调整权重
	match rarity:
		Rarity.UNCOMMON:
			weight *= 0.7
		Rarity.RARE:
			weight *= 0.4
		Rarity.EPIC:
			weight *= 0.15
		Rarity.LEGENDARY:
			weight *= 0.05
	
	# 高楼层略微增加稀有升级出现概率
	if current_floor > 3:
		var floor_bonus = (current_floor - 3) * 0.05
		if rarity >= Rarity.RARE:
			weight *= (1.0 + floor_bonus)
	
	return weight

# ========== 复制方法 ==========

## 创建升级数据的副本
func duplicate_upgrade() -> UpgradeData:
	var copy = UpgradeData.new()
	copy.id = id
	copy.display_name = display_name
	copy.description = description
	copy.icon = icon
	copy.upgrade_type = upgrade_type
	copy.rarity = rarity
	copy.target_stat = target_stat
	copy.max_level = max_level
	copy.value_per_level = value_per_level
	copy.base_weight = base_weight
	copy.required_character_ids = required_character_ids.duplicate()
	copy.required_upgrade_ids = required_upgrade_ids.duplicate()
	copy.exclusive_upgrade_ids = exclusive_upgrade_ids.duplicate()
	copy.min_floor = min_floor
	copy.tags = tags.duplicate()
	return copy
