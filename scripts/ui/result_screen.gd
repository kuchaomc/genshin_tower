extends Node2D

## 结算界面脚本

@onready var victory_label: Label = $CanvasLayer/VBoxContainer/TitleLabel
@onready var stats_container: VBoxContainer = $CanvasLayer/VBoxContainer/StatsContainer
@onready var continue_button: Button = $CanvasLayer/VBoxContainer/ContinueButton

var run_record: Dictionary = {}

func _ready() -> void:
	load_run_record()
	display_results()
	
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)

	# 如果是从战斗胜利转场进入结算界面，需要把黑屏淡入撤掉
	# 约定：发起方只负责 fade_out；目标场景在 _ready() 检测 is_transitioning 后执行 fade_in
	if TransitionManager != null and TransitionManager.is_transitioning:
		await TransitionManager.fade_in(0.4)

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
	stats_container.add_child(hbox)
	
	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size = Vector2(150, 30)
	hbox.add_child(label)
	
	var value = Label.new()
	value.text = value_text
	hbox.add_child(value)

## 继续按钮
func _on_continue_pressed() -> void:
	if GameManager:
		GameManager.go_to_main_menu()
