extends BaseCharacter
class_name NahidaCharacter

## 纳西妲：法器角色
## 设计目标（按你的需求分阶段落地）：
## 1) 普攻：向指定方向发射绿色大粒子，命中造成伤害
## 2) 重击：对离鼠标最近的敌人造成伤害，并扩散至附近敌人（默认3个）
## 3) E：短按环绕伤害；长按瞄准标记并延迟爆炸（后续完善）
## 4) Q：生成区域持续伤害并降低抗性（后续完善）

# ========== 普攻/重击 ==========
@export var normal_projectile_scene: PackedScene = preload("res://scenes/projectiles/nahida_normal_projectile.tscn")
@export var normal_attack_multiplier: float = 1.0
@export var normal_projectile_spawn_offset: Vector2 = Vector2(10.0, -10.0)
@export var normal_attack_interval: float = 0.5
var _normal_attack_next_ready_ms: int = 0

@export var charged_attack_multiplier: float = 1.15
@export var charged_splash_radius: float = 100.0
@export var charged_splash_damage_ratio: float = 0.5

@export_group("重击蓄力提示")
@export var charged_glow_color: Color = Color(0.15, 1.0, 0.25, 1.0)
@export var charged_glow_max_strength: float = 1.0
@export var charged_glow_size: float = 2.8
@export var charged_breathe_frequency: float = 2.2
@export var charged_ready_pulse_strength_mul: float = 1.25
@export var charged_weapon_shake_amplitude: float = 2.6
@export var charged_weapon_shake_frequency: float = 16.0
@export var charged_weapon_shake_ready_mul: float = 1.8
@export_group("")

@export_group("重击命中特效")
@export var charged_hit_effect_texture: Texture2D = preload("res://textures/characters/nahida/effects/技能.png")
@export var charged_hit_effect_scale: float = 1.2
@export var charged_hit_effect_alpha: float = 0.95
@export var charged_splash_effect_scale: float = 0.95
@export var charged_splash_effect_alpha: float = 0.45
@export var charged_effect_lifetime: float = 0.22
@export_group("")

enum AttackMode {
	NONE,
	NORMAL,
	CHARGED,
}
var _attack_mode: AttackMode = AttackMode.NONE

var _weapon_glow_shader: Shader
var _weapon_glow_material: ShaderMaterial
var _weapon_sprite_original_material: Material
var _charged_ready_last_frame: bool = false
var _charged_ready_pulse_tween: Tween
var _charged_ready_pulse_mul: float = 1.0
var _weapon_shake_last_offset: Vector2 = Vector2.ZERO

# ========== E技能（短按环绕，先做最小版） ==========
@export var skill_cooldown: float = 6.0
@export var skill_damage_multiplier: float = 1.2
@export var skill_duration: float = 3.0
@export var skill_radius: float = 90.0
## 同一敌人的受击冷却（去抖）：避免同一帧/短时间内重复触发；下一次再次进入时可再次受伤
@export var skill_tick_interval: float = 0.1
## 环绕圈数：总旋转角度 = TAU * 圈数；圈数越少环绕越慢（在持续时间不变的情况下）
@export var skill_orbit_rotations: float = 2.0

## 场景预置节点（按绫华逻辑：尽量不在代码里 new 节点）
@export var skill_orbit_pivot: Node2D
@export var skill_area: Area2D

var skill_next_ready_ms: int = 0
## Key: enemy instance_id (int) -> Value: 下次允许结算伤害的时间戳(ms)
var _skill_next_hit_ms_by_enemy_id: Dictionary = {}
var _skill_orbit_tween: Tween = null

signal skill_cooldown_changed(remaining_time: float, cooldown_time: float)

# ========== Q大招（先做最小版：区域持续伤害） ==========
@export var burst_max_energy: float = 100.0
@export var burst_damage_multiplier: float = 0.55
@export var burst_duration: float = 5.0
@export var burst_radius: float = 180.0
@export var burst_tick_interval: float = 0.5
@export var energy_per_hit: float = 10.0

var burst_current_energy: float = 0.0

signal burst_energy_changed(current_energy: float, max_energy: float)
signal burst_used(character_id: String)

var _last_e_pressed: bool = false
var _last_q_pressed: bool = false

func _ready() -> void:
	super._ready()
	_ensure_weapon_glow_material()
	_initialize_skill_nodes()
	_update_burst_energy_display()
	_update_skill_cooldown_display()


func _initialize_skill_nodes() -> void:
	# 对齐绫华：如果没在面板绑定，自动按节点名查找
	if skill_orbit_pivot == null:
		skill_orbit_pivot = get_node_or_null("SkillOrbitPivot") as Node2D
	if skill_area == null and is_instance_valid(skill_orbit_pivot):
		skill_area = skill_orbit_pivot.get_node_or_null("SkillArea") as Area2D
	elif skill_area == null:
		skill_area = get_node_or_null("SkillOrbitPivot/SkillArea") as Area2D

	if is_instance_valid(skill_orbit_pivot):
		skill_orbit_pivot.visible = false
		skill_orbit_pivot.rotation = 0.0

	if is_instance_valid(skill_area):
		# 约定：第2层=敌人(Enemies)。技能范围 Area2D 只需要检测敌人层即可。
		skill_area.collision_mask = 2
		if not skill_area.area_entered.is_connected(_on_skill_area_entered):
			skill_area.area_entered.connect(_on_skill_area_entered)
		if not skill_area.body_entered.is_connected(_on_skill_body_entered):
			skill_area.body_entered.connect(_on_skill_body_entered)
		skill_area.monitoring = false
		skill_area.monitorable = false


func _physics_process(delta: float) -> void:
	# WeaponSprite 由 BaseCharacter 统一跟随更新；这里先移除上一帧抖动偏移，避免累积导致漂移。
	if is_instance_valid(_weapon_sprite) and _weapon_shake_last_offset != Vector2.ZERO:
		_weapon_sprite.global_position -= _weapon_shake_last_offset
		_weapon_shake_last_offset = Vector2.ZERO

	if not is_game_over:
		_handle_skill_input()
		_handle_burst_input()
		_update_skill_cooldown_display()
		_update_burst_energy_display()
	super._physics_process(delta)
	if not is_game_over:
		_update_charged_charge_indicator()


# =============================
# 普攻 / 重击
# =============================

func _start_normal_attack() -> void:
	# 普攻节流：固定 0.5s 一次（只影响纳西妲）
	if Time.get_ticks_msec() < _normal_attack_next_ready_ms:
		_attack_mode = AttackMode.NONE
		return
	_normal_attack_next_ready_ms = Time.get_ticks_msec() + int(normal_attack_interval * 1000.0)

	_reset_charged_charge_visuals()
	_attack_mode = AttackMode.NORMAL
	_change_state(CharacterState.ATTACKING)


func _start_charged_attack() -> void:
	_reset_charged_charge_visuals()
	_attack_mode = AttackMode.CHARGED
	_change_state(CharacterState.ATTACKING)


func perform_attack() -> void:
	match _attack_mode:
		AttackMode.NORMAL:
			_perform_normal_attack()
		AttackMode.CHARGED:
			_perform_charged_attack()
			# 默认兜底：避免卡死在 ATTACKING
		_:
			finish_attack()


func _perform_normal_attack() -> void:
	# 普攻：向鼠标方向发射一个“绿色大粒子”
	if normal_projectile_scene == null:
		finish_attack()
		return

	var mouse_pos := get_global_mouse_position()
	var dir := (mouse_pos - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = _last_nonzero_move_dir

	var inst := normal_projectile_scene.instantiate() as Area2D
	if inst == null:
		finish_attack()
		return

	inst.global_position = global_position + normal_projectile_spawn_offset
	inst.set("direction", dir)
	inst.set("owner_character", self)
	inst.set("damage_multiplier", normal_attack_multiplier)

	var p := get_parent()
	if p:
		p.add_child(inst)
	else:
		get_tree().root.add_child(inst)

	finish_attack()


func _perform_charged_attack() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		finish_attack()
		return

	var mouse_pos := get_global_mouse_position()
	var primary: Node2D = null
	var best_d := INF
	for e in enemies:
		var n := e as Node2D
		if n == null:
			continue
		var d := (n.global_position - mouse_pos).length()
		if d < best_d:
			best_d = d
			primary = n

	if primary == null:
		finish_attack()
		return

	deal_damage_to(primary, charged_attack_multiplier, false, false, false, true)
	_add_burst_energy(energy_per_hit * get_energy_gain_multiplier())
	_spawn_charged_hit_effect(primary.global_position, true)

	var r: float = maxf(0.0, charged_splash_radius)
	var ratio: float = clampf(charged_splash_damage_ratio, 0.0, 1.0)
	if r > 0.0 and ratio > 0.0:
		for e in enemies:
			var n := e as Node2D
			if n == null:
				continue
			if n == primary:
				continue
			if (n.global_position - primary.global_position).length() > r:
				continue
			deal_damage_to(n, charged_attack_multiplier * ratio, false, false, false, true)
			_add_burst_energy(energy_per_hit * get_energy_gain_multiplier())
			_spawn_charged_hit_effect(n.global_position, false)

	finish_attack()


func _spawn_charged_hit_effect(world_pos: Vector2, is_primary: bool) -> void:
	if charged_hit_effect_texture == null:
		return

	var spr := Sprite2D.new()
	spr.texture = charged_hit_effect_texture
	spr.top_level = true
	spr.z_as_relative = false
	spr.z_index = 80
	spr.global_position = world_pos

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	spr.material = mat

	var a: float = charged_hit_effect_alpha if is_primary else charged_splash_effect_alpha
	var s: float = charged_hit_effect_scale if is_primary else charged_splash_effect_scale
	spr.modulate = Color(0.15, 1.0, 0.25, clampf(a, 0.0, 1.0))
	spr.scale = Vector2.ONE * maxf(0.01, s)
	spr.rotation = randf() * TAU

	var p := get_parent()
	if p:
		p.add_child(spr)
	else:
		get_tree().root.add_child(spr)

	var life: float = maxf(0.01, charged_effect_lifetime)
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_SINE)
	t.tween_property(spr, "modulate:a", 0.0, life)
	t.parallel().tween_property(spr, "scale", spr.scale * 1.15, life)
	t.tween_callback(spr.queue_free)


func _ensure_weapon_glow_material() -> void:
	if not is_instance_valid(_weapon_sprite):
		return
	if _weapon_sprite_original_material == null:
		_weapon_sprite_original_material = _weapon_sprite.material
	if not is_instance_valid(_weapon_glow_shader):
		_weapon_glow_shader = Shader.new()
		_weapon_glow_shader.code = """shader_type canvas_item;
uniform vec4 glow_color : source_color = vec4(0.15, 1.0, 0.25, 1.0);
uniform float glow_strength = 0.0;
uniform float glow_size = 2.8;
void fragment(){
	vec4 tex = texture(TEXTURE, UV);
	float a = tex.a;
	vec2 px = TEXTURE_PIXEL_SIZE * glow_size;
	float g = 0.0;
	g = max(g, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	g = max(g, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
	g = max(g, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	g = max(g, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
	g = max(g, texture(TEXTURE, UV + vec2(px.x, px.y)).a);
	g = max(g, texture(TEXTURE, UV + vec2(-px.x, px.y)).a);
	g = max(g, texture(TEXTURE, UV + vec2(px.x, -px.y)).a);
	g = max(g, texture(TEXTURE, UV + vec2(-px.x, -px.y)).a);
	float outline = max(0.0, g - a);
	vec3 add = glow_color.rgb * (outline + a) * glow_strength * glow_color.a;
	COLOR = tex;
	COLOR.rgb += add;
}
"""
	if not is_instance_valid(_weapon_glow_material):
		_weapon_glow_material = ShaderMaterial.new()
		_weapon_glow_material.shader = _weapon_glow_shader

	_weapon_glow_material.set_shader_parameter("glow_color", charged_glow_color)
	_weapon_glow_material.set_shader_parameter("glow_strength", 0.0)
	_weapon_glow_material.set_shader_parameter("glow_size", maxf(0.0, charged_glow_size))


func _reset_charged_charge_visuals() -> void:
	_charged_ready_last_frame = false
	_charged_ready_pulse_mul = 1.0
	if is_instance_valid(_charged_ready_pulse_tween):
		_charged_ready_pulse_tween.kill()
		_charged_ready_pulse_tween = null
	if is_instance_valid(_weapon_sprite) and _weapon_shake_last_offset != Vector2.ZERO:
		_weapon_sprite.global_position -= _weapon_shake_last_offset
		_weapon_shake_last_offset = Vector2.ZERO
	if is_instance_valid(_weapon_sprite):
		if _weapon_sprite.material == _weapon_glow_material and _weapon_sprite_original_material != null:
			_weapon_sprite.material = _weapon_sprite_original_material
		if is_instance_valid(_weapon_glow_material):
			_weapon_glow_material.set_shader_parameter("glow_strength", 0.0)


func _update_charged_charge_indicator() -> void:
	if not is_instance_valid(_weapon_sprite):
		return
	_ensure_weapon_glow_material()
	if get_tree().paused:
		return

	if _attack_button_pressed and not is_attacking():
		var hold_duration := get_attack_hold_duration()
		var time_sec: float = float(Time.get_ticks_msec()) / 1000.0
		var progress: float = clampf(hold_duration / charged_attack_threshold, 0.0, 1.0)
		var strength: float = progress * progress * (3.0 - 2.0 * progress)

		if is_instance_valid(_weapon_glow_material):
			if _weapon_sprite.material != _weapon_glow_material:
				_weapon_sprite.material = _weapon_glow_material
			_weapon_glow_material.set_shader_parameter("glow_color", charged_glow_color)
			_weapon_glow_material.set_shader_parameter("glow_size", maxf(0.0, charged_glow_size))
			var pulse: float = 0.5 + 0.5 * sin(time_sec * charged_breathe_frequency * TAU)
			var base_strength: float = charged_glow_max_strength * (0.10 + 0.90 * strength) * (0.55 + 0.45 * pulse)
			_weapon_glow_material.set_shader_parameter("glow_strength", clampf(base_strength * _charged_ready_pulse_mul, 0.0, 2.0))

		var is_ready: bool = hold_duration >= charged_attack_threshold
		if is_ready and not _charged_ready_last_frame:
			if is_instance_valid(_charged_ready_pulse_tween):
				_charged_ready_pulse_tween.kill()
			_charged_ready_pulse_tween = create_tween()
			_charged_ready_pulse_tween.set_trans(Tween.TRANS_QUAD)
			_charged_ready_pulse_tween.set_ease(Tween.EASE_OUT)
			_charged_ready_pulse_mul = 1.0
			_charged_ready_pulse_tween.tween_property(self, "_charged_ready_pulse_mul", charged_ready_pulse_strength_mul, 0.10)
			_charged_ready_pulse_tween.tween_property(self, "_charged_ready_pulse_mul", 1.0, 0.12)
		_charged_ready_last_frame = is_ready

		if is_instance_valid(_weapon_sprite):
			var ready_mul: float = charged_weapon_shake_ready_mul if is_ready else 1.0
			var amp: float = maxf(0.0, charged_weapon_shake_amplitude) * strength * ready_mul
			var freq: float = maxf(0.0, charged_weapon_shake_frequency)
			var sx: float = sin(time_sec * freq * TAU)
			var sy: float = cos(time_sec * (freq * 0.93) * TAU)
			var offset := Vector2(sx, sy) * amp
			_weapon_sprite.global_position += offset
			_weapon_shake_last_offset = offset
	else:
		_reset_charged_charge_visuals()


# =============================
# E 技能（短按环绕）
# =============================

func _handle_skill_input() -> void:
	var e_pressed := Input.is_physical_key_pressed(KEY_E)
	if (Input.is_action_just_pressed("ui_select") or (e_pressed and not _last_e_pressed)):
		if _is_skill_ready() and can_move():
			_use_skill_short_press()
	_last_e_pressed = e_pressed


func _is_skill_ready() -> bool:
	return Time.get_ticks_msec() >= skill_next_ready_ms


func _use_skill_short_press() -> void:
	# 播放技能语音
	if BGMManager and character_data and not character_data.id.is_empty():
		BGMManager.play_character_voice(character_data.id, "技能", 0.0, 0.2)

	var actual_cd := skill_cooldown * get_skill_cooldown_multiplier()
	skill_next_ready_ms = Time.get_ticks_msec() + int(actual_cd * 1000.0)
	_skill_next_hit_ms_by_enemy_id.clear()

	# 场景预置环绕：旋转 pivot，让 SkillArea 在外圈绕行
	if not is_instance_valid(skill_orbit_pivot) or not is_instance_valid(skill_area):
		return

	skill_orbit_pivot.global_position = global_position
	skill_orbit_pivot.rotation = 0.0
	skill_orbit_pivot.visible = true

	skill_area.monitoring = true
	skill_area.monitorable = true
	skill_area.visible = true

	# 旋转 pivot（外圈绕行的关键：SkillArea 在 pivot 下有 position 偏移）
	if is_instance_valid(_skill_orbit_tween):
		_skill_orbit_tween.kill()
	_skill_orbit_tween = create_tween()
	_skill_orbit_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_skill_orbit_tween.tween_property(skill_orbit_pivot, "rotation", TAU * skill_orbit_rotations, skill_duration)

	var timer := get_tree().create_timer(skill_duration)
	timer.timeout.connect(_end_skill_short_press)


func _end_skill_short_press() -> void:
	if is_instance_valid(_skill_orbit_tween):
		_skill_orbit_tween.kill()
		_skill_orbit_tween = null
	_skill_next_hit_ms_by_enemy_id.clear()

	if is_instance_valid(skill_area):
		skill_area.monitoring = false
		skill_area.monitorable = false
		skill_area.visible = false
	if is_instance_valid(skill_orbit_pivot):
		skill_orbit_pivot.visible = false


func _on_skill_area_entered(area: Area2D) -> void:
	_handle_skill_hit(area)


func _on_skill_body_entered(body: Node2D) -> void:
	_handle_skill_hit(body)


func _handle_skill_hit(target: Node2D) -> void:
	_try_skill_damage(target)


func _try_skill_damage(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	if not target.is_in_group("enemies"):
		return

	var now_ms := Time.get_ticks_msec()
	var enemy_id := int(target.get_instance_id())
	var next_ms := int(_skill_next_hit_ms_by_enemy_id.get(enemy_id, 0))
	if now_ms < next_ms:
		return

	_skill_next_hit_ms_by_enemy_id[enemy_id] = now_ms + int(maxf(0.02, skill_tick_interval) * 1000.0)
	deal_damage_to(target, skill_damage_multiplier * get_weapon_skill_burst_damage_multiplier(), false, false, false, true)
	_add_burst_energy(energy_per_hit * get_energy_gain_multiplier())


func _update_skill_cooldown_display() -> void:
	var now_ms := Time.get_ticks_msec()
	if now_ms < skill_next_ready_ms:
		var remaining := (skill_next_ready_ms - now_ms) / 1000.0
		emit_signal("skill_cooldown_changed", remaining, skill_cooldown)
	else:
		emit_signal("skill_cooldown_changed", 0.0, skill_cooldown)


# =============================
# Q 大招（最小版：区域持续伤害）
# =============================

func _handle_burst_input() -> void:
	var q_pressed := Input.is_physical_key_pressed(KEY_Q)
	if q_pressed and not _last_q_pressed:
		if _is_burst_ready() and can_move():
			_use_burst()
	_last_q_pressed = q_pressed


func _is_burst_ready() -> bool:
	return burst_current_energy >= burst_max_energy


func _use_burst() -> void:
	if not _is_burst_ready():
		return

	# 播放大招语音
	if BGMManager and character_data and not character_data.id.is_empty():
		BGMManager.play_character_voice(character_data.id, "大招", 0.0, 0.2)

	burst_current_energy = 0.0
	_update_burst_energy_display()
	if character_data and not character_data.id.is_empty():
		emit_signal("burst_used", character_data.id)

	var burst_area := Area2D.new()
	burst_area.name = "NahidaBurstArea"
	burst_area.collision_mask = 2
	burst_area.monitoring = true
	burst_area.monitorable = true
	burst_area.global_position = global_position
	get_parent().add_child(burst_area)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = burst_radius
	shape.shape = circle
	burst_area.add_child(shape)

	# 视觉：用半透明绿色圆形（先用技能图标放大占位）
	var spr := Sprite2D.new()
	spr.texture = preload("res://textures/characters/nahida/effects/技能.png")
	spr.modulate = Color(0.25, 1.0, 0.35, 0.35)
	spr.scale = Vector2(4.0, 4.0)
	burst_area.add_child(spr)

	var tick_count := int(ceil(burst_duration / maxf(0.05, burst_tick_interval)))
	for i in range(tick_count):
		var t := get_tree().create_timer(float(i) * burst_tick_interval)
		t.timeout.connect(func() -> void:
			if not is_instance_valid(burst_area):
				return
			_apply_burst_tick(burst_area)
		)

	var end_timer := get_tree().create_timer(burst_duration)
	end_timer.timeout.connect(func() -> void:
		if is_instance_valid(burst_area):
			burst_area.queue_free()
	)


func _apply_burst_tick(area: Area2D) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	var center := area.global_position
	for e in enemies:
		var n := e as Node2D
		if n == null:
			continue
		if (n.global_position - center).length() > burst_radius:
			continue
		deal_damage_to(n, burst_damage_multiplier * get_weapon_skill_burst_damage_multiplier(), false, false, false, false)


func _add_burst_energy(amount: float) -> void:
	if amount <= 0.0:
		return
	if burst_current_energy < burst_max_energy:
		burst_current_energy = min(burst_current_energy + amount, burst_max_energy)
		_update_burst_energy_display()


func _update_burst_energy_display() -> void:
	emit_signal("burst_energy_changed", burst_current_energy, burst_max_energy)
