extends Control
class_name SkillUI

## 技能UI组件
## 显示技能图标和冷却时间

@onready var icon_texture: TextureRect = $IconTexture
@onready var cooldown_overlay: ColorRect = $CooldownOverlay
@onready var cooldown_label: Label = $CooldownLabel

var skill_icon: Texture2D
var max_cooldown: float = 10.0
var current_cooldown: float = 0.0

## 是否启用“大招充能完成”粒子特效（仅对充能模式生效）
@export var enable_ready_particles: bool = true

var _ready_particles: GPUParticles2D
var _is_ready_particles_enabled: bool = false

var _global_ready_particles_enabled: bool = true

var _cooldown_radial_material: ShaderMaterial
var _did_preload_ready_effects: bool = false

func _ready() -> void:
	add_to_group("skill_ui")
	_global_ready_particles_enabled = _load_burst_ready_effect_enabled_from_settings()

	if icon_texture:
		if skill_icon:
			icon_texture.texture = skill_icon
		else:
			# 如果没有设置图标，尝试加载默认图标
			var default_icon: Texture2D = null
			if DataManager:
				default_icon = DataManager.get_texture("res://textures/icons/神里技能图标.png")
			else:
				default_icon = load("res://textures/icons/神里技能图标.png") as Texture2D
			if default_icon:
				icon_texture.texture = default_icon
	
	_ensure_cooldown_radial_material()
	_update_overlay_transform()
	if not resized.is_connected(_update_overlay_transform):
		resized.connect(_update_overlay_transform)
	if icon_texture and not icon_texture.resized.is_connected(_update_overlay_transform):
		icon_texture.resized.connect(_update_overlay_transform)
	
	_update_display()

## 设置技能图标
func set_skill_icon(texture: Texture2D) -> void:
	skill_icon = texture
	if icon_texture:
		icon_texture.texture = texture

## 更新冷却时间
func update_cooldown(remaining_time: float, cooldown_time: float) -> void:
	current_cooldown = remaining_time
	max_cooldown = cooldown_time
	_update_display()

## 更新充能进度（用于大招）
func update_energy(current_energy: float, max_energy: float) -> void:
	current_cooldown = max_energy - current_energy  # 反转：充能值越高，遮罩越小
	max_cooldown = max_energy
	_preload_ready_effects_if_needed()
	_update_display()

## 更新显示
func _update_display() -> void:
	if not cooldown_overlay or not cooldown_label:
		return
	
	# 仅在“充能模式”（大招）下允许触发粒子特效
	var is_energy_mode: bool = max_cooldown >= 100.0
	var is_energy_ready: bool = is_energy_mode and max_cooldown > 0.0 and current_cooldown <= 0.0
	
	if current_cooldown > 0.0 and max_cooldown > 0.0:
		# 显示冷却遮罩或充能遮罩
		var progress: float = clampf(current_cooldown / max_cooldown, 0.0, 1.0)
		cooldown_overlay.visible = true
		cooldown_overlay.color.a = 0.6  # 半透明遮罩
		_set_cooldown_overlay_progress(progress)
		
		# 更新冷却时间文本（如果是充能，显示充能百分比）
		cooldown_label.visible = true
		if max_cooldown >= 100.0:  # 充能系统（最大值通常是100）
			var energy = max_cooldown - current_cooldown
			var energy_percent = int((energy / max_cooldown) * 100)
			cooldown_label.text = str(energy_percent) + "%"
		else:
			cooldown_label.text = "%.1f" % current_cooldown
		
		_update_overlay_transform()
		
		# 降低图标透明度（如果未充能完成）
		if icon_texture:
			if max_cooldown >= 100.0 and current_cooldown <= 0.0:
				# 充能完成，图标高亮
				icon_texture.modulate.a = 1.0
			else:
				icon_texture.modulate.a = 0.5
		
		if is_energy_mode or _ready_particles:
			_set_ready_particles_enabled(false)
	else:
		# 技能可用或充能完成
		cooldown_overlay.visible = false
		cooldown_label.visible = false
		if icon_texture:
			icon_texture.modulate.a = 1.0
		
		if is_energy_mode or _ready_particles:
			_set_ready_particles_enabled(is_energy_ready)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_ready_particles_transform()
		_update_overlay_transform()


## 预创建大招“充能完成特效”所需资源，避免充能满时瞬间创建导致卡顿
func _preload_ready_effects_if_needed() -> void:
	if _did_preload_ready_effects:
		return
	if not enable_ready_particles:
		return
	# 仅对“充能模式”（大招）进行预加载
	if max_cooldown < 100.0:
		return
	if not icon_texture:
		return

	_did_preload_ready_effects = true
	_ensure_ready_particles()
	_update_ready_particles_transform()

	if not resized.is_connected(_update_ready_particles_transform):
		resized.connect(_update_ready_particles_transform)
	if not resized.is_connected(_update_overlay_transform):
		resized.connect(_update_overlay_transform)
	if icon_texture and not icon_texture.resized.is_connected(_update_ready_particles_transform):
		icon_texture.resized.connect(_update_ready_particles_transform)
	if icon_texture and not icon_texture.resized.is_connected(_update_overlay_transform):
		icon_texture.resized.connect(_update_overlay_transform)


## 确保“充能完成”粒子节点已创建
func _ensure_ready_particles() -> void:
	if _ready_particles:
		return
	if not icon_texture:
		return

	_ready_particles = GPUParticles2D.new()
	_ready_particles.name = "ReadyParticles"
	_ready_particles.visible = false
	_ready_particles.emitting = false
	_ready_particles.one_shot = false
	_ready_particles.amount = 72
	_ready_particles.lifetime = 1.2
	_ready_particles.explosiveness = 0.0
	_ready_particles.randomness = 0.35
	_ready_particles.z_index = 10
	_ready_particles.texture = _create_snowflake_texture(40)
	
	# 使用加法混合，让雪花更有“发光粒子”的感觉
	var canvas_mat := CanvasItemMaterial.new()
	canvas_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_ready_particles.material = canvas_mat

	var mat := ParticleProcessMaterial.new()
	# 从图标边缘环形发射，而不是从中心点
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	mat.emission_ring_height = 0.0
	mat.emission_ring_cone_angle = 90.0
	_update_ready_particles_emission_ring(mat)

	# 以 +X 为基准，180 度扩散等价于 360 度全方向
	mat.direction = Vector3(1.0, 0.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3(0.0, 0.0, 0.0)
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 90.0
	mat.damping_min = 1.0
	mat.damping_max = 4.0
	mat.scale_min = 0.25
	mat.scale_max = 0.65
	mat.color = Color(0.65, 0.9, 1.0, 1.0)
	mat.angle_min = 0.0
	mat.angle_max = 360.0
	mat.angular_velocity_min = -120.0
	mat.angular_velocity_max = 120.0

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.65, 0.9, 1.0, 1.0))
	gradient.set_color(1, Color(0.65, 0.9, 1.0, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	mat.color_ramp = ramp
	_ready_particles.process_material = mat

	icon_texture.add_child(_ready_particles)


## 根据当前 UI 尺寸更新粒子中心点
func _update_ready_particles_transform() -> void:
	if not _ready_particles or not icon_texture:
		return
	_ready_particles.position = icon_texture.size * 0.5
	var mat := _ready_particles.process_material as ParticleProcessMaterial
	if mat:
		_update_ready_particles_emission_ring(mat)


## 根据图标尺寸更新环形发射半径（从 UI 边缘一圈开始生成）
func _update_ready_particles_emission_ring(mat: ParticleProcessMaterial) -> void:
	if not icon_texture:
		return
	var radius: float = minf(icon_texture.size.x, icon_texture.size.y) * 0.48
	var inner_radius: float = radius - 4.0
	mat.emission_ring_radius = maxf(radius, 0.0)
	mat.emission_ring_inner_radius = maxf(inner_radius, 0.0)


## 开关粒子（仅在大招充能完成时开启，未完成时关闭）
func _set_ready_particles_enabled(enabled: bool) -> void:
	if not enable_ready_particles:
		return
	if not _global_ready_particles_enabled:
		enabled = false
	if enabled:
		_ensure_ready_particles()
		if not _ready_particles:
			return
	else:
		if not _ready_particles:
			return
	
	if _is_ready_particles_enabled == enabled:
		return
	_is_ready_particles_enabled = enabled

	_ready_particles.visible = enabled
	_ready_particles.emitting = enabled
	if enabled:
		_update_ready_particles_transform()
		_ready_particles.restart()
	else:
		# 关闭时清理状态，避免下次开启不触发
		_is_ready_particles_enabled = false


## 创建雪花纹理（用于粒子，避免新增贴图资源）
func _create_snowflake_texture(size_px: int) -> Texture2D:
	# 简化雪花：6 条主分支 + 两侧小分叉，做轻微柔化
	var img := Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 0.0))

	var center := Vector2((size_px - 1) * 0.5, (size_px - 1) * 0.5)
	var r_main := float(size_px) * 0.45
	var r_branch := float(size_px) * 0.18
	var thickness := 1.4

	for i in range(6):
		var a := TAU * float(i) / 6.0
		_draw_soft_line(img, center, center + Vector2(cos(a), sin(a)) * r_main, thickness)
		# 两侧分叉
		var branch_pos := center + Vector2(cos(a), sin(a)) * (r_main * 0.6)
		_draw_soft_line(img, branch_pos, branch_pos + Vector2(cos(a + 0.45), sin(a + 0.45)) * r_branch, thickness)
		_draw_soft_line(img, branch_pos, branch_pos + Vector2(cos(a - 0.45), sin(a - 0.45)) * r_branch, thickness)

	# 轻微径向柔化，避免锯齿
	for y in range(size_px):
		for x in range(size_px):
			var col := img.get_pixel(x, y)
			if col.a <= 0.0:
				continue
			var d := center.distance_to(Vector2(x, y))
			var fade: float = clampf(1.0 - (d / (r_main + 1.0)), 0.0, 1.0)
			col.a *= pow(fade, 0.8)
			img.set_pixel(x, y, col)

	return ImageTexture.create_from_image(img)


## 绘制带柔边的线段（用于程序化雪花纹理）
func _draw_soft_line(img: Image, from_pos: Vector2, to_pos: Vector2, thickness: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var dir := to_pos - from_pos
	var line_len := dir.length()
	if line_len <= 0.001:
		return
	var dir_n := dir / line_len
	var steps := int(ceil(line_len))
	for s in range(steps + 1):
		var p := from_pos + dir_n * float(s)
		for oy in range(-3, 4):
			for ox in range(-3, 4):
				var px := int(round(p.x)) + ox
				var py := int(round(p.y)) + oy
				if px < 0 or px >= w or py < 0 or py >= h:
					continue
				var d := Vector2(px, py).distance_to(p)
				var a: float = clampf(1.0 - (d / thickness), 0.0, 1.0)
				if a <= 0.0:
					continue
				var old := img.get_pixel(px, py)
				var new_a: float = clampf(old.a + a * 0.8, 0.0, 1.0)
				img.set_pixel(px, py, Color(1.0, 1.0, 1.0, new_a))


## 确保冷却遮罩为圆形径向遮罩
func _ensure_cooldown_radial_material() -> void:
	if _cooldown_radial_material:
		return
	if not cooldown_overlay:
		return

	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec4 overlay_color : source_color = vec4(0.0, 0.0, 0.0, 0.6);
uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float inner_radius : hint_range(0.0, 0.5) = 0.0;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float r = length(uv);
	if (r > 0.5 || r < inner_radius) {
		discard;
	}
	float ang = atan(uv.y, uv.x);
	// 从正上方开始，顺时针增加
	float ang_n = mod((ang + 1.57079632679) + 6.28318530718, 6.28318530718) / 6.28318530718;
	if (ang_n > fill) {
		discard;
	}
	COLOR = overlay_color;
}
"""

	_cooldown_radial_material = ShaderMaterial.new()
	_cooldown_radial_material.shader = shader
	cooldown_overlay.material = _cooldown_radial_material
	_set_cooldown_overlay_progress(1.0)


## 设置径向遮罩填充比例（表示剩余冷却/剩余充能）
func _set_cooldown_overlay_progress(progress: float) -> void:
	_ensure_cooldown_radial_material()
	if not _cooldown_radial_material:
		return
	_cooldown_radial_material.set_shader_parameter("fill", clampf(progress, 0.0, 1.0))
	_cooldown_radial_material.set_shader_parameter("inner_radius", 0.0)
	# 将 ColorRect 的颜色同步到 shader，避免 fragment 输出不确定
	_cooldown_radial_material.set_shader_parameter("overlay_color", cooldown_overlay.color)


## 同步遮罩尺寸，使其始终覆盖整个图标区域
func _update_overlay_transform() -> void:
	if not cooldown_overlay or not icon_texture:
		return
	cooldown_overlay.position = Vector2.ZERO
	cooldown_overlay.size = icon_texture.size


## 设置界面用于实时开关特效
func set_global_ready_particles_enabled(is_enabled: bool) -> void:
	_global_ready_particles_enabled = is_enabled
	_set_ready_particles_enabled(false)


func _load_burst_ready_effect_enabled_from_settings() -> bool:
	var config := ConfigFile.new()
	var err: Error = config.load("user://settings.cfg")
	if err != OK:
		return true
	return bool(config.get_value("ui", "burst_ready_effect_enabled", true))
