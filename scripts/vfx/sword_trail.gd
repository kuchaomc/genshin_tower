extends Node2D
class_name SwordTrail

## 简易“刀光/剑轨”：
## - 采样目标（剑尖）的世界坐标
## - 用 Line2D 连接成一段短轨迹
## - 停止后快速淡出并自动销毁

@export var max_points: int = 12
@export var min_distance: float = 6.0
@export var width: float = 16.0
@export var fade_time: float = 0.12
@export var start_color: Color = Color(0.75, 0.92, 1.0, 0.9)
@export var end_color: Color = Color(0.75, 0.92, 1.0, 0.0)
@export var z: int = 50

var target: Node2D

var _line: Line2D
var _last_pos: Vector2
var _stopping: bool = false

func _ready() -> void:
	top_level = true # 让 Line2D 的点可以直接使用世界坐标
	global_position = Vector2.ZERO
	_last_pos = Vector2(INF, INF)
	_setup_line()

func setup(p_target: Node2D) -> void:
	target = p_target
	if is_instance_valid(target):
		_sample(target.global_position, true)
		_sample(target.global_position, true)

func stop() -> void:
	if _stopping:
		return
	_stopping = true
	set_physics_process(false)
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "modulate:a", 0.0, fade_time)
	t.tween_callback(queue_free)

func _physics_process(_delta: float) -> void:
	if _stopping:
		return
	if not is_instance_valid(target):
		stop()
		return
	_sample(target.global_position, false)

func _setup_line() -> void:
	_line = Line2D.new()
	_line.width = width
	_line.antialiased = true
	_line.z_index = z
	_line.z_as_relative = false
	_line.round_precision = 6

	var grad := Gradient.new()
	grad.colors = PackedColorArray([start_color, end_color])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	_line.gradient = grad

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_line.material = mat

	add_child(_line)

func _sample(world_pos: Vector2, force: bool) -> void:
	if not force and _last_pos.is_finite():
		if world_pos.distance_to(_last_pos) < min_distance:
			return
	_last_pos = world_pos
	_line.add_point(world_pos)
	while _line.get_point_count() > max_points:
		_line.remove_point(0)
