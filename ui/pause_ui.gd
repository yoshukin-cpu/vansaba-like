extends CanvasLayer

signal resume_pressed
signal quit_pressed

var focus_idx: int = 0

@onready var resume_btn: Button = $Center/VBox/ResumeBtn
@onready var quit_btn: Button = $Center/VBox/QuitBtn

func _ready() -> void:
	visible = false
	resume_btn.pressed.connect(func() -> void: resume_pressed.emit())
	quit_btn.pressed.connect(func() -> void: quit_pressed.emit())
	resume_btn.focus_entered.connect(_on_focus.bind(0))
	quit_btn.focus_entered.connect(_on_focus.bind(1))

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventJoypadButton and event.pressed:
		if (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
			if focus_idx == 0:
				resume_pressed.emit()
			else:
				quit_pressed.emit()
			get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	focus_idx = 0
	resume_btn.grab_focus()

func _on_focus(i: int) -> void:
	focus_idx = i

func close() -> void:
	visible = false
