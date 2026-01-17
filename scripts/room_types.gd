extends Object
class_name RoomTypes

# 房间类型枚举
enum RoomType {
	BATTLE_NORMAL,      # 普通战斗
	BATTLE_ELITE,       # 精英战斗
	SHOP,               # 商店
	REST,               # 休息处
	EVENT,              # 随机事件
	BOSS                # BOSS战
}

# 房间状态枚举
enum RoomState {
	LOCKED,     # 锁定（不可访问）
	AVAILABLE,  # 可访问
	COMPLETED   # 已完成
}

# 房间数据类
class RoomData:
	var type: RoomType
	var state: RoomState = RoomState.LOCKED
	var position: Vector2i = Vector2i.ZERO  # 层和位置 (layer, index)
	var name: String = ""
	var icon_path: String = ""
	
	func _init(room_type: RoomType, pos: Vector2i) -> void:
		type = room_type
		position = pos
		name = get_room_name(room_type)
		icon_path = get_room_icon_path(room_type)
	
	func is_battle_room() -> bool:
		return type == RoomType.BATTLE_NORMAL or type == RoomType.BATTLE_ELITE or type == RoomType.BOSS
	
	func is_accessible() -> bool:
		return state == RoomState.AVAILABLE
	
	func is_completed() -> bool:
		return state == RoomState.COMPLETED
	
	func complete() -> void:
		state = RoomState.COMPLETED
	
	func unlock() -> void:
		state = RoomState.AVAILABLE
	
	func lock() -> void:
		state = RoomState.LOCKED

# 获取房间类型对应的显示名称
static func get_room_name(room_type: RoomType) -> String:
	match room_type:
		RoomType.BATTLE_NORMAL:
			return "普通战斗"
		RoomType.BATTLE_ELITE:
			return "精英战斗"
		RoomType.SHOP:
			return "商店"
		RoomType.REST:
			return "休息处"
		RoomType.EVENT:
			return "随机事件"
		RoomType.BOSS:
			return "BOSS战"
		_:
			return "未知房间"

# 获取房间类型对应的图标路径
static func get_room_icon_path(room_type: RoomType) -> String:
	match room_type:
		RoomType.BATTLE_NORMAL:
			return "res://textures/普通战斗房间图标.png"
		RoomType.BATTLE_ELITE:
			return "res://textures/暂不使用.png"  # 暂用占位符
		RoomType.SHOP:
			return "res://textures/商店图标.png"
		RoomType.REST:
			return "res://textures/暂不使用.png"  # 暂用占位符
		RoomType.EVENT:
			return "res://textures/奇遇图标.png"
		RoomType.BOSS:
			return "res://textures/暂不使用.png"  # 暂用占位符
		_:
			return "res://textures/暂不使用.png"

# 获取房间类型对应的颜色（用于UI显示）
static func get_room_color(room_type: RoomType) -> Color:
	match room_type:
		RoomType.BATTLE_NORMAL:
			return Color.WHITE
		RoomType.BATTLE_ELITE:
			return Color.GOLD
		RoomType.SHOP:
			return Color.SKY_BLUE
		RoomType.REST:
			return Color.LIME_GREEN
		RoomType.EVENT:
			return Color.PLUM
		RoomType.BOSS:
			return Color.CRIMSON
		_:
			return Color.GRAY

# 检查是否为战斗类型房间
static func is_battle_type(room_type: RoomType) -> bool:
	return room_type == RoomType.BATTLE_NORMAL or room_type == RoomType.BATTLE_ELITE or room_type == RoomType.BOSS

# 检查是否为可交互的非战斗房间
static func is_interactive_type(room_type: RoomType) -> bool:
	return room_type == RoomType.SHOP or room_type == RoomType.REST or room_type == RoomType.EVENT