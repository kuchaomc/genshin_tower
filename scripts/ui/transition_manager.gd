extends Node

## 转场管理器
## 负责场景切换时的转场动画效果

signal transition_finished

# 转场遮罩层（动态创建）
var transition_overlay: ColorRect
var transition_layer: CanvasLayer
# BackBufferCopy（用于屏幕纹理采样）
var _back_buffer_copy: BackBufferCopy
# 是否正在转场
var is_transitioning: bool = false

# Iris（向中心汇聚）转场材质（懒加载）
var _iris_material: ShaderMaterial

func _ready() -> void:
	print("转场管理器已初始化")

## 确保转场层存在
func _ensure_transition_layer() -> void:
	if not transition_layer:
		transition_layer = CanvasLayer.new()
		transition_layer.layer = 100  # 设置高层级，确保在最上层
		add_child(transition_layer)
	
	if transition_layer and not _back_buffer_copy:
		_back_buffer_copy = BackBufferCopy.new()
		_back_buffer_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		transition_layer.add_child(_back_buffer_copy)
	
	if not transition_overlay:
		transition_overlay = ColorRect.new()
		transition_overlay.color = Color(0, 0, 0, 0)  # 初始透明
		transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		transition_overlay.visible = false
		transition_layer.add_child(transition_overlay)


## 确保 Iris 材质存在（黑色从四周向中心收缩）
func _ensure_iris_material() -> void:
	if _iris_material:
		return
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture;

uniform float radius : hint_range(0.0, 2.0) = 1.2;
uniform float softness : hint_range(0.0, 0.2) = 0.02;
uniform vec2 center = vec2(0.5, 0.5);
uniform float blur_radius : hint_range(0.0, 8.0) = 3.0;

vec4 sample_blur(vec2 uv) {
	vec2 tex_size = vec2(textureSize(screen_texture, 0));
	vec2 px = vec2(blur_radius) / max(tex_size, vec2(1.0));
	// blur_radius 很小时直接返回原图，避免首帧亮度突变
	if (blur_radius <= 0.001) {
		return texture(screen_texture, uv);
	}
	// 9-tap 简易模糊（权重总和=1.0）
	vec4 c = texture(screen_texture, uv) * 0.20;
	c += texture(screen_texture, uv + vec2(px.x, 0.0)) * 0.15;
	c += texture(screen_texture, uv - vec2(px.x, 0.0)) * 0.15;
	c += texture(screen_texture, uv + vec2(0.0, px.y)) * 0.15;
	c += texture(screen_texture, uv - vec2(0.0, px.y)) * 0.15;
	c += texture(screen_texture, uv + vec2(px.x, px.y)) * 0.10;
	c += texture(screen_texture, uv + vec2(-px.x, px.y)) * 0.10;
	c += texture(screen_texture, uv + vec2(px.x, -px.y)) * 0.10;
	c += texture(screen_texture, uv + vec2(-px.x, -px.y)) * 0.10;
	return c;
}

void fragment() {
	float d = distance(UV, center);
	// alpha: 圆外为1（黑色不透明），圆内为0（透明），边缘做一点柔化
	float a = smoothstep(radius - softness, radius, d);
	vec4 blur_c = sample_blur(SCREEN_UV);
	vec4 black_c = vec4(0.0, 0.0, 0.0, 1.0);
	COLOR = mix(blur_c, black_c, a);
}
"""
	_iris_material = ShaderMaterial.new()
	_iris_material.shader = shader

## 播放淡出动画（场景切换前）
func fade_out(duration: float = 2.0) -> void:
	if is_transitioning:
		return
	
	_ensure_transition_layer()
	is_transitioning = true
	transition_overlay.visible = true
	transition_overlay.material = null
	transition_overlay.color = Color(0, 0, 0, 0)
	
	var tween = create_tween()
	tween.tween_property(transition_overlay, "color:a", 1.0, duration)
	await tween.finished
	
	emit_signal("transition_finished")


## Iris Close：黑色出现并向中心汇聚（死亡用）
## 动画结束后保持为黑屏（is_transitioning=true），由目标场景自行 fade_in 撤黑。
func iris_close_to_center(duration: float = 2.0) -> void:
	if is_transitioning:
		return
	_ensure_transition_layer()
	_ensure_iris_material()
	is_transitioning = true
	transition_overlay.visible = true
	transition_overlay.color = Color(0, 0, 0, 1)
	transition_overlay.material = _iris_material
	# 半径足够大时相当于完全透明；收缩到 0 即全黑
	_iris_material.set_shader_parameter("radius", 1.2)
	_iris_material.set_shader_parameter("softness", 0.02)
	_iris_material.set_shader_parameter("center", Vector2(0.5, 0.5))
	_iris_material.set_shader_parameter("blur_radius", 0.0)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	# 同时做“收缩变黑”和“模糊”，避免先模糊一段时间才开始黑屏
	tween.tween_property(_iris_material, "shader_parameter/radius", 0.0, duration)
	tween.parallel().tween_property(_iris_material, "shader_parameter/blur_radius", 3.0, duration)
	await tween.finished
	emit_signal("transition_finished")

## 播放淡入动画（场景加载后）
func fade_in(duration: float = 2.0) -> void:
	_ensure_transition_layer()
	
	if not transition_overlay:
		return
	
	transition_overlay.visible = true
	transition_overlay.material = null
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
	transition_overlay.material = null
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
		transition_overlay.material = null
		transition_overlay.color = Color(0, 0, 0, 0)
		transition_overlay.visible = false
		is_transitioning = false

## 立即设置为完全不透明（用于场景切换前的准备）
func set_opaque() -> void:
	_ensure_transition_layer()
	if transition_overlay:
		transition_overlay.material = null
		transition_overlay.color = Color(0, 0, 0, 1)
		transition_overlay.visible = true
		is_transitioning = true
