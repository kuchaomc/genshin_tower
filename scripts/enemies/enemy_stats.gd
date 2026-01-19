extends Resource
class_name EnemyStats

## 敌人属性资源类
## 统一存储敌人的所有战斗相关属性

# ========== 基础生存属性 ==========
## 最大生命值
@export var max_health: float = 100.0
## 减伤比例（0.0 ~ 1.0，例如 0.2 表示减少 20% 伤害）
@export_range(0.0, 1.0) var defense_percent: float = 0.0

# ========== 攻击属性 ==========
## 基础攻击力（用于对玩家造成伤害）
@export var attack: float = 25.0

# ========== 移动属性 ==========
## 移动速度
@export var move_speed: float = 100.0

# ========== 伤害计算方法 ==========

## 计算受到的伤害（应用自身减伤）
## raw_damage: 原始伤害值
## 返回值: 实际受到的伤害
func calculate_damage_taken(raw_damage: float) -> float:
	var defense_multiplier = 1.0 - clamp(defense_percent, 0.0, 1.0)
	return raw_damage * defense_multiplier

## 创建属性的副本（用于运行时修改）
func duplicate_stats() -> EnemyStats:
	var new_stats = EnemyStats.new()
	new_stats.max_health = max_health
	new_stats.defense_percent = defense_percent
	new_stats.attack = attack
	new_stats.move_speed = move_speed
	return new_stats

## 获取属性摘要（调试用）
func get_summary() -> String:
	return "HP:%.0f ATK:%.0f DEF:%.0f%% SPD:%.0f" % [
		max_health,
		attack,
		defense_percent * 100,
		move_speed
	]
