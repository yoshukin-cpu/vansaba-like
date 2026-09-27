extends CanvasLayer
## スタッフロール再演のカウントダウン (SPEC §35.13、v1.8 追補2・D77)。
## 3→2→1 を 1秒刻みで出し、0 で finished を出す (クリア演出と同じ beep)。
## タイトル画面は paused のため process_mode は ALWAYS (tscn 側で設定)。

signal finished

const DEFAULT_SECS := 3.0

@onready var count: Label = $Count

## 残り秒。負値 = 非動作。
var remaining: float = -1.0
var _last: int = -1


func _ready() -> void:
	visible = false


## カウントダウンを開始する (検証からも呼ぶ)。
func start(secs: float = DEFAULT_SECS) -> void:
	remaining = maxf(0.0, secs)
	_last = -1
	visible = true


func _process(delta: float) -> void:
	if remaining < 0.0:
		return
	remaining -= delta
	var n: int = int(ceil(remaining))
	if n >= 1 and n != _last:
		_last = n
		count.text = str(n)
		var audio: Node = get_tree().get_first_node_in_group("audio")
		if audio != null:
			audio.call("play", "beep")
	if remaining < 0.0:
		visible = false
		finished.emit()
