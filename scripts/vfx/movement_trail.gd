extends Node2D
class_name MovementTrail

@export var max_points: int = 18
@export var min_distance: float = 4.0

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

func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	_last_pos = Vector2(INF, INF)
	_setup_line()

func reset(world_pos: Vector2) -> void:
	_last_pos = Vector2(INF, INF)
	_line.clear_points()
	_update_shader_params()
	_sample(world_pos, true)
	_sample(world_pos, true)

func update_trail(world_pos: Vector2, speed: float, delta: float) -> void:
	var target_strength := 0.0
	if speed_for_max_strength > 0.0:
		target_strength = clamp(speed / speed_for_max_strength, 0.0, 1.0)

	_strength = move_toward(_strength, target_strength, delta * fade_speed)

	_line.width = lerp(min_width, max_width, _strength)
	_update_shader_params()

	if _strength <= 0.01:
		if _line.get_point_count() > 0:
			_line.clear_points()
		return

	_sample(world_pos, false)

func _setup_line() -> void:
	_line = Line2D.new()
	_line.width = min_width
	_line.antialiased = true
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
		if world_pos.distance_to(_last_pos) < min_distance:
			return

	_last_pos = world_pos
	_line.add_point(world_pos)
	while _line.get_point_count() > max_points:
		_line.remove_point(0)
