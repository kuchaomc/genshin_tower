extends Node2D

## 结算界面脚本

@onready var background: ColorRect = $CanvasLayer/Background
@onready var result_panel: PanelContainer = $CanvasLayer/CenterContainer/ResultPanel
@onready var victory_label: Label = $CanvasLayer/CenterContainer/ResultPanel/MarginContainer/Content/TitleLabel
@onready var stats_container: VBoxContainer = $CanvasLayer/CenterContainer/ResultPanel/MarginContainer/Content/StatsContainer
@onready var continue_button: Button = $CanvasLayer/CenterContainer/ResultPanel/MarginContainer/Content/ButtonContainer/ContinueButton

var run_record: Dictionary = {}


func _enter_tree() -> void:
	# 尽可能早地把UI置为透明，避免首帧闪烁
	var bg := get_node_or_null("CanvasLayer/Background") as CanvasItem
	if bg:
		bg.modulate.a = 0.0
	var panel := get_node_or_null("CanvasLayer/CenterContainer/ResultPanel") as CanvasItem
	if panel:
		panel.modulate.a = 0.0

func _ready() -> void:
	# 防止进入结算时闪一下：先把UI设为透明，再等待转场黑屏淡出
	if is_instance_valid(background):
		background.modulate.a = 0.0
	if is_instance_valid(result_panel):
		result_panel.modulate.a = 0.0

	load_run_record()
	display_results()
	
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)

	# 如果是从战斗胜利转场进入结算界面，需要把黑屏淡入撤掉
	# 约定：发起方只负责 fade_out；目标场景在 _ready() 检测 is_transitioning 后执行 fade_in
	if TransitionManager != null and TransitionManager.is_transitioning:
		await TransitionManager.fade_in(0.4)
	await get_tree().process_frame
	_play_show_animation()


func _play_show_animation() -> void:
	if not result_panel:
		return
	# 背景遮罩与面板一起淡入
	if is_instance_valid(background):
		background.modulate.a = 0.0
	result_panel.modulate.a = 0.0
	result_panel.scale = Vector2.ONE
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	if is_instance_valid(background):
		tween.parallel().tween_property(background, "modulate:a", 1.0, 0.35)
	tween.tween_property(result_panel, "modulate:a", 1.0, 0.35)

## 加载结算记录
func load_run_record() -> void:
	if GameManager:
		run_record = GameManager.get_latest_record()
	else:
		run_record = {}

## 显示结算结果
func display_results() -> void:
	if run_record.is_empty():
		victory_label.text = "游戏结束"
		return
	
	for child in stats_container.get_children():
		child.queue_free()
	
	var victory = run_record.get("victory", false)
	if victory:
		victory_label.text = "胜利！"
		victory_label.modulate = Color.GREEN
	else:
		victory_label.text = "失败"
		victory_label.modulate = Color.RED
	
	# 显示统计数据
	display_stat("角色", run_record.get("character_name", "未知"))
	display_stat("到达楼层", str(run_record.get("floors_cleared", 0)))
	display_stat("击杀敌人", str(run_record.get("enemies_killed", 0)))
	display_stat("获得金币", str(run_record.get("gold_earned", 0)))
	display_stat("获得原石", str(run_record.get("primogems_earned", 0)))
	display_stat("造成伤害", "%.1f" % run_record.get("damage_dealt", 0.0))
	display_stat("受到伤害", "%.1f" % run_record.get("damage_taken", 0.0))
	
	var time_elapsed = run_record.get("time_elapsed", 0.0)
	var minutes = int(time_elapsed / 60)
	var seconds = int(time_elapsed) % 60
	display_stat("游戏时长", "%d分%d秒" % [minutes, seconds])

## 显示一条统计信息
func display_stat(label_text: String, value_text: String) -> void:
	if not stats_container:
		return
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	stats_container.add_child(hbox)
	
	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size = Vector2(220, 30)
	hbox.add_child(label)
	
	var value = Label.new()
	value.text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(value)

## 继续按钮
func _on_continue_pressed() -> void:
	if GameManager:
		GameManager.go_to_main_menu()
