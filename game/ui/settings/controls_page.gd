class_name ControlsPage
extends SettingsPage
## Settings › Controls: the mouse (sensitivity, invert) and every key, the list that used to run along the top of the
## screen. The keys are read from the input map (KeyNames), so the list always says what the game really uses and is
## named in the player's keyboard layout.

## What each key does, in the order the list shows them: words, then the actions whose keys are shown (two actions
## read "W / S"). An empty list of actions shows `KEYS_WITHOUT_ACTION`'s words instead.
const KEYS: Array[Array] = [
	["Speed up / slow down", [&"thrust_forward", &"thrust_back"]],
	["Slide left / right", [&"strafe_left", &"strafe_right"]],
	["Slide up / down", [&"thrust_up", &"thrust_down"]],
	["Steer (pitch and yaw)", []],
	["Roll left / right", [&"roll_left", &"roll_right"]],
	["Flight assist on or off", [&"toggle_assist"]],
	["Full stop", [&"full_stop"]],
	["Cruise drive (aim at a place to fly there)", [&"toggle_cruise"]],
	["Enter or leave orbit", [&"toggle_orbit"]],
	["Dock, land, undock or take off", [&"dock"]],
	["Cockpit or chase camera", [&"toggle_camera"]],
	["Pause, settings and controls", [&"pause"]],
	["Fullscreen or window", []],
	["Debug overlay", []],
]
## The keys that aren't in the input map, by their words in KEYS.
const KEYS_WITHOUT_ACTION: Dictionary[String, String] = {
	"Steer (pitch and yaw)": "Mouse",
	"Fullscreen or window": "F11 or Alt+Enter",
	"Debug overlay": "F3",
}
const KEY_COLOUR := Color(1.0, 0.86, 0.5)
const KEY_COLUMN_WIDTH := 300.0

var sensitivity_slider: HSlider
var invert_check: CheckButton
## The key list's right-hand labels, in KEYS's order (public for the tests).
var key_labels: Array[Label] = []


func _init() -> void:
	title = "Controls"
	keys = PackedStringArray(["sensitivity", "invert_mouse"])


func build() -> void:
	add_heading("Mouse")
	sensitivity_slider = add_slider("Mouse sensitivity", Settings.SENSITIVITY_MIN, Settings.SENSITIVITY_MAX,
			Settings.SENSITIVITY_STEP, Settings.set_sensitivity)
	invert_check = add_toggle("Invert mouse: mouse up points the nose down", Settings.set_invert_mouse)
	add_heading("Keys")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", GAP * 2)
	grid.add_theme_constant_override("v_separation", GAP / 2)
	add_child(grid)
	for entry in KEYS:
		var does := Label.new()
		does.text = entry[0]
		does.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		does.add_theme_font_size_override("font_size", SETTING_SIZE)
		grid.add_child(does)
		var key := Label.new()
		key.custom_minimum_size = Vector2(KEY_COLUMN_WIDTH, 0)
		key.add_theme_font_size_override("font_size", SETTING_SIZE)
		key.add_theme_color_override("font_color", KEY_COLOUR)
		grid.add_child(key)
		key_labels.append(key)
	add_hint("Click captures the mouse again after it was let go.")


func sync() -> void:
	sensitivity_slider.set_value_no_signal(Settings.sensitivity)
	SettingsPage.value_label(sensitivity_slider).text = "%.2f×" % Settings.sensitivity
	invert_check.set_pressed_no_signal(Settings.invert_mouse)
	for i in KEYS.size():
		key_labels[i].text = ControlsPage.keys_text(KEYS[i])


## The keys of one entry of KEYS: "W / S", "Ctrl or C", or its fixed words.
static func keys_text(entry: Array) -> String:
	var actions: Array = entry[1]
	if actions.is_empty():
		return KEYS_WITHOUT_ACTION.get(entry[0], KeyNames.NO_KEY)
	var parts := PackedStringArray()
	for action: StringName in actions:
		parts.append(KeyNames.of_action(action))
	return " / ".join(parts)
