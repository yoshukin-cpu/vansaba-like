extends SceneTree
func _init() -> void:
	var sf := load("res://player/sprites/player_frames.tres") as SpriteFrames
	if sf == null:
		push_error("SpriteFrames load failed")
		quit(1)
		return
	for n in sf.get_animation_names():
		print(n, " frames=", sf.get_frame_count(n), " fps=", sf.get_animation_speed(n), " loop=", sf.get_animation_loop(n))
	quit()
