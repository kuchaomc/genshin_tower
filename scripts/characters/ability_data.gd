extends Resource
class_name AbilityData

## 技能数据Resource类
## 用于存储技能的基础信息

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D

# 技能类型
@export var ability_type: String = "passive"  # passive, active, ultimate

# 技能效果（未来扩展）
@export var effects: Dictionary = {}
