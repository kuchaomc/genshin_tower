extends Node2D
class_name MapNodeView

## 地图节点视图（只负责显示与交互）

signal node_selected(node_data: MapNodeData)

@onready var button: Button = $VBoxContainer/Button
@onready var icon: TextureRect = $VBoxContainer/Button/Icon
@onready var type_label: Label = $VBoxContainer/TypeLabel

var data: MapNodeData
var is_visited: bool = false

func _ready() -> void:
	if button:
		button.pressed.connect(_on_pressed)
	# 如果已经有数据，刷新显示（对象池复用场景）
	if data:
		_refresh_text_and_icon()

func bind(node_data: MapNodeData) -> void:
	data = node_data
	is_visited = false
	# 确保节点准备好后再刷新（如果还没准备好，延迟到下一帧）
	if is_inside_tree() and button and icon and type_label:
		_refresh_text_and_icon()
	else:
		call_deferred("_refresh_text_and_icon")
	update_visual_state(false)

func set_visited(visited: bool) -> void:
	is_visited = visited

func update_visual_state(is_selectable: bool) -> void:
	if not button:
		return
	if is_visited:
		button.modulate = Color(0.5, 0.5, 0.5, 1.0)
		button.disabled = true
	elif not is_selectable:
		var base := _get_base_color()
		button.modulate = Color(base.r * 0.7, base.g * 0.7, base.b * 0.7, 0.75)
		button.disabled = true
	else:
		button.modulate = _get_base_color()
		button.disabled = false

func _refresh_text_and_icon() -> void:
	if not data:
		return
	# 确保节点引用已准备好
	if not is_inside_tree():
		return
	if not button or not icon or not type_label:
		# 如果节点还没准备好，延迟执行
		call_deferred("_refresh_text_and_icon")
		return
	
	# 更新文本
	type_label.text = data.get_type_name()
	
	# 加载图标
	var path := data.get_icon_path()
	if path.is_empty():
		print("警告：节点类型 ", data.node_type, " 没有图标路径")
		icon.texture = null
		return
	
	var tex: Texture2D = null
	if DataManager and DataManager.has_method("get_texture"):
		tex = DataManager.get_texture(path)
	else:
		tex = load(path) as Texture2D
	
	if tex:
		icon.texture = tex
		icon.visible = true
	else:
		print("警告：无法加载节点图标 ", path, " (节点类型: ", data.node_type, ")")
		icon.texture = null
		icon.visible = false

func _get_base_color() -> Color:
	if not data:
		return Color.WHITE
	match data.node_type:
		MapNodeData.NodeType.ENEMY:
			return Color(1.0, 0.8, 0.8, 1.0)
		MapNodeData.NodeType.TREASURE:
			return Color(1.0, 0.9, 0.6, 1.0)
		MapNodeData.NodeType.SHOP:
			return Color(0.8, 0.8, 1.0, 1.0)
		MapNodeData.NodeType.REST:
			return Color(0.8, 1.0, 0.8, 1.0)
		MapNodeData.NodeType.EVENT:
			return Color(1.0, 1.0, 0.8, 1.0)
		MapNodeData.NodeType.BOSS:
			return Color(1.0, 0.4, 0.4, 1.0)
		_:
			return Color.WHITE

func _on_pressed() -> void:
	if is_visited or not data:
		return
	emit_signal("node_selected", data)

