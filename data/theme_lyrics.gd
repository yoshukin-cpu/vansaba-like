extends RefCounted
## テーマソングの時刻付き歌詞 (`audio/music/vansaba_theme_lyrics_timing.txt`)。
## 形式: 1行 `MM:SS.cc テキスト` (`:` 区切りも許容)。テキスト空行は区切りマーカー
## (アウトロ開始など) で、その時刻以降は歌詞を表示しない。

const PATH := "res://audio/music/vansaba_theme_lyrics_timing.txt"


## "MM:SS.cc" / "MM:SS:cc" → 秒。不正は -1.0。
static func parse_time(s: String) -> float:
	var a: PackedStringArray = s.replace(".", ":").split(":")
	if a.size() < 3 or not a[0].is_valid_int():
		return -1.0
	return float(a[0]) * 60.0 + float(a[1]) + float(a[2]) / 100.0


## 時刻順の [{"t": float, "text": String}]。読めなければ空配列。
static func load_timed() -> Array:
	var out: Array = []
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line: String = f.get_line().strip_edges()
		if line == "":
			continue
		var sp: int = line.find(" ")
		var t: float = parse_time(line if sp < 0 else line.substr(0, sp))
		if t < 0.0:
			continue
		var text := "" if sp < 0 else line.substr(sp + 1).strip_edges()
		out.append({"t": t, "text": text})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	return out


## song_pos(曲頭からの秒) での表示行。空文字は非表示 (前奏・間奏の空白・アウトロ以降)。
static func line_at(entries: Array, song_pos: float) -> Dictionary:
	var cur := ""
	var next := ""
	for e: Dictionary in entries:
		if float(e["t"]) <= song_pos:
			cur = str(e["text"])
		else:
			if str(e["text"]) != "":
				next = str(e["text"])
			break
	if cur == "":
		return {"cur": "", "next": ""}
	return {"cur": cur, "next": next}
