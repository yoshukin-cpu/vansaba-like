extends Node

var players: Array = []
var streams: Dictionary = {}
var last_play: Dictionary = {}

const SFX_DIR := "res://audio/sfx/"
const SFX_KEYS := ["shoot", "zap", "hit", "kill", "hurt", "levelup", "ui", "warn",
	"clear", "death", "pop", "chest", "coin", "explode", "buff", "heal", "beep",
	"item_pickup", "chest_open", "gem"]

func _ready() -> void:
	add_to_group("audio")
	for i: int in range(8):
		var p := AudioStreamPlayer.new()
		p.volume_db = -10.0
		p.bus = "SE"
		add_child(p)
		players.append(p)
	for k: String in SFX_KEYS:
		streams[k] = load(SFX_DIR + k + ".wav")

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
