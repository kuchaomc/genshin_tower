extends Node

## 转场管理器
## 负责场景切换时的转场动画效果

signal transition_finished

# 转场遮罩层（动态创建）
var transition_overlay: ColorRect
var transition_layer: CanvasLayer
# 是否正在转场
var is_transitioning: bool = false

func _ready() -> void:
	print("转场管理器已初始化")

## 确保转场层存在
func _ensure_transition_layer() -> void:
	if not transition_layer:
		transition_layer = CanvasLayer.new()
		transition_layer.layer = 100  # 设置高层级，确保在最上层
		add_child(transition_layer)
	
	if not transition_overlay:
		transition_overlay = ColorRect.new()
		transition_overlay.color = Color(0, 0, 0, 0)  # 初始透明
		transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		transition_overlay.visible = false
		transition_layer.add_child(transition_overlay)

## 播放淡出动画（场景切换前）
func fade_out(duration: float = 2.0) -> void:
	if is_transitioning:
		return
	
	_ensure_transition_layer()
	is_transitioning = true
	transition_overlay.visible = true
	transition_overlay.color = Color(0, 0, 0, 0)
	
	var tween = create_tween()
	tween.tween_property(transition_overlay, "color:a", 1.0, duration)
	await tween.finished
	
	emit_signal("transition_finished")

## 播放淡入动画（场景加载后）
func fade_in(duration: float = 2.0) -> void:
	_ensure_transition_layer()
	
	if not transition_overlay:
		return
	
	transition_overlay.visible = true
	transition_overlay.color = Color(0, 0, 0, 1)  # 从黑色开始
	
	var tween = create_tween()
	tween.tween_property(transition_overlay, "color:a", 0.0, duration)
	await tween.finished
	
	transition_overlay.visible = false
	is_transitioning = false

## 播放淡入动画，同时控制另一个节点的透明度（用于楼层提示与黑屏一同淡出）
func fade_in_with_node(duration: float = 2.0, target_node: Node = null) -> void:
	_ensure_transition_layer()
	
	if not transition_overlay:
		return
	
	transition_overlay.visible = true
	transition_overlay.color = Color(0, 0, 0, 1)  # 从黑色开始
	
	# 如果提供了目标节点，同时控制其透明度
	var control_node: Control = null
	if target_node and target_node is Control:
		control_node = target_node as Control
		control_node.modulate.a = 1.0  # 确保初始完全不透明
	
	var tween = create_tween()
	tween.tween_property(transition_overlay, "color:a", 0.0, duration)
	
	# 如果提供了目标节点，同时淡出
	if control_node:
		tween.parallel().tween_property(control_node, "modulate:a", 0.0, duration)
	
	await tween.finished
	
	transition_overlay.visible = false
	if control_node:
		control_node.visible = false
	is_transitioning = false

## 立即设置为完全透明（用于场景加载后的初始化）
func set_transparent() -> void:
	_ensure_transition_layer()
	if transition_overlay:
		transition_overlay.color = Color(0, 0, 0, 0)
		transition_overlay.visible = false
		is_transitioning = false

## 立即设置为完全不透明（用于场景切换前的准备）
func set_opaque() -> void:
	_ensure_transition_layer()
	if transition_overlay:
		transition_overlay.color = Color(0, 0, 0, 1)
		transition_overlay.visible = true
		is_transitioning = true
