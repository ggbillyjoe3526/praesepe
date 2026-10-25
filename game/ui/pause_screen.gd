class_name PauseScreen
extends CanvasLayer
## Pausing (project instructions, "Pause on Esc, focus loss and mouse-capture loss"): Esc, the window losing focus or
## the game losing hold of the mouse stops the game (the tree is paused, so the ship, the clock and every timer stand
## still) and shows this screen with the mouse free. Esc or Resume carries on; the mouse is captured again. Quit to
## title goes back to the start menu, Quit to desktop closes the game. The pause mechanic follows the owner's Airsoft-Next project (game/ui/pause_menu.gd); its look is a placeholder.
## Settings opens the settings menu (SettingsMenu) over it; Esc or Back comes back here. Any change is saved when the
## menu closes, on resume and on quit (Settings.commit()).

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

## Who to hand the mouse back to on resume, and whether losing the mouse pauses (off when nobody is flying by hand,
## as in the smoke test).
@export var controls: PilotControls

## The settings menu (public for the tests and the smoke test).
var settings_menu: SettingsMenu

var _resume: Button
var _settings_button: Button
var _seed: Label
## The pause screen's own plate, hidden while the settings menu is up.
var _main: Control
var _was_captured: bool = false


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func open() -> void:
	if visible:
		return
	_seed.text = "World seed %d" % Game.world_seed
	visible = true
	_main.visible = true
	settings_menu.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_was_captured = false
	_resume.grab_focus()


func close() -> void:
	if not visible:
		return
	settings_menu.close()
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


## The settings menu over the pause screen.
func open_settings() -> void:
	_main.visible = false
	settings_menu.open()


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
	_main = centre
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
	_settings_button = _button(list, "Settings")
	_settings_button.pressed.connect(open_settings)
	var to_title := _button(list, "Quit to title")
	to_title.pressed.connect(_quit_to_title)
	var quit := _button(list, "Quit to desktop")
	quit.pressed.connect(_quit)
	settings_menu = SettingsMenu.new()
	settings_menu.visible = false
	settings_menu.closed.connect(_settings_closed)
	add_child(settings_menu)


func _quit() -> void:
	Settings.commit()
	get_tree().quit()


## Back to the title screen (TitleScreen): the game scene is freed whole, so nothing of it is left running.
func _quit_to_title() -> void:
	Settings.commit()
	get_tree().paused = false
	get_tree().change_scene_to_file(TitleScreen.SCENE)


func _settings_closed() -> void:
	if not visible:
		return
	_main.visible = true
	_settings_button.grab_focus()


func _button(parent: Control, words: String) -> Button:
	var b := Button.new()
	b.text = words
	b.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	b.add_theme_font_size_override("font_size", BUTTON_TEXT_SIZE)
	parent.add_child(b)
	return b
