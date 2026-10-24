class_name PauseScreen
extends CanvasLayer
## Pausing (project instructions, "Pause on Esc, focus loss and mouse-capture loss"): Esc, the window losing focus or
## the game losing hold of the mouse stops the game (the tree is paused, so the ship, the clock and every timer stand
## still) and shows this screen with the mouse free. Esc or Resume carries on; the mouse is captured again. The pause
## mechanic follows the owner's Airsoft-Next project (game/ui/pause_menu.gd); its look is a placeholder.
## It also holds the comfort settings until the settings menu exists: field of view, camera shake, head bob and reduce
## motion. Each takes effect at once (the paused frame behind shows the new field of view) and is saved on resume or
## quit (Settings.commit()).

const LAYER := 50
const PLATE_COLOUR := Color(0.03, 0.04, 0.08, 0.96)
const SHADE_COLOUR := Color(0.0, 0.0, 0.0, 0.45)
const SEED_COLOUR := Color(0.7, 0.75, 0.85)
## Sizes in px at 1080p.
const PLATE_MARGIN := 36.0
const PLATE_WIDTH := 600.0
const GAP := 16
const TITLE_SIZE := 48
const SEED_SIZE := 22
const BUTTON_HEIGHT := 64.0
const BUTTON_TEXT_SIZE := 28
const HEADING_SIZE := 30
const SETTING_SIZE := 24
const HINT_SIZE := 19
const HINT_COLOUR := Color(0.7, 0.75, 0.85)
const OFF_TEXT_COLOUR := Color(0.55, 0.58, 0.65)
const SLIDER_HEIGHT := 36.0
## Camera shake is set in steps of this (of full shake).
const SHAKE_STEP := 0.1

## Who to hand the mouse back to on resume, and whether losing the mouse pauses (off when nobody is flying by hand,
## as in the smoke test).
@export var controls: PilotControls

## The comfort settings' controls (public for the tests).
var fov_slider: HSlider
var shake_slider: HSlider
var head_bob_check: CheckButton
var reduce_motion_check: CheckButton

var _resume: Button
var _seed: Label
var _fov_value: Label
var _shake_value: Label
var _was_captured: bool = false


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Settings.changed.connect(_sync_settings)
	_sync_settings()
	visible = false


func _exit_tree() -> void:
	if Settings.changed.is_connected(_sync_settings):
		Settings.changed.disconnect(_sync_settings)


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
	Settings.commit()
	if controls != null:
		controls.capture_mouse()


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
	box.set_content_margin_all(PLATE_MARGIN)
	plate.add_theme_stylebox_override("panel", box)
	centre.add_child(plate)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", GAP)
	list.custom_minimum_size = Vector2(PLATE_WIDTH, 0)
	plate.add_child(list)
	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(title)
	_seed = Label.new()
	_seed.add_theme_font_size_override("font_size", SEED_SIZE)
	_seed.add_theme_color_override("font_color", SEED_COLOUR)
	_seed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(_seed)
	_resume = _button(list, "Resume (Esc)")
	_resume.pressed.connect(close)
	var quit := _button(list, "Quit to desktop")
	quit.pressed.connect(_quit)
	_build_comfort(list)


func _quit() -> void:
	Settings.commit()
	get_tree().quit()


func _build_comfort(list: VBoxContainer) -> void:
	list.add_child(HSeparator.new())
	var heading := Label.new()
	heading.text = "Comfort"
	heading.add_theme_font_size_override("font_size", HEADING_SIZE)
	list.add_child(heading)
	_fov_value = _setting_row(list, "Field of view")
	fov_slider = _slider(list, Settings.FOV_MIN, Settings.FOV_MAX, 1.0)
	fov_slider.value_changed.connect(Settings.set_fov)
	_shake_value = _setting_row(list, "Camera shake")
	shake_slider = _slider(list, 0.0, 1.0, SHAKE_STEP)
	shake_slider.value_changed.connect(Settings.set_shake)
	head_bob_check = _check(list, "Head bob: your head sways as the ship pushes")
	head_bob_check.toggled.connect(Settings.set_head_bob)
	reduce_motion_check = _check(list, "Reduce motion")
	reduce_motion_check.toggled.connect(Settings.set_reduce_motion)
	var hint := Label.new()
	hint.text = "Reduce motion turns off shake and head bob, and steadies the chase camera."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", HINT_SIZE)
	hint.add_theme_color_override("font_color", HINT_COLOUR)
	list.add_child(hint)


## Shows the settings as they are now, without sending them back.
func _sync_settings() -> void:
	if fov_slider == null:
		return
	var calm := Settings.reduce_motion
	fov_slider.set_value_no_signal(Settings.fov)
	_fov_value.text = "%d°" % roundi(Settings.fov)
	shake_slider.set_value_no_signal(Settings.shake)
	shake_slider.editable = not calm
	_shake_value.text = "off (reduce motion)" if calm else "%d%%" % roundi(Settings.shake * 100.0)
	_shake_value.add_theme_color_override("font_color", OFF_TEXT_COLOUR if calm else Color.WHITE)
	head_bob_check.set_pressed_no_signal(Settings.head_bob)
	head_bob_check.disabled = calm
	reduce_motion_check.set_pressed_no_signal(calm)


## A setting's name on the left and its value on the right; returns the value's label.
func _setting_row(parent: Control, words: String) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var name_label := Label.new()
	name_label.text = words
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", SETTING_SIZE)
	row.add_child(name_label)
	var value := Label.new()
	value.add_theme_font_size_override("font_size", SETTING_SIZE)
	row.add_child(value)
	return value


func _slider(parent: Control, low: float, high: float, step: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.custom_minimum_size = Vector2(0, SLIDER_HEIGHT)
	parent.add_child(slider)
	return slider


func _check(parent: Control, words: String) -> CheckButton:
	var check := CheckButton.new()
	check.text = words
	check.add_theme_font_size_override("font_size", SETTING_SIZE)
	parent.add_child(check)
	return check


func _button(parent: Control, words: String) -> Button:
	var b := Button.new()
	b.text = words
	b.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	b.add_theme_font_size_override("font_size", BUTTON_TEXT_SIZE)
	parent.add_child(b)
	return b
