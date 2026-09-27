extends RefCounted
## オプションの定義と適用 (SPEC §35.2・§35.3、v1.8/案6)。
## 表示: ウィンドウ/フルスクリーン + 解像度16件 (4Kまで。余りは黒帯 = stretch keep)。
## 音量: BGM/SE バスの 0〜100% (5%刻み)。

const MODE_WINDOW := "window"
const MODE_FULLSCREEN := "fullscreen"
const DEFAULT_BGM := 0.8
const DEFAULT_SE := 1.0
const VOL_STEP := 0.05

## 解像度 (ウィンドウ時のサイズ。16:9・16:10・4:3 のみ。縦長は考慮しない)。

const RESOLUTIONS: Array = [
	[1152, 648], [1280, 720], [1600, 900], [1920, 1080], [2560, 1440], [3840, 2160],
	[1280, 800], [1680, 1050], [1920, 1200], [2560, 1600], [3840, 2400],
	[1024, 768], [1280, 960], [1600, 1200], [1920, 1440], [2880, 2160],
]


static func parse_resolution(res: String) -> Vector2i:
	var parts: PackedStringArray = res.split("x")
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		return Vector2i(parts[0].to_int(), parts[1].to_int())
	return Vector2i(1152, 648)


static func format_resolution(size: Vector2i) -> String:
	return "%dx%d" % [size.x, size.y]


static func is_valid_resolution(res: String) -> bool:
	var s: Vector2i = parse_resolution(res)
	for r: Array in RESOLUTIONS:
		if int(r[0]) == s.x and int(r[1]) == s.y:
			return true
	return false


static func resolution_index(res: String) -> int:
	var s: Vector2i = parse_resolution(res)
	for i: int in range(RESOLUTIONS.size()):
		var r: Array = RESOLUTIONS[i]
		if int(r[0]) == s.x and int(r[1]) == s.y:
			return i
	return 0


static func resolution_at(index: int) -> String:
	var i: int = ((index % RESOLUTIONS.size()) + RESOLUTIONS.size()) % RESOLUTIONS.size()
	var r: Array = RESOLUTIONS[i]
	return format_resolution(Vector2i(int(r[0]), int(r[1])))


static func aspect_label(size: Vector2i) -> String:
	var r: float = float(size.x) / float(size.y)
	if is_equal_approx(r, 16.0 / 9.0):
		return "16:9"
	if is_equal_approx(r, 16.0 / 10.0):
		return "16:10"
	return "4:3"


static func resolution_label(res: String) -> String:
	var s: Vector2i = parse_resolution(res)
	return "%d×%d (%s)" % [s.x, s.y, aspect_label(s)]


## モニタに収まらない解像度は、作業領域に収まるよう等比で縮小する (セーブ値は元のまま)。
static func fitted_window_size(res: String, usable: Rect2i) -> Vector2i:
	var s: Vector2i = parse_resolution(res)
	if usable.size.x <= 0 or usable.size.y <= 0:
		return s
	var sc: float = minf(1.0, minf(float(usable.size.x) / float(s.x), float(usable.size.y) / float(s.y)))
	return Vector2i(int(floor(float(s.x) * sc)), int(floor(float(s.y) * sc)))


static func centered_position(usable: Rect2i, size: Vector2i) -> Vector2i:
	return usable.position + (usable.size - size) / 2


# --- 音量 (BGM/SE バス) ---

static func clamp_volume(v: float) -> float:
	return clampf(snappedf(v, VOL_STEP), 0.0, 1.0)


static func apply_volume(bgm: float, se: float) -> void:
	_set_bus("BGM", bgm)
	_set_bus("SE", se)


static func _set_bus(bname: String, v: float) -> void:
	var idx: int = AudioServer.get_bus_index(bname)
	if idx < 0:
		return
	var lin: float = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, lin <= 0.0001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(lin, 0.0001)))


static func bus_volume(bname: String) -> float:
	var idx: int = AudioServer.get_bus_index(bname)
	if idx < 0:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))


# --- 表示の適用 ---

static func apply_display(mode: String, res: String) -> void:
	# ヘッドレスでは表示の操作を行わない (検証は純関数側で行う)。
	if DisplayServer.get_name() == "headless":
		return
	if mode == MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var size: Vector2i = fitted_window_size(res, usable)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(centered_position(usable, size))
