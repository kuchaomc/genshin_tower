extends RefCounted
class_name ArtifactManager

## 圣遗物管理器
## 管理角色的圣遗物装备、卸载和属性加成应用

## 当前装备的圣遗物套装
var equipped_set: ArtifactSetData = null

## 圣遗物等级字典（槽位 -> 等级）
## 等级0 = 50%效果，等级1 = 100%效果
var artifact_levels: Dictionary = {}

## 初始化圣遗物管理器
func initialize(artifact_set: ArtifactSetData) -> void:
	equipped_set = artifact_set
	artifact_levels.clear()

## 装备圣遗物到指定槽位
## 如果该槽位已有相同圣遗物，则升级（等级+1，最高1级）
## 如果是新圣遗物，则装备并设置为0级（50%效果）
func equip_artifact(slot: ArtifactSlot.SlotType, artifact: ArtifactData) -> bool:
	if not equipped_set:
		push_error("ArtifactManager: 未初始化圣遗物套装")
		return false
	
	var current_artifact = equipped_set.get_artifact(slot)
	
	# 如果已装备相同圣遗物，则升级
	if current_artifact and current_artifact.name == artifact.name:
		var current_level = artifact_levels.get(slot, 0)
		if current_level < 1:  # 最高1级（100%效果）
			artifact_levels[slot] = current_level + 1
			print("圣遗物升级：%s 等级 %d -> %d（效果：%d%%）" % [artifact.name, current_level, artifact_levels[slot], _get_effect_percent(artifact_levels[slot])])
			return true
		else:
			print("圣遗物已满级：%s" % artifact.name)
			return false
	else:
		# 装备新圣遗物，初始等级0（50%效果）
		equipped_set.set_artifact(slot, artifact)
		artifact_levels[slot] = 0
		print("装备圣遗物：%s（等级0，效果50%%）" % artifact.name)
		return true

## 卸载指定槽位的圣遗物
func unequip_artifact(slot: ArtifactSlot.SlotType) -> bool:
	if not equipped_set:
		return false
	
	equipped_set.set_artifact(slot, null)
	# 清除等级信息
	if artifact_levels.has(slot):
		artifact_levels.erase(slot)
	return true

## 获取指定槽位的圣遗物
func get_artifact(slot: ArtifactSlot.SlotType) -> ArtifactData:
	if not equipped_set:
		return null
	return equipped_set.get_artifact(slot)

## 获取所有已装备的圣遗物
func get_all_equipped_artifacts() -> Dictionary:
	if not equipped_set:
		return {}
	return equipped_set.get_all_artifacts()

## 获取指定槽位的圣遗物等级
func get_artifact_level(slot: ArtifactSlot.SlotType) -> int:
	return artifact_levels.get(slot, 0)

## 获取指定槽位的效果百分比（0级=50%，1级=100%）
func _get_effect_percent(level: int) -> int:
	match level:
		0:
			return 50
		1:
			return 100
		_:
			return 50

## 应用圣遗物属性加成到角色属性
## 返回一个字典，包含所有属性加成（根据等级计算）
func apply_stat_bonuses() -> Dictionary:
	if not equipped_set:
		return {}
	
	var total_bonuses: Dictionary = {}
	
	for slot in ArtifactSlot.get_all_slots():
		var artifact = equipped_set.get_artifact(slot)
		if artifact:
			var level = artifact_levels.get(slot, 0)
			var effect_multiplier = 0.5 if level == 0 else 1.0  # 0级=50%，1级=100%
			
			var bonuses = artifact.get_all_stat_bonuses()
			for stat_name in bonuses:
				if not total_bonuses.has(stat_name):
					total_bonuses[stat_name] = 0.0
				# 根据等级应用效果
				total_bonuses[stat_name] += bonuses[stat_name] * effect_multiplier
	
	return total_bonuses

## 检查是否已装备指定槽位的圣遗物
func is_slot_equipped(slot: ArtifactSlot.SlotType) -> bool:
	return get_artifact(slot) != null

## 获取已装备圣遗物数量
func get_equipped_count() -> int:
	if not equipped_set:
		return 0
	
	var count = 0
	for slot in ArtifactSlot.get_all_slots():
		if is_slot_equipped(slot):
			count += 1
	return count
