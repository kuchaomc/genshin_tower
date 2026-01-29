extends Node3D

@export var animation_player_path: NodePath = NodePath("AnimationPlayer")

func _ready() -> void:
	var animation_player := get_node_or_null(animation_player_path) as AnimationPlayer
	if animation_player == null:
		# 兜底：场景结构变动时避免报错。
		push_warning("[AyakaNormalAnimCombiner] AnimationPlayer not found: %s" % [String(animation_player_path)])
		return

	var library := animation_player.get_animation_library("")
	if library == null:
		# 兜底：AnimationPlayer 没有默认动画库时直接跳过。
		push_warning("[AyakaNormalAnimCombiner] Default AnimationLibrary is null")
		return

	# 将“身体/面部”两套动画合并成一个入口动画名，播放时即可同步。
	_combine_into(library, &"开心", &"开心身体", &"开心面部")
	_combine_into(library, &"害羞", &"害羞身体", &"害羞面部")


func _combine_into(library: AnimationLibrary, new_name: StringName, body_name: StringName, face_name: StringName) -> void:
	if library.has_animation(new_name):
		return
	if not library.has_animation(body_name):
		push_warning("[AyakaNormalAnimCombiner] Missing animation: %s" % [String(body_name)])
		return
	if not library.has_animation(face_name):
		push_warning("[AyakaNormalAnimCombiner] Missing animation: %s" % [String(face_name)])
		return

	var body_anim := library.get_animation(body_name)
	var face_anim := library.get_animation(face_name)
	if body_anim == null or face_anim == null:
		push_warning("[AyakaNormalAnimCombiner] Failed to get source animations: %s / %s" % [String(body_name), String(face_name)])
		return

	var combined := Animation.new()
	# 以两者较长者为准，避免播放到一半提前结束。
	combined.length = maxf(body_anim.length, face_anim.length)
	combined.loop_mode = body_anim.loop_mode

	_copy_tracks(body_anim, combined)
	_copy_tracks(face_anim, combined)

	library.add_animation(new_name, combined)


func _copy_tracks(source: Animation, target: Animation) -> void:
	var track_count := source.get_track_count()
	for track_index in track_count:
		var track_type := source.track_get_type(track_index)
		var new_track_index := target.add_track(track_type)
		target.track_set_path(new_track_index, source.track_get_path(track_index))
		target.track_set_interpolation_type(new_track_index, source.track_get_interpolation_type(track_index))
		target.track_set_loop_wrap(new_track_index, source.track_get_loop_wrap(track_index))
		target.track_set_enabled(new_track_index, source.track_get_enabled(track_index))

		var key_count := source.track_get_key_count(track_index)
		for key_index in key_count:
			var time := source.track_get_key_time(track_index, key_index)
			var value := source.track_get_key_value(track_index, key_index)
			var transition := source.track_get_key_transition(track_index, key_index)
			target.track_insert_key(new_track_index, time, value, transition)
