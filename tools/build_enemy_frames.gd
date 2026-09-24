extends SceneTree
## 敵の SpriteFrames (down/up 各2フレーム) を一括生成する
## 実行: godot --headless --path <project> --script res://tools/build_enemy_frames.gd

const DIR := "res://enemies/sprites/"

const ENEMIES := ["slime", "bat", "goblin", "archer", "wolf", "golem", "splitter", "sniper", "swarm", "knight"]
const BOSSES := ["golem_king", "void_emperor"]


func _init() -> void:
	var missing := 0
	for e: String in ENEMIES:
		missing += _build("%s_frames.tres" % e, [
			"enemy_%s_0.png" % e, "enemy_%s_1.png" % e,
			"enemy_%s_b0.png" % e, "enemy_%s_b1.png" % e,
		])
	for b: String in BOSSES:
		missing += _build("boss_%s_frames.tres" % b, [
			"boss_%s_f0.png" % b, "boss_%s_f1.png" % b,
			"boss_%s_b0.png" % b, "boss_%s_b1.png" % b,
		])
	print("done. missing=", missing)
	quit(0 if missing == 0 else 1)


func _build(out_name: String, files: Array) -> int:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var missing := 0
	missing += _add_anim(sf, "down", [files[0], files[1]])
	missing += _add_anim(sf, "up", [files[2], files[3]])
	var err := ResourceSaver.save(sf, DIR + out_name)
	if err != OK:
		push_error("save failed: " + out_name)
		return missing + 1
	print("saved ", out_name)
	return missing


func _add_anim(sf: SpriteFrames, anim: String, files: Array) -> int:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, 6.0)
	sf.set_animation_loop(anim, true)
	var missing := 0
	for f: String in files:
		var path := DIR + String(f)
		if not ResourceLoader.exists(path):
			push_error("not found: " + path)
			missing += 1
			continue
		sf.add_frame(anim, load(path))
	return missing
