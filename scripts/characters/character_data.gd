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
## 角色属性（推荐使用）
@export var stats: CharacterStats = null

# ========== 兼容旧版属性（将被废弃） ==========
@export_group("旧版属性（将被废弃）")
## 最大生命值
@export var max_health: float = 100.0
## 移动速度
@export var move_speed: float = 100.0
## 基础伤害
@export var base_damage: float = 25.0
## 攻击速度倍率
@export var attack_speed: float = 1.0
## 击退力度
@export var knockback_force: float = 150.0

## 角色场景路径（必须为每个角色显式设置）
@export var scene_path: String = ""

## 角色技能列表（未来扩展）
@export var abilities: Array[String] = []

## 获取有效的属性对象
## 如果 stats 存在则返回 stats，否则从旧字段创建
func get_stats() -> CharacterStats:
	if stats:
		return stats
	
	# 从旧字段创建属性（兼容旧版数据）
	var legacy_stats = CharacterStats.new()
	legacy_stats.max_health = max_health
	legacy_stats.move_speed = move_speed
	legacy_stats.attack = base_damage
	legacy_stats.attack_speed = attack_speed
	legacy_stats.knockback_force = knockback_force
	return legacy_stats

# 角色描述文本
func get_description() -> String:
	if description.is_empty():
		return "基础角色"
	return description
