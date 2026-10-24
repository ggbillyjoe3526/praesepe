class_name PauseScreen
extends CanvasLayer
## Pausing (project instructions, "Pause on Esc, focus loss and mouse-capture loss"): Esc, the window losing focus or
## the game losing hold of the mouse stops the game (the tree is paused, so the ship, the clock and every timer stand
## still) and shows this screen with the mouse free. Esc or Resume carries on; the mouse is captured again. The pause
## mechanic follows the owner's Airsoft-Next project (game/ui/pause_menu.gd); its look is a placeholder.

signal resumed

const LAYER := 50
const PLATE_COLOUR := Color(0.03, 0.04, 0.08, 0.96)
const SHADE_COLOUR := Color(0.0, 0.0, 0.0, 0.45)

## Who to hand the mouse back to on resume, and whether losing the mouse pauses (off when nobody is flying by hand,
## as in the smoke test).
@export var controls: PilotControls

var _resume: Button
var _seed: Label
var _was_captured: bool = false


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	_seed.text = "World seed %d" % Game.world_seed
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_was_captured = false
	_resume.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	if controls != null:
		controls.capture_mouse()
	resumed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if visible:
			close()
		else:
			open()


func _process(_delta: float) -> void:
	if controls == null or visible:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _was_captured and not captured:
		open()
		return
	_was_captured = captured


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if is_inside_tree() and controls != null:
			open()


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = SHADE_COLOUR
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var plate := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = PLATE_COLOUR
	box.set_corner_radius_all(10)
	box.set_content_margin_all(36.0)
	plate.add_theme_stylebox_override("panel", box)
	centre.add_child(plate)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 16)
	list.custom_minimum_size = Vector2(460, 0)
	plate.add_child(list)
	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(title)
	_seed = Label.new()
	_seed.add_theme_font_size_override("font_size", 22)
	_seed.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	_seed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(_seed)
	_resume = _button(list, "Resume (Esc)")
	_resume.pressed.connect(close)
	var quit := _button(list, "Quit to desktop")
	quit.pressed.connect(func() -> void: get_tree().quit())


func _button(parent: Control, words: String) -> Button:
	var b := Button.new()
	b.text = words
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", 28)
	parent.add_child(b)
	return b
