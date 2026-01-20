extends RefCounted
class_name MapNodeData

## 纯数据地图节点（不挂场景树，不创建 UI）
## 用于 MapGenerator 生成与 MapView 渲染

enum NodeType {
	ENEMY,      # 普通战斗
	TREASURE,   # 宝箱
	REST,       # 休息处
	SHOP,       # 商店
	EVENT,      # 奇遇事件
	BOSS        # BOSS战
}

var node_id: String = ""
var node_type: NodeType = NodeType.ENEMY
var floor_number: int = 0
var position_in_floor: int = 0
var connected_nodes: Array[String] = []

func add_connection(connected_node_id: String) -> void:
	if connected_node_id.is_empty():
		return
	if connected_node_id not in connected_nodes:
		connected_nodes.append(connected_node_id)

func get_type_name() -> String:
	match node_type:
		NodeType.ENEMY:
			return "普通战斗"
		NodeType.TREASURE:
			return "宝箱"
		NodeType.SHOP:
			return "商店"
		NodeType.REST:
			return "休息处"
		NodeType.EVENT:
			return "奇遇事件"
		NodeType.BOSS:
			return "BOSS战"
		_:
			return "未知"

func get_icon_path() -> String:
	match node_type:
		NodeType.ENEMY:
			return "res://textures/ui/ENEMY.png"
		NodeType.TREASURE:
			return "res://textures/ui/TREASURE.png"
		NodeType.SHOP:
			return "res://textures/ui/SHOP.png"
		NodeType.REST:
			return "res://textures/ui/REST.png"
		NodeType.EVENT:
			return "res://textures/ui/EVENT.png"
		NodeType.BOSS:
			return "res://textures/ui/BOSS.png"
		_:
			return ""

