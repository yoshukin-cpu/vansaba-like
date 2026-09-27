extends RefCounted
## カード選択と取得履歴で使う 24x24 ドット絵マークの生成器。
## 拡大表示しても輪郭が崩れないよう、1px単位の図形だけで描く。
## カード側は大きめ (約112pxへニアレスト拡大)、取得履歴側は24pxのまま並べる。

const CardsDB := preload("res://data/cards_db.gd")

const MARK_SIZE := 24

const INK := Color(0.07, 0.08, 0.12)
const PAPER := Color(0.93, 0.94, 0.97)
const STEEL_FILL := Color(0.16, 0.19, 0.27)
const STEEL_EDGE := Color(0.55, 0.60, 0.72)
const LEAF_FILL := Color(0.13, 0.20, 0.15)
const LEAF_EDGE := Color(0.58, 0.68, 0.55)
const AID_FILL := Color(0.24, 0.12, 0.13)
const AID_EDGE := Color(0.86, 0.55, 0.56)
## フォールバック3種 (D34) の台座色: 修練の書=濃緑 / ノヴァ=氷青。
const XP_FILL := Color(0.10, 0.24, 0.14)
const XP_EDGE := Color(0.45, 0.95, 0.55)
const NOVA_FILL := Color(0.10, 0.13, 0.24)
const NOVA_EDGE := Color(0.72, 0.88, 1.0)

## フォールバック3種 (D34) の表示名と台座種別。
const FALLBACK_LABELS := {"HEAL": "応急手当", "CXP": "修練の書", "CNOVA": "ノヴァ"}
const FALLBACK_KINDS := {"HEAL": "heal", "CXP": "xp", "CNOVA": "nova"}

static var _cache: Dictionary = {}


static func all_ids() -> Array:
	var ids: Array = CardsDB.DEFS.keys()
	ids.append_array(FALLBACK_LABELS.keys())
	return ids


static func label_for(card_id: String) -> String:
	if FALLBACK_LABELS.has(card_id):
		return str(FALLBACK_LABELS[card_id])
	var d: Dictionary = CardsDB.get_def(card_id)
	if d.is_empty():
		return card_id
	return str(d.get("name", card_id))


static func kind_for(card_id: String) -> String:
	if FALLBACK_KINDS.has(card_id):
		return str(FALLBACK_KINDS[card_id])
	var d: Dictionary = CardsDB.get_def(card_id)
	return str(d.get("kind", "stat"))


static func texture_for(card_id: String) -> Texture2D:
	if _cache.has(card_id):
		return _cache[card_id] as Texture2D
	var img := Image.create(MARK_SIZE, MARK_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_plate(img, kind_for(card_id))
	match card_id:
		"C01":
			_draw_spin_sword(img)
		"C02":
			_draw_straight_shot(img)
		"C03":
			_draw_homing(img)
		"C04":
			_draw_chain(img)
		"C05":
			_draw_flame(img)
		"C06":
			_draw_bomb(img)
		"C07":
			_draw_attack(img)
		"C08":
			_draw_quick(img)
		"C09":
			_draw_multi(img)
		"C10":
			_draw_area(img)
		"C11":
			_draw_duration(img)
		"C12":
			_draw_critical(img)
		"C13":
			_draw_bullet_speed(img)
		"C14":
			_draw_knockback(img)
		"C15":
			_draw_sneaker(img)
		"C16":
			_draw_heart(img)
		"C17":
			_draw_regen(img)
		"C18":
			_draw_armor(img)
		"C19":
			_draw_magnet(img)
		"C20":
			_draw_study(img)
		"HEAL":
			_draw_heal(img)
		"CXP":
			_draw_xp_book(img)
		"CNOVA":
			_draw_nova(img)
		_:
			_draw_unknown(img)
	var tex := ImageTexture.create_from_image(img)
	_cache[card_id] = tex
	return tex


## テスト用: 画像内容の簡易署名。別カードが同じ絵になっていないことを見る。
static func signature(card_id: String) -> int:
	var img: Image = (texture_for(card_id) as ImageTexture).get_image()
	var h := 7
	for y: int in range(MARK_SIZE):
		for x: int in range(MARK_SIZE):
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			h = (h * 31 + x) & 0x7fffffff
			h = (h * 31 + y) & 0x7fffffff
			h = (h * 31 + int(c.r * 255.0)) & 0x7fffffff
			h = (h * 31 + int(c.g * 255.0)) & 0x7fffffff
			h = (h * 31 + int(c.b * 255.0)) & 0x7fffffff
	return h


static func _plate(img: Image, kind: String) -> void:
	var fill := STEEL_FILL
	var edge := STEEL_EDGE
	if kind == "stat":
		fill = LEAF_FILL
		edge = LEAF_EDGE
	elif kind == "heal":
		fill = AID_FILL
		edge = AID_EDGE
	elif kind == "xp":
		fill = XP_FILL
		edge = XP_EDGE
	elif kind == "nova":
		fill = NOVA_FILL
		edge = NOVA_EDGE
	_fill_rect(img, 3, 1, 18, 22, fill)
	_fill_rect(img, 1, 3, 22, 18, fill)
	_hline(img, 3, 20, 1, edge)
	_hline(img, 3, 20, 22, edge)
	_vline(img, 1, 3, 20, edge)
	_vline(img, 22, 3, 20, edge)
	_px(img, 2, 2, edge)
	_px(img, 21, 2, edge)
	_px(img, 2, 21, edge)
	_px(img, 21, 21, edge)


static func _draw_spin_sword(img: Image) -> void:
	var orbit := Color(0.35, 0.85, 0.90)
	_circle(img, 12, 12, 7, orbit)
	_line(img, 7, 17, 17, 7, INK)
	_line(img, 7, 16, 16, 7, PAPER)
	_line(img, 7, 17, 16, 8, Color(1.0, 0.82, 0.25))
	_fill_rect(img, 5, 16, 3, 4, Color(0.42, 0.25, 0.12))
	_px(img, 6, 20, INK)


static func _draw_straight_shot(img: Image) -> void:
	_fill_rect(img, 4, 11, 12, 3, INK)
	_fill_rect(img, 4, 12, 12, 1, Color(1.0, 0.82, 0.25))
	_polyline(img, [Vector2i(13, 8), Vector2i(20, 12), Vector2i(13, 16)], INK)
	_polyline(img, [Vector2i(14, 9), Vector2i(19, 12), Vector2i(14, 15)], Color(1.0, 0.82, 0.25))


static func _draw_homing(img: Image) -> void:
	var trail := Color(1.0, 0.35, 0.75)
	_px(img, 3, 16, trail)
	_px(img, 4, 15, trail)
	_px(img, 5, 15, trail)
	_px(img, 6, 14, trail)
	_px(img, 7, 13, trail)
	_fill_rect(img, 8, 11, 8, 3, INK)
	_fill_rect(img, 9, 12, 6, 1, Color(0.75, 0.80, 0.88))
	_polyline(img, [Vector2i(15, 10), Vector2i(19, 12), Vector2i(15, 14)], Color(1.0, 0.30, 0.25))
	_px(img, 11, 12, Color(0.35, 0.85, 0.90))
	_fill_rect(img, 8, 14, 2, 2, Color(1.0, 0.30, 0.25))
	_fill_rect(img, 8, 8, 2, 2, Color(1.0, 0.30, 0.25))


static func _draw_chain(img: Image) -> void:
	var bolt := Color(1.0, 0.85, 0.25)
	_line(img, 7, 16, 12, 11, Color(1.0, 0.55, 0.15))
	_line(img, 12, 11, 17, 7, Color(1.0, 0.55, 0.15))
	_disc(img, 7, 16, 2, INK)
	_disc(img, 12, 11, 2, INK)
	_disc(img, 17, 7, 2, INK)
	_disc(img, 7, 16, 1, bolt)
	_disc(img, 12, 11, 1, bolt)
	_disc(img, 17, 7, 1, bolt)


static func _draw_flame(img: Image) -> void:
	_disc(img, 12, 14, 5, Color(0.85, 0.20, 0.10))
	_disc(img, 12, 14, 4, Color(1.0, 0.48, 0.08))
	_disc(img, 12, 15, 2, Color(1.0, 0.85, 0.25))
	_line(img, 12, 10, 12, 6, Color(1.0, 0.85, 0.25))
	_px(img, 10, 13, PAPER)


static func _draw_bomb(img: Image) -> void:
	_disc(img, 11, 14, 5, Color(0.10, 0.11, 0.16))
	_circle(img, 11, 14, 5, INK)
	_px(img, 9, 12, PAPER)
	_px(img, 10, 11, PAPER)
	_line(img, 14, 10, 17, 7, Color(0.42, 0.25, 0.12))
	_hline(img, 16, 20, 6, Color(1.0, 0.85, 0.25))
	_vline(img, 18, 4, 8, Color(1.0, 0.85, 0.25))


static func _draw_attack(img: Image) -> void:
	_fill_rect(img, 11, 6, 3, 10, INK)
	_fill_rect(img, 12, 6, 1, 9, PAPER)
	_polyline(img, [Vector2i(11, 6), Vector2i(12, 4), Vector2i(13, 6)], PAPER)
	_fill_rect(img, 9, 16, 7, 2, Color(0.42, 0.25, 0.12))
	_fill_rect(img, 11, 18, 3, 2, INK)


static func _draw_quick(img: Image) -> void:
	var hand := Color(0.35, 0.85, 0.90)
	_circle(img, 12, 12, 6, hand)
	_px(img, 12, 6, PAPER)
	_px(img, 18, 12, PAPER)
	_px(img, 12, 18, PAPER)
	_px(img, 6, 12, PAPER)
	_line(img, 12, 12, 12, 8, PAPER)
	_line(img, 12, 12, 15, 14, PAPER)
	_px(img, 12, 12, INK)


static func _draw_multi(img: Image) -> void:
	for y: int in [8, 12, 16]:
		_fill_rect(img, 4, y, 11, 1, Color(1.0, 0.82, 0.25))
		_polyline(img, [Vector2i(13, y - 2), Vector2i(18, y), Vector2i(13, y + 2)], INK)
		_polyline(img, [Vector2i(14, y - 1), Vector2i(17, y), Vector2i(14, y + 1)], Color(1.0, 0.82, 0.25))


static func _draw_area(img: Image) -> void:
	var wave := Color(0.35, 0.85, 0.90)
	_rect_outline(img, 5, 5, 14, 14, wave)
	_rect_outline(img, 7, 7, 10, 10, PAPER)
	_rect_outline(img, 9, 9, 6, 6, wave)
	_px(img, 12, 12, Color(1.0, 0.82, 0.25))


static func _draw_duration(img: Image) -> void:
	_hline(img, 8, 15, 6, PAPER)
	_hline(img, 8, 15, 17, PAPER)
	_polyline(img, [Vector2i(8, 6), Vector2i(12, 12), Vector2i(8, 17)], INK)
	_polyline(img, [Vector2i(15, 6), Vector2i(12, 12), Vector2i(15, 17)], INK)
	_fill_rect(img, 11, 14, 2, 3, Color(1.0, 0.82, 0.25))
	_px(img, 12, 8, Color(1.0, 0.82, 0.25))


static func _draw_critical(img: Image) -> void:
	var ray := Color(1.0, 0.55, 0.15)
	for p: Vector2i in [Vector2i(12, 4), Vector2i(18, 6), Vector2i(20, 12), Vector2i(18, 18), Vector2i(12, 20), Vector2i(6, 18), Vector2i(4, 12), Vector2i(6, 6)]:
		_line(img, 12, 12, p.x, p.y, ray)
	_disc(img, 12, 12, 3, INK)
	_disc(img, 12, 12, 2, Color(1.0, 0.85, 0.25))
	_px(img, 11, 11, PAPER)


static func _draw_bullet_speed(img: Image) -> void:
	var wind := Color(0.35, 0.85, 0.90)
	_hline(img, 3, 7, 9, wind)
	_hline(img, 3, 8, 12, wind)
	_hline(img, 3, 7, 15, wind)
	_fill_rect(img, 8, 11, 9, 3, INK)
	_fill_rect(img, 9, 12, 7, 1, Color(0.75, 0.80, 0.88))
	_polyline(img, [Vector2i(16, 10), Vector2i(20, 12), Vector2i(16, 14)], PAPER)


static func _draw_knockback(img: Image) -> void:
	_rect_outline(img, 5, 7, 5, 10, Color(0.65, 0.72, 0.84))
	_vline(img, 7, 9, 14, PAPER)
	_fill_rect(img, 11, 11, 6, 3, INK)
	_fill_rect(img, 11, 12, 6, 1, Color(1.0, 0.30, 0.25))
	_polyline(img, [Vector2i(15, 9), Vector2i(20, 12), Vector2i(15, 15)], Color(1.0, 0.30, 0.25))
	_px(img, 10, 9, PAPER)
	_px(img, 10, 15, PAPER)


static func _draw_sneaker(img: Image) -> void:
	var shoe := Color(0.30, 0.70, 0.35)
	_fill_rect(img, 6, 10, 7, 7, INK)
	_fill_rect(img, 7, 11, 5, 5, shoe)
	_fill_rect(img, 12, 13, 6, 3, shoe)
	_fill_rect(img, 6, 16, 12, 2, INK)
	_px(img, 8, 12, PAPER)
	_px(img, 10, 13, PAPER)
	_px(img, 15, 14, PAPER)


static func _draw_heart(img: Image) -> void:
	var heart := Color(0.90, 0.20, 0.25)
	_disc(img, 9, 10, 3, heart)
	_disc(img, 14, 10, 3, heart)
	for y: int in range(11, 19):
		var t: float = float(y - 11) / 7.0
		_hline(img, int(lerpf(6.0, 12.0, t)), int(lerpf(18.0, 12.0, t)), y, heart)
	_px(img, 8, 9, PAPER)
	_px(img, 9, 8, PAPER)


static func _draw_regen(img: Image) -> void:
	_circle(img, 12, 12, 6, Color(0.35, 0.80, 0.40))
	_hline(img, 10, 14, 12, PAPER)
	_vline(img, 12, 10, 14, PAPER)
	_polyline(img, [Vector2i(16, 7), Vector2i(18, 9), Vector2i(16, 11)], Color(1.0, 0.82, 0.25))


static func _draw_armor(img: Image) -> void:
	var plate_color := Color(0.35, 0.48, 0.68)
	_fill_rect(img, 8, 6, 8, 8, INK)
	_fill_rect(img, 9, 7, 6, 6, plate_color)
	for y: int in range(14, 19):
		var t: float = float(y - 14) / 4.0
		_hline(img, int(lerpf(8.0, 11.0, t)), int(lerpf(16.0, 12.0, t)), y, plate_color)
	_vline(img, 12, 7, 16, PAPER)


static func _draw_magnet(img: Image) -> void:
	var iron := Color(0.85, 0.20, 0.20)
	_fill_rect(img, 6, 6, 12, 5, INK)
	_fill_rect(img, 6, 6, 3, 12, INK)
	_fill_rect(img, 15, 6, 3, 12, INK)
	_fill_rect(img, 7, 7, 10, 3, iron)
	_fill_rect(img, 7, 7, 2, 8, iron)
	_fill_rect(img, 15, 7, 2, 8, iron)
	_fill_rect(img, 7, 15, 2, 3, PAPER)
	_fill_rect(img, 15, 15, 2, 3, PAPER)


static func _draw_study(img: Image) -> void:
	_fill_rect(img, 7, 7, 10, 10, INK)
	_fill_rect(img, 8, 8, 8, 8, Color(0.25, 0.45, 0.90))
	_fill_rect(img, 10, 9, 4, 6, PAPER)
	_vline(img, 12, 9, 14, INK)
	_px(img, 11, 11, Color(0.30, 0.70, 0.35))
	_px(img, 13, 13, Color(0.30, 0.70, 0.35))


static func _draw_heal(img: Image) -> void:
	_fill_rect(img, 10, 6, 4, 12, INK)
	_fill_rect(img, 6, 10, 12, 4, INK)
	_fill_rect(img, 11, 7, 2, 10, Color(0.35, 0.85, 0.40))
	_fill_rect(img, 7, 11, 10, 2, Color(0.35, 0.85, 0.40))
	_px(img, 12, 12, PAPER)


## 修練の書 (CXP): 開いた本 + 浮かぶ緑の結晶。
static func _draw_xp_book(img: Image) -> void:
	var paper := Color(0.94, 0.95, 0.98)
	var gem := Color(0.40, 0.95, 0.50)
	# 浮かぶ結晶
	_polyline(img, [Vector2i(12, 3), Vector2i(16, 7), Vector2i(12, 11), Vector2i(8, 7), Vector2i(12, 3)], INK)
	_disc(img, 12, 7, 2, gem)
	_px(img, 11, 6, PAPER)
	# 開いた本 (左右のページと背)
	_fill_rect(img, 4, 13, 16, 6, INK)
	_fill_rect(img, 5, 14, 6, 4, paper)
	_fill_rect(img, 13, 14, 6, 4, paper)
	_vline(img, 12, 13, 18, INK)


## ノヴァ (CNOVA): 白い十字の光。
static func _draw_nova(img: Image) -> void:
	var light := Color(1, 1, 1)
	var glow := Color(0.72, 0.90, 1.0)
	# 縁取りつきの十字
	_fill_rect(img, 4, 10, 17, 5, INK)
	_fill_rect(img, 10, 4, 5, 17, INK)
	_fill_rect(img, 5, 11, 15, 3, light)
	_fill_rect(img, 11, 5, 3, 15, light)
	# 斜めの短い光
	_line(img, 7, 7, 9, 9, glow)
	_line(img, 16, 7, 14, 9, glow)
	_line(img, 7, 16, 9, 14, glow)
	_line(img, 16, 16, 14, 14, glow)
	# 中心
	_disc(img, 12, 12, 3, INK)
	_disc(img, 12, 12, 2, light)
	_px(img, 12, 12, glow)


static func _draw_unknown(img: Image) -> void:
	_polyline(img, [Vector2i(12, 6), Vector2i(18, 12), Vector2i(12, 18), Vector2i(6, 12), Vector2i(12, 6)], Color(0.65, 0.72, 0.84))
	_px(img, 12, 12, PAPER)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < MARK_SIZE and y < MARK_SIZE:
		img.set_pixel(x, y, c)


static func _hline(img: Image, x0: int, x1: int, y: int, c: Color) -> void:
	for x: int in range(mini(x0, x1), maxi(x0, x1) + 1):
		_px(img, x, y, c)


static func _vline(img: Image, x: int, y0: int, y1: int, c: Color) -> void:
	for y: int in range(mini(y0, y1), maxi(y0, y1) + 1):
		_px(img, x, y, c)


static func _fill_rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy: int in range(y, y + h):
		for xx: int in range(x, x + w):
			_px(img, xx, yy, c)


static func _rect_outline(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	_hline(img, x, x + w - 1, y, c)
	_hline(img, x, x + w - 1, y + h - 1, c)
	_vline(img, x, y, y + h - 1, c)
	_vline(img, x + w - 1, y, y + h - 1, c)


static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	while true:
		_px(img, x0, y0, c)
		if x0 == x1 and y0 == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


static func _polyline(img: Image, points: Array, c: Color) -> void:
	for i: int in range(points.size() - 1):
		var a: Vector2i = points[i] as Vector2i
		var b: Vector2i = points[i + 1] as Vector2i
		_line(img, a.x, a.y, b.x, b.y, c)


static func _circle(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for a: int in range(360):
		var t: float = float(a) * PI / 180.0
		_px(img, cx + int(round(cos(t) * float(r))), cy + int(round(sin(t) * float(r))), c)


static func _disc(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for dy: int in range(-r, r + 1):
		var dx: int = int(sqrt(float(maxi(0, r * r - dy * dy))))
		_hline(img, cx - dx, cx + dx, cy + dy, c)
