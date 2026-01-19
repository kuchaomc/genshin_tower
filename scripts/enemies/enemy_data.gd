extends Resource
class_name EnemyData

## 敌人数据Resource类
## 用于存储敌人的基础属性和配置信息

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

# ========== 统一属性系统 ==========
## 敌人属性（推荐使用）
@export var stats: EnemyStats = null

# ========== 兼容旧版属性（将被废弃） ==========
@export_group("Legacy Attributes (Deprecated)")
@export var max_health: float = 100.0
@export var damage: float = 25.0
@export var move_speed: float = 100.0
@export var warning_duration: float = 2.0

# AI行为类型
@export var behavior_type: String = "chase"  # chase, ranged, boss, stationary

# 掉落奖励
@export var drop_gold: int = 10
@export var drop_exp: int = 1

# 敌人场景路径
@export var scene_path: String = "res://scenes/enemies/enemy.tscn"

# 敌人类型（用于地图生成）
@export var enemy_type: String = "normal"  # normal, elite, boss

## 获取有效的属性对象
## 如果 stats 存在则返回 stats，否则从旧字段创建
func get_stats() -> EnemyStats:
	if stats:
		return stats
	
	# 从旧字段创建属性（兼容旧版数据）
	var legacy_stats = EnemyStats.new()
	legacy_stats.max_health = max_health
	legacy_stats.move_speed = move_speed
	legacy_stats.attack = damage
	return legacy_stats
