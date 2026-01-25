extends Area2D
class_name PrimogemPickup

## 原石拾取物
## 可以被角色拾取的原石掉落物（拾取后原石数量 +10，跨局保存）

const _PRIMOGEM_TEXTURE: Texture2D = preload("res://textures/ui/原石.png")

# 原石数量（默认10）
var primogem_amount: int = 10

# 拾取范围检测
var pickup_range: float = 0.0
var player: Node2D = null

# 移动速度（被吸引时的速度）
@export var attraction_speed: float = 300.0
# 初始延迟（掉落后的延迟，避免立即被吸引）
@export var initial_delay: float = 0.3
var delay_timer: float = 0.0

# 视觉组件
var sprite: Sprite2D

## 设置原石数量
func set_primogem_amount(amount: int) -> void:
	primogem_amount = amount

func _ready() -> void:
	# 添加到组（用于屏幕指示器/管理）
	add_to_group("primogem_pickups")

	# 注意：掉落物通常在“碰撞回调链路”（敌人死亡/受击）里被实例化。
	# 这时 Godot 可能正在 flushing physics queries，直接改 Area2D 的形状/碰撞状态会报错。
	# 因此把所有碰撞相关初始化延迟到本帧物理查询结束之后再做。
	call_deferred("_deferred_setup")

	# 初始化延迟计时器
	delay_timer = initial_delay

## 延迟初始化（避免 flushing queries 报错）
func _deferred_setup() -> void:
	# 设置碰撞层和掩码
	# 约定：第4层=玩家(Player) => bit 1<<3 == 8；第3层作为拾取物层 => bit 1<<2 == 4
	collision_layer = 1 << 2
	collision_mask = 1 << 3

	# 创建/确保碰撞形状存在（避免重复创建）
	var collision_shape: CollisionShape2D = null
	for child in get_children():
		if child is CollisionShape2D:
			collision_shape = child as CollisionShape2D
			break

	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		add_child(collision_shape)

	var circle_shape := CircleShape2D.new()
	circle_shape.radius = 8.0
	collision_shape.shape = circle_shape

	# 创建精灵（避免重复创建）
	if sprite == null:
		sprite = Sprite2D.new()
		add_child(sprite)

	sprite.texture = _PRIMOGEM_TEXTURE
	sprite.scale = Vector2(0.5, 0.5)

	# 连接信号（也放到延迟里，确保安全）
	_connect_signals()

## 连接信号（延迟调用）
func _connect_signals() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# 更新延迟计时器
	if delay_timer > 0.0:
		delay_timer -= delta
		return

	# 查找玩家
	if not player:
		_find_player()

	# 如果找到玩家且在拾取范围内，被吸引
	if player and pickup_range > 0.0:
		var distance := global_position.distance_to(player.global_position)
		if distance <= pickup_range:
			# 被吸引到玩家
			var direction := (player.global_position - global_position).normalized()
			global_position += direction * attraction_speed * delta

			# 如果距离很近，直接拾取
			if distance < 10.0:
				_pickup()

## 查找玩家
func _find_player() -> void:
	# 尝试多种方式查找玩家
	var battle_manager = get_tree().get_first_node_in_group("battle_manager")
	if battle_manager and battle_manager.has_method("get_player"):
		player = battle_manager.get_player() as Node2D
		if player and player.has_method("get_pickup_range"):
			pickup_range = player.get_pickup_range()
		return

	# 尝试直接查找
	var scene_root = get_tree().current_scene
	if scene_root:
		player = scene_root.get_node_or_null("player") as Node2D
		if player and player.has_method("get_pickup_range"):
			pickup_range = player.get_pickup_range()

## 身体进入回调
func _on_body_entered(body: Node2D) -> void:
	if body.name == "player" or body is BaseCharacter:
		_pickup()

## 拾取原石
func _pickup() -> void:
	if RunManager:
		RunManager.add_primogems(primogem_amount)

	queue_free()
