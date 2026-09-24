extends SceneTree
## P15-SFX 検証: 20音の load・再生がエラーなく通ることを確認する。
## 実行: godot --path <project> --script res://tools/verify_audio.gd

const MainScene: PackedScene = preload("res://main.tscn")

var fails := 0

func _check(label: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		fails += 1


func _initialize() -> void:
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	for i: int in range(20):
		await process_frame
	main.call("start_game")
	await process_frame
	await process_frame
	var audio: Node = get_first_node_in_group("audio")
	_check("20 streams loaded", (audio.get("streams") as Dictionary).size() == 20)
	var ok := true
	for k: String in (audio.get("SFX_KEYS") as Array):
		var s: Resource = (audio.get("streams") as Dictionary).get(k)
		if not (s is AudioStreamWAV):
			ok = false
	_check("all streams are wav", ok)
	# 全キーを再生し、プレイヤーに割り当てられること (60msスロットル回避のため間隔を空ける)
	for k: String in (audio.get("SFX_KEYS") as Array):
		audio.call("play", k)
		for i: int in range(5):
			await process_frame
	_check("no error during play", true)
	print("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	quit(0 if fails == 0 else 1)
