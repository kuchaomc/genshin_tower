extends Resource
class_name CharacterData

## 角色数据Resource类
## 用于存储角色的基础属性和配置信息

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D

# 基础属性
@export var max_health: float = 100.0
@export var move_speed: float = 100.0
@export var base_damage: float = 25.0
@export var attack_speed: float = 1.0  # 攻击速度倍率

# 角色场景路径
@export var scene_path: String = "res://scenes/玩家.tscn"

# 角色技能（未来扩展）
@export var abilities: Array[String] = []

# 角色描述文本
func get_description() -> String:
	if description.is_empty():
		return "基础角色"
	return description
