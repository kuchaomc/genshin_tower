extends Area2D
class_name GoldPickup

## 摩拉拾取物
## 可以被角色拾取的摩拉掉落物

# 摩拉数量（默认1）
var gold_amount: int = 1

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

## 设置摩拉数量
func set_gold_amount(amount: int) -> void:
	gold_amount = amount

func _ready() -> void:
	# 添加到组
	add_to_group("gold_pickups")

	# 注意：摩拉通常在“碰撞回调链路”（敌人死亡/受击）里被实例化。
	# 这时 Godot 可能正在 flushing physics queries，直接改 Area2D 的形状/碰撞状态会报错。
	# 因此把所有碰撞相关初始化延迟到本帧物理查询结束之后再做。
	call_deferred("_deferred_setup")
	
	# 初始化延迟计时器
	delay_timer = initial_delay

## 延迟初始化（避免 flushing queries 报错）
func _deferred_setup() -> void:
	# 设置碰撞层和掩码
	# 摩拉在碰撞层0（默认），检测玩家层（第4层）
	collision_layer = 0
	collision_mask = 4  # 玩家层

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
	circle_shape.radius = 8.0  # 摩拉碰撞半径
	collision_shape.shape = circle_shape

	# 创建精灵（避免重复创建）
	if sprite == null:
		sprite = Sprite2D.new()
		add_child(sprite)

	var texture = load("res://textures/ui/摩拉.png")
	if texture:
		sprite.texture = texture
		sprite.scale = Vector2(0.5, 0.5)  # 缩小显示

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
		var distance = global_position.distance_to(player.global_position)
		if distance <= pickup_range:
			# 被吸引到玩家
			var direction = (player.global_position - global_position).normalized()
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

## 拾取摩拉
func _pickup() -> void:
	# 添加到RunManager
	if RunManager:
		RunManager.add_gold(gold_amount)
	
	# 播放拾取效果（可以添加粒子效果等）
	# TODO: 添加拾取音效和视觉效果
	
	# 删除节点
	queue_free()
