extends SceneTree
## P8 検証: 地形生成の決定論・周期性・密度・速度を headless で確認する。
## 実行: godot --headless --path <project> --script res://tools/verify_world.gd

const CG := preload("res://world/chunk_gen.gd")


func _init() -> void:
	var fails: int = 0

	# 0) 起動時の LUT 構築コスト
	var tl: int = Time.get_ticks_msec()
	CG.biome_lut()
	print("biome LUT build: %d ms (起動時に1回)" % (Time.get_ticks_msec() - tl))

	# 1) 周期性: 周期ぶんずらしても同じ内容 (障害物のハッシュも周期座標で計算されている)
	for cx: int in range(-3, 4):
		for cy: int in range(-3, 4):
			var a: Dictionary = CG.generate_chunk(cx, cy)
			var b: Dictionary = CG.generate_chunk(cx + CG.CHUNKS_PER_PERIOD, cy + CG.CHUNKS_PER_PERIOD)
			if not _same_chunk(a, b):
				fails += 1
				print("FAIL periodicity %d,%d" % [cx, cy])

	# 2) チャンクキーの折り返し
	if CG.chunk_key(-1, -1) != Vector2i(CG.CHUNKS_PER_PERIOD - 1, CG.CHUNKS_PER_PERIOD - 1):
		fails += 1
		print("FAIL chunk_key(-1,-1) = ", CG.chunk_key(-1, -1))

	# 3) 1周期ぶんの被覆率・障害物密度
	var grass: int = 0
	var waste: int = 0
	var gravel: int = 0
	var decor: int = 0
	var obstacle_count: int = 0
	var trees: int = 0
	var rocks: int = 0
	for cy: int in range(CG.CHUNKS_PER_PERIOD):
		for cx: int in range(CG.CHUNKS_PER_PERIOD):
			var d: Dictionary = CG.generate_chunk(cx, cy)
			var g: PackedInt32Array = d["ground"] as PackedInt32Array
			for v: int in g:
				if v < CG.G_WASTE:
					grass += 1
				elif v < CG.G_GRAVEL:
					waste += 1
				elif v < CG.G_DECOR:
					gravel += 1
				else:
					decor += 1
			for ob: Dictionary in (d["obstacles"] as Array):
				obstacle_count += 1
				if int(ob["tile"]) < CG.O_ROCK:
					trees += 1
				else:
					rocks += 1
	var total: int = grass + waste + gravel + decor
	print("--- 1周期 (%d x %d セル) ---" % [CG.PERIOD_TILES, CG.PERIOD_TILES])
	print("草原 %d (%.1f%%) / 荒野 %d (%.1f%%) / 砂利 %d (%.1f%%) / 装飾 %d (%.1f%%)" % [
		grass, 100.0 * float(grass) / float(total),
		waste, 100.0 * float(waste) / float(total),
		gravel, 100.0 * float(gravel) / float(total),
		decor, 100.0 * float(decor) / float(total),
	])
	print("障害物 %d (%.2f%% of cells)  木 %d / 岩 %d" % [
		obstacle_count, 100.0 * float(obstacle_count) / float(total), trees, rocks,
	])
	if waste * 100 / total < 10 or waste * 100 / total > 30:
		fails += 1
		print("FAIL 荒野の被覆率が目標 (15-25%%) から外れている")
	if obstacle_count * 10000 / total < 100 or obstacle_count * 10000 / total > 500:
		fails += 1
		print("FAIL 障害物密度が想定 (1-5%%) から外れている")

	# 4) 開始地点の周囲に障害物が無い
	var near: int = 0
	for cy: int in range(-1, 2):
		for cx: int in range(-1, 2):
			for ob: Dictionary in (CG.generate_chunk(cx, cy)["obstacles"] as Array):
				var cell: Vector2i = (ob["cell"] as Vector2i) + Vector2i(cx * CG.CHUNK, cy * CG.CHUNK)
				if Vector2(float(cell.x), float(cell.y)).length() < CG.SPAWN_CLEAR:
					near += 1
	if near > 0:
		fails += 1
		print("FAIL 開始地点の周囲に障害物が %d 個ある" % near)

	# 5) 生成コスト
	var t0: int = Time.get_ticks_msec()
	CG.biome_lut()
	print("biome LUT build: %d ms (起動時に1回)" % (Time.get_ticks_msec() - t0))
	t0 = Time.get_ticks_msec()
	var n: int = 300
	for i: int in range(n):
		CG.generate_chunk(randi_range(-40, 40), randi_range(-40, 40))
	var ms: float = float(Time.get_ticks_msec() - t0) / float(n)
	print("generate_chunk: %.2f ms/call" % ms)
	if ms > 6.0:
		fails += 1
		print("FAIL 生成が遅い (目標 < 3ms)")

	print("RESULT: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)


func _same_chunk(a: Dictionary, b: Dictionary) -> bool:
	var ga: PackedInt32Array = a["ground"] as PackedInt32Array
	var gb: PackedInt32Array = b["ground"] as PackedInt32Array
	if ga.size() != gb.size():
		return false
	for i: int in range(ga.size()):
		if ga[i] != gb[i]:
			return false
	var oa: Array = a["obstacles"] as Array
	var ob2: Array = b["obstacles"] as Array
	if oa.size() != ob2.size():
		return false
	for i: int in range(oa.size()):
		if (oa[i]["cell"] as Vector2i) != (ob2[i]["cell"] as Vector2i):
			return false
		if int(oa[i]["tile"]) != int(ob2[i]["tile"]):
			return false
	return true
