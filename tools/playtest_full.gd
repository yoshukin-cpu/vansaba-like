extends SceneTree
## P12 計測: 10分通しプレイを8倍速で自動操作し、バランス指標を30秒ごとに記録する。
## 実行: godot --path <project> --script res://tools/playtest_full.gd
## 自動操作: 逃げ + 探索周回。レベルアップは1枚目を自動選択 (ビルドはランダム)。
## 終了: Clear / GameOver / 11分経過でログを出して quit(0)。

const SPEED := 3.0
const LOG_EVERY := 30.0
const END_AT := 660.0
const FLEE_RANGE := 350.0


func _init() -> void:
	Engine.time_scale = SPEED
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	main.call("start_game")
	# 比較用: --nochest で宝箱なしベースラインを計測する
	if "--nochest" in OS.get_cmdline_user_args():
		main.get_node("ChestDirector").set("running", false)
		print("mode: NO CHEST baseline")
	else:
		print("mode: with chests")
	# 安定性証明用: --godmode で不死にして11分走行する (バランス評価ではなく、
	# 全時間帯・両ボス・全アイテム経路をエラーなく通すことが目的)
	if "--godmode" in OS.get_cmdline_user_args():
		print("mode: GODMODE stability run")
	var player: Node2D = main.get_node("Player")
	var director: Node = main.get_node("SpawnDirector")
	if "--godmode" in OS.get_cmdline_user_args():
		player.set("max_hp", 1000000.0)
		player.set("hp", 1000000.0)
	var levelup: CanvasLayer = main.get_node("LevelUpUI")
	var pool: Node = main.get_node("PoolGems")
	print("t enemies hp lv kills score gems chests fps")
	var dirs := ["move_left", "move_right", "move_up", "move_down"]
	var next_log := LOG_EVERY
	var frames := 0
	var min_fps := 1e9
	while true:
		# 逃げ行動: 最寄りの敵から離れる (+少し旋回)。敵が遠ければ緩やかに周回して探索。
		_steer(player, float(director.get("elapsed")))
		await process_frame
		frames += 1
		# レベルアップは1枚目を即選択 (複数溜まり対応)
		var guard := 0
		while bool(levelup.visible) and guard < 8:
			var offers: Array = levelup.get("offers")
			if offers.is_empty():
				break
			levelup.call("_on_btn", 0)
			guard += 1
			await process_frame
			frames += 1
		var t: float = float(director.get("elapsed"))
		min_fps = minf(min_fps, float(Engine.get_frames_per_second()))
		if t >= next_log or bool(main.get("result_shown")):
			print("%3.0f %7d %3.0f %2d %5d %5d %4d %6d %3.0f" % [
				t, get_nodes_in_group("enemies").size(),
				float(player.get("hp")), int(player.get("level")),
				int(main.get("kills")), int(main.get("score")),
				_active_gems(pool), get_nodes_in_group("chests").size(),
				float(Engine.get_frames_per_second()),
			])
			next_log += LOG_EVERY
		if bool(main.get("result_shown")):
			break
		if t >= END_AT:
			print("TIMEOUT enemy_boss_alive")
			break
	for a: String in dirs:
		Input.action_release(a)
	Engine.time_scale = 1.0
	print("end: dead=%s clear=%s t=%.0f lv=%d kills=%d score=%d min_fps=%.0f" % [
		str(player.get("dead")), str(not bool(player.get("dead")) and bool(main.get("result_shown"))),
		float(director.get("elapsed")), int(player.get("level")),
		int(main.get("kills")), int(main.get("score")), min_fps,
	])
	print("playtest done")
	quit()


func _active_gems(pool: Node) -> int:
	var n := 0
	for g: Node in get_nodes_in_group("gems"):
		if bool(g.get("active")):
			n += 1
	return n


## 自動操作: 脅威から逃げ、平時は周回。Input の強度付き押しでアナログ移動する。
func _steer(player: Node2D, t: float) -> void:
	var pp: Vector2 = player.global_position
	var best: Node2D = null
	var best_d := FLEE_RANGE
	for n: Node in get_nodes_in_group("enemies"):
		if not (n is Node2D):
			continue
		if bool(n.get("dead")):
			continue
		var d: float = ((n as Node2D).global_position - pp).length()
		if d < best_d:
			best_d = d
			best = n as Node2D
	var vec: Vector2
	if best != null:
		vec = (pp - best.global_position).normalized().rotated(0.45)
	else:
		vec = Vector2.RIGHT.rotated(t * 0.12)
	for a: String in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if vec.x < -0.05:
		Input.action_press("move_left", minf(1.0, -vec.x))
	elif vec.x > 0.05:
		Input.action_press("move_right", minf(1.0, vec.x))
	if vec.y < -0.05:
		Input.action_press("move_up", minf(1.0, -vec.y))
	elif vec.y > 0.05:
		Input.action_press("move_down", minf(1.0, vec.y))
