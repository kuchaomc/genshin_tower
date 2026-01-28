extends Node

## 奇遇事件注册表
## 管理所有可用事件的注册、查询和随机选取
## 作为自动加载单例使用

# ========== 信号 ==========
signal events_registered
signal event_added(event_id: String)

# ========== 存储 ==========
## 所有已注册的事件 {id: EventData}
var _events: Dictionary = {}

## 按类型分类的事件ID列表
var _events_by_type: Dictionary = {}

## 按标签分类的事件ID列表
var _events_by_tag: Dictionary = {}

## 按稀有度分类的事件ID列表
var _events_by_rarity: Dictionary = {}

## 已触发的事件ID列表（用于one_time_only检查）
var _triggered_events: Array[String] = []

# ========== 初始化 ==========

func _ready() -> void:
	# 注册所有内置事件
	_register_builtin_events()
	
	# 加载自定义事件（从文件）
	_load_custom_events()
	
	_validate_all_events()
	
	emit_signal("events_registered")
	if DebugLogger:
		DebugLogger.log_info("已注册 %d 个事件" % _events.size(), "EventRegistry")

## 加载自定义事件文件
func _load_custom_events() -> void:
	# 注意：导出版本里 res:// 通常是只读包体，运行时不应尝试创建目录/写入。
	# 自定义事件优先从 user://data/events/ 读取（可由玩家/外部写入），其次从 res://data/events/ 读取（随包体发布）。
	_load_custom_events_from_dir("user://data/events/")
	_load_custom_events_from_dir("res://data/events/")

func _load_custom_events_from_dir(events_dir: String) -> void:
	var dir := DirAccess.open(events_dir)
	if dir == null:
		if DebugLogger:
			DebugLogger.log_debug("未找到事件目录 %s" % events_dir, "EventRegistry")
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	var loaded_count = 0
	
	while file_name != "":
		if not dir.current_is_dir():
			var is_tres := file_name.ends_with(".tres") or file_name.ends_with(".tres.remap")
			var is_res := file_name.ends_with(".res") or file_name.ends_with(".res.remap")
			if not (is_tres or is_res):
				file_name = dir.get_next() as String
				continue
			var actual_file: String = file_name
			if actual_file.ends_with(".remap"):
				actual_file = actual_file.substr(0, actual_file.length() - 6)
			var file_path = events_dir + actual_file
			var event: EventData = null
			if DataManager:
				var res := DataManager.load_cached(file_path)
				event = res as EventData if res is EventData else null
			else:
				event = load(file_path) as EventData
			
			if event and not event.id.is_empty():
				# 记录来源路径：用于校验/定位 user:// 覆盖问题
				event.set_meta("source_path", file_path)
				if not _is_event_valid_for_register(event):
					if DebugLogger:
						DebugLogger.log_warning("跳过非法事件 '%s'（%s）" % [event.id, file_path], "EventRegistry")
					else:
						push_warning("EventRegistry: 跳过非法事件 '%s'（%s）" % [event.id, file_path])
					file_name = dir.get_next() as String
					continue
				# 避免覆盖内置事件
				if not _events.has(event.id):
					_register_event(event)
					loaded_count += 1
					if DebugLogger:
						DebugLogger.log_debug("加载自定义事件 '%s'（%s）" % [event.id, file_name], "EventRegistry")
				else:
					if DebugLogger:
						DebugLogger.log_warning("跳过重复的事件ID '%s'" % event.id, "EventRegistry")
		
		file_name = dir.get_next() as String
	
	dir.list_dir_end()
	
	if loaded_count > 0:
		if DebugLogger:
			DebugLogger.log_info("从 %s 共加载 %d 个自定义事件" % [events_dir, loaded_count], "EventRegistry")

## 注册所有内置事件
func _register_builtin_events() -> void:
	# ========== 简单奖励事件 ==========
	
	# 发现宝箱 - 获得摩拉
	_register_event(_create_reward_event(
		"treasure_gold_small", "发现宝箱", "你发现了一个宝箱，里面有一些摩拉。\n获得 {reward} 摩拉。",
		EventData.RewardType.GOLD, 50, EventData.Rarity.COMMON, ["reward", "gold"]
	))
	
	_register_event(_create_reward_event(
		"treasure_gold_medium", "发现宝箱", "你发现了一个精致的宝箱，里面有不少摩拉。\n获得 {reward} 摩拉。",
		EventData.RewardType.GOLD, 100, EventData.Rarity.UNCOMMON, ["reward", "gold"]
	))
	
	_register_event(_create_reward_event(
		"treasure_gold_large", "发现宝箱", "你发现了一个华丽的宝箱，里面装满了摩拉！\n获得 {reward} 摩拉。",
		EventData.RewardType.GOLD, 200, EventData.Rarity.RARE, ["reward", "gold"]
	))
	
	# 恢复生命值
	_register_event(_create_reward_event(
		"healing_spring", "治愈之泉", "你发现了一处治愈之泉，泉水恢复了你的体力。\n恢复 {reward} 点生命值。",
		EventData.RewardType.HEALTH, 30, EventData.Rarity.COMMON, ["reward", "healing"]
	))
	
	_register_event(_create_reward_event(
		"healing_spring_great", "圣洁之泉", "你发现了一处圣洁之泉，泉水充满了治愈的力量。\n恢复 {reward} 点生命值。",
		EventData.RewardType.HEALTH, 50, EventData.Rarity.UNCOMMON, ["reward", "healing"]
	))
	
	# ========== 选择事件 ==========
	
	# 神秘商人
	var merchant_event = EventData.new()
	merchant_event.id = "mysterious_merchant"
	merchant_event.display_name = "神秘商人"
	merchant_event.description = "你遇到了一个神秘商人，他向你展示了一些商品。"
	merchant_event.event_type = EventData.EventType.CHOICE
	merchant_event.rarity = EventData.Rarity.UNCOMMON
	merchant_event.base_weight = 80.0
	merchant_event.tags.append("choice")
	merchant_event.tags.append("merchant")
	merchant_event.choices.append({
		"text": "购买生命药水（50摩拉）",
		"reward_type": EventData.RewardType.HEALTH,
		"reward_value": 40,
		"cost": 50,
		"description": "恢复40点生命值"
	})
	merchant_event.choices.append({
		"text": "购买升级卷轴（100摩拉）",
		"reward_type": EventData.RewardType.UPGRADE,
		"reward_value": "random",
		"cost": 100,
		"description": "随机获得一个升级"
	})
	merchant_event.choices.append({
		"text": "离开",
		"reward_type": null,
		"reward_value": null,
		"cost": 0,
		"description": "不购买任何东西"
	})
	_register_event(merchant_event)
	
	# 危险的选择
	var danger_event = EventData.new()
	danger_event.id = "dangerous_choice"
	danger_event.display_name = "危险的选择"
	danger_event.description = "你发现了两条路，一条看起来安全但奖励较少，另一条充满危险但可能有丰厚回报。"
	danger_event.event_type = EventData.EventType.CHOICE
	danger_event.rarity = EventData.Rarity.RARE
	danger_event.base_weight = 60.0
	danger_event.tags.append("choice")
	danger_event.tags.append("risk")
	danger_event.choices.append({
		"text": "选择安全的路",
		"reward_type": EventData.RewardType.GOLD,
		"reward_value": 50,
		"description": "安全地获得50摩拉"
	})
	danger_event.choices.append({
		"text": "选择危险的路",
		"reward_type": EventData.RewardType.MULTIPLE,
		"reward_value": {"gold": 150, "health": -20},
		"description": "获得150摩拉，但失去20点生命值"
	})
	_register_event(danger_event)
	
	# ========== 战斗事件 ==========
	
	var battle_event = EventData.new()
	battle_event.id = "ambush"
	battle_event.display_name = "遭遇伏击"
	battle_event.description = "你遭到了敌人的伏击！必须战斗才能继续前进。"
	battle_event.event_type = EventData.EventType.BATTLE
	battle_event.rarity = EventData.Rarity.COMMON
	battle_event.base_weight = 100.0
	battle_event.tags.append("battle")
	battle_event.tags.append("combat")
	battle_event.battle_reward = {
		"gold": 80,
		"description": "击败敌人后获得80摩拉"
	}
	_register_event(battle_event)
	
	print("EventRegistry: 已注册 %d 个内置事件" % _events.size())

## 创建奖励事件的辅助方法
func _create_reward_event(
	id: String,
	name: String,
	desc: String,
	reward_type: EventData.RewardType,
	reward_value: Variant,
	rarity: EventData.Rarity,
	tags: Array
) -> EventData:
	var event = EventData.new()
	event.id = id
	event.display_name = name
	event.description = desc
	event.event_type = EventData.EventType.REWARD
	event.reward_type = reward_type
	event.reward_value = reward_value
	event.rarity = rarity
	event.base_weight = 100.0
	for tag in tags:
		event.tags.append(tag)
	return event

# ========== 注册方法 ==========

## 注册单个事件
func _register_event(event: EventData) -> void:
	if event.id.is_empty():
		push_error("EventRegistry: 事件ID不能为空")
		return
	
	if _events.has(event.id):
		push_warning("EventRegistry: 事件 '%s' 已存在，将被覆盖" % event.id)
	
	_events[event.id] = event
	
	# 按类型分类
	var type_key = str(event.event_type)
	if not _events_by_type.has(type_key):
		_events_by_type[type_key] = []
	_events_by_type[type_key].append(event.id)
	
	# 按标签分类
	for tag in event.tags:
		if not _events_by_tag.has(tag):
			_events_by_tag[tag] = []
		_events_by_tag[tag].append(event.id)
	
	# 按稀有度分类
	var rarity_key = str(event.rarity)
	if not _events_by_rarity.has(rarity_key):
		_events_by_rarity[rarity_key] = []
	_events_by_rarity[rarity_key].append(event.id)
	
	emit_signal("event_added", event.id)

## 注册自定义事件（供外部使用）
func register_event(event: EventData) -> void:
	_register_event(event)

## 批量注册事件
func register_events(events: Array[EventData]) -> void:
	for event in events:
		_register_event(event)

# ========== 查询方法 ==========

## 获取所有事件
func get_all_events() -> Array[EventData]:
	var result: Array[EventData] = []
	for event in _events.values():
		result.append(event)
	return result

## 根据ID获取事件
func get_event(id: String) -> EventData:
	return _events.get(id, null)

## 获取指定类型的事件
func get_events_by_type(type: EventData.EventType) -> Array[EventData]:
	var result: Array[EventData] = []
	var type_key = str(type)
	if _events_by_type.has(type_key):
		for id in _events_by_type[type_key]:
			result.append(_events[id])
	return result

## 获取指定标签的事件
func get_events_by_tag(tag: String) -> Array[EventData]:
	var result: Array[EventData] = []
	if _events_by_tag.has(tag):
		for id in _events_by_tag[tag]:
			result.append(_events[id])
	return result

## 获取指定稀有度的事件
func get_events_by_rarity(rarity: EventData.Rarity) -> Array[EventData]:
	var result: Array[EventData] = []
	var rarity_key = str(rarity)
	if _events_by_rarity.has(rarity_key):
		for id in _events_by_rarity[rarity_key]:
			result.append(_events[id])
	return result

# ========== 随机选取方法 ==========

## 获取可用的事件列表（过滤不符合条件的）
func get_available_events(
	character_id: String,
	current_floor: int,
	filter_tags: Array[String] = []
) -> Array[EventData]:
	var result: Array[EventData] = []
	
	for event in _events.values():
		# 检查是否满足触发条件
		if not event.can_trigger(character_id, current_floor, _triggered_events):
			continue
		
		# 检查标签过滤
		if filter_tags.size() > 0:
			var has_tag = false
			for tag in filter_tags:
				if tag in event.tags:
					has_tag = true
					break
			if not has_tag:
				continue
		
		result.append(event)
	
	# 调试信息：打印可用事件列表
	if result.size() > 0:
		print("EventRegistry: 找到 %d 个可用事件: " % result.size(), result.map(func(e): return e.id))
	
	return result

## 随机选取一个事件（带权重）
func pick_random_event(
	character_id: String,
	current_floor: int,
	filter_tags: Array[String] = []
) -> EventData:
	var available = get_available_events(character_id, current_floor, filter_tags)
	
	if available.is_empty():
		push_warning("EventRegistry: 没有可用的事件")
		return null
	
	if available.size() == 1:
		return available[0]
	
	# 计算权重
	var weights: Array[float] = []
	var total_weight: float = 0.0
	
	for event in available:
		var weight = event.calculate_weight(current_floor, _triggered_events)
		weights.append(weight)
		total_weight += weight
	
	# 权重随机选取：统一走 RunManager RNG（避免频繁 randomize 破坏可控性）
	var rng: RandomNumberGenerator = null
	if RunManager:
		rng = RunManager.get_rng()
	if not rng:
		push_warning("EventRegistry: RunManager 不可用，创建临时 RNG")
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var random_value: float = rng.randf() * total_weight
	var cumulative_weight: float = 0.0
	
	for i in range(available.size()):
		cumulative_weight += weights[i]
		if random_value <= cumulative_weight:
			return available[i]
	
	# 如果出现意外情况，返回第一个
	return available[0]

# ========== 事件触发管理 ==========

## 标记事件已触发
func mark_event_triggered(event_id: String) -> void:
	if event_id not in _triggered_events:
		_triggered_events.append(event_id)

## 检查事件是否已触发
func is_event_triggered(event_id: String) -> bool:
	return event_id in _triggered_events

## 清除所有触发记录（用于新游戏）
func clear_triggered_events() -> void:
	_triggered_events.clear()

## 获取已触发的事件列表
func get_triggered_events() -> Array[String]:
	return _triggered_events.duplicate()

# ========== 工具方法 ==========

## 获取事件数量
func get_event_count() -> int:
	return _events.size()

## 检查事件是否存在
func has_event(id: String) -> bool:
	return _events.has(id)


func _validate_all_events() -> void:
	if _events.is_empty():
		return
	var supported_random_ids: Array[String] = ["weather_change", "fate_dice"]
	var issues: Array[String] = []
	for e in _events.values():
		var event := e as EventData
		if event == null:
			continue
		if event.id.is_empty():
			issues.append("事件存在空 id")
			continue
		if event.display_name.is_empty():
			issues.append("[%s] display_name 为空" % event.id)
		if event.description.is_empty():
			issues.append("[%s] description 为空" % event.id)
		if event.base_weight <= 0.0:
			issues.append("[%s] base_weight <= 0" % event.id)
		# 引用检查：前置/互斥ID必须存在
		for rid in event.required_event_ids:
			var sid := str(rid)
			if sid.is_empty():
				continue
			if not _events.has(sid):
				issues.append("[%s] required_event_ids 引用了不存在的事件 '%s'" % [event.id, sid])
		for xid in event.exclusive_event_ids:
			var sid := str(xid)
			if sid.is_empty():
				continue
			if not _events.has(sid):
				issues.append("[%s] exclusive_event_ids 引用了不存在的事件 '%s'" % [event.id, sid])
		# 类型与字段匹配
		match event.event_type:
			EventData.EventType.CHOICE:
				if event.choices.is_empty():
					issues.append("[%s] CHOICE 事件 choices 为空" % event.id)
				else:
					for i in range(event.choices.size()):
						var c: Dictionary = event.choices[i]
						var text := str(c.get("text", ""))
						if text.is_empty():
							issues.append("[%s] choices[%d] text 为空" % [event.id, i])
						var cost_v: Variant = c.get("cost", 0)
						if (cost_v is int or cost_v is float) and float(cost_v) < 0.0:
							issues.append("[%s] choices[%d] cost 为负数" % [event.id, i])
			EventData.EventType.REWARD:
				# RANDOM/SHOP/REST/UPGRADE/BATTLE 的奖励逻辑由 EventUI 分支处理，这里只做轻量校验
				pass
			EventData.EventType.BATTLE:
				# BATTLE=1：事件战斗走通用战斗，不要求配置 enemy_data
				pass
			EventData.EventType.SHOP:
				# SHOP=2：目前仅 antique_shop 有完整购买逻辑，其它 SHOP 仍视为占位
				if event.id != "antique_shop":
					issues.append("[%s] SHOP 事件尚未实现购买逻辑（当前仅支持 antique_shop）" % event.id)
			EventData.EventType.REST:
				# REST=2：按 reward_type/reward_value 数据驱动执行
				if event.reward_type == EventData.RewardType.MULTIPLE and (not (event.reward_value is Dictionary)):
					var src := str(event.get_meta("source_path", ""))
					issues.append("[%s] REST 事件 reward_type=MULTIPLE 但 reward_value 不是 Dictionary（typeof=%d value=%s source=%s）" % [event.id, typeof(event.reward_value), str(event.reward_value), src])
				elif event.reward_type == EventData.RewardType.GOLD and (not (event.reward_value is int or event.reward_value is float)):
					issues.append("[%s] REST 事件 reward_type=GOLD 但 reward_value 不是数值" % event.id)
			EventData.EventType.UPGRADE:
				# UPGRADE=2：按 reward_type/reward_value 数据驱动执行
				if event.reward_type != EventData.RewardType.UPGRADE:
					issues.append("[%s] UPGRADE 事件 reward_type 不是 UPGRADE" % event.id)
				if event.reward_value == null:
					issues.append("[%s] UPGRADE 事件 reward_value 为空" % event.id)
			EventData.EventType.RANDOM:
				if not (event.id in supported_random_ids):
					issues.append("[%s] RANDOM 事件未在 EventUI 中实现专用逻辑（会走默认随机展示）" % event.id)
			_:
				pass
	
	if issues.is_empty():
		return
	if DebugLogger:
		DebugLogger.log_warning("事件校验发现问题数：%d" % issues.size(), "EventRegistry")
		for line in issues:
			DebugLogger.log_warning(line, "EventRegistry")
	else:
		for line in issues:
			push_warning("EventRegistry: %s" % line)


func _is_event_valid_for_register(event: EventData) -> bool:
	if event == null:
		return false
	if event.id.is_empty():
		return false
	# 对 user:// 覆盖文件做最小校验，避免坏数据把 res:// 正常版本“挡住”
	match event.event_type:
		EventData.EventType.REST:
			if event.reward_type == EventData.RewardType.MULTIPLE and not (event.reward_value is Dictionary):
				return false
		EventData.EventType.UPGRADE:
			if event.reward_type != EventData.RewardType.UPGRADE:
				return false
			if event.reward_value == null:
				return false
		_:
			pass
	return true
