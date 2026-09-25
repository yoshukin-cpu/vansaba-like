extends CanvasLayer

signal choice_selected(card_id: String)

const CardMarks := preload("res://data/card_marks.gd")
const MARK_MIN := Vector2(112, 112)

var offers: Array = []
var focus_idx: int = 0
var _icons: Array = []
var _names: Array = []
var _levels: Array = []
var _details: Array = []

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
		_build_card(b)

func show_offers(o: Array) -> void:
	offers = o
	focus_idx = 0
	visible = true
	var buttons: Array = [btn0, btn1, btn2]
	for i: int in range(buttons.size()):
		var e: Dictionary = offers[i] as Dictionary
		(_names[i] as Label).text = str(e["name"])
		(_levels[i] as Label).text = str(e["level_text"])
		(_details[i] as Label).text = str(e["detail"])
		var tex: Texture2D = e.get("icon", null)
		if tex == null:
			tex = CardMarks.texture_for(str(e["id"]))
		(_icons[i] as TextureRect).texture = tex
	btn0.grab_focus()

func _on_btn(i: int) -> void:
	if not visible:
		return
	if i >= 0 and i < offers.size():
		choice_selected.emit(str((offers[i] as Dictionary)["id"]))

func _on_focus(i: int) -> void:
	focus_idx = i

func _build_card(b: Button) -> void:
	b.text = ""
	var box := VBoxContainer.new()
	box.name = "Box"
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.name = "Mark"
	icon.custom_minimum_size = MARK_MIN
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var level_label := Label.new()
	level_label.name = "Level"
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 18)
	level_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var detail_label := Label.new()
	detail_label.name = "Detail"
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.add_theme_font_size_override("font_size", 18)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(icon)
	box.add_child(name_label)
	box.add_child(level_label)
	box.add_child(detail_label)
	_icons.append(icon)
	_names.append(name_label)
	_levels.append(level_label)
	_details.append(detail_label)
	b.add_child(box)

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
