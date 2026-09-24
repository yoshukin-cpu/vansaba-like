extends SceneTree
## 「タイトルへ」選択時のエラー回帰テスト
## 実行: godot --path <project> --script res://tools/test_quit_to_title.gd
## 期待: SCRIPT ERROR が出力されず、両パスでシーンがリロードされる

func _init() -> void:
	# --- 1) ポーズメニュー → タイトルへ ---
	var main: Node = await _new_scene()
	var main_id: int = main.get_instance_id()
	main.call("start_game")
	for i in 30:
		await process_frame
	var pause_ev := InputEventAction.new()
	pause_ev.action = "pause_game"
	pause_ev.pressed = true
	main.call("_unhandled_input", pause_ev)
	await process_frame
	var pause_ui: Node = main.get_node("PauseUI")
	print("1) pause opened: visible=", pause_ui.visible)
	pause_ui.get_node("Center/VBox/QuitBtn").grab_focus()
	await process_frame
	_send_pad_a(pause_ui)
	for i in 30:
		await process_frame
	print("   -> scene reloaded: ", _is_new_scene(main_id))

	# --- 2) リザルト画面 (ゲームオーバー) → タイトルへ ---
	var main2: Node = current_scene
	var main2_id: int = main2.get_instance_id()
	main2.call("start_game")
	for i in 30:
		await process_frame
	main2.get_node("Player").call("take_damage", 9999.0)
	for i in 10:
		await process_frame
	var result_ui: Node = main2.get_node("ResultUI")
	print("2) game over shown: visible=", result_ui.visible)
	result_ui.get_node("Center/VBox/TitleBtn").grab_focus()
	await process_frame
	_send_pad_a(result_ui)
	for i in 30:
		await process_frame
	print("   -> scene reloaded: ", _is_new_scene(main2_id))

	print("done (SCRIPT ERROR が出ていなければ修正成功)")
	quit()


func _new_scene() -> Node:
	var m: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(m)
	current_scene = m
	await process_frame
	await process_frame
	return m


func _send_pad_a(ui: Node) -> void:
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	ui.call("_unhandled_input", a)


func _is_new_scene(old_id: int) -> bool:
	return current_scene != null and current_scene.get_instance_id() != old_id
