extends Node2D
class_name MovementTrail

@export var max_points: int = 18
@export var min_distance: float = 4.0

@export var max_insert_points_per_frame: int = 3

@export var idle_clear_delay: float = 0.18

@export var min_width: float = 2.0
@export var max_width: float = 8.0

@export var speed_for_max_strength: float = 220.0
@export var fade_speed: float = 10.0

@export var tint: Color = Color(0.75, 0.92, 1.0, 0.9)
@export var tail_power: float = 1.6
@export var z: int = 40

const _TRAIL_SHADER: Shader = preload("res://shaders/movement_trail.gdshader")

var _line: Line2D
var _last_pos: Vector2
var _strength: float = 0.0
var _idle_time: float = 0.0

func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	_last_pos = Vector2(INF, INF)
	_setup_line()

func reset(world_pos: Vector2) -> void:
	_last_pos = Vector2(INF, INF)
	_idle_time = 0.0
	_line.clear_points()
	_update_shader_params()
	_sample(world_pos, true)
	_sample(world_pos, true)

func update_trail(world_pos: Vector2, speed: float, delta: float) -> void:
	var target_strength := 0.0
	if speed_for_max_strength > 0.0:
		target_strength = clamp(speed / speed_for_max_strength, 0.0, 1.0)

	if speed <= 0.1:
		_idle_time += delta
	else:
		_idle_time = 0.0

	_strength = move_toward(_strength, target_strength, delta * fade_speed)

	_line.width = lerp(min_width, max_width, _strength)
	_update_shader_params()

	if _strength <= 0.01:
		if _idle_time >= idle_clear_delay and _line.get_point_count() > 0:
			_line.clear_points()
		return

	_sample(world_pos, false)

func _setup_line() -> void:
	_line = Line2D.new()
	_line.width = min_width
	_line.antialiased = true
	_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_line.z_index = z
	_line.z_as_relative = false
	_line.round_precision = 6

	var mat := ShaderMaterial.new()
	mat.shader = _TRAIL_SHADER
	_line.material = mat

	add_child(_line)

func _update_shader_params() -> void:
	var mat := _line.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("strength", _strength)
	mat.set_shader_parameter("tail_power", tail_power)

func _sample(world_pos: Vector2, force: bool) -> void:
	if not force and _last_pos.is_finite():
		var dist := world_pos.distance_to(_last_pos)
		if dist < min_distance:
			return

		var steps := 1
		if max_insert_points_per_frame > 0 and min_distance > 0.0:
			steps = int(floor(dist / min_distance))
			steps = clamp(steps, 1, max_insert_points_per_frame)
		for i in range(1, steps + 1):
			_line.add_point(_last_pos.lerp(world_pos, float(i) / float(steps)))
		_last_pos = world_pos
	else:
		_last_pos = world_pos
		_line.add_point(world_pos)
	while _line.get_point_count() > max_points:
		_line.remove_point(0)
