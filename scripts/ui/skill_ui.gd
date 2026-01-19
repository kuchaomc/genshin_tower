extends Control
class_name SkillUI

## 技能UI组件
## 显示技能图标和冷却时间

@onready var icon_texture: TextureRect = $IconTexture
@onready var cooldown_overlay: ColorRect = $CooldownOverlay
@onready var cooldown_label: Label = $CooldownLabel

var skill_icon: Texture2D
var max_cooldown: float = 10.0
var current_cooldown: float = 0.0

func _ready() -> void:
	if icon_texture:
		if skill_icon:
			icon_texture.texture = skill_icon
		else:
			# 如果没有设置图标，尝试加载默认图标
			var default_icon = load("res://textures/神里技能图标.png")
			if default_icon:
				icon_texture.texture = default_icon
	
	_update_display()

## 设置技能图标
func set_skill_icon(texture: Texture2D) -> void:
	skill_icon = texture
	if icon_texture:
		icon_texture.texture = texture

## 更新冷却时间
func update_cooldown(remaining_time: float, cooldown_time: float) -> void:
	current_cooldown = remaining_time
	max_cooldown = cooldown_time
	_update_display()

## 更新显示
func _update_display() -> void:
	if not cooldown_overlay or not cooldown_label:
		return
	
	if current_cooldown > 0.0 and max_cooldown > 0.0:
		# 显示冷却遮罩
		var progress = current_cooldown / max_cooldown
		cooldown_overlay.visible = true
		cooldown_overlay.color.a = 0.6  # 半透明遮罩
		
		# 更新冷却时间文本
		cooldown_label.visible = true
		cooldown_label.text = "%.1f" % current_cooldown
		
		# 更新遮罩位置（从下往上覆盖）
		var parent_size = cooldown_overlay.get_parent().size
		cooldown_overlay.size = Vector2(parent_size.x, parent_size.y * progress)
		cooldown_overlay.position = Vector2(0, parent_size.y * (1.0 - progress))
		
		# 降低图标透明度
		if icon_texture:
			icon_texture.modulate.a = 0.5
	else:
		# 技能可用
		cooldown_overlay.visible = false
		cooldown_label.visible = false
		if icon_texture:
			icon_texture.modulate.a = 1.0
