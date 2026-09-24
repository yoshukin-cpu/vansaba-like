extends Node

var players: Array = []
var streams: Dictionary = {}
var last_play: Dictionary = {}

func _ready() -> void:
	add_to_group("audio")
	for i: int in range(8):
		var p := AudioStreamPlayer.new()
		p.volume_db = -10.0
		add_child(p)
		players.append(p)
	streams["shoot"] = _tone(880.0, 0.06, 0.5)
	streams["zap"] = _tone(1400.0, 0.09, 0.4)
	streams["hit"] = _tone(220.0, 0.05, 0.5)
	streams["kill"] = _tone(520.0, 0.09, 0.5)
	streams["hurt"] = _tone(160.0, 0.15, 0.6)
	streams["levelup"] = _tone(990.0, 0.18, 0.5)
	streams["ui"] = _tone(700.0, 0.05, 0.4)
	streams["warn"] = _tone(150.0, 0.4, 0.6)
	streams["clear"] = _tone(784.0, 0.35, 0.5)
	streams["death"] = _tone(110.0, 0.5, 0.6)
	streams["pop"] = _tone(600.0, 0.08, 0.4)
	streams["chest"] = _tone(520.0, 0.12, 0.5)
	streams["coin"] = _tone(1568.0, 0.1, 0.4)
	streams["explode"] = _tone(70.0, 0.5, 0.7)
	streams["buff"] = _tone(660.0, 0.15, 0.5)
	streams["heal"] = _tone(740.0, 0.15, 0.45)
	streams["beep"] = _tone(880.0, 0.08, 0.5)

func _tone(freq: float, dur: float, vol: float) -> AudioStreamWAV:
	var rate: int = 22050
	var n: int = int(rate * dur)
	var data := PackedByteArray()
	data.resize(n)
	for i: int in range(n):
		var t: float = float(i) / float(rate)
		var env: float = exp(-4.0 * float(i) / float(n))
		var s: float = sin(TAU * freq * t) * env * vol
		data[i] = int(clampf(128.0 + 127.0 * s, 0.0, 255.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav

func play(sname: String) -> void:
	if not streams.has(sname):
		return
	var now: int = Time.get_ticks_msec()
	if int(last_play.get(sname, -1000)) + 60 > now:
		return
	last_play[sname] = now
	for p: AudioStreamPlayer in players:
		if not p.playing:
			p.stream = streams[sname] as AudioStreamWAV
			p.play()
			return
