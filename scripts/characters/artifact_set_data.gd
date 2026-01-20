extends Resource
class_name ArtifactSetData

## 圣遗物套装数据类
## 为每个角色定义专属的圣遗物套装（5个位置）

## 角色ID（用于关联角色）
@export var character_id: String = ""

## 套装名称
@export var set_name: String = ""

## 套装描述
@export var set_description: String = ""

## 五个位置的圣遗物
@export var flower: ArtifactData = null      # 生之花
@export var plume: ArtifactData = null       # 死之羽
@export var sands: ArtifactData = null       # 时之沙
@export var goblet: ArtifactData = null      # 空之杯
@export var circlet: ArtifactData = null     # 理之冠

## 根据槽位类型获取圣遗物
func get_artifact(slot: ArtifactSlot.SlotType) -> ArtifactData:
	match slot:
		ArtifactSlot.SlotType.FLOWER:
			return flower
		ArtifactSlot.SlotType.PLUME:
			return plume
		ArtifactSlot.SlotType.SANDS:
			return sands
		ArtifactSlot.SlotType.GOBLET:
			return goblet
		ArtifactSlot.SlotType.CIRCLET:
			return circlet
		_:
			return null

## 设置指定槽位的圣遗物
func set_artifact(slot: ArtifactSlot.SlotType, artifact: ArtifactData) -> void:
	match slot:
		ArtifactSlot.SlotType.FLOWER:
			flower = artifact
		ArtifactSlot.SlotType.PLUME:
			plume = artifact
		ArtifactSlot.SlotType.SANDS:
			sands = artifact
		ArtifactSlot.SlotType.GOBLET:
			goblet = artifact
		ArtifactSlot.SlotType.CIRCLET:
			circlet = artifact

## 获取所有已装备的圣遗物
func get_all_artifacts() -> Dictionary:
	var result = {}
	if flower:
		result[ArtifactSlot.SlotType.FLOWER] = flower
	if plume:
		result[ArtifactSlot.SlotType.PLUME] = plume
	if sands:
		result[ArtifactSlot.SlotType.SANDS] = sands
	if goblet:
		result[ArtifactSlot.SlotType.GOBLET] = goblet
	if circlet:
		result[ArtifactSlot.SlotType.CIRCLET] = circlet
	return result

## 获取所有属性加成的总和
func get_total_stat_bonuses() -> Dictionary:
	var total_bonuses: Dictionary = {}
	
	for slot in ArtifactSlot.get_all_slots():
		var artifact = get_artifact(slot)
		if artifact:
			var bonuses = artifact.get_all_stat_bonuses()
			for stat_name in bonuses:
				if not total_bonuses.has(stat_name):
					total_bonuses[stat_name] = 0.0
				total_bonuses[stat_name] += bonuses[stat_name]
	
	return total_bonuses
