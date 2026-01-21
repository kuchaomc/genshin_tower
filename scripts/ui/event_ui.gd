extends Node2D

## 奇遇事件界面脚本
## 功能：
## - 从EventRegistry随机选取并显示事件
## - 根据事件类型显示不同的UI（奖励、选择、战斗等）
## - 处理事件结果并应用奖励
## - 支持多种事件类型和交互方式

signal event_completed(event_id: String)
signal reward_given(reward_type: EventData.RewardType, reward_value: Variant)

@onready var title_label: Label = $CanvasLayer/VBoxContainer/TitleLabel
@onready var description_label: Label = $CanvasLayer/VBoxContainer/DescriptionLabel
@onready var content_container: VBoxContainer = $CanvasLayer/VBoxContainer/ContentContainer
@onready var choice_container: VBoxContainer = $CanvasLayer/VBoxContainer/ChoiceContainer

## 当前显示的事件
var current_event: EventData = null

## 当前事件ID
var current_event_id: String = ""

func _ready() -> void:
	# 获取随机事件
	_load_random_event()
	
	# 显示事件内容
	_display_event()

## 加载随机事件
func _load_random_event() -> void:
	var registry := EventRegistry
	
	var character_id := ""
	var current_floor := 0
	
	if RunManager.current_character:
		character_id = RunManager.current_character.id
	current_floor = RunManager.current_floor
	
	current_event = registry.pick_random_event(character_id, current_floor)
	
	if current_event:
		current_event_id = current_event.id
		print("EventUI: 加载事件 '%s' (%s)" % [current_event.display_name, current_event.id])
	else:
		push_error("EventUI: 无法加载事件")
		# 如果无法加载事件，显示默认消息
		current_event = null

## 显示事件内容
func _display_event() -> void:
	if not current_event:
		_show_error_message()
		return
	
	# 设置标题和描述
	if title_label:
		title_label.text = current_event.display_name
		title_label.add_theme_color_override("font_color", current_event.get_rarity_color())
	
	if description_label:
		var context = {
			"floor": RunManager.current_floor,
			"gold": RunManager.gold,
			"health": RunManager.health
		}
		description_label.text = current_event.get_formatted_description(context)
	
	# 清空内容容器
	_clear_content()
	
	# 根据事件类型显示不同的UI
	match current_event.event_type:
		EventData.EventType.REWARD:
			_show_reward_event()
		EventData.EventType.CHOICE:
			_show_choice_event()
		EventData.EventType.BATTLE:
			_show_battle_event()
		EventData.EventType.SHOP:
			_show_shop_event()
		EventData.EventType.REST:
			_show_rest_event()
		EventData.EventType.UPGRADE:
			_show_upgrade_event()
		EventData.EventType.RANDOM:
			_show_random_event()
		_:
			_show_default_event()

## 清空内容容器
func _clear_content() -> void:
	if content_container:
		for child in content_container.get_children():
			child.queue_free()
	
	if choice_container:
		for child in choice_container.get_children():
			child.queue_free()

## 显示奖励事件
func _show_reward_event() -> void:
	if not content_container:
		return
	
	var reward_label = Label.new()
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# 如果是圣遗物奖励，预先抽取并显示具体信息
	if current_event.reward_type == EventData.RewardType.ARTIFACT:
		var artifact_result = RunManager.get_random_artifact_with_slot_from_character_set()
		if artifact_result.is_empty():
			reward_label.text = "获得圣遗物！（但没有可用的圣遗物套装）"
			reward_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.9))
			content_container.add_child(reward_label)
			var confirm_button = Button.new()
			confirm_button.text = "确认"
			confirm_button.custom_minimum_size = Vector2(200, 50)
			confirm_button.pressed.connect(_complete_event)
			content_container.add_child(confirm_button)
		else:
			var artifact: ArtifactData = artifact_result.artifact
			var slot: ArtifactSlot.SlotType = artifact_result.slot
			var slot_name = ArtifactSlot.get_slot_name(slot)
			reward_label.text = "获得圣遗物！\n%s（%s）\n%s" % [artifact.name, slot_name, artifact.get_bonus_summary(0)]
			reward_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.9))
			content_container.add_child(reward_label)
			var confirm_button = Button.new()
			confirm_button.text = "获得奖励"
			confirm_button.custom_minimum_size = Vector2(200, 50)
			# 直接使用已抽取的圣遗物
			confirm_button.pressed.connect(func(): _give_specific_artifact(artifact, slot); _complete_event())
			content_container.add_child(confirm_button)
	else:
		reward_label.text = _get_reward_text(current_event.reward_type, current_event.reward_value)
		reward_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		content_container.add_child(reward_label)
		
		# 自动应用奖励
		var confirm_button = Button.new()
		confirm_button.text = "获得奖励"
		confirm_button.custom_minimum_size = Vector2(200, 50)
		confirm_button.pressed.connect(_on_reward_confirmed)
		content_container.add_child(confirm_button)

## 显示选择事件
func _show_choice_event() -> void:
	if not choice_container or not current_event.choices:
		return
	
	for i in range(current_event.choices.size()):
		var choice = current_event.choices[i]
		var choice_button = Button.new()
		choice_button.text = choice.get("text", "选择 %d" % (i + 1))
		choice_button.custom_minimum_size = Vector2(400, 60)
		choice_button.pressed.connect(_on_choice_selected.bind(i))
		choice_container.add_child(choice_button)

## 显示战斗事件
func _show_battle_event() -> void:
	if not content_container:
		return
	
	var battle_label = Label.new()
	battle_label.text = "准备战斗！"
	battle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(battle_label)
	
	var battle_button = Button.new()
	battle_button.text = "开始战斗"
	battle_button.custom_minimum_size = Vector2(200, 50)
	battle_button.pressed.connect(_on_battle_started)
	content_container.add_child(battle_button)

## 显示商店事件
func _show_shop_event() -> void:
	if not content_container:
		return
	
	var shop_label = Label.new()
	shop_label.text = "特殊商店（功能待实现）"
	shop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(shop_label)

## 显示休息事件
func _show_rest_event() -> void:
	if not content_container:
		return
	
	var rest_label = Label.new()
	rest_label.text = "你找到了一个休息的地方。"
	rest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(rest_label)
	
	var rest_button = Button.new()
	rest_button.text = "休息"
	rest_button.custom_minimum_size = Vector2(200, 50)
	rest_button.pressed.connect(_on_rest_confirmed)
	content_container.add_child(rest_button)

## 显示升级事件
func _show_upgrade_event() -> void:
	if not content_container:
		return
	
	var upgrade_label = Label.new()
	upgrade_label.text = "你获得了升级机会！"
	upgrade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(upgrade_label)
	
	var upgrade_button = Button.new()
	upgrade_button.text = "选择升级"
	upgrade_button.custom_minimum_size = Vector2(200, 50)
	upgrade_button.pressed.connect(_on_upgrade_confirmed)
	content_container.add_child(upgrade_button)

## 显示随机事件
func _show_random_event() -> void:
	if not content_container:
		return
	
	# 根据事件ID处理特定的随机事件
	if current_event_id == "weather_change":
		_show_weather_change_event()
	elif current_event_id == "fate_dice":
		_show_fate_dice_event()
	else:
		# 默认随机选择一种类型
		var rng := RunManager.get_rng() if RunManager else null
		var random_type: int = (rng.randi_range(0, 2) if rng else (randi() % 3))
		match random_type:
			0:
				_show_reward_event()
			1:
				_show_choice_event()
			_:
				_show_default_event()

## 显示天气变化事件
func _show_weather_change_event() -> void:
	if not content_container:
		return
	
	var rng := RunManager.get_rng() if RunManager else null
	var random: float = rng.randf() if rng else randf()
	var result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	if random < 0.2:
		# 20%概率：生命值-10%
		result_label.text = "暴雨导致滑倒，生命值-10%"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		var confirm_button = Button.new()
		confirm_button.text = "确认"
		confirm_button.custom_minimum_size = Vector2(200, 50)
		confirm_button.pressed.connect(func(): _apply_reward(EventData.RewardType.HEALTH, -10, current_event); _complete_event())
		content_container.add_child(result_label)
		content_container.add_child(confirm_button)
	elif random < 0.5:
		# 30%概率：生命值+5%
		result_label.text = "微风拂面，生命值+5%"
		result_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		var confirm_button = Button.new()
		confirm_button.text = "确认"
		confirm_button.custom_minimum_size = Vector2(200, 50)
		confirm_button.pressed.connect(func(): _apply_reward(EventData.RewardType.HEALTH, 5, current_event); _complete_event())
		content_container.add_child(result_label)
		content_container.add_child(confirm_button)
	else:
		# 50%概率：无影响
		result_label.text = "天气变化没有带来任何影响"
		result_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		var confirm_button = Button.new()
		confirm_button.text = "继续"
		confirm_button.custom_minimum_size = Vector2(200, 50)
		confirm_button.pressed.connect(_complete_event)
		content_container.add_child(result_label)
		content_container.add_child(confirm_button)

## 显示命运的骰子事件
func _show_fate_dice_event() -> void:
	if not content_container:
		return
	
	var rng := RunManager.get_rng() if RunManager else null
	var random: float = rng.randf() if rng else randf()
	var result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	if random < 0.1:
		# 10%概率：获得圣遗物
		# 先抽取圣遗物以显示具体名称
		var artifact_result = RunManager.get_random_artifact_with_slot_from_character_set() if RunManager else {}
		if artifact_result.is_empty():
			result_label.text = "获得圣遗物！（但没有可用的圣遗物套装）"
			result_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.9))
			var confirm_button = Button.new()
			confirm_button.text = "确认"
			confirm_button.custom_minimum_size = Vector2(200, 50)
			confirm_button.pressed.connect(_complete_event)
			content_container.add_child(result_label)
			content_container.add_child(confirm_button)
		else:
			var artifact: ArtifactData = artifact_result.artifact
			var slot: ArtifactSlot.SlotType = artifact_result.slot
			var slot_name = ArtifactSlot.get_slot_name(slot)
			result_label.text = "获得圣遗物！\n%s（%s）\n%s" % [artifact.name, slot_name, artifact.get_bonus_summary(0)]
			result_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.9))
			var confirm_button = Button.new()
			confirm_button.text = "获得奖励"
			confirm_button.custom_minimum_size = Vector2(200, 50)
			# 直接使用已抽取的圣遗物，而不是再随机一次
			confirm_button.pressed.connect(func(): _give_specific_artifact(artifact, slot); _complete_event())
			content_container.add_child(result_label)
			content_container.add_child(confirm_button)
	elif random < 0.3:
		# 20%概率：触发战斗
		result_label.text = "触发了战斗！"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		var battle_button = Button.new()
		battle_button.text = "开始战斗"
		battle_button.custom_minimum_size = Vector2(200, 50)
		battle_button.pressed.connect(_on_battle_started)
		content_container.add_child(result_label)
		content_container.add_child(battle_button)
	elif random < 0.6:
		# 30%概率：获得500摩拉
		result_label.text = "获得500摩拉！"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		var confirm_button = Button.new()
		confirm_button.text = "获得奖励"
		confirm_button.custom_minimum_size = Vector2(200, 50)
		confirm_button.pressed.connect(func(): _apply_reward(EventData.RewardType.GOLD, 500, current_event); _complete_event())
		content_container.add_child(result_label)
		content_container.add_child(confirm_button)
	else:
		# 40%概率：生命值恢复30%
		result_label.text = "生命值恢复30%！"
		result_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		var confirm_button = Button.new()
		confirm_button.text = "获得奖励"
		confirm_button.custom_minimum_size = Vector2(200, 50)
		confirm_button.pressed.connect(func(): _apply_reward(EventData.RewardType.HEALTH, -30, current_event); _complete_event())
		content_container.add_child(result_label)
		content_container.add_child(confirm_button)

## 显示默认事件
func _show_default_event() -> void:
	if not content_container:
		return
	
	var default_label = Label.new()
	default_label.text = "这是一个神秘的事件..."
	default_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(default_label)

## 显示错误消息
func _show_error_message() -> void:
	if title_label:
		title_label.text = "错误"
	if description_label:
		description_label.text = "无法加载事件"

# ========== 事件处理 ==========

## 确认奖励
func _on_reward_confirmed() -> void:
	if not current_event:
		return
	
	_apply_reward(current_event.reward_type, current_event.reward_value, current_event)
	_complete_event()

## 选择选项
func _on_choice_selected(choice_index: int) -> void:
	if not current_event or choice_index < 0 or choice_index >= current_event.choices.size():
		return
	
	var choice = current_event.choices[choice_index]
	
	# 检查是否需要支付成本
	if choice.has("cost") and choice.cost > 0:
		if not RunManager.spend_gold(choice.cost):
			print("摩拉不足，无法选择此选项")
			return
	
	# 应用奖励
	if choice.has("reward_type") and choice.reward_type != null:
		var reward_type = choice.get("reward_type")
		var reward_value = choice.get("reward_value")
		
		# 检查是否是战斗选项
		if choice.has("is_battle") and choice.is_battle:
			# 触发战斗
			_mark_event_triggered()
			if GameManager:
				GameManager.start_battle()
			return
		
		# 检查是否包含圣遗物奖励，如果是则显示获得的圣遗物信息
		var has_artifact_reward = false
		if reward_type == EventData.RewardType.ARTIFACT:
			has_artifact_reward = true
		elif reward_type == EventData.RewardType.MULTIPLE and reward_value is Dictionary:
			has_artifact_reward = reward_value.has("artifact")
		
		if has_artifact_reward:
			_show_artifact_reward_result(reward_type, reward_value)
			return
		
		_apply_reward(reward_type, reward_value, current_event)
	
	_complete_event()

## 开始战斗
func _on_battle_started() -> void:
	if not current_event:
		return
	
	# 标记事件已触发
	_mark_event_triggered()
	
	# 如果事件有敌人数据，可以在这里设置
	# 目前直接进入战斗场景
	if GameManager:
		GameManager.start_battle()
	else:
		_complete_event()

## 确认休息
func _on_rest_confirmed() -> void:
	if not current_event:
		return
	
	# 检查是否需要支付成本
	if current_event_id == "liyue_inn":
		# 璃月客栈需要支付200摩拉
		if not RunManager.spend_gold(200):
			print("摩拉不足，无法在客栈休息")
			return
		# 生命值全满
		RunManager.heal(RunManager.max_health)
	else:
		# 其他休息事件根据reward_value恢复
		_apply_reward(current_event.reward_type, current_event.reward_value, current_event)
	
	_complete_event()

## 确认升级
func _on_upgrade_confirmed() -> void:
	if not current_event:
		return
	
	# 在场景切换之前先标记事件（因为场景切换后节点会被移除）
	_mark_event_triggered()
	emit_signal("event_completed", current_event_id)
	
	# 打开升级选择界面
	if GameManager:
		GameManager.show_upgrade_selection()


# ========== 奖励处理 ==========

## 应用奖励
func _apply_reward(reward_type: EventData.RewardType, reward_value: Variant, event_data: EventData = null) -> void:
	# 处理随机奖励范围
	var actual_value = _get_actual_reward_value(reward_type, reward_value, event_data)
	
	match reward_type:
		EventData.RewardType.GOLD:
			if actual_value is int or actual_value is float:
				RunManager.add_gold(int(actual_value))
				print("获得摩拉：", actual_value)
		
		EventData.RewardType.HEALTH:
			if actual_value is int or actual_value is float:
				# 检查是否是百分比（负数表示百分比）
				if actual_value < 0:
					var percent = abs(actual_value)
					var heal_amount = RunManager.max_health * (percent / 100.0)
					RunManager.heal(heal_amount)
					print("恢复生命值：", heal_amount, " (", percent, "%)")
				else:
					RunManager.heal(float(actual_value))
					print("恢复生命值：", actual_value)
		
		EventData.RewardType.UPGRADE:
			if actual_value is String:
				if actual_value == "random_max":
					# 随机选择一个升级并直接满级
					_give_random_upgrade_max_level()
				else:
					# 直接给指定的升级
					var level = 1
					if event_data and event_data.has("upgrade_level"):
						level = event_data.upgrade_level
					RunManager.add_upgrade(actual_value, level)
					print("获得升级：", actual_value, " 等级：", level)
			elif actual_value == "random" or actual_value == null:
				# 随机选择一个升级
				_give_random_upgrade()
			elif actual_value is int:
				# 给多个随机升级
				for i in range(actual_value):
					_give_random_upgrade()
		
		EventData.RewardType.ARTIFACT:
			# 圣遗物奖励：从角色专属圣遗物套装中随机抽取
			var artifact_count_to_give = 1
			if actual_value is int:
				artifact_count_to_give = actual_value
			
			for i in range(artifact_count_to_give):
				var result = RunManager.get_random_artifact_with_slot_from_character_set()
				if result.is_empty():
					print("无法获取圣遗物：角色没有专属圣遗物套装")
					continue
				
				var artifact: ArtifactData = result.artifact
				var slot: ArtifactSlot.SlotType = result.slot
				var slot_name = ArtifactSlot.get_slot_name(slot)
				
				# 添加到库存并装备
				RunManager.add_artifact_to_inventory(artifact, slot)
				RunManager.equip_artifact_to_character(artifact, slot)
				
				print("获得圣遗物：%s（%s）" % [artifact.name, slot_name])
		
		EventData.RewardType.MULTIPLE:
			if actual_value is Dictionary:
				# 处理多种奖励
				for key in actual_value:
					var value = actual_value[key]
					if key == "gold":
						# 如果事件有随机范围，且gold是最大值，则使用随机范围
						if event_data and event_data.reward_min > 0 and event_data.reward_max > 0:
							var rng := RunManager.get_rng()
							var random_gold = rng.randi_range(int(event_data.reward_min), int(event_data.reward_max))
							RunManager.add_gold(random_gold)
							print("获得摩拉：", random_gold)
						else:
							RunManager.add_gold(int(value))
					elif key == "health":
						if value is float and value < 0:
							# 负数表示扣血
							RunManager.take_damage(abs(value))
						elif value is float and value > 1000:
							# 大数值表示全满
							RunManager.heal(RunManager.max_health)
						else:
							# 正数表示恢复生命值
							RunManager.heal(float(value))
					elif key == "upgrade":
						if value is String:
							RunManager.add_upgrade(value, 1)
						elif value is int:
							for i in range(value):
								_give_random_upgrade()
					elif key == "artifact":
						# 圣遗物奖励：从角色专属圣遗物套装中随机抽取
						var artifact_num = 1
						if value is int:
							artifact_num = value
						
						for j in range(artifact_num):
							var result = RunManager.get_random_artifact_with_slot_from_character_set()
							if result.is_empty():
								print("无法获取圣遗物：角色没有专属圣遗物套装")
								continue
							
							var artifact: ArtifactData = result.artifact
							var slot: ArtifactSlot.SlotType = result.slot
							var slot_name = ArtifactSlot.get_slot_name(slot)
							
							# 添加到库存并装备
							RunManager.add_artifact_to_inventory(artifact, slot)
							RunManager.equip_artifact_to_character(artifact, slot)
							
							print("获得圣遗物：%s（%s）" % [artifact.name, slot_name])
	
	emit_signal("reward_given", reward_type, actual_value)

## 获取实际奖励值（处理随机范围）
func _get_actual_reward_value(reward_type: EventData.RewardType, reward_value: Variant, event_data: EventData) -> Variant:
	if not event_data:
		return reward_value
	
	# 检查是否有随机范围
	if event_data.reward_min > 0 and event_data.reward_max > 0:
		# 使用随机范围
		var rng := RunManager.get_rng() if RunManager else null
		var random_value = (rng.randi_range(int(event_data.reward_min), int(event_data.reward_max)) if rng else randi_range(int(event_data.reward_min), int(event_data.reward_max)))
		return random_value
	
	# 检查reward_value是否是数组范围
	if reward_value is Array and reward_value.size() == 2:
		var min_val = reward_value[0]
		var max_val = reward_value[1]
		var rng := RunManager.get_rng() if RunManager else null
		return (rng.randi_range(int(min_val), int(max_val)) if rng else randi_range(int(min_val), int(max_val)))
	
	return reward_value

## 给予随机升级
func _give_random_upgrade() -> void:
	var registry := UpgradeRegistry
	
	var character_id := ""
	var current_floor := 0
	var current_upgrades: Dictionary = {}
	
	if RunManager.current_character:
		character_id = RunManager.current_character.id
	current_floor = RunManager.current_floor
	current_upgrades = RunManager.upgrades
	
	var picked = registry.pick_random_upgrades(character_id, current_upgrades, current_floor, 1)
	if picked.size() > 0:
		var upgrade = picked[0]
		RunManager.add_upgrade(upgrade.id, 1)
		print("随机获得升级：", upgrade.display_name)

## 给予随机升级并直接满级
func _give_random_upgrade_max_level() -> void:
	var registry := UpgradeRegistry
	
	var character_id := ""
	var current_floor := 0
	var current_upgrades: Dictionary = {}
	
	if RunManager.current_character:
		character_id = RunManager.current_character.id
	current_floor = RunManager.current_floor
	current_upgrades = RunManager.upgrades
	
	var picked = registry.pick_random_upgrades(character_id, current_upgrades, current_floor, 1)
	if picked.size() > 0:
		var upgrade = picked[0]
		var max_level = upgrade.max_level if upgrade.max_level > 0 else 5  # 如果没有最大等级，默认5级
		var current_level = RunManager.get_upgrade_level(upgrade.id)
		var levels_to_add = max_level - current_level
		if levels_to_add > 0:
			RunManager.add_upgrade(upgrade.id, levels_to_add)
			print("随机获得升级并满级：", upgrade.display_name, " 等级：", max_level)

## 给予指定的圣遗物（用于已预先抽取的情况）
func _give_specific_artifact(artifact: ArtifactData, slot: ArtifactSlot.SlotType) -> void:
	if not artifact:
		return
	
	var slot_name = ArtifactSlot.get_slot_name(slot)
	
	# 添加到库存并装备
	RunManager.add_artifact_to_inventory(artifact, slot)
	RunManager.equip_artifact_to_character(artifact, slot)
	
	print("获得圣遗物：%s（%s）" % [artifact.name, slot_name])

## 显示圣遗物奖励结果（用于选择事件中的圣遗物奖励）
func _show_artifact_reward_result(reward_type: EventData.RewardType, reward_value: Variant) -> void:
	# 清空选择按钮
	if choice_container:
		for child in choice_container.get_children():
			child.queue_free()
	
	# 清空内容容器
	_clear_content()
	
	# 抽取圣遗物
	var artifact_result = RunManager.get_random_artifact_with_slot_from_character_set()
	
	var result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	if artifact_result.is_empty():
		result_label.text = "获得圣遗物！（但没有可用的圣遗物套装）"
		result_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.9))
		content_container.add_child(result_label)
		
		# 如果有其他奖励（MULTIPLE类型），也要应用
		if reward_type == EventData.RewardType.MULTIPLE and reward_value is Dictionary:
			_apply_non_artifact_rewards(reward_value)
		
		var confirm_button = Button.new()
		confirm_button.text = "确认"
		confirm_button.custom_minimum_size = Vector2(200, 50)
		confirm_button.pressed.connect(_complete_event)
		content_container.add_child(confirm_button)
	else:
		var artifact: ArtifactData = artifact_result.artifact
		var slot: ArtifactSlot.SlotType = artifact_result.slot
		var slot_name = ArtifactSlot.get_slot_name(slot)
		
		# 构建显示文本
		var display_text = "获得圣遗物！\n%s（%s）\n%s" % [artifact.name, slot_name, artifact.get_bonus_summary(0)]
		
		# 如果是MULTIPLE类型且有其他奖励，添加到显示
		if reward_type == EventData.RewardType.MULTIPLE and reward_value is Dictionary:
			var other_rewards: Array[String] = []
			for key in reward_value:
				if key != "artifact":
					var value = reward_value[key]
					if key == "gold":
						other_rewards.append("摩拉 +%d" % int(value))
					elif key == "health":
						if value < 0:
							other_rewards.append("生命值 %d" % int(value))
						else:
							other_rewards.append("生命值 +%d" % int(value))
			if other_rewards.size() > 0:
				display_text += "\n\n其他奖励：" + ", ".join(other_rewards)
		
		result_label.text = display_text
		result_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.9))
		content_container.add_child(result_label)
		
		var confirm_button = Button.new()
		confirm_button.text = "获得奖励"
		confirm_button.custom_minimum_size = Vector2(200, 50)
		# 点击后给予圣遗物和其他奖励
		confirm_button.pressed.connect(func():
			_give_specific_artifact(artifact, slot)
			if reward_type == EventData.RewardType.MULTIPLE and reward_value is Dictionary:
				_apply_non_artifact_rewards(reward_value)
			_complete_event()
		)
		content_container.add_child(confirm_button)

## 应用非圣遗物奖励（用于MULTIPLE类型中排除圣遗物后的其他奖励）
func _apply_non_artifact_rewards(reward_dict: Dictionary) -> void:
	for key in reward_dict:
		if key == "artifact":
			continue  # 跳过圣遗物，已单独处理
		
		var value = reward_dict[key]
		if key == "gold":
			RunManager.add_gold(int(value))
			print("获得摩拉：", value)
		elif key == "health":
			if value is float and value < 0:
				RunManager.take_damage(abs(value))
			else:
				RunManager.heal(float(value))
		elif key == "upgrade":
			if value is String:
				RunManager.add_upgrade(value, 1)
			elif value is int:
				for i in range(value):
					_give_random_upgrade()

## 获取奖励文本
func _get_reward_text(reward_type: EventData.RewardType, reward_value: Variant) -> String:
	match reward_type:
		EventData.RewardType.GOLD:
			return "获得 %d 摩拉" % int(reward_value)
		EventData.RewardType.HEALTH:
			return "恢复 %d 点生命值" % int(reward_value)
		EventData.RewardType.UPGRADE:
			return "获得升级"
		EventData.RewardType.MULTIPLE:
			return "获得多种奖励"
		_:
			return "获得奖励"

# ========== 工具方法 ==========

## 完成事件
func _complete_event() -> void:
	_mark_event_triggered()
	emit_signal("event_completed", current_event_id)
	
	# 检查场景树是否存在（节点可能已经不在场景树中）
	var tree = get_tree()
	if tree:
		# 延迟返回地图（给玩家时间看到奖励）
		await tree.create_timer(1.0).timeout
		if GameManager:
			GameManager.go_to_map_view()
	else:
		# 如果节点不在场景树中，直接返回地图
		if GameManager:
			GameManager.go_to_map_view()

## 标记事件已触发
func _mark_event_triggered() -> void:
	if current_event_id.is_empty():
		return
	
	EventRegistry.mark_event_triggered(current_event_id)
