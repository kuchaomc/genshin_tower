extends Resource
class_name EnemyData

## 敌人数据Resource类
## 用于存储敌人的基础属性和配置信息

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

# 基础属性
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
@export var scene_path: String = "res://scenes/敌人.tscn"

# 敌人类型（用于地图生成）
@export var enemy_type: String = "normal"  # normal, elite, boss
