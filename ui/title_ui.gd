extends CanvasLayer

signal start_pressed
signal quit_pressed

@onready var start_btn: Button = $Center/VBox/StartBtn
@onready var quit_btn: Button = $Center/VBox/QuitBtn

func _ready() -> void:
	start_btn.pressed.connect(func() -> void: start_pressed.emit())
	quit_btn.pressed.connect(func() -> void: quit_pressed.emit())
	start_btn.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		start_pressed.emit()
		return
	if event is InputEventJoypadButton and event.pressed:
		if (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
			get_viewport().set_input_as_handled()
			start_pressed.emit()
