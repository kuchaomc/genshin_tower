extends Resource
class_name EventData

## 奇遇事件数据资源类
## 定义单个事件的所有属性和行为
## 支持多种事件类型、条件判断和动态效果

# ========== 事件类型枚举 ==========
enum EventType {
	REWARD,          # 简单奖励事件（直接给奖励）
	CHOICE,          # 选择事件（多个选项，不同结果）
	BATTLE,          # 战斗事件（触发战斗）
	SHOP,            # 特殊商店事件
	REST,            # 休息事件（回复生命值）
	UPGRADE,         # 升级事件（直接给升级）
	RANDOM,          # 随机事件（随机结果）
	CUSTOM           # 自定义事件（通过回调实现）
}

# ========== 奖励类型枚举 ==========
enum RewardType {
	GOLD,            # 摩拉
	HEALTH,          # 生命值
	UPGRADE,         # 升级
	ARTIFACT,        # 圣遗物
	MULTIPLE         # 多种奖励组合
}

# ========== 事件稀有度枚举 ==========
enum Rarity {
	COMMON,          # 普通（白色）
	UNCOMMON,        # 稀有（绿色）
	RARE,            # 精良（蓝色）
	EPIC,            # 史诗（紫色）
	LEGENDARY        # 传说（橙色）
}

# ========== 基础信息 ==========
## 事件唯一标识符
@export var id: String = ""
## 事件显示名称
@export var display_name: String = ""
## 事件描述文本（支持 {value} 等占位符）
@export_multiline var description: String = ""
## 事件图标
@export var icon: Texture2D

# ========== 事件配置 ==========
## 事件类型
@export var event_type: EventType = EventType.REWARD
## 稀有度
@export var rarity: Rarity = Rarity.COMMON
## 基础权重（影响出现概率，越高越容易出现）
@export var base_weight: float = 100.0

# ========== 条件和限制 ==========
## 需要的角色ID（空表示所有角色可用）
@export var required_character_ids: Array[String] = []
## 需要的前置事件ID（必须先触发过这些事件）
@export var required_event_ids: Array[String] = []
## 互斥的事件ID（不能同时出现）
@export var exclusive_event_ids: Array[String] = []
## 最低楼层要求
@export var min_floor: int = 0
## 最高楼层限制（0表示无限制）
@export var max_floor: int = 0
## 是否只能触发一次
@export var one_time_only: bool = false

# ========== 标签系统（用于分类和筛选） ==========
## 事件标签
@export var tags: Array[String] = []

# ========== 奖励配置 ==========
## 奖励类型（用于REWARD类型事件）
@export var reward_type: RewardType = RewardType.GOLD
## 奖励数值（摩拉数量、生命值、升级ID等）
## 支持固定值、数组范围[min, max]用于随机，或字典用于MULTIPLE类型
@export var reward_value: Variant = 0
## 奖励最小值（用于随机范围，如果设置了则reward_value为最大值）
@export var reward_min: float = 0.0
## 奖励最大值（用于随机范围）
@export var reward_max: float = 0.0
## 奖励描述文本
@export var reward_description: String = ""

# ========== 选择配置（用于CHOICE类型事件） ==========
## 选择项列表（每个选择项是一个字典）
## 格式: {text: String, reward_type: RewardType, reward_value: Variant, description: String}
@export var choices: Array[Dictionary] = []

# ========== 战斗配置（用于BATTLE类型事件） ==========
## 敌人数据资源（EnemyData）
@export var enemy_data: Resource = null
## 战斗胜利奖励
@export var battle_reward: Dictionary = {}

# ========== 动态数值计算 ==========

## 获取格式化的描述（替换占位符）
func get_formatted_description(context: Dictionary = {}) -> String:
	var formatted = description
	
	# 替换通用占位符
	formatted = formatted.replace("{floor}", str(context.get("floor", 0)))
	formatted = formatted.replace("{gold}", str(context.get("gold", 0)))
	formatted = formatted.replace("{health}", str(context.get("health", 0)))
	
	# 替换奖励相关占位符
	if reward_type == RewardType.GOLD:
		formatted = formatted.replace("{reward}", str(reward_value))
	elif reward_type == RewardType.HEALTH:
		formatted = formatted.replace("{reward}", str(reward_value))
	
	return formatted

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

## 检查事件是否可以触发
func can_trigger(character_id: String, current_floor: int, triggered_events: Array[String]) -> bool:
	# 检查角色限制
	if required_character_ids.size() > 0 and character_id not in required_character_ids:
		return false
	
	# 检查楼层限制
	if current_floor < min_floor:
		return false
	
	if max_floor > 0 and current_floor > max_floor:
		return false
	
	# 检查是否只能触发一次
	if one_time_only and id in triggered_events:
		return false
	
	# 检查前置事件
	for required_id in required_event_ids:
		if required_id not in triggered_events:
			return false
	
	# 检查互斥事件
	for exclusive_id in exclusive_event_ids:
		if exclusive_id in triggered_events:
			return false
	
	return true

## 计算当前权重（可被子类重写以实现动态权重）
func calculate_weight(current_floor: int, triggered_events: Array[String]) -> float:
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
	
	# 高楼层略微增加稀有事件出现概率
	if current_floor > 3:
		var floor_bonus = (current_floor - 3) * 0.05
		if rarity >= Rarity.RARE:
			weight *= (1.0 + floor_bonus)
	
	return weight

# ========== 复制方法 ==========

## 创建事件数据的副本
func duplicate_event() -> EventData:
	var copy = EventData.new()
	copy.id = id
	copy.display_name = display_name
	copy.description = description
	copy.icon = icon
	copy.event_type = event_type
	copy.rarity = rarity
	copy.base_weight = base_weight
	copy.required_character_ids = required_character_ids.duplicate()
	copy.required_event_ids = required_event_ids.duplicate()
	copy.exclusive_event_ids = exclusive_event_ids.duplicate()
	copy.min_floor = min_floor
	copy.max_floor = max_floor
	copy.one_time_only = one_time_only
	copy.tags = tags.duplicate()
	copy.reward_type = reward_type
	copy.reward_value = reward_value
	copy.reward_description = reward_description
	copy.choices = choices.duplicate()
	copy.enemy_data = enemy_data
	copy.battle_reward = battle_reward.duplicate()
	return copy
