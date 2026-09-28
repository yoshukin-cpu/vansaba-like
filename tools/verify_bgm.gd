extends SceneTree
## P21 検証: v1.8 BGM (SPEC §35.1) — 3曲・ループ・BGMバス・状態遷移・フェード・
## フェードアウト位置からの再開・paused 中も鳴り続ける。
## 実行: godot --headless --fixed-fps 60 --path <project> --script res://tools/verify_bgm.gd
## 全ケースPASSで終了コード0、失敗があれば1。

const SaveData := preload("res://systems/save_data.gd")
const BgmScript := preload("res://systems/bgm_manager.gd")
const MainScene: PackedScene = preload("res://main.tscn")
const B01Scene: PackedScene = preload("res://enemies/boss_golem_king.tscn")

const TEST_SAVE := "user://test_bgm_save.json"

var failures := 0


func _check(label: String, ok: bool) -> void:
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)


func _frames(n: int) -> void:
	for i: int in range(n):
		await process_frame


func _remove_save() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)


func _init() -> void:
	SaveData.path = TEST_SAVE
	_remove_save()
	_t_static()
	await _t_states()
	# 後始末 (テストが実セーブを汚さない)
	SaveData.path = SaveData.DEFAULT_PATH
	SaveData.reset()
	_remove_save()
	print("RESULT: ", "ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures)
	quit(1 if failures > 0 else 0)


# === 1) 曲とバス ===

func _t_static() -> void:
	print("\n=== 1) 曲とバス ===")
	for k: String in ["title", "game", "boss"]:
		var path: String = str(BgmScript.TRACKS[k])
		_check("%s の曲が存在 (%s)" % [k, path.get_file()], ResourceLoader.exists(path))
		var s: AudioStream = load(path)
		_check("%s は MP3" % k, s is AudioStreamMP3)
	_check("BGM バスがある", AudioServer.get_bus_index("BGM") >= 0)
	_check("SE バスがある", AudioServer.get_bus_index("SE") >= 0)
	_check("基準音量 title -8 / game -10 / boss -10 (D80)",
		float(BgmScript.TRACK_DB["title"]) == -8.0
		and float(BgmScript.TRACK_DB["game"]) == -10.0
		and float(BgmScript.TRACK_DB["boss"]) == -10.0)


# === 2) 状態遷移・フェード・再開 ===

func _t_states() -> void:
	print("\n=== 2) 状態遷移・フェード・再開 ===")
	SaveData.reset()
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(3)
	var bgm: Node = main.get_node("BGM")
	var pt: AudioStreamPlayer = bgm.get_node("BgmTitle")
	var pg: AudioStreamPlayer = bgm.get_node("BgmGame")
	var pb: AudioStreamPlayer = bgm.get_node("BgmBoss")

	_check("タイトルで title 状態", int(bgm.get("state")) == BgmScript.State.TITLE)
	_check("タイトル曲が鳴っている", pt.playing)
	for pl: AudioStreamPlayer in [pt, pg, pb]:
		_check("%s: ループ有効" % pl.name, (pl.stream as AudioStreamMP3).loop)
		_check("%s: バス = BGM" % pl.name, pl.bus == "BGM")
		_check("%s: process_mode ALWAYS" % pl.name, pl.process_mode == Node.PROCESS_MODE_ALWAYS)
	await _frames(60)
	_check("title のフェードイン完了 ≈ -8dB (%.2f)" % pt.volume_db, absf(pt.volume_db - (-8.0)) <= 0.3)

	# ゲーム開始: title をフェードアウトして game を頭から
	main.call("start_game")
	await _frames(6)
	_check("game 状態", int(bgm.get("state")) == BgmScript.State.GAME)
	_check("ゲーム曲が鳴っている", pg.playing)
	await _frames(55)
	_check("game のフェードイン完了 ≈ -10dB (%.2f)" % pg.volume_db, absf(pg.volume_db - (-10.0)) <= 0.3)
	_check("title はフェードアウトして停止", not pt.playing)

	# ボス出現 → boss (フェードアウト時に再生位置を保存する)
	var boss: Node2D = B01Scene.instantiate()
	main.add_child(boss)
	await _frames(6)
	_check("ボス出現で boss 状態", int(bgm.get("state")) == BgmScript.State.BOSS)
	_check("ボス曲が鳴っている", pb.playing)
	var saved_pos: float = float(bgm.get("game_pos"))
	_check("切替時に再生位置を保存 (%.3f > 0)" % saved_pos, saved_pos > 0.0)

	# ボス撃破 (除去) → game を保存位置から再開
	boss.queue_free()
	await _frames(6)
	_check("ボス消滅で game 状態", int(bgm.get("state")) == BgmScript.State.GAME)
	_check("ゲーム曲が再開している", pg.playing)
	_check("再開位置は保存値 %.3f (%.3f)" % [saved_pos, float(bgm.get("last_resume_pos"))],
		absf(float(bgm.get("last_resume_pos")) - saved_pos) <= 0.001)

	# paused (レベルアップ/ポーズ相当) でも鳴り続け、フェードも進む
	main.call("start_game")
	await _frames(3)
	paused = true
	var v0: float = pg.volume_db
	await _frames(30)
	_check("paused 中も鳴っている", pg.playing)
	_check("paused 中もフェードが進む (%.2f → %.2f)" % [v0, pg.volume_db], pg.volume_db > v0)
	paused = false

	# 長時間ループ後 (web の get_playback_position() は曲長を超える値を返す) でも
	# 範囲内の位置で再開する (P25・Web 不具合修正)。
	var glen: float = pg.stream.get_length()
	_check("game 曲長が取れる (%.1fs)" % glen, glen > 30.0)
	var forced: float = glen * 3.0 + 12.5
	bgm.set("game_elapsed", forced)
	var boss2: Node2D = B01Scene.instantiate()
	main.add_child(boss2)
	await _frames(6)
	_check("再出現で boss 状態", int(bgm.get("state")) == BgmScript.State.BOSS)
	var wrapped: float = fposmod(forced, glen)
	var gp2: float = float(bgm.get("game_pos"))
	_check("保存位置が曲長未満に畳まれる (%.3f < %.3f)" % [gp2, glen], gp2 < glen)
	_check("保存位置は曲長で折り返した値 ≈ %.3f (%.3f)" % [wrapped, gp2], absf(gp2 - wrapped) <= 0.6)
	boss2.queue_free()
	await _frames(6)
	var rp2: float = float(bgm.get("last_resume_pos"))
	_check("再開位置も曲長未満 (%.3f < %.3f)" % [rp2, glen], rp2 < glen)
	_check("再開位置は保存位置と一致 (%.3f)" % rp2, absf(rp2 - gp2) <= 0.001)
	_check("ゲーム曲が再開している (2回目)", pg.playing)

	# 曲尾の直前 (最後の 0.5s) は頭に回す (web の再ループが offset 起点のため)。
	_check("曲尾直前は頭に回す (%.3f → 0)" % (glen - 0.2), bgm.call("_wrap_pos", glen - 0.2) == 0.0)
	_check("曲尾から離れた位置はそのまま (%.3f)" % (glen * 0.5), absf(float(bgm.call("_wrap_pos", glen * 0.5)) - glen * 0.5) <= 0.001)

	# 死亡/クリア確定 → 無音 (フェードアウト)
	main.call("show_result", false)
	await _frames(90)
	_check("リザルトで無音 (3曲とも停止)", not pt.playing and not pg.playing and not pb.playing)
	_check("state = SILENT", int(bgm.get("state")) == BgmScript.State.SILENT)
