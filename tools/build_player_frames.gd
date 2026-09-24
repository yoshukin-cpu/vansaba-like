extends SceneTree
## player/sprites/ 以下のフレームPNGから SpriteFrames リソースを構築して保存する。
## 実行: godot --headless --path <project> --script res://tools/build_player_frames.gd

const SPRITES_DIR := "res://player/sprites/"
const OUT_PATH := "res://player/sprites/player_frames.tres"

const DIRECTIONS := ["down", "left", "right", "up"]
const WALK_FRAMES := 4
const IDLE_FRAMES := 2


func _init() -> void:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var missing := 0

	for d: String in DIRECTIONS:
		var walk: String = "walk_" + d
		sf.add_animation(walk)
		sf.set_animation_speed(walk, 8.0)
		sf.set_animation_loop(walk, true)
		for i in WALK_FRAMES:
			var tex := _load_frame("player_walk_%s_%d.png" % [d, i])
			if tex == null:
				missing += 1
			else:
				sf.add_frame(walk, tex)

		var idle: String = "idle_" + d
		sf.add_animation(idle)
		sf.set_animation_speed(idle, 2.5)
		sf.set_animation_loop(idle, true)
		for i in IDLE_FRAMES:
			var tex2 := _load_frame("player_idle_%s_%d.png" % [d, i])
			if tex2 == null:
				missing += 1
			else:
				sf.add_frame(idle, tex2)

	if missing > 0:
		push_error("missing frames: %d" % missing)

	var err := ResourceSaver.save(sf, OUT_PATH)
	if err != OK:
		push_error("save failed: %d" % err)
	else:
		print("saved: ", OUT_PATH, " animations=", sf.get_animation_names())
	quit(0 if missing == 0 and err == OK else 1)


func _load_frame(file_name: String) -> Texture2D:
	var path := SPRITES_DIR + file_name
	if not ResourceLoader.exists(path):
		push_error("not found: " + path)
		return null
	return load(path) as Texture2D
