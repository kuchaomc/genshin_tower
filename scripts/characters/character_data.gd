extends Resource
class_name CharacterData

## 角色数据Resource类
## 用于存储角色的基础属性和配置信息

## 角色唯一标识符
@export var id: String = ""
## 角色显示名称
@export var display_name: String = ""
## 角色描述文本
@export var description: String = ""
## 角色图标
@export var icon: Texture2D

# ========== 统一属性系统 ==========
## 角色属性（必填）
@export var stats: CharacterStats = null

## 角色场景路径（必须为每个角色显式设置）
@export var scene_path: String = ""

## 角色技能列表（未来扩展）
@export var abilities: Array[String] = []

# ========== 圣遗物系统 ==========
## 角色专属圣遗物套装（每个角色都有独一无二的圣遗物）
@export var artifact_set: ArtifactSetData = null

## 获取角色属性对象
func get_stats() -> CharacterStats:
	if stats:
		return stats
	
	# 如果没有设置属性，返回默认属性
	push_warning("角色 '%s' 未设置 stats 属性，使用默认值" % display_name)
	var default_stats = CharacterStats.new()
	return default_stats

# 角色描述文本
func get_description() -> String:
	if description.is_empty():
		return "基础角色"
	return description
