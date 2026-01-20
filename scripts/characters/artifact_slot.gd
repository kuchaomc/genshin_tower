extends RefCounted
class_name ArtifactSlot

## 圣遗物槽位枚举
## 定义五个圣遗物装备位置

enum SlotType {
	FLOWER,      # 生之花
	PLUME,       # 死之羽
	SANDS,       # 时之沙
	GOBLET,      # 空之杯
	CIRCLET      # 理之冠
}

## 获取槽位名称
static func get_slot_name(slot: SlotType) -> String:
	match slot:
		SlotType.FLOWER:
			return "生之花"
		SlotType.PLUME:
			return "死之羽"
		SlotType.SANDS:
			return "时之沙"
		SlotType.GOBLET:
			return "空之杯"
		SlotType.CIRCLET:
			return "理之冠"
		_:
			return "未知"

## 获取所有槽位
static func get_all_slots() -> Array[SlotType]:
	return [SlotType.FLOWER, SlotType.PLUME, SlotType.SANDS, SlotType.GOBLET, SlotType.CIRCLET]
