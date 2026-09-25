extends SceneTree
## v1.4 検証: ラン単位の地形シード (毎回異なるマップ) と地形生成の品質。
## 実行: godot --headless --path <project> --script res://tools/verify_seed.gd
## 全ケースPASSで終了コード0、失敗があれば1。

const CG := preload("res://world/chunk_gen.gd")
const HN := preload("res://world/hash_noise.gd")
const MainScene: PackedScene = preload("res://main.tscn")

## 被覆率・密度の判定帯 (SPEC §17.3: 目標15〜25%、README検証値 18.6% / 2.61%)
const COVER_MIN: float = 10.0
const COVER_MAX: float = 35.0
const DENS_MIN: float = 1.2
const DENS_MAX: float = 4.5
## サンプリング: 周期 9x9 チャンクから 3x3 を等間隔に取る
const SAMPLE_CHUNKS: Array = [[0, 0], [0, 3], [0, 6], [3, 0], [3, 3], [3, 6], [6, 0], [6, 3], [6, 6]]

var fails := 0


func _check(label: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		fails += 1


func _initialize() -> void:
	_t_determinism()
	_t_variety()
	_t_quality()
	_t_hash_uniform()
	await _t_game_seed()
	print("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	quit(0 if fails == 0 else 1)


## 1) 同じシードなら同じ地形 (決定論) / シードを変えると別地形
func _t_determinism() -> void:
	print("\n=== 1) 決定論 ===")
	CG.begin_run(0)
	var g0: PackedInt32Array = CG.generate_chunk(2, -1)["ground"]
	var o0: Array = CG.generate_chunk(2, -1)["obstacles"]
	# 同じシードを再設定 (キャッシュを捨てて作り直す) → 完全に同じ
	CG.begin_run(424242)
	var g1: PackedInt32Array = CG.generate_chunk(2, -1)["ground"]
	var o1: Array = CG.generate_chunk(2, -1)["obstacles"]
	CG.begin_run(424242)
	var g2: PackedInt32Array = CG.generate_chunk(2, -1)["ground"]
	var o2: Array = CG.generate_chunk(2, -1)["obstacles"]
	_check("同じシード → 同じ地面 (キャッシュを作り直しても)", g1 == g2)
	_check("同じシード → 同じ障害物", str(o1) == str(o2))
	_check("シードを変えると地面が変わる", g1 != g0)
	_check("シードを変えると障害物が変わる", str(o1) != str(o0))
	var diff: int = 0
	for i: int in range(g0.size()):
		if g0[i] != g1[i]:
			diff += 1
	print("  地面の差分: %d / %d セル (%.1f%%)" % [diff, g0.size(), 100.0 * float(diff) / float(g0.size())])
	_check("地面の 50%% 以上が別タイル (>%d セル)" % (g0.size() / 2), diff > g0.size() / 2)
	# 同一ラン内では安定
	_check("同一ラン内で地形が変わらない", CG.generate_chunk(5, 5)["ground"] == CG.generate_chunk(5, 5)["ground"])
	# 周期性 (チャンクキーが周期に畳まれる) はシードに依らず維持される
	_check("周期性 (周期ぶんずらすと同じ)",
		CG.generate_chunk(2, -1)["ground"] == CG.generate_chunk(2 + CG.CHUNKS_PER_PERIOD, -1)["ground"])


## 2) シードを変えるとマップがまるごと変わる (毎回異なるマップ)
func _t_variety() -> void:
	print("\n=== 2) シード違いで別のマップ (1周期 81チャンクを全走査) ===")
	var seeds: Array = [0, 1, 2, 12345, 20260924, 2147483647]
	var sigs: Dictionary = {}
	var cover_min: float = 100.0
	var cover_max: float = 0.0
	var dens_min: float = 100.0
	var dens_max: float = 0.0
	for s: int in seeds:
		CG.begin_run(s)
		var cov: float = _coverage()
		var dens: float = _density()
		var sig: int = _signature()
		cover_min = minf(cover_min, cov)
		cover_max = maxf(cover_max, cov)
		dens_min = minf(dens_min, dens)
		dens_max = maxf(dens_max, dens)
		print("  seed %-10d 荒野 %5.1f%% / 障害物 %4.2f%% / sig %d" % [s, cov, dens, sig])
		_check("seed %d が既存シードと別のマップ" % s, not sigs.has(sig))
		sigs[sig] = s
		_check("seed %d: 被覆率が帯内 (%.1f%%)" % [s, cov], cov >= COVER_MIN and cov <= COVER_MAX)
		_check("seed %d: 障害物密度が帯内 (%.2f%%)" % [s, dens], dens >= DENS_MIN and dens <= DENS_MAX)
	print("  被覆率の幅: %.1f%% 〜 %.1f%% / 密度の幅: %.2f%% 〜 %.2f%%" % [cover_min, cover_max, dens_min, dens_max])


## 3) シードを変えても品質が落ちない
func _t_quality() -> void:
	print("\n=== 3) 品質 (seed 0 = v1.3 までの地形と同一) ===")
	CG.begin_run(0)
	var c0: float = _coverage()
	var d0: float = _density()
	print("  seed 0 (1周期 81チャンク): 荒野 %.1f%% / 障害物 %.2f%%" % [c0, d0])
	_check("seed 0 の被覆率 18.6%% (実測 %.1f%%)" % c0, absf(c0 - 18.6) < 0.15)
	_check("seed 0 の密度 2.61%% (実測 %.2f%%)" % d0, absf(d0 - 2.61) < 0.05)

	print("  16 シードの統計:")
	var total_cov: float = 0.0
	var total_dens: float = 0.0
	var lo: float = 100.0
	var hi: float = 0.0
	var n: int = 16
	for i: int in range(n):
		CG.begin_run(1000 + i * 7919)
		var c: float = _coverage()
		var d: float = _density()
		total_cov += c
		total_dens += d
		lo = minf(lo, c)
		hi = maxf(hi, c)
		print("    seed %-9d 荒野 %5.1f%% / 障害物 %4.2f%%" % [1000 + i * 7919, c, d])
		_check("seed %d: 被覆率が帯内 (%.1f%%)" % [1000 + i * 7919, c], c >= COVER_MIN and c <= COVER_MAX)
		_check("seed %d: 密度が帯内 (%.2f%%)" % [1000 + i * 7919, d], d >= DENS_MIN and d <= DENS_MAX)
	var cov: float = total_cov / float(n)
	var dens: float = total_dens / float(n)
	print("  %d種の平均: 荒野 %.1f%% (%.1f〜%.1f%%) / 障害物 %.2f%%" % [n, cov, lo, hi, dens])
	_check("平均被覆率が目標帯 (15〜25%%) 内 (%.1f%%)" % cov, cov >= 15.0 and cov <= 25.0)
	_check("平均障害物密度が 2〜3.5%% 内 (%.2f%%)" % dens, dens >= 2.0 and dens <= 3.5)


## 4) ハッシュの分布が偏っていない (シードを混ぜても品質が落ちていない)
func _t_hash_uniform() -> void:
	print("\n=== 4) ハッシュ分布 ===")
	for s: int in [0, 12345, 2147483647]:
		HN.set_run_seed(s)
		var bins := PackedInt32Array()
		bins.resize(10)
		var total: float = 0.0
		for x: int in range(200):
			for y: int in range(100):
				var v: float = HN.f2(x, y, 1101)
				total += v
				bins[mini(9, int(v * 10.0))] += 1
		var mean: float = total / 20000.0
		var worst: float = 0.0
		for b: int in bins:
			worst = maxf(worst, absf(float(b) / 2000.0 - 1.0) * 100.0)
		print("  seed %-10d 平均 %.3f / 最悪ビン偏差 %.1f%%" % [s, mean, worst])
		_check("seed %d: 平均が 0.5±0.02 (%.3f)" % [s, mean], absf(mean - 0.5) < 0.02)
		_check("seed %d: 10ビンの偏りが 15%% 以内 (%.1f%%)" % [s, worst], worst <= 15.0)


## 5) ゲーム起動時: ランごとに違うシードが入る / --seed で固定できる
func _t_game_seed() -> void:
	print("\n=== 5) ゲーム起動時のシード ===")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var fixed: int = -1
	for i: int in range(args.size() - 1):
		if args[i] == "--seed" and args[i + 1].is_valid_int():
			fixed = args[i + 1].to_int()
	var seen: Array = []
	for i: int in range(2):
		var m: Node = MainScene.instantiate()
		root.add_child(m)
		current_scene = m
		for j: int in range(10):
			await process_frame
		seen.append(HN.run_seed & 0x7FFFFFFF)
		_check("World が地形を生成している (seed %d)" % HN.run_seed, _placed_cells() > 10000)
		m.queue_free()
		await process_frame
		await process_frame
	print("  ラン 1/2 のシード: %d / %d (起動引数 %s)" % [
		seen[0], seen[1], ("--seed %d" % fixed) if fixed >= 0 else "なし"])
	if fixed >= 0:
		_check("--seed %d がそのまま使われる" % fixed, seen[0] == fixed and seen[1] == fixed)
	else:
		_check("ランごとに違うシード (毎回異なるマップ)", seen[0] != seen[1])


func _placed_cells() -> int:
	var world: Node = current_scene.get_node("World")
	var ground: TileMapLayer = world.get("ground") as TileMapLayer
	if ground == null:
		return 0
	return ground.get_used_cells().size()


## サンプル 9 チャンクの地面タイル配列から作る安定な署名
func _signature() -> int:
	var h: int = 17
	for c: Array in SAMPLE_CHUNKS:
		var d: Dictionary = CG.generate_chunk(int(c[0]), int(c[1]))
		var g: PackedInt32Array = d["ground"]
		for i: int in range(0, g.size(), 7):
			h = (h * 31 + g[i]) & 0x7FFFFFFF
		h = (h * 31 + (d["obstacles"] as Array).size()) & 0x7FFFFFFF
	return h


## 荒野の被覆率 (%)。1周期 81 チャンクを全走査する (部分サンプルは偏るため)。
func _coverage() -> float:
	var waste: int = 0
	var total: int = 0
	for c: Array in _chunks():
		var g: PackedInt32Array = CG.generate_chunk(int(c[0]), int(c[1]))["ground"]
		for t: int in g:
			total += 1
			if t >= CG.G_WASTE and t < CG.G_GRAVEL:
				waste += 1
	return float(waste) * 100.0 / float(total)


## 障害物密度 (%)。1周期 81 チャンクを全走査する。
func _density() -> float:
	var obs: int = 0
	var total: int = 0
	for c: Array in _chunks():
		var d: Dictionary = CG.generate_chunk(int(c[0]), int(c[1]))
		obs += (d["obstacles"] as Array).size()
		total += CG.CHUNK * CG.CHUNK
	return float(obs) * 100.0 / float(total)


func _chunks() -> Array:
	var all: Array = []
	for cy: int in range(CG.CHUNKS_PER_PERIOD):
		for cx: int in range(CG.CHUNKS_PER_PERIOD):
			all.append([cx, cy])
	return all
