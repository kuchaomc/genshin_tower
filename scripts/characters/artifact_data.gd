extends Resource
class_name ArtifactData

## 圣遗物数据类
## 存储单个圣遗物的名称和属性加成效果

## 圣遗物名称
@export var name: String = ""

## 属性加成字典
## key: CharacterStats的属性名（如 "attack", "max_health" 等）
## value: 加成数值（固定值或百分比，根据属性类型决定）
## 例如: {"attack": 10.0} 表示增加10点攻击力
##      {"crit_rate": 0.05} 表示增加5%暴击率
@export var stat_bonuses: Dictionary = {}

## 获取属性加成
func get_stat_bonus(stat_name: String) -> float:
	return stat_bonuses.get(stat_name, 0.0)

## 获取所有属性加成
func get_all_stat_bonuses() -> Dictionary:
	return stat_bonuses.duplicate()

## 获取属性加成摘要（用于显示）
## level: 圣遗物等级（0=50%效果，1=100%效果）
func get_bonus_summary(level: int = 1) -> String:
	if stat_bonuses.is_empty():
		return "无属性加成"
	
	var effect_multiplier = 0.5 if level == 0 else 1.0
	var summary_parts: Array[String] = []
	for stat_name in stat_bonuses:
		var base_value = stat_bonuses[stat_name]
		var actual_value = base_value * effect_multiplier
		var stat_display_name = _get_stat_display_name(stat_name)
		summary_parts.append("%s: %s" % [stat_display_name, _format_stat_value(stat_name, actual_value)])
	
	return ", ".join(summary_parts)

## 获取属性显示名称
func _get_stat_display_name(stat_name: String) -> String:
	match stat_name:
		"max_health":
			return "生命值"
		"defense_percent":
			return "减伤"
		"attack":
			return "攻击力"
		"damage_multiplier":
			return "总伤"
		"attack_percent":
			return "攻击力百分比"
		"attack_speed":
			return "攻击速度"
		"knockback_force":
			return "击退"
		"crit_rate":
			return "暴击率"
		"crit_damage":
			return "暴击伤害"
		"move_speed":
			return "移动速度"
		_:
			return stat_name

## 格式化属性值显示
func _format_stat_value(stat_name: String, value: float) -> String:
	# 百分比属性显示为百分比
	if stat_name == "defense_percent" or stat_name == "crit_rate" or stat_name == "attack_percent" or stat_name == "crit_damage" or stat_name == "damage_multiplier":
		var percent_value: float = snappedf(value * 100.0, 0.1)
		if abs(percent_value - float(roundi(percent_value))) < 0.0001:
			return "%.0f%%" % percent_value
		return "%.1f%%" % percent_value
	# 其他属性显示为数值
	return "%.1f" % value
