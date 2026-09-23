extends CanvasLayer

signal start_pressed

@onready var start_btn: Button = $Center/VBox/StartBtn

func _ready() -> void:
	start_btn.pressed.connect(func() -> void: start_pressed.emit())
	start_btn.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		start_pressed.emit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed:
		if (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
			start_pressed.emit()
			get_viewport().set_input_as_handled()
