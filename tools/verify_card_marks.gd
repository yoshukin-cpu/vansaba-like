extends SceneTree
## カードマーク表示の検証: 24px生成・選択画面の大きめ表示・取得順の履歴表示。
## 実行: godot --headless --path <project> --script res://tools/verify_card_marks.gd -- --seed 0
## 全ケースPASSで終了コード0、失敗があれば1。

const MainScene: PackedScene = preload("res://main.tscn")
const CardsDB := preload("res://data/cards_db.gd")
const CardMarks := preload("res://data/card_marks.gd")

var fails := 0


func _check(label: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		fails += 1


func _initialize() -> void:
	_t_marks()
	await _t_levelup_and_history()
	print("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	quit(0 if fails == 0 else 1)


func _t_marks() -> void:
	print("\n=== 1) 24pxマーク生成 ===")
	var ids: Array = CardMarks.all_ids()
	_check("マークは20種+HEALの21種", ids.size() == 21)
	var sigs := {}
	for card_id: String in ids:
		var tex: Texture2D = CardMarks.texture_for(card_id)
		_check("%s の絵がある" % card_id, tex != null)
		if tex == null:
			continue
		_check("%s は24x24" % card_id, tex.get_width() == 24 and tex.get_height() == 24)
		var img: Image = (tex as ImageTexture).get_image()
		var opaque := 0
		for y: int in range(img.get_height()):
			for x: int in range(img.get_width()):
				if img.get_pixel(x, y).a >= 0.5:
					opaque += 1
		_check("%s に十分な画素がある (%d)" % [card_id, opaque], opaque >= 200)
		var sig: int = CardMarks.signature(card_id)
		_check("%s は他と別の絵" % card_id, not sigs.has(sig))
		sigs[sig] = card_id


func _t_levelup_and_history() -> void:
	print("\n=== 2) 選択画面と履歴表示 ===")
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	for i: int in range(20):
		await process_frame
	main.call("start_game")
	var player: Node2D = main.get_node("Player")
	player.set("max_hp", 1000000.0)
	player.set("hp", 1000000.0)
	player.set("xp_next", 1000000000)
	main.get_node("SpawnDirector").set("running", false)
	main.get_node("ChestDirector").set("running", false)
	for n: Node in get_nodes_in_group("enemies"):
		n.queue_free()
	for i: int in range(5):
		await process_frame

	var card_manager: Node = main.get_node("CardManager")
	var levelup: CanvasLayer = main.get_node("LevelUpUI")
	var offers: Array = card_manager.call("get_offers")
	_check("3枚提示される", offers.size() == 3)
	for e: Dictionary in offers:
		_check("%s の提示に絵が付く" % str(e["id"]), e.get("icon", null) != null)
	levelup.call("show_offers", offers)
	for i: int in range(3):
		await process_frame
	for i: int in range(3):
		var b: Button = levelup.get_node("Center/VBox/Cards/Btn%d" % i)
		var icon: TextureRect = b.get_node_or_null("Box/Mark") as TextureRect
		_check("カード%d に大きめの絵 (%s)" % [i + 1, str((offers[i] as Dictionary)["id"])],
			icon != null and icon.texture != null and icon.custom_minimum_size.x >= 96.0)
		_check("カード%d は絵+ラベル表示 (Button直書きなし)" % (i + 1), b.text == "")
		var brect: Rect2 = (b as Control).get_global_rect()
		var inside := true
		for part: String in ["Box/Mark", "Box/Name", "Box/Level", "Box/Detail"]:
			var c: Control = b.get_node_or_null(part) as Control
			if c == null:
				inside = false
				break
			var r: Rect2 = c.get_global_rect()
			if r.size.x <= 0.0 or r.size.y <= 0.0 or not brect.grow(1.0).encloses(r):
				inside = false
				break
		_check("カード%d の内容は枠内に収まる" % (i + 1), inside)

	var marks: GridContainer = main.get_node("HUD/AcquiredMarks")
	_check("履歴は初期状態で空", marks.get_child_count() == 0)
	_check("履歴は画面下部に固定", marks.anchor_top == 1.0 and marks.anchor_bottom == 1.0)
	var first: String = str((offers[0] as Dictionary)["id"])
	main.call("_on_card_chosen", first)
	for i: int in range(3):
		await process_frame
	var offers2: Array = card_manager.call("get_offers")
	levelup.call("show_offers", offers2)
	for i: int in range(3):
		await process_frame
	var second: String = str((offers2[0] as Dictionary)["id"])
	main.call("_on_card_chosen", second)
	for i: int in range(3):
		await process_frame
	_check("取得順に2件並ぶ", marks.get_child_count() == 2
		and str((marks.get_child(0) as TextureRect).get_meta("card_id")) == first
		and str((marks.get_child(1) as TextureRect).get_meta("card_id")) == second)
	for c: Node in marks.get_children():
		var r: TextureRect = c as TextureRect
		_check("履歴は24px表示 (%s)" % str(r.get_meta("card_id")),
			r.texture != null and r.custom_minimum_size == Vector2(24, 24))

	var chest: Node = main.get_node("ChestDirector")
	var before_t09: int = marks.get_child_count()
	chest.call("apply_item", "T09", player.global_position)
	for i: int in range(5):
		await process_frame
	var last_id := ""
	if marks.get_child_count() == before_t09 + 1:
		last_id = str((marks.get_child(marks.get_child_count() - 1) as TextureRect).get_meta("card_id"))
	_check("アイテム強化も履歴に入る (%s)" % last_id,
		marks.get_child_count() == before_t09 + 1 and (last_id == "C01" or last_id == "C02"))

	for i: int in range(60):
		main.call("_record_acquired_card", "HEAL")
	for i: int in range(5):
		await process_frame
	var total: int = marks.get_child_count()
	var columns: int = maxi(1, marks.columns)
	var rows: int = maxi(1, int(ceil(float(total) / float(columns))))
	var height: float = float(rows) * 24.0 + float(rows - 1) * 6.0
	_check("複数行になる (%d件/%d列/%d行)" % [total, columns, rows], rows > 1)
	_check("下端基準で行が伸びる", absf((-marks.offset_top - 12.0) - height) < 0.01)
	_check("末尾は最後の取得", str((marks.get_child(total - 1) as TextureRect).get_meta("card_id")) == "HEAL")

	var info: Label = main.get_node("HUD/InfoLabel")
	for i: int in range(3):
		await process_frame
	_check("デバッグ文は右下・履歴の上に集約", info.anchor_right == 1.0 and info.anchor_bottom == 1.0
		and info.offset_bottom <= marks.offset_top
		and info.text.contains("FPS") and info.text.contains("敵"))
