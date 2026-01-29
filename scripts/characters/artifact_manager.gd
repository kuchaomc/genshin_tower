extends RefCounted
class_name ArtifactManager

## 圣遗物管理器
## 管理角色的圣遗物装备、卸载和属性加成应用

## 当前装备的圣遗物套装
var equipped_set: ArtifactSetData = null

## 圣遗物等级字典（槽位 -> 等级）
## 兼容字段：当前版本圣遗物获得即 100% 效果，等级恒为 1
var artifact_levels: Dictionary = {}

## 初始化圣遗物管理器
func initialize(artifact_set: ArtifactSetData) -> void:
	equipped_set = artifact_set
	artifact_levels.clear()

## 装备圣遗物到指定槽位
func equip_artifact(slot: ArtifactSlot.SlotType, artifact: ArtifactData) -> bool:
	if not equipped_set:
		push_error("ArtifactManager: 未初始化圣遗物套装")
		return false
	
	var current_artifact = equipped_set.get_artifact(slot)
	
	# 始终确保槽位装备为该圣遗物（不同圣遗物则替换）
	if not current_artifact or current_artifact.name != artifact.name:
		equipped_set.set_artifact(slot, artifact)
		artifact_levels[slot] = 1
		print("装备圣遗物：%s（效果100%%）" % artifact.name)
		return true

	# 相同圣遗物：重复获得不再提升效果
	print("圣遗物已装备：%s" % artifact.name)
	return false

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
	return artifact_levels.get(slot, 1)

## 应用圣遗物属性加成到角色属性
## 返回一个字典，包含所有属性加成（当前版本：获得即满效果）
func apply_stat_bonuses() -> Dictionary:
	if not equipped_set:
		return {}
	
	var total_bonuses: Dictionary = {}
	
	for slot in ArtifactSlot.get_all_slots():
		var artifact = equipped_set.get_artifact(slot)
		if artifact:
			var bonuses = artifact.get_all_stat_bonuses()
			for stat_name in bonuses:
				if not total_bonuses.has(stat_name):
					total_bonuses[stat_name] = 0.0
				total_bonuses[stat_name] += bonuses[stat_name]
	
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
