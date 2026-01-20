extends Resource
class_name EnemyData

## 敌人数据Resource类
## 用于存储敌人的基础属性和配置信息

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

# ========== 统一属性系统 ==========
## 敌人属性（必填）
@export var stats: EnemyStats = null

# ========== 敌人配置 ==========
@export var warning_duration: float = 2.0

# AI行为类型
@export var behavior_type: String = "chase"  # chase, ranged, boss, stationary

# 掉落奖励
@export var drop_gold: int = 10
@export var drop_exp: int = 1
# 击杀分值（每击杀一个敌人获得的分数）
@export var score_value: int = 1

# 敌人场景路径
@export var scene_path: String = "res://scenes/enemies/enemy.tscn"

# 敌人类型（用于地图生成）
@export var enemy_type: String = "normal"  # normal, boss

## 获取敌人属性对象
func get_stats() -> EnemyStats:
	if stats:
		return stats
	
	# 如果没有设置属性，返回默认属性
	push_warning("敌人 '%s' 未设置 stats 属性，使用默认值" % display_name)
	var default_stats = EnemyStats.new()
	return default_stats
