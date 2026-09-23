extends Node2D

var nums: Array = []
var sparks: Array = []

func _ready() -> void:
	add_to_group("combat_fx")
	z_index = 50

func damage_number(pos: Vector2, amount: float, crit: bool) -> void:
	var txt: String = str(int(round(amount)))
	if crit:
		nums.append({"pos": pos + Vector2(randf_range(-6, 6), -18), "vel": Vector2(randf_range(-20, 20), -140), "age": 0.0, "life": 0.9, "text": txt + "!", "size": 26, "color": Color(1.0, 0.8, 0.2)})
	else:
		nums.append({"pos": pos + Vector2(randf_range(-6, 6), -14), "vel": Vector2(randf_range(-15, 15), -110), "age": 0.0, "life": 0.6, "text": txt, "size": 16, "color": Color(1, 1, 1)})
	while nums.size() > 120:
		nums.pop_front()

func spark(pos: Vector2, color: Color) -> void:
	sparks.append({"pos": pos, "age": 0.0, "life": 0.18, "max_r": 14.0, "color": color, "width": 3.0})
	while sparks.size() > 80:
		sparks.pop_front()

func poof(pos: Vector2, color: Color, big: bool) -> void:
	var r: float = 34.0 if big else 20.0
	sparks.append({"pos": pos, "age": 0.0, "life": 0.3, "max_r": r, "color": color, "width": 5.0})

func _process(delta: float) -> void:
	var dirty := false
	for i: int in range(nums.size() - 1, -1, -1):
		var n: Dictionary = nums[i]
		n["age"] = float(n["age"]) + delta
		if float(n["age"]) >= float(n["life"]):
			nums.remove_at(i)
		else:
			n["pos"] = (n["pos"] as Vector2) + (n["vel"] as Vector2) * delta
			nums[i] = n
		dirty = true
	for i: int in range(sparks.size() - 1, -1, -1):
		var s: Dictionary = sparks[i]
		s["age"] = float(s["age"]) + delta
		if float(s["age"]) >= float(s["life"]):
			sparks.remove_at(i)
		else:
			sparks[i] = s
		dirty = true
	if dirty or nums.size() > 0 or sparks.size() > 0:
		queue_redraw()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for n: Dictionary in nums:
		var k: float = 1.0 - float(n["age"]) / float(n["life"])
		var c: Color = (n["color"] as Color)
		c.a = clampf(k * 1.5, 0.0, 1.0)
		draw_string(font, (n["pos"] as Vector2) - global_position, str(n["text"]), HORIZONTAL_ALIGNMENT_CENTER, -1.0, int(n["size"]), c)
	for s: Dictionary in sparks:
		var t: float = float(s["age"]) / float(s["life"])
		var c2: Color = (s["color"] as Color)
		c2.a = 1.0 - t
		draw_arc((s["pos"] as Vector2) - global_position, float(s["max_r"]) * t + 4.0, 0.0, TAU, 16, c2, float(s["width"]), true)
