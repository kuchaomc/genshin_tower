extends Area2D
class_name NahidaBurstField

## 纳西妲Q「心景幻成」区域
## - 代码生成绿色领域（不依赖额外场景）
## - 对领域内敌人造成周期伤害
## - 对领域内敌人施加“抗性降低”（当前项目用 EnemyStats.defense_percent 作为伤害减免/抗性）

@export var owner_character: BaseCharacter = null
@export var damage_multiplier: float = 0.55
@export var duration: float = 5.0
@export var radius: float = 180.0
@export var tick_interval: float = 0.5

## 抗性降低（0~1）：例如 0.2 表示降低 20% 伤害减免/抗性
@export_range(0.0, 1.0) var resistance_reduction: float = 0.20

@export var field_fill_color: Color = Color(0.15, 1.0, 0.25, 0.22)
@export var field_ring_color: Color = Color(0.15, 1.0, 0.25, 0.55)
@export var field_ring_width: float = 3.0

@export var field_fade_in: float = 0.12
@export var field_fade_out: float = 0.12

var _enemies_by_id: Dictionary = {}
var _source_id: int = 0
var _tick_timer: Timer
var _end_tween: Tween
var _is_ending: bool = false

func _ready() -> void:
	_source_id = int(get_instance_id())

	# 约定：第2层=敌人(Enemies)
	collision_mask = 2
	monitoring = true
	monitorable = true

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = maxf(0.0, radius)
	shape.shape = circle
	add_child(shape)

	modulate = Color(1.0, 1.0, 1.0, 0.0)
	var fade_in: float = maxf(0.01, field_fade_in)
	var t_in := create_tween()
	t_in.tween_property(self, "modulate:a", 1.0, fade_in)

	_tick_timer = Timer.new()
	_tick_timer.one_shot = false
	_tick_timer.wait_time = maxf(0.05, tick_interval)
	_tick_timer.autostart = true
	_tick_timer.timeout.connect(_apply_tick)
	add_child(_tick_timer)

	_apply_tick()

	var end_timer := get_tree().create_timer(maxf(0.05, duration))
	end_timer.timeout.connect(_begin_end_field)

	queue_redraw()


func _draw() -> void:
	var r: float = maxf(0.0, radius)
	if r <= 0.0:
		return
	if field_fill_color.a > 0.0:
		draw_circle(Vector2.ZERO, r, field_fill_color)
	if field_ring_width > 0.0 and field_ring_color.a > 0.0:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, field_ring_color, maxf(1.0, field_ring_width), true)


func _update_inside_enemies() -> void:
	var r: float = maxf(0.0, radius)
	if r <= 0.0:
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		# 没敌人时也要清理已记录的目标，避免减抗残留
		for k in _enemies_by_id.keys():
			var old_obj: Variant = _enemies_by_id.get(k)
			if not is_instance_valid(old_obj):
				continue
			var old_enemy := old_obj as Node2D
			if old_enemy != null and old_enemy.has_method("remove_resistance_reduction"):
				old_enemy.call("remove_resistance_reduction", _source_id)
		_enemies_by_id.clear()
		return

	var inside: Dictionary = {}
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var enemy := e as Node2D
		if enemy == null:
			continue
		if (enemy.global_position - global_position).length() > r:
			continue
		var enemy_id: int = int(enemy.get_instance_id())
		inside[enemy_id] = enemy
		if not _enemies_by_id.has(enemy_id):
			if resistance_reduction > 0.0 and enemy.has_method("apply_resistance_reduction"):
				enemy.call("apply_resistance_reduction", _source_id, resistance_reduction)

	# 处理离开领域的敌人：移除减抗
	for k in _enemies_by_id.keys():
		if inside.has(k):
			continue
		var old_obj: Variant = _enemies_by_id.get(k)
		if not is_instance_valid(old_obj):
			continue
		var old_enemy := old_obj as Node2D
		if old_enemy != null and old_enemy.has_method("remove_resistance_reduction"):
			old_enemy.call("remove_resistance_reduction", _source_id)

	_enemies_by_id = inside


func _apply_tick() -> void:
	if not is_instance_valid(owner_character):
		return

	_update_inside_enemies()

	for k in _enemies_by_id.keys():
		var enemy_obj: Variant = _enemies_by_id.get(k)
		if not is_instance_valid(enemy_obj):
			continue
		var enemy := enemy_obj as Node2D
		if enemy == null:
			continue
		owner_character.deal_damage_to(enemy, damage_multiplier * owner_character.get_weapon_skill_burst_damage_multiplier(), false, false, false, false)



func _begin_end_field() -> void:
	if _is_ending:
		return
	_is_ending = true
	monitoring = false
	monitorable = false
	if is_instance_valid(_tick_timer):
		_tick_timer.stop()

	# 结束时兜底移除减抗
	for k in _enemies_by_id.keys():
		var enemy_obj: Variant = _enemies_by_id.get(k)
		if not is_instance_valid(enemy_obj):
			continue
		var enemy := enemy_obj as Node2D
		if enemy != null and enemy.has_method("remove_resistance_reduction"):
			enemy.call("remove_resistance_reduction", _source_id)
	_enemies_by_id.clear()

	var fade_out: float = maxf(0.01, field_fade_out)
	if is_instance_valid(_end_tween):
		_end_tween.kill()
	_end_tween = create_tween()
	_end_tween.tween_property(self, "modulate:a", 0.0, fade_out)
	_end_tween.tween_callback(queue_free)


func _end_field() -> void:
	# 结束时兜底移除减抗
	for k in _enemies_by_id.keys():
		var enemy_obj: Variant = _enemies_by_id.get(k)
		if not is_instance_valid(enemy_obj):
			continue
		var enemy := enemy_obj as Node2D
		if enemy != null and enemy.has_method("remove_resistance_reduction"):
			enemy.call("remove_resistance_reduction", _source_id)
	_enemies_by_id.clear()
	_begin_end_field()


func _exit_tree() -> void:
	# 防御性兜底：如果节点被提前移除，也要清理减抗
	for k in _enemies_by_id.keys():
		var enemy_obj: Variant = _enemies_by_id.get(k)
		if not is_instance_valid(enemy_obj):
			continue
		var enemy := enemy_obj as Node2D
		if enemy != null and enemy.has_method("remove_resistance_reduction"):
			enemy.call("remove_resistance_reduction", _source_id)
	_enemies_by_id.clear()
