extends Node2D
class_name DamageNumber

## 伤害飘字组件
## 显示伤害数字，支持普通伤害和暴击伤害的不同样式

@onready var label: Label = get_node_or_null("Label")

# 飘字参数
@export var float_distance: float = 50.0  # 飘字移动距离
@export var float_duration: float = 1.0   # 飘字持续时间
@export var fade_start_time: float = 0.5  # 开始淡出的时间

# 颜色配置
var normal_color: Color = Color.WHITE      # 普通伤害颜色
var crit_color: Color = Color.YELLOW       # 暴击伤害颜色
var heal_color: Color = Color.GREEN       # 治疗颜色

# 字体大小配置
var normal_font_size: int = 24
var crit_font_size: int = 32

var damage_value: float = 0.0
var is_crit: bool = false
var is_heal: bool = false

var _rng: RandomNumberGenerator

func _ready() -> void:
	# 如果没有label节点，创建一个
	if not label:
		label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(label)

	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	
	# 设置初始状态
	label.text = ""
	label.modulate.a = 0.0

## 显示伤害数字
## position: 显示位置（世界坐标）
## damage: 伤害值
## is_critical: 是否暴击
func show_damage(position: Vector2, damage: float, is_critical: bool = false) -> void:
	damage_value = damage
	is_crit = is_critical
	is_heal = false
	
	# 设置位置
	global_position = position
	
	# 设置文本
	label.text = str(int(damage))
	
	# 设置样式
	if is_crit:
		label.add_theme_font_size_override("font_size", crit_font_size)
		label.modulate = crit_color
	else:
		label.add_theme_font_size_override("font_size", normal_font_size)
		label.modulate = normal_color
	
	# 播放动画
	_play_float_animation()

## 显示治疗数字
## position: 显示位置（世界坐标）
## heal_amount: 治疗量
func show_heal(position: Vector2, heal_amount: float) -> void:
	damage_value = heal_amount
	is_crit = false
	is_heal = true
	
	# 设置位置
	global_position = position
	
	# 设置文本（治疗显示+号）
	label.text = "+" + str(int(heal_amount))
	
	# 设置样式
	label.add_theme_font_size_override("font_size", normal_font_size)
	label.modulate = heal_color
	
	# 播放动画
	_play_float_animation()

## 播放飘字动画
func _play_float_animation() -> void:
	# 随机水平偏移，避免多个飘字重叠
	var random_offset_x: float = _rng.randf_range(-20.0, 20.0)
	var start_pos = global_position
	var end_pos = start_pos + Vector2(random_offset_x, -float_distance)
	
	# 初始状态：完全透明，稍微放大
	label.modulate.a = 0.0
	label.scale = Vector2(0.5, 0.5)
	
	# 创建补间动画
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 淡入动画（快速出现）
	tween.tween_property(label, "modulate:a", 1.0, 0.1)
	
	# 缩放动画（弹跳效果）
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2).set_delay(0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	
	# 位置动画（向上飘）
	tween.tween_property(self, "global_position", end_pos, float_duration).set_ease(Tween.EASE_OUT)
	
	# 淡出动画（后半段开始淡出）
	tween.tween_property(label, "modulate:a", 0.0, float_duration - fade_start_time).set_delay(fade_start_time)
	
	# 动画结束后回收（对象池）
	tween.tween_callback(_recycle_self).set_delay(float_duration)

func _recycle_self() -> void:
	if DamageNumberManager and DamageNumberManager.has_method("recycle_damage_number"):
		DamageNumberManager.call("recycle_damage_number", self)
		return
	queue_free()
