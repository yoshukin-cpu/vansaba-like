extends CanvasLayer

signal choice_selected(card_id: String)

var offers: Array = []
var focus_idx: int = 0

@onready var btn0: Button = $Center/VBox/Cards/Btn0
@onready var btn1: Button = $Center/VBox/Cards/Btn1
@onready var btn2: Button = $Center/VBox/Cards/Btn2

func _ready() -> void:
	visible = false
	var buttons: Array = [btn0, btn1, btn2]
	for i: int in range(buttons.size()):
		var b: Button = buttons[i] as Button
		b.pressed.connect(_on_btn.bind(i))
		b.focus_entered.connect(_on_focus.bind(i))

func show_offers(o: Array) -> void:
	offers = o
	focus_idx = 0
	visible = true
	var buttons: Array = [btn0, btn1, btn2]
	for i: int in range(buttons.size()):
		var b: Button = buttons[i] as Button
		var e: Dictionary = offers[i] as Dictionary
		var head: String = str(e["name"])
		if str(e["level_text"]) != "":
			head += "\n" + str(e["level_text"])
		b.text = head + "\n\n" + str(e["detail"])
	btn0.grab_focus()

func _on_btn(i: int) -> void:
	if not visible:
		return
	if i >= 0 and i < offers.size():
		choice_selected.emit(str((offers[i] as Dictionary)["id"]))

func _on_focus(i: int) -> void:
	focus_idx = i

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var ke: InputEventKey = event as InputEventKey
		var k: int = int(ke.physical_keycode) if int(ke.physical_keycode) != 0 else int(ke.keycode)
		if k == KEY_1 or k == KEY_2 or k == KEY_3:
			get_viewport().set_input_as_handled()
			_on_btn(int(k - KEY_1))
			return
	if event is InputEventJoypadButton and event.pressed:
		if (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
			get_viewport().set_input_as_handled()
			_on_btn(focus_idx)
