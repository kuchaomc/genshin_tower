extends RefCounted
class_name ArtifactManager

## 圣遗物管理器
## 管理角色的圣遗物装备、卸载和属性加成应用

## 当前装备的圣遗物套装
var equipped_set: ArtifactSetData = null

## 初始化圣遗物管理器
func initialize(artifact_set: ArtifactSetData) -> void:
	equipped_set = artifact_set

## 装备圣遗物到指定槽位
func equip_artifact(slot: ArtifactSlot.SlotType, artifact: ArtifactData) -> bool:
	if not equipped_set:
		push_error("ArtifactManager: 未初始化圣遗物套装")
		return false
	
	equipped_set.set_artifact(slot, artifact)
	return true

## 卸载指定槽位的圣遗物
func unequip_artifact(slot: ArtifactSlot.SlotType) -> bool:
	if not equipped_set:
		return false
	
	equipped_set.set_artifact(slot, null)
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

## 应用圣遗物属性加成到角色属性
## 返回一个字典，包含所有属性加成
func apply_stat_bonuses() -> Dictionary:
	if not equipped_set:
		return {}
	
	return equipped_set.get_total_stat_bonuses()

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
